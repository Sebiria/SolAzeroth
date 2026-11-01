// v3 (01/11/2026, demande de l'utilisateur) : rang d'aventurier et montures (proposition validée le 01/11/2026,
// « Rang d'aventurier et montures — proposition.md » ; paliers et montures : outils\montures_v3.py, migration 092).
// - Rang de compte, alimenté par tous ses personnages : chaque objectif ne rapporte qu'une fois par compte
//   (acore_characters.solazeroth_v3_aventurier). Aucune puissance : confort, modes, montures, titres, mascottes.
//   Remplace le Renom de la v2 (renom.cpp n'est plus chargé en v3).
// - Points de base : quête d'histoire 10, sous-zone 2, lieu nettoyé 20, annexe 25 (+10 pour une médaille d'or), relique
//   10, zone à 60 % 50 et à 100 % 300, donjon terminé (dernier boss tué) 150. Ils croissent avec la zone :
//   × (1 + puissance haute conseillée / 100) ; pour un donjon, la puissance de son dernier boss. Durotar à 100 % et le
//   Gouffre de Ragefeu donnent environ 2 000 points : la première monture arrive juste après (choix de l'utilisateur,
//   « Monture après Durotar »).
// - 40 paliers jusqu'à 20 000 (solazeroth_v3_aventurier_paliers) : titres, pierre de foyer (30 min de base, sort
//   8690), mascottes, modes de zone (difficile au palier 5, cauchemar au 9 : v3_modes.cpp), monte au palier 10 (Apprenti
//   cavalier 33388 et une monture à 60 % offerte, selon la faction), puis chaque vitesse de monture.
// - Montures : plus de vente ni de formation (migration 092). Avant le palier 10, on ne peut pas monter ; les montures
//   volantes ne se lancent pas. Boutique en Marques du voyageur (solazeroth_v3_montures, .monture acheter <sort>) :
//   les montures achetées sont au compte et apprises à chaque connexion.
// - Interface (SolUI_Aventurier.lua, préfixe SOLAVENT) : « RANG;points;palier », puis « POSSEDE;sort,sort,… » (par
//   morceaux, à ajouter), puis « FIN » ; « PALIER;palier » quand un palier est atteint.

#include "SolAzeroth.h"
#include "Chat.h"
#include "Creature.h"
#include "DatabaseEnv.h"
#include "DBCStores.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "Spell.h"
#include "SpellInfo.h"
#include "StringFormat.h"
#include "WorldSession.h"
#include <cmath>
#include <set>
#include <unordered_map>
#include <vector>

using namespace Acore::ChatCommands;

namespace
{
    // Genres d'objectif : 1 à 5 comme solazeroth_v3_zone_parts, puis les nôtres.
    uint8 const QUETE = 1, EXPLORATION = 2, LIEU = 3, ANNEXE = 4, RELIQUE = 5, MEDAILLE_OR = 6, DONJON = 7,
                ZONE_60 = 8, ZONE_100 = 9, OFFERTE = 10;
    uint32 const POINTS[] = { 0, 10, 2, 20, 25, 10, 10, 150, 50, 300, 0 };

    // Récompenses (montures_v3.py).
    enum Recompense : uint8 { RIEN, TITRE, FOYER, MASCOTTE, MODE, MONTE, VITESSE_OUVERTE, DIFFICULTE_DONJON };
    uint32 const TITRE_FINAL = 85;                       // « %s le suprême », avec le dernier palier
    uint32 const APPRENTI_CAVALIER = 33388;
    uint32 const OFFERTE_HORDE = 580, OFFERTE_ALLIANCE = 458;
    uint32 const PIERRE_DE_FOYER = 8690, FOYER_BASE = 30;  // minutes
    uint8 const PALIER_MONTE = 10;
    uint32 const BALAYAGE = 5 * IN_MILLISECONDS;

