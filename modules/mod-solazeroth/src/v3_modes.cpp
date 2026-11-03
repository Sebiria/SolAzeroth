// v3, F9 (01/11/2026) : modes de zone (document v3, « Un jeu dur, mais permissif pour qui veut récolter »).
// - À 60 % d'une zone (v3_zone.cpp), le joueur choisit dans une zone de repos (auberge, ville) le mode de cette zone :
//   .mode normal|difficile|cauchemar|aucun. Gardé dans acore_characters.solazeroth_v3_modes (migration 091).
//   Le difficile s'ouvre au palier 5 du rang d'aventurier, le cauchemar au palier 9 (v3_aventurier.cpp).
// - Quand un monstre de la zone engage le joueur, il est remis à la puissance du mode : la puissance de base du joueur
//   (moyenne des niveaux d'objet, sans les rangs : les rangs restent un vrai gain, outils\simulation_modes.py ; la plus
//   haute atteinte depuis le lot 4a, pour qu'une maille de bas niveau ne garde pas les monstres faibles), plus
//   l'écart du mode. Un monstre plus fort la garde. Vie, dégâts d'arme, puissance d'attaque et armure suivent les
//   statistiques de base du moteur à la nouvelle puissance (rapport nouvelle / ancienne, pour garder les modificateurs).
//   - normal : écart 0 ;
//   - difficile : écart 2, vie et dégâts × 1,25, une technique, éclats × 2 ;
//   - cauchemar (hors des zones de repos) : écart 2, × 1,5, deux techniques plus fortes, éclats × 3, rares + 50 % de
//     vie ; toutes les 4 à 6 minutes, un événement (pluie de feu ou rare de la zone près du joueur) ; écran rougeâtre.
//   Simulation (fiche à puissance 9,7, niveau d'objet 7,5) : difficile, 49 % de victoires au rang 3 avec la potion de
//   départ et 100 % avec F7 ; cauchemar, 2 % au rang 3, 63 % au rang 4 et 98 % au rang 5 avec F7.
// - Techniques (reprises des affixes de donjon de la v2, affixes_mecanique.cpp) :
//   - Enragé : sous 30 % de vie, +50 % de dégâts (+75 % en cauchemar) ;
//   - Renforçant : à sa mort, les monstres à 30 m gagnent +20 % de dégâts et de vie (+30 % en cauchemar), 5 fois au plus
//     (aura 59449) ;
//   - Volcanique : en combat, toutes les 10 s (8 en cauchemar), une pluie de feu sous le joueur ; 2 s plus tard la
//     fissure (900101) explose et retire 15 % de la vie à qui est resté dedans (dégâts réglés par affixes_mecanique.cpp).
// - Interface (SolUI_Zone.lua, préfixe SOLMODE) : « MODE;zone;mode;débloqué;au repos;cauchemar actif;modes ouverts »
//   (0 à 2) au changement et toutes les 10 s. Les éclats suivent le mode (SolAzeroth::FacteurEclatsMode, v3_collection.cpp).
// - Donjons (01/11/2026, réputation des donjons, v3_donjons.cpp) : en difficulté 2 à 5, tous les monstres hostiles du
//   donjon, boss compris, passent de même à la puissance de base du joueur + écart, vie et dégâts × facteur, éclats ×
//   1,5 à × 3, avec les techniques tirées pour le donjon. Technique de plus, Explosif : en combat, toutes les 12 s, une
//   sphère instable (900100) à 6 m du joueur, 5 % de sa vie ; non détruite en 6 s, elle retire 15 % de la vie à 30 m.
// - Passif Mauvais œil (v3_passifs.cpp) : en mode difficile ou cauchemar, une technique de moins (au moins une).

#include "SolAzeroth.h"
#include "CellImpl.h"
#include "Chat.h"
#include "CommandScript.h"
#include "Containers.h"
#include "Creature.h"
#include "DatabaseEnv.h"
#include "GridNotifiers.h"
#include "GridNotifiersImpl.h"
#include "Map.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "Random.h"
#include "ScriptMgr.h"
#include "SpellAuraEffects.h"
#include "SpellAuras.h"
#include "SpellInfo.h"
#include "StringFormat.h"
#include "TemporarySummon.h"
#include <algorithm>
#include <cmath>
#include <unordered_map>
#include <vector>

