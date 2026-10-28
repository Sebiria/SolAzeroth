// Butin des boss de donjon choisi par le joueur (donjons à 5 uniquement, pas les raids)
// - L'équipement propre au boss (armes et armures, qualité inhabituelle ou mieux) ne tombe plus au hasard.
//   Les réserves d'objets aléatoires du monde liées à certains boss restent tirées au hasard, comme avant.
// - À la mort du boss, chaque joueur présent reçoit un choix : la liste de l'équipement propre au boss.
// - L'addon SolAzerothButin affiche la liste ; « .solbutin choisir <jeton> <objet> » donne l'objet choisi.
// - Les choix non faits sont gardés en base (solazeroth_butin_attente) et proposés à la connexion.

#include "SolAzeroth.h"
#include "Chat.h"
#include "Creature.h"
#include "DatabaseEnv.h"
#include "LootMgr.h"
#include "Map.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "StringFormat.h"
#include "WorldPacket.h"
#include "WorldSession.h"
#include <algorithm>
#include <mutex>
#include <set>
#include <sstream>
#include <unordered_map>
#include <vector>

using namespace Acore::ChatCommands;

namespace
{
    char const* const PREFIXE = "SOLBUTIN";
    uint32 const OBJETS_MAX = 16;

    struct Choix
    {
        uint32 jeton;
        std::string boss;
        std::vector<uint32> objets;
        uint8 rang = 0;   // rang de menace de l'instance à la mort du boss : enchantement de bonus (bonus.cpp)
    };

    std::mutex verrou;
    std::unordered_map<ObjectGuid::LowType, std::vector<Choix>> attente;
    uint32 prochainJeton = 1;

    bool EstEquipement(ItemTemplate const* objet)
    {
        return objet && (objet->Class == ITEM_CLASS_WEAPON || objet->Class == ITEM_CLASS_ARMOR)
            && objet->Quality >= ITEM_QUALITY_UNCOMMON;
    }

    bool EstDonjon(Map const* map)
    {
        return map && map->IsDungeon() && !map->IsRaid();
    }

    void EnvoyerAddon(Player* player, std::string const& message)
    {
        SolAzeroth::EnvoyerAddon(player, PREFIXE, message);
    }

    std::string Liste(std::vector<uint32> const& objets)
    {
        std::ostringstream texte;
        for (size_t i = 0; i < objets.size(); ++i)
            texte << (i ? "," : "") << objets[i];
        return texte.str();
    }

    void EnvoyerChoix(Player* player, Choix const& choix)
    {
        EnvoyerAddon(player, Acore::StringFormat("CHOIX;{};{};{};{}", choix.jeton, choix.boss, Liste(choix.objets), choix.rang));
    }

    // Au-delà de cette taille, une table de référence est une réserve d'objets aléatoires du monde (des centaines
    // d'objets verts communs à toute une tranche de niveaux), pas le butin propre du boss : elle reste au hasard.
    uint32 const TAILLE_MAX_REFERENCE_DE_BOSS = 25;

    // L'équipement propre à une table de butin de boss, références de boss comprises.
    void Collecter(char const* table, uint32 entree, std::set<uint32>& objets, uint8 profondeur = 0)
    {
        if (profondeur > 4)
            return;
        QueryResult resultat = WorldDatabase.Query("SELECT Item, Reference FROM {} WHERE Entry = {}", table, entree);
        if (!resultat)
            return;
        do
        {
            Field* champs = resultat->Fetch();
            if (uint32 reference = champs[1].Get<uint32>())
            {
                QueryResult taille = WorldDatabase.Query("SELECT COUNT(*) FROM reference_loot_template WHERE Entry = {}", reference);
                if (taille && (*taille)[0].Get<uint64>() <= TAILLE_MAX_REFERENCE_DE_BOSS)
                    Collecter("reference_loot_template", reference, objets, profondeur + 1);
            }
            else if (EstEquipement(sObjectMgr->GetItemTemplate(champs[0].Get<uint32>())))
                objets.insert(champs[0].Get<uint32>());
        } while (resultat->NextRow());
    }

    // Objets proposés au choix pour une table de butin (calculés une fois, puis gardés).
    std::mutex verrouOfferts;
    std::unordered_map<uint32, std::set<uint32>> offerts;

    std::set<uint32> const& Offerts(uint32 lootId)
    {
        std::lock_guard<std::mutex> garde(verrouOfferts);
        auto it = offerts.find(lootId);
        if (it == offerts.end())
        {
            std::set<uint32> objets;
            Collecter("creature_loot_template", lootId, objets);
            it = offerts.emplace(lootId, std::move(objets)).first;
        }
        return it->second;
    }

    Creature* BossDeDonjon(Player const* player, Loot const& loot)
    {
        if (!player || !loot.sourceWorldObjectGUID.IsCreature())
            return nullptr;
        Map* map = player->GetMap();
        if (!EstDonjon(map))
            return nullptr;
        Creature* creature = map->GetCreature(loot.sourceWorldObjectGUID);
        return creature && creature->IsDungeonBoss() ? creature : nullptr;
    }
}

// Retire l'équipement du tirage normal des boss de donjon.
class solazeroth_butin_tirage : public GlobalScript
{
public:
    solazeroth_butin_tirage() : GlobalScript("solazeroth_butin_tirage", { GLOBALHOOK_ON_ITEM_ROLL }) { }