    struct Palier
    {
        uint32 points;
        uint8 genre;
        uint32 valeur;
    };
    std::vector<Palier> paliers;
    std::unordered_map<uint32, std::pair<uint8, uint32>> catalogue;   // sort -> (vitesse, prix)

    struct Compte
    {
        uint32 points = 0;
        std::set<uint64> faits;
        std::set<uint32> montures;
    };
    std::unordered_map<uint32, Compte> comptes;

    struct Minuterie : DataMap::Base
    {
        uint32 attente = 3 * IN_MILLISECONDS;
        bool envoye = false;
    };

    uint64 Cle(uint8 genre, uint32 cle) { return (uint64(genre) << 32) | cle; }

    Compte& CompteDe(uint32 compte)
    {
        auto it = comptes.find(compte);
        if (it != comptes.end())
            return it->second;
        Compte& c = comptes[compte];
        if (QueryResult r = CharacterDatabase.Query("SELECT genre, cle, points FROM solazeroth_v3_aventurier WHERE compte = {}", compte))
        {
            do
            {
                Field* f = r->Fetch();
                c.faits.insert(Cle(f[0].Get<uint8>(), f[1].Get<uint32>()));
                c.points += f[2].Get<uint32>();
            } while (r->NextRow());
        }
        if (QueryResult r = CharacterDatabase.Query("SELECT sort FROM solazeroth_v3_montures_compte WHERE compte = {}", compte))
        {
            do
                c.montures.insert((*r)[0].Get<uint32>());
            while (r->NextRow());
        }
        return c;
    }

    Compte& CompteDe(Player* player) { return CompteDe(player->GetSession()->GetAccountId()); }

    uint8 PalierDe(uint32 points)
    {
        uint8 n = 0;
        for (Palier const& p : paliers)
            if (points >= p.points)
                ++n;
        return n;
    }

    uint8 PalierDe(Player* player) { return PalierDe(CompteDe(player).points); }

    // Plus haute valeur des récompenses d'un genre atteintes (0 sans).
    uint32 Meilleure(uint8 palier, uint8 genre)
    {
        uint32 v = 0;
        for (uint8 i = 0; i < palier && i < paliers.size(); ++i)
            if (paliers[i].genre == genre)
                v = std::max(v, paliers[i].valeur);
        return v;
    }

    uint32 VitesseOuverte(uint8 palier)
    {
        return std::max(Meilleure(palier, MONTE), Meilleure(palier, VITESSE_OUVERTE));
    }

    uint32 MinutesFoyer(uint8 palier)
    {
        uint32 m = FOYER_BASE;
        for (uint8 i = 0; i < palier && i < paliers.size(); ++i)
            if (paliers[i].genre == FOYER)
                m = std::min(m, paliers[i].valeur);
        return m;
    }

    void Envoyer(Player* player)
    {
        Compte& c = CompteDe(player);
        SolAzeroth::EnvoyerAddon(player, "SOLAVENT", Acore::StringFormat("RANG;{};{}", c.points, uint32(PalierDe(c.points))));
        std::string morceau;
        for (uint32 sort : c.montures)
        {
            morceau += (morceau.empty() ? "" : ",") + std::to_string(sort);
            if (morceau.size() > 200)
            {
                SolAzeroth::EnvoyerAddon(player, "SOLAVENT", "POSSEDE;" + morceau);
                morceau.clear();
            }
        }
        if (!morceau.empty())
            SolAzeroth::EnvoyerAddon(player, "SOLAVENT", "POSSEDE;" + morceau);
        SolAzeroth::EnvoyerAddon(player, "SOLAVENT", "FIN");
    }

    void AjouterMonture(Player* player, uint32 sort)
    {
        uint32 compte = player->GetSession()->GetAccountId();
        if (CompteDe(compte).montures.insert(sort).second)
            CharacterDatabase.Execute("INSERT IGNORE INTO solazeroth_v3_montures_compte (compte, sort) VALUES ({}, {})", compte, sort);
        if (!player->HasSpell(sort))
            player->learnSpell(sort, false);
    }

