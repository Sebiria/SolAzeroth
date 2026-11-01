// v3 (01/11/2026, demande de l'utilisateur) : signaler un bug en jeu. La touche « ! » (Interface\FrameXML\
// SolUI_Signalement.lua) note tout de suite où se trouve le personnage, puis ouvre une fenêtre pour décrire le problème.
// Les signalements vont dans acore_characters.solazeroth_v3_signalements (migration 097), pour être traités ensemble :
//   SELECT * FROM acore_characters.solazeroth_v3_signalements WHERE traite = 0;
// Commandes envoyées par l'interface :
//   .signaler debut          position, zone et cible à cet instant (avant que le joueur écrive) ;
//   .signaler texte <mots>   un morceau du texte (une ligne de discussion fait 255 caractères au plus) ;
//   .signaler fin            enregistre le signalement.

#include "SolAzeroth.h"
#include "Chat.h"
#include "DatabaseEnv.h"
#include "ObjectAccessor.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "StringFormat.h"

using namespace Acore::ChatCommands;

namespace
{
    constexpr size_t TEXTE_MAX = 4000;

    struct Signalement : DataMap::Base
    {
        bool ouvert = false;
        uint32 carte = 0, zone = 0, lieu = 0;
        float x = 0, y = 0, z = 0, o = 0;
        std::string cible;
        std::string texte;
    };

    Signalement* SignalementDe(Player* player)
    {
        return player->CustomData.GetDefault<Signalement>("solazeroth_v3_signalement");
    }

    std::string Echappe(std::string texte)
    {
        CharacterDatabase.EscapeString(texte);
        return texte;
    }
}

class solazeroth_v3_signalement_commandes : public CommandScript
{
public:
    solazeroth_v3_signalement_commandes() : CommandScript("solazeroth_v3_signalement_commandes") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable signaler =
        {
            { "debut", HandleDebut, SEC_PLAYER, Console::No },
            { "texte", HandleTexte, SEC_PLAYER, Console::No },
            { "fin",   HandleFin,   SEC_PLAYER, Console::No },
        };
        static ChatCommandTable commandes =
        {
            { "signaler", signaler },
        };
        return commandes;
    }

    static bool HandleDebut(ChatHandler* handler)
    {
        Player* player = handler->GetPlayer();
        Signalement* s = SignalementDe(player);
        s->ouvert = true;
        s->carte = player->GetMapId();
        s->zone = player->GetZoneId();
        s->lieu = player->GetAreaId();
        s->x = player->GetPositionX();
        s->y = player->GetPositionY();
        s->z = player->GetPositionZ();
        s->o = player->GetOrientation();
        s->cible.clear();
        if (Unit* cible = ObjectAccessor::GetUnit(*player, player->GetTarget()))
            s->cible = Acore::StringFormat("{} ({})", cible->GetName(), cible->GetEntry());
        s->texte.clear();
        return true;
    }

    static bool HandleTexte(ChatHandler* handler, Tail mots)
    {
        Signalement* s = SignalementDe(handler->GetPlayer());
        if (!s->ouvert)
            return true;
        if (!s->texte.empty())
            s->texte += ' ';
        s->texte += std::string(mots);
        if (s->texte.size() > TEXTE_MAX)
            s->texte.resize(TEXTE_MAX);
        return true;
    }

    static bool HandleFin(ChatHandler* handler)
    {
        Player* player = handler->GetPlayer();
        Signalement* s = SignalementDe(player);
        if (!s->ouvert || s->texte.empty())
        {
            s->ouvert = false;
            handler->SendErrorMessage("Signalement vide : rien n'a été enregistré.");
            return false;
        }
        s->ouvert = false;
        CharacterDatabase.Execute("INSERT INTO solazeroth_v3_signalements (compte, guid, personnage, niveau, carte, zone, "
            "lieu, x, y, z, o, cible, texte) VALUES ({}, {}, '{}', {}, {}, {}, {}, {}, {}, {}, {}, '{}', '{}')",
            player->GetSession()->GetAccountId(), player->GetGUID().GetCounter(), Echappe(player->GetName()),
            player->GetLevel(), s->carte, s->zone, s->lieu, s->x, s->y, s->z, s->o, Echappe(s->cible), Echappe(s->texte));
        handler->SendSysMessage("|cff8cc4a6Bug signalé, merci.|r Il sera traité avec les autres.");
        return true;
    }
};

void AddSC_solazeroth_v3_signalement()
{
    new solazeroth_v3_signalement_commandes();
}
