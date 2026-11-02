// Audit du jeu, lot 4a (02/11/2026, C4 du consensus : « l'or achète du temps, jamais de la puissance ») : Mogra,
// fournisseuse de matériaux de Razor Hill (migration 113, outils\fournisseur_v3.py, qui écrit les prix et leurs
// hypothèses). Elle vend les matériaux communs (minerai, pierre, lin, cuir), environ 4 fois la valeur du temps de farm,
// plafond par jour et par personnage ; jamais d'éclats, de Braises ni de pierres taillées. L'achat est rangé dans la
// Collection. L'interface reçoit les prix (« PRIX;objet:prix:reste,… », préfixe SOLFOURN) pour les listes de courses.

#include "SolAzeroth.h"
#include "Chat.h"
#include "CreatureScript.h"
#include "DatabaseEnv.h"
#include "Player.h"
#include "ScriptedGossip.h"
#include "ScriptMgr.h"
#include "StringFormat.h"
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

    void Envoyer(Player* player)
    {
        std::string message = "PRIX;";
        for (size_t i = 0; i < materiaux.size(); ++i)
            message += Acore::StringFormat("{}{}:{}:{}", i ? "," : "", materiaux[i].objet, materiaux[i].prix,
                Reste(player, materiaux[i]));
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
            uint32 reste = Reste(player, m);
            for (size_t l = 0; l < std::size(LOTS); ++l)
                if (reste >= LOTS[l])
                    AddGossipItemFor(player, GOSSIP_ICON_VENDOR, Acore::StringFormat("{} {} : {} (encore {} aujourd'hui)",
                        LOTS[l], m.nom, Argent(m.prix * LOTS[l]), reste), GOSSIP_SENDER_MAIN, uint32(i * 10 + l));
        }
        SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
        Envoyer(player);
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 /*sender*/, uint32 action) override
    {
        size_t i = action / 10, l = action % 10;
        if (i < materiaux.size() && l < std::size(LOTS))
        {
            Materiau const& m = materiaux[i];
            uint32 nombre = LOTS[l], prix = m.prix * nombre;
            ChatHandler chat(player->GetSession());
            if (Reste(player, m) < nombre)
                chat.SendSysMessage("Mogra : « Plus rien de ça pour toi aujourd'hui. Reviens demain. »");
            else if (player->GetMoney() < prix)
                chat.PSendSysMessage("Mogra : « {}, pas moins. »", Argent(prix));
            else if (!SolAzeroth::AjouterACollection(player, m.objet, nombre))
                chat.SendSysMessage("Mogra : « Ça ne se range pas dans ta Collection. »");
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
        if (QueryResult r = WorldDatabase.Query("SELECT objet, nom, prix, plafond FROM solazeroth_v3_fournisseur ORDER BY prix"))
        {
            do
            {
                Field* f = r->Fetch();
                materiaux.push_back({ f[0].Get<uint32>(), f[2].Get<uint32>(), f[3].Get<uint32>(), f[1].Get<std::string>() });
            } while (r->NextRow());
        }
    }
};

class solazeroth_v3_fournisseur_joueur : public PlayerScript
{
public:
    solazeroth_v3_fournisseur_joueur() : PlayerScript("solazeroth_v3_fournisseur_joueur", {
        PLAYERHOOK_ON_LOGIN, PLAYERHOOK_ON_DELETE }) { }

    void OnPlayerLogin(Player* player) override
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