    // Récompenses des paliers atteints (sans effet si déjà données) et montures du compte.
    void Appliquer(Player* player)
    {
        Compte& c = CompteDe(player);
        uint8 palier = PalierDe(c.points);
        for (uint8 i = 0; i < palier && i < paliers.size(); ++i)
        {
            Palier const& p = paliers[i];
            if (p.genre == TITRE || (i + 1 == paliers.size()))
                if (CharTitlesEntry const* titre = sCharTitlesStore.LookupEntry(p.genre == TITRE ? p.valeur : TITRE_FINAL))
                    if (!player->HasTitle(titre))
                        player->SetTitle(titre);
            if (p.genre == MASCOTTE && !player->HasSpell(p.valeur))
                player->learnSpell(p.valeur, false);
            if (p.genre == MONTE)
            {
                if (!player->HasSpell(APPRENTI_CAVALIER))
                    player->learnSpell(APPRENTI_CAVALIER, false);
                if (c.faits.insert(Cle(OFFERTE, 0)).second)
                {
                    CharacterDatabase.Execute("INSERT IGNORE INTO solazeroth_v3_aventurier (compte, genre, cle, points) "
                        "VALUES ({}, {}, 0, 0)", player->GetSession()->GetAccountId(), OFFERTE);
                    AjouterMonture(player, player->GetTeamId() == TEAM_HORDE ? OFFERTE_HORDE : OFFERTE_ALLIANCE);
                }
            }
        }
        for (uint32 sort : c.montures)
            if (!player->HasSpell(sort))
                player->learnSpell(sort, false);
    }

    // Objectif atteint : ses points, la première fois pour le compte. Rend les points gagnés.
    uint32 Compter(Player* player, uint8 genre, uint32 cle, uint8 puissance)
    {
        Compte& c = CompteDe(player);
        if (!c.faits.insert(Cle(genre, cle)).second)
            return 0;
        uint32 points = uint32(std::lround(POINTS[genre] * (1.0f + puissance / 100.0f)));
        c.points += points;
        CharacterDatabase.Execute("INSERT IGNORE INTO solazeroth_v3_aventurier (compte, genre, cle, points) VALUES ({}, {}, {}, {})",
            player->GetSession()->GetAccountId(), genre, cle, points);
        return points;
    }

    void Gagner(Player* player, uint32 gain, uint8 avant)
    {
        if (!gain)
            return;
        uint32 total = CompteDe(player).points;
        ChatHandler(player->GetSession()).PSendSysMessage("|cffffd100Rang d'aventurier : +{} points ({}).|r", gain, total);
        uint8 apres = PalierDe(total);
        for (uint8 n = avant + 1; n <= apres; ++n)
        {
            ChatHandler(player->GetSession()).PSendSysMessage("|cffffd100Rang d'aventurier : palier {} atteint !|r", n);
            SolAzeroth::EnvoyerAddon(player, "SOLAVENT", Acore::StringFormat("PALIER;{}", n));
        }
        if (apres > avant)
            Appliquer(player);
        Envoyer(player);
    }

    void Balayer(Player* player)
    {
        uint8 avant = PalierDe(player);
        uint32 gain = 0;
        SolAzeroth::ObjectifsAcquis(player, [&](unsigned int zone, unsigned char genre, unsigned int cle)
        {
            uint8 puissance = SolAzeroth::PuissanceHauteZone(zone);
            gain += Compter(player, genre, cle, puissance);
            if (genre == ANNEXE && SolAzeroth::MedailleDefi(player, cle) == 3)
                gain += Compter(player, MEDAILLE_OR, cle, puissance);
        });
        for (uint32 zone : SolAzeroth::ZonesAvecParts())
        {
            uint32 pourcent = SolAzeroth::PourcentZone(player, zone);
            uint8 puissance = SolAzeroth::PuissanceHauteZone(zone);
            if (pourcent >= 6000)
                gain += Compter(player, ZONE_60, zone, puissance);
            if (pourcent >= 10000)
                gain += Compter(player, ZONE_100, zone, puissance);
        }
        Gagner(player, gain, avant);
    }
}

