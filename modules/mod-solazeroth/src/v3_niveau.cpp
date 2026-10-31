// v3, F1 (31/10/2026) : niveau caché et fixe (document v3, section 2).
// - Les joueurs commencent et restent au niveau 80, sans talents (configurer.ps1) ; leurs statistiques de base au
//   niveau 80 sont celles du niveau 1 (migration 060) : le niveau ne donne plus de force, l'équipement si.
// - Les créatures gardent la vie, les dégâts et l'armure de leur niveau d'origine, qui devient leur « puissance »,
//   puis passent au niveau 80 : à niveau égal, plus de bonus ni de malus de toucher, de critique ou d'esquive.
// - La puissance d'attaque des joueurs ne compte plus le niveau (formule du niveau 1).
// - Régénération de vie : celle du jeu, selon l'Esprit, est coupée (Rate.Health = 0.001) car elle remplissait les petites
//   réserves de vie en quelques secondes ; hors combat, le joueur récupère SolAzeroth.V3.RegenVie % de sa vie maximum
//   par seconde (2 par défaut, demande du 31/10/2026), rendus toutes les 2 secondes ; le Repos au coin du feu en
//   ajoute 1 (v3_bivouac.cpp).
// - F4 (31/10/2026) : puissance conseillée de chaque zone, calculée au démarrage d'après ses monstres, et envoyée à
//   l'interface v3 (préfixe SOLZONE, « ZONE;basse;haute ») au changement de zone et toutes les 10 s.

#include "SolAzeroth.h"
#include "Config.h"
#include "Creature.h"
#include "DatabaseEnv.h"
#include "Log.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "StringFormat.h"
#include <algorithm>
#include <unordered_map>
#include <vector>

namespace
{
    uint8 const NIVEAU_FIXE = 80;

    uint32 const TICK_REGEN = 2000;

    struct Puissance : DataMap::Base
    {
        uint8 valeur = 0;
    };

    struct Regen : DataMap::Base
    {
        uint32 attente = 0;
        uint32 zone = 0;
        uint8 renvoi = 0;
    };

    // Puissance conseillée par zone : du 5e au 90e centile des puissances de ses monstres ordinaires (sans PNJ de
    // service, élites ni bestioles). Durotar donne 1-10, les Tarides 11-22. Une zone trop disparate (capitale, plus de
    // 25 d'écart) n'a pas de puissance conseillée.
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
        LOG_INFO("module", "Sol'Azeroth v3 : puissance conseillée calculée pour {} zones", puissanceDesZones.size());
    }
}

unsigned char SolAzeroth::PuissanceCreature(Creature const* creature)
{
    Puissance const* p = creature ? const_cast<Creature*>(creature)->CustomData.Get<Puissance>("solazeroth_puissance") : nullptr;
    return p ? p->valeur : (creature ? creature->GetLevel() : 0);
}

class solazeroth_v3_niveau_creatures : public AllCreatureScript
{
public:
    solazeroth_v3_niveau_creatures() : AllCreatureScript("solazeroth_v3_niveau_creatures") { }

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
    solazeroth_v3_niveau_monde() : WorldScript("solazeroth_v3_niveau_monde", { WORLDHOOK_ON_STARTUP }) { }

    void OnStartup() override
    {
        CalculerPuissanceDesZones();
    }
};

class solazeroth_v3_niveau_joueur : public PlayerScript
{
public:
    solazeroth_v3_niveau_joueur() : PlayerScript("solazeroth_v3_niveau_joueur", {
        PLAYERHOOK_ON_BEFORE_UPDATE_ATTACK_POWER_AND_DAMAGE, PLAYERHOOK_ON_UPDATE }) { }

    void OnPlayerBeforeUpdateAttackPowerAndDamage(Player* /*player*/, float& level, float& /*val2*/, bool /*ranged*/) override
    {
        level = 1.0f;
    }

    void OnPlayerUpdate(Player* player, uint32 diff) override
    {
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
