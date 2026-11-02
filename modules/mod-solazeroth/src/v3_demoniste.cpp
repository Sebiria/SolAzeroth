// v3, lot D2 (02/11/2026) : ce que Spell.dbc ne sait pas écrire dans le kit du démoniste Affliction (sorts :
// outils\demoniste_v3.py, migration 123 ; spécialisation et ordre de déblocage : v3_kit.cpp).
// - Les sorts ne font que de la puissance d'attaque (spell_bonus_data) : aucun dégât d'arme (règle de l'utilisateur).
// - Moisson (passif) : 20 % des dégâts des sorts sur la durée reviennent en vie.
// - Malédiction d'agonie : le tiers du milieu à 100 %, le premier à 50 %, le dernier à 150 %.
// - Drain d'âme : double sur une cible sous 25 % de vie. Affliction instable : +50 % sur une cible qui porte Corruption
//   et Agonie.
// - Graine de corruption : explose à la fin, ou à la mort de la cible.
// - Invocations temporaires (aucun familier permanent, règle de l'utilisateur) : Diablotin, Marcheur du Vide, Chasseur
//   corrompu. Leur vie suit celle du démoniste ; leurs attaques sont des sorts lancés au nom du démoniste (puissance
//   d'attaque du démoniste, menace sur lui). Elles repartent à la fin de leur durée, ou si le démoniste meurt ou s'éloigne.
// - Aucune attaque automatique (règle de l'utilisateur, 02/11/2026 : que des sorts). Le module passe après le coup
//   automatique dans la mise à jour du joueur : le minuteur d'attaque est donc tenu toujours chargé, et la posture
//   d'attaque coupée.

#include "SolAzeroth.h"
#include "Creature.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "ScriptedCreature.h"
#include "SpellAuraEffects.h"
#include "SpellScript.h"
#include "SpellScriptLoader.h"
#include "TemporarySummon.h"
#include <cmath>

namespace
{
    uint32 const MOISSON = 100200, CORRUPTION = 100202, DIABLOTIN = 100203, AGONIE = 100204, DRAIN_DE_VIE = 100205,
        MARCHEUR = 100207, SIPHON = 100209, GRAINE = 100211, EXPLOSION_GRAINE = 100212, DRAIN_D_AME = 100214,
        CHASSEUR = 100216, INSTABLE = 100217, MOISSON_SOIN = 100218, TRAIT_DE_FEU = 100219, VERROU = 100220,
        MORSURE = 100221, TOURMENT = 100222;
    int32 const PART_MOISSON = 20;              // % des dégâts sur la durée rendus en vie
    uint32 const CADENCE = 2000;                // une attaque d'invocation toutes les 2 s
    float const DISTANCE_MAX = 60.0f;           // au-delà, l'invocation repart
    int32 const JAMAIS_PRET = 60000;            // minuteur d'attaque automatique, rechargé à chaque mise à jour

    struct Invocation
    {
        uint32 sort;
        uint32 creature;
        uint32 duree;          // ms
        float vie;             // part de la vie maximale du démoniste
        bool attaquable;       // seul le Marcheur encaisse
    };

    Invocation const INVOCATIONS[] =
    {
        { DIABLOTIN, 910050, 15000, 0.3f, false },
        { MARCHEUR, 910051, 10000, 1.0f, true },
        { CHASSEUR, 910052, 15000, 0.5f, false },
    };

    bool SurLaDuree(uint32 sort)
    {
        switch (sort)
        {
            case CORRUPTION: case AGONIE: case DRAIN_DE_VIE: case SIPHON: case GRAINE: case DRAIN_D_AME: case INSTABLE:
                return true;
            default:
                return false;
        }
    }

    Unit* Proprietaire(Creature* moi)
    {
        TempSummon* invocation = moi->ToTempSummon();
        return invocation ? invocation->GetSummonerUnit() : nullptr;
    }

    // La cible du démoniste en combat : celle qu'il attaque, sinon celle qu'il a choisie.
    Unit* CibleDu(Unit* proprietaire)
    {
        if (!proprietaire->IsInCombat())
            return nullptr;
        Unit* cible = proprietaire->GetVictim();
        if (!cible)
            if (Player* joueur = proprietaire->ToPlayer())
                cible = joueur->GetSelectedUnit();
        return cible && cible->IsAlive() && proprietaire->IsValidAttackTarget(cible) ? cible : nullptr;
    }

    // L'invocation repart si le démoniste meurt ou s'éloigne.
    bool Garder(Creature* moi, Unit* proprietaire)
    {
        if (proprietaire && proprietaire->IsAlive() && moi->IsWithinDistInMap(proprietaire, DISTANCE_MAX))
            return true;
        moi->DespawnOrUnsummon();
        return false;
    }
}

class solazeroth_v3_demoniste_unites : public UnitScript
{
public:
    solazeroth_v3_demoniste_unites() : UnitScript("solazeroth_v3_demoniste_unites", true, {
        UNITHOOK_MODIFY_PERIODIC_DAMAGE_AURAS_TICK }) { }

