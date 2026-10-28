// Protection contre la malchance et Éclats (section 6.3, V3).
// - Objets rares : tout objet (équipement, monture ou mascotte, qualité rare ou mieux) qu'un boss de donjon ou de
//   raid laisse à 3 % ou moins. Par compte et par objet, chaque tirage raté compte : la chance double à partir de
//   20 essais, vaut au moins 5 % à partir de 40, et l'objet est garanti au 60e essai. Le compteur repart à 0
//   quand l'objet est ramassé.
// - Éclats (raids seulement, décision de l'utilisateur) : chaque boss de raid vaincu donne 1 Éclat de ce boss au
//   compte. 30 Éclats achètent l'objet de son choix dans la table du boss (onglet « Éclats » de l'addon
//   d'apprentissage, catégorie E).

#include "SolAzeroth.h"
#include "Chat.h"
#include "Config.h"
#include "Creature.h"
#include "DatabaseEnv.h"
#include "DBCStores.h"
#include "LootMgr.h"
#include "Map.h"
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
#include <vector>

namespace
{
    struct Reglages
    {
        float seuil = 3.0f;          // % : en dessous, un objet de boss est « rare »
        uint32 palierDouble = 20;
        uint32 palierCinq = 40;
        uint32 garantie = 60;
        uint32 prixEclats = 30;
    } reglages;

    uint32 const TAILLE_MAX_REFERENCE_DE_BOSS = 25;   // comme butin.cpp

    std::set<uint32> rares;                              // objets protégés
    std::map<uint32, std::vector<uint32>> tablesRaid;    // boss de raid -> objets achetables en Éclats
    std::map<uint32, std::string> nomsBoss;

    // Compteurs en mémoire (le tirage du butin se fait dans le fil de chaque carte).
    std::mutex verrou;
    std::map<std::pair<uint32, uint32>, uint32> essais;  // (compte, objet) -> tirages ratés

    bool EstObjetVise(ItemTemplate const* m)
    {
        if (!m || m->Quality < ITEM_QUALITY_RARE)
            return false;
        if (m->Class == ITEM_CLASS_WEAPON || m->Class == ITEM_CLASS_ARMOR)
            return m->InventoryType != INVTYPE_NON_EQUIP;
        return m->Class == ITEM_CLASS_MISC && (m->SubClass == ITEM_SUBCLASS_JUNK_PET || m->SubClass == ITEM_SUBCLASS_JUNK_MOUNT);
    }

    // Objets propres à une table de boss (références de 25 objets ou moins), avec leur chance.
    void Collecter(char const* table, uint32 entree, std::map<uint32, float>& objets, uint8 profondeur = 0)
    {
        if (profondeur > 4)
            return;
        QueryResult r = WorldDatabase.Query("SELECT Item, Reference, Chance FROM {} WHERE Entry = {}", table, entree);
        if (!r)
            return;
        do
        {
            Field* f = r->Fetch();
            if (uint32 reference = f[1].Get<uint32>())
            {
                QueryResult taille = WorldDatabase.Query("SELECT COUNT(*) FROM reference_loot_template WHERE Entry = {}", reference);
                if (taille && (*taille)[0].Get<uint64>() <= TAILLE_MAX_REFERENCE_DE_BOSS)
                    Collecter("reference_loot_template", reference, objets, profondeur + 1);
            }
            else if (EstObjetVise(sObjectMgr->GetItemTemplate(f[0].Get<uint32>())))
            {
                float chance = f[2].Get<float>();
                auto it = objets.find(f[0].Get<uint32>());
                if (it == objets.end() || it->second < chance)
                    objets[f[0].Get<uint32>()] = chance;
            }
        } while (r->NextRow());
    }

    std::string NomCreature(uint32 entree)
    {
        CreatureTemplate const* modele = sObjectMgr->GetCreatureTemplate(entree);
        if (!modele)
            return "?";
        std::string nom = modele->Name;
        if (CreatureLocale const* traduction = sObjectMgr->GetCreatureLocale(entree))
            ObjectMgr::GetLocaleString(traduction->Name, sWorld->GetDefaultDbcLocale(), nom);
        nom.erase(std::remove_if(nom.begin(), nom.end(), [](char c) { return c == ';' || c == ':'; }), nom.end());
        return nom;
    }

