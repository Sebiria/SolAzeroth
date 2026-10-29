// Codex (sections 1.3 et 7.1, V4) : pourcentage de chaque ligne et de chaque fin, pour tout le compte.
// Découpage validé par l'utilisateur le 28/10/2026 :
// - une ligne vaut ses heures (section 1.3) ; son pourcentage est la part accomplie de ce qui se mesure aujourd'hui.
//   Ce qui n'existe pas encore (chaîne d'histoire, rangs de menace des raids, ligues, quêtes cachées, thèmes du mois)
//   n'est pas compté : la ligne se recalcule quand ce contenu arrive ;
// - fins emboîtées : Histoire (250 h), Maître (820 h, Histoire comprise), 100 % (2 550 h, Maître comprise) ;
// - meilleur résultat du compte, tous personnages confondus.
// Addon SolAzerothCodex (préfixe SOLCODEX) : « .solcodex » -> « L;fin;nom;heures;pourcent;détail » pour chaque ligne,
//   puis « FINS;histoire;maître;cent ».
// Enregistre aussi les raids terminés (solazeroth_raids_reussis) et les élites rares tuées (solazeroth_rares_tues, une
// ligne par créature différente).
// Les hauts faits des fins (critère 6, hauts_faits.cpp) lisent PourcentFinCodex.

#include "SolAzeroth.h"
#include "Chat.h"
#include "Config.h"
#include "Creature.h"
#include "DatabaseEnv.h"
#include "DBCStores.h"
#include "GameTime.h"
#include "Map.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "ReputationMgr.h"
#include "ScriptMgr.h"
#include "StringFormat.h"
#include "WorldSession.h"
#include <algorithm>
#include <cmath>
#include <map>
#include <mutex>
#include <set>
#include <unordered_map>
#include <vector>

using namespace Acore::ChatCommands;

namespace
{
    char const* const PREFIXE = "SOLCODEX";

    struct Objectifs
    {
        uint32 primes = 50, reputations = 50, rares = 100, quetes = 3000, sansFilet = 100, montures = 100, mascottes = 100;
        uint32 plafondAncien = 5, plafondWotlk = 10;
    } objectifs;

    std::vector<uint64> xpCumul;                        // expérience cumulée pour atteindre chaque niveau
    std::map<uint32, uint32> donjons;                   // carte de donjon -> extension
    std::set<uint32> raidsWotlk, raidsAnciens;          // cartes de raid
    std::unordered_map<uint32, uint32> bossFinauxRaid;  // dernier boss d'un raid -> carte
    std::set<uint32> bossDeDonjon;                      // boss de donjon (défis de boss)
    std::set<uint32> recettesRares, montures, mascottes;

    uint32 const EXPLORATION[] = { 42, 43, 44, 45 };
    // Croisade d'argent, Kirin Tor, Chevaliers de la Lame d'ébène, Accord du Repos du ver, Fils de Hodir,
    // puis Avant-garde de l'Alliance ou Expédition de la Horde (comptées comme une seule).
    uint32 const REPUTATIONS[] = { 1106, 1090, 1098, 1091, 1119 };
    uint32 const AVANT_GARDE[] = { 1037, 1052 };
    uint32 const METIERS[] = { 171, 164, 333, 202, 182, 773, 755, 165, 186, 393, 197, 185, 129, 356 };
    int32 const EXALTE = 42000;
    char const* const NOMS_CLASSES[] = { "", "Guerrier", "Paladin", "Chasseur", "Voleur", "Prêtre", "Chevalier de la mort",
                                         "Chaman", "Mage", "Démoniste", "", "Druide" };

    struct Ligne
    {
        uint8 fin;
        std::string nom;
        float heures;
        float part;          // 0 à 1
        std::string detail;
    };

    struct Resultat
    {
        std::vector<Ligne> lignes;
        float fins[4] = {};  // pourcentages, index 1 à 3
        float heures = 0.0f; // heures du Codex accomplies (Renom)
    };

    std::mutex verrou;
    std::map<uint32, std::pair<time_t, Resultat>> cache;   // par compte, pour les hauts faits des fins

    float Part(uint32 fait, uint32 total) { return total ? std::min(1.0f, float(fait) / float(total)) : 0.0f; }

