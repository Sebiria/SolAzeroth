// v3, F10 (01/11/2026) : l'âme, à la manière de Dofus (document v3, « L'âme » ; chiffres validés par l'utilisateur,
// rythme simulé par outils\simulation_ame.py).
// - Chaque personnage a AME_MAX points d'âme (acore_characters.solazeroth_v3_ame, migration 088 ; sans ligne, l'âme est
//   pleine). Chaque mort en coûte 1 + puissance / 15, au plus PERTE_MAX : presque rien à Durotar, 10 en fin de jeu.
//   Le retour à la pierre de foyer de F5a (v3_mort.cpp) ne change pas. Champs de bataille et personnages Hardcore
//   gardent leur règle.
// - Régénérer coûte ECLATS_PAR_POINT éclats cadavériques par point, multipliés comme le prix des rangs
//   (1 + (puissance - 12) / 12 au-delà de 12), pris dans la Collection. Seulement en zone de repos (auberge ou ville) :
//   .ame regenerer rend autant de points que les éclats le permettent, jusqu'au maximum.
// - À zéro, l'âme est éteinte : le personnage est immobilisé, prévenu, puis déconnecté au bout de 5 s ; chaque
//   connexion suivante fait de même. Le joueur le supprime lui-même. .ame fixer <nom> <valeur> (MJ) le déverrouille
//   après une mort due à un bogue, même hors ligne.
// L'interface (SolUI_Perso.lua) reçoit « AME;âme;maximum;perte à la prochaine mort;éclats par point;repos (0/1) » et
// « ETEINTE » (message SOLAME), à la connexion, à chaque changement, et toutes les 10 s.

#include "SolAzeroth.h"
#include "ChallengeModes.h"
#include "Chat.h"
#include "CommandScript.h"
#include "DatabaseEnv.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "StringFormat.h"
#include "WorldSession.h"
#include <algorithm>

using namespace Acore::ChatCommands;

namespace
{
    char const* const PREFIXE = "SOLAME";
    uint32 const ECLAT = 910120;
    uint32 const AME_MAX = 100;
    uint32 const PERTE_MAX = 10;
    float const PUISSANCE_PAR_PERTE = 15.0f;
    float const ECLATS_PAR_POINT = 4.0f;
    uint32 const DELAI_EXPULSION = 5000;
    uint32 const TICK_ENVOI = 2000;

    struct Ame : DataMap::Base
    {
        uint32 valeur = AME_MAX;
        uint32 morts = 0;
        uint32 attente = 0;
        uint8 renvoi = 0;
        int32 expulsion = -1;   // ms avant la déconnexion d'une âme éteinte (-1 : aucune ; 0 : déjà expulsé)
        std::string affiche;
    };

    Ame* AmeDe(Player* player)
    {
        return player->CustomData.GetDefault<Ame>("solazeroth_v3_ame");
    }

    uint32 Perte(Player* player)
    {
        return std::min(PERTE_MAX, 1 + uint32(SolAzeroth::PuissanceJoueur(player) / PUISSANCE_PAR_PERTE));
    }

    uint32 PrixPoint(Player* player)
    {
        float facteur = 1.0f + std::max(0.0f, SolAzeroth::PuissanceJoueur(player) - 12.0f) / 12.0f;
        return uint32(ECLATS_PAR_POINT * facteur + 0.5f);
    }

    bool EnRepos(Player* player)
    {
        return player->HasRestFlag(REST_FLAG_IN_TAVERN) || player->HasRestFlag(REST_FLAG_IN_CITY);
    }

    void Sauver(ObjectGuid::LowType guid, uint32 valeur, uint32 morts)
    {
        CharacterDatabase.DirectExecute(Acore::StringFormat(
            "REPLACE INTO solazeroth_v3_ame (guid, ame, morts) VALUES ({}, {}, {})", guid, valeur, morts));
    }

    void Envoyer(Player* player, bool force = false)
    {
        Ame* a = AmeDe(player);
        std::string message = Acore::StringFormat("AME;{};{};{};{};{}", a->valeur, AME_MAX, Perte(player),
            PrixPoint(player), EnRepos(player) ? 1 : 0);
        if (!force && message == a->affiche)
            return;
        a->affiche = message;
        SolAzeroth::EnvoyerAddon(player, PREFIXE, message);
    }

    // Âme à zéro : le personnage ne peut plus rien faire, et part au bout de DELAI_EXPULSION.
    void Eteindre(Player* player)
    {
        Ame* a = AmeDe(player);
        if (a->expulsion >= 0)
            return;
        a->expulsion = DELAI_EXPULSION;
        player->SetClientControl(player, false);
        player->SetUnitFlag(UNIT_FLAG_PACIFIED);
        player->SetUnitFlag(UNIT_FLAG_SILENCED);
        SolAzeroth::EnvoyerAddon(player, PREFIXE, "ETEINTE");
        ChatHandler(player->GetSession()).SendSysMessage(
            "|cffc9483eÂme éteinte.|r Ce personnage ne peut plus jouer : supprime-le depuis la liste des personnages.");
    }

    bool Hardcore(Player* player)
    {
        return sChallengeModes->challengeEnabledForPlayer(SETTING_HARDCORE, player);
    }
}

class solazeroth_v3_ame : public PlayerScript
{
public:
    solazeroth_v3_ame() : PlayerScript("solazeroth_v3_ame",
        { PLAYERHOOK_ON_LOGIN, PLAYERHOOK_ON_PLAYER_JUST_DIED, PLAYERHOOK_ON_UPDATE }) { }

