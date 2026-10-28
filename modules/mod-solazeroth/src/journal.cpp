// Journal de donjon pour l'équilibrage (demande de l'utilisateur, V2)
// À chaque nouvelle instance de donjon ou de raid, le fichier journaux\<carte>_<nom>.log est remplacé.
// Il contient : le personnage (niveau, talents, statistiques, équipement), les réglages de difficulté,
// chaque monstre engagé (PV et mana actuels comparés à l'original), chaque combat (durée, dégâts,
// soins), les sorts lancés par les monstres et les morts. Claude le lit après le donjon pour comparer
// avec le jeu d'origine et proposer des réglages.

#include "SolAzeroth.h"
#include "Config.h"
#include "Creature.h"
#include "Item.h"
#include "Map.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "SpellInfo.h"
#include "StringFormat.h"
#include "World.h"
#include <cctype>
#include <chrono>
#include <filesystem>
#include <fstream>
#include <map>
#include <memory>
#include <mutex>
#include <unordered_map>

namespace
{
    std::string const DOSSIER = "C:/SolAzeroth/journaux";
    uint32 const SPHERE_INSTABLE = 900100;   // affixe Explosif (affixes_mecanique.cpp)

    struct Sort
    {
        std::string nom;
        uint32 nombre = 0;
        uint64 total = 0;
    };

    struct Monstre
    {
        std::string nom;
        uint32 entree = 0;
        double debut = 0;
        uint64 degatsRecus = 0;      // infligés par le joueur et ses familiers
        uint64 degatsInfliges = 0;   // au joueur et à ses familiers
        std::map<uint32, Sort> sorts;
    };

    struct Journal
    {
        std::ofstream fichier;
        std::chrono::steady_clock::time_point depart = std::chrono::steady_clock::now();
        std::unordered_map<ObjectGuid, Monstre> monstres;
        double debutCombat = -1;
        uint64 combatInfliges = 0, combatSubis = 0, combatSoins = 0;
        uint64 totalInfliges = 0, totalSubis = 0, totalSoins = 0;
        uint32 combats = 0, morts = 0, mortsJoueur = 0;

        double Temps() const
        {
            return std::chrono::duration<double>(std::chrono::steady_clock::now() - depart).count();
        }

        void Ecrire(std::string const& ligne)
        {
            fichier << Acore::StringFormat("[{:7.1f}] ", Temps()) << ligne << '\n';
            fichier.flush();
        }
    };

    std::mutex verrou;
    std::unordered_map<uint32, std::unique_ptr<Journal>> journaux;   // clé : identifiant d'instance

    bool Suivie(Map const* map)
    {
        return map && map->IsDungeon();
    }

    Journal* Trouver(Map const* map)
    {
        if (!Suivie(map))
            return nullptr;
        auto it = journaux.find(map->GetInstanceId());
        return it != journaux.end() ? it->second.get() : nullptr;
    }

    bool CoteJoueur(Unit const* unite)
    {
        return unite && unite->GetCharmerOrOwnerPlayerOrPlayerItself();
    }

    std::string NomFichier(Map const* map)
    {
        std::string nom = map->GetMapName();
        for (char& c : nom)
            if (!std::isalnum(static_cast<unsigned char>(c)))
                c = '_';
        return Acore::StringFormat("{}/{}_{}.log", DOSSIER, map->GetId(), nom);
    }

    std::string NomSort(SpellInfo const* sort)
    {
        if (!sort)
            return "attaque";
        char const* nom = sort->SpellName[sWorld->GetDefaultDbcLocale()];
        return nom && *nom ? nom : Acore::StringFormat("sort {}", sort->Id);
    }

    char const* const NOMS_EMPLACEMENTS[] = { "tête", "cou", "épaules", "chemise", "torse", "taille", "jambes", "pieds",
        "poignets", "mains", "doigt 1", "doigt 2", "bijou 1", "bijou 2", "dos", "main droite", "main gauche", "distance", "tabard" };