    // Part des niveaux vers le niveau 80, la barre du niveau en cours comprise (le chevalier de la mort commence au
    // niveau 55). Calibrage final (29/10/2026) : avant, c'était la part de l'XP, qui n'affichait que 14 % au niveau 60
    // alors que la moitié du temps de montée était faite ; la barre doit avancer chaque soir.
    float PartExperience(uint8 classe, uint8 niveau, uint32 xp)
    {
        if (xpCumul.size() <= 80)
            return 0.0f;
        uint8 depart = classe == CLASS_DEATH_KNIGHT ? 55 : 1;
        niveau = std::clamp<uint8>(niveau, 1, 80);
        if (niveau >= 80)
            return 1.0f;
        uint64 besoin = xpCumul[niveau + 1] - xpCumul[niveau];
        float avance = (niveau - depart) + (besoin ? std::min(1.0f, float(double(xp) / double(besoin))) : 0.0f);
        return std::clamp(avance / float(80 - depart), 0.0f, 1.0f);
    }

    // Réputation de départ d'une faction pour une race et une classe (comme le jeu).
    int32 ReputationDeBase(FactionEntry const* f, uint8 race, uint8 classe)
    {
        uint32 masqueRace = 1 << (race - 1), masqueClasse = 1 << (classe - 1);
        for (uint8 i = 0; i < 4; ++i)
            if (((f->BaseRepRaceMask[i] & masqueRace) || (!f->BaseRepRaceMask[i] && f->BaseRepClassMask[i]))
                && (!f->BaseRepClassMask[i] || (f->BaseRepClassMask[i] & masqueClasse)))
                return f->BaseRepValue[i];
        return 0;
    }

    std::set<uint32> Liste(QueryResult r)
    {
        std::set<uint32> valeurs;
        if (r)
        {
            do
                valeurs.insert((*r)[0].Get<uint32>());
            while (r->NextRow());
        }
        return valeurs;
    }

    std::string Pourcent(float part) { return Acore::StringFormat("{:.0f} %", part * 100.0f); }