    void ModifyPeriodicDamageAurasTick(Unit* cible, Unit* attaquant, uint32& degats, SpellInfo const* sort) override
    {
        if (!attaquant || !sort || !SurLaDuree(sort->Id))
            return;
        switch (sort->Id)
        {
            case AGONIE:
                if (AuraEffect const* effet = cible->GetAuraEffect(AGONIE, EFFECT_0, attaquant->GetGUID()))
                {
                    uint32 tiers = std::max<uint32>(1, effet->GetTotalTicks() / 3);
                    float facteur = effet->GetTickNumber() <= tiers ? 0.5f : effet->GetTickNumber() <= 2 * tiers ? 1.0f : 1.5f;
                    degats = uint32(degats * facteur);
                }
                break;
            case DRAIN_D_AME:
                if (cible->HealthBelowPct(25))
                    degats *= 2;
                break;
            case INSTABLE:
                if (cible->HasAura(CORRUPTION, attaquant->GetGUID()) && cible->HasAura(AGONIE, attaquant->GetGUID()))
                    degats = uint32(degats * 1.5f);
                break;
            default:
                break;
        }
        if (degats && attaquant->HasAura(MOISSON))
        {
            int32 soin = std::max<int32>(1, int32(degats * PART_MOISSON / 100));
            attaquant->CastCustomSpell(attaquant, MOISSON_SOIN, &soin, nullptr, nullptr, true);
        }
    }
};

class solazeroth_v3_demoniste_joueur : public PlayerScript
{
public:
    solazeroth_v3_demoniste_joueur() : PlayerScript("solazeroth_v3_demoniste_joueur", { PLAYERHOOK_ON_UPDATE }) { }

    void OnPlayerUpdate(Player* player, uint32 /*diff*/) override
    {
        if (player->getClass() != CLASS_WARLOCK)
            return;
        player->setAttackTimer(BASE_ATTACK, JAMAIS_PRET);
        player->setAttackTimer(OFF_ATTACK, JAMAIS_PRET);
        if (player->HasUnitState(UNIT_STATE_MELEE_ATTACKING))
            player->AttackStop();
    }
};

// Diablotin, Marcheur du Vide, Chasseur corrompu : la technique invoque, la créature (ScriptName) agit.
class spell_solazeroth_v3_invocation : public SpellScript
{
    PrepareSpellScript(spell_solazeroth_v3_invocation);

    void Invoquer(SpellEffIndex /*effet*/)
    {
        Unit* lanceur = GetCaster();
        if (!lanceur)
            return;
        for (Invocation const& i : INVOCATIONS)
        {
            if (i.sort != GetSpellInfo()->Id)
                continue;
            TempSummon* invocation = lanceur->SummonCreature(i.creature, lanceur->GetNearPosition(2.0f, float(M_PI) * 0.75f),
                TEMPSUMMON_TIMED_DESPAWN, i.duree);
            if (!invocation)
                return;
            invocation->SetFaction(lanceur->GetFaction());
            invocation->SetCreatorGUID(lanceur->GetGUID());
            uint32 vie = std::max<uint32>(1, uint32(lanceur->GetMaxHealth() * i.vie));
            invocation->SetCreateHealth(vie);
            invocation->SetStatFlatModifier(UNIT_MOD_HEALTH, BASE_VALUE, float(vie));
            invocation->SetMaxHealth(vie);
            invocation->SetHealth(vie);
            invocation->SetStatFlatModifier(UNIT_MOD_ARMOR, BASE_VALUE, float(lanceur->GetArmor()));
            invocation->UpdateArmor();
            // Ses coups au contact ne comptent pas : ses attaques sont des sorts au nom du démoniste.
            invocation->SetBaseWeaponDamage(BASE_ATTACK, MINDAMAGE, 1.0f);
            invocation->SetBaseWeaponDamage(BASE_ATTACK, MAXDAMAGE, 1.0f);
            invocation->UpdateDamagePhysical(BASE_ATTACK);
            if (!i.attaquable)
                invocation->SetUnitFlag(UNIT_FLAG_NON_ATTACKABLE);
            return;
        }
    }

    void Register() override
    {
        OnEffectHit += SpellEffectFn(spell_solazeroth_v3_invocation::Invoquer, EFFECT_0, SPELL_EFFECT_DUMMY);
    }
};

class spell_solazeroth_v3_graine : public AuraScript
{
    PrepareAuraScript(spell_solazeroth_v3_graine);

    void Exploser(AuraEffect const* /*effet*/, AuraEffectHandleModes /*mode*/)
    {
        AuraRemoveMode raison = GetTargetApplication()->GetRemoveMode();
        Unit* lanceur = GetCaster();
        Unit* cible = GetTarget();
        if (lanceur && cible && (raison == AURA_REMOVE_BY_EXPIRE || raison == AURA_REMOVE_BY_DEATH))
            lanceur->CastSpell(cible->GetPositionX(), cible->GetPositionY(), cible->GetPositionZ(), EXPLOSION_GRAINE, true);
    }

