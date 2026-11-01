// v3 (01/11/2026, proposition validée par l'utilisateur : « Réputation des donjons — proposition.md ») : difficultés
// de donjon et réputation des donjons. Chiffres : outils\passifs_v3.py et outils\simulation_donjons.py.
// - Difficulté 1 à 5 de chaque donjon (pas des raids), choisie à l'entrée (.donjon <1-5>, fenêtre d'entrée de
//   SolUI_Passifs.lua) parmi celles qu'ouvre le rang d'aventurier (paliers 12, 20, 30, 38). Elle reste modifiable
//   jusqu'au premier combat, puis elle est verrouillée jusqu'à la remise à zéro du donjon (solazeroth_v3_donjons).
//   Une instance neuve prend la dernière difficulté choisie par le compte, si elle est encore ouverte.
// - Les monstres (v3_modes.cpp) : en difficulté 2 et plus, puissance de base du joueur + écart, vie et dégâts × facteur,
//   et les techniques du donjon (tirées au sort à chaque changement de difficulté) ; éclats × 1,5 à × 3.
// - Dernier boss : + 2 Marques du voyageur par difficulté au-dessus de 1 ; à partir de la difficulté 3, 25 % de chances
//   par difficulté au-dessus de 2 d'une pierre taillée (joaillerie, F8), rangée dans la Collection.
// - Réputation des donjons, au compte (donjons et raids) : 1 par monstre tué, 10 par boss, 100 au dernier boss, le tout
//   × la difficulté (1 en raid). 10 rangs ; ils ouvrent les emplacements des passifs de donjon (v3_passifs.cpp).
// - Interface (préfixe SOLDONJON) : « DONJON;difficulté;ouvertes;verrouillé;techniques » en donjon, « AUCUN » dehors.

#include "SolAzeroth.h"
#include "Chat.h"
#include "CommandScript.h"
#include "Containers.h"
#include "Creature.h"
#include "DatabaseEnv.h"
#include "Map.h"
#include "Player.h"
#include "Random.h"
#include "ScriptMgr.h"
#include "StringFormat.h"
#include "WorldSession.h"
#include <unordered_map>
#include <vector>

using namespace Acore::ChatCommands;

namespace
{
    uint8 const DIFFICULTE_MAX = 5;
    uint8 const TECHNIQUES_PAR_DIFFICULTE[] = { 0, 0, 1, 2, 2, 3 };
    uint8 const TOUTES_TECHNIQUES[] = { 1, 2, 4, 8 };    // Enragé, Renforçant, Volcanique, Explosif (v3_modes.cpp)
    uint32 const RANGS[] = { 0, 100, 300, 600, 1000, 1600, 2400, 3400, 4600, 6000 };
    uint32 const PIERRES_TAILLEES[] = { 910180, 910181, 910182 };

    struct Instance
    {
        uint8 difficulte = 1;
        uint8 techniques = 0;
        bool verrouille = false;
    };
    std::unordered_map<uint32, Instance> instances;
    std::unordered_map<uint32, uint32> reputations;     // compte -> points
    std::unordered_map<uint32, uint8> dernieres;        // compte -> dernière difficulté choisie

    struct Suivi : DataMap::Base
    {
        std::string envoye;
    };

    bool AvecDifficulte(Map* map) { return map && map->IsNonRaidDungeon(); }

    uint32& Reputation(uint32 compte)
    {
        auto it = reputations.find(compte);
        if (it != reputations.end())
            return it->second;
        uint32& points = reputations[compte];
        if (QueryResult r = CharacterDatabase.Query("SELECT points FROM solazeroth_v3_reputation WHERE compte = {}", compte))
            points = (*r)[0].Get<uint32>();
        return points;
    }

    uint8 RangDe(uint32 points)
    {
        uint8 rang = 0;
        for (uint32 seuil : RANGS)
            if (points >= seuil)
                ++rang;
        return rang;
    }

    uint8 Tirer(uint8 difficulte)
    {
        std::vector<uint8> toutes(std::begin(TOUTES_TECHNIQUES), std::end(TOUTES_TECHNIQUES));
        Acore::Containers::RandomShuffle(toutes);
        uint8 masque = 0;
        for (uint8 i = 0; i < TECHNIQUES_PAR_DIFFICULTE[difficulte]; ++i)
            masque |= toutes[i];
        return masque;
    }

    void Sauver(uint32 instance, Instance const& e)
    {
        CharacterDatabase.Execute("REPLACE INTO solazeroth_v3_donjons (instance, difficulte, techniques, verrouille) "
            "VALUES ({}, {}, {}, {})", instance, e.difficulte, e.techniques, e.verrouille ? 1 : 0);
    }