    Resultat Calculer(Player* player)
    {
        uint32 compte = player->GetSession()->GetAccountId();
        Resultat res;

        // Personnages du compte (le personnage connecté d'après le jeu, plus à jour que la base).
        struct Perso { uint8 classe, race, niveau; uint32 xp; };
        std::map<uint32, Perso> persos;
        if (QueryResult r = CharacterDatabase.Query("SELECT guid, class, race, level, xp FROM characters WHERE account = {}", compte))
        {
            do
            {
                Field* f = r->Fetch();
                persos[f[0].Get<uint32>()] = { f[1].Get<uint8>(), f[2].Get<uint8>(), f[3].Get<uint8>(), f[4].Get<uint32>() };
            } while (r->NextRow());
        }
        persos[player->GetGUID().GetCounter()] = { player->getClass(), player->getRace(), uint8(player->GetLevel()),
                                                  player->GetUInt32Value(PLAYER_XP) };

        float meilleure = 0.0f;
        uint8 meilleurNiveau = 1;
        std::map<uint8, float> parClasse;
        for (auto const& [guid, p] : persos)
        {
            float part = PartExperience(p.classe, p.niveau, p.xp);
            if (part > meilleure || (part == meilleure && p.niveau > meilleurNiveau))
            {
                meilleure = part;
                meilleurNiveau = p.niveau;
            }
            parClasse[p.classe] = std::max(parClasse[p.classe], part);
        }

        std::map<std::string, uint32> compteurs;
        if (QueryResult r = CharacterDatabase.Query("SELECT cle, valeur FROM solazeroth_compteurs WHERE account = {}", compte))
        {
            do
                compteurs[(*r)[0].Get<std::string>()] = (*r)[1].Get<uint32>();
            while (r->NextRow());
        }
        // Élites rares : créatures différentes tuées (calibrage final : tuer 100 fois le même rare ne compte plus 100).
        if (QueryResult r = CharacterDatabase.Query("SELECT COUNT(*) FROM solazeroth_rares_tues WHERE account = {}", compte))
            compteurs["elites_rares"] = uint32((*r)[0].Get<uint64>());

        std::set<uint32> sorts = Liste(CharacterDatabase.Query("SELECT DISTINCT s.spell FROM character_spell s "
            "JOIN characters c ON c.guid = s.guid WHERE c.account = {}", compte));
        for (auto const& [sort, info] : player->GetSpellMap())
            if (info->State != PLAYERSPELL_REMOVED)
                sorts.insert(sort);

        // --- Histoire : meilleur personnage vers le niveau 80 (230 h), Roi-liche vaincu (20 h).
        bool roiLiche = compteurs["boss_36597"] > 0;
        res.lignes.push_back({ 1, "Histoire", 250.0f, (meilleure * 230.0f + (roiLiche ? 20.0f : 0.0f)) / 250.0f,
            Acore::StringFormat("Meilleur personnage : niveau {} ({} de l'expérience vers 80) - Roi-liche : {}",
                meilleurNiveau, Pourcent(meilleure), roiLiche ? "vaincu" : "pas encore vaincu") });

        // --- Donjons : une case par donjon et par rang réussi (plafond du rang selon l'extension).
        std::map<uint32, uint32> rangs;
        if (QueryResult r = CharacterDatabase.Query("SELECT map_id, MAX(rang_max) FROM solazeroth_menace_reussites WHERE account = {} GROUP BY map_id", compte))
        {
            do
                rangs[(*r)[0].Get<uint32>()] = (*r)[1].Get<uint32>();
            while (r->NextRow());
        }
        uint32 cases15 = 0, faits15 = 0, cases610 = 0, faits610 = 0;
        for (auto const& [carte, extension] : donjons)
        {
            uint32 plafond = extension >= 2 ? objectifs.plafondWotlk : objectifs.plafondAncien;
            uint32 rang = std::min(rangs.count(carte) ? rangs[carte] : 0u, plafond);
            cases15 += std::min(plafond, 5u);
            faits15 += std::min(rang, 5u);
            cases610 += plafond > 5 ? plafond - 5 : 0;
            faits610 += rang > 5 ? rang - 5 : 0;
        }

        // --- Raids terminés (dernier boss vaincu).
        std::set<uint32> raids = Liste(CharacterDatabase.Query("SELECT map_id FROM solazeroth_raids_reussis WHERE account = {}", compte));
        uint32 wotlk = 0, anciens = 0;
        for (uint32 carte : raids)
        {
            wotlk += raidsWotlk.count(carte);
            anciens += raidsAnciens.count(carte);
        }

        // --- Exploration (hauts faits du jeu) et réputations.
        std::set<uint32> explores = Liste(CharacterDatabase.Query("SELECT DISTINCT a.achievement FROM character_achievement a "
            "JOIN characters c ON c.guid = a.guid WHERE c.account = {} AND a.achievement IN (42, 43, 44, 45)", compte));
        for (uint32 hf : EXPLORATION)
            if (player->HasAchieved(hf))
                explores.insert(hf);

        std::map<uint32, int32> reputations;   // faction -> meilleure réputation du compte
        if (QueryResult r = CharacterDatabase.Query("SELECT r.faction, r.standing, c.race, c.class FROM character_reputation r "
            "JOIN characters c ON c.guid = r.guid WHERE c.account = {} AND c.guid <> {}", compte, player->GetGUID().GetCounter()))
        {
            do
            {
                Field* f = r->Fetch();
                if (FactionEntry const* faction = sFactionStore.LookupEntry(f[0].Get<uint32>()))
                {
                    int32 total = ReputationDeBase(faction, f[2].Get<uint8>(), f[3].Get<uint8>()) + f[1].Get<int32>();
                    auto it = reputations.find(faction->ID);
                    reputations[faction->ID] = it == reputations.end() ? total : std::max(it->second, total);
                }
            } while (r->NextRow());
        }
        for (auto const& [index, etat] : player->GetReputationMgr().GetStateList())
        {
            int32 total = player->GetReputationMgr().GetReputation(etat.ID);
            auto it = reputations.find(etat.ID);
            reputations[etat.ID] = it == reputations.end() ? total : std::max(it->second, total);
        }
        auto exalte = [&](uint32 faction) { auto it = reputations.find(faction); return it != reputations.end() && it->second >= EXALTE; };
        uint32 principales = 0, exaltees = 0;
        for (uint32 faction : REPUTATIONS)
            principales += exalte(faction) ? 1 : 0;
        principales += (exalte(AVANT_GARDE[0]) || exalte(AVANT_GARDE[1])) ? 1 : 0;
        for (auto const& [faction, valeur] : reputations)
            exaltees += valeur >= EXALTE ? 1 : 0;

        // --- Métiers : meilleure valeur du compte (métiers partagés, personnages, personnage connecté).
        std::map<uint32, uint32> metiers;
        if (QueryResult r = CharacterDatabase.Query("SELECT skill, valeur FROM solazeroth_metiers_compte WHERE account = {}", compte))
        {
            do
                metiers[(*r)[0].Get<uint32>()] = (*r)[1].Get<uint32>();
            while (r->NextRow());
        }
        if (QueryResult r = CharacterDatabase.Query("SELECT s.skill, MAX(s.value) FROM character_skills s JOIN characters c ON c.guid = s.guid "
            "WHERE c.account = {} GROUP BY s.skill", compte))
        {
            do
                metiers[(*r)[0].Get<uint32>()] = std::max(metiers[(*r)[0].Get<uint32>()], (*r)[1].Get<uint32>());
            while (r->NextRow());
        }
        float partMetiers = 0.0f;
        uint32 metiers450 = 0;
        for (uint32 skill : METIERS)
        {
            uint32 valeur = std::max<uint32>(metiers[skill], player->GetPureSkillValue(skill));
            partMetiers += Part(valeur, 450) / float(std::size(METIERS));
            metiers450 += valeur >= 450 ? 1 : 0;
        }

        // --- Défis de boss réussis au moins une fois.
        uint32 defis = 0;
        for (uint32 boss : Liste(CharacterDatabase.Query("SELECT boss FROM solazeroth_defis_reussis WHERE account = {}", compte)))
            defis += bossDeDonjon.count(boss);

        // --- Quêtes rendues (distinctes, tout le compte).
        uint32 quetes = 0;
        if (QueryResult r = CharacterDatabase.Query("SELECT COUNT(DISTINCT q.quest) FROM character_queststatus_rewarded q "
            "JOIN characters c ON c.guid = q.guid WHERE c.account = {}", compte))
            quetes = uint32((*r)[0].Get<uint64>());

        uint32 recettes = 0, nbMontures = 0, nbMascottes = 0;
        for (uint32 sort : sorts)
        {
            recettes += recettesRares.count(sort);
            nbMontures += montures.count(sort);
            nbMascottes += mascottes.count(sort);
        }

        // --- Classes : chacune des 9 autres classes vers le niveau 80 (la classe la plus avancée est la principale).
        uint8 principale = 0;
        for (auto const& [classe, part] : parClasse)
            if (!principale || part > parClasse[principale])
                principale = classe;
        float partClasses = 0.0f;
        uint32 classes80 = 0;
        for (auto const& [classe, part] : parClasse)
            if (classe != principale)
            {
                partClasses += part / 9.0f;
                classes80 += part >= 1.0f ? 1 : 0;
            }

        uint32 hfObtenus = 0, hfTotal = 0;
        SolAzeroth::HautsFaitsDuCompte(compte, hfObtenus, hfTotal);
        uint32 primes = compteurs["primes"], rares = compteurs["elites_rares"], sansFilet = compteurs["defis_sans_filet"];

        // --- Fin « Maître »
        res.lignes.push_back({ 2, "Donjons, rangs 1 à 5", 150.0f, Part(faits15, cases15),
            Acore::StringFormat("{} / {} rangs réussis ({} donjons)", faits15, cases15, donjons.size()) });
        res.lignes.push_back({ 2, "Raids du Norfendre", 120.0f, Part(wotlk, uint32(raidsWotlk.size())),
            Acore::StringFormat("{} / {} raids terminés au rang 0 (les rangs 1 à 3 viendront avec le rang de menace des raids)",
                wotlk, raidsWotlk.size()) });
        res.lignes.push_back({ 2, "Monde", 150.0f,
            (60.0f * Part(uint32(explores.size()), 4) + 60.0f * Part(principales, 6) + 30.0f * Part(primes, objectifs.primes)) / 150.0f,
            Acore::StringFormat("Exploration {} / 4 - Réputations principales exaltées {} / 6 - Primes de zone {} / {}",
                explores.size(), principales, std::min(primes, objectifs.primes), objectifs.primes) });
        res.lignes.push_back({ 2, "Métiers", 100.0f, partMetiers,
            Acore::StringFormat("{} métiers sur 14 à 450", metiers450) });
        res.lignes.push_back({ 2, "Défis de base", 50.0f, Part(defis, uint32(bossDeDonjon.size())),
            Acore::StringFormat("{} / {} boss dont le défi est réussi", defis, bossDeDonjon.size()) });

        // --- Fin « 100 % »
        res.lignes.push_back({ 3, "Donjons, rangs 6 à 10", 200.0f, Part(faits610, cases610),
            Acore::StringFormat("{} / {} rangs réussis (donjons du Norfendre)", faits610, cases610) });
        res.lignes.push_back({ 3, "Raids anciens", 180.0f, Part(anciens, uint32(raidsAnciens.size())),
            Acore::StringFormat("{} / {} raids classiques et de l'Outreterre terminés (les rangs 4 et 5 du Norfendre viendront plus tard)",
                anciens, raidsAnciens.size()) });
        res.lignes.push_back({ 3, "Monde, tout", 250.0f,
            (100.0f * Part(exaltees, objectifs.reputations) + 50.0f * Part(rares, objectifs.rares) + 100.0f * Part(quetes, objectifs.quetes)) / 250.0f,
            Acore::StringFormat("Réputations exaltées {} / {} - Élites rares {} / {} - Quêtes {} / {}",
                std::min(exaltees, objectifs.reputations), objectifs.reputations, std::min(rares, objectifs.rares), objectifs.rares,
                std::min(quetes, objectifs.quetes), objectifs.quetes) });
        res.lignes.push_back({ 3, "Recettes rares", 100.0f, Part(recettes, uint32(recettesRares.size())),
            Acore::StringFormat("{} / {} recettes qui ne s'apprennent pas chez l'entraîneur", recettes, recettesRares.size()) });
        res.lignes.push_back({ 3, "Classes", 500.0f, partClasses,
            Acore::StringFormat("{} / 9 autres classes au niveau 80 (classe principale : {})", classes80,
                principale < std::size(NOMS_CLASSES) ? NOMS_CLASSES[principale] : "?") });
        // Journal de collection compté à 80 % (section 7.3) : 150 h ; montures et mascottes : 75 h chacune.
        uint32 journal = 0, journalTotal = 0;
        SolAzeroth::JournalDeCollection(compte, journal, journalTotal);
        uint32 journalObjectif = uint32(std::ceil(journalTotal * 0.8f));
        res.lignes.push_back({ 3, "Collections", 300.0f,
            (150.0f * Part(journal, journalObjectif) + 75.0f * Part(nbMontures, objectifs.montures) + 75.0f * Part(nbMascottes, objectifs.mascottes)) / 300.0f,
            Acore::StringFormat("Journal de collection {} / {} (80 % de {}) - Montures {} / {} - Mascottes {} / {}",
                std::min(journal, journalObjectif), journalObjectif, journalTotal,
                std::min(nbMontures, objectifs.montures), objectifs.montures, std::min(nbMascottes, objectifs.mascottes), objectifs.mascottes) });
        res.lignes.push_back({ 3, "Défis et hauts faits", 200.0f,
            (100.0f * Part(sansFilet, objectifs.sansFilet) + 100.0f * Part(hfObtenus, hfTotal)) / 200.0f,
            Acore::StringFormat("Défis « Sans filet » {} / {} - Hauts faits du compte {} / {}",
                std::min(sansFilet, objectifs.sansFilet), objectifs.sansFilet, hfObtenus, hfTotal) });

        // Fins emboîtées : heures accomplies sur heures des lignes de cette fin et des précédentes.
        for (uint8 fin = 1; fin <= 3; ++fin)
        {
            float faites = 0.0f, total = 0.0f;
            for (Ligne const& l : res.lignes)
                if (l.fin <= fin)
                {
                    faites += l.heures * std::min(1.0f, l.part);
                    total += l.heures;
                }
            res.fins[fin] = total > 0.0f ? 100.0f * faites / total : 0.0f;
        }
        for (Ligne const& l : res.lignes)
            res.heures += l.heures * std::min(1.0f, l.part);

        std::lock_guard<std::mutex> garde(verrou);
        cache[compte] = { GameTime::GetGameTime().count(), res };
        return res;
    }