    void Register() override
    {
        AfterEffectRemove += AuraEffectRemoveFn(spell_solazeroth_v3_graine::Exploser, EFFECT_0, SPELL_AURA_PERIODIC_DAMAGE,
            AURA_EFFECT_HANDLE_REAL);
    }
};

// Commun aux invocations : ne prend pas l'initiative, suit le démoniste, repart avec lui.
struct solazeroth_v3_invocation_ai : public ScriptedAI
{
    explicit solazeroth_v3_invocation_ai(Creature* creature) : ScriptedAI(creature) { }

    uint32 attente = 0;
    bool suit = false;

    void MoveInLineOfSight(Unit* /*qui*/) override { }
    void EnterEvadeMode(EvadeReason /*raison*/) override { }

    void Suivre(Unit* proprietaire)
    {
        if (!suit)
            me->GetMotionMaster()->MoveFollow(proprietaire, 2.0f, float(M_PI) * 0.75f);
        suit = true;
    }
};

// Tire des traits de feu sur la cible du démoniste, sans bouger de ses côtés.
struct npc_solazeroth_v3_diablotin : public solazeroth_v3_invocation_ai
{
    explicit npc_solazeroth_v3_diablotin(Creature* creature) : solazeroth_v3_invocation_ai(creature) { }

    void AttackStart(Unit* /*cible*/) override { }

    void UpdateAI(uint32 diff) override
    {
        Unit* proprietaire = Proprietaire(me);
        if (!Garder(me, proprietaire))
            return;
        Suivre(proprietaire);
        if (attente > diff)
        {
            attente -= diff;
            return;
        }
        attente = 0;
        Unit* cible = CibleDu(proprietaire);
        if (cible && me->IsWithinDistInMap(cible, 30.0f) && me->IsWithinLOSInMap(cible))
        {
            me->SetFacingToObject(cible);
            me->CastSpell(cible, TRAIT_DE_FEU, true, nullptr, nullptr, proprietaire->GetGUID());
            attente = CADENCE;
        }
    }
};

// Provoque les ennemis à 15 m à son arrivée, puis se bat au contact.
struct npc_solazeroth_v3_marcheur : public solazeroth_v3_invocation_ai
{
    explicit npc_solazeroth_v3_marcheur(Creature* creature) : solazeroth_v3_invocation_ai(creature) { }

    bool provoque = false;

    void UpdateAI(uint32 /*diff*/) override
    {
        Unit* proprietaire = Proprietaire(me);
        if (!Garder(me, proprietaire))
            return;
        if (!provoque)
        {
            me->CastSpell(me, TOURMENT, true);
            provoque = true;
        }
        if (!UpdateVictim())
        {
            Suivre(proprietaire);
            return;
        }
        suit = false;
        DoMeleeAttackIfReady();
    }
};

// Interrompt la cible du démoniste et la réduit au silence, puis la mord.
struct npc_solazeroth_v3_chasseur : public solazeroth_v3_invocation_ai
{
    explicit npc_solazeroth_v3_chasseur(Creature* creature) : solazeroth_v3_invocation_ai(creature) { }

    ObjectGuid poursuivie;
    bool verrou = false;

    void AttackStart(Unit* /*cible*/) override { }

    void UpdateAI(uint32 diff) override
    {
        Unit* proprietaire = Proprietaire(me);
        if (!Garder(me, proprietaire))
            return;
        Unit* cible = CibleDu(proprietaire);
        if (!cible)
        {
            poursuivie.Clear();
            Suivre(proprietaire);
            return;
        }
        if (cible->GetGUID() != poursuivie)
        {
            poursuivie = cible->GetGUID();
            suit = false;
            me->GetMotionMaster()->MoveChase(cible);
        }
        if (!verrou)
        {
            me->CastSpell(cible, VERROU, true, nullptr, nullptr, proprietaire->GetGUID());
            verrou = true;
        }
        if (attente > diff)
        {
            attente -= diff;
            return;
        }
        attente = 0;
        if (me->IsWithinMeleeRange(cible))
        {
            me->CastSpell(cible, MORSURE, true, nullptr, nullptr, proprietaire->GetGUID());
            attente = CADENCE;
        }
    }
};

void AddSC_solazeroth_v3_demoniste()
{
    new solazeroth_v3_demoniste_unites();
    new solazeroth_v3_demoniste_joueur();
    RegisterSpellScript(spell_solazeroth_v3_invocation);
    RegisterSpellScript(spell_solazeroth_v3_graine);
    RegisterCreatureAI(npc_solazeroth_v3_diablotin);
    RegisterCreatureAI(npc_solazeroth_v3_marcheur);
    RegisterCreatureAI(npc_solazeroth_v3_chasseur);
}
