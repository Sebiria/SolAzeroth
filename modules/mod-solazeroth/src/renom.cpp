// Renom du compte (section 7.2, V4), validé par l'utilisateur le 28/10/2026.
// Points = 10 par heure de Codex accomplie + 5 par contrat terminé. Le Renom ne redescend jamais (le Codex peut baisser
// quand du contenu arrive) : on garde le maximum atteint dans solazeroth_renom.
// Rangs (10) et récompenses, du confort et presque pas de puissance :
//   1 sac de 16 places, 4 sac de 20, 7 sac de 22 : à réclamer, une fois par personnage, liés au personnage
//     (demande de l'utilisateur : pas de personnage créé exprès pour transférer les sacs) ;
//   2 pierre de foyer rechargée en 15 min au lieu de 30 ;
//   3 réserve de contrats +3, 6 un contrat de plus par jour (contrats.cpp) ;
//   5 affixe au menu : Fortifié ou Tyrannique au choix pour les donjons (menace.cpp) ;
//   8 et 9 : 500 puis 1 000 Marques, une fois par compte ; 10 : vol en Kalimdor et Royaumes de l'Est (V8+).
// Addon (onglet Renom du Codex, préfixe SOLRENOM) : « .solrenom liste » -> « ETAT;rang;points;seuil_suivant;affixe »,
//   « R;rang;nom;seuil;récompense;état » (0 à venir, 1 acquis, 2 à réclamer, 3 réclamé, 4 plus tard), « FIN » ;
//   « .solrenom reclamer <rang> », « .solrenom affixe <0|1|2> » ; « RANG;n » à chaque nouveau rang.

#include "SolAzeroth.h"
#include "Chat.h"
#include "DatabaseEnv.h"
#include "Item.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "Spell.h"
#include "SpellInfo.h"
#include "StringFormat.h"
#include "WorldSession.h"
#include <cmath>
#include <map>
#include <mutex>

using namespace Acore::ChatCommands;
using namespace std::chrono_literals;

namespace
{
    char const* const PREFIXE = "SOLRENOM";
    uint32 const PIERRE_DE_FOYER = 8690;

    enum Recompense : uint8 { RIEN, SAC, FOYER, RESERVE, AFFIXE, CONTRAT, MARQUES, VOL };

    struct Rang
    {
        char const* nom;
        uint32 seuil;
        Recompense type;
        uint32 valeur;       // sac : objet ; marques : nombre
        char const* texte;
    };

    Rang const RANGS[] =
    {
        { "Inconnu",     0,     RIEN,     0,     "" },
        { "Voyageur",    100,   SAC,      21841, "Sac en tisse-néant (16 places), à réclamer pour chaque personnage" },
        { "Aventurier",  300,   FOYER,    0,     "Pierre de foyer : 15 min de recharge au lieu de 30" },
        { "Explorateur", 600,   RESERVE,  0,     "Réserve de contrats : 12 au lieu de 9" },
        { "Vétéran",     1000,  SAC,      41599, "Sac en tisse-givre (20 places), à réclamer pour chaque personnage" },
        { "Renommé",     1600,  AFFIXE,   0,     "Affixe au menu : Fortifié ou Tyrannique au choix pour tes donjons" },
        { "Héros",       2500,  CONTRAT,  0,     "Un contrat de plus par jour (4 au lieu de 3)" },
        { "Champion",    4000,  SAC,      41600, "Sac glaciaire (22 places), à réclamer pour chaque personnage" },
        // Rangs 8 et 9 : 500 et 1 000 Marques avant le calibrage final (29/10/2026).
        { "Légende",     6000,  MARQUES,  250,   "250 Marques du voyageur, une fois" },
        { "Mythe",       8200,  MARQUES,  500,   "500 Marques du voyageur, une fois" },
        { "Éternel",     12000, VOL,      0,     "Vol en Kalimdor et dans les Royaumes de l'Est (plus tard, V8+)" },
    };
    uint8 const RANG_MAX = 10;

    struct Etat { uint32 points = 0; uint8 affixe = 0; uint32 marques = 0; };   // marques : rangs déjà réclamés (bits)

    std::mutex verrou;
    std::map<uint32, Etat> etats;   // par compte

    struct Minuterie : DataMap::Base { uint32 attente = 0; };

