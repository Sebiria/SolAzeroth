// v3, F2 (31/10/2026) : règles de combat (document v3, sections 2.3, 2.4 et F2).
// - Tout coup porte : plus de raté, d'esquive, de parade, de blocage, ni de coup érafle ou écrasant, en mêlée comme pour
//   les sorts (résistance aux effets comprise). Seul le critique reste. Les sorts passent par l'accroche OnSpellHitRoll,
//   ajoutée au moteur (patches\azerothcore-v3-combat.patch).
// - Armure = réduction fixe : chaque coup physique perd armure / SolAzeroth.V3.ArmureParPoint points de dégâts, à la place
//   du pourcentage du moteur, en gardant au moins SolAzeroth.V3.ArmureMinimum % du coup.
// - Plus de ressource : les sorts ne coûtent plus ni mana, ni rage, ni énergie, ni puissance runique (les sorts payés en
//   vie gardent leur coût). L'affichage des barres disparaît avec l'interface v3 (F4).
// - Puissance du personnage : moyenne des niveaux d'objet équipés, rang d'amélioration compris (provisoire : les chiffres
//   par qualité et origine restent à fixer, question 3 du document). Envoyée à l'interface (« SOLPUISSANCE ») et
//   affichée par .puissance.
// - Malus hors de sa puissance : face à un monstre plus fort, les dégâts infligés par le joueur et ses familiers baissent
//   de SolAzeroth.V3.MalusParPoint % par point de puissance manquant, au plus SolAzeroth.V3.MalusMax %.
// - Calibrage (31/10/2026) : les dégâts des monstres contre le joueur et ses familiers sont multipliés par
//   SolAzeroth.V3.MonstresDegats, avant l'armure (leur vie l'est dans v3_niveau.cpp). Leurs sorts magiques et leurs
//   dégâts sur la durée, qui ne passent pas par l'armure, le sont par SolAzeroth.V3.MonstresDegatsSorts (×2 : Yarrog
//   Plaie-d'ombre tuait en 12 s à coups de Corruption à 40 par tick, journal du 31/10/2026), et leurs dégâts sur la durée
//   par SolAzeroth.V3.MonstresDegatsDuree (×1,5, accord de l'utilisateur après d'autres essais contre Yarrog).

#include "SolAzeroth.h"
#include "Chat.h"
#include "CommandScript.h"
#include "Config.h"
#include "Creature.h"
#include "Item.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "SpellInfo.h"
#include "StringFormat.h"
#include <cmath>

using namespace Acore::ChatCommands;

namespace
{
    char const* const PREFIXE = "SOLPUISSANCE";
    uint32 const TICK_PUISSANCE = 2000;

    struct Reglages
    {
        float armureParPoint = 20.0f;
        float armureMinimum = 25.0f;
        float malusParPoint = 2.0f;
        float malusMax = 75.0f;
        float pourcentParRang = 0.03f;
        float degatsMonstres = 4.0f;
        float degatsSorts = 2.0f;
        float degatsDuree = 1.5f;
    } reglages;

    struct Puissance : DataMap::Base
    {
        float valeur = 0.0f;
        uint32 attente = TICK_PUISSANCE;
        uint8 renvoi = 0;
        std::string affiche;
    };

    float CalculerPuissance(Player* player)
    {
        float somme = 0.0f;
        uint32 nombre = 0;
        for (uint8 emplacement = EQUIPMENT_SLOT_START; emplacement < EQUIPMENT_SLOT_END; ++emplacement)
        {
            if (emplacement == EQUIPMENT_SLOT_BODY || emplacement == EQUIPMENT_SLOT_TABARD)
                continue;
            Item* objet = player->GetItemByPos(INVENTORY_SLOT_BAG_0, emplacement);
            if (!objet)
                continue;
            somme += objet->GetTemplate()->ItemLevel
                * (1.0f + reglages.pourcentParRang * SolAzeroth::RangDObjet(objet->GetGUID().GetCounter()));
            ++nombre;
        }
        return nombre ? somme / nombre : 0.0f;
    }