using namespace Acore::ChatCommands;

namespace
{
    enum Mode : uint8 { AUCUN = 0, NORMAL = 1, DIFFICILE = 2, CAUCHEMAR = 3 };
    char const* const NOMS[] = { "aucun", "normal", "difficile", "cauchemar" };

    struct Regle
    {
        uint8 ecart;
        float facteur;      // vie et dégâts
        uint8 techniques;   // nombre tiré au sort
        float eclats;
        float technique;    // force des techniques : 1 en difficile, 1,5 en cauchemar
    };
    // Indexées par Mode, puis 4 à 8 : difficultés de donjon 1 à 5 (outils\passifs_v3.py).
    Regle const REGLES[] = { { 0, 1.0f, 0, 1.0f, 1.0f }, { 0, 1.0f, 0, 1.0f, 1.0f }, { 2, 1.25f, 1, 2.0f, 1.0f },
                             { 2, 1.5f, 2, 3.0f, 1.5f }, { 0, 1.0f, 0, 1.0f, 1.0f }, { 0, 1.1f, 1, 1.5f, 1.0f },
                             { 0, 1.25f, 2, 2.0f, 1.0f }, { 1, 1.3f, 2, 2.5f, 1.0f }, { 1, 1.4f, 3, 3.0f, 1.0f } };
    uint8 const DONJON = 3;   // règle d'une difficulté : DONJON + difficulté

    uint32 const SEUIL = 6000;                 // 60 %, en centièmes
    uint32 const TICK = 1000, RENVOI = 10;
    float const VIE_RARE_CAUCHEMAR = 1.5f;

    enum Technique : uint8 { ENRAGE = 1, RENFORCANT = 2, VOLCANIQUE = 4, EXPLOSIF = 8 };
    float const ENRAGE_SEUIL = 30.0f, ENRAGE_DEGATS = 0.5f;
    float const RENFORT_PAR_CUMUL = 0.2f, RENFORT_PORTEE = 30.0f;
    uint8 const RENFORT_MAX = 5;
    uint32 const FISSURE = 900101, SORT_PLUIE_DE_FEU = 43440, SORT_NOVA_DE_FEU = 12470, SORT_RENFORT = 59449;
    // Explosif (repris de affixes_mecanique.cpp, que la v3 ne charge pas).
    uint32 const SPHERE = 900100, SORT_PROJECTILES = 15791, SORT_ASPECT_SPHERE = 50756;
    uint32 const SPHERE_INTERVALLE = 12000;
    float const SPHERE_VIE = 0.05f, SPHERE_DEGATS = 0.15f;

    // Événements du cauchemar : toutes les 4 à 6 minutes, hors combat ou non.
    uint32 const EVENEMENT_MIN = 4 * MINUTE * IN_MILLISECONDS, EVENEMENT_MAX = 6 * MINUTE * IN_MILLISECONDS;
    uint32 const RARE_DUREE = 5 * MINUTE * IN_MILLISECONDS;

    struct Modes : DataMap::Base
    {
        std::unordered_map<uint32, uint8> zones;
        uint32 attente = 0, renvoi = 0;
        int32 evenement = -1;   // ms avant le prochain événement du cauchemar ; -1 : à tirer
        uint32 sphere = 0;      // ms de combat depuis la dernière sphère d'Explosif
        std::string envoye;
    };

    struct EtatMonstre : DataMap::Base
    {
        bool traite = false;
        uint8 mode = AUCUN;
        uint8 techniques = 0;
        bool enrage = false;
        bool rare = false;   // rare appelé par un événement du cauchemar : il donne ses éclats malgré l'appel
    };

    // Rares de chaque zone (rang rare ou rare élite parmi ses créatures), pour l'événement du cauchemar. Lot T6 des
    // Tarides (point 8.5 du comparatif) : sans les rares secrets (solazeroth_v3_rares_secrets), à Durotar aussi.
    std::unordered_map<uint32, std::vector<uint32>> raresDesZones;

    Modes* ModesDe(Player* player) { return player->CustomData.GetDefault<Modes>("solazeroth_v3_modes"); }
    EtatMonstre* EtatDe(Creature* creature) { return creature->CustomData.GetDefault<EtatMonstre>("solazeroth_v3_mode"); }

