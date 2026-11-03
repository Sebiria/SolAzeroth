// v3, F1 (31/10/2026) : niveau caché et fixe (document v3, section 2).
// - Les joueurs commencent et restent au niveau 80, sans talents (configurer.ps1) ; leurs statistiques de base au
//   niveau 80 sont celles du niveau 1 (migration 060) : le niveau ne donne plus de force, l'équipement si.
// - Les créatures gardent la vie, les dégâts et l'armure de leur niveau d'origine, qui devient leur « puissance »,
//   puis passent au niveau 80 : à niveau égal, plus de bonus ni de malus de toucher, de critique ou d'esquive.
// - La puissance d'attaque des joueurs ne compte plus le niveau (formule du niveau 1).
// - Lot D1 (02/11/2026) : une seule règle pour toutes les classes, au lieu des formules de Blizzard par classe : la
//   puissance d'attaque de base vaut 2 par point de caractéristique principale (Force, Agilité ou Intelligence, selon la
//   spécialisation : v3_kit.cpp), comme la Force du guerrier. Les sorts du démoniste suivent ainsi son Intelligence.
//   Lot D4 : un lanceur de sorts y ajoute les dégâts par seconde de son arme × 14.
// - Régénération de vie : celle du jeu, selon l'Esprit, est coupée (Rate.Health = 0.001) car elle remplissait les petites
//   réserves de vie en quelques secondes ; hors combat, le joueur récupère SolAzeroth.V3.RegenVie % de sa vie maximum
//   par seconde (2 par défaut, demande du 31/10/2026), rendus toutes les 2 secondes ; le Repos au coin du feu en
//   ajoute 1 (v3_bivouac.cpp).
// - F4 (31/10/2026) : puissance conseillée de chaque zone, calculée au démarrage d'après ses monstres, et envoyée à
//   l'interface v3 (préfixe SOLZONE, « ZONE;basse;haute ») au changement de zone et toutes les 10 s.
// - Lot T1 des Tarides (03/11/2026, point 1 du §5.2 du brouillon) : puissance par secteur, fixée à chaque apparition.
//   Avant que le moteur ne calcule les statistiques (OnBeforeCreatureSelectLevel), le niveau tiré est ramené sur la
//   plage de puissance du secteur de l'apparition (table solazeroth_v3_puissance_apparitions, écrite par
//   outils\puissance_tarides.py), en ligne droite depuis la plage d'origine du secteur, arrondi et borné. Vie, dégâts,
//   puissance d'attaque et armure sont ainsi ceux de ce niveau, et les sorts suivent (v3_combat.cpp). Une entrée de
//   solazeroth_v3_puissance_entrees marquée « fixe » l'emporte (chefs nommés, élites hors annexes). Une créature
//   invoquée par un monstre des secteurs prend sa puissance ; invoquée autrement dans la zone, la plage la plus
//   fréquente de son entrée. Durotar n'a pas de secteurs : rien n'y change. Une zone à secteurs a pour puissance
//   conseillée la plage de ses secteurs (solazeroth_v3_puissance_secteurs : les Tarides 14-30).

#include "SolAzeroth.h"
#include "Config.h"
#include "Creature.h"
#include "DatabaseEnv.h"
#include "DBCStores.h"
#include "Item.h"
#include "Log.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "StringFormat.h"
#include "TemporarySummon.h"
#include <algorithm>
#include <cmath>
#include <unordered_map>
#include <vector>

namespace
{
    uint8 const NIVEAU_FIXE = 80;

    uint32 const TICK_REGEN = 2000;

    struct Puissance : DataMap::Base
    {
        uint8 valeur = 0;
        bool secteur = false;   // puissance fixée par un secteur (lot T1 des Tarides)
    };