unsigned char SolAzeroth::ModesOuverts(Player* player)
{
    return uint8(Meilleure(PalierDe(player), MODE));
}

class solazeroth_v3_aventurier_joueur : public PlayerScript
{
public:
    solazeroth_v3_aventurier_joueur() : PlayerScript("solazeroth_v3_aventurier_joueur", {
        PLAYERHOOK_ON_LOGIN, PLAYERHOOK_ON_UPDATE, PLAYERHOOK_ON_CREATURE_KILL, PLAYERHOOK_ON_SPELL_CAST }) { }

    void OnPlayerLogin(Player* player) override
    {
        Appliquer(player);
    }

    void OnPlayerUpdate(Player* player, uint32 diff) override
    {
        Minuterie* m = player->CustomData.GetDefault<Minuterie>("solazeroth_v3_aventurier");
        if (m->attente > diff)
        {
            m->attente -= diff;
            return;
        }
        m->attente = BALAYAGE;
        if (!player->IsInWorld())
            return;
        Balayer(player);
        if (!m->envoye)
        {
            m->envoye = true;
            Envoyer(player);
        }
    }

    // Donjon terminé : son dernier boss tué.
    void OnPlayerCreatureKill(Player* player, Creature* creature) override
    {
        if (!player->GetMap()->IsDungeon() || !SolAzeroth::EstBossFinal(creature->GetEntry()))
            return;
        uint8 avant = PalierDe(player);
        Gagner(player, Compter(player, DONJON, player->GetMapId(), SolAzeroth::PuissanceCreature(creature)), avant);
    }

    // La recharge de la pierre de foyer est posée juste après le lancement ; on la réduit selon le palier.
    void OnPlayerSpellCast(Player* player, Spell* sort, bool /*sansVerification*/) override
    {
        if (sort->GetSpellInfo()->Id != PIERRE_DE_FOYER)
            return;
        uint32 reduction = FOYER_BASE - MinutesFoyer(PalierDe(player));
        if (!reduction)
            return;
        player->m_Events.AddEventAtOffset([player, reduction]()
        {
            player->ModifySpellCooldown(PIERRE_DE_FOYER, -int32(reduction * MINUTE * IN_MILLISECONDS));
        }, 100ms);
    }
};

// Pas de monte avant le palier 10, jamais de monture volante.
class solazeroth_v3_aventurier_sorts : public AllSpellScript
{
public:
    solazeroth_v3_aventurier_sorts() : AllSpellScript("solazeroth_v3_aventurier_sorts", { ALLSPELLHOOK_ON_SPELL_CHECK_CAST }) { }

    void OnSpellCheckCast(Spell* spell, bool /*strict*/, SpellCastResult& res) override
    {
        Player* player = spell->GetCaster() ? spell->GetCaster()->ToPlayer() : nullptr;
        SpellInfo const* info = spell->GetSpellInfo();
        if (!player || player->IsGameMaster() || !info->HasAura(SPELL_AURA_MOUNTED))
            return;
        if (info->HasAura(SPELL_AURA_MOD_INCREASE_MOUNTED_FLIGHT_SPEED) || info->HasAura(SPELL_AURA_FLY))
            res = SPELL_FAILED_NOT_HERE;
        else if (PalierDe(player) < PALIER_MONTE)
        {
            res = SPELL_FAILED_NOT_HERE;
            ChatHandler(player->GetSession()).SendSysMessage("La monte s'ouvre au palier 10 du rang d'aventurier.");
        }
    }
};

