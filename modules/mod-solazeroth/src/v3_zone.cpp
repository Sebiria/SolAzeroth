// v3, F5e (31/10/2026) : pourcentage de la zone (document v3, F5 ; document de Durotar, §4).
// Les parts sont dans acore_world.solazeroth_v3_zone_parts (migration 074, générée par outils\zone_durotar.py), en
// centièmes de % :
// - genre 1, quête d'histoire rendue ;
// - genre 2, sous-zone explorée (les zones découvertes du jeu, PLAYER_EXPLORED_ZONES) ;
// - genre 3, lieu à nettoyer : tous les monstres de sa troupe tués dans la zone, au nombre voulu
//   (solazeroth_v3_lieux_monstres). Les monstres tués pour une quête comptent aussi.
// Chef renforcé (A01, A02, A05, A06, A10 ; solazeroth_v3_lieux_chefs, créatures de la migration 075) : quand la
// troupe est tombée et que le joueur est à moins de PROCHE m de la place du chef, le chef d'origine disparaît et sa
// copie renforcée apparaît. C'est sa mort qui clôt le lieu ; la troupe repart alors à zéro, pour que le chef revienne
// au prochain nettoyage (défis à venir).
// Les autres annexes (primes, contrats, défis, reliques) viendront ensuite.
// Interface (SolUI_Zone.lua, préfixe SOLZONE), quand ça change et qu'on est dans une zone qui a des parts :
// « POURCENT;total;histoire;exploration;annexes », « EXPLO;faites;total », « LIEU;lieu;nom;tués;requis;part;nettoyé »
// pour chaque lieu (le chef renforcé compte dans « requis »), puis « FINZONE ». Hors de ces zones : « POURCENT;-1 ».

#include "SolAzeroth.h"
#include "Creature.h"
#include "DatabaseEnv.h"
#include "DBCStores.h"
#include "ObjectAccessor.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "StringFormat.h"
#include <functional>
#include <unordered_map>
#include <vector>

namespace
{
    uint8 const QUETE = 1, EXPLORATION = 2, LIEU = 3;
    uint32 const RELECTURE = 2000;
    float const PROCHE = 120.0f;
    uint32 const DUREE_CHEF = 10 * MINUTE * IN_MILLISECONDS;   // le chef disparaît 10 min après la fin du combat

    struct Part
    {
        uint8 genre;
        uint32 cle, part;
        std::string nom;
    };

    std::unordered_map<uint32, std::vector<Part>> parts;                                // zone -> parts
    std::unordered_map<uint32, std::vector<std::pair<uint32, uint32>>> monstresDuLieu;  // lieu -> (créature, nombre)
    std::unordered_map<uint32, std::vector<std::pair<uint32, uint32>>> lieuxDuMonstre;  // créature -> (lieu, nombre)
    std::unordered_map<uint32, uint32> zoneDuLieu;

    struct Chef
    {
        uint32 origine = 0, renforce = 0, carte = 0;
        Position place;
    };
    std::unordered_map<uint32, Chef> chefs;              // lieu -> chef renforcé
    std::unordered_map<uint32, uint32> lieuDuRenforce;   // copie renforcée -> lieu

    struct Progres : DataMap::Base
    {
        std::unordered_map<uint64, uint32> tues;   // (lieu << 32 | créature) -> nombre ; chef renforcé : 1 = lieu clos
        std::unordered_map<uint32, ObjectGuid> invoques;   // lieu -> chef renforcé apparu
        uint32 attente = 0;
        size_t empreinte = 0;
    };

    Progres* ProgresDe(Player* player)
    {
        return player->CustomData.GetDefault<Progres>("solazeroth_v3_zone");
    }

    uint64 Cle(uint32 lieu, uint32 creature)
    {
        return (uint64(lieu) << 32) | creature;
    }

    bool Explore(Player* player, uint32 zone)
    {
        AreaTableEntry const* aire = sAreaTableStore.LookupEntry(zone);
        if (!aire || aire->exploreFlag / 32 >= PLAYER_EXPLORED_ZONES_SIZE)
            return false;
        return player->GetUInt32Value(PLAYER_EXPLORED_ZONES_1 + aire->exploreFlag / 32) & (1u << (aire->exploreFlag % 32));
    }

    // Monstres de la troupe tués (au plus le nombre voulu de chacun) et nombre voulu.
    std::pair<uint32, uint32> Troupe(Progres* p, uint32 lieu)
    {
        uint32 tues = 0, requis = 0;
        for (auto const& [creature, nombre] : monstresDuLieu[lieu])
        {
            tues += std::min(nombre, p->tues[Cle(lieu, creature)]);
            requis += nombre;
        }
        return { tues, requis };
    }