    void Envoyer(Player* player)
    {
        Resultat res = Calculer(player);
        for (Ligne const& l : res.lignes)
            SolAzeroth::EnvoyerAddon(player, PREFIXE, Acore::StringFormat("L;{};{};{:.0f};{:.1f};{}",
                l.fin, l.nom, l.heures, 100.0f * std::min(1.0f, l.part), l.detail));
        SolAzeroth::EnvoyerAddon(player, PREFIXE, Acore::StringFormat("FINS;{:.1f};{:.1f};{:.1f}", res.fins[1], res.fins[2], res.fins[3]));
    }

    // Recalculé au plus une fois par minute (les hauts faits vérifient toutes les 30 secondes).
    Resultat EnCache(Player* player)
    {
        uint32 compte = player->GetSession()->GetAccountId();
        {
            std::lock_guard<std::mutex> garde(verrou);
            auto it = cache.find(compte);
            if (it != cache.end() && GameTime::GetGameTime().count() - it->second.first < 60)
                return it->second.second;
        }
        return Calculer(player);
    }
}

float SolAzeroth::PourcentFinCodex(Player* player, unsigned char fin)
{
    return fin >= 1 && fin <= 3 ? EnCache(player).fins[fin] : 0.0f;
}

float SolAzeroth::HeuresCodex(Player* player)
{
    return EnCache(player).heures;
}

