// Affixes de mécanique à cocher (section 4.4, V5, décision de l'utilisateur du 29/10/2026 : affixes à points).
// Le joueur coche ses affixes dans la fenêtre du rang (/rang), pour le prochain donjon, comme le rang (menace.cpp).
// Chaque affixe vaut des points : palier de butin = rang + points, plafonné au rang maximal du donjon.
// Valeurs provisoires dans mod_solazeroth.conf (SolAzeroth.Mecanique.*) :
//   Enragé (1 pt)     : un monstre hors boss sous 30 % de vie fait +50 % de dégâts (émote « devient enragé ! »).
//   Renforçant (1 pt) : un monstre hors boss qui meurt renforce les monstres hors boss à 30 m : +20 % de dégâts et
//                       de PV par cumul (comme le rang : dégâts subis divisés), et ils grandissent de 10 %.
//                       Buff visible « Renforcement chancreux » (sort 59449, 5 cumuls au plus) : il porte les dégâts en
//                       plus et son nombre de cumuls sert aux PV.
//   Volcanique (2 pts): en combat, toutes les 10 s, une Pluie de feu (sort 43440) tombe sous les pieds d'un joueur ;
//                       elle ne sert que de signal : 2 s plus tard, la fissure explose (Nova de feu, sort 12470) et retire
//                       15 % de ses PV max à qui est resté à 5 m.
//   Explosif (2 pts)  : en combat, toutes les 12 s, une Sphère instable (900100, migration 038) apparaît près d'un
//                       joueur. Non détruite en 6 s, elle explose : 15 % des PV max de chaque joueur à 30 m.
//                       Elle a 5 % des PV max du joueur ; mod-autobalance l'ignore, sinon il lui imposerait les PV de son
//                       modèle (niveau 80).
// « En combat » = attaqué par un vrai monstre : la sphère ne compte pas, sinon elle en appellerait d'autres.

#include "SolAzeroth.h"
#include "ABCreatureInfo.h"
#include "CellImpl.h"
#include "Config.h"
#include "Containers.h"
#include "Creature.h"
#include "GridNotifiers.h"
#include "GridNotifiersImpl.h"
#include "Map.h"
#include "Player.h"
#include "Random.h"
#include "ScriptMgr.h"
#include "SpellAuraEffects.h"
#include "SpellAuras.h"
#include "SpellInfo.h"
#include "StringFormat.h"
#include "TemporarySummon.h"
#include <mutex>
#include <unordered_map>
#include <unordered_set>
#include <vector>

namespace
{
    enum Affixe : uint8 { ENRAGE = 1, RENFORCANT = 2, VOLCANIQUE = 4, EXPLOSIF = 8 };

    uint32 const SPHERE = 900100, FISSURE = 900101;
    uint32 const SORT_PLUIE_DE_FEU = 43440, SORT_PROJECTILES = 15791;
    uint32 const SORT_NOVA_DE_FEU = 12470;      // impact de l'affixe Volcanique (explosion de feu autour de la fissure)
    float const RAYON_VOLCAN = 5.0f;            // rayon de la Pluie de feu 43440
    uint32 const SORT_RENFORT = 59449;          // « Renforcement chancreux » : dégâts infligés +X % par cumul, 5 cumuls
    uint32 const SORT_ASPECT_SPHERE = 50756;   // aura sans effet qui donne son apparence à la sphère (sans elle, invisible)

    struct Reglages
    {
        bool active = true;
        uint32 points[4] = { 1, 1, 2, 2 };
        float enrageSeuil = 30.0f, enrageDegats = 0.50f;
        float renfortParCumul = 0.20f, renfortPortee = 30.0f;
        uint32 volcanIntervalle = 10000;
        float volcanDegats = 0.15f;
        uint32 sphereIntervalle = 12000, sphereDelai = 6000;
        float spherePv = 0.05f, sphereDegats = 0.15f;
    } reglages;

    struct Orbe
    {
        ObjectGuid guid;
        int32 restant;
    };

    struct Eruption
    {
        ObjectGuid fissure;
        int32 restant;
    };

    struct EtatCombat
    {
        uint32 volcan = 0, sphere = 0;
        std::vector<Orbe> orbes;
        std::vector<Eruption> eruptions;
    };

    std::mutex verrou;
    std::unordered_map<uint32, EtatCombat> combats;          // clé : instance
    std::unordered_set<ObjectGuid> enrages;                  // monstres qui ont déjà annoncé leur rage