    uint32 Eclats(uint32 compte, uint32 boss)
    {
        QueryResult r = CharacterDatabase.Query("SELECT eclats FROM solazeroth_eclats WHERE account = {} AND boss = {}", compte, boss);
        return r ? (*r)[0].Get<uint32>() : 0;
    }
}

void SolAzeroth::ListerEclats(Player* player, std::function<void(std::string const&)> const& ajouter)
{
    uint32 compte = player->GetSession()->GetAccountId();
    QueryResult r = CharacterDatabase.Query("SELECT boss, eclats FROM solazeroth_eclats WHERE account = {} AND eclats > 0", compte);
    if (!r)
        return;
    do
    {
        uint32 boss = (*r)[0].Get<uint32>(), nombre = (*r)[1].Get<uint32>();
        auto table = tablesRaid.find(boss);
        if (table == tablesRaid.end())
            continue;
        for (uint32 objet : table->second)
            ajouter(Acore::StringFormat("{}:{}:{}:{}:{}", objet, boss, nombre, reglages.prixEclats, nomsBoss[boss]));
    } while (r->NextRow());
}

// « id » est l'objet ; on paie avec les Éclats d'un boss de raid qui le laisse et dont le compte a assez d'Éclats.
void SolAzeroth::AcheterEclats(Player* player, unsigned int objet)
{
    ChatHandler chat(player->GetSession());
    uint32 compte = player->GetSession()->GetAccountId();
    for (auto const& [boss, objets] : tablesRaid)
    {
        if (std::find(objets.begin(), objets.end(), objet) == objets.end() || Eclats(compte, boss) < reglages.prixEclats)
            continue;
        if (!SolAzeroth::DonnerObjetDeRang(player, objet, 0))
        {
            chat.SendSysMessage("|cffff0000Sacs pleins.|r");
            return;
        }
        SolAzeroth::Collectionner(player, objet);
        CharacterDatabase.DirectExecute("UPDATE solazeroth_eclats SET eclats = eclats - {} WHERE account = {} AND boss = {}",
            reglages.prixEclats, compte, boss);
        chat.SendSysMessage(Acore::StringFormat("|cff00ff00Échange effectué : {} Éclats de {}.|r", reglages.prixEclats, nomsBoss[boss]));
        return;
    }
    chat.SendSysMessage(Acore::StringFormat("|cffff0000Il faut {} Éclats du boss qui laisse cet objet.|r", reglages.prixEclats));
}

// Chance des objets rares selon les tirages déjà ratés par le compte.
class solazeroth_malchance_tirage : public GlobalScript
{
public:
    solazeroth_malchance_tirage() : GlobalScript("solazeroth_malchance_tirage", { GLOBALHOOK_ON_ITEM_ROLL }) { }

    bool OnItemRoll(Player const* player, LootStoreItem const* objet, float& chance, Loot& /*loot*/, LootStore const& magasin) override
    {
        if (!player || !objet || &magasin != &LootTemplates_Creature || !rares.count(objet->itemid))
            return true;
        uint32 compte = player->GetSession()->GetAccountId();
        uint32 n;
        {
            std::lock_guard<std::mutex> garde(verrou);
            n = essais[{ compte, objet->itemid }]++;
        }
        CharacterDatabase.Execute("INSERT INTO solazeroth_malchance (account, item, essais) VALUES ({}, {}, {}) "
            "ON DUPLICATE KEY UPDATE essais = VALUES(essais)", compte, objet->itemid, n + 1);

        if (n + 1 >= reglages.garantie)
            chance = 100.0f;
        else if (n >= reglages.palierCinq)
            chance = std::max(chance * 2.0f, 5.0f);
        else if (n >= reglages.palierDouble)
            chance *= 2.0f;
        return true;
    }
};

class solazeroth_malchance_joueur : public PlayerScript
{
public:
    solazeroth_malchance_joueur() : PlayerScript("solazeroth_malchance_joueur", { PLAYERHOOK_ON_LOOT_ITEM }) { }

    // Objet rare ramassé : le compteur repart à 0.
    void OnPlayerLootItem(Player* player, Item* item, uint32 /*nombre*/, ObjectGuid /*source*/) override
    {
        if (!item || !rares.count(item->GetEntry()))
            return;
        uint32 compte = player->GetSession()->GetAccountId();
        {
            std::lock_guard<std::mutex> garde(verrou);
            essais.erase({ compte, item->GetEntry() });
        }
        CharacterDatabase.Execute("DELETE FROM solazeroth_malchance WHERE account = {} AND item = {}", compte, item->GetEntry());
    }
};

