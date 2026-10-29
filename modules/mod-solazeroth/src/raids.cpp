// Rendements décroissants des raids (section 4.7, V6). Pas de verrou hebdomadaire et réinitialisation libre : pour
// éviter de rejouer le même raid en boucle, chaque entrée dans une nouvelle instance d'un raid compte un passage du jour
// (par personnage et par raid, jour de l'ordinateur). Au-delà de 3 passages (provisoire, mod_solazeroth.conf), le
// personnage est « épuisé » dans ce raid : le butin rare baisse de 50 %.
// - Butin des boss : les références de butin (les objets épiques des raids) donnent deux fois moins d'objets, et
//   chaque objet bleu ou mieux a deux fois moins de chances de tomber.
// - Calibrage final (29/10/2026) : 1 passage par jour (au lieu de 3), baisse de 75 % (au lieu de 50 %), et l'épuisement
//   réduit aussi l'or ramassé et coupe les Éclats (malchance.cpp).
// - Affichage : un message à chaque entrée (« passage 2 sur 3 aujourd'hui ») et, une fois épuisé, l'aura « Épuisement
//   spectral » (44867, une aura sans effet ; son vrai nom viendra avec le patch client de V7).

#include "SolAzeroth.h"
#include "Chat.h"
#include "Config.h"
#include "DatabaseEnv.h"
#include "ItemTemplate.h"
#include "LootMgr.h"
#include "Map.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "Random.h"
#include "ScriptMgr.h"
#include "SpellAuras.h"
#include "Timer.h"
#include <ctime>
#include <mutex>
#include <unordered_set>

namespace
{
    uint32 const AURA_EPUISE = 100001;         // « Raid épuisé » (V7, outils/auras_nommees.py, migration 050)

    struct Reglages
    {
        bool actif = true;
        uint32 passages = 3;
        float reduction = 0.5f;
    } reglages;

    std::mutex verrou;
    std::unordered_set<ObjectGuid> epuises;   // joueurs épuisés dans le raid où ils sont

    uint32 Jour()
    {
        std::tm t = Acore::Time::TimeBreakdown(time(nullptr));
        return uint32((t.tm_year + 1900) * 10000 + (t.tm_mon + 1) * 100 + t.tm_mday);
    }

    bool Epuise(Player const* player)
    {
        if (!player)
            return false;
        std::lock_guard<std::mutex> garde(verrou);
        return epuises.count(player->GetGUID()) > 0;
    }

    void Noter(Player* player, bool epuise)
    {
        {
            std::lock_guard<std::mutex> garde(verrou);
            if (epuise)
                epuises.insert(player->GetGUID());
            else
                epuises.erase(player->GetGUID());
        }
        if (epuise)
        {
            if (Aura* aura = player->AddAura(AURA_EPUISE, player))
            {
                aura->SetMaxDuration(-1);
                aura->SetDuration(-1);
            }
        }
        else
            player->RemoveAurasDueToSpell(AURA_EPUISE);
    }
}

class solazeroth_raids_joueur : public PlayerScript
{
public:
    solazeroth_raids_joueur() : PlayerScript("solazeroth_raids_joueur", {
        PLAYERHOOK_ON_MAP_CHANGED, PLAYERHOOK_ON_LOGOUT, PLAYERHOOK_ON_BEFORE_LOOT_MONEY }) { }

    // Épuisé : l'or ramassé baisse comme le butin rare.
    void OnPlayerBeforeLootMoney(Player* player, Loot* loot) override
    {
        if (loot && loot->gold && player->GetMap() && player->GetMap()->IsRaid() && Epuise(player))
            loot->gold = uint32(loot->gold * (1.0f - reglages.reduction));
    }

