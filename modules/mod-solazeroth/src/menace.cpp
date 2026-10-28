// Rang de menace de compte (sections 4.2 à 4.4 du document de conception)
// - Le rang est un niveau de compte : réussir le rang N dans 3 donjons différents débloque N + 1.
// - Le joueur règle à l'avance le rang de son prochain donjon (addon SolAzerothMenace, /rang). Une instance neuve
//   prend ce rang à la première entrée ; la fenêtre s'ouvre et le rang reste modifiable jusqu'au premier combat,
//   qui le verrouille. Un changement ensuite ne touche que le prochain donjon réinitialisé.
// - Formules : la créature subit les dégâts divisés par (1 + 0,12 × rang), inflige (1 + 0,08 × rang) de dégâts.
// - Affixes à partir du rang 2 : Fortifié (monstres) et Tyrannique (boss), en alternance chaque semaine.
// Toutes les valeurs sont dans mod_solazeroth.conf.

#include "SolAzeroth.h"
#include "Chat.h"
#include "Config.h"
#include "Creature.h"
#include "DatabaseEnv.h"
#include "GameTime.h"
#include "LootMgr.h"
#include "Map.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "StringFormat.h"
#include "WorldSession.h"
#include <algorithm>
#include <mutex>
#include <sstream>
#include <unordered_map>
#include <vector>

using namespace Acore::ChatCommands;

namespace
{
    char const* const PREFIXE = "SOLMENACE";

    struct Reglages
    {
        bool active = true;
        float pvParRang = 0.12f;
        float degatsParRang = 0.08f;
        float orParRang = 0.10f;
        uint32 donjonsPourDebloquer = 3;
        uint32 plafondAncien = 5;
        uint32 plafondWotlk = 10;
        uint32 affixeRangMin = 2;
        float fortifiePv = 0.20f;
        float fortifieDegats = 0.20f;
        float tyranniquePv = 0.30f;
        float tyranniqueDegats = 0.15f;
    } reglages;

    struct EtatInstance
    {
        uint8 rang = 0;
        bool verrouille = false;
        bool initialise = false;   // le rang réglé à l'avance a été appliqué
        uint8 affixe = 0;          // 0 celui de la semaine, 1 Fortifié, 2 Tyrannique (choix du Renom, rang 5)
        uint8 affixes = 0;         // affixes de mécanique cochés (affixes_mecanique.cpp)
    };

    // Ajustements par créature (SolAzeroth.Ajustement.Creatures), valables partout, rang ou non :
    // fraction des PV d'origine et fraction des dégâts d'origine. Exemple : boss de fête prévus pour 5 joueurs.
    std::unordered_map<uint32, SolAzeroth::Modificateurs> ajustements;

    std::mutex verrou;                                    // les cartes peuvent être mises à jour en parallèle
    std::unordered_map<uint32, EtatInstance> instances;   // clé : identifiant d'instance
    std::unordered_map<uint32, uint32> bossFinaux;         // entrée du dernier boss -> identifiant du donjon

    bool EstDonjon(Map const* map)
    {
        return map && map->IsDungeon() && !map->IsRaid();
    }

    uint8 Plafond(Map const* map)
    {
        return map->GetEntry()->Expansion() >= 2 ? reglages.plafondWotlk : reglages.plafondAncien;
    }

    // Fortifié les semaines paires, Tyrannique les semaines impaires.
    bool SemaineFortifiee()
    {
        return (GameTime::GetGameTime().count() / WEEK) % 2 == 0;
    }

    // Affixe effectif : celui choisi au menu (Renom) ou celui de la semaine.
    bool Fortifie(uint8 affixe)
    {
        return affixe == 1 || (affixe == 0 && SemaineFortifiee());
    }