// Boss de raid vaincu : 1 Éclat de ce boss pour le compte de chaque joueur présent.
class solazeroth_eclats_boss : public UnitScript
{
public:
    solazeroth_eclats_boss() : UnitScript("solazeroth_eclats_boss", true, { UNITHOOK_ON_UNIT_DEATH }) { }

    void OnUnitDeath(Unit* unite, Unit* /*tueur*/) override
    {
        if (!unite->IsCreature() || !tablesRaid.count(unite->GetEntry()))
            return;
        Map* map = unite->GetMap();
        if (!map->IsRaid())
            return;
        for (auto const& ref : map->GetPlayers())
        {
            Player* player = ref.GetSource();
            if (!player)
                continue;
            uint32 compte = player->GetSession()->GetAccountId();
            CharacterDatabase.DirectExecute("INSERT INTO solazeroth_eclats (account, boss, eclats) VALUES ({}, {}, 1) "
                "ON DUPLICATE KEY UPDATE eclats = eclats + 1", compte, unite->GetEntry());
            ChatHandler(player->GetSession()).SendSysMessage(Acore::StringFormat(
                "|cffa335ee+1 Éclat de {}|r ({} au total, {} pour un objet au choix).", nomsBoss[unite->GetEntry()],
                Eclats(compte, unite->GetEntry()), reglages.prixEclats));
        }
    }
};

class solazeroth_malchance_monde : public WorldScript
{
public:
    solazeroth_malchance_monde() : WorldScript("solazeroth_malchance_monde", { WORLDHOOK_ON_AFTER_CONFIG_LOAD, WORLDHOOK_ON_STARTUP }) { }

    void OnAfterConfigLoad(bool /*rechargement*/) override
    {
        reglages.seuil = sConfigMgr->GetOption<float>("SolAzeroth.Malchance.Seuil", 3.0f);
        reglages.palierDouble = sConfigMgr->GetOption<uint32>("SolAzeroth.Malchance.PalierDouble", 20);
        reglages.palierCinq = sConfigMgr->GetOption<uint32>("SolAzeroth.Malchance.PalierCinq", 40);
        reglages.garantie = sConfigMgr->GetOption<uint32>("SolAzeroth.Malchance.Garantie", 60);
        reglages.prixEclats = sConfigMgr->GetOption<uint32>("SolAzeroth.Eclats.Prix", 30);
    }

    void OnStartup() override
    {
        // Boss : créatures qui valident une rencontre (donjons et raids).
        if (QueryResult r = WorldDatabase.Query("SELECT entry, creditEntry FROM instance_encounters WHERE creditType = 0"))
        {
            std::set<uint32> vus;
            do
            {
                uint32 rencontre = (*r)[0].Get<uint32>(), boss = (*r)[1].Get<uint32>();
                CreatureTemplate const* modele = sObjectMgr->GetCreatureTemplate(boss);
                if (!modele || !modele->lootid || !vus.insert(boss).second)
                    continue;
                std::map<uint32, float> objets;
                Collecter("creature_loot_template", modele->lootid, objets);
                for (auto const& [objet, chance] : objets)
                    if (chance > 0.0f && chance <= reglages.seuil)
                        rares.insert(objet);

                DungeonEncounterEntry const* entree = sDungeonEncounterStore.LookupEntry(rencontre);
                MapEntry const* carte = entree ? sMapStore.LookupEntry(entree->mapId) : nullptr;
                if (carte && carte->IsRaid() && !objets.empty())
                {
                    for (auto const& [objet, chance] : objets)
                        tablesRaid[boss].push_back(objet);
                    nomsBoss[boss] = NomCreature(boss);
                }
            } while (r->NextRow());
        }

        if (QueryResult r = CharacterDatabase.Query("SELECT account, item, essais FROM solazeroth_malchance"))
        {
            do
                essais[{ (*r)[0].Get<uint32>(), (*r)[1].Get<uint32>() }] = (*r)[2].Get<uint32>();
            while (r->NextRow());
        }
        LOG_INFO("module", "Sol'Azeroth malchance : {} objets rares protégés, {} boss de raid à Éclats", rares.size(), tablesRaid.size());
    }
};

void AddSC_solazeroth_malchance()
{
    new solazeroth_malchance_tirage();
    new solazeroth_malchance_joueur();
    new solazeroth_eclats_boss();
    new solazeroth_malchance_monde();
}
