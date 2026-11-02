// v3, lot V2 (02/11/2026) : ce que Spell.dbc ne sait pas écrire dans le kit du voleur Assassinat (sorts :
// outils\voleur_v3.py, migration 129 ; spécialisation et ordre de déblocage : v3_kit.cpp).
// - Toxines (passif) et Ouverture posent leurs sorts par le moteur (déclenchement écrit dans Spell.dbc).
// - Envenimer : il faut au moins un cumul de Poison mortel sur la cible ; ses dégâts sont multipliés par le nombre de
//   cumuls, qu'il consomme.
// - Camouflage : quand il se brise (coup donné ou reçu), l'Ouverture fait du coup suivant un Garrot. Rien si le joueur
//   l'annule lui-même.
// - Lot V7 (02/11/2026, idée de l'utilisateur) : l'Éventail de couteaux lancé en Camouflage devient Assommer, sur la
//   cible du joueur. Un seul bouton : le serveur choisit, car le jeu interdit de changer le sort d'un bouton en combat.
//   Assommer a sa propre recharge ; l'Éventail, refusé sans message, ne prend pas la sienne. Assommer exige une cible
//   hors combat ; tout dégât la libère (Spell.dbc).

#include "SolAzeroth.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "SpellAuraEffects.h"
#include "SpellScript.h"
#include "SpellScriptLoader.h"

namespace
{
    uint32 const POISON = 100301, CAMOUFLAGE = 100308, OUVERTURE = 100310, ASSOMMER = 100322;
}

class spell_solazeroth_v3_envenimer : public SpellScript
{
    PrepareSpellScript(spell_solazeroth_v3_envenimer);

    SpellCastResult Verifier()
    {
        Unit* cible = GetExplTargetUnit();
        if (!cible || !cible->HasAura(POISON, GetCaster()->GetGUID()))
            return SPELL_FAILED_TARGET_AURASTATE;
        return SPELL_CAST_OK;
    }

    void Frapper()
    {
        Unit* cible = GetHitUnit();
        Aura* poison = cible ? cible->GetAura(POISON, GetCaster()->GetGUID()) : nullptr;
        if (!poison)
        {
            SetHitDamage(0);
            return;
        }
        SetHitDamage(GetHitDamage() * poison->GetStackAmount());
        poison->Remove();
    }

    void Register() override
    {
        OnCheckCast += SpellCheckCastFn(spell_solazeroth_v3_envenimer::Verifier);
        OnHit += SpellHitFn(spell_solazeroth_v3_envenimer::Frapper);
    }
};

class spell_solazeroth_v3_camouflage : public AuraScript
{
    PrepareAuraScript(spell_solazeroth_v3_camouflage);

    void Briser(AuraEffect const* /*effet*/, AuraEffectHandleModes /*mode*/)
    {
        switch (GetTargetApplication()->GetRemoveMode())
        {
            case AURA_REMOVE_BY_CANCEL: case AURA_REMOVE_BY_EXPIRE: case AURA_REMOVE_BY_DEATH:
                return;
            default:
                break;
        }
        Unit* voleur = GetTarget();
        if (voleur->IsAlive() && voleur->IsInWorld())
            voleur->CastSpell(voleur, OUVERTURE, true);
    }

    void Register() override
    {
        AfterEffectRemove += AuraEffectRemoveFn(spell_solazeroth_v3_camouflage::Briser, EFFECT_1, SPELL_AURA_MOD_STEALTH,
            AURA_EFFECT_HANDLE_REAL);
    }
};

class spell_solazeroth_v3_eventail : public SpellScript
{
    PrepareSpellScript(spell_solazeroth_v3_eventail);

    SpellCastResult Verifier()
    {
        Player* voleur = GetCaster()->ToPlayer();
        if (!voleur || !voleur->HasAura(CAMOUFLAGE))
            return SPELL_CAST_OK;
        Unit* cible = voleur->GetSelectedUnit();
        if (!cible || cible == voleur)
            return SPELL_FAILED_BAD_TARGETS;
        // Assommer fait ses propres vérifications (portée, recharge, cible hors combat) et dit ses propres erreurs.
        voleur->CastSpell(cible, ASSOMMER, false);
        return SPELL_FAILED_DONT_REPORT;
    }

    void Register() override
    {
        OnCheckCast += SpellCheckCastFn(spell_solazeroth_v3_eventail::Verifier);
    }
};

class spell_solazeroth_v3_assommer : public SpellScript
{
    PrepareSpellScript(spell_solazeroth_v3_assommer);

    SpellCastResult Verifier()
    {
        Unit* cible = GetExplTargetUnit();
        if (cible && cible->IsInCombat())
            return SPELL_FAILED_TARGET_AFFECTING_COMBAT;
        return SPELL_CAST_OK;
    }

    void Register() override
    {
        OnCheckCast += SpellCheckCastFn(spell_solazeroth_v3_assommer::Verifier);
    }
};

void AddSC_solazeroth_v3_voleur()
{
    RegisterSpellScript(spell_solazeroth_v3_envenimer);
    RegisterSpellScript(spell_solazeroth_v3_camouflage);
    RegisterSpellScript(spell_solazeroth_v3_eventail);
    RegisterSpellScript(spell_solazeroth_v3_assommer);
}