    // Nom de l'affixe et son effet, pour la fenêtre de l'addon.
    std::string TexteAffixe(uint8 affixe)
    {
        if (Fortifie(affixe))
            return Acore::StringFormat("Fortifié (monstres hors boss : +{:.0f} % PV, +{:.0f} % dégâts)",
                reglages.fortifiePv * 100, reglages.fortifieDegats * 100);
        return Acore::StringFormat("Tyrannique (boss : +{:.0f} % PV, +{:.0f} % dégâts)",
            reglages.tyranniquePv * 100, reglages.tyranniqueDegats * 100);
    }

    void SauverInstance(uint32 instanceId, EtatInstance const& etat)
    {
        CharacterDatabase.Execute("REPLACE INTO solazeroth_menace_instance (instance_id, rang, verrouille, affixe, affixes) VALUES ({}, {}, {}, {}, {})",
            instanceId, etat.rang, etat.verrouille ? 1 : 0, etat.affixe, etat.affixes);
    }

    // Rang débloqué sur le compte : 1 + le plus haut rang réussi dans au moins N donjons différents.
    uint8 RangDebloque(uint32 compte)
    {
        std::vector<uint8> rangs;
        if (QueryResult resultat = CharacterDatabase.Query("SELECT rang_max FROM solazeroth_menace_reussites WHERE account = {} ORDER BY rang_max DESC", compte))
        {
            do
                rangs.push_back((*resultat)[0].Get<uint8>());
            while (resultat->NextRow());
        }
        if (rangs.size() < reglages.donjonsPourDebloquer)
            return 0;
        return std::min<uint32>(rangs[reglages.donjonsPourDebloquer - 1] + 1, reglages.plafondWotlk);
    }

    void Dire(Player* player, std::string const& message)
    {
        ChatHandler(player->GetSession()).SendSysMessage(message);
    }

    // Rang réglé à l'avance pour le prochain donjon (par compte).
    uint8 RangProchain(uint32 compte)
    {
        QueryResult resultat = CharacterDatabase.Query("SELECT rang_prochain FROM solazeroth_menace_compte WHERE account = {}", compte);
        return resultat ? (*resultat)[0].Get<uint8>() : 0;
    }

    // Affixes de mécanique cochés pour le prochain donjon (par compte).
    uint8 AffixesProchain(uint32 compte)
    {
        QueryResult resultat = CharacterDatabase.Query("SELECT affixes_prochain FROM solazeroth_menace_compte WHERE account = {}", compte);
        return resultat ? (*resultat)[0].Get<uint8>() : 0;
    }

    uint8 Palier(uint8 rang, uint8 affixes, uint8 plafond)
    {
        return uint8(std::min<uint32>(rang + SolAzeroth::PointsAffixes(affixes), plafond));
    }

    // État pour l'addon : « MECA;bit;nom;points;description » par affixe de mécanique, puis
    // « ETAT;débloqué;prochain;dans_donjon;rang_instance;verrouillé;plafond;affixe;rang_affixe;pv;dégâts;or;affixes;palier »
    // (affixes : ceux de l'instance dans un donjon, sinon ceux cochés pour le prochain). À appeler sans tenir le verrou.
    void EnvoyerEtat(Player* player, bool ouvrir)
    {
        uint32 compte = player->GetSession()->GetAccountId();
        Map* map = player->GetMap();
        bool donjon = map && map->IsDungeon() && !map->IsRaid();
        uint8 rang = 0, plafond = reglages.plafondWotlk;
        bool verrouille = false;
        // Hors donjon : l'affixe que prendra le prochain donjon (choix du Renom, ou celui de la semaine).
        uint8 affixe = SolAzeroth::AffixeChoisi(compte);
        uint8 affixes = AffixesProchain(compte);
        uint8 prochain = RangProchain(compte);
        if (donjon)
        {
            std::lock_guard<std::mutex> garde(verrou);
            EtatInstance const& etat = instances[map->GetInstanceId()];
            rang = etat.rang;
            verrouille = etat.verrouille;
            affixe = etat.affixe;
            affixes = etat.affixes;
            plafond = map->GetEntry()->Expansion() >= 2 ? reglages.plafondWotlk : reglages.plafondAncien;
        }
        for (std::string const& ligne : SolAzeroth::ListeAffixesMecanique())
            SolAzeroth::EnvoyerAddon(player, PREFIXE, "MECA;" + ligne);
        SolAzeroth::EnvoyerAddon(player, PREFIXE, Acore::StringFormat("ETAT;{};{};{};{};{};{};{};{};{};{};{};{};{}",
            RangDebloque(compte), prochain, donjon ? 1 : 0, rang, verrouille ? 1 : 0, plafond,
            TexteAffixe(affixe), reglages.affixeRangMin,
            reglages.pvParRang, reglages.degatsParRang, reglages.orParRang,
            affixes, Palier(donjon ? rang : prochain, affixes, plafond)));
        if (ouvrir)
            SolAzeroth::EnvoyerAddon(player, PREFIXE, "OUVRIR");
    }
}