class solazeroth_v3_aventurier_monde : public WorldScript
{
public:
    solazeroth_v3_aventurier_monde() : WorldScript("solazeroth_v3_aventurier_monde", { WORLDHOOK_ON_STARTUP }) { }

    void OnStartup() override
    {
        paliers.clear();
        catalogue.clear();
        if (QueryResult r = WorldDatabase.Query("SELECT points, genre, valeur FROM solazeroth_v3_aventurier_paliers ORDER BY palier"))
        {
            do
            {
                Field* f = r->Fetch();
                paliers.push_back({ f[0].Get<uint32>(), f[1].Get<uint8>(), f[2].Get<uint32>() });
            } while (r->NextRow());
        }
        if (QueryResult r = WorldDatabase.Query("SELECT sort, vitesse, prix FROM solazeroth_v3_montures"))
        {
            do
            {
                Field* f = r->Fetch();
                catalogue[f[0].Get<uint32>()] = { f[1].Get<uint8>(), f[2].Get<uint32>() };
            } while (r->NextRow());
        }
        LOG_INFO("module", ">> Sol'Azeroth v3 : rang d'aventurier, {} paliers et {} montures en boutique",
            paliers.size(), catalogue.size());
    }
};

class solazeroth_v3_aventurier_commandes : public CommandScript
{
public:
    solazeroth_v3_aventurier_commandes() : CommandScript("solazeroth_v3_aventurier_commandes") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable monture =
        {
            { "acheter", HandleAcheter, SEC_PLAYER, Console::No },
        };
        static ChatCommandTable commandes =
        {
            { "aventurier", HandleEtat, SEC_PLAYER, Console::No },
            { "monture", monture },
        };
        return commandes;
    }

    // .aventurier : points et palier (et renvoi à l'interface).
    static bool HandleEtat(ChatHandler* handler)
    {
        Player* player = handler->GetPlayer();
        Compte& c = CompteDe(player);
        uint8 palier = PalierDe(c.points);
        if (palier < paliers.size())
            handler->PSendSysMessage("Rang d'aventurier : {} points, palier {} / {} (suivant à {}).", c.points, palier,
                paliers.size(), paliers[palier].points);
        else
            handler->PSendSysMessage("Rang d'aventurier : {} points, dernier palier atteint.", c.points);
        Envoyer(player);
        return true;
    }

    // .monture acheter <sort> : une monture de la boutique, en Marques du voyageur.
    static bool HandleAcheter(ChatHandler* handler, uint32 sort)
    {
        Player* player = handler->GetPlayer();
        auto it = catalogue.find(sort);
        if (it == catalogue.end())
        {
            handler->SendErrorMessage("Cette monture n'est pas en boutique.");
            return false;
        }
        auto [vitesse, prix] = it->second;
        uint8 palier = PalierDe(player);
        if (palier < PALIER_MONTE)
        {
            handler->SendErrorMessage("La boutique des montures s'ouvre au palier 10 du rang d'aventurier.");
            return false;
        }
        if (vitesse > VitesseOuverte(palier))
        {
            handler->SendErrorMessage("Cette vitesse n'est pas encore ouverte par le rang d'aventurier.");
            return false;
        }
        if (CompteDe(player).montures.count(sort))
        {
            handler->SendErrorMessage("Monture déjà achetée.");
            return false;
        }
        if (!SolAzeroth::RetirerMarques(player, prix))
        {
            handler->PSendSysMessage("Il faut {} Marques du voyageur.", prix);
            return false;
        }
        AjouterMonture(player, sort);
        handler->PSendSysMessage("Monture achetée ({} Marques du voyageur).", prix);
        Envoyer(player);
        return true;
    }
};

void AddSC_solazeroth_v3_aventurier()
{
    new solazeroth_v3_aventurier_joueur();
    new solazeroth_v3_aventurier_sorts();
    new solazeroth_v3_aventurier_monde();
    new solazeroth_v3_aventurier_commandes();
}