    // Plage d'une apparition ou d'une entrée : niveaux d'origine du secteur et puissances du secteur ou de la sous-zone.
    struct Plage
    {
        uint8 origineMin = 0, origineMax = 0, puissanceMin = 0, puissanceMax = 0;
        uint32 zone = 0;
        bool fixe = false;
    };
    std::unordered_map<uint32, Plage> plagesApparitions;   // guid d'apparition -> plage
    std::unordered_map<uint32, Plage> plagesEntrees;       // entrée -> plage
    std::unordered_map<uint32, std::pair<uint8, uint8>> plagesZones;   // zone -> puissance conseillée

    uint8 Ramener(uint8 niveau, Plage const& p)
    {
        if (p.puissanceMin == p.puissanceMax)
            return p.puissanceMin;
        if (p.origineMax <= p.origineMin)
            return uint8(std::lround((p.puissanceMin + p.puissanceMax) / 2.0f));
        float v = p.puissanceMin + float(int32(niveau) - int32(p.origineMin)) * (p.puissanceMax - p.puissanceMin)
            / float(p.origineMax - p.origineMin);
        return uint8(std::clamp<long>(std::lround(v), p.puissanceMin, p.puissanceMax));
    }

    Plage LirePlage(Field* f, uint32 premier)
    {
        Plage p;
        p.origineMin = f[premier].Get<uint8>();
        p.origineMax = f[premier + 1].Get<uint8>();
        p.puissanceMin = f[premier + 2].Get<uint8>();
        p.puissanceMax = f[premier + 3].Get<uint8>();
        return p;
    }

    void ChargerSecteurs()
    {
        plagesApparitions.clear();
        plagesEntrees.clear();
        plagesZones.clear();
        if (QueryResult r = WorldDatabase.Query("SELECT guid, origine_min, origine_max, puissance_min, puissance_max "
            "FROM solazeroth_v3_puissance_apparitions"))
        {
            do
            {
                Field* f = r->Fetch();
                plagesApparitions[f[0].Get<uint32>()] = LirePlage(f, 1);
            } while (r->NextRow());
        }
        if (QueryResult r = WorldDatabase.Query("SELECT entree, origine_min, origine_max, puissance_min, puissance_max, "
            "zone, fixe FROM solazeroth_v3_puissance_entrees"))
        {
            do
            {
                Field* f = r->Fetch();
                Plage p = LirePlage(f, 1);
                p.zone = f[5].Get<uint32>();
                p.fixe = f[6].Get<uint8>() != 0;
                plagesEntrees[f[0].Get<uint32>()] = p;
            } while (r->NextRow());
        }
        if (QueryResult r = WorldDatabase.Query("SELECT zone, MIN(puissance_min), MAX(puissance_max) FROM "
            "solazeroth_v3_puissance_secteurs GROUP BY zone"))
        {
            do
            {
                Field* f = r->Fetch();
                plagesZones[f[0].Get<uint32>()] = { f[1].Get<uint8>(), f[2].Get<uint8>() };
            } while (r->NextRow());
        }
        LOG_INFO("module", "Sol'Azeroth v3 : puissance par secteur pour {} apparitions et {} entrées",
            plagesApparitions.size(), plagesEntrees.size());
    }

    struct ArmePortee : DataMap::Base
    {
        uint32 entree = 0;
        uint32 enchantement = 0;
    };

    struct Regen : DataMap::Base
    {
        uint32 attente = 0;
        uint32 zone = 0;
        uint8 renvoi = 0;
    };

    // Puissance conseillée par zone : du 5e au 90e centile des puissances de ses monstres ordinaires (sans PNJ de
    // service, élites ni bestioles). Durotar donne 1-10. Une zone trop disparate (capitale, plus de 25 d'écart) n'a pas
    // de puissance conseillée. Une zone à secteurs prend la plage de ses secteurs (lot T1 : les Tarides 14-30).
    std::unordered_map<uint32, std::pair<uint8, uint8>> puissanceDesZones;