    Puissance* PuissanceDe(Player* player)
    {
        return player->CustomData.GetDefault<Puissance>("solazeroth_v3_puissance");
    }

    // Malus en % (positif) du joueur face à cette créature.
    float Malus(Player* player, Creature const* creature)
    {
        float manque = SolAzeroth::PuissanceCreature(creature) - PuissanceDe(player)->valeur;
        return manque > 0.0f ? std::min(manque * reglages.malusParPoint, reglages.malusMax) : 0.0f;
    }

    Creature* Monstre(Unit* unite)
    {
        Creature* creature = unite ? unite->ToCreature() : nullptr;
        return creature && !creature->GetCharmerOrOwnerPlayerOrPlayerItself() ? creature : nullptr;
    }

    // 31/10/2026 (Familier vil de la vallée des Épreuves : Boule de feu à 1 100) : le moteur calcule les sorts des
    // monstres sur leur niveau affiché, 80, et non sur leur puissance (niveau d'origine). Rapport qui ramène un sort à la
    // puissance du monstre : points par niveau (SpellEffectInfo::CalcValue), sinon mise à l'échelle des sorts de
    // créature (SPELL_ATTR0_SCALES_WITH_CREATURE_LEVEL, d'après les dégâts de base de CreatureBaseStats).
    float EchelleSort(Unit* lanceur, SpellInfo const* sort)
    {
        Creature* creature = Monstre(lanceur);
        if (!creature || !sort)
            return 1.0f;
        int32 origine = SolAzeroth::PuissanceCreature(creature), affiche = creature->GetLevel();
        if (origine <= 0 || origine >= affiche)
            return 1.0f;
        for (SpellEffectInfo const& effet : sort->GetEffects())
        {
            if (!effet.Effect || effet.RealPointsPerLevel == 0.0f)
                continue;
            auto Valeur = [&](int32 niveau)
            {
                if (niveau > int32(sort->MaxLevel) && sort->MaxLevel > 0)
                    niveau = int32(sort->MaxLevel);
                else if (niveau < int32(sort->BaseLevel))
                    niveau = int32(sort->BaseLevel);
                niveau -= int32(std::max(sort->BaseLevel, sort->SpellLevel));
                return effet.BasePoints + 1 + std::abs(effet.DieSides) / 2.0f + niveau * effet.RealPointsPerLevel;
            };
            float haut = Valeur(affiche);
            return haut > 0.0f ? std::clamp(Valeur(origine) / haut, 0.0f, 1.0f) : 1.0f;
        }
        if (sort->HasAttribute(SPELL_ATTR0_SCALES_WITH_CREATURE_LEVEL) && sort->SpellLevel && int32(sort->SpellLevel) != affiche)
        {
            uint8 extension = creature->GetCreatureTemplate()->expansion;
            CreatureBaseStats const* haut = sObjectMgr->GetCreatureBaseStats(affiche, creature->getClass());
            CreatureBaseStats const* bas = sObjectMgr->GetCreatureBaseStats(origine, creature->getClass());
            if (haut && bas && haut->BaseDamage[extension] > 0.0f)
                return std::clamp(bas->BaseDamage[extension] / haut->BaseDamage[extension], 0.0f, 1.0f);
        }
        return 1.0f;
    }

    void Envoyer(Player* player)
    {
        Puissance* p = PuissanceDe(player);
        std::string message = Acore::StringFormat("PUISSANCE;{:.1f}", p->valeur);
        if (Creature* cible = Monstre(player->GetSelectedUnit()))
            message += Acore::StringFormat(";{};{:.0f}", uint32(SolAzeroth::PuissanceCreature(cible)), Malus(player, cible));
        if (message != p->affiche)
        {
            p->affiche = message;
            SolAzeroth::EnvoyerAddon(player, PREFIXE, message);
        }
    }
}

float SolAzeroth::PuissanceJoueur(Player* player)
{
    return PuissanceDe(player)->valeur;
}