    struct Definition
    {
        Affixe bit;
        char const* nom;
    };
    Definition const AFFIXES[] = { { ENRAGE, "Enragé" }, { RENFORCANT, "Renforçant" }, { VOLCANIQUE, "Volcanique" }, { EXPLOSIF, "Explosif" } };

    std::string Description(Affixe bit)
    {
        switch (bit)
        {
            case ENRAGE:     return Acore::StringFormat("Les monstres (hors boss) sous {:.0f} % de vie font +{:.0f} % de dégâts.",
                                 reglages.enrageSeuil, reglages.enrageDegats * 100);
            case RENFORCANT: return Acore::StringFormat("Un monstre (hors boss) qui meurt donne aux monstres à {:.0f} m +{:.0f} % de dégâts et de PV, cumulables 5 fois (buff « Renforcement chancreux »).",
                                 reglages.renfortPortee, reglages.renfortParCumul * 100);
            case VOLCANIQUE: return Acore::StringFormat("En combat, toutes les {} s, une pluie de feu tombe sous tes pieds : sors-en en 2 s ou perds {:.0f} % de tes PV.",
                                 reglages.volcanIntervalle / 1000, reglages.volcanDegats * 100);
            case EXPLOSIF:   return Acore::StringFormat("En combat, toutes les {} s, une sphère apparaît : détruis-la en {} s ou elle explose ({:.0f} % de tes PV).",
                                 reglages.sphereIntervalle / 1000, reglages.sphereDelai / 1000, reglages.sphereDegats * 100);
        }
        return "";
    }

    bool EstDonjon(Map const* map)
    {
        return map && map->IsDungeon() && !map->IsRaid();
    }

    uint8 AffixesDe(Map const* map)
    {
        return reglages.active && EstDonjon(map) ? SolAzeroth::AffixesInstance(map->GetInstanceId()) : 0;
    }

    // Monstre ordinaire de l'instance : ni du côté du joueur, ni boss, ni créature d'affixe.
    Creature* MonstreOrdinaire(Unit* unite)
    {
        Creature* creature = unite ? unite->ToCreature() : nullptr;
        if (!creature || creature->GetCharmerOrOwnerPlayerOrPlayerItself() || creature->IsDungeonBoss() || creature->isWorldBoss()
            || creature->GetEntry() == SPHERE || creature->GetEntry() == FISSURE)
            return nullptr;
        return creature;
    }

    uint8 Renforts(Creature const* creature)
    {
        Aura const* aura = creature->GetAura(SORT_RENFORT);
        return aura ? aura->GetStackAmount() : 0;
    }

    // Joueur attaqué par un vrai monstre (pas par une créature d'affixe).
    bool EnCombat(Player* player)
    {
        if (!player->IsAlive() || !player->IsInCombat() || player->IsGameMaster())
            return false;
        for (Unit* attaquant : player->getAttackers())
            if (Creature* c = attaquant->ToCreature(); c && c->GetEntry() != SPHERE && c->GetEntry() != FISSURE
                && !c->GetCharmerOrOwnerPlayerOrPlayerItself())
                return true;
        return false;
    }

    void Exploser(Creature* sphere)
    {
        for (auto const& ref : sphere->GetMap()->GetPlayers())
            if (Player* player = ref.GetSource(); player && player->IsAlive() && player->IsWithinDistInMap(sphere, 30.0f))
                sphere->CastSpell(player, SORT_PROJECTILES, true);
        sphere->DespawnOrUnsummon(1500ms);
    }
}

unsigned int SolAzeroth::PointsAffixes(unsigned char affixes)
{
    uint32 total = 0;
    for (uint8 i = 0; i < 4; ++i)
        if (affixes & (1 << i))
            total += reglages.points[i];
    return total;
}

std::vector<std::string> SolAzeroth::ListeAffixesMecanique()
{
    std::vector<std::string> lignes;
    for (Definition const& d : AFFIXES)
        lignes.push_back(Acore::StringFormat("{};{};{};{}", uint32(d.bit), d.nom, PointsAffixes(d.bit), Description(d.bit)));
    return lignes;
}

std::string SolAzeroth::NomsAffixesMecanique(unsigned char affixes)
{
    std::string noms;
    for (Definition const& d : AFFIXES)
        if (affixes & d.bit)
            noms += (noms.empty() ? "" : ", ") + std::string(d.nom);
    return noms.empty() ? "aucun" : noms;
}

