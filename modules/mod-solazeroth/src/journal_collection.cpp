// Journal de collection (section 7.3, V4 étape 5), façon OSRS : une case par objet de chaque boss, pour tout le compte.
// Cases : acore_world.solazeroth_journal (migration 036). Un objet est collectionné quand il est obtenu sur le corps d'un
// boss, par le choix de butin des donjons (butin.cpp) ou par les Éclats de raid (malchance.cpp) ; pas les achats chez
// l'intendant ni les objets des contrats. Un objet laissé par plusieurs boss coche la case de chacun.
// Le Codex (ligne Collections) compte le journal à 80 %.
// Addon SolAzerothJournal (préfixe SOLJOURNAL) :
//   « .soljournal instances » -> « I;carte;raid;extension;nom;obtenus;total » par instance, « RESUME;obtenus;total », « FIN »
//   « .soljournal instance <carte> » -> « B;boss;nom;obtenus;total » puis « O;boss;objet:0|1,objet:0|1,… » (par paquets),
//   et « FINI;carte » ; « NOUVEAU;objet » à chaque nouvel objet collectionné.

#include "SolAzeroth.h"
#include "Chat.h"
#include "DatabaseEnv.h"
#include "DBCStores.h"
#include "GameTime.h"
#include "Item.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "StringFormat.h"
#include "World.h"
#include "WorldSession.h"
#include <algorithm>
#include <map>
#include <mutex>
#include <set>
#include <unordered_map>
#include <unordered_set>
#include <vector>

using namespace Acore::ChatCommands;

namespace
{
    char const* const PREFIXE = "SOLJOURNAL";
    uint32 const PAR_PAQUET = 12;

    struct Boss
    {
        uint32 entree;
        uint32 ordre;
        std::string nom;
        std::vector<uint32> objets;
    };

    struct Instance
    {
        uint32 carte;
        bool raid;
        uint32 extension;
        std::string nom;
        std::vector<Boss> boss;
    };

    std::map<uint32, Instance> instances;        // par carte
    std::unordered_set<uint32> objetsDuJournal;   // tous les objets du journal

    std::mutex verrou;
    std::unordered_map<uint32, std::unordered_set<uint32>> collections;   // par compte

    std::string Propre(std::string texte)
    {
        std::replace(texte.begin(), texte.end(), ';', ',');
        return texte;
    }

    std::unordered_set<uint32> Collection(uint32 compte)
    {
        {
            std::lock_guard<std::mutex> garde(verrou);
            auto it = collections.find(compte);
            if (it != collections.end())
                return it->second;
        }
        std::unordered_set<uint32> objets;
        if (QueryResult r = CharacterDatabase.Query("SELECT item FROM solazeroth_collection WHERE account = {}", compte))
        {
            do
                objets.insert((*r)[0].Get<uint32>());
            while (r->NextRow());
        }
        std::lock_guard<std::mutex> garde(verrou);
        return collections.emplace(compte, objets).first->second;
    }

    uint32 Compter(Boss const& b, std::unordered_set<uint32> const& collection)
    {
        uint32 n = 0;
        for (uint32 objet : b.objets)
            n += collection.count(objet);
        return n;
    }

    void EnvoyerInstances(Player* player)
    {
        std::unordered_set<uint32> collection = Collection(player->GetSession()->GetAccountId());
        for (auto const& [carte, inst] : instances)
        {
            std::set<uint32> objets;
            for (Boss const& b : inst.boss)
                objets.insert(b.objets.begin(), b.objets.end());
            uint32 obtenus = 0;
            for (uint32 objet : objets)
                obtenus += collection.count(objet);
            SolAzeroth::EnvoyerAddon(player, PREFIXE, Acore::StringFormat("I;{};{};{};{};{};{}", carte, inst.raid ? 1 : 0,
                inst.extension, inst.nom, obtenus, objets.size()));
        }
        uint32 obtenus = 0, total = 0;
        SolAzeroth::JournalDeCollection(player->GetSession()->GetAccountId(), obtenus, total);
        SolAzeroth::EnvoyerAddon(player, PREFIXE, Acore::StringFormat("RESUME;{};{}", obtenus, total));
        SolAzeroth::EnvoyerAddon(player, PREFIXE, "FIN");
    }

    void EnvoyerInstance(Player* player, uint32 carte)
    {
        auto it = instances.find(carte);
        if (it == instances.end())
            return;
        std::unordered_set<uint32> collection = Collection(player->GetSession()->GetAccountId());
        for (Boss const& b : it->second.boss)
        {
            SolAzeroth::EnvoyerAddon(player, PREFIXE, Acore::StringFormat("B;{};{};{};{}", b.entree, b.nom,
                Compter(b, collection), b.objets.size()));
            std::string paquet;
            uint32 n = 0;
            for (uint32 objet : b.objets)
            {
                paquet += (paquet.empty() ? "" : ",") + Acore::StringFormat("{}:{}", objet, collection.count(objet) ? 1 : 0);
                if (++n % PAR_PAQUET == 0)
                {
                    SolAzeroth::EnvoyerAddon(player, PREFIXE, Acore::StringFormat("O;{};{}", b.entree, paquet));
                    paquet.clear();
                }
            }
            if (!paquet.empty())
                SolAzeroth::EnvoyerAddon(player, PREFIXE, Acore::StringFormat("O;{};{}", b.entree, paquet));
        }
        SolAzeroth::EnvoyerAddon(player, PREFIXE, Acore::StringFormat("FINI;{}", carte));
    }
}