// Élites rares tuées (ligne Monde du Codex).
class solazeroth_codex_joueur : public PlayerScript
{
public:
    solazeroth_codex_joueur() : PlayerScript("solazeroth_codex_joueur", { PLAYERHOOK_ON_CREATURE_KILL_CREDIT }) { }

    void OnPlayerCreatureKillCredit(Player* player, Creature* tue) override
    {
        if (!tue)
            return;
        uint32 rang = tue->GetCreatureTemplate()->rank;
        if (rang == CREATURE_ELITE_RARE || rang == CREATURE_ELITE_RAREELITE)
            CharacterDatabase.Execute("INSERT IGNORE INTO solazeroth_rares_tues (account, entry) VALUES ({}, {})",
                player->GetSession()->GetAccountId(), tue->GetEntry());
    }
};

// Raid terminé : son dernier boss est vaincu (chaque joueur présent).
class solazeroth_codex_raids : public UnitScript
{
public:
    solazeroth_codex_raids() : UnitScript("solazeroth_codex_raids", true, { UNITHOOK_ON_UNIT_DEATH }) { }

    void OnUnitDeath(Unit* unite, Unit* /*tueur*/) override
    {
        if (!unite->IsCreature() || !unite->GetMap()->IsRaid())
            return;
        auto it = bossFinauxRaid.find(unite->GetEntry());
        if (it == bossFinauxRaid.end() || it->second != unite->GetMapId())
            return;
        for (auto const& ref : unite->GetMap()->GetPlayers())
            if (Player* player = ref.GetSource())
                CharacterDatabase.Execute("INSERT IGNORE INTO solazeroth_raids_reussis (account, map_id) VALUES ({}, {})",
                    player->GetSession()->GetAccountId(), it->second);
    }
};

