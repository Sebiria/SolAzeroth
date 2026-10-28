// Banque de compte par la banque de guilde (demande de l'utilisateur, V2)
// - À la connexion, un personnage sans guilde rejoint la guilde personnelle de son compte, « Coffre de <nom> »,
//   créée au besoin par le premier personnage connecté. Tous les personnages du compte y sont maîtres de guilde
//   (Guild.AllowMultipleGuildMaster = 1) : accès complet à la banque.
// - Les onglets s'achètent au prix configuré dans worldserver.conf (Guild.BankTabCost0 à 5).
// - .coffre fait apparaître un coffre de guilde à côté du joueur pendant 2 minutes.

#include "SolAzeroth.h"
#include "Chat.h"
#include "DatabaseEnv.h"
#include "GameObject.h"
#include "Guild.h"
#include "GuildMgr.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "StringFormat.h"
#include "WorldSession.h"

using namespace Acore::ChatCommands;

namespace
{
    uint32 const COFFRE_DE_GUILDE = 187290;   // « Guild Vault »
    uint32 const DUREE_COFFRE = 120;

    Guild* GuildeDuCompte(uint32 compte)
    {
        QueryResult resultat = CharacterDatabase.Query("SELECT guild_id FROM solazeroth_banque_compte WHERE account = {}", compte);
        return resultat ? sGuildMgr->GetGuildById((*resultat)[0].Get<uint32>()) : nullptr;
    }
}

class solazeroth_banque_joueur : public PlayerScript
{
public:
    solazeroth_banque_joueur() : PlayerScript("solazeroth_banque_joueur", { PLAYERHOOK_ON_LOGIN }) { }

    void OnPlayerLogin(Player* player) override
    {
        if (player->GetGuildId())
            return;
        uint32 compte = player->GetSession()->GetAccountId();

        if (Guild* guilde = GuildeDuCompte(compte))
        {
            if (guilde->AddMember(player->GetGUID(), GR_GUILDMASTER))
                ChatHandler(player->GetSession()).SendSysMessage(Acore::StringFormat("Coffre du compte rejoint : {}.", guilde->GetName()));
            return;
        }

        Guild* guilde = new Guild();
        std::string nom = "Coffre de " + player->GetName();
        if (!guilde->Create(player, nom))
        {
            delete guilde;
            return;
        }
        sGuildMgr->AddGuild(guilde);
        CharacterDatabase.Execute("REPLACE INTO solazeroth_banque_compte (account, guild_id) VALUES ({}, {})", compte, guilde->GetId());
        ChatHandler(player->GetSession()).SendSysMessage(Acore::StringFormat(
            "|cffffd100Coffre du compte créé : {}.|r Ses onglets de banque se partagent entre tous tes personnages.", nom));
    }
};

class solazeroth_banque_commandes : public CommandScript
{
public:
    solazeroth_banque_commandes() : CommandScript("solazeroth_banque_commandes") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable commandes =
        {
            { "coffre", HandleCoffre, SEC_PLAYER, Console::No },
        };
        return commandes;
    }

    static bool HandleCoffre(ChatHandler* handler)
    {
        Player* player = handler->GetSession()->GetPlayer();
        if (!player->GetGuildId())
        {
            handler->SendSysMessage("Aucun coffre de compte : reconnecte-toi pour le créer.");
            return true;
        }
        if (player->IsInCombat() || player->GetMap()->Instanceable())
        {
            handler->SendSysMessage("Le coffre ne s'ouvre qu'hors combat et hors instance.");
            return true;
        }
        float o = player->GetOrientation();
        float x = player->GetPositionX() + 2.0f * std::cos(o);
        float y = player->GetPositionY() + 2.0f * std::sin(o);
        float rotation = o + float(M_PI);
        player->SummonGameObject(COFFRE_DE_GUILDE, x, y, player->GetPositionZ(), rotation,
            0.0f, 0.0f, std::sin(rotation / 2.0f), std::cos(rotation / 2.0f), DUREE_COFFRE);
        handler->SendSysMessage("Coffre du compte ouvert pour 2 minutes.");
        return true;
    }
};

void AddSC_solazeroth_banque()
{
    new solazeroth_banque_joueur();
    new solazeroth_banque_commandes();
}