    void OnPlayerMapChanged(Player* player) override
    {
        Map* map = player->GetMap();
        if (!reglages.actif || !map || !map->IsRaid())
        {
            Noter(player, false);
            return;
        }

        uint32 guid = player->GetGUID().GetCounter(), carte = map->GetId(), instance = map->GetInstanceId(), jour = Jour();
        uint32 passages = 0, derniere = 0;
        if (QueryResult r = CharacterDatabase.Query("SELECT passages, instance FROM solazeroth_raid_passages "
            "WHERE guid = {} AND map = {} AND jour = {}", guid, carte, jour))
        {
            passages = (*r)[0].Get<uint32>();
            derniere = (*r)[1].Get<uint32>();
        }
        if (instance != derniere)
        {
            ++passages;
            CharacterDatabase.Execute("REPLACE INTO solazeroth_raid_passages (guid, map, jour, passages, instance) "
                "VALUES ({}, {}, {}, {}, {})", guid, carte, jour, passages, instance);
        }

        bool epuise = passages > reglages.passages;
        Noter(player, epuise);
        ChatHandler handler(player->GetSession());
        if (epuise)
            handler.PSendSysMessage("|cffff8000Raid épuisé : passage {} aujourd'hui (plus de {}). Le butin rare et l'or baissent de {:.0f} %, sans Éclats, jusqu'à demain.|r",
                passages, reglages.passages, reglages.reduction * 100.0f);
        else
            handler.PSendSysMessage("|cff00ccffRaid : passage {} sur {} aujourd'hui avant l'épuisement.|r", passages, reglages.passages);
    }

    void OnPlayerLogout(Player* player) override
    {
        std::lock_guard<std::mutex> garde(verrou);
        epuises.erase(player->GetGUID());
    }
};

class solazeroth_raids_butin : public GlobalScript
{
public:
    solazeroth_raids_butin() : GlobalScript("solazeroth_raids_butin", { GLOBALHOOK_ON_AFTER_REF_COUNT, GLOBALHOOK_ON_ITEM_ROLL }) { }

    // Une référence de butin (objets épiques des boss) donne moins d'objets : 2 -> 1, 1 -> 0 ou 1 au hasard.
    void OnAfterRefCount(Player const* player, LootStoreItem* /*objet*/, Loot& /*loot*/, bool /*canRate*/, uint16 /*lootMode*/,
        uint32& maxcount, LootStore const& magasin) override
    {
        if (!Epuise(player) || (&magasin != &LootTemplates_Creature && &magasin != &LootTemplates_Gameobject))
            return;
        float reste = maxcount * (1.0f - reglages.reduction);
        maxcount = uint32(reste) + (roll_chance_f((reste - uint32(reste)) * 100.0f) ? 1 : 0);
    }

    bool OnItemRoll(Player const* player, LootStoreItem const* objet, float& chance, Loot& /*loot*/, LootStore const& magasin) override
    {
        if (!objet || !Epuise(player) || (&magasin != &LootTemplates_Creature && &magasin != &LootTemplates_Gameobject))
            return true;
        if (ItemTemplate const* modele = sObjectMgr->GetItemTemplate(objet->itemid))
            if (modele->Quality >= ITEM_QUALITY_RARE)
                chance *= 1.0f - reglages.reduction;
        return true;
    }
};

class solazeroth_raids_monde : public WorldScript
{
public:
    solazeroth_raids_monde() : WorldScript("solazeroth_raids_monde", { WORLDHOOK_ON_AFTER_CONFIG_LOAD }) { }

    void OnAfterConfigLoad(bool /*rechargement*/) override
    {
        reglages.actif = sConfigMgr->GetOption<bool>("SolAzeroth.Raids.Epuisement", true);
        reglages.passages = sConfigMgr->GetOption<uint32>("SolAzeroth.Raids.PassagesParJour", 3);
        reglages.reduction = sConfigMgr->GetOption<float>("SolAzeroth.Raids.Reduction", 0.5f);
    }
};

bool SolAzeroth::EpuiseRaid(Player const* player)
{
    return Epuise(player);
}

void AddSC_solazeroth_raids()
{
    new solazeroth_raids_joueur();
    new solazeroth_raids_butin();
    new solazeroth_raids_monde();
}
