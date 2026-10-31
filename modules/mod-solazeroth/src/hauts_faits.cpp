// Hauts faits du compte (section 7.4, V4).
// Définitions dans acore_world.solazeroth_hauts_faits (migration 031), réglables sans recompiler. Un haut fait obtenu
// vaut pour tout le compte (solazeroth_hf_obtenus). Les compteurs (défis de boss, contrats, quêtes en défi…) sont
// alimentés par les autres fichiers du module via SolAzeroth::AjouterCompteur.
// Points de talent : chaque haut fait « talent » donne un point bonus, au plus 1 par niveau à partir du niveau 10
// (décision de l'utilisateur) : bonus utilisable = min(points gagnés, niveau − 9). Crochet OnPlayerCalculateTalentsPoints,
// donc la réinitialisation des talents et les cinq spécialisations les comptent d'office.
// Vérification : à la connexion, toutes les 30 secondes, et dès qu'un compteur avance.
// Addon SolAzerothHautsFaits (préfixe SOLHF) : « .solhf liste » ->
//   « HF;id;catégorie;nom;description;actuel;requis;obtenu;talent » pour chaque haut fait,
//   « RESUME;obtenus;total;points_talent;points_utilisables », « FIN » ; « OBTENU;id » à chaque nouveau haut fait.

#include "SolAzeroth.h"
#include "Chat.h"
#include "Config.h"
#include "Creature.h"
#include "DatabaseEnv.h"
#include "DBCStores.h"
#include "Map.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "StringFormat.h"
#include "WorldSession.h"
#include <algorithm>
#include <map>
#include <mutex>
#include <set>
#include <sstream>
#include <vector>

using namespace Acore::ChatCommands;

namespace
{
    char const* const PREFIXE = "SOLHF";

    enum Critere : uint8 { DONJONS = 1, COMPTEUR = 2, NATIF = 3, METIERS = 4, SORT = 5, CODEX = 6 };

    struct HautFait
    {
        uint32 id;
        uint8 categorie;
        std::string nom, description;
        uint8 critere;
        uint32 valeur, quantite;
        std::string liste;
        std::vector<uint32> nombres;     // liste lue comme des nombres (donjons, métiers)
        bool talent;
    };
    std::vector<HautFait> hautsFaits;
    std::set<uint32> bossSuivis;         // créatures dont la mort alimente un compteur « boss_<entrée> »

    uint32 marquesParHautFait = 10;
    uint32 orParNiveau = 1;              // pièces d'or par niveau du personnage, pour chaque haut fait

    // Points de talent gagnés par compte (pour le calcul des points, appelé souvent).
    std::mutex verrou;
    std::map<uint32, uint32> talentsGagnes;

    struct Minuterie : DataMap::Base { uint32 attente = 0; };

    uint32 Compteur(uint32 compte, std::string const& cle)
    {
        QueryResult r = CharacterDatabase.Query("SELECT valeur FROM solazeroth_compteurs WHERE account = {} AND cle = '{}'", compte, cle);
        return r ? (*r)[0].Get<uint32>() : 0;
    }

    std::string ListeSql(std::vector<uint32> const& nombres)
    {
        std::string texte;
        for (uint32 n : nombres)
            texte += (texte.empty() ? "" : ",") + std::to_string(n);
        return texte.empty() ? "0" : texte;
    }

    // Progression actuelle d'un haut fait pour le compte du joueur.
    uint32 Actuel(Player* player, HautFait const& hf)
    {
        uint32 compte = player->GetSession()->GetAccountId();
        switch (hf.critere)
        {
            case DONJONS:
            {
                QueryResult r = CharacterDatabase.Query("SELECT COUNT(DISTINCT donjon) FROM solazeroth_menace_reussites "
                    "WHERE account = {} AND rang_max >= {} AND donjon IN ({})", compte, hf.valeur, ListeSql(hf.nombres));
                return r ? uint32((*r)[0].Get<uint64>()) : 0;
            }
            case COMPTEUR:
                return Compteur(compte, hf.liste);
            case NATIF:
            {
                if (player->HasAchieved(hf.valeur))
                    return 1;
                QueryResult r = CharacterDatabase.Query("SELECT COUNT(*) FROM character_achievement a JOIN characters c ON c.guid = a.guid "
                    "WHERE c.account = {} AND a.achievement = {}", compte, hf.valeur);
                return r && (*r)[0].Get<uint64>() > 0 ? 1 : 0;
            }
            case METIERS:
            {
                // Meilleure valeur du compte (métiers partagés) ou du personnage connecté.
                std::map<uint32, uint32> valeurs;
                if (QueryResult r = CharacterDatabase.Query("SELECT skill, valeur FROM solazeroth_metiers_compte WHERE account = {} AND skill IN ({})",
                    compte, ListeSql(hf.nombres)))
                {
                    do
                        valeurs[(*r)[0].Get<uint32>()] = (*r)[1].Get<uint32>();
                    while (r->NextRow());
                }
                uint32 nombre = 0;
                for (uint32 skill : hf.nombres)
                    if (std::max<uint32>(valeurs[skill], player->GetPureSkillValue(skill)) >= hf.valeur)
                        ++nombre;
                return nombre;
            }
            case SORT:
            {
                if (player->HasSpell(hf.valeur))
                    return 1;
                QueryResult r = CharacterDatabase.Query("SELECT COUNT(*) FROM character_spell s JOIN characters c ON c.guid = s.guid "
                    "WHERE c.account = {} AND s.spell = {}", compte, hf.valeur);
                return r && (*r)[0].Get<uint64>() > 0 ? 1 : 0;
            }
            case CODEX:
                return uint32(SolAzeroth::PourcentFinCodex(player, uint8(hf.valeur)));
            default:
                return 0;
        }
    }