class solazeroth_codex_commandes : public CommandScript
{
public:
    solazeroth_codex_commandes() : CommandScript("solazeroth_codex_commandes") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable commandes =
        {
            { "solcodex", HandleCodex, SEC_PLAYER, Console::No },
        };
        return commandes;
    }

    static bool HandleCodex(ChatHandler* handler)
    {
        Envoyer(handler->GetPlayer());
        return true;
    }
};

class solazeroth_codex_monde : public WorldScript
{
public:
    solazeroth_codex_monde() : WorldScript("solazeroth_codex_monde", { WORLDHOOK_ON_AFTER_CONFIG_LOAD, WORLDHOOK_ON_STARTUP }) { }

    void OnAfterConfigLoad(bool /*rechargement*/) override
    {
        objectifs.primes = sConfigMgr->GetOption<uint32>("SolAzeroth.Codex.Primes", 50);
        objectifs.reputations = sConfigMgr->GetOption<uint32>("SolAzeroth.Codex.Reputations", 50);
        objectifs.rares = sConfigMgr->GetOption<uint32>("SolAzeroth.Codex.ElitesRares", 100);
        objectifs.quetes = sConfigMgr->GetOption<uint32>("SolAzeroth.Codex.Quetes", 3000);
        objectifs.sansFilet = sConfigMgr->GetOption<uint32>("SolAzeroth.Codex.SansFilet", 100);
        objectifs.montures = sConfigMgr->GetOption<uint32>("SolAzeroth.Codex.Montures", 100);
        objectifs.mascottes = sConfigMgr->GetOption<uint32>("SolAzeroth.Codex.Mascottes", 100);
        objectifs.plafondAncien = sConfigMgr->GetOption<uint32>("SolAzeroth.Menace.PlafondClassiqueBC", 5);
        objectifs.plafondWotlk = sConfigMgr->GetOption<uint32>("SolAzeroth.Menace.PlafondWotLK", 10);
    }

