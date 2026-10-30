// v3, F1 (31/10/2026) : niveau caché et fixe (document v3, section 2).
// - Les joueurs commencent et restent au niveau 80, sans talents (configurer.ps1) ; leurs statistiques de base au
//   niveau 80 sont celles du niveau 1 (migration 060) : le niveau ne donne plus de force, l'équipement si.
// - Les créatures gardent la vie, les dégâts et l'armure de leur niveau d'origine, qui devient leur « puissance »,
//   puis passent au niveau 80 : à niveau égal, plus de bonus ni de malus de toucher, de critique ou d'esquive.
// - La puissance d'attaque des joueurs ne compte plus le niveau (formule du niveau 1).

#include "SolAzeroth.h"
#include "Creature.h"
#include "Player.h"
#include "ScriptMgr.h"

namespace
{
    uint8 const NIVEAU_FIXE = 80;

    struct Puissance : DataMap::Base
    {
        uint8 valeur = 0;
    };
}

unsigned char SolAzeroth::PuissanceCreature(Creature const* creature)
{
    Puissance const* p = creature ? const_cast<Creature*>(creature)->CustomData.Get<Puissance>("solazeroth_puissance") : nullptr;
    return p ? p->valeur : (creature ? creature->GetLevel() : 0);
}

class solazeroth_v3_niveau_creatures : public AllCreatureScript
{
public:
    solazeroth_v3_niveau_creatures() : AllCreatureScript("solazeroth_v3_niveau_creatures") { }

    // Appelé à la fin de Creature::SelectLevel, statistiques déjà calculées au niveau d'origine.
    void OnCreatureSelectLevel(CreatureTemplate const* /*cinfo*/, Creature* creature) override
    {
        if (creature->IsPet() || creature->HasUnitTypeMask(UNIT_MASK_MINION))
            return;
        uint8 origine = creature->GetLevel();
        creature->CustomData.GetDefault<Puissance>("solazeroth_puissance")->valeur = origine;
        if (origine < NIVEAU_FIXE)
            creature->SetLevel(NIVEAU_FIXE);
    }
};

class solazeroth_v3_niveau_joueur : public PlayerScript
{
public:
    solazeroth_v3_niveau_joueur() : PlayerScript("solazeroth_v3_niveau_joueur", { PLAYERHOOK_ON_BEFORE_UPDATE_ATTACK_POWER_AND_DAMAGE }) { }

    void OnPlayerBeforeUpdateAttackPowerAndDamage(Player* /*player*/, float& level, float& /*val2*/, bool /*ranged*/) override
    {
        level = 1.0f;
    }
};

void AddSC_solazeroth_v3_niveau()
{
    new solazeroth_v3_niveau_creatures();
    new solazeroth_v3_niveau_joueur();
}