    std::set<uint32> Obtenus(uint32 compte)
    {
        std::set<uint32> obtenus;
        if (QueryResult r = CharacterDatabase.Query("SELECT hf FROM solazeroth_hf_obtenus WHERE account = {}", compte))
        {
            do
                obtenus.insert((*r)[0].Get<uint32>());
            while (r->NextRow());
        }
        return obtenus;
    }

    void CompterTalents(uint32 compte)
    {
        std::set<uint32> obtenus = Obtenus(compte);
        uint32 talents = 0;
        for (HautFait const& hf : hautsFaits)
            if (hf.talent && obtenus.count(hf.id))
                ++talents;
        std::lock_guard<std::mutex> garde(verrou);
        talentsGagnes[compte] = talents;
    }

    // Calculé à la demande s'il n'est pas encore connu : le jeu recalcule les points de talent pendant le chargement du
    // personnage, avant la connexion, et réinitialiserait ses talents s'il y avait plus de points dépensés que disponibles.
    uint32 TalentsGagnes(uint32 compte)
    {
        {
            std::lock_guard<std::mutex> garde(verrou);
            auto it = talentsGagnes.find(compte);
            if (it != talentsGagnes.end())
                return it->second;
        }
        CompterTalents(compte);
        std::lock_guard<std::mutex> garde(verrou);
        return talentsGagnes[compte];
    }

    uint32 TalentsUtilisables(uint32 gagnes, uint8 niveau)
    {
        return std::min<uint32>(gagnes, niveau >= 10 ? niveau - 9 : 0);
    }

    // Fenêtre native (V7, outils/hauts_faits_natifs.py) : chaque haut fait existe aussi comme haut fait du jeu 9000 + id.
    // Son unique critère (plus haute cote personnelle, fausse équipe d'arène 1000 + id) reçoit l'avancement du compte.
    AchievementEntry const* Natif(HautFait const& hf)
    {
        return sAchievementStore.LookupEntry(9000 + hf.id);
    }

    void AccorderNatif(Player* player, HautFait const& hf)
    {
        if (AchievementEntry const* natif = Natif(hf))
            if (!player->HasAchieved(natif->ID))
                player->CompletedAchievement(natif);
    }

    // Vérifie les hauts faits pas encore obtenus et accorde ceux qui sont remplis.
    void Verifier(Player* player)
    {
        uint32 compte = player->GetSession()->GetAccountId();
        std::set<uint32> obtenus = Obtenus(compte);
        bool talent = false;
        for (HautFait const& hf : hautsFaits)
        {
            if (obtenus.count(hf.id))
            {
                AccorderNatif(player, hf);
                continue;
            }
            uint32 actuel = Actuel(player, hf);
            if (actuel && Natif(hf))
                player->UpdateAchievementCriteria(ACHIEVEMENT_CRITERIA_TYPE_HIGHEST_PERSONAL_RATING, std::min(actuel, hf.quantite), 1000 + hf.id);
            if (actuel < hf.quantite)
                continue;
            CharacterDatabase.DirectExecute("INSERT IGNORE INTO solazeroth_hf_obtenus (account, hf, date) VALUES ({}, {}, UNIX_TIMESTAMP())",
                compte, hf.id);
            ChatHandler(player->GetSession()).SendSysMessage(Acore::StringFormat("|cffffd100Haut fait obtenu : {} !|r{}", hf.nom,
                hf.talent ? " |cff00ff00+1 point de talent.|r" : ""));
            SolAzeroth::EnvoyerAddon(player, PREFIXE, Acore::StringFormat("OBTENU;{}", hf.id));
            if (marquesParHautFait)
                SolAzeroth::DonnerMarques(player, marquesParHautFait, "haut fait");
            if (uint32 cuivre = orParNiveau * player->GetLevel() * GOLD)
            {
                player->ModifyMoney(int32(cuivre));
                ChatHandler(player->GetSession()).SendSysMessage(Acore::StringFormat("+{} po (haut fait).", cuivre / GOLD));
            }
            talent = talent || hf.talent;
            AccorderNatif(player, hf);
        }
        if (talent)
        {
            CompterTalents(compte);
            player->InitTalentForLevel();
            player->SendTalentsInfoData(false);
        }
    }