    bool AuRepos(Player* player)
    {
        return player->HasRestFlag(REST_FLAG_IN_TAVERN) || player->HasRestFlag(REST_FLAG_IN_CITY);
    }

    uint8 ModeChoisi(Player* player, uint32 zone)
    {
        Modes* m = ModesDe(player);
        auto it = m->zones.find(zone);
        return it == m->zones.end() ? AUCUN : it->second;
    }

    // Mode en vigueur là où est le joueur : celui de la zone, débloqué ; le cauchemar s'arrête dans les zones de repos.
    uint8 ModeActif(Player* player)
    {
        uint32 zone = player->GetZoneId();
        uint8 mode = ModeChoisi(player, zone);
        if (mode == AUCUN || SolAzeroth::PourcentZone(player, zone) < SEUIL || player->GetMap()->Instanceable())
            return AUCUN;
        if (mode > NORMAL && SolAzeroth::ModesOuverts(player) < mode - NORMAL)
            return AUCUN;
        if (mode == CAUCHEMAR && AuRepos(player))
            return AUCUN;
        return mode;
    }

    Player* JoueurDe(Unit* unite)
    {
        return unite ? unite->GetCharmerOrOwnerPlayerOrPlayerItself() : nullptr;
    }

    // Monstre que les modes touchent : hostile, ni familier, ni boss, ni bestiole, ni PNJ de service, ni fissure.
    bool Concerne(Creature* creature)
    {
        CreatureTemplate const* modele = creature->GetCreatureTemplate();
        return !creature->GetCharmerOrOwnerPlayerOrPlayerItself() && !creature->IsDungeonBoss() && !creature->isWorldBoss()
            && modele->type != CREATURE_TYPE_CRITTER && !modele->npcflag && creature->GetEntry() != FISSURE
            && !creature->GetMap()->Instanceable();
    }

    // Monstre de donjon que les difficultés touchent : hostile, boss compris.
    bool ConcerneDonjon(Creature* creature)
    {
        CreatureTemplate const* modele = creature->GetCreatureTemplate();
        return !creature->GetCharmerOrOwnerPlayerOrPlayerItself() && modele->type != CREATURE_TYPE_CRITTER && !modele->npcflag
            && creature->GetEntry() != FISSURE && creature->GetEntry() != SPHERE && creature->GetMap()->IsNonRaidDungeon()
            && creature->IsHostileToPlayers();
    }

    float ForceTechnique(Creature* creature)
    {
        return REGLES[EtatDe(creature)->mode].technique;
    }

    // Statistiques à une autre puissance : rapport des statistiques de base du moteur (nouvelle / ancienne).
    void ChangerPuissance(Creature* creature, uint8 ancienne, uint8 nouvelle, float facteurVie)
    {
        CreatureTemplate const* modele = creature->GetCreatureTemplate();
        CreatureBaseStats const* avant = sObjectMgr->GetCreatureBaseStats(ancienne, modele->unit_class);
        CreatureBaseStats const* apres = sObjectMgr->GetCreatureBaseStats(nouvelle, modele->unit_class);
        float pourcent = creature->GetHealthPct();
        float vie = creature->GetCreateHealth() * facteurVie;
        if (nouvelle != ancienne)
        {
            vie *= float(apres->GenerateHealth(modele)) / std::max<uint32>(1, avant->GenerateHealth(modele));
            float degats = apres->GenerateBaseDamage(modele) / std::max(0.01f, avant->GenerateBaseDamage(modele));
            for (WeaponAttackType type : { BASE_ATTACK, OFF_ATTACK, RANGED_ATTACK })
                for (WeaponDamageRange borne : { MINDAMAGE, MAXDAMAGE })
                    creature->SetBaseWeaponDamage(type, borne, creature->GetWeaponDamageRange(type, borne) * degats);
            creature->SetStatFlatModifier(UNIT_MOD_ATTACK_POWER, BASE_VALUE, apres->AttackPower);
            creature->SetStatFlatModifier(UNIT_MOD_ATTACK_POWER_RANGED, BASE_VALUE, apres->RangedAttackPower);
            creature->SetStatFlatModifier(UNIT_MOD_ARMOR, BASE_VALUE, apres->GenerateArmor(modele));
            SolAzeroth::FixerPuissanceCreature(creature, nouvelle);
        }
        uint32 total = std::max<uint32>(1, uint32(vie));
        creature->SetCreateHealth(total);
        creature->SetStatFlatModifier(UNIT_MOD_HEALTH, BASE_VALUE, float(total));
        creature->UpdateAllStats();
        creature->SetHealth(std::max<uint32>(1, uint32(creature->GetMaxHealth() * pourcent / 100.0f)));
    }