class solazeroth_v3_combat_unites : public UnitScript
{
public:
    solazeroth_v3_combat_unites() : UnitScript("solazeroth_v3_combat_unites", true, {
        UNITHOOK_ON_BEFORE_ROLL_MELEE_OUTCOME_AGAINST, UNITHOOK_ON_SPELL_HIT_ROLL,
        UNITHOOK_ON_AFTER_CALC_ARMOR_REDUCED_DAMAGE, UNITHOOK_ON_SPELL_POWER_COST,
        UNITHOOK_MODIFY_MELEE_DAMAGE, UNITHOOK_MODIFY_SPELL_DAMAGE_TAKEN, UNITHOOK_MODIFY_PERIODIC_DAMAGE_AURAS_TICK,
        UNITHOOK_MODIFY_HEAL_RECEIVED }) { }

    // Compétences égalisées : ni bonus d'esquive ou de parade selon l'écart, ni coup érafle (attaquant = défense + 5),
    // ni coup écrasant (moins de 15 points d'écart), même face à un boss resté au-dessus du niveau 80.
    void OnBeforeRollMeleeOutcomeAgainst(Unit const* /*attaquant*/, Unit const* /*victime*/, WeaponAttackType /*type*/,
        int32& maxAttaquant, int32& maxVictime, int32& armeAttaquant, int32& defenseVictime, int32& /*critique*/,
        int32& rate, int32& esquive, int32& parade, int32& blocage) override
    {
        maxAttaquant = maxVictime;
        armeAttaquant = maxVictime;
        defenseVictime = maxVictime - 5;
        rate = 0;
        esquive = 0;
        parade = 0;
        blocage = 0;
    }

    void OnSpellHitRoll(WorldObject const* /*lanceur*/, Unit const* /*victime*/, SpellInfo const* /*sort*/, bool& toujours) override
    {
        toujours = true;
    }

    void OnAfterCalcArmorReducedDamage(Unit const* /*attaquant*/, Unit const* /*victime*/, uint32 degats, float armure,
        uint32& reduits) override
    {
        float minimum = degats * reglages.armureMinimum / 100.0f;
        reduits = uint32(std::ceil(std::max(degats - armure / reglages.armureParPoint, minimum)));
    }

    void OnSpellPowerCost(WorldObject const* lanceur, SpellInfo const* sort, int32& cout) override
    {
        if (lanceur && lanceur->ToUnit() && sort->PowerType != POWER_HEALTH)
            cout = 0;
    }

    template <typename T>
    static void AppliquerMalus(Unit* cible, Unit* attaquant, T& degats)
    {
        Player* player = attaquant ? attaquant->GetCharmerOrOwnerPlayerOrPlayerItself() : nullptr;
        Creature* creature = Monstre(cible);
        if (!player || !creature)
            return;
        if (float malus = Malus(player, creature))
            degats = T(degats * (1.0f - malus / 100.0f));
    }

    // multiplicateur : celui de la mêlée (et des techniques physiques, qui passent par l'armure), ou celui des sorts.
    template <typename T>
    static void AppliquerMonstre(Unit* cible, Unit* attaquant, T& degats, float multiplicateur)
    {
        if (multiplicateur != 1.0f && Monstre(attaquant) && cible && cible->GetCharmerOrOwnerPlayerOrPlayerItself())
            degats = T(std::lround(degats * multiplicateur)); // arrondi : 1 x 2,5 donnait 2 (journal du 31/10/2026)
    }

    template <typename T>
    static void Appliquer(Unit* cible, Unit* attaquant, T& degats, float multiplicateur)
    {
        AppliquerMalus(cible, attaquant, degats);
        AppliquerMonstre(cible, attaquant, degats, multiplicateur);
    }

