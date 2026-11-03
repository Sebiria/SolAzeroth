// Audit du jeu, lot 4a (02/11/2026, C4 du consensus : « l'or achète du temps, jamais de la puissance ») : Mogra,
// fournisseuse de matériaux de Razor Hill (migration 113, outils\fournisseur_v3.py, qui écrit les prix et leurs
// hypothèses). Elle vend les matériaux communs (minerai, pierre, lin, cuir), environ 4 fois la valeur du temps de farm,
// plafond par jour et par personnage ; jamais d'éclats, de Braises ni de pierres taillées. L'achat est rangé dans la
// Collection. L'interface reçoit les prix (« PRIX;objet:prix:reste,… », préfixe SOLFOURN) pour les listes de courses.
// Lot T9 des Tarides (03/11/2026, §4.7.8 du brouillon des Tarides) : plusieurs fournisseurs (colonne pnj de
// solazeroth_v3_fournisseur : Mogra 910030 à Razor Hill, Hraq 3477 à la Croisée), chacun son assortiment. Le prix
// suit la puissance de l'acheteur, pas le fournisseur : prix de base × (1 + max(0, P − 12) / 12), comme le coût des
// rangs (v3_equipement.cpp Cout) ; le même matériau coûte donc le même prix partout. Le plafond du jour reste par
// personnage et par matériau, commun à tous les fournisseurs. « PRIX;objet:prix:reste:fournisseurs,… » (les noms
// séparés par « / ») : chaque matériau une fois, à son prix pour ce joueur.

#include "SolAzeroth.h"
#include "Chat.h"
#include "CreatureScript.h"
#include "ObjectMgr.h"
#include "DatabaseEnv.h"
#include "Player.h"
#include "ScriptedGossip.h"
#include "ScriptMgr.h"
#include "StringFormat.h"
#include <map>
#include <unordered_map>
#include <vector>

namespace
{
    char const* const PREFIXE = "SOLFOURN";
    uint32 const LOTS[] = { 1, 5 };

    struct Materiau
    {
        uint32 objet = 0, prix = 0, plafond = 0;
        std::string nom;
        uint32 pnj = 0;
    };
    std::vector<Materiau> materiaux;

    struct Achats : DataMap::Base
    {
        std::unordered_map<uint32, std::pair<uint32, uint32>> faits;   // objet -> (jour, nombre)
        bool lus = false;
    };

    uint32 Aujourdhui()
    {
        return uint32(time(nullptr) / DAY);
    }

    Achats* AchatsDe(Player* player)
    {
        Achats* a = player->CustomData.GetDefault<Achats>("solazeroth_v3_fournisseur");
        if (!a->lus)
        {
            a->lus = true;
            if (QueryResult r = CharacterDatabase.Query("SELECT objet, jour, nombre FROM solazeroth_v3_fournisseur_achats "
                "WHERE guid = {}", player->GetGUID().GetCounter()))
            {
                do
                    a->faits[(*r)[0].Get<uint32>()] = { (*r)[1].Get<uint32>(), (*r)[2].Get<uint32>() };
                while (r->NextRow());
            }
        }
        return a;
    }

    uint32 Reste(Player* player, Materiau const& m)
    {
        auto const& [jour, nombre] = AchatsDe(player)->faits[m.objet];
        return jour == Aujourdhui() ? m.plafond - std::min(m.plafond, nombre) : m.plafond;
    }

    // Prix de l'unité pour ce joueur : prix de base × facteur de sa puissance.
    uint32 Prix(Player* player, Materiau const& m)
    {
        float facteur = 1.0f + std::max(0, int32(SolAzeroth::PuissanceJoueur(player)) - 12) / 12.0f;
        return uint32(m.prix * facteur + 0.5f);
    }

    std::string NomDuPnj(uint32 pnj)
    {
        CreatureTemplate const* modele = sObjectMgr->GetCreatureTemplate(pnj);
        return modele ? modele->Name : "le fournisseur";
    }

    std::string Argent(uint32 cuivre)
    {
        std::string texte;
        if (cuivre >= GOLD)
            texte += Acore::StringFormat("{} po ", cuivre / GOLD);
        if (cuivre % GOLD >= SILVER)
            texte += Acore::StringFormat("{} pa ", cuivre % GOLD / SILVER);
        if (cuivre % SILVER)
            texte += Acore::StringFormat("{} pc ", cuivre % SILVER);
        if (!texte.empty())
            texte.pop_back();
        return texte;
    }

    std::unordered_map<uint32, uint32> zoneDuPnj;   // fournisseur -> zone de son apparition

    // Le nom affiché est celui du fournisseur de la zone du joueur s'il vend ce matériau ; sinon, tous ceux qui le
    // vendent (Durotar affiche donc « Mogra », comme avant le lot T9).
    void Envoyer(Player* player)
    {
        std::map<uint32, std::pair<Materiau const*, std::string>> parObjet;   // objet -> (matériau, fournisseurs)
        std::map<uint32, std::string> ici;                                     // objet -> fournisseur de la zone
        for (Materiau const& m : materiaux)
        {
            auto& [premier, noms] = parObjet[m.objet];
            if (!premier)
                premier = &m;
            noms += (noms.empty() ? "" : "/") + NomDuPnj(m.pnj);
            auto z = zoneDuPnj.find(m.pnj);
            if (z != zoneDuPnj.end() && z->second == player->GetZoneId() && !ici.count(m.objet))
                ici[m.objet] = NomDuPnj(m.pnj);
        }
        for (auto const& [objet, nom] : ici)
            parObjet[objet].second = nom;
        std::string message = "PRIX;";
        bool suite = false;
        for (auto const& [objet, entree] : parObjet)
        {
            message += Acore::StringFormat("{}{}:{}:{}:{}", suite ? "," : "", objet, Prix(player, *entree.first),
                Reste(player, *entree.first), entree.second);
            suite = true;
        }
        SolAzeroth::EnvoyerAddon(player, PREFIXE, message);
    }
}