    // État du donjon où est le joueur ; une instance neuve prend la dernière difficulté du compte.
    Instance* InstanceDe(Player* player)
    {
        Map* map = player->GetMap();
        if (!AvecDifficulte(map))
            return nullptr;
        auto it = instances.find(map->GetInstanceId());
        if (it != instances.end())
            return &it->second;
        Instance& e = instances[map->GetInstanceId()];
        uint32 compte = player->GetSession()->GetAccountId();
        e.difficulte = std::min(dernieres.count(compte) ? dernieres[compte] : uint8(1), SolAzeroth::DifficultesOuvertes(player));
        e.techniques = Tirer(e.difficulte);
        Sauver(map->GetInstanceId(), e);
        return &e;
    }

    void Envoyer(Player* player, bool force)
    {
        Suivi* s = player->CustomData.GetDefault<Suivi>("solazeroth_v3_donjons");
        Instance* e = InstanceDe(player);
        std::string message = e ? Acore::StringFormat("DONJON;{};{};{};{}", e->difficulte,
            uint32(SolAzeroth::DifficultesOuvertes(player)), e->verrouille ? 1 : 0, e->techniques) : std::string("AUCUN");
        if (!force && message == s->envoye)
            return;
        s->envoye = message;
        SolAzeroth::EnvoyerAddon(player, "SOLDONJON", message);
    }

    void Gagner(Player* player, uint32 points)
    {
        uint32 compte = player->GetSession()->GetAccountId();
        uint32& total = Reputation(compte);
        uint8 avant = RangDe(total);
        total += points;
        CharacterDatabase.Execute("INSERT INTO solazeroth_v3_reputation (compte, points) VALUES ({}, {}) "
            "ON DUPLICATE KEY UPDATE points = VALUES(points)", compte, total);
        if (RangDe(total) > avant)
        {
            ChatHandler(player->GetSession()).PSendSysMessage("|cffffd100Réputation des donjons : rang {} atteint !|r",
                uint32(RangDe(total)));
            SolAzeroth::EnvoyerAddon(player, "SOLZONE", Acore::StringFormat("ALERTE;Réputation des donjons : rang {}",
                uint32(RangDe(total))));
        }
    }
}

unsigned char SolAzeroth::DifficulteDonjon(Map* map)
{
    if (!AvecDifficulte(map))
        return 0;
    auto it = instances.find(map->GetInstanceId());
    return it == instances.end() ? 1 : it->second.difficulte;
}

unsigned char SolAzeroth::TechniquesDonjon(Map* map)
{
    if (!AvecDifficulte(map))
        return 0;
    auto it = instances.find(map->GetInstanceId());
    return it == instances.end() ? 0 : it->second.techniques;
}

bool SolAzeroth::DonjonVerrouille(Map* map)
{
    if (!AvecDifficulte(map))
        return false;
    auto it = instances.find(map->GetInstanceId());
    return it != instances.end() && it->second.verrouille;
}

unsigned char SolAzeroth::RangReputation(Player* player)
{
    return RangDe(Reputation(player->GetSession()->GetAccountId()));
}

unsigned int SolAzeroth::PointsReputation(Player* player)
{
    return Reputation(player->GetSession()->GetAccountId());
}

class solazeroth_v3_donjons_joueur : public PlayerScript
{
public:
    solazeroth_v3_donjons_joueur() : PlayerScript("solazeroth_v3_donjons_joueur", {
        PLAYERHOOK_ON_MAP_CHANGED, PLAYERHOOK_ON_CREATURE_KILL, PLAYERHOOK_ON_UPDATE }) { }

    void OnPlayerMapChanged(Player* player) override
    {
        Envoyer(player, true);
    }

    void OnPlayerUpdate(Player* player, uint32 /*diff*/) override
    {
        if (player->IsInWorld() && AvecDifficulte(player->GetMap()))
            Envoyer(player, false);
    }

    void OnPlayerCreatureKill(Player* player, Creature* creature) override
    {
        Map* map = player->GetMap();
        if (!map->IsDungeon() || creature->GetCharmerOrOwnerPlayerOrPlayerItself() || creature->IsSummon())
            return;
        uint8 difficulte = std::max<uint8>(1, SolAzeroth::DifficulteDonjon(map));
        bool final = SolAzeroth::EstBossFinal(creature->GetEntry());
        uint32 points = final ? 100 : creature->IsDungeonBoss() ? 10 : 1;
        Gagner(player, points * difficulte);
        if (!final || difficulte < 2)
            return;
        SolAzeroth::DonnerMarques(player, 2 * (difficulte - 1), Acore::StringFormat("difficulté {}", uint32(difficulte)));
        if (difficulte >= 3 && urand(1, 100) <= 25u * (difficulte - 2))
        {
            uint32 pierre = PIERRES_TAILLEES[urand(0, 2)];
            SolAzeroth::AjouterACollection(player, pierre, 1);
            ChatHandler(player->GetSession()).SendSysMessage("|cffffd100Une pierre taillée est rangée dans la Collection.|r");
        }
    }
};

