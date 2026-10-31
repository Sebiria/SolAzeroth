// v3, F5f (31/10/2026) : accès au Gouffre de Ragefeu à 60 % de Durotar (document v3, F5 ; document de Durotar, D26 et
// moment scripté n°1).
// - Ruga Brise-cendre (910001), devant la faille du Rocher du crâne : en plus de ses quêtes, une option « Descendre dans
//   la faille ». Avec D26 rendue et 60 % de Durotar, elle envoie le joueur à l'entrée du Gouffre ; sinon elle lui dit
//   ce qui manque, avec son pourcentage.
// - Toute autre entrée dans le Gouffre (l'entrée d'origine, à Orgrimmar) est refusée sous ces conditions.
// - La sortie du Gouffre ramène auprès de Ruga (migration 076, areatrigger_teleport 2226).
// Les maîtres du jeu passent toujours.

#include "SolAzeroth.h"
#include "Chat.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "ScriptedCreature.h"
#include "ScriptedGossip.h"
#include "StringFormat.h"

namespace
{
    uint32 const DUROTAR = 14;
    uint32 const GOUFFRE = 389;
    uint32 const SEUIL = 6000;           // centièmes de %
    uint32 const SEUIL_QUETE = 910026;   // D26, Le seuil du Gouffre
    uint32 const TEXTE_RUGA = 910001;    // npc_text
    uint32 const DESCENDRE = 1;

    std::string Pourcent(uint32 centiemes)
    {
        std::string texte = Acore::StringFormat("{:.1f}", centiemes / 100.0f);
        if (texte.size() > 2 && texte.substr(texte.size() - 2) == ".0")
            texte.resize(texte.size() - 2);
        for (char& c : texte)
            if (c == '.')
                c = ',';
        return texte + " %";
    }

    // Ce qui empêche de descendre, ou une chaîne vide.
    std::string Refus(Player* player)
    {
        if (player->IsGameMaster())
            return {};
        if (!player->GetQuestRewardStatus(SEUIL_QUETE))
            return "Margoz garde l'œil sur cette faille. Va d'abord le voir, au sud du Rocher du crâne.";
        uint32 pourcent = SolAzeroth::PourcentZone(player, DUROTAR);
        if (pourcent < SEUIL)
            return Acore::StringFormat("Durotar ne parle pas encore assez de toi : {} de la zone. Reviens à 60 %.",
                Pourcent(pourcent));
        return {};
    }
}

class npc_solazeroth_ruga : public CreatureScript
{
public:
    npc_solazeroth_ruga() : CreatureScript("npc_solazeroth_ruga") { }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        if (creature->IsQuestGiver())
            player->PrepareQuestMenu(creature->GetGUID());
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Descendre dans la faille.", GOSSIP_SENDER_MAIN, DESCENDRE);
        SendGossipMenuFor(player, TEXTE_RUGA, creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 /*sender*/, uint32 action) override
    {
        CloseGossipMenuFor(player);
        if (action != DESCENDRE)
            return true;
        if (std::string refus = Refus(player); !refus.empty())
        {
            creature->Whisper(refus, LANG_UNIVERSAL, player);
            return true;
        }
        player->TeleportTo(GOUFFRE, 3.81f, -14.82f, -17.84f, 4.39f);
        return true;
    }
};

class solazeroth_v3_gouffre_joueur : public PlayerScript
{
public:
    solazeroth_v3_gouffre_joueur() : PlayerScript("solazeroth_v3_gouffre_joueur", { PLAYERHOOK_ON_BEFORE_TELEPORT }) { }

    bool OnPlayerBeforeTeleport(Player* player, uint32 carte, float /*x*/, float /*y*/, float /*z*/, float /*o*/,
        uint32 /*options*/, Unit* /*cible*/) override
    {
        if (carte != GOUFFRE || player->GetMapId() == GOUFFRE)
            return true;
        std::string refus = Refus(player);
        if (refus.empty())
            return true;
        ChatHandler(player->GetSession()).SendSysMessage(
            "Le Gouffre de Ragefeu se passe par la faille du Rocher du crâne, gardée par Ruga Brise-cendre. " + refus);
        return false;
    }
};

void AddSC_solazeroth_v3_gouffre()
{
    new npc_solazeroth_ruga();
    new solazeroth_v3_gouffre_joueur();
}