    // Troupe tombée et joueur près de la place : le chef d'origine s'efface devant sa copie renforcée.
    void FaireApparaitre(Player* player, Progres* p, uint32 lieu, Chef const& chef)
    {
        auto [tues, requis] = Troupe(p, lieu);
        if (tues < requis || player->GetMapId() != chef.carte || player->GetDistance(chef.place) > PROCHE)
            return;
        Creature* renforce = ObjectAccessor::GetCreature(*player, p->invoques[lieu]);
        if (!renforce)
        {
            renforce = player->SummonCreature(chef.renforce, chef.place, TEMPSUMMON_TIMED_DESPAWN_OUT_OF_COMBAT, DUREE_CHEF);
            if (!renforce)
                return;
            p->invoques[lieu] = renforce->GetGUID();
        }
        if (renforce->IsAlive())
            if (Creature* origine = renforce->FindNearestCreature(chef.origine, PROCHE, true); origine && !origine->IsInCombat())
                origine->DespawnOrUnsummon();
    }

    void Envoyer(Player* player, Progres* p)
    {
        auto it = parts.find(player->GetZoneId());
        if (it == parts.end())
        {
            if (p->empreinte != 1)
                SolAzeroth::EnvoyerAddon(player, "SOLZONE", "POURCENT;-1");
            p->empreinte = 1;
            return;
        }
        uint32 sommes[4] = {};
        uint32 explorees = 0, sousZones = 0;
        std::vector<std::string> lieux;
        for (Part const& part : it->second)
        {
            bool acquis = false;
            if (part.genre == QUETE)
                acquis = player->GetQuestRewardStatus(part.cle);
            else if (part.genre == EXPLORATION)
            {
                acquis = Explore(player, part.cle);
                ++sousZones;
                explorees += acquis;
            }
            else if (part.genre == LIEU)
            {
                auto [tues, requis] = Troupe(p, part.cle);
                acquis = requis && tues >= requis;
                if (auto c = chefs.find(part.cle); c != chefs.end())
                {
                    FaireApparaitre(player, p, part.cle, c->second);
                    acquis = p->tues[Cle(part.cle, c->second.renforce)] != 0;
                    ++requis;
                }
                lieux.push_back(Acore::StringFormat("LIEU;{};{};{};{};{};{}", part.cle, part.nom, tues, requis, part.part,
                    acquis ? 1 : 0));
            }
            if (acquis)
                sommes[part.genre] += part.part;
        }
        std::string pourcent = Acore::StringFormat("POURCENT;{};{};{};{}", sommes[QUETE] + sommes[EXPLORATION] +
            sommes[LIEU], sommes[QUETE], sommes[EXPLORATION], sommes[LIEU]);
        std::string explo = Acore::StringFormat("EXPLO;{};{}", explorees, sousZones);
        std::string tout = pourcent + explo;
        for (std::string const& l : lieux)
            tout += l;
        size_t empreinte = std::hash<std::string>{}(tout) | 2;
        if (empreinte == p->empreinte)
            return;
        p->empreinte = empreinte;
        SolAzeroth::EnvoyerAddon(player, "SOLZONE", pourcent);
        SolAzeroth::EnvoyerAddon(player, "SOLZONE", explo);
        for (std::string const& l : lieux)
            SolAzeroth::EnvoyerAddon(player, "SOLZONE", l);
        SolAzeroth::EnvoyerAddon(player, "SOLZONE", "FINZONE");
    }
}

class solazeroth_v3_zone_joueur : public PlayerScript
{
public:
    solazeroth_v3_zone_joueur() : PlayerScript("solazeroth_v3_zone_joueur", {
        PLAYERHOOK_ON_LOGIN, PLAYERHOOK_ON_UPDATE, PLAYERHOOK_ON_CREATURE_KILL_CREDIT, PLAYERHOOK_ON_DELETE }) { }

    void OnPlayerLogin(Player* player) override
    {
        Progres* p = ProgresDe(player);
        if (QueryResult r = CharacterDatabase.Query("SELECT lieu, creature, nombre FROM solazeroth_v3_lieux WHERE guid = {}",
            player->GetGUID().GetCounter()))
        {
            do
                p->tues[Cle((*r)[0].Get<uint32>(), (*r)[1].Get<uint32>())] = (*r)[2].Get<uint32>();
            while (r->NextRow());
        }
    }