char const* SolAzeroth::AffixeDeLaSemaine()
{
    return SemaineFortifiee() ? "Fortifié (monstres +20 % PV et dégâts)" : "Tyrannique (boss +30 % PV, +15 % dégâts)";
}

unsigned char SolAzeroth::RangInstance(unsigned int instanceId)
{
    std::lock_guard<std::mutex> garde(verrou);
    auto it = instances.find(instanceId);
    return it != instances.end() ? it->second.rang : 0;
}

unsigned char SolAzeroth::AffixesInstance(unsigned int instanceId)
{
    std::lock_guard<std::mutex> garde(verrou);
    auto it = instances.find(instanceId);
    return it != instances.end() ? it->second.affixes : 0;
}

unsigned char SolAzeroth::PalierButin(Map const* map)
{
    if (!EstDonjon(map))
        return 0;
    uint8 rang, affixes;
    {
        std::lock_guard<std::mutex> garde(verrou);
        auto it = instances.find(map->GetInstanceId());
        if (it == instances.end())
            return 0;
        rang = it->second.rang;
        affixes = it->second.affixes;
    }
    return Palier(rang, affixes, Plafond(map));
}

bool SolAzeroth::EstBossFinal(unsigned int entree)
{
    return bossFinaux.count(entree) > 0;
}

unsigned char SolAzeroth::RangMenaceDebloque(unsigned int compte)
{
    return RangDebloque(compte);
}

SolAzeroth::Modificateurs SolAzeroth::ModificateursMenace(Creature const* creature)
{
    Modificateurs m;
    if (!creature)
        return m;
    auto ajustement = ajustements.find(creature->GetEntry());
    if (ajustement != ajustements.end())
        m = ajustement->second;
    if (!reglages.active)
        return m;
    Map const* map = creature->GetMap();
    if (!EstDonjon(map))
        return m;

    uint8 rang = 0, affixe = 0;
    {
        std::lock_guard<std::mutex> garde(verrou);
        auto it = instances.find(map->GetInstanceId());
        if (it != instances.end())
        {
            rang = it->second.rang;
            affixe = it->second.affixe;
        }
    }
    if (rang == 0)
        return m;

    m.pv *= 1.0f + reglages.pvParRang * rang;
    m.degats *= 1.0f + reglages.degatsParRang * rang;
    if (rang >= reglages.affixeRangMin)
    {
        bool boss = creature->IsDungeonBoss();
        if (Fortifie(affixe) && !boss)
        {
            m.pv *= 1.0f + reglages.fortifiePv;
            m.degats *= 1.0f + reglages.fortifieDegats;
        }
        else if (!Fortifie(affixe) && boss)
        {
            m.pv *= 1.0f + reglages.tyranniquePv;
            m.degats *= 1.0f + reglages.tyranniqueDegats;
        }
    }
    return m;
}

namespace
{
    // Le joueur, son familier ou ses invocations.
    bool CoteJoueur(Unit const* unite)
    {
        return unite && unite->GetCharmerOrOwnerPlayerOrPlayerItself();
    }