    void Volcan(Creature* creature);

    // Pluie de feu sous le joueur, puis l'explosion 2 s plus tard (dégâts réglés par affixes_mecanique.cpp).
    void Eruption(Player* player)
    {
        TempSummon* fissure = player->GetMap()->SummonCreature(FISSURE, player->GetPosition(), nullptr, 4000);
        if (!fissure)
            return;
        fissure->SetFaction(14);
        fissure->SetLevel(player->GetLevel());
        fissure->RemoveUnitFlag(UNIT_FLAG_IMMUNE_TO_PC | UNIT_FLAG_IMMUNE_TO_NPC);
        fissure->CastSpell(player->GetPositionX(), player->GetPositionY(), player->GetPositionZ(), SORT_PLUIE_DE_FEU, true);
        fissure->m_Events.AddEventAtOffset([fissure]() { fissure->CastSpell(fissure, SORT_NOVA_DE_FEU, true); }, 2s);
    }

    // Technique Volcanique : tant que le monstre se bat contre un joueur, une éruption sur sa cible à intervalle fixe.
    void Volcan(Creature* creature)
    {
        Milliseconds intervalle = EtatDe(creature)->mode == CAUCHEMAR ? 8s : 10s;
        creature->m_Events.AddEventAtOffset([creature]()
        {
            if (!creature->IsAlive() || !creature->IsInCombat() || !EtatDe(creature)->traite)
                return;
            if (Player* cible = JoueurDe(creature->GetVictim()); cible && cible->IsAlive())
                Eruption(cible);
            Volcan(creature);
        }, intervalle);
    }

    void Rehausser(Creature* creature, Player* player)
    {
        EtatMonstre* etat = EtatDe(creature);
        if (etat->traite)
            return;
        etat->traite = true;
        uint8 mode = AUCUN;
        if (ConcerneDonjon(creature))
        {
            // Lot 4a : en difficulté 1, l'affixe de la semaine seulement (v3_semaine.cpp), sans changer la puissance.
            uint8 difficulte = SolAzeroth::DifficulteDonjon(creature->GetMap());
            if (difficulte >= 2 || (difficulte == 1 && SolAzeroth::TechniquesDonjon(creature->GetMap())))
                mode = DONJON + difficulte;
        }
        else if (Concerne(creature) && creature->GetZoneId() == player->GetZoneId())
            mode = ModeActif(player);
        if (mode == AUCUN)
            return;
        Regle const& regle = REGLES[mode];
        etat->mode = mode;
        uint8 ancienne = SolAzeroth::PuissanceCreature(creature);
        uint8 visee = uint8(std::clamp<int32>(int32(std::floor(SolAzeroth::PuissanceDeBaseMax(player))) + regle.ecart, 1, 79));
        float facteurVie = regle.facteur;
        uint32 rang = creature->GetCreatureTemplate()->rank;
        if (mode == CAUCHEMAR && (rang == CREATURE_ELITE_RARE || rang == CREATURE_ELITE_RAREELITE))
            facteurVie *= VIE_RARE_CAUCHEMAR;
        if (mode != DONJON + 1)
            ChangerPuissance(creature, ancienne, std::max(ancienne, visee), facteurVie);

        if (mode > DONJON)
            etat->techniques = SolAzeroth::TechniquesDonjon(creature->GetMap());
        else
        {
            std::vector<uint8> techniques = { ENRAGE, RENFORCANT, VOLCANIQUE };
            Acore::Containers::RandomShuffle(techniques);
            uint8 nombre = regle.techniques;
            if (nombre > 1 && SolAzeroth::PassifActif(player, SolAzeroth::MAUVAIS_OEIL))
                --nombre;
            for (uint8 i = 0; i < nombre && i < techniques.size(); ++i)
                etat->techniques |= techniques[i];
        }
        if (etat->techniques & VOLCANIQUE)
            Volcan(creature);
    }