    void OnStartup() override
    {
        xpCumul.assign(82, 0);
        for (uint8 niveau = 1; niveau <= 80; ++niveau)
            xpCumul[niveau + 1] = xpCumul[niveau] + (niveau < 80 ? sObjectMgr->GetXPForLevel(niveau) : 0);

        // Donjons et raids : cartes qui ont un dernier boss ; boss de donjon : tous les boss de rencontre d'un donjon.
        if (QueryResult r = WorldDatabase.Query("SELECT entry, creditType, creditEntry, lastEncounterDungeon FROM instance_encounters"))
        {
            do
            {
                Field* f = r->Fetch();
                DungeonEncounterEntry const* rencontre = sDungeonEncounterStore.LookupEntry(f[0].Get<uint32>());
                MapEntry const* carte = rencontre ? sMapStore.LookupEntry(rencontre->mapId) : nullptr;
                if (!carte)
                    continue;
                bool creature = f[1].Get<uint8>() == 0;
                if (carte->IsNonRaidDungeon())
                {
                    donjons[carte->MapID] = carte->Expansion();
                    if (creature)
                        bossDeDonjon.insert(f[2].Get<uint32>());
                }
                else if (carte->IsRaid() && f[3].Get<uint32>())
                {
                    (carte->Expansion() >= 2 ? raidsWotlk : raidsAnciens).insert(carte->MapID);
                    if (creature)
                        bossFinauxRaid[f[2].Get<uint32>()] = carte->MapID;
                }
            } while (r->NextRow());
        }

        // Recettes rares : apprises par un objet de recette (hors livres) et absentes des entraîneurs.
        recettesRares = Liste(WorldDatabase.Query("SELECT DISTINCT spellid_2 FROM item_template WHERE class = 9 AND subclass <> 0 "
            "AND spellid_1 IN (483, 55884) AND spellid_2 <> 0 AND spellid_2 NOT IN (SELECT SpellId FROM trainer_spell)"));

        for (uint32 i = 0; i < sSkillLineAbilityStore.GetNumRows(); ++i)
            if (SkillLineAbilityEntry const* a = sSkillLineAbilityStore.LookupEntry(i))
            {
                if (a->SkillLine == SKILL_MOUNTS)
                    montures.insert(a->Spell);
                else if (a->SkillLine == SKILL_COMPANIONS)
                    mascottes.insert(a->Spell);
            }

        LOG_INFO("module", "Sol'Azeroth Codex : {} donjons, {} raids du Norfendre, {} raids anciens, {} boss de donjon, {} recettes rares, {} montures, {} mascottes",
            donjons.size(), raidsWotlk.size(), raidsAnciens.size(), bossDeDonjon.size(), recettesRares.size(), montures.size(), mascottes.size());
    }
};

void AddSC_solazeroth_codex()
{
    new solazeroth_codex_joueur();
    new solazeroth_codex_raids();
    new solazeroth_codex_commandes();
    new solazeroth_codex_monde();
}
