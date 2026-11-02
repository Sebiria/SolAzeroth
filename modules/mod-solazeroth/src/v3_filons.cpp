// Audit du jeu, lot 7 (02/11/2026, « avant la zone 2 » ; choix de l'utilisateur : estimer + compteur) : mesure en jeu
// du nombre de filons minés par heure, le rythme qui fixe le coût des pierres taillées des rangs 4 et 5. L'estimation
// d'après les points d'apparition est outils\filons_heure.py.
// - Chaque filon ouvert (butin d'un objet à serrure de minage) est noté dans solazeroth_v3_filons (migration 122) avec
//   le temps de jeu total du personnage : la mesure ne compte que le temps passé en jeu.
// - « .filons » : total, dernière heure de jeu, et rythme pendant le minage (pauses de plus de 10 minutes retirées).

#include "SolAzeroth.h"
#include "Chat.h"
#include "CommandScript.h"
#include "DatabaseEnv.h"
#include "DBCStores.h"
#include "GameObject.h"
#include "ObjectAccessor.h"
#include "Player.h"
#include "ScriptMgr.h"
#include <vector>

using namespace Acore::ChatCommands;

namespace
{
    uint32 const PAUSE = 600;   // secondes de jeu sans filon : le minage s'est arrêté

    struct DernierFilon : DataMap::Base
    {
        ObjectGuid filon;   // le butin d'un filon peut se rouvrir : on ne le compte qu'une fois
    };

    bool EstUnFilon(GameObject const* objet)
    {
        LockEntry const* serrure = sLockStore.LookupEntry(objet->GetGOInfo()->GetLockId());
        if (!serrure)
            return false;
        for (uint8 i = 0; i < MAX_LOCK_CASE; ++i)
            if (serrure->Type[i] == LOCK_KEY_SKILL && serrure->Index[i] == LOCKTYPE_MINING)
                return true;
        return false;
    }
}

class solazeroth_v3_filons_joueur : public PlayerScript
{
public:
    solazeroth_v3_filons_joueur() : PlayerScript("solazeroth_v3_filons_joueur", { PLAYERHOOK_ON_BEFORE_SEND_LOOT }) { }

    void OnPlayerBeforeSendLoot(Player* player, ObjectGuid lootGuid, Loot* /*loot*/) override
    {
        if (!lootGuid.IsGameObject())
            return;
        DernierFilon* dernier = player->CustomData.GetDefault<DernierFilon>("solazeroth_v3_filons");
        if (dernier->filon == lootGuid)
            return;
        GameObject* objet = ObjectAccessor::GetGameObject(*player, lootGuid);
        if (!objet || !EstUnFilon(objet))
            return;
        dernier->filon = lootGuid;
        CharacterDatabase.Execute("INSERT INTO solazeroth_v3_filons (guid, joue, zone, objet) VALUES ({}, {}, {}, {})",
            player->GetGUID().GetCounter(), player->GetTotalPlayedTime(), player->GetZoneId(), objet->GetEntry());
    }
};

class solazeroth_v3_filons_commandes : public CommandScript
{
public:
    solazeroth_v3_filons_commandes() : CommandScript("solazeroth_v3_filons_commandes") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable commandes =
        {
            { "filons", HandleFilons, SEC_PLAYER, Console::No },
        };
        return commandes;
    }

    static bool HandleFilons(ChatHandler* handler)
    {
        Player* player = handler->GetPlayer();
        std::vector<uint32> instants;
        uint32 dansLaZone = 0;
        if (QueryResult r = CharacterDatabase.Query("SELECT joue, zone FROM solazeroth_v3_filons WHERE guid = {} "
            "ORDER BY joue", player->GetGUID().GetCounter()))
        {
            do
            {
                instants.push_back((*r)[0].Get<uint32>());
                dansLaZone += (*r)[1].Get<uint32>() == player->GetZoneId();
            } while (r->NextRow());
        }
        if (instants.empty())
        {
            handler->SendSysMessage("Aucun filon miné pour l'instant.");
            return true;
        }
        uint32 maintenant = player->GetTotalPlayedTime(), derniereHeure = 0, duree = 0, intervalles = 0;
        for (size_t i = 0; i < instants.size(); ++i)
        {
            derniereHeure += instants[i] + 3600 >= maintenant;
            if (i && instants[i] - instants[i - 1] <= PAUSE)
            {
                duree += instants[i] - instants[i - 1];
                ++intervalles;
            }
        }
        handler->PSendSysMessage("Filons minés : {} au total, dont {} dans cette zone ; {} dans la dernière heure de jeu.",
            instants.size(), dansLaZone, derniereHeure);
        if (duree >= 60)
            handler->PSendSysMessage("Pendant le minage (pauses de plus de 10 min retirées) : {:.0f} filons par heure, "
                "sur {} min.", intervalles * 3600.0f / duree, duree / 60);
        return true;
    }
};

void AddSC_solazeroth_v3_filons()
{
    new solazeroth_v3_filons_joueur();
    new solazeroth_v3_filons_commandes();
}