    bool OnItemRoll(Player const* player, LootStoreItem const* objet, float& /*chance*/, Loot& loot, LootStore const& magasin) override
    {
        if (objet->reference || (&magasin != &LootTemplates_Creature && &magasin != &LootTemplates_Reference))
            return true;
        Creature* boss = BossDeDonjon(player, loot);
        if (!boss)
            return true;
        return !Offerts(boss->GetCreatureTemplate()->lootid).count(objet->itemid);
    }
};

// À la mort d'un boss de donjon, chaque joueur présent reçoit un choix.
class solazeroth_butin_boss : public UnitScript
{
public:
    solazeroth_butin_boss() : UnitScript("solazeroth_butin_boss", true, { UNITHOOK_ON_UNIT_DEATH }) { }

    void OnUnitDeath(Unit* unite, Unit* /*tueur*/) override
    {
        Creature* boss = unite->ToCreature();
        if (!boss || !boss->IsDungeonBoss() || !EstDonjon(boss->GetMap()))
            return;

        std::set<uint32> const& trouves = Offerts(boss->GetCreatureTemplate()->lootid);
        if (trouves.empty())
            return;
        std::vector<uint32> objets(trouves.begin(), trouves.end());
        if (objets.size() > OBJETS_MAX)
            objets.resize(OBJETS_MAX);

        for (auto const& ref : boss->GetMap()->GetPlayers())
        {
            Player* player = ref.GetSource();
            if (!player)
                continue;
            Choix choix;
            {
                std::lock_guard<std::mutex> garde(verrou);
                choix = { prochainJeton++, boss->GetName(), objets, SolAzeroth::PalierButin(boss->GetMap()) };
                attente[player->GetGUID().GetCounter()].push_back(choix);
            }
            std::string nom = choix.boss;
            CharacterDatabase.EscapeString(nom);
            CharacterDatabase.Execute("INSERT INTO solazeroth_butin_attente (jeton, guid, boss, objets, rang) VALUES ({}, {}, '{}', '{}', {})",
                choix.jeton, player->GetGUID().GetCounter(), nom, Liste(choix.objets), choix.rang);
            EnvoyerChoix(player, choix);
        }
    }
};

class solazeroth_butin_monde : public WorldScript
{
public:
    solazeroth_butin_monde() : WorldScript("solazeroth_butin_monde", { WORLDHOOK_ON_STARTUP }) { }

    void OnStartup() override
    {
        std::lock_guard<std::mutex> garde(verrou);
        if (QueryResult resultat = CharacterDatabase.Query("SELECT jeton, guid, boss, objets, rang FROM solazeroth_butin_attente ORDER BY jeton"))
        {
            do
            {
                Field* champs = resultat->Fetch();
                Choix choix{ champs[0].Get<uint32>(), champs[2].Get<std::string>(), {}, champs[4].Get<uint8>() };
                std::istringstream liste(champs[3].Get<std::string>());
                std::string objet;
                while (std::getline(liste, objet, ','))
                    choix.objets.push_back(uint32(std::stoul(objet)));
                attente[champs[1].Get<uint32>()].push_back(choix);
                prochainJeton = std::max(prochainJeton, choix.jeton + 1);
            } while (resultat->NextRow());
        }
    }
};

class solazeroth_butin_commandes : public CommandScript
{
public:
    solazeroth_butin_commandes() : CommandScript("solazeroth_butin_commandes") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable sousCommandes =
        {
            { "liste",   HandleListe,   SEC_PLAYER, Console::No },
            { "choisir", HandleChoisir, SEC_PLAYER, Console::No },
        };
        static ChatCommandTable commandes =
        {
            { "solbutin", sousCommandes },
        };
        return commandes;
    }

    // Renvoie à l'addon tous les choix en attente.
    static bool HandleListe(ChatHandler* handler)
    {
        Player* player = handler->GetSession()->GetPlayer();
        std::vector<Choix> choix;
        {
            std::lock_guard<std::mutex> garde(verrou);
            choix = attente[player->GetGUID().GetCounter()];
        }
        for (Choix const& c : choix)
            EnvoyerChoix(player, c);
        return true;
    }

    static bool HandleChoisir(ChatHandler* handler, uint32 jeton, uint32 objet)
    {
        Player* player = handler->GetSession()->GetPlayer();
        std::lock_guard<std::mutex> garde(verrou);
        std::vector<Choix>& liste = attente[player->GetGUID().GetCounter()];
        for (auto it = liste.begin(); it != liste.end(); ++it)
        {
            if (it->jeton != jeton)
                continue;
            if (std::find(it->objets.begin(), it->objets.end(), objet) == it->objets.end())
                return true;
            if (!SolAzeroth::DonnerObjetDeRang(player, objet, it->rang))
            {
                handler->SendSysMessage("|cffff0000Sacs pleins :|r fais de la place, le choix reste disponible.");
                return true;
            }
            SolAzeroth::Collectionner(player, objet);
            CharacterDatabase.Execute("DELETE FROM solazeroth_butin_attente WHERE jeton = {}", jeton);
            liste.erase(it);
            EnvoyerAddon(player, Acore::StringFormat("FAIT;{}", jeton));
            return true;
        }
        return true;
    }
};

void AddSC_solazeroth_butin()
{
    new solazeroth_butin_tirage();
    new solazeroth_butin_boss();
    new solazeroth_butin_monde();
    new solazeroth_butin_commandes();
}
