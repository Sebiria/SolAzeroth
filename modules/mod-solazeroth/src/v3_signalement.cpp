// v3 (01/11/2026, demande de l'utilisateur) : signaler un bug en jeu. La touche « ! » (Interface\FrameXML\
// SolUI_Signalement.lua) note tout de suite où se trouve le personnage, puis ouvre une fenêtre pour décrire le problème.
// Les signalements vont dans acore_characters.solazeroth_v3_signalements (migration 097), pour être traités ensemble :
//   SELECT * FROM acore_characters.solazeroth_v3_signalements WHERE traite = 0;
// Commandes envoyées par l'interface :
//   .signaler debut          position, zone et cible à cet instant (avant que le joueur écrive) ;
//   .signaler texte <mots>   un morceau du texte (une ligne de discussion fait 255 caractères au plus) ;
//   .signaler fin            enregistre le signalement ;
//   .signaler liste          les signalements pas encore exportés, dans la discussion ;
//   .signaler exporter       demande au lanceur d'écrire le fichier .txt à envoyer (version publique, 02/11/2026).
// Export (migration 131) : le serveur pose runtime\signalements_export.flag ; le lanceur (scripts\signalements.ps1)
// ouvre « Enregistrer sous », écrit le fichier puis supprime les signalements exportés (ou les marque exporte = 1 sur
// l'installation de développement) ; il laisse son compte rendu dans runtime\signalements_resultat.txt, relayé ici.
// Message SOLSIGNAL « N;nombre » : signalements en attente d'export, pour la fenêtre.

#include "SolAzeroth.h"
#include "Chat.h"
#include "DatabaseEnv.h"
#include "DBCStores.h"
#include "ObjectAccessor.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "StringFormat.h"
#include "WorldSession.h"
#include "WorldSessionMgr.h"
#include <filesystem>
#include <fstream>
#include <sstream>

using namespace Acore::ChatCommands;

namespace
{
    constexpr size_t TEXTE_MAX = 4000;
    constexpr uint32 SCRUTATION = 2000;  // ms entre deux regards sur le compte rendu du lanceur

    struct Signalement : DataMap::Base
    {
        bool ouvert = false;
        uint32 carte = 0, zone = 0, lieu = 0;
        float x = 0, y = 0, z = 0, o = 0;
        std::string cible;
        std::string nomLieu;
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

    std::string Runtime(char const* nom)
    {
        return SolAzeroth::DossierRacine() + "/runtime/" + nom;
    }

    uint32 EnAttente()
    {
        if (QueryResult r = CharacterDatabase.Query("SELECT COUNT(*) FROM solazeroth_v3_signalements WHERE exporte = 0"))
            return r->Fetch()[0].Get<uint32>();
        return 0;
    }

    void EnvoyerNombre(Player* player, uint32 nombre)
    {
        SolAzeroth::EnvoyerAddon(player, "SOLSIGNAL", Acore::StringFormat("N;{}", nombre));
    }

    std::string NomLieu(Player* player, LocaleConstant langue)
    {
        auto nom = [langue](uint32 id) -> std::string
        {
            AreaTableEntry const* a = sAreaTableStore.LookupEntry(id);
            return a && a->area_name[langue] ? a->area_name[langue] : "";
        };
        std::string zone = nom(player->GetZoneId());
        std::string lieu = nom(player->GetAreaId());
        if (lieu.empty() || lieu == zone)
            return zone;
        return zone.empty() ? lieu : zone + " - " + lieu;
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
            { "debut",    HandleDebut,    SEC_PLAYER, Console::No },
            { "texte",    HandleTexte,    SEC_PLAYER, Console::No },
            { "fin",      HandleFin,      SEC_PLAYER, Console::No },
            { "liste",    HandleListe,    SEC_PLAYER, Console::No },
            { "exporter", HandleExporter, SEC_PLAYER, Console::No },
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
        s->nomLieu = NomLieu(player, handler->GetSessionDbcLocale());
        s->cible.clear();
        if (Unit* cible = ObjectAccessor::GetUnit(*player, player->GetTarget()))
            s->cible = Acore::StringFormat("{} ({})", cible->GetName(), cible->GetEntry());
        s->texte.clear();
        EnvoyerNombre(player, EnAttente());
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
        CharacterDatabase.DirectExecute(Acore::StringFormat("INSERT INTO solazeroth_v3_signalements (compte, guid, "
            "personnage, niveau, classe, carte, zone, lieu, nom_lieu, x, y, z, o, cible, texte) VALUES ({}, {}, '{}', {}, "
            "{}, {}, {}, {}, '{}', {}, {}, {}, {}, '{}', '{}')",
            player->GetSession()->GetAccountId(), player->GetGUID().GetCounter(), Echappe(player->GetName()),
            player->GetLevel(), player->getClass(), s->carte, s->zone, s->lieu, Echappe(s->nomLieu), s->x, s->y, s->z,
            s->o, Echappe(s->cible), Echappe(s->texte)));
        uint32 nombre = EnAttente();
        handler->PSendSysMessage("|cff8cc4a6Bug signalé, merci.|r {} signalement(s) en attente : touche « ! » puis "
            "Exporter pour en faire un fichier à envoyer.", nombre);
        EnvoyerNombre(player, nombre);
        return true;
    }