    template <typename T>
    void Appliquer(Unit* cible, Unit* attaquant, T& degats)
    {
        if (cible && CoteJoueur(attaquant) && cible->IsCreature() && !CoteJoueur(cible))
        {
            SolAzeroth::Modificateurs m = SolAzeroth::ModificateursMenace(cible->ToCreature());
            if (m.pv != 1.0f)
                degats = T(degats / m.pv);
        }
        else if (attaquant && CoteJoueur(cible) && attaquant->IsCreature() && !CoteJoueur(attaquant))
        {
            SolAzeroth::Modificateurs m = SolAzeroth::ModificateursMenace(attaquant->ToCreature());
            if (m.degats != 1.0f)
                degats = T(degats * m.degats);
        }
    }
}

class solazeroth_menace_degats : public UnitScript
{
public:
    solazeroth_menace_degats() : UnitScript("solazeroth_menace_degats", true, {
        UNITHOOK_MODIFY_MELEE_DAMAGE, UNITHOOK_MODIFY_SPELL_DAMAGE_TAKEN, UNITHOOK_MODIFY_PERIODIC_DAMAGE_AURAS_TICK, UNITHOOK_ON_UNIT_DEATH }) { }

    void ModifyMeleeDamage(Unit* cible, Unit* attaquant, uint32& degats) override { Appliquer(cible, attaquant, degats); }
    void ModifySpellDamageTaken(Unit* cible, Unit* attaquant, int32& degats, SpellInfo const* /*sort*/) override { Appliquer(cible, attaquant, degats); }
    void ModifyPeriodicDamageAurasTick(Unit* cible, Unit* attaquant, uint32& degats, SpellInfo const* /*sort*/) override { Appliquer(cible, attaquant, degats); }

    // Dernier boss tué : réussite du donjon au rang de l'instance pour chaque joueur présent.
    void OnUnitDeath(Unit* unite, Unit* /*tueur*/) override
    {
        if (!reglages.active || !unite->IsCreature() || !bossFinaux.count(unite->GetEntry()))
            return;
        Map* map = unite->GetMap();
        if (!EstDonjon(map))
            return;

        uint8 rang = 0;
        {
            std::lock_guard<std::mutex> garde(verrou);
            rang = instances[map->GetInstanceId()].rang;
        }

        for (auto const& ref : map->GetPlayers())
        {
            Player* player = ref.GetSource();
            if (!player)
                continue;
            uint32 compte = player->GetSession()->GetAccountId();
            uint8 avant = RangDebloque(compte);
            CharacterDatabase.DirectExecute("INSERT INTO solazeroth_menace_reussites (account, donjon, map_id, rang_max) VALUES ({}, {}, {}, {}) "
                "ON DUPLICATE KEY UPDATE rang_max = GREATEST(rang_max, VALUES(rang_max))",
                compte, bossFinaux[unite->GetEntry()], map->GetId(), rang);
            uint8 apres = RangDebloque(compte);
            Dire(player, Acore::StringFormat("|cffffd100Donjon réussi au rang de menace {}.|r", rang));
            if (apres > avant)
                Dire(player, Acore::StringFormat("|cff00ff00Nouveau rang de menace débloqué : {} !|r", apres));
            SolAzeroth::ContratDonjonReussi(player, bossFinaux[unite->GetEntry()], rang);
        }
    }
};

class solazeroth_menace_joueur : public PlayerScript
{
public:
    solazeroth_menace_joueur() : PlayerScript("solazeroth_menace_joueur", {
        PLAYERHOOK_ON_MAP_CHANGED, PLAYERHOOK_ON_PLAYER_ENTER_COMBAT, PLAYERHOOK_ON_BEFORE_LOOT_MONEY }) { }