    void CalculerPuissanceDesZones()
    {
        puissanceDesZones.clear();
        std::unordered_map<uint32, std::vector<uint8>> niveaux;
        if (QueryResult resultat = WorldDatabase.Query("SELECT c.zoneId, t.minlevel FROM creature c "
            "JOIN creature_template t ON t.entry = c.id WHERE c.zoneId <> 0 AND t.npcflag = 0 AND t.`rank` = 0 AND t.type <> 8"))
        {
            do
            {
                Field* champs = resultat->Fetch();
                niveaux[champs[0].Get<uint32>()].push_back(champs[1].Get<uint8>());
            } while (resultat->NextRow());
        }
        for (auto& [zone, liste] : niveaux)
        {
            std::sort(liste.begin(), liste.end());
            uint8 bas = liste[size_t(0.05 * (liste.size() - 1))];
            uint8 haut = liste[size_t(0.90 * (liste.size() - 1))];
            if (haut - bas <= 25)
                puissanceDesZones[zone] = { bas, haut };
        }
        for (auto const& [zone, plage] : plagesZones)
            puissanceDesZones[zone] = plage;
        LOG_INFO("module", "Sol'Azeroth v3 : puissance conseillée calculée pour {} zones", puissanceDesZones.size());
    }
}

unsigned char SolAzeroth::PuissanceHauteZone(unsigned int zone)
{
    auto it = puissanceDesZones.find(zone);
    return it == puissanceDesZones.end() ? 0 : it->second.second;
}

unsigned char SolAzeroth::PuissanceCreature(Creature const* creature)
{
    Puissance const* p = creature ? const_cast<Creature*>(creature)->CustomData.Get<Puissance>("solazeroth_puissance") : nullptr;
    return p ? p->valeur : (creature ? creature->GetLevel() : 0);
}

void SolAzeroth::FixerPuissanceCreature(Creature* creature, unsigned char puissance)
{
    creature->CustomData.GetDefault<Puissance>("solazeroth_puissance")->valeur = puissance;
}

class solazeroth_v3_niveau_creatures : public AllCreatureScript
{
public:
    solazeroth_v3_niveau_creatures() : AllCreatureScript("solazeroth_v3_niveau_creatures") { }

    // Lot T1 des Tarides : le niveau tiré est remplacé par la puissance du secteur, avant le calcul des statistiques.
    void OnBeforeCreatureSelectLevel(CreatureTemplate const* /*cinfo*/, Creature* creature, uint8& niveau) override
    {
        if (creature->IsPet() || creature->HasUnitTypeMask(UNIT_MASK_MINION))
            return;
        bool secteur = false;
        auto entree = plagesEntrees.find(creature->GetEntry());
        auto apparition = plagesApparitions.find(creature->GetSpawnId());
        if (entree != plagesEntrees.end() && entree->second.fixe)
        {
            niveau = Ramener(niveau, entree->second);
            secteur = true;
        }
        else if (creature->GetSpawnId() && apparition != plagesApparitions.end())
        {
            niveau = Ramener(niveau, apparition->second);
            secteur = true;
        }
        else if (!creature->GetSpawnId() && creature->IsSummon())
        {
            Unit* invocateur = creature->ToTempSummon()->GetSummonerUnit();
            Creature* monstre = invocateur ? invocateur->ToCreature() : nullptr;
            Puissance const* p = monstre ? monstre->CustomData.Get<Puissance>("solazeroth_puissance") : nullptr;
            if (p && p->secteur)
            {
                niveau = p->valeur;
                secteur = true;
            }
            else if (entree != plagesEntrees.end() && entree->second.zone == creature->GetZoneId())
            {
                niveau = Ramener(niveau, entree->second);
                secteur = true;
            }
        }
        creature->CustomData.GetDefault<Puissance>("solazeroth_puissance")->secteur = secteur;
    }