    Etat Lire(uint32 compte)
    {
        {
            std::lock_guard<std::mutex> garde(verrou);
            auto it = etats.find(compte);
            if (it != etats.end())
                return it->second;
        }
        Etat e;
        if (QueryResult r = CharacterDatabase.Query("SELECT points, affixe, marques FROM solazeroth_renom WHERE account = {}", compte))
        {
            e.points = (*r)[0].Get<uint32>();
            e.affixe = (*r)[1].Get<uint8>();
            e.marques = (*r)[2].Get<uint32>();
        }
        std::lock_guard<std::mutex> garde(verrou);
        return etats.emplace(compte, e).first->second;
    }

    void Ecrire(uint32 compte, Etat const& e)
    {
        {
            std::lock_guard<std::mutex> garde(verrou);
            etats[compte] = e;
        }
        CharacterDatabase.DirectExecute("REPLACE INTO solazeroth_renom (account, points, affixe, marques) VALUES ({}, {}, {}, {})",
            compte, e.points, e.affixe, e.marques);
    }

    uint8 RangDe(uint32 points)
    {
        uint8 rang = 0;
        while (rang < RANG_MAX && points >= RANGS[rang + 1].seuil)
            ++rang;
        return rang;
    }

    // Recalcule les points ; annonce un nouveau rang.
    void MettreAJour(Player* player)
    {
        uint32 compte = player->GetSession()->GetAccountId();
        uint32 contrats = 0;
        if (QueryResult r = CharacterDatabase.Query("SELECT valeur FROM solazeroth_compteurs WHERE account = {} AND cle = 'contrats'", compte))
            contrats = (*r)[0].Get<uint32>();
        uint32 points = uint32(std::floor(SolAzeroth::HeuresCodex(player) * 10.0f)) + 5 * contrats;

        Etat e = Lire(compte);
        if (points <= e.points)
            return;
        uint8 avant = RangDe(e.points);
        e.points = points;
        Ecrire(compte, e);
        uint8 apres = RangDe(points);
        if (apres > avant)
        {
            ChatHandler(player->GetSession()).SendSysMessage(Acore::StringFormat("|cffffd100Renom du compte : rang {}, {} !|r {}.",
                apres, RANGS[apres].nom, RANGS[apres].texte));
            SolAzeroth::EnvoyerAddon(player, PREFIXE, Acore::StringFormat("RANG;{}", apres));
        }
    }

    bool SacReclame(Player* player, uint8 rang)
    {
        return CharacterDatabase.Query("SELECT 1 FROM solazeroth_renom_sacs WHERE guid = {} AND rang = {}",
            player->GetGUID().GetCounter(), rang) != nullptr;
    }

    // 0 à venir, 1 acquis, 2 à réclamer, 3 réclamé, 4 plus tard
    uint8 EtatRecompense(Player* player, Etat const& e, uint8 rang)
    {
        Rang const& r = RANGS[rang];
        if (r.type == VOL)
            return 4;
        if (RangDe(e.points) < rang)
            return 0;
        if (r.type == SAC)
            return SacReclame(player, rang) ? 3 : 2;
        if (r.type == MARQUES)
            return (e.marques & (1u << rang)) ? 3 : 2;
        return 1;
    }

    void Envoyer(Player* player)
    {
        MettreAJour(player);
        Etat e = Lire(player->GetSession()->GetAccountId());
        uint8 rang = RangDe(e.points);
        SolAzeroth::EnvoyerAddon(player, PREFIXE, Acore::StringFormat("ETAT;{};{};{};{}", rang, e.points,
            rang < RANG_MAX ? RANGS[rang + 1].seuil : RANGS[RANG_MAX].seuil, e.affixe));
        for (uint8 i = 1; i <= RANG_MAX; ++i)
            SolAzeroth::EnvoyerAddon(player, PREFIXE, Acore::StringFormat("R;{};{};{};{};{}", i, RANGS[i].nom, RANGS[i].seuil,
                RANGS[i].texte, EtatRecompense(player, e, i)));
        SolAzeroth::EnvoyerAddon(player, PREFIXE, "FIN");
    }
}

unsigned char SolAzeroth::RangRenom(unsigned int compte)
{
    return RangDe(Lire(compte).points);
}

unsigned char SolAzeroth::AffixeChoisi(unsigned int compte)
{
    Etat e = Lire(compte);
    return RangDe(e.points) >= 5 ? e.affixe : 0;
}

class solazeroth_renom_joueur : public PlayerScript
{
public:
    solazeroth_renom_joueur() : PlayerScript("solazeroth_renom_joueur", {
        PLAYERHOOK_ON_LOGIN, PLAYERHOOK_ON_UPDATE, PLAYERHOOK_ON_SPELL_CAST }) { }