    void EnvoyerEtat(Player* player, bool force)
    {
        Modes* m = ModesDe(player);
        uint32 zone = player->GetZoneId();
        std::string message = Acore::StringFormat("MODE;{};{};{};{};{};{}", zone, uint32(ModeChoisi(player, zone)),
            SolAzeroth::PourcentZone(player, zone) >= SEUIL ? 1 : 0, AuRepos(player) ? 1 : 0,
            ModeActif(player) == CAUCHEMAR ? 1 : 0, uint32(SolAzeroth::ModesOuverts(player)));
        if (!force && message == m->envoye)
            return;
        m->envoye = message;
        SolAzeroth::EnvoyerAddon(player, "SOLMODE", message);
    }

    // Événement du cauchemar : un rare de la zone près du joueur, ou une pluie de feu (trois éruptions).
    void Evenement(Player* player)
    {
        auto rares = raresDesZones.find(player->GetZoneId());
        if (rares != raresDesZones.end() && !rares->second.empty() && urand(0, 1))
        {
            uint32 entree = Acore::Containers::SelectRandomContainerElement(rares->second);
            Position position = player->GetFirstCollisionPosition(20.0f, frand(0.0f, 2 * float(M_PI)));
            if (TempSummon* rare = player->SummonCreature(entree, position, TEMPSUMMON_TIMED_DESPAWN_OUT_OF_COMBAT,
                RARE_DUREE))
            {
                EtatDe(rare)->rare = true;
                rare->SetFacingToObject(player);
                SolAzeroth::EnvoyerAddon(player, "SOLZONE", "ALERTE;Cauchemar : " + rare->GetName() + " rôde tout près.");
                return;
            }
        }
        SolAzeroth::EnvoyerAddon(player, "SOLZONE", "ALERTE;Cauchemar : une pluie de feu s'abat !");
        for (uint32 i = 0; i < 3; ++i)
            player->m_Events.AddEventAtOffset([player]()
            {
                if (player->IsAlive() && ModeActif(player) == CAUCHEMAR)
                    Eruption(player);
            }, Milliseconds(i * 3000));
    }

    // Explosif : la sphère apparaît à 6 m du joueur ; non détruite en 6 s, elle explose sur les joueurs à 30 m.
    void Sphere(Player* player)
    {
        Position position = player->GetFirstCollisionPosition(6.0f, frand(0.0f, 2 * float(M_PI)));
        position.m_positionZ += 1.5f;
        TempSummon* orbe = player->GetMap()->SummonCreature(SPHERE, position, nullptr, 9000);
        if (!orbe)
            return;
        uint32 vie = std::max<uint32>(1, uint32(player->GetMaxHealth() * SPHERE_VIE));
        orbe->SetLevel(player->GetLevel());
        orbe->SetMaxHealth(vie);
        orbe->SetHealth(vie);
        orbe->SetReactState(REACT_PASSIVE);
        orbe->SetControlled(true, UNIT_STATE_ROOT);
        orbe->SetDisableGravity(true);
        orbe->CastSpell(orbe, SORT_ASPECT_SPHERE, true);
        orbe->TextEmote("apparaît ! Détruis-la avant qu'elle n'explose.", player, true);
        orbe->m_Events.AddEventAtOffset([orbe]()
        {
            if (!orbe->IsAlive())
                return;
            for (auto const& ref : orbe->GetMap()->GetPlayers())
                if (Player* cible = ref.GetSource(); cible && cible->IsAlive() && cible->IsWithinDistInMap(orbe, 30.0f))
                    orbe->CastSpell(cible, SORT_PROJECTILES, true);
            orbe->DespawnOrUnsummon(1500ms);
        }, 6s);
    }

    // Le joueur se bat contre un monstre de donjon qui a la technique Explosif.
    bool CombatExplosif(Player* player)
    {
        if (!player->IsInCombat() || !player->IsAlive() || player->IsGameMaster())
            return false;
        for (Unit* attaquant : player->getAttackers())
            if (Creature* c = attaquant->ToCreature())
                if (EtatMonstre* etat = c->CustomData.Get<EtatMonstre>("solazeroth_v3_mode"); etat && etat->mode > DONJON
                    && (etat->techniques & EXPLOSIF))
                    return true;
        return false;
    }

