// v3 (31/10/2026) : journal de combat, pour vérifier que les chiffres sont cohérents (demande de l'utilisateur).
// Un fichier par personnage et par connexion : journaux\combat\<nom>_<date>.log. Pour chaque combat :
// - la fiche du joueur (puissance, vie, armure, force, puissance d'attaque, dégâts et vitesse de l'arme, critique,
//   Rempart), puis celle de chaque monstre rencontré (puissance d'origine, vie, armure, dégâts et vitesse, malus du
//   joueur contre lui) ;
// - chaque coup, dans les deux sens : technique, dégâts reçus, part retirée par l'armure, absorbée (Rempart…),
//   résistée ou bloquée, critique, vie restante de la cible et Rempart du joueur ; les soins et les morts ;
// - un bilan : durée, dégâts infligés et subis par seconde, détail par technique.
// Les coups arrivent par l'accroche OnDamageLog, ajoutée au moteur (patches\azerothcore-v3-combat.patch).
// Réglage : SolAzeroth.V3.JournalCombat = 1 (0 pour le couper).

#include "SolAzeroth.h"
#include "Config.h"
#include "Creature.h"
#include "GameTime.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "SpellAuraEffects.h"
#include "SpellInfo.h"
#include "StringFormat.h"
#include <ctime>
#include <filesystem>
#include <fstream>
#include <map>
#include <set>

namespace
{
    std::string const DOSSIER = "C:/SolAzeroth/journaux/combat";
    uint32 const REMPART = 100010;

    bool actif = true;
    float malusParPoint = 2.0f;
    float malusMax = 75.0f;

    struct ParTechnique
    {
        uint32 coups = 0;
        uint32 critiques = 0;
        uint64 total = 0;
        uint32 maximum = 0;
    };

    struct Journal : DataMap::Base
    {
        std::ofstream fichier;
        bool enCombat = false;
        uint32 numero = 0;
        int64 debut = 0;
        std::set<ObjectGuid> fiches;
        std::map<std::string, ParTechnique> infliges;
        uint64 subis = 0, armureSubie = 0, absorbeSubi = 0, soins = 0;
        uint32 tues = 0;
    };

    std::string Heure()
    {
        std::time_t t = std::time(nullptr);
        std::tm tm{};
        localtime_s(&tm, &t);
        char texte[32];
        std::strftime(texte, sizeof(texte), "%Y-%m-%d_%Hh%M", &tm);
        return texte;
    }

    Journal* JournalDe(Player* player)
    {
        Journal* j = player->CustomData.GetDefault<Journal>("solazeroth_v3_journal");
        if (!j->fichier.is_open())
        {
            std::filesystem::create_directories(DOSSIER);
            j->fichier.open(DOSSIER + "/" + player->GetName() + "_" + Heure() + ".log", std::ios::app);
            j->fichier << "Journal de combat de " << player->GetName() << " (Sol'Azeroth v3). Armure : "
                << sConfigMgr->GetOption<float>("SolAzeroth.V3.ArmureParPoint", 20.0f) << " points d'armure retirent 1 point par coup physique, "
                << sConfigMgr->GetOption<float>("SolAzeroth.V3.ArmureMinimum", 25.0f) << " % du coup passent toujours. Monstres : vie x"
                << sConfigMgr->GetOption<float>("SolAzeroth.V3.MonstresVie", 2.0f) << ", dégâts x"
                << sConfigMgr->GetOption<float>("SolAzeroth.V3.MonstresDegats", 4.0f) << " (avant l'armure), sorts x"
                << sConfigMgr->GetOption<float>("SolAzeroth.V3.MonstresDegatsSorts", 2.0f) << ".\n";
        }
        return j;
    }

    Player* Joueur(Unit* unite)
    {
        return unite ? unite->GetCharmerOrOwnerPlayerOrPlayerItself() : nullptr;
    }

    std::string NomSort(SpellInfo const* sort)
    {
        if (!sort)
            return "mêlée";
        char const* nom = sort->SpellName[LOCALE_frFR];
        if (!nom || !*nom)
            nom = sort->SpellName[LOCALE_enUS];
        return Acore::StringFormat("{} ({})", nom && *nom ? nom : "?", sort->Id);
    }

    float Malus(Player* player, Creature* creature)
    {
        float manque = SolAzeroth::PuissanceCreature(creature) - SolAzeroth::PuissanceJoueur(player);
        return manque > 0.0f ? std::min(manque * malusParPoint, malusMax) : 0.0f;
    }

    int32 Rempart(Unit* unite)
    {
        AuraEffect* effet = unite->GetAuraEffect(REMPART, EFFECT_0);
        return effet ? effet->GetAmount() : 0;
    }