    void OnPlayerCreatureKillCredit(Player* player, Creature* creature) override
    {
        if (auto c = lieuDuRenforce.find(creature->GetEntry()); c != lieuDuRenforce.end())
        {
            // Chef renforcé tué : lieu clos, la troupe repart à zéro.
            uint32 lieu = c->second;
            Progres* p = ProgresDe(player);
            for (auto const& [membre, nombre] : monstresDuLieu[lieu])
                p->tues[Cle(lieu, membre)] = 0;
            p->tues[Cle(lieu, creature->GetEntry())] = 1;
            p->invoques.erase(lieu);
            p->attente = 0;
            CharacterDatabase.Execute("DELETE FROM solazeroth_v3_lieux WHERE guid = {} AND lieu = {}",
                player->GetGUID().GetCounter(), lieu);
            CharacterDatabase.Execute("INSERT INTO solazeroth_v3_lieux (guid, lieu, creature, nombre) VALUES ({}, {}, {}, 1)",
                player->GetGUID().GetCounter(), lieu, creature->GetEntry());
            return;
        }
        auto it = lieuxDuMonstre.find(creature->GetEntry());
        if (it == lieuxDuMonstre.end())
            return;
        Progres* p = ProgresDe(player);
        for (auto const& [lieu, nombre] : it->second)
        {
            uint32& tues = p->tues[Cle(lieu, creature->GetEntry())];
            if (zoneDuLieu[lieu] != creature->GetZoneId() || tues >= nombre)
                continue;
            ++tues;
            CharacterDatabase.Execute("REPLACE INTO solazeroth_v3_lieux (guid, lieu, creature, nombre) VALUES ({}, {}, {}, {})",
                player->GetGUID().GetCounter(), lieu, creature->GetEntry(), tues);
            p->attente = 0;
        }
    }

    void OnPlayerUpdate(Player* player, uint32 diff) override
    {
        Progres* p = ProgresDe(player);
        if (p->attente > diff)
        {
            p->attente -= diff;
            return;
        }
        p->attente = RELECTURE;
        if (player->IsInWorld())
            Envoyer(player, p);
    }

    void OnPlayerDelete(ObjectGuid guid, uint32 /*compte*/) override
    {
        CharacterDatabase.Execute("DELETE FROM solazeroth_v3_lieux WHERE guid = {}", guid.GetCounter());
    }
};

class solazeroth_v3_zone_monde : public WorldScript
{
public:
    solazeroth_v3_zone_monde() : WorldScript("solazeroth_v3_zone_monde", { WORLDHOOK_ON_STARTUP }) { }

    void OnStartup() override
    {
        parts.clear();
        monstresDuLieu.clear();
        lieuxDuMonstre.clear();
        zoneDuLieu.clear();
        chefs.clear();
        lieuDuRenforce.clear();
        if (QueryResult r = WorldDatabase.Query("SELECT zone, genre, cle, part, nom FROM solazeroth_v3_zone_parts"))
        {
            do
            {
                Field* f = r->Fetch();
                Part part{ f[1].Get<uint8>(), f[2].Get<uint32>(), f[3].Get<uint32>(), f[4].Get<std::string>() };
                if (part.genre == LIEU)
                    zoneDuLieu[part.cle] = f[0].Get<uint32>();
                parts[f[0].Get<uint32>()].push_back(std::move(part));
            } while (r->NextRow());
        }
        if (QueryResult r = WorldDatabase.Query("SELECT lieu, creature, nombre FROM solazeroth_v3_lieux_monstres"))
        {
            do
            {
                Field* f = r->Fetch();
                monstresDuLieu[f[0].Get<uint32>()].emplace_back(f[1].Get<uint32>(), f[2].Get<uint32>());
                lieuxDuMonstre[f[1].Get<uint32>()].emplace_back(f[0].Get<uint32>(), f[2].Get<uint32>());
            } while (r->NextRow());
        }
        if (QueryResult r = WorldDatabase.Query("SELECT lieu, origine, renforce FROM solazeroth_v3_lieux_chefs"))
        {
            do
            {
                Field* f = r->Fetch();
                Chef& chef = chefs[f[0].Get<uint32>()];
                chef.origine = f[1].Get<uint32>();
                chef.renforce = f[2].Get<uint32>();
                lieuDuRenforce[chef.renforce] = f[0].Get<uint32>();
            } while (r->NextRow());
        }
        // Place du chef : celle de l'apparition d'origine.
        for (auto const& [guid, lieu] : sObjectMgr->GetAllCreatureData())
            for (auto& [numero, chef] : chefs)
                if (lieu.id == chef.origine)
                {
                    chef.carte = lieu.mapid;
                    chef.place.Relocate(lieu.posX, lieu.posY, lieu.posZ, lieu.orientation);
                }
        LOG_INFO("module", ">> Sol'Azeroth v3 : pourcentage de {} zone(s), {} lieux à nettoyer, {} chefs renforcés",
            parts.size(), zoneDuLieu.size(), chefs.size());
    }
};

void AddSC_solazeroth_v3_zone()
{
    new solazeroth_v3_zone_joueur();
    new solazeroth_v3_zone_monde();
}