class npc_solazeroth_v3_fournisseur : public CreatureScript
{
public:
    npc_solazeroth_v3_fournisseur() : CreatureScript("npc_solazeroth_v3_fournisseur") { }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        for (size_t i = 0; i < materiaux.size(); ++i)
        {
            Materiau const& m = materiaux[i];
            if (m.pnj != creature->GetEntry())
                continue;
            uint32 reste = Reste(player, m);
            for (size_t l = 0; l < std::size(LOTS); ++l)
                if (reste >= LOTS[l])
                    AddGossipItemFor(player, GOSSIP_ICON_VENDOR, Acore::StringFormat("{} {} : {} (encore {} aujourd'hui)",
                        LOTS[l], m.nom, Argent(Prix(player, m) * LOTS[l]), reste), GOSSIP_SENDER_MAIN, uint32(i * 10 + l));
        }
        SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
        Envoyer(player);
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 /*sender*/, uint32 action) override
    {
        size_t i = action / 10, l = action % 10;
        if (i < materiaux.size() && l < std::size(LOTS) && materiaux[i].pnj == creature->GetEntry())
        {
            Materiau const& m = materiaux[i];
            uint32 nombre = LOTS[l], prix = Prix(player, m) * nombre;
            std::string const nom = creature->GetName();
            ChatHandler chat(player->GetSession());
            if (Reste(player, m) < nombre)
                chat.PSendSysMessage("{} : « Plus rien de ça pour toi aujourd'hui. Reviens demain. »", nom);
            else if (player->GetMoney() < prix)
                chat.PSendSysMessage("{} : « {}, pas moins. »", nom, Argent(prix));
            else if (!SolAzeroth::AjouterACollection(player, m.objet, nombre))
                chat.PSendSysMessage("{} : « Ça ne se range pas dans ta Collection. »", nom);
            else
            {
                player->ModifyMoney(-int32(prix));
                auto& [jour, fait] = AchatsDe(player)->faits[m.objet];
                if (jour != Aujourdhui())
                    jour = Aujourdhui(), fait = 0;
                fait += nombre;
                CharacterDatabase.Execute("REPLACE INTO solazeroth_v3_fournisseur_achats (guid, objet, jour, nombre) VALUES "
                    "({}, {}, {}, {})", player->GetGUID().GetCounter(), m.objet, jour, fait);
                chat.PSendSysMessage("{} {} rangé(s) dans la Collection, pour {}.", nombre, m.nom, Argent(prix));
            }
        }
        ClearGossipMenuFor(player);
        return OnGossipHello(player, creature);
    }
};

class solazeroth_v3_fournisseur_monde : public WorldScript
{
public:
    solazeroth_v3_fournisseur_monde() : WorldScript("solazeroth_v3_fournisseur_monde", { WORLDHOOK_ON_STARTUP }) { }

    void OnStartup() override
    {
        materiaux.clear();
        if (QueryResult r = WorldDatabase.Query("SELECT objet, nom, prix, plafond, pnj FROM solazeroth_v3_fournisseur "
            "ORDER BY pnj, prix"))
        {
            do
            {
                Field* f = r->Fetch();
                materiaux.push_back({ f[0].Get<uint32>(), f[2].Get<uint32>(), f[3].Get<uint32>(), f[1].Get<std::string>(),
                    f[4].Get<uint32>() });
            } while (r->NextRow());
        }
        zoneDuPnj.clear();
        if (QueryResult r = WorldDatabase.Query("SELECT id, MIN(zoneId) FROM creature WHERE id IN "
            "(SELECT DISTINCT pnj FROM solazeroth_v3_fournisseur) GROUP BY id"))
        {
            do
                zoneDuPnj[(*r)[0].Get<uint32>()] = (*r)[1].Get<uint32>();
            while (r->NextRow());
        }
    }
};

class solazeroth_v3_fournisseur_joueur : public PlayerScript
{
public:
    solazeroth_v3_fournisseur_joueur() : PlayerScript("solazeroth_v3_fournisseur_joueur", {
        PLAYERHOOK_ON_LOGIN, PLAYERHOOK_ON_UPDATE_ZONE, PLAYERHOOK_ON_DELETE }) { }

    void OnPlayerLogin(Player* player) override
    {
        Envoyer(player);
    }

    // Lot T9 : en changeant de zone, le nom du fournisseur et le prix (selon la puissance) se mettent à jour.
    void OnPlayerUpdateZone(Player* player, uint32 /*zone*/, uint32 /*aire*/) override
    {
        Envoyer(player);
    }

    void OnPlayerDelete(ObjectGuid guid, uint32 /*compte*/) override
    {
        CharacterDatabase.Execute("DELETE FROM solazeroth_v3_fournisseur_achats WHERE guid = {}", guid.GetCounter());
    }
};

void AddSC_solazeroth_v3_fournisseur()
{
    new npc_solazeroth_v3_fournisseur();
    new solazeroth_v3_fournisseur_monde();
    new solazeroth_v3_fournisseur_joueur();
}