    // Entrée dans un donjon : une instance neuve prend le rang réglé à l'avance, et la fenêtre s'ouvre.
    void OnPlayerMapChanged(Player* player) override
    {
        Map* map = player->GetMap();
        if (!reglages.active || !EstDonjon(map))
            return;

        uint32 compte = player->GetSession()->GetAccountId();
        uint8 voulu = std::min({ RangProchain(compte), RangDebloque(compte), Plafond(map) });
        uint8 affixe = SolAzeroth::AffixeChoisi(compte);
        uint8 affixes = AffixesProchain(compte);
        bool ouvrir;
        uint8 rang;
        {
            std::lock_guard<std::mutex> garde(verrou);
            EtatInstance& etat = instances[map->GetInstanceId()];
            if (!etat.initialise && !etat.verrouille)
            {
                etat.rang = voulu;
                etat.affixe = affixe;
                etat.affixes = affixes;
                etat.initialise = true;
                SauverInstance(map->GetInstanceId(), etat);
            }
            ouvrir = !etat.verrouille;
            rang = etat.rang;
        }
        Dire(player, Acore::StringFormat(ouvrir
            ? "|cffffd100Rang de menace {} pour ce donjon.|r Modifiable jusqu'au premier combat (/rang)."
            : "Rang de menace de cette instance : {} (verrouillé).", rang));
        EnvoyerEtat(player, ouvrir);
    }

    // Premier combat dans l'instance : le rang est verrouillé.
    void OnPlayerEnterCombat(Player* player, Unit* ennemi) override
    {
        Map* map = player->GetMap();
        if (!reglages.active || !EstDonjon(map) || !ennemi || !ennemi->IsCreature())
            return;

        uint8 rang;
        {
            std::lock_guard<std::mutex> garde(verrou);
            EtatInstance& etat = instances[map->GetInstanceId()];
            if (etat.verrouille)
                return;
            etat.verrouille = true;
            etat.initialise = true;
            SauverInstance(map->GetInstanceId(), etat);
            rang = etat.rang;
        }
        Dire(player, Acore::StringFormat("Rang de menace {} verrouillé pour cette instance.", rang));
        EnvoyerEtat(player, false);
    }

    // L'or ramassé augmente avec le rang.
    void OnPlayerBeforeLootMoney(Player* player, Loot* loot) override
    {
        Map* map = player->GetMap();
        if (!reglages.active || !EstDonjon(map) || !loot || !loot->gold)
            return;
        uint8 rang;
        {
            std::lock_guard<std::mutex> garde(verrou);
            auto it = instances.find(map->GetInstanceId());
            rang = it != instances.end() ? it->second.rang : 0;
        }
        if (rang)
            loot->gold = uint32(loot->gold * (1.0f + reglages.orParRang * rang));
    }
};

class solazeroth_menace_monde : public WorldScript
{
public:
    solazeroth_menace_monde() : WorldScript("solazeroth_menace_monde", { WORLDHOOK_ON_AFTER_CONFIG_LOAD, WORLDHOOK_ON_STARTUP }) { }

    void OnAfterConfigLoad(bool /*rechargement*/) override
    {
        reglages.active = sConfigMgr->GetOption<bool>("SolAzeroth.Menace.Enable", true);
        reglages.pvParRang = sConfigMgr->GetOption<float>("SolAzeroth.Menace.PVParRang", 0.12f);
        reglages.degatsParRang = sConfigMgr->GetOption<float>("SolAzeroth.Menace.DegatsParRang", 0.08f);
        reglages.orParRang = sConfigMgr->GetOption<float>("SolAzeroth.Menace.OrParRang", 0.10f);
        reglages.donjonsPourDebloquer = std::max<uint32>(1, sConfigMgr->GetOption<uint32>("SolAzeroth.Menace.DonjonsPourDebloquer", 3));
        reglages.plafondAncien = sConfigMgr->GetOption<uint32>("SolAzeroth.Menace.PlafondClassiqueBC", 5);
        reglages.plafondWotlk = sConfigMgr->GetOption<uint32>("SolAzeroth.Menace.PlafondWotLK", 10);
        reglages.affixeRangMin = sConfigMgr->GetOption<uint32>("SolAzeroth.Affixes.RangMin", 2);
        reglages.fortifiePv = sConfigMgr->GetOption<float>("SolAzeroth.Affixes.Fortifie.PV", 0.20f);
        reglages.fortifieDegats = sConfigMgr->GetOption<float>("SolAzeroth.Affixes.Fortifie.Degats", 0.20f);
        reglages.tyranniquePv = sConfigMgr->GetOption<float>("SolAzeroth.Affixes.Tyrannique.PV", 0.30f);
        reglages.tyranniqueDegats = sConfigMgr->GetOption<float>("SolAzeroth.Affixes.Tyrannique.Degats", 0.15f);

        // « entrée fraction_PV fraction_dégâts, entrée ... »
        ajustements.clear();
        std::istringstream liste(sConfigMgr->GetOption<std::string>("SolAzeroth.Ajustement.Creatures", "", false));
        std::string element;
        while (std::getline(liste, element, ','))
        {
            std::istringstream valeurs(element);
            uint32 entree = 0;
            SolAzeroth::Modificateurs m;
            if (valeurs >> entree >> m.pv >> m.degats && entree && m.pv > 0.0f)
                ajustements[entree] = m;
        }
    }