class solazeroth_mecanique_unites : public UnitScript
{
public:
    solazeroth_mecanique_unites() : UnitScript("solazeroth_mecanique_unites", true, {
        UNITHOOK_MODIFY_MELEE_DAMAGE, UNITHOOK_MODIFY_SPELL_DAMAGE_TAKEN, UNITHOOK_MODIFY_PERIODIC_DAMAGE_AURAS_TICK,
        UNITHOOK_ON_UNIT_DEATH }) { }

    template <typename T>
    static void Appliquer(Unit* cible, Unit* attaquant, T& degats)
    {
        if (!cible || !attaquant || cible == attaquant)
            return;
        uint8 affixes = AffixesDe(cible->GetMap());
        if (!affixes)
            return;
        // Monstre qui frappe un joueur ou son familier.
        if (cible->GetCharmerOrOwnerPlayerOrPlayerItself())
        {
            Creature* monstre = MonstreOrdinaire(attaquant);
            if (!monstre)
                return;
            float facteur = 1.0f;
            if ((affixes & ENRAGE) && monstre->HealthBelowPct(int32(reglages.enrageSeuil)))
            {
                facteur += reglages.enrageDegats;
                bool annoncer;
                {
                    std::lock_guard<std::mutex> garde(verrou);
                    annoncer = enrages.insert(monstre->GetGUID()).second;
                }
                if (annoncer)
                    monstre->TextEmote("devient enragé !");
            }
            if (facteur != 1.0f)
                degats = T(degats * facteur);
        }
        // Joueur qui frappe un monstre renforcé : il « tient » plus longtemps, comme avec le rang.
        else if ((affixes & RENFORCANT) && attaquant->GetCharmerOrOwnerPlayerOrPlayerItself())
        {
            if (Creature* monstre = MonstreOrdinaire(cible))
                if (uint8 cumuls = Renforts(monstre))
                    degats = T(degats / (1.0f + reglages.renfortParCumul * cumuls));
        }
    }

    void ModifyMeleeDamage(Unit* cible, Unit* attaquant, uint32& degats) override { Appliquer(cible, attaquant, degats); }

    void ModifySpellDamageTaken(Unit* cible, Unit* attaquant, int32& degats, SpellInfo const* sort) override
    {
        // Explosion de la Sphère instable : part des PV max.
        if (attaquant && attaquant->GetEntry() == SPHERE && sort && sort->Id == SORT_PROJECTILES && cible->IsPlayer())
        {
            degats = int32(cible->GetMaxHealth() * reglages.sphereDegats);
            return;
        }
        // Impact de l'affixe Volcanique : part des PV max, seulement si on est resté dans la pluie de feu.
        if (attaquant && attaquant->GetEntry() == FISSURE && sort && sort->Id == SORT_NOVA_DE_FEU)
        {
            degats = cible->GetCharmerOrOwnerPlayerOrPlayerItself() && cible->GetExactDist2d(attaquant) <= RAYON_VOLCAN
                ? int32(cible->GetMaxHealth() * reglages.volcanDegats) : 0;
            return;
        }
        Appliquer(cible, attaquant, degats);
    }

    void ModifyPeriodicDamageAurasTick(Unit* cible, Unit* attaquant, uint32& degats, SpellInfo const* sort) override
    {
        // Pluie de feu de l'affixe Volcanique : seulement le signal visuel, les dégâts viennent de la Nova de feu.
        if (attaquant && attaquant->GetEntry() == FISSURE && sort && sort->Id == SORT_PLUIE_DE_FEU)
        {
            degats = 0;
            return;
        }
        Appliquer(cible, attaquant, degats);
    }

    void OnUnitDeath(Unit* unite, Unit* /*tueur*/) override
    {
        Creature* mort = unite ? unite->ToCreature() : nullptr;
        if (!mort)
            return;
        {
            std::lock_guard<std::mutex> garde(verrou);
            enrages.erase(mort->GetGUID());
        }
        if (!(AffixesDe(mort->GetMap()) & RENFORCANT) || !MonstreOrdinaire(mort) || !mort->IsHostileToPlayers())
            return;

        std::list<Unit*> voisins;
        Acore::AnyUnitInObjectRangeCheck verification(mort, reglages.renfortPortee);
        Acore::UnitListSearcher<Acore::AnyUnitInObjectRangeCheck> chercheur(mort, voisins, verification);
        Cell::VisitObjects(mort, chercheur, reglages.renfortPortee);
        for (Unit* voisin : voisins)
        {
            Creature* creature = MonstreOrdinaire(voisin);
            if (!creature || creature == mort || !creature->IsAlive() || !creature->IsHostileToPlayers())
                continue;
            Aura* aura = creature->GetAura(SORT_RENFORT);
            if (aura)
                aura->ModStackAmount(1);
            else
                aura = creature->AddAura(SORT_RENFORT, creature);
            if (!aura)
                continue;
            if (AuraEffect* effet = aura->GetEffect(EFFECT_0))
                effet->ChangeAmount(int32(reglages.renfortParCumul * 100 * aura->GetStackAmount()));
            creature->SetObjectScale(creature->GetNativeObjectScale() * (1.0f + 0.1f * aura->GetStackAmount()));
        }
    }
};