    void ChargerRares()
    {
        raresDesZones.clear();
        if (QueryResult resultat = WorldDatabase.Query("SELECT DISTINCT c.zoneId, t.entry FROM creature c JOIN creature_template "
            "t ON t.entry = c.id WHERE c.zoneId <> 0 AND t.`rank` IN (2, 4) AND t.npcflag = 0 AND t.entry NOT IN "
            "(SELECT creature FROM solazeroth_v3_rares_secrets)"))
        {
            do
            {
                Field* champs = resultat->Fetch();
                raresDesZones[champs[0].Get<uint32>()].push_back(champs[1].Get<uint32>());
            } while (resultat->NextRow());
        }
    }
}

float SolAzeroth::FacteurEclatsMode(Creature* creature)
{
    EtatMonstre const* etat = creature ? creature->CustomData.Get<EtatMonstre>("solazeroth_v3_mode") : nullptr;
    return etat ? REGLES[etat->mode].eclats : 1.0f;
}

bool SolAzeroth::RareDeCauchemar(Creature* creature)
{
    EtatMonstre const* etat = creature ? creature->CustomData.Get<EtatMonstre>("solazeroth_v3_mode") : nullptr;
    return etat && etat->rare;
}

unsigned char SolAzeroth::ModeMonstre(Creature* creature)
{
    EtatMonstre const* etat = creature ? creature->CustomData.Get<EtatMonstre>("solazeroth_v3_mode") : nullptr;
    return etat && (etat->mode == DIFFICILE || etat->mode == CAUCHEMAR) ? etat->mode : 0;
}

unsigned char SolAzeroth::TechniquesMonstre(Creature* creature)
{
    EtatMonstre const* etat = creature ? creature->CustomData.Get<EtatMonstre>("solazeroth_v3_mode") : nullptr;
    return etat ? etat->techniques : 0;
}

float SolAzeroth::ForceTechniques(Creature* creature)
{
    EtatMonstre const* etat = creature ? creature->CustomData.Get<EtatMonstre>("solazeroth_v3_mode") : nullptr;
    return etat ? REGLES[etat->mode].technique : 1.0f;
}

class solazeroth_v3_modes_unites : public UnitScript
{
public:
    solazeroth_v3_modes_unites() : UnitScript("solazeroth_v3_modes_unites", true, {
        UNITHOOK_ON_UNIT_ENTER_COMBAT, UNITHOOK_MODIFY_MELEE_DAMAGE, UNITHOOK_MODIFY_SPELL_DAMAGE_TAKEN,
        UNITHOOK_MODIFY_PERIODIC_DAMAGE_AURAS_TICK, UNITHOOK_ON_UNIT_DEATH }) { }

    void OnUnitEnterCombat(Unit* unite, Unit* cible) override
    {
        Creature* creature = unite ? unite->ToCreature() : nullptr;
        if (Player* player = JoueurDe(cible); creature && player)
            Rehausser(creature, player);
    }

    template <typename T>
    static void Appliquer(Unit* cible, Unit* attaquant, T& degats)
    {
        if (!cible || !attaquant || cible == attaquant || attaquant->GetEntry() == SPHERE)
            return;
        // Monstre d'un mode qui frappe un joueur ou son familier : dégâts du mode et Enragé.
        if (Creature* monstre = attaquant->ToCreature(); monstre && JoueurDe(cible))
        {
            EtatMonstre* etat = monstre->CustomData.Get<EtatMonstre>("solazeroth_v3_mode");
            if (!etat || etat->mode == AUCUN)
                return;
            float facteur = REGLES[etat->mode].facteur;
            if ((etat->techniques & ENRAGE) && monstre->HealthBelowPct(int32(ENRAGE_SEUIL)))
            {
                facteur *= 1.0f + ENRAGE_DEGATS * ForceTechnique(monstre);
                if (!etat->enrage)
                {
                    etat->enrage = true;
                    monstre->TextEmote("devient enragé !");
                }
            }
            degats = T(degats * facteur);
        }
        // Joueur qui frappe un monstre renforcé : il tient plus longtemps (la vie du renfort).
        else if (Creature* renforce = cible->ToCreature(); renforce && JoueurDe(attaquant))
        {
            EtatMonstre* etat = renforce->CustomData.Get<EtatMonstre>("solazeroth_v3_mode");
            Aura const* aura = etat && etat->mode != AUCUN ? renforce->GetAura(SORT_RENFORT) : nullptr;
            if (aura)
                degats = T(degats / (1.0f + RENFORT_PAR_CUMUL * ForceTechnique(renforce) * aura->GetStackAmount()));
        }
    }