    void OnStartup() override
    {
        if (QueryResult resultat = WorldDatabase.Query("SELECT creditEntry, lastEncounterDungeon FROM instance_encounters WHERE creditType = 0 AND lastEncounterDungeon <> 0"))
        {
            do
                bossFinaux[(*resultat)[0].Get<uint32>()] = (*resultat)[1].Get<uint32>();
            while (resultat->NextRow());
        }

        std::lock_guard<std::mutex> garde(verrou);
        if (QueryResult resultat = CharacterDatabase.Query("SELECT instance_id, rang, verrouille, affixe, affixes FROM solazeroth_menace_instance"))
        {
            do
            {
                Field* champs = resultat->Fetch();
                EtatInstance& etat = instances[champs[0].Get<uint32>()];
                etat.rang = champs[1].Get<uint8>();
                etat.verrouille = champs[2].Get<bool>();
                etat.affixe = champs[3].Get<uint8>();
                etat.affixes = champs[4].Get<uint8>();
                etat.initialise = true;
            } while (resultat->NextRow());
        }
    }
};

// Instance réinitialisée : son rang est oublié.
class solazeroth_menace_global : public GlobalScript
{
public:
    solazeroth_menace_global() : GlobalScript("solazeroth_menace_global", { GLOBALHOOK_ON_INSTANCEID_REMOVED }) { }

    void OnInstanceIdRemoved(uint32 instanceId) override
    {
        {
            std::lock_guard<std::mutex> garde(verrou);
            instances.erase(instanceId);
        }
        CharacterDatabase.Execute("DELETE FROM solazeroth_menace_instance WHERE instance_id = {}", instanceId);
    }
};

