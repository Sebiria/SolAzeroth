// Audit du jeu, lot 6b (02/11/2026, C8 ; demande de l'utilisateur) : rares secrets. Trois par zone de départ, sans prime
// ni point sur la carte, réglés pour un personnage tout en bleu du Gouffre et tous ses bonus (outils\rares_secrets_v3.py,
// migration 121). Le bijou et la bague tombent du corps ; la monture rejoint les montures du compte. La fenêtre des
// objectifs compte les vaincus de la zone, « SECRETS;vaincus;total;noms » (v3_zone.cpp), sans nommer les autres.
// Lot T6 des Tarides (03/11/2026) : tout est lu par zone dans solazeroth_v3_rares_secrets ; les Tarides en ont cinq
// (migration 147, réglés pour les bleues des Cavernes), et l'événement du cauchemar ne les appelle pas (v3_modes.cpp).

#include "SolAzeroth.h"
#include "Chat.h"
#include "Creature.h"
#include "DatabaseEnv.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "StringFormat.h"
#include <map>
#include <set>

namespace
{
    struct Secret
    {
        uint32 zone = 0, monture = 0;
    };
    std::map<uint32, Secret> secrets;   // créature -> rare secret

    struct Vaincus : DataMap::Base
    {
        std::set<uint32> creatures;
    };

    Vaincus* VaincusDe(Player* player)
    {
        return player->CustomData.GetDefault<Vaincus>("solazeroth_v3_rares_secrets");
    }

    std::string NomDe(uint32 entree)
    {
        CreatureTemplate const* modele = sObjectMgr->GetCreatureTemplate(entree);
        return modele ? modele->Name : "?";
    }
}

std::string SolAzeroth::RaresSecrets(Player* player, unsigned int zone)
{
    Vaincus* v = VaincusDe(player);
    uint32 total = 0, vaincus = 0;
    std::string noms;
    for (auto const& [entree, s] : secrets)
    {
        if (s.zone != zone)
            continue;
        ++total;
        if (!v->creatures.count(entree))
            continue;
        ++vaincus;
        noms += (noms.empty() ? "" : ",") + NomDe(entree);
    }
    return total ? Acore::StringFormat("SECRETS;{};{};{}", vaincus, total, noms) : "";
}

class solazeroth_v3_rares_secrets_joueur : public PlayerScript
{
public:
    solazeroth_v3_rares_secrets_joueur() : PlayerScript("solazeroth_v3_rares_secrets_joueur", {
        PLAYERHOOK_ON_LOGIN, PLAYERHOOK_ON_CREATURE_KILL }) { }

    void OnPlayerLogin(Player* player) override
    {
        Vaincus* v = VaincusDe(player);
        if (QueryResult r = CharacterDatabase.Query("SELECT creature FROM solazeroth_v3_rares_vaincus WHERE guid = {}",
            player->GetGUID().GetCounter()))
        {
            do
                v->creatures.insert((*r)[0].Get<uint32>());
            while (r->NextRow());
        }
    }

    void OnPlayerCreatureKill(Player* player, Creature* creature) override
    {
        auto it = secrets.find(creature->GetEntry());
        if (it == secrets.end())
            return;
        if (it->second.monture)
            SolAzeroth::AjouterMontureCompte(player, it->second.monture);
        Vaincus* v = VaincusDe(player);
        if (!v->creatures.insert(it->first).second)
            return;
        CharacterDatabase.Execute("INSERT IGNORE INTO solazeroth_v3_rares_vaincus (guid, creature) VALUES ({}, {})",
            player->GetGUID().GetCounter(), it->first);
        uint32 vaincus = 0, total = 0;
        for (auto const& [entree, s] : secrets)
            if (s.zone == it->second.zone)
            {
                ++total;
                vaincus += v->creatures.count(entree);
            }
        std::string texte = Acore::StringFormat("Rare secret vaincu : {} ({} / {})", NomDe(it->first), vaincus, total);
        SolAzeroth::EnvoyerAddon(player, "SOLZONE", "ALERTE;" + texte);
        ChatHandler(player->GetSession()).SendSysMessage("|cffa335ee" + texte + "|r" + (it->second.monture
            ? " — sa monture rejoint celles du compte (utilisable dès la monte, palier 10 du rang d'aventurier)." : ""));
    }
};

class solazeroth_v3_rares_secrets_monde : public WorldScript
{
public:
    solazeroth_v3_rares_secrets_monde() : WorldScript("solazeroth_v3_rares_secrets_monde", { WORLDHOOK_ON_STARTUP }) { }

    void OnStartup() override
    {
        secrets.clear();
        if (QueryResult r = WorldDatabase.Query("SELECT creature, zone, monture FROM solazeroth_v3_rares_secrets"))
        {
            do
            {
                Field* f = r->Fetch();
                secrets[f[0].Get<uint32>()] = { f[1].Get<uint32>(), f[2].Get<uint32>() };
            } while (r->NextRow());
        }
        LOG_INFO("module", "Sol'Azeroth v3 : {} rares secrets", secrets.size());
    }
};

void AddSC_solazeroth_v3_rares_secrets()
{
    new solazeroth_v3_rares_secrets_joueur();
    new solazeroth_v3_rares_secrets_monde();
}