    // Appelé à la fin de Creature::SelectLevel, statistiques déjà calculées au niveau d'origine.
    void OnCreatureSelectLevel(CreatureTemplate const* /*cinfo*/, Creature* creature) override
    {
        if (creature->IsPet() || creature->HasUnitTypeMask(UNIT_MASK_MINION))
            return;
        uint8 origine = creature->GetLevel();
        creature->CustomData.GetDefault<Puissance>("solazeroth_puissance")->valeur = origine;
        if (origine < NIVEAU_FIXE)
            creature->SetLevel(NIVEAU_FIXE);

        // Calibrage (journal du 31/10/2026 : un sanglier tenait 6 s et ne coûtait rien) : vie des monstres multipliée par
        // SolAzeroth.V3.MonstresVie. Leurs dégâts le sont dans v3_combat.cpp (SolAzeroth.V3.MonstresDegats).
        static float const multiplicateur = sConfigMgr->GetOption<float>("SolAzeroth.V3.MonstresVie", 2.0f);
        if (multiplicateur != 1.0f)
        {
            uint32 vie = std::max<uint32>(1, uint32(creature->GetCreateHealth() * multiplicateur));
            creature->SetCreateHealth(vie);
            creature->SetMaxHealth(vie);
            creature->SetHealth(vie);
            creature->SetStatFlatModifier(UNIT_MOD_HEALTH, BASE_VALUE, float(vie));
            creature->ResetPlayerDamageReq();
        }
    }

    // L'armure de base est générée après SelectLevel, donc au niveau 80 (9729 pour un sanglier de Durotar, journal de
    // combat du 31/10/2026) : on reprend celle du niveau d'origine. Accroche ajoutée au moteur (patch v3).
    void OnCreatureBaseArmor(Creature* creature, float& armure) override
    {
        Puissance const* p = creature->CustomData.Get<Puissance>("solazeroth_puissance");
        if (!p || p->valeur >= NIVEAU_FIXE)
            return;
        CreatureTemplate const* modele = creature->GetCreatureTemplate();
        if (CreatureBaseStats const* stats = sObjectMgr->GetCreatureBaseStats(p->valeur, modele->unit_class))
            armure = stats->GenerateArmor(modele);
    }
};

class solazeroth_v3_niveau_monde : public WorldScript
{
public:
    solazeroth_v3_niveau_monde() : WorldScript("solazeroth_v3_niveau_monde", { WORLDHOOK_ON_BEFORE_WORLD_INITIALIZED,
        WORLDHOOK_ON_STARTUP }) { }

    // Avant le chargement des grilles (PreloadAllNonInstancedMapGrids) : les premières apparitions lisent déjà les
    // secteurs.
    void OnBeforeWorldInitialized() override
    {
        ChargerSecteurs();
    }

    void OnStartup() override
    {
        CalculerPuissanceDesZones();
    }
};

class solazeroth_v3_niveau_joueur : public PlayerScript
{
public:
    solazeroth_v3_niveau_joueur() : PlayerScript("solazeroth_v3_niveau_joueur", {
        PLAYERHOOK_ON_BEFORE_UPDATE_ATTACK_POWER_AND_DAMAGE, PLAYERHOOK_ON_AFTER_UPDATE_ATTACK_POWER_AND_DAMAGE,
        PLAYERHOOK_ON_UPDATE }) { }

    void OnPlayerBeforeUpdateAttackPowerAndDamage(Player* /*player*/, float& level, float& /*val2*/, bool /*ranged*/) override
    {
        level = 1.0f;
    }

    // Formule du guerrier au niveau 1 (3 + 2 × Force − 20), appliquée à la caractéristique principale de chacun.
    // Lot D4 (02/11/2026) : un lanceur de sorts (caractéristique principale Intelligence, aujourd'hui le seul démoniste)
    // ne frappe pas avec son arme ; ses dégâts par seconde × 14 s'ajoutent à sa puissance d'attaque, celle des sorts,
    // comme le moteur les ajoute aux coups de mêlée. Une meilleure arme vaut ainsi autant pour lui que pour le guerrier.
    void OnPlayerAfterUpdateAttackPowerAndDamage(Player* player, float& level, float& base, float& /*mod*/,
        float& /*multiplicateur*/, bool ranged) override
    {
        float caracteristique = player->GetStat(Stats(SolAzeroth::CaracteristiquePrincipale(player)));
        base = (std::max(0.0f, level * 3.0f + caracteristique * 2.0f - 20.0f) + PuissanceDeLArme(player))
            * player->GetPctModifierValue(ranged ? UNIT_MOD_ATTACK_POWER_RANGED : UNIT_MOD_ATTACK_POWER, BASE_PCT);
    }