    static bool HandleListe(ChatHandler* handler)
    {
        QueryResult r = CharacterDatabase.Query("SELECT id, DATE_FORMAT(quand, '%d/%m %H:%i'), nom_lieu, texte "
            "FROM solazeroth_v3_signalements WHERE exporte = 0 ORDER BY id");
        if (!r)
        {
            handler->SendSysMessage("Aucun signalement en attente.");
            return true;
        }
        handler->PSendSysMessage("|cff8cc4a6{} signalement(s) en attente d'export :|r", r->GetRowCount());
        uint32 montres = 0;
        do
        {
            if (++montres > 20)
            {
                handler->PSendSysMessage("… et {} autre(s).", r->GetRowCount() - 20);
                break;
            }
            Field* f = r->Fetch();
            std::string texte = f[3].Get<std::string>();
            if (texte.size() > 90)
                texte = texte.substr(0, 87) + "...";
            std::string lieu = f[2].Get<std::string>();
            handler->PSendSysMessage("  #{} {}{} : {}", f[0].Get<uint32>(), f[1].Get<std::string>(),
                lieu.empty() ? "" : " - " + lieu, texte);
        } while (r->NextRow());
        return true;
    }

    static bool HandleExporter(ChatHandler* handler)
    {
        if (EnAttente() == 0)
        {
            handler->SendSysMessage("Aucun signalement à exporter.");
            return true;
        }
        std::ofstream flag(Runtime("signalements_export.flag"));
        if (!flag)
        {
            handler->SendErrorMessage("Export impossible : le dossier runtime de l'installation est introuvable.");
            return false;
        }
        flag << "export\n";
        handler->SendSysMessage("|cff8cc4a6Export demandé.|r Une fenêtre Windows « Enregistrer sous » va s'ouvrir : "
            "si tu ne la vois pas, elle est derrière le jeu (Alt+Tab).");
        return true;
    }
};

// Compte rendu du lanceur après un export : relayé aux joueurs connectés, avec le nouveau nombre en attente.
class solazeroth_v3_signalement_monde : public WorldScript
{
public:
    solazeroth_v3_signalement_monde() : WorldScript("solazeroth_v3_signalement_monde", { WORLDHOOK_ON_UPDATE }) { }

    void OnUpdate(uint32 diff) override
    {
        _attente += diff;
        if (_attente < SCRUTATION)
            return;
        _attente = 0;

        std::string chemin = Runtime("signalements_resultat.txt");
        std::error_code erreur;
        if (!std::filesystem::exists(chemin, erreur))
            return;
        std::string message;
        {
            std::ifstream f(chemin);
            std::ostringstream lu;
            lu << f.rdbuf();
            message = lu.str();
        }
        std::filesystem::remove(chemin, erreur);
        while (!message.empty() && (message.back() == '\n' || message.back() == '\r'))
            message.pop_back();
        if (message.empty())
            return;

        uint32 nombre = EnAttente();
        for (auto const& [id, session] : sWorldSessionMgr->GetAllSessions())
            if (Player* player = session ? session->GetPlayer() : nullptr)
            {
                ChatHandler(session).SendSysMessage("|cff8cc4a6Signalements :|r " + message);
                EnvoyerNombre(player, nombre);
            }
    }

private:
    uint32 _attente = 0;
};

void AddSC_solazeroth_v3_signalement()
{
    new solazeroth_v3_signalement_commandes();
    new solazeroth_v3_signalement_monde();
}