    float Secondes(Journal* j)
    {
        return (GameTime::GetGameTimeMS().count() - j->debut) / 1000.0f;
    }

    void FicheJoueur(Journal* j, Player* p)
    {
        j->fichier << Acore::StringFormat("  Joueur {} : puissance {:.1f}, vie {}/{}, armure {} (-{:.1f} par coup), force {:.0f}, "
            "endurance {:.0f}, puissance d'attaque {:.0f}, arme {:.0f}-{:.0f} toutes les {:.2f} s, critique {:.1f} %, Rempart {}\n",
            p->GetName(), SolAzeroth::PuissanceJoueur(p), p->GetHealth(), p->GetMaxHealth(), p->GetArmor(),
            p->GetArmor() / sConfigMgr->GetOption<float>("SolAzeroth.V3.ArmureParPoint", 20.0f),
            p->GetStat(STAT_STRENGTH), p->GetStat(STAT_STAMINA), p->GetTotalAttackPowerValue(BASE_ATTACK),
            p->GetFloatValue(UNIT_FIELD_MINDAMAGE), p->GetFloatValue(UNIT_FIELD_MAXDAMAGE), p->GetAttackTime(BASE_ATTACK) / 1000.0f,
            p->GetFloatValue(PLAYER_CRIT_PERCENTAGE), Rempart(p));
    }

    void FicheMonstre(Journal* j, Player* p, Creature* c)
    {
        if (!j->fiches.insert(c->GetGUID()).second)
            return;
        j->fichier << Acore::StringFormat("  Monstre {} (entrée {}{}) : puissance {}, vie {}/{}, armure {}, coups {:.0f}-{:.0f} "
            "toutes les {:.2f} s ; malus du joueur contre lui : {:.0f} %\n",
            c->GetName(), c->GetEntry(), c->isElite() ? ", élite" : "", uint32(SolAzeroth::PuissanceCreature(c)),
            c->GetHealth(), c->GetMaxHealth(), c->GetArmor(), c->GetFloatValue(UNIT_FIELD_MINDAMAGE),
            c->GetFloatValue(UNIT_FIELD_MAXDAMAGE), c->GetAttackTime(BASE_ATTACK) / 1000.0f, Malus(p, c));
    }

    void Commencer(Journal* j, Player* p)
    {
        if (j->enCombat)
            return;
        j->enCombat = true;
        ++j->numero;
        j->debut = GameTime::GetGameTimeMS().count();
        j->fiches.clear();
        j->infliges.clear();
        j->subis = j->armureSubie = j->absorbeSubi = j->soins = 0;
        j->tues = 0;
        std::time_t t = std::time(nullptr);
        std::tm tm{};
        localtime_s(&tm, &t);
        char heure[16];
        std::strftime(heure, sizeof(heure), "%H:%M:%S", &tm);
        j->fichier << Acore::StringFormat("\n=== Combat {} à {}, zone {}, carte {} ({:.0f}, {:.0f})\n", j->numero, heure,
            p->GetZoneId(), p->GetMapId(), p->GetPositionX(), p->GetPositionY());
        FicheJoueur(j, p);
    }

    void Terminer(Journal* j, Player* p)
    {
        if (!j->enCombat)
            return;
        j->enCombat = false;
        float duree = std::max(0.1f, Secondes(j));
        uint64 total = 0;
        for (auto const& [nom, t] : j->infliges)
            total += t.total;
        j->fichier << Acore::StringFormat("--- Bilan du combat {} : {:.1f} s, {} monstre(s) tué(s), vie {}/{}\n", j->numero, duree,
            j->tues, p->GetHealth(), p->GetMaxHealth());
        j->fichier << Acore::StringFormat("    infligés {} ({:.1f}/s) ; subis {} ({:.1f}/s), dont armure retirée {} et absorbé {} ; soins {}\n",
            total, total / duree, j->subis, j->subis / duree, j->armureSubie, j->absorbeSubi, j->soins);
        for (auto const& [nom, t] : j->infliges)
            j->fichier << Acore::StringFormat("    {} : {} coup(s), {} critique(s), total {}, moyenne {:.0f}, maximum {}\n",
                nom, t.coups, t.critiques, t.total, t.coups ? double(t.total) / t.coups : 0.0, t.maximum);
        j->fichier.flush();
    }
}

class solazeroth_v3_journal_unites : public UnitScript
{
public:
    solazeroth_v3_journal_unites() : UnitScript("solazeroth_v3_journal_unites", true, { UNITHOOK_ON_DAMAGE_LOG, UNITHOOK_ON_HEAL }) { }

