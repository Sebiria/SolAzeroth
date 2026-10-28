// Envoi d'un message d'addon au joueur (chuchotement en langue « addon » à lui-même), commun aux addons Sol'Azeroth.

#include "SolAzeroth.h"
#include "Chat.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "WorldPacket.h"
#include "WorldSession.h"
#include <cstdlib>
#include <sstream>

using namespace Acore::ChatCommands;

void SolAzeroth::EnvoyerAddon(Player* player, std::string const& prefixe, std::string const& message)
{
    std::string complet = prefixe + "\t" + message;
    WorldPacket data(SMSG_MESSAGECHAT, 100);
    data << uint8(CHAT_MSG_WHISPER);
    data << int32(LANG_ADDON);
    data << player->GetGUID();
    data << uint32(0);
    data << player->GetGUID();
    data << uint32(complet.length() + 1);
    data << complet;
    data << uint8(0);
    player->GetSession()->SendPacket(&data);
}

// Noms des objets dans la langue du joueur : « .solnoms 862,2564,… » répond « id:nom;id:nom… » (préfixe SolAzerothNoms).
// Le client ne connaît le nom d'un objet qu'après l'avoir demandé au serveur, un par un ; les addons affichaient
// alors « Objet 862 ». Ils demandent maintenant tous les noms manquants d'un coup.
class solazeroth_addon_commandes : public CommandScript
{
public:
    solazeroth_addon_commandes() : CommandScript("solazeroth_addon_commandes") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable commandes =
        {
            { "solnoms", HandleNoms, SEC_PLAYER, Console::No },
        };
        return commandes;
    }

    static bool HandleNoms(ChatHandler* handler, Tail liste)
    {
        Player* player = handler->GetSession()->GetPlayer();
        LocaleConstant langue = handler->GetSession()->GetSessionDbLocaleIndex();
        std::string paquet;
        std::stringstream flux{ std::string(liste) };
        std::string morceau;
        while (std::getline(flux, morceau, ','))
        {
            uint32 id = uint32(std::strtoul(morceau.c_str(), nullptr, 10));
            ItemTemplate const* modele = id ? sObjectMgr->GetItemTemplate(id) : nullptr;
            if (!modele)
                continue;
            std::string nom = modele->Name1;
            if (ItemLocale const* traduction = sObjectMgr->GetItemLocale(id))
                ObjectMgr::GetLocaleString(traduction->Name, langue, nom);
            std::string element = std::to_string(id) + ":" + nom;
            if (paquet.size() + element.size() + 1 > 220)
            {
                SolAzeroth::EnvoyerAddon(player, "SolAzerothNoms", paquet);
                paquet.clear();
            }
            paquet += (paquet.empty() ? "" : ";") + element;
        }
        if (!paquet.empty())
            SolAzeroth::EnvoyerAddon(player, "SolAzerothNoms", paquet);
        return true;
    }
};

void AddSC_solazeroth_addon()
{
    new solazeroth_addon_commandes();
}
