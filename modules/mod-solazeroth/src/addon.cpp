// Envoi d'un message d'addon au joueur (chuchotement en langue « addon » à lui-même), commun aux addons Sol'Azeroth.

#include "SolAzeroth.h"
#include "Player.h"
#include "WorldPacket.h"
#include "WorldSession.h"

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