    void ModifyMeleeDamage(Unit* cible, Unit* attaquant, uint32& degats) override
    {
        Appliquer(cible, attaquant, degats, reglages.degatsMonstres);
    }
    void ModifySpellDamageTaken(Unit* cible, Unit* attaquant, int32& degats, SpellInfo const* sort) override
    {
        degats = int32(std::lround(degats * EchelleSort(attaquant, sort)));
        bool physique = sort && (sort->GetSchoolMask() & SPELL_SCHOOL_MASK_NORMAL);
        Appliquer(cible, attaquant, degats, physique ? reglages.degatsMonstres : reglages.degatsSorts);
    }
    // Les dégâts sur la durée, même physiques (saignements), ne passent pas par l'armure.
    void ModifyPeriodicDamageAurasTick(Unit* cible, Unit* attaquant, uint32& degats, SpellInfo const* sort) override
    {
        degats = uint32(std::lround(degats * EchelleSort(attaquant, sort)));
        Appliquer(cible, attaquant, degats, reglages.degatsDuree);
    }
    // Soins des monstres (sur eux ou leurs alliés) : même rapport.
    void ModifyHealReceived(Unit* /*cible*/, Unit* soigneur, uint32& soin, SpellInfo const* sort) override
    {
        soin = uint32(std::lround(soin * EchelleSort(soigneur, sort)));
    }
};

class solazeroth_v3_combat_joueur : public PlayerScript
{
public:
    solazeroth_v3_combat_joueur() : PlayerScript("solazeroth_v3_combat_joueur", { PLAYERHOOK_ON_UPDATE }) { }

    void OnPlayerUpdate(Player* player, uint32 diff) override
    {
        Puissance* p = PuissanceDe(player);
        p->attente += diff;
        if (p->attente < TICK_PUISSANCE)
            return;
        p->attente = 0;
        p->valeur = CalculerPuissance(player);
        // Renvoi complet toutes les 10 s : l'interface v3 (F4) retrouve son état après un /reload.
        if (++p->renvoi >= 5)
        {
            p->renvoi = 0;
            p->affiche.clear();
        }
        Envoyer(player);
    }
};

class solazeroth_v3_combat_monde : public WorldScript
{
public:
    solazeroth_v3_combat_monde() : WorldScript("solazeroth_v3_combat_monde", { WORLDHOOK_ON_AFTER_CONFIG_LOAD }) { }

    void OnAfterConfigLoad(bool /*reload*/) override
    {
        reglages.armureParPoint = std::max(0.1f, sConfigMgr->GetOption<float>("SolAzeroth.V3.ArmureParPoint", 20.0f));
        reglages.armureMinimum = sConfigMgr->GetOption<float>("SolAzeroth.V3.ArmureMinimum", 25.0f);
        reglages.malusParPoint = sConfigMgr->GetOption<float>("SolAzeroth.V3.MalusParPoint", 2.0f);
        reglages.malusMax = sConfigMgr->GetOption<float>("SolAzeroth.V3.MalusMax", 75.0f);
        reglages.pourcentParRang = sConfigMgr->GetOption<float>("SolAzeroth.Bonus.PourcentParRang", 0.03f);
        reglages.degatsMonstres = sConfigMgr->GetOption<float>("SolAzeroth.V3.MonstresDegats", 4.0f);
        reglages.degatsSorts = sConfigMgr->GetOption<float>("SolAzeroth.V3.MonstresDegatsSorts", 2.0f);
        reglages.degatsDuree = sConfigMgr->GetOption<float>("SolAzeroth.V3.MonstresDegatsDuree", 1.5f);
    }
};

class solazeroth_v3_combat_commandes : public CommandScript
{
public:
    solazeroth_v3_combat_commandes() : CommandScript("solazeroth_v3_combat_commandes") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable commandes =
        {
            { "puissance", HandlePuissance, SEC_PLAYER, Console::No },
        };
        return commandes;
    }

    static bool HandlePuissance(ChatHandler* handler)
    {
        Player* player = handler->GetPlayer();
        Puissance* p = PuissanceDe(player);
        p->valeur = CalculerPuissance(player);
        handler->PSendSysMessage("Puissance : {:.1f}", p->valeur);
        if (Creature* cible = Monstre(player->GetSelectedUnit()))
            handler->PSendSysMessage("Cible {} : puissance {}, malus de dégâts {:.1f} %", cible->GetName(),
                uint32(SolAzeroth::PuissanceCreature(cible)), Malus(player, cible));
        return true;
    }
};

void AddSC_solazeroth_v3_combat()
{
    new solazeroth_v3_combat_unites();
    new solazeroth_v3_combat_joueur();
    new solazeroth_v3_combat_monde();
    new solazeroth_v3_combat_commandes();
}