class solazeroth_mecanique_cartes : public AllMapScript
{
public:
    solazeroth_mecanique_cartes() : AllMapScript("solazeroth_mecanique_cartes", { ALLMAPHOOK_ON_MAP_UPDATE }) { }

    void OnMapUpdate(Map* map, uint32 ecoule) override
    {
        uint8 affixes = AffixesDe(map);
        if (!(affixes & (VOLCANIQUE | EXPLOSIF)))
            return;

        std::vector<Player*> enCombat;
        for (auto const& ref : map->GetPlayers())
            if (Player* player = ref.GetSource(); player && EnCombat(player))
                enCombat.push_back(player);

        std::vector<Creature*> aExploser, impacts;
        Player* volcan = nullptr;
        Player* sphere = nullptr;
        {
            std::lock_guard<std::mutex> garde(verrou);
            EtatCombat& etat = combats[map->GetInstanceId()];
            for (auto it = etat.eruptions.begin(); it != etat.eruptions.end();)
            {
                it->restant -= int32(ecoule);
                if (it->restant > 0)
                {
                    ++it;
                    continue;
                }
                if (Creature* fissure = map->GetCreature(it->fissure))
                    impacts.push_back(fissure);
                it = etat.eruptions.erase(it);
            }
            for (auto it = etat.orbes.begin(); it != etat.orbes.end();)
            {
                Creature* orbe = map->GetCreature(it->guid);
                it->restant -= int32(ecoule);
                if (!orbe || !orbe->IsAlive())
                    it = etat.orbes.erase(it);
                else if (it->restant <= 0)
                {
                    aExploser.push_back(orbe);
                    it = etat.orbes.erase(it);
                }
                else
                    ++it;
            }
            if (enCombat.empty())
            {
                etat.volcan = etat.sphere = 0;   // le premier effet arrive un intervalle après le début du combat
            }
            else
            {
                if ((affixes & VOLCANIQUE) && (etat.volcan += ecoule) >= reglages.volcanIntervalle)
                {
                    etat.volcan = 0;
                    volcan = Acore::Containers::SelectRandomContainerElement(enCombat);
                }
                if ((affixes & EXPLOSIF) && (etat.sphere += ecoule) >= reglages.sphereIntervalle)
                {
                    etat.sphere = 0;
                    sphere = Acore::Containers::SelectRandomContainerElement(enCombat);
                }
            }
        }

        for (Creature* orbe : aExploser)
            Exploser(orbe);
        for (Creature* fissure : impacts)
            fissure->CastSpell(fissure, SORT_NOVA_DE_FEU, true);

        // La pluie de feu sert de signal ; 2 s plus tard, la fissure explose (Nova de feu) et touche qui est resté à 5 m.
        // Le déclencheur copié (23837) est immunisé contre les joueurs : on retire cette immunité, sinon rien ne les touche.
        if (volcan)
            if (TempSummon* fissure = map->SummonCreature(FISSURE, volcan->GetPosition(), nullptr, 4000))
            {
                fissure->SetFaction(14);
                fissure->SetLevel(volcan->GetLevel());
                fissure->RemoveUnitFlag(UNIT_FLAG_IMMUNE_TO_PC | UNIT_FLAG_IMMUNE_TO_NPC);
                fissure->CastSpell(volcan->GetPositionX(), volcan->GetPositionY(), volcan->GetPositionZ(), SORT_PLUIE_DE_FEU, true);
                std::lock_guard<std::mutex> garde(verrou);
                combats[map->GetInstanceId()].eruptions.push_back({ fissure->GetGUID(), 2000 });
            }

        if (sphere)
        {
            // À 6 m du joueur, au sol (sans traverser les murs), un peu au-dessus pour qu'on la voie bien.
            Position position = sphere->GetFirstCollisionPosition(6.0f, frand(0.0f, 2 * float(M_PI)));
            position.m_positionZ += 1.5f;
            if (TempSummon* orbe = map->SummonCreature(SPHERE, position, nullptr, reglages.sphereDelai + 3000))
            {
                // mod-autobalance l'ignore : sinon il remettrait les PV de son modèle (niveau 80) à chaque mise à jour
                orbe->CustomData.GetDefault<AutoBalanceCreatureInfo>("AutoBalanceCreatureInfo")->relevance = AUTOBALANCE_RELEVANCE_FALSE;
                uint32 pv = std::max<uint32>(1, uint32(sphere->GetMaxHealth() * reglages.spherePv));
                orbe->SetLevel(sphere->GetLevel());
                orbe->SetMaxHealth(pv);
                orbe->SetHealth(pv);
                orbe->SetReactState(REACT_PASSIVE);
                orbe->SetControlled(true, UNIT_STATE_ROOT);
                orbe->SetDisableGravity(true);
                orbe->CastSpell(orbe, SORT_ASPECT_SPHERE, true);
                orbe->TextEmote("apparaît ! Détruis-la avant qu'elle n'explose.", sphere, true);
                SolAzeroth::JournalApparition(orbe);
                std::lock_guard<std::mutex> garde(verrou);
                combats[map->GetInstanceId()].orbes.push_back({ orbe->GetGUID(), int32(reglages.sphereDelai) });
            }
        }
    }
};