void SolAzeroth::Collectionner(Player* player, unsigned int objet)
{
    if (!objetsDuJournal.count(objet))
        return;
    uint32 compte = player->GetSession()->GetAccountId();
    if (Collection(compte).count(objet))
        return;
    {
        std::lock_guard<std::mutex> garde(verrou);
        collections[compte].insert(objet);
    }
    CharacterDatabase.Execute("INSERT IGNORE INTO solazeroth_collection (account, item, date) VALUES ({}, {}, {})",
        compte, objet, GameTime::GetGameTime().count());
    SolAzeroth::EnvoyerAddon(player, PREFIXE, Acore::StringFormat("NOUVEAU;{}", objet));
}

void SolAzeroth::JournalDeCollection(unsigned int compte, unsigned int& obtenus, unsigned int& total)
{
    std::unordered_set<uint32> collection = Collection(compte);
    total = uint32(objetsDuJournal.size());
    obtenus = 0;
    for (uint32 objet : collection)
        obtenus += objetsDuJournal.count(objet);
}

// Objet pris sur un corps (raids, boss de donjon dont le butin n'est pas au choix).
class solazeroth_journal_joueur : public PlayerScript
{
public:
    solazeroth_journal_joueur() : PlayerScript("solazeroth_journal_joueur", { PLAYERHOOK_ON_LOOT_ITEM }) { }

    void OnPlayerLootItem(Player* player, Item* objet, uint32 /*nombre*/, ObjectGuid /*source*/) override
    {
        if (objet)
            SolAzeroth::Collectionner(player, objet->GetEntry());
    }
};

class solazeroth_journal_commandes : public CommandScript
{
public:
    solazeroth_journal_commandes() : CommandScript("solazeroth_journal_commandes") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable sousCommandes =
        {
            { "instances", HandleInstances, SEC_PLAYER, Console::No },
            { "instance",  HandleInstance,  SEC_PLAYER, Console::No },
        };
        static ChatCommandTable commandes =
        {
            { "soljournal", sousCommandes },
        };
        return commandes;
    }

    static bool HandleInstances(ChatHandler* handler)
    {
        EnvoyerInstances(handler->GetPlayer());
        return true;
    }

    static bool HandleInstance(ChatHandler* handler, uint32 carte)
    {
        EnvoyerInstance(handler->GetPlayer(), carte);
        return true;
    }
};

class solazeroth_journal_monde : public WorldScript
{
public:
    solazeroth_journal_monde() : WorldScript("solazeroth_journal_monde", { WORLDHOOK_ON_STARTUP }) { }

    void OnStartup() override
    {
        // Boss -> carte et ordre de rencontre (DungeonEncounter.dbc).
        struct Lieu { uint32 carte, ordre; };
        std::unordered_map<uint32, Lieu> lieux;
        if (QueryResult r = WorldDatabase.Query("SELECT entry, creditEntry FROM instance_encounters WHERE creditType = 0"))
        {
            do
            {
                if (DungeonEncounterEntry const* rencontre = sDungeonEncounterStore.LookupEntry((*r)[0].Get<uint32>()))
                    lieux.emplace((*r)[1].Get<uint32>(), Lieu{ rencontre->mapId, rencontre->encounterIndex });
            } while (r->NextRow());
        }

        std::map<uint32, std::vector<uint32>> objetsParBoss;
        if (QueryResult r = WorldDatabase.Query("SELECT boss, item FROM solazeroth_journal ORDER BY boss, item"))
        {
            do
                objetsParBoss[(*r)[0].Get<uint32>()].push_back((*r)[1].Get<uint32>());
            while (r->NextRow());
        }

        LocaleConstant langue = sWorld->GetDefaultDbcLocale();
        for (auto& [entree, objets] : objetsParBoss)
        {
            auto lieu = lieux.find(entree);
            MapEntry const* carte = lieu != lieux.end() ? sMapStore.LookupEntry(lieu->second.carte) : nullptr;
            if (!carte)
                continue;
            Instance& inst = instances[carte->MapID];
            if (inst.nom.empty())
            {
                inst.carte = carte->MapID;
                inst.raid = carte->IsRaid();
                inst.extension = carte->Expansion();
                inst.nom = Propre(carte->name[langue][0] ? carte->name[langue] : carte->name[0]);
            }
            Boss b{ entree, lieu->second.ordre, "", objets };
            if (CreatureTemplate const* modele = sObjectMgr->GetCreatureTemplate(entree))
            {
                b.nom = modele->Name;
                if (CreatureLocale const* locale = sObjectMgr->GetCreatureLocale(entree))
                    ObjectMgr::GetLocaleString(locale->Name, LOCALE_frFR, b.nom);
            }
            b.nom = Propre(b.nom);
            inst.boss.push_back(b);
            objetsDuJournal.insert(objets.begin(), objets.end());
        }
        for (auto& [carte, inst] : instances)
            std::sort(inst.boss.begin(), inst.boss.end(), [](Boss const& a, Boss const& b) { return a.ordre < b.ordre; });

        LOG_INFO("module", "Sol'Azeroth journal de collection : {} instances, {} objets", instances.size(), objetsDuJournal.size());
    }
};

void AddSC_solazeroth_journal_collection()
{
    new solazeroth_journal_joueur();
    new solazeroth_journal_commandes();
    new solazeroth_journal_monde();
}