    void EnvoyerListe(Player* player)
    {
        uint32 compte = player->GetSession()->GetAccountId();
        std::set<uint32> obtenus = Obtenus(compte);
        for (HautFait const& hf : hautsFaits)
        {
            bool fait = obtenus.count(hf.id) > 0;
            uint32 actuel = fait ? hf.quantite : std::min(Actuel(player, hf), hf.quantite);
            SolAzeroth::EnvoyerAddon(player, PREFIXE, Acore::StringFormat("HF;{};{};{};{};{};{};{};{}", hf.id, hf.categorie,
                hf.nom, hf.description, actuel, hf.quantite, fait ? 1 : 0, hf.talent ? 1 : 0));
        }
        uint32 gagnes = TalentsGagnes(compte);
        SolAzeroth::EnvoyerAddon(player, PREFIXE, Acore::StringFormat("RESUME;{};{};{};{}", obtenus.size(), hautsFaits.size(),
            gagnes, TalentsUtilisables(gagnes, player->GetLevel())));
        for (std::string const& ligne : SolAzeroth::LignesBonusHautsFaits(player))
            SolAzeroth::EnvoyerAddon(player, PREFIXE, "BONUS;" + ligne);
        SolAzeroth::EnvoyerAddon(player, PREFIXE, "FIN");
    }
}

void SolAzeroth::HautsFaitsDuCompte(unsigned int compte, unsigned int& obtenus, unsigned int& total)
{
    std::set<uint32> faits = Obtenus(compte);
    obtenus = total = 0;
    for (HautFait const& hf : hautsFaits)
    {
        if (hf.critere == CODEX)
            continue;
        ++total;
        if (faits.count(hf.id))
            ++obtenus;
    }
}

void SolAzeroth::AjouterCompteur(Player* player, std::string const& cle, unsigned int nombre)
{
    CharacterDatabase.DirectExecute("INSERT INTO solazeroth_compteurs (account, cle, valeur) VALUES ({}, '{}', {}) "
        "ON DUPLICATE KEY UPDATE valeur = valeur + {}", player->GetSession()->GetAccountId(), cle, nombre, nombre);
    Verifier(player);
}

class solazeroth_hauts_faits_joueur : public PlayerScript
{
public:
    solazeroth_hauts_faits_joueur() : PlayerScript("solazeroth_hauts_faits_joueur", {
        PLAYERHOOK_ON_CREATE, PLAYERHOOK_ON_LOGIN, PLAYERHOOK_ON_UPDATE, PLAYERHOOK_ON_CALCULATE_TALENTS_POINTS,
        PLAYERHOOK_ON_LEVEL_CHANGED }) { }

    // v3, F5d (31/10/2026) : un nouveau personnage reçoit les hauts faits déjà obtenus par le compte sans annonce.
    // Sans cela, Verifier les lui accorde à la connexion et le jeu les annonce dans la discussion.
    void OnPlayerCreate(Player* player) override
    {
        std::set<uint32> obtenus = Obtenus(player->GetSession()->GetAccountId());
        for (HautFait const& hf : hautsFaits)
            if (obtenus.count(hf.id))
                if (AchievementEntry const* natif = Natif(hf))
                    CharacterDatabase.DirectExecute("INSERT IGNORE INTO character_achievement (guid, achievement, date) "
                        "VALUES ({}, {}, UNIX_TIMESTAMP())", player->GetGUID().GetCounter(), natif->ID);
    }

    void OnPlayerLogin(Player* player) override
    {
        CompterTalents(player->GetSession()->GetAccountId());
        player->InitTalentForLevel();
        Verifier(player);
    }

    void OnPlayerUpdate(Player* player, uint32 temps) override
    {
        Minuterie* m = player->CustomData.GetDefault<Minuterie>("solazeroth_hauts_faits");
        m->attente += temps;
        if (m->attente < 30 * IN_MILLISECONDS)
            return;
        m->attente = 0;
        Verifier(player);
    }