    void EcrireJoueur(Journal& j, Player* player)
    {
        j.Ecrire(Acore::StringFormat("JOUEUR nom={} niveau={} race={} classe={} spé(arbre le plus rempli)={} talents dépensés={}",
            player->GetName(), player->GetLevel(), player->getRace(), player->getClass(), player->GetMostPointsTalentTree(),
            player->CalculateTalentsPoints() - player->GetFreeTalentPoints()));
        j.Ecrire(Acore::StringFormat("STATS pv={} mana={} armure={} force={} agilité={} endurance={} intelligence={} esprit={} puissance_attaque={} puissance_sorts={} critique={:.1f}%",
            player->GetMaxHealth(), player->GetMaxPower(POWER_MANA), player->GetArmor(),
            player->GetStat(STAT_STRENGTH), player->GetStat(STAT_AGILITY), player->GetStat(STAT_STAMINA),
            player->GetStat(STAT_INTELLECT), player->GetStat(STAT_SPIRIT),
            player->GetTotalAttackPowerValue(BASE_ATTACK), player->SpellBaseDamageBonusDone(SPELL_SCHOOL_MASK_ALL),
            player->GetFloatValue(PLAYER_CRIT_PERCENTAGE)));

        uint32 somme = 0, nombre = 0;
        for (uint8 emplacement = EQUIPMENT_SLOT_START; emplacement < EQUIPMENT_SLOT_END; ++emplacement)
        {
            Item* objet = player->GetItemByPos(INVENTORY_SLOT_BAG_0, emplacement);
            if (!objet)
                continue;
            ItemTemplate const* modele = objet->GetTemplate();
            j.Ecrire(Acore::StringFormat("EQUIPEMENT {} = {} (entrée {}, niveau d'objet {}, qualité {})",
                NOMS_EMPLACEMENTS[emplacement], modele->Name1, modele->ItemId, modele->ItemLevel, modele->Quality));
            if (emplacement != EQUIPMENT_SLOT_BODY && emplacement != EQUIPMENT_SLOT_TABARD)
            {
                somme += modele->ItemLevel;
                ++nombre;
            }
        }
        j.Ecrire(Acore::StringFormat("EQUIPEMENT niveau d'objet moyen = {:.1f} sur {} emplacements", nombre ? double(somme) / nombre : 0.0, nombre));
    }

    void EcrireReglages(Journal& j, Map const* map)
    {
        auto valeur = [](char const* cle) { return sConfigMgr->GetOption<std::string>(cle, "?", false); };
        uint8 affixes = SolAzeroth::AffixesInstance(map->GetInstanceId());
        j.Ecrire(Acore::StringFormat("REGLAGES rang_menace={} affixe_semaine={} difficulté={}",
            SolAzeroth::RangInstance(map->GetInstanceId()), SolAzeroth::AffixeDeLaSemaine(), uint32(map->GetDifficulty())));
        j.Ecrire(Acore::StringFormat("REGLAGES affixes_mecanique={} palier_butin={}",
            affixes ? SolAzeroth::NomsAffixesMecanique(affixes) : "aucun", SolAzeroth::PalierButin(map)));
        j.Ecrire(Acore::StringFormat("REGLAGES autobalance MinPlayers={} PV={} dégâts={} mana={} boss_PV={} boss_dégâts={} XP={}",
            valeur("AutoBalance.MinPlayers"), valeur("AutoBalance.StatModifier.Health"), valeur("AutoBalance.StatModifier.Damage"),
            valeur("AutoBalance.StatModifier.Mana"), valeur("AutoBalance.StatModifier.Boss.Health"),
            valeur("AutoBalance.StatModifier.Boss.Damage"), valeur("AutoBalance.RewardScaling.XP.Modifier")));
    }

    void FinCombat(Journal& j, Player* player)
    {
        if (j.debutCombat < 0)
            return;
        double duree = j.Temps() - j.debutCombat;
        j.Ecrire(Acore::StringFormat("FIN_COMBAT durée={:.1f}s dégâts_infligés={} ({:.0f}/s) dégâts_subis={} ({:.0f}/s) soins_reçus={} pv_restants={}%",
            duree, j.combatInfliges, duree > 0 ? j.combatInfliges / duree : 0.0, j.combatSubis, duree > 0 ? j.combatSubis / duree : 0.0,
            j.combatSoins, player ? uint32(player->GetHealthPct()) : 0));
        j.debutCombat = -1;
        j.combatInfliges = j.combatSubis = j.combatSoins = 0;
    }

    void CompterSort(Journal& j, Unit* lanceur, SpellInfo const* sort, uint64 montant)
    {
        if (!lanceur || !lanceur->IsCreature() || CoteJoueur(lanceur) || !sort)
            return;
        auto it = j.monstres.find(lanceur->GetGUID());
        if (it == j.monstres.end())
            return;
        Sort& s = it->second.sorts[sort->Id];
        s.nom = NomSort(sort);
        ++s.nombre;
        s.total += montant;
    }
}

void SolAzeroth::Journaliser(Map const* map, std::string const& ligne)
{
    std::lock_guard<std::mutex> garde(verrou);
    if (Journal* j = Trouver(map))
        j->Ecrire("EVENEMENT " + ligne);
}