    void OnPlayerLogin(Player* player) override
    {
        Ame* a = AmeDe(player);
        if (QueryResult resultat = CharacterDatabase.Query("SELECT ame, morts FROM solazeroth_v3_ame WHERE guid = {}",
            player->GetGUID().GetCounter()))
        {
            a->valeur = (*resultat)[0].Get<uint32>();
            a->morts = (*resultat)[1].Get<uint32>();
        }
        Envoyer(player, true);
        if (a->valeur == 0)
            Eteindre(player);
    }

    void OnPlayerJustDied(Player* player) override
    {
        if (player->GetBattleground() || Hardcore(player))
            return;
        Ame* a = AmeDe(player);
        if (a->valeur == 0)
            return;
        uint32 perte = std::min(a->valeur, Perte(player));
        a->valeur -= perte;
        ++a->morts;
        Sauver(player->GetGUID().GetCounter(), a->valeur, a->morts);
        ChatHandler(player->GetSession()).PSendSysMessage("|cffb48ce6Âme : -{} ({} / {}).|r", perte, a->valeur, AME_MAX);
        Envoyer(player, true);
        if (a->valeur == 0)
            Eteindre(player);
    }

    void OnPlayerUpdate(Player* player, uint32 diff) override
    {
        Ame* a = AmeDe(player);
        if (a->expulsion >= 0)
        {
            if (a->expulsion > 0)
            {
                a->expulsion -= std::min(a->expulsion, int32(diff));
                if (a->expulsion == 0)   // reste à 0 (« éteinte ») jusqu'à la déconnexion
                    player->GetSession()->KickPlayer("Âme éteinte");
            }
            return;
        }
        a->attente += diff;
        if (a->attente < TICK_ENVOI)
            return;
        a->attente = 0;
        // Renvoi complet toutes les 10 s : l'interface retrouve son état après un /reload.
        bool force = ++a->renvoi >= 5;
        if (force)
            a->renvoi = 0;
        Envoyer(player, force);
    }
};

class solazeroth_v3_ame_commandes : public CommandScript
{
public:
    solazeroth_v3_ame_commandes() : CommandScript("solazeroth_v3_ame_commandes") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable ame =
        {
            { "",          HandleEtat,      SEC_PLAYER,     Console::No },
            { "regenerer", HandleRegenerer, SEC_PLAYER,     Console::No },
            { "fixer",     HandleFixer,     SEC_GAMEMASTER, Console::Yes },
        };
        static ChatCommandTable commandes =
        {
            { "ame", ame },
        };
        return commandes;
    }

    // .ame : état de l'âme (et renvoi à l'interface).
    static bool HandleEtat(ChatHandler* handler)
    {
        Player* player = handler->GetPlayer();
        Ame* a = AmeDe(player);
        handler->PSendSysMessage("Âme : {} / {} ({} morts). Prochaine mort : -{}. Régénération : {} éclats par point, "
            "en auberge ou en ville.", a->valeur, AME_MAX, a->morts, Perte(player), PrixPoint(player));
        Envoyer(player, true);
        return true;
    }

    // .ame regenerer : autant de points que les éclats de la Collection le permettent, jusqu'au maximum.
    static bool HandleRegenerer(ChatHandler* handler)
    {
        Player* player = handler->GetPlayer();
        Ame* a = AmeDe(player);
        if (a->valeur == 0)
            return false;
        if (a->valeur >= AME_MAX)
        {
            handler->SendErrorMessage("Ton âme est déjà entière.");
            return false;
        }
        if (!EnRepos(player))
        {
            handler->SendErrorMessage("L'âme se régénère en auberge ou en ville.");
            return false;
        }
        uint32 prix = PrixPoint(player), eclats = SolAzeroth::NombreEnCollection(player, ECLAT);
        uint32 points = std::min(AME_MAX - a->valeur, eclats / prix);
        if (!points)
        {
            handler->SendErrorMessage("Il faut {} éclats cadavériques par point d'âme (tu en as {}).", prix, eclats);
            return false;
        }
        SolAzeroth::RetirerDeCollection(player, ECLAT, points * prix);
        a->valeur += points;
        Sauver(player->GetGUID().GetCounter(), a->valeur, a->morts);
        handler->PSendSysMessage("|cffb48ce6Âme : +{} ({} / {}), pour {} éclats.|r", points, a->valeur, AME_MAX,
            points * prix);
        Envoyer(player, true);
        return true;
    }

    // .ame fixer <nom> <valeur> (MJ) : fixe l'âme, même hors ligne ; au-dessus de 0, le personnage est déverrouillé.
    static bool HandleFixer(ChatHandler* handler, PlayerIdentifier cible, uint32 valeur)
    {
        valeur = std::min(valeur, AME_MAX);
        uint32 morts = 0;
        if (Player* player = cible.GetConnectedPlayer())
        {
            Ame* a = AmeDe(player);
            a->valeur = valeur;
            morts = a->morts;
            if (valeur == 0)
                Eteindre(player);
            else
            {
                if (a->expulsion >= 0)   // déverrouillé avant la déconnexion
                {
                    a->expulsion = -1;
                    player->SetClientControl(player, true);
                    player->RemoveUnitFlag(UNIT_FLAG_PACIFIED);
                    player->RemoveUnitFlag(UNIT_FLAG_SILENCED);
                }
                Envoyer(player, true);
            }
        }
        else if (QueryResult resultat = CharacterDatabase.Query("SELECT morts FROM solazeroth_v3_ame WHERE guid = {}",
            cible.GetGUID().GetCounter()))
            morts = (*resultat)[0].Get<uint32>();
        Sauver(cible.GetGUID().GetCounter(), valeur, morts);
        handler->PSendSysMessage("Âme de {} : {} / {}.", cible.GetName(), valeur, AME_MAX);
        return true;
    }
};

void AddSC_solazeroth_v3_ame()
{
    new solazeroth_v3_ame();
    new solazeroth_v3_ame_commandes();
}