    // Points bonus des hauts faits, au plus 1 par niveau à partir du niveau 10.
    void OnPlayerCalculateTalentsPoints(Player const* player, uint32& points) override
    {
        points += TalentsUtilisables(TalentsGagnes(player->GetSession()->GetAccountId()), player->GetLevel());
    }

    // « Survivant » : niveau 40 avec un personnage Hardcore (réglage 0 du module des défis, mod-challenge-modes).
    void OnPlayerLevelChanged(Player* player, uint8 /*ancien*/) override
    {
        if (player->GetLevel() >= 40 && player->GetPlayerSetting("mod-challenge-modes", 0).value
            && !Compteur(player->GetSession()->GetAccountId(), "hardcore_40"))
            SolAzeroth::AjouterCompteur(player, "hardcore_40");
    }
};

// Boss suivis (compteurs « boss_<entrée> ») : chaque joueur présent compte la victoire.
class solazeroth_hauts_faits_boss : public UnitScript
{
public:
    solazeroth_hauts_faits_boss() : UnitScript("solazeroth_hauts_faits_boss", true, { UNITHOOK_ON_UNIT_DEATH }) { }

    void OnUnitDeath(Unit* unite, Unit* /*tueur*/) override
    {
        if (!unite->IsCreature() || !bossSuivis.count(unite->GetEntry()))
            return;
        for (auto const& ref : unite->GetMap()->GetPlayers())
            if (Player* player = ref.GetSource())
                SolAzeroth::AjouterCompteur(player, Acore::StringFormat("boss_{}", unite->GetEntry()));
    }
};

class solazeroth_hauts_faits_commandes : public CommandScript
{
public:
    solazeroth_hauts_faits_commandes() : CommandScript("solazeroth_hauts_faits_commandes") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable sousCommandes =
        {
            { "liste", HandleListe, SEC_PLAYER, Console::No },
        };
        static ChatCommandTable commandes =
        {
            { "solhf", sousCommandes },
        };
        return commandes;
    }

    static bool HandleListe(ChatHandler* handler)
    {
        EnvoyerListe(handler->GetPlayer());
        return true;
    }
};

class solazeroth_hauts_faits_monde : public WorldScript
{
public:
    solazeroth_hauts_faits_monde() : WorldScript("solazeroth_hauts_faits_monde", { WORLDHOOK_ON_AFTER_CONFIG_LOAD, WORLDHOOK_ON_STARTUP }) { }

    void OnAfterConfigLoad(bool /*rechargement*/) override
    {
        marquesParHautFait = sConfigMgr->GetOption<uint32>("SolAzeroth.HautsFaits.Marques", 10);
        orParNiveau = sConfigMgr->GetOption<uint32>("SolAzeroth.HautsFaits.OrParNiveau", 1);
    }

    void OnStartup() override
    {
        if (QueryResult r = WorldDatabase.Query("SELECT id, categorie, nom, description, critere, valeur, quantite, liste, talent "
            "FROM solazeroth_hauts_faits ORDER BY categorie, id"))
        {
            do
            {
                Field* f = r->Fetch();
                HautFait hf;
                hf.id = f[0].Get<uint32>();
                hf.categorie = f[1].Get<uint8>();
                hf.nom = f[2].Get<std::string>();
                hf.description = f[3].Get<std::string>();
                hf.critere = f[4].Get<uint8>();
                hf.valeur = f[5].Get<uint32>();
                hf.quantite = std::max<uint32>(1, f[6].Get<uint32>());
                hf.liste = f[7].Get<std::string>();
                hf.talent = f[8].Get<uint8>() != 0;
                std::replace(hf.nom.begin(), hf.nom.end(), ';', ',');
                std::replace(hf.description.begin(), hf.description.end(), ';', ',');
                std::stringstream flux(hf.liste);
                std::string morceau;
                while (std::getline(flux, morceau, ','))
                    if (!morceau.empty() && std::isdigit(static_cast<unsigned char>(morceau[0])))
                        hf.nombres.push_back(uint32(std::stoul(morceau)));
                if (hf.critere == COMPTEUR && hf.liste.rfind("boss_", 0) == 0)
                    bossSuivis.insert(uint32(std::stoul(hf.liste.substr(5))));
                hautsFaits.push_back(hf);
            } while (r->NextRow());
        }
        LOG_INFO("module", "Sol'Azeroth hauts faits : {} définis, {} boss suivis", hautsFaits.size(), bossSuivis.size());
    }
};

void AddSC_solazeroth_hauts_faits()
{
    new solazeroth_hauts_faits_joueur();
    new solazeroth_hauts_faits_boss();
    new solazeroth_hauts_faits_commandes();
    new solazeroth_hauts_faits_monde();
}