    void OnDamageLog(Unit* attaquant, Unit* victime, SpellInfo const* sort, uint32 degats, uint32 armure, uint32 absorbe,
        uint32 resiste, uint32 bloque, bool critique, bool periodique) override
    {
        if (!actif || !attaquant || !victime)
            return;
        Player* source = Joueur(attaquant);
        Player* cible = victime->ToPlayer();
        Player* p = source ? source : cible;
        if (!p || (source && cible))
            return;
        Journal* j = JournalDe(p);
        Commencer(j, p);
        Creature* monstre = (source ? victime : attaquant)->ToCreature();
        if (monstre)
            FicheMonstre(j, p, monstre);

        uint32 vieApres = victime->GetHealth() > degats ? victime->GetHealth() - degats : 0;
        std::string nom = NomSort(sort) + (periodique ? " [périodique]" : "");
        j->fichier << Acore::StringFormat("{:7.1f} s  {} -> {} | {} | {}{} | armure -{} | absorbé {}{}{} | vie {}/{}{}\n",
            Secondes(j), attaquant->GetName(), victime->GetName(), nom, degats, critique ? " CRITIQUE" : "", armure, absorbe,
            resiste ? Acore::StringFormat(" | résisté {}", resiste) : "", bloque ? Acore::StringFormat(" | bloqué {}", bloque) : "",
            vieApres, victime->GetMaxHealth(), cible ? Acore::StringFormat(" | Rempart {}", Rempart(cible)) : "");

        if (source)
        {
            ParTechnique& t = j->infliges[(attaquant == source ? "" : "familier : ") + nom];
            ++t.coups;
            t.critiques += critique;
            t.total += degats;
            t.maximum = std::max(t.maximum, degats);
            // Mort comptée ici : la sortie de combat (bilan) arrive avant l'accroche de mort du monstre.
            if (!vieApres && monstre)
            {
                ++j->tues;
                j->fichier << Acore::StringFormat("{:7.1f} s  {} meurt\n", Secondes(j), monstre->GetName());
            }
        }
        else
        {
            j->subis += degats;
            j->armureSubie += armure;
            j->absorbeSubi += absorbe;
        }
    }

    void OnHeal(Unit* soigneur, Unit* cible, uint32& gain) override
    {
        Player* p = cible ? cible->ToPlayer() : nullptr;
        if (!actif || !p || !gain || !p->IsInCombat())
            return;
        Journal* j = JournalDe(p);
        Commencer(j, p);
        j->soins += gain;
        j->fichier << Acore::StringFormat("{:7.1f} s  {} soigne {} : +{} | vie {}/{}\n", Secondes(j),
            soigneur ? soigneur->GetName() : "?", p->GetName(), gain, std::min(p->GetHealth() + gain, p->GetMaxHealth()), p->GetMaxHealth());
    }
};

class solazeroth_v3_journal_joueur : public PlayerScript
{
public:
    solazeroth_v3_journal_joueur() : PlayerScript("solazeroth_v3_journal_joueur", {
        PLAYERHOOK_ON_PLAYER_LEAVE_COMBAT, PLAYERHOOK_ON_PLAYER_KILLED_BY_CREATURE, PLAYERHOOK_ON_LOGOUT }) { }

    void OnPlayerLeaveCombat(Player* player) override
    {
        if (actif)
            Terminer(JournalDe(player), player);
    }

    void OnPlayerKilledByCreature(Creature* tueur, Player* player) override
    {
        if (!actif)
            return;
        Journal* j = JournalDe(player);
        j->fichier << Acore::StringFormat("{:7.1f} s  MORT du joueur, tué par {}\n", Secondes(j), tueur->GetName());
        Terminer(j, player);
    }

    void OnPlayerLogout(Player* player) override
    {
        if (!actif)
            return;
        Journal* j = JournalDe(player);
        Terminer(j, player);
        j->fichier.close();
    }
};

class solazeroth_v3_journal_monde : public WorldScript
{
public:
    solazeroth_v3_journal_monde() : WorldScript("solazeroth_v3_journal_monde", { WORLDHOOK_ON_AFTER_CONFIG_LOAD }) { }

    void OnAfterConfigLoad(bool /*reload*/) override
    {
        actif = sConfigMgr->GetOption<bool>("SolAzeroth.V3.JournalCombat", true);
        malusParPoint = sConfigMgr->GetOption<float>("SolAzeroth.V3.MalusParPoint", 2.0f);
        malusMax = sConfigMgr->GetOption<float>("SolAzeroth.V3.MalusMax", 75.0f);
    }
};

void AddSC_solazeroth_v3_journal()
{
    new solazeroth_v3_journal_unites();
    new solazeroth_v3_journal_joueur();
    new solazeroth_v3_journal_monde();
}