class solazeroth_mecanique_global : public GlobalScript
{
public:
    solazeroth_mecanique_global() : GlobalScript("solazeroth_mecanique_global", { GLOBALHOOK_ON_INSTANCEID_REMOVED }) { }

    void OnInstanceIdRemoved(uint32 instanceId) override
    {
        std::lock_guard<std::mutex> garde(verrou);
        combats.erase(instanceId);
    }
};

class solazeroth_mecanique_config : public WorldScript
{
public:
    solazeroth_mecanique_config() : WorldScript("solazeroth_mecanique_config", { WORLDHOOK_ON_AFTER_CONFIG_LOAD }) { }

    void OnAfterConfigLoad(bool /*rechargement*/) override
    {
        reglages.active = sConfigMgr->GetOption<bool>("SolAzeroth.Mecanique.Enable", true);
        reglages.points[0] = sConfigMgr->GetOption<uint32>("SolAzeroth.Mecanique.Enrage.Points", 1);
        reglages.points[1] = sConfigMgr->GetOption<uint32>("SolAzeroth.Mecanique.Renforcant.Points", 1);
        reglages.points[2] = sConfigMgr->GetOption<uint32>("SolAzeroth.Mecanique.Volcanique.Points", 2);
        reglages.points[3] = sConfigMgr->GetOption<uint32>("SolAzeroth.Mecanique.Explosif.Points", 2);
        reglages.enrageSeuil = sConfigMgr->GetOption<float>("SolAzeroth.Mecanique.Enrage.Seuil", 30.0f);
        reglages.enrageDegats = sConfigMgr->GetOption<float>("SolAzeroth.Mecanique.Enrage.Degats", 0.50f);
        reglages.renfortParCumul = sConfigMgr->GetOption<float>("SolAzeroth.Mecanique.Renforcant.ParCumul", 0.20f);
        reglages.renfortPortee = sConfigMgr->GetOption<float>("SolAzeroth.Mecanique.Renforcant.Portee", 30.0f);
        reglages.volcanIntervalle = sConfigMgr->GetOption<uint32>("SolAzeroth.Mecanique.Volcanique.Intervalle", 10) * 1000;
        reglages.volcanDegats = sConfigMgr->GetOption<float>("SolAzeroth.Mecanique.Volcanique.Degats", 0.15f);
        reglages.sphereIntervalle = sConfigMgr->GetOption<uint32>("SolAzeroth.Mecanique.Explosif.Intervalle", 12) * 1000;
        reglages.sphereDelai = sConfigMgr->GetOption<uint32>("SolAzeroth.Mecanique.Explosif.Delai", 6) * 1000;
        reglages.spherePv = sConfigMgr->GetOption<float>("SolAzeroth.Mecanique.Explosif.PV", 0.05f);
        reglages.sphereDegats = sConfigMgr->GetOption<float>("SolAzeroth.Mecanique.Explosif.Degats", 0.15f);
    }
};

void AddSC_solazeroth_affixes_mecanique()
{
    new solazeroth_mecanique_unites();
    new solazeroth_mecanique_cartes();
    new solazeroth_mecanique_global();
    new solazeroth_mecanique_config();
}