    void ModifyMeleeDamage(Unit* cible, Unit* attaquant, uint32& degats) override { Appliquer(cible, attaquant, degats); }

    void ModifySpellDamageTaken(Unit* cible, Unit* attaquant, int32& degats, SpellInfo const* sort) override
    {
        // Explosion de la sphère d'Explosif : part de la vie maximale.
        if (attaquant && attaquant->GetEntry() == SPHERE && sort && sort->Id == SORT_PROJECTILES && cible && cible->IsPlayer())
        {
            degats = int32(cible->GetMaxHealth() * SPHERE_DEGATS);
            return;
        }
        Appliquer(cible, attaquant, degats);
    }

    void ModifyPeriodicDamageAurasTick(Unit* cible, Unit* attaquant, uint32& degats, SpellInfo const* /*sort*/) override
    {
        Appliquer(cible, attaquant, degats);
    }

    // Renforçant : les monstres du même mode à 30 m prennent un cumul de renfort.
    void OnUnitDeath(Unit* unite, Unit* /*tueur*/) override
    {
        Creature* mort = unite ? unite->ToCreature() : nullptr;
        EtatMonstre* etat = mort ? mort->CustomData.Get<EtatMonstre>("solazeroth_v3_mode") : nullptr;
        if (!etat || !(etat->techniques & RENFORCANT))
            return;
        float force = REGLES[etat->mode].technique;
        Acore::AnyUnitInObjectRangeCheck verification(mort, RENFORT_PORTEE);
        std::list<Unit*> unites;
        Acore::UnitListSearcher<Acore::AnyUnitInObjectRangeCheck> chercheur(mort, unites, verification);
        Cell::VisitObjects(mort, chercheur, RENFORT_PORTEE);
        for (Unit* voisin : unites)
        {
            Creature* creature = voisin->ToCreature();
            if (!creature || creature == mort || !creature->IsAlive() || !(Concerne(creature) || ConcerneDonjon(creature))
                || !creature->IsHostileToPlayers())
                continue;
            Aura* aura = creature->GetAura(SORT_RENFORT);
            if (aura && aura->GetStackAmount() >= RENFORT_MAX)
                continue;
            if (aura)
                aura->ModStackAmount(1);
            else
                aura = creature->AddAura(SORT_RENFORT, creature);
            if (!aura)
                continue;
            if (AuraEffect* effet = aura->GetEffect(EFFECT_0))
                effet->ChangeAmount(int32(RENFORT_PAR_CUMUL * force * 100 * aura->GetStackAmount()));
            creature->SetObjectScale(creature->GetNativeObjectScale() * (1.0f + 0.1f * aura->GetStackAmount()));
            EtatDe(creature)->mode = std::max(EtatDe(creature)->mode, etat->mode);   // la vie du renfort compte
        }
    }
};

// Monstre réapparu : statistiques de son niveau d'origine (SelectLevel), on oublie le mode.
class solazeroth_v3_modes_creatures : public AllCreatureScript
{
public:
    solazeroth_v3_modes_creatures() : AllCreatureScript("solazeroth_v3_modes_creatures") { }

    void OnCreatureSelectLevel(CreatureTemplate const* /*cinfo*/, Creature* creature) override
    {
        if (EtatMonstre* etat = creature->CustomData.Get<EtatMonstre>("solazeroth_v3_mode"))
            *etat = EtatMonstre();
    }
};

class solazeroth_v3_modes_joueurs : public PlayerScript
{
public:
    solazeroth_v3_modes_joueurs() : PlayerScript("solazeroth_v3_modes_joueurs",
        { PLAYERHOOK_ON_LOGIN, PLAYERHOOK_ON_UPDATE, PLAYERHOOK_ON_DELETE }) { }

    void OnPlayerLogin(Player* player) override
    {
        Modes* m = ModesDe(player);
        m->zones.clear();
        if (QueryResult resultat = CharacterDatabase.Query("SELECT zone, mode FROM solazeroth_v3_modes WHERE guid = {}",
            player->GetGUID().GetCounter()))
        {
            do
            {
                Field* champs = resultat->Fetch();
                m->zones[champs[0].Get<uint32>()] = champs[1].Get<uint8>();
            } while (resultat->NextRow());
        }
        EnvoyerEtat(player, true);
    }