    static float PuissanceDeLArme(Player* player)
    {
        if (SolAzeroth::CaracteristiquePrincipale(player) != STAT_INTELLECT)
            return 0.0f;
        Item* arme = player->GetWeaponForAttack(BASE_ATTACK, true);
        ItemTemplate const* modele = arme ? arme->GetTemplate() : nullptr;
        if (!modele || !modele->Delay)
            return 0.0f;
        float moyenne = (modele->Damage[0].DamageMin + modele->Damage[0].DamageMax) / 2.0f;
        // Lot D5 : les enchantements de dégâts de l'arme (Frappe, Impact) comptent aussi.
        if (SpellItemEnchantmentEntry const* e = sSpellItemEnchantmentStore.LookupEntry(
                arme->GetEnchantmentId(PERM_ENCHANTMENT_SLOT)))
            for (uint8 i = 0; i < MAX_SPELL_ITEM_ENCHANTMENT_EFFECTS; ++i)
                if (e->type[i] == ITEM_ENCHANTMENT_TYPE_DAMAGE)
                    moyenne += e->amount[i];
        return moyenne / (modele->Delay / 1000.0f) * 14.0f;
    }

    void OnPlayerUpdate(Player* player, uint32 diff) override
    {
        // Arme ou son enchantement changés : la puissance d'attaque du lanceur de sorts suit (l'équipement ne la recalcule pas toujours).
        if (SolAzeroth::CaracteristiquePrincipale(player) == STAT_INTELLECT)
        {
            Item* arme = player->GetWeaponForAttack(BASE_ATTACK, true);
            ArmePortee* a = player->CustomData.GetDefault<ArmePortee>("solazeroth_v3_arme_portee");
            uint32 entree = arme ? arme->GetEntry() : 0;
            uint32 enchantement = arme ? arme->GetEnchantmentId(PERM_ENCHANTMENT_SLOT) : 0;
            if (entree != a->entree || enchantement != a->enchantement)
            {
                a->entree = entree;
                a->enchantement = enchantement;
                player->UpdateAttackPowerAndDamage();
            }
        }
        Regen* r = player->CustomData.GetDefault<Regen>("solazeroth_v3_regen");
        r->attente += diff;
        if (r->attente < TICK_REGEN)
            return;
        r->attente = 0;

        if (player->GetZoneId() != r->zone || ++r->renvoi >= 5)
        {
            r->zone = player->GetZoneId();
            r->renvoi = 0;
            auto zone = puissanceDesZones.find(r->zone);
            SolAzeroth::EnvoyerAddon(player, "SOLZONE", zone == puissanceDesZones.end() ? std::string("ZONE;0;0")
                : Acore::StringFormat("ZONE;{};{}", uint32(zone->second.first), uint32(zone->second.second)));
        }

        if (!player->IsAlive() || player->IsInCombat() || player->GetHealth() >= player->GetMaxHealth())
            return;
        static float const pourcentage = sConfigMgr->GetOption<float>("SolAzeroth.V3.RegenVie", 2.0f);
        if (pourcentage <= 0.0f)
            return;
        player->ModifyHealth(std::max<int32>(1, int32(player->GetMaxHealth() * pourcentage * TICK_REGEN / 1000 / 100.0f)));
    }
};

void AddSC_solazeroth_v3_niveau()
{
    new solazeroth_v3_niveau_creatures();
    new solazeroth_v3_niveau_monde();
    new solazeroth_v3_niveau_joueur();
}