class solazeroth_menace_commandes : public CommandScript
{
public:
    solazeroth_menace_commandes() : CommandScript("solazeroth_menace_commandes") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable sousCommandes =
        {
            { "etat",    HandleEtat,    SEC_PLAYER, Console::No },
            { "choisir", HandleChoisir, SEC_PLAYER, Console::No },
            { "affixes", HandleAffixes, SEC_PLAYER, Console::No },
        };
        static ChatCommandTable commandes =
        {
            { "menace", HandleMenace, SEC_PLAYER, Console::No },
            { "solmenace", sousCommandes },
        };
        return commandes;
    }

    static bool HandleEtat(ChatHandler* handler)
    {
        EnvoyerEtat(handler->GetSession()->GetPlayer(), false);
        return true;
    }

    // Règle le rang du prochain donjon ; dans un donjon pas encore verrouillé, l'applique aussi tout de suite.
    static bool HandleChoisir(ChatHandler* handler, uint8 rang)
    {
        Player* player = handler->GetSession()->GetPlayer();
        uint32 compte = handler->GetSession()->GetAccountId();
        rang = std::min(rang, RangDebloque(compte));
        CharacterDatabase.DirectExecute("INSERT INTO solazeroth_menace_compte (account, rang_prochain) VALUES ({}, {}) "
            "ON DUPLICATE KEY UPDATE rang_prochain = VALUES(rang_prochain)", compte, rang);

        Map* map = player->GetMap();
        std::string ici;
        if (EstDonjon(map))
        {
            std::lock_guard<std::mutex> garde(verrou);
            EtatInstance& etat = instances[map->GetInstanceId()];
            if (!etat.verrouille)
            {
                etat.rang = std::min(rang, Plafond(map));
                etat.initialise = true;
                SauverInstance(map->GetInstanceId(), etat);
                ici = Acore::StringFormat(" Appliqué à ce donjon : rang {}.", etat.rang);
            }
            else
                ici = " Ce donjon reste à son rang verrouillé ; le nouveau rang vaudra pour le prochain.";
        }
        handler->SendSysMessage(Acore::StringFormat("|cffffd100Rang de menace réglé sur {}.|r{}", rang, ici));
        EnvoyerEtat(player, false);
        return true;
    }

    // Coche les affixes de mécanique du prochain donjon (somme de bits) ; dans un donjon pas encore verrouillé, aussi tout de suite.
    static bool HandleAffixes(ChatHandler* handler, uint8 affixes)
    {
        Player* player = handler->GetSession()->GetPlayer();
        uint32 compte = handler->GetSession()->GetAccountId();
        affixes &= 0x0F;
        CharacterDatabase.DirectExecute("INSERT INTO solazeroth_menace_compte (account, rang_prochain, affixes_prochain) VALUES ({}, 0, {}) "
            "ON DUPLICATE KEY UPDATE affixes_prochain = VALUES(affixes_prochain)", compte, affixes);
        Map* map = player->GetMap();
        if (EstDonjon(map))
        {
            std::lock_guard<std::mutex> garde(verrou);
            EtatInstance& etat = instances[map->GetInstanceId()];
            if (!etat.verrouille)
            {
                etat.affixes = affixes;
                etat.initialise = true;
                SauverInstance(map->GetInstanceId(), etat);
            }
        }
        EnvoyerEtat(player, false);
        return true;
    }

    // .menace : rang débloqué, rang de l'instance actuelle et affixe de la semaine.
    static bool HandleMenace(ChatHandler* handler)
    {
        Player* player = handler->GetSession()->GetPlayer();
        uint32 compte = handler->GetSession()->GetAccountId();
        handler->SendSysMessage(Acore::StringFormat("Rang de menace débloqué sur le compte : {}.", RangDebloque(compte)));
        handler->SendSysMessage(Acore::StringFormat("Affixe de la semaine (dès le rang {}) : {}.", reglages.affixeRangMin, SolAzeroth::AffixeDeLaSemaine()));

        if (QueryResult resultat = CharacterDatabase.Query("SELECT COUNT(*) FROM solazeroth_menace_reussites WHERE account = {}", compte))
            handler->SendSysMessage(Acore::StringFormat("Donjons réussis : {}.", (*resultat)[0].Get<uint32>()));

        Map* map = player->GetMap();
        if (EstDonjon(map))
        {
            std::lock_guard<std::mutex> garde(verrou);
            EtatInstance const& etat = instances[map->GetInstanceId()];
            handler->SendSysMessage(Acore::StringFormat("Cette instance : rang {}{} (plafond {}), affixes de mécanique : {}, palier de butin {}.", etat.rang,
                etat.verrouille ? ", verrouillé" : ", pas encore verrouillé", Plafond(map),
                SolAzeroth::NomsAffixesMecanique(etat.affixes), Palier(etat.rang, etat.affixes, Plafond(map))));
        }
        return true;
    }
};

void AddSC_solazeroth_menace()
{
    new solazeroth_menace_degats();
    new solazeroth_menace_joueur();
    new solazeroth_menace_monde();
    new solazeroth_menace_global();
    new solazeroth_menace_commandes();
}