class solazeroth_journal_joueur : public PlayerScript
{
public:
    solazeroth_journal_joueur() : PlayerScript("solazeroth_journal_joueur", {
        PLAYERHOOK_ON_MAP_CHANGED, PLAYERHOOK_ON_PLAYER_ENTER_COMBAT }) { }

    // Nouvelle instance : on remplace le journal de ce donjon. Instance déjà connue : on note le retour.
    void OnPlayerMapChanged(Player* player) override
    {
        Map* map = player->GetMap();
        if (!Suivie(map))
            return;
        std::lock_guard<std::mutex> garde(verrou);
        if (Journal* j = Trouver(map))
        {
            j->Ecrire("RETOUR dans l'instance");
            return;
        }
        std::error_code erreur;
        std::filesystem::create_directories(DOSSIER, erreur);
        auto j = std::make_unique<Journal>();
        j->fichier.open(NomFichier(map), std::ios::out | std::ios::trunc);
        if (!j->fichier)
            return;
        j->Ecrire(Acore::StringFormat("DONJON carte={} nom={} instance={} joueurs_max={}",
            map->GetId(), map->GetMapName(), map->GetInstanceId(), map->ToInstanceMap() ? map->ToInstanceMap()->GetMaxPlayers() : 0));
        EcrireJoueur(*j, player);
        EcrireReglages(*j, map);
        journaux[map->GetInstanceId()] = std::move(j);
    }

    void OnPlayerEnterCombat(Player* player, Unit* ennemi) override
    {
        std::lock_guard<std::mutex> garde(verrou);
        Journal* j = Trouver(player->GetMap());
        if (!j || j->debutCombat >= 0)
            return;
        j->debutCombat = j->Temps();
        ++j->combats;
        j->Ecrire(Acore::StringFormat("DEBUT_COMBAT n°{} contre {} rang_menace={} pv_joueur={}%",
            j->combats, ennemi ? ennemi->GetName() : "?", SolAzeroth::RangInstance(player->GetMap()->GetInstanceId()),
            uint32(player->GetHealthPct())));
    }
};

// Note un monstre engagé : ses valeurs actuelles et celles du jeu d'origine.
static void Engager(Creature* creature)
{
    std::lock_guard<std::mutex> garde(verrou);
    Journal* j = Trouver(creature->GetMap());
    if (!j || j->monstres.count(creature->GetGUID()))
        return;
    CreatureTemplate const* modele = creature->GetCreatureTemplate();
    CreatureBaseStats const* base = sObjectMgr->GetCreatureBaseStats(creature->GetLevel(), modele->unit_class);
    Monstre& m = j->monstres[creature->GetGUID()];
    m.nom = creature->GetName();
    m.entree = creature->GetEntry();
    m.debut = j->Temps();
    j->Ecrire(Acore::StringFormat("ENGAGE {} (entrée {}) niveau={} rang={} boss={} pv={} (origine {}) mana={} (origine {})",
        m.nom, m.entree, creature->GetLevel(), modele->rank, creature->IsDungeonBoss() ? "oui" : "non",
        creature->GetMaxHealth(), base ? base->GenerateHealth(modele) : 0,
        creature->GetMaxPower(POWER_MANA), base ? base->GenerateMana(modele) : 0));
}

void SolAzeroth::JournalApparition(Creature* creature)
{
    Engager(creature);
}

class solazeroth_journal_unites : public UnitScript
{
public:
    solazeroth_journal_unites() : UnitScript("solazeroth_journal_unites", true, {
        UNITHOOK_ON_DAMAGE, UNITHOOK_ON_HEAL, UNITHOOK_ON_UNIT_ENTER_COMBAT, UNITHOOK_ON_UNIT_EXIT_COMBAT, UNITHOOK_ON_UNIT_DEATH,
        UNITHOOK_MODIFY_SPELL_DAMAGE_TAKEN, UNITHOOK_MODIFY_PERIODIC_DAMAGE_AURAS_TICK, UNITHOOK_MODIFY_HEAL_RECEIVED }) { }

    // Premier engagement d'un monstre. La Sphère instable entre en combat dès son apparition, avant d'avoir son niveau
    // et ses PV : affixes_mecanique.cpp la note lui-même ensuite (JournalApparition).
    void OnUnitEnterCombat(Unit* unite, Unit* cible) override
    {
        if (!unite->IsCreature() || CoteJoueur(unite) || !CoteJoueur(cible) || unite->GetEntry() == SPHERE_INSTABLE)
            return;
        Engager(unite->ToCreature());
    }