    void OnPlayerLogin(Player* player) override
    {
        MettreAJour(player);
    }

    // Recalcul toutes les 5 minutes (le Codex est mis en cache une minute).
    void OnPlayerUpdate(Player* player, uint32 temps) override
    {
        Minuterie* m = player->CustomData.GetDefault<Minuterie>("solazeroth_renom");
        m->attente += temps;
        if (m->attente < 5 * MINUTE * IN_MILLISECONDS)
            return;
        m->attente = 0;
        MettreAJour(player);
    }

    // Rang 2 : la recharge de la pierre de foyer est posée juste après le lancement ; on la réduit de 15 minutes.
    void OnPlayerSpellCast(Player* player, Spell* sort, bool /*sansVerification*/) override
    {
        if (sort->GetSpellInfo()->Id != PIERRE_DE_FOYER || SolAzeroth::RangRenom(player->GetSession()->GetAccountId()) < 2)
            return;
        player->m_Events.AddEventAtOffset([player]()
        {
            player->ModifySpellCooldown(PIERRE_DE_FOYER, -int32(15 * MINUTE * IN_MILLISECONDS));
        }, 100ms);
    }
};

class solazeroth_renom_commandes : public CommandScript
{
public:
    solazeroth_renom_commandes() : CommandScript("solazeroth_renom_commandes") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable sousCommandes =
        {
            { "liste",    HandleListe,    SEC_PLAYER, Console::No },
            { "reclamer", HandleReclamer, SEC_PLAYER, Console::No },
            { "affixe",   HandleAffixe,   SEC_PLAYER, Console::No },
        };
        static ChatCommandTable commandes =
        {
            { "solrenom", sousCommandes },
        };
        return commandes;
    }

    static bool HandleListe(ChatHandler* handler)
    {
        Envoyer(handler->GetPlayer());
        return true;
    }

    static bool HandleReclamer(ChatHandler* handler, uint8 rang)
    {
        Player* player = handler->GetPlayer();
        uint32 compte = player->GetSession()->GetAccountId();
        if (rang < 1 || rang > RANG_MAX)
            return true;
        Etat e = Lire(compte);
        if (EtatRecompense(player, e, rang) != 2)
        {
            handler->SendSysMessage("Rien à réclamer pour ce rang.");
            return true;
        }
        Rang const& r = RANGS[rang];
        if (r.type == SAC)
        {
            ItemPosCountVec dest;
            if (player->CanStoreNewItem(NULL_BAG, NULL_SLOT, dest, r.valeur, 1) != EQUIP_ERR_OK)
            {
                handler->SendSysMessage("|cffff0000Plus de place dans tes sacs.|r");
                return true;
            }
            Item* sac = player->StoreNewItem(dest, r.valeur, true);
            if (!sac)
                return true;
            // Lié au personnage : il ne peut pas être donné à un autre.
            sac->SetBinding(true);
            sac->SetState(ITEM_CHANGED, player);
            player->SendNewItem(sac, 1, true, false);
            CharacterDatabase.DirectExecute("INSERT IGNORE INTO solazeroth_renom_sacs (guid, rang) VALUES ({}, {})",
                player->GetGUID().GetCounter(), rang);
        }
        else if (r.type == MARQUES)
        {
            if (!SolAzeroth::DonnerMarques(player, r.valeur, "Renom"))
                return true;
            e.marques |= 1u << rang;
            Ecrire(compte, e);
        }
        Envoyer(player);
        return true;
    }

    static bool HandleAffixe(ChatHandler* handler, uint8 affixe)
    {
        Player* player = handler->GetPlayer();
        uint32 compte = player->GetSession()->GetAccountId();
        Etat e = Lire(compte);
        if (RangDe(e.points) < 5 || affixe > 2)
        {
            handler->SendSysMessage("L'affixe au menu demande le rang de Renom 5.");
            return true;
        }
        e.affixe = affixe;
        Ecrire(compte, e);
        char const* const noms[] = { "celui de la semaine", "Fortifié", "Tyrannique" };
        handler->SendSysMessage(Acore::StringFormat("Affixe de tes prochains donjons : {}.", noms[affixe]));
        Envoyer(player);
        return true;
    }
};

void AddSC_solazeroth_renom()
{
    new solazeroth_renom_joueur();
    new solazeroth_renom_commandes();
}