// Premier combat d'un monstre contre un joueur : la difficulté est verrouillée.
class solazeroth_v3_donjons_unites : public UnitScript
{
public:
    solazeroth_v3_donjons_unites() : UnitScript("solazeroth_v3_donjons_unites", true, { UNITHOOK_ON_UNIT_ENTER_COMBAT }) { }

    void OnUnitEnterCombat(Unit* unite, Unit* cible) override
    {
        Creature* creature = unite ? unite->ToCreature() : nullptr;
        Player* player = cible ? cible->GetCharmerOrOwnerPlayerOrPlayerItself() : nullptr;
        if (!creature || !player || creature->GetCharmerOrOwnerPlayerOrPlayerItself() || !AvecDifficulte(creature->GetMap()))
            return;
        Instance* e = InstanceDe(player);
        if (e && !e->verrouille)
        {
            e->verrouille = true;
            Sauver(creature->GetMap()->GetInstanceId(), *e);
            Envoyer(player, true);
        }
    }
};

class solazeroth_v3_donjons_global : public GlobalScript
{
public:
    solazeroth_v3_donjons_global() : GlobalScript("solazeroth_v3_donjons_global", { GLOBALHOOK_ON_INSTANCEID_REMOVED }) { }

    void OnInstanceIdRemoved(uint32 instance) override
    {
        instances.erase(instance);
        CharacterDatabase.Execute("DELETE FROM solazeroth_v3_donjons WHERE instance = {}", instance);
    }
};

class solazeroth_v3_donjons_monde : public WorldScript
{
public:
    solazeroth_v3_donjons_monde() : WorldScript("solazeroth_v3_donjons_monde", { WORLDHOOK_ON_STARTUP }) { }

    void OnStartup() override
    {
        SolAzeroth::ChargerBossFinaux();
        instances.clear();
        if (QueryResult r = CharacterDatabase.Query("SELECT instance, difficulte, techniques, verrouille FROM solazeroth_v3_donjons"))
        {
            do
            {
                Field* f = r->Fetch();
                instances[f[0].Get<uint32>()] = { f[1].Get<uint8>(), f[2].Get<uint8>(), f[3].Get<uint8>() != 0 };
            } while (r->NextRow());
        }
        LOG_INFO("module", ">> Sol'Azeroth v3 : difficultés de donjon, {} instance(s) en cours", instances.size());
    }
};

class solazeroth_v3_donjons_commandes : public CommandScript
{
public:
    solazeroth_v3_donjons_commandes() : CommandScript("solazeroth_v3_donjons_commandes") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable commandes =
        {
            { "donjon", HandleDonjon, SEC_PLAYER, Console::No },
        };
        return commandes;
    }

    // .donjon : état ; .donjon <1-5> : difficulté du donjon, avant le premier combat.
    static bool HandleDonjon(ChatHandler* handler, Optional<uint8> difficulte)
    {
        Player* player = handler->GetPlayer();
        Instance* e = InstanceDe(player);
        if (!e)
        {
            handler->PSendSysMessage("Réputation des donjons : rang {}, {} points. Les difficultés se choisissent dans un donjon.",
                uint32(SolAzeroth::RangReputation(player)), Reputation(player->GetSession()->GetAccountId()));
            return true;
        }
        if (!difficulte)
        {
            handler->PSendSysMessage("Difficulté du donjon : {}{} (ouvertes : 1 à {}).", uint32(e->difficulte),
                e->verrouille ? ", verrouillée" : "", uint32(SolAzeroth::DifficultesOuvertes(player)));
            Envoyer(player, true);
            return true;
        }
        if (*difficulte < 1 || *difficulte > DIFFICULTE_MAX)
        {
            handler->SendErrorMessage("Difficultés : 1 à 5.");
            return false;
        }
        if (*difficulte > SolAzeroth::DifficultesOuvertes(player))
        {
            handler->SendErrorMessage("Cette difficulté n'est pas encore ouverte par le rang d'aventurier.");
            return false;
        }
        if (e->verrouille)
        {
            handler->SendErrorMessage("Le premier combat est livré : la difficulté est verrouillée jusqu'à la remise à zéro du donjon.");
            return false;
        }
        e->difficulte = *difficulte;
        e->techniques = Tirer(e->difficulte);
        dernieres[player->GetSession()->GetAccountId()] = e->difficulte;
        Sauver(player->GetMap()->GetInstanceId(), *e);
        handler->PSendSysMessage("Difficulté du donjon : {}.", uint32(e->difficulte));
        Envoyer(player, true);
        return true;
    }
};

void AddSC_solazeroth_v3_donjons()
{
    new solazeroth_v3_donjons_joueur();
    new solazeroth_v3_donjons_unites();
    new solazeroth_v3_donjons_global();
    new solazeroth_v3_donjons_monde();
    new solazeroth_v3_donjons_commandes();
}