    void OnDamage(Unit* attaquant, Unit* victime, uint32& degats) override
    {
        if (!victime || !degats)
            return;
        std::lock_guard<std::mutex> garde(verrou);
        Journal* j = Trouver(victime->GetMap());
        if (!j)
            return;
        if (CoteJoueur(attaquant) && !CoteJoueur(victime))
        {
            j->combatInfliges += degats;
            j->totalInfliges += degats;
            auto it = j->monstres.find(victime->GetGUID());
            if (it != j->monstres.end())
                it->second.degatsRecus += degats;
        }
        else if (attaquant && CoteJoueur(victime) && !CoteJoueur(attaquant))
        {
            j->combatSubis += degats;
            j->totalSubis += degats;
            auto it = j->monstres.find(attaquant->GetGUID());
            if (it != j->monstres.end())
                it->second.degatsInfliges += degats;
        }
    }

    void OnHeal(Unit* /*soigneur*/, Unit* cible, uint32& soins) override
    {
        if (!CoteJoueur(cible) || !soins)
            return;
        std::lock_guard<std::mutex> garde(verrou);
        if (Journal* j = Trouver(cible->GetMap()))
        {
            j->combatSoins += soins;
            j->totalSoins += soins;
        }
    }

    void ModifySpellDamageTaken(Unit* cible, Unit* attaquant, int32& degats, SpellInfo const* sort) override
    {
        if (!cible)
            return;
        std::lock_guard<std::mutex> garde(verrou);
        if (Journal* j = Trouver(cible->GetMap()))
            CompterSort(*j, attaquant, sort, degats > 0 ? uint64(degats) : 0);
    }

    void ModifyPeriodicDamageAurasTick(Unit* cible, Unit* attaquant, uint32& degats, SpellInfo const* sort) override
    {
        if (!cible)
            return;
        std::lock_guard<std::mutex> garde(verrou);
        if (Journal* j = Trouver(cible->GetMap()))
            CompterSort(*j, attaquant, sort, degats);
    }

    void ModifyHealReceived(Unit* cible, Unit* soigneur, uint32& soins, SpellInfo const* sort) override
    {
        if (!cible)
            return;
        std::lock_guard<std::mutex> garde(verrou);
        if (Journal* j = Trouver(cible->GetMap()))
            CompterSort(*j, soigneur, sort, soins);
    }

    void OnUnitExitCombat(Unit* unite) override
    {
        Player* player = unite->ToPlayer();
        if (!player)
            return;
        std::lock_guard<std::mutex> garde(verrou);
        if (Journal* j = Trouver(player->GetMap()))
            FinCombat(*j, player);
    }

    void OnUnitDeath(Unit* unite, Unit* tueur) override
    {
        std::lock_guard<std::mutex> garde(verrou);
        Journal* j = Trouver(unite->GetMap());
        if (!j)
            return;

        if (Player* player = unite->ToPlayer())
        {
            ++j->mortsJoueur;
            j->Ecrire(Acore::StringFormat("MORT_JOUEUR tué par {}", tueur ? tueur->GetName() : "?"));
            FinCombat(*j, player);
            return;
        }

        auto it = j->monstres.find(unite->GetGUID());
        if (it == j->monstres.end())
            return;
        Monstre const& m = it->second;
        ++j->morts;
        std::string sorts;
        for (auto const& [id, s] : m.sorts)
            sorts += Acore::StringFormat(" {} x{} ({})", s.nom, s.nombre, s.total);
        j->Ecrire(Acore::StringFormat("MORT {} (entrée {}) en {:.1f}s dégâts_reçus={} dégâts_infligés={} sorts:{}",
            m.nom, m.entree, j->Temps() - m.debut, m.degatsRecus, m.degatsInfliges, sorts.empty() ? " aucun" : sorts));

        if (SolAzeroth::EstBossFinal(m.entree))
            j->Ecrire(Acore::StringFormat("DONJON_REUSSI durée totale={:.0f}s combats={} monstres tués={} morts du joueur={} dégâts infligés={} subis={} soins reçus={}",
                j->Temps(), j->combats, j->morts, j->mortsJoueur, j->totalInfliges, j->totalSubis, j->totalSoins));
        j->monstres.erase(it);
    }
};

// Instance réinitialisée : son journal est fermé (le fichier reste jusqu'à la prochaine instance).
class solazeroth_journal_global : public GlobalScript
{
public:
    solazeroth_journal_global() : GlobalScript("solazeroth_journal_global", { GLOBALHOOK_ON_INSTANCEID_REMOVED }) { }

    void OnInstanceIdRemoved(uint32 instanceId) override
    {
        std::lock_guard<std::mutex> garde(verrou);
        journaux.erase(instanceId);
    }
};

void AddSC_solazeroth_journal()
{
    new solazeroth_journal_joueur();
    new solazeroth_journal_unites();
    new solazeroth_journal_global();
}