    void OnPlayerUpdate(Player* player, uint32 diff) override
    {
        Modes* m = ModesDe(player);
        m->attente += diff;
        if (m->attente < TICK)
            return;
        uint32 ecoule = m->attente;
        m->attente = 0;
        bool force = ++m->renvoi >= RENVOI;
        if (force)
            m->renvoi = 0;
        EnvoyerEtat(player, force);

        if (CombatExplosif(player))
        {
            if ((m->sphere += ecoule) >= SPHERE_INTERVALLE)
            {
                m->sphere = 0;
                Sphere(player);
            }
        }
        else
            m->sphere = 0;

        if (ModeActif(player) != CAUCHEMAR || !player->IsAlive() || player->IsGameMaster())
        {
            m->evenement = -1;
            return;
        }
        if (m->evenement < 0)
            m->evenement = int32(urand(EVENEMENT_MIN, EVENEMENT_MAX));
        m->evenement -= int32(ecoule);
        if (m->evenement <= 0)
        {
            m->evenement = -1;
            Evenement(player);
        }
    }

    void OnPlayerDelete(ObjectGuid guid, uint32 /*compte*/) override
    {
        CharacterDatabase.Execute("DELETE FROM solazeroth_v3_modes WHERE guid = {}", guid.GetCounter());
    }
};

class solazeroth_v3_modes_monde : public WorldScript
{
public:
    solazeroth_v3_modes_monde() : WorldScript("solazeroth_v3_modes_monde", { WORLDHOOK_ON_STARTUP }) { }

    void OnStartup() override
    {
        ChargerRares();
    }
};

class solazeroth_v3_modes_commandes : public CommandScript
{
public:
    solazeroth_v3_modes_commandes() : CommandScript("solazeroth_v3_modes_commandes") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable commandes =
        {
            { "mode", HandleMode, SEC_PLAYER, Console::No },
        };
        return commandes;
    }

    // .mode : état ; .mode normal|difficile|cauchemar|aucun : choix pour la zone, dans une zone de repos, à 60 %.
    static bool HandleMode(ChatHandler* handler, Optional<std::string> nom)
    {
        Player* player = handler->GetSession()->GetPlayer();
        uint32 zone = player->GetZoneId();
        if (!nom)
        {
            handler->PSendSysMessage("Mode de la zone : {} (en vigueur : {}).", NOMS[ModeChoisi(player, zone)],
                NOMS[ModeActif(player)]);
            return true;
        }
        auto trouve = std::find_if(std::begin(NOMS), std::end(NOMS), [&](char const* n) { return *nom == n; });
        if (trouve == std::end(NOMS))
        {
            handler->SendErrorMessage("Modes : aucun, normal, difficile, cauchemar.");
            return false;
        }
        if (SolAzeroth::PourcentZone(player, zone) < SEUIL)
        {
            handler->SendErrorMessage("Les modes s'ouvrent à 60 % de la zone.");
            return false;
        }
        if (!AuRepos(player))
        {
            handler->SendErrorMessage("Le mode se choisit dans une zone de repos (auberge ou ville).");
            return false;
        }
        uint8 mode = uint8(trouve - std::begin(NOMS));
        if (mode > NORMAL && SolAzeroth::ModesOuverts(player) < mode - NORMAL)
        {
            handler->SendErrorMessage(mode == DIFFICILE ? "Le mode difficile s'ouvre au palier 5 du rang d'aventurier."
                : "Le mode cauchemar s'ouvre au palier 9 du rang d'aventurier.");
            return false;
        }
        ModesDe(player)->zones[zone] = mode;
        CharacterDatabase.Execute("REPLACE INTO solazeroth_v3_modes (guid, zone, mode) VALUES ({}, {}, {})",
            player->GetGUID().GetCounter(), zone, uint32(mode));
        handler->PSendSysMessage("Mode de la zone : {}.", NOMS[mode]);
        EnvoyerEtat(player, true);
        return true;
    }
};

void AddSC_solazeroth_v3_modes()
{
    new solazeroth_v3_modes_unites();
    new solazeroth_v3_modes_creatures();
    new solazeroth_v3_modes_joueurs();
    new solazeroth_v3_modes_monde();
    new solazeroth_v3_modes_commandes();
}
