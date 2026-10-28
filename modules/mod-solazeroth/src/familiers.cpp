// Familiers pour toutes les classes (section 3.9, V3b, étape 5).
// - Chasseur : apprivoiser, appeler et ressusciter un familier, et parler au maître des écuries, passent par
//   IsClass(CLASS_HUNTER, CLASS_CONTEXT_PET). Activé pour qui connaît Dressage ou Appel du familier.
// - Démoniste : la permanence des démons et le rappel du dernier démon invoqué passent par
//   IsClass(CLASS_WARLOCK, CLASS_CONTEXT_PET). Activé pour qui connaît une invocation de démon.
// - Type de familier : le serveur le choisit d'après la classe du maître (le démoniste d'abord). Ici, il dépend de la
//   créature : un démon est un démon invoqué, une bête apprivoisable un familier de chasseur. Un personnage qui a les
//   deux reste ainsi cohérent. Les autres familiers (goule, élémentaires) gardent le choix du serveur.
// Le grimoire d'origine a déjà un onglet « Familier » pour toutes les classes dès qu'un familier est présent.

#include "SolAzeroth.h"
#include "CreatureData.h"
#include "Pet.h"
#include "Player.h"
#include "ScriptMgr.h"
#include <algorithm>
#include <array>

namespace
{
    char const* const CLE = "solazeroth_familiers";

    // Dressage, Appel du familier.
    std::array<uint32, 2> const SORTS_CHASSEUR = { 1515, 883 };
    // Invocation d'un diablotin, d'un marcheur du Vide, d'une succube, d'un chasseur corrompu, d'un gangregarde.
    std::array<uint32, 5> const SORTS_DEMONISTE = { 688, 697, 712, 691, 30146 };

    struct Familiers : DataMap::Base
    {
        bool chasseur = false;
        bool demoniste = false;
    };

    void Calculer(Player* player)
    {
        Familiers* f = player->CustomData.GetDefault<Familiers>(CLE);
        f->chasseur = std::any_of(SORTS_CHASSEUR.begin(), SORTS_CHASSEUR.end(), [&](uint32 s) { return player->HasSpell(s); });
        f->demoniste = std::any_of(SORTS_DEMONISTE.begin(), SORTS_DEMONISTE.end(), [&](uint32 s) { return player->HasSpell(s); });
    }
}

class solazeroth_familiers : public PlayerScript
{
public:
    solazeroth_familiers() : PlayerScript("solazeroth_familiers", {
        PLAYERHOOK_ON_LOGIN, PLAYERHOOK_ON_LEARN_SPELL, PLAYERHOOK_ON_PLAYER_IS_CLASS,
        PLAYERHOOK_ON_BEFORE_GUARDIAN_INIT_STATS_FOR_LEVEL }) { }

    void OnPlayerLogin(Player* player) override
    {
        Calculer(player);
    }

    void OnPlayerLearnSpell(Player* player, uint32 /*sort*/) override
    {
        Calculer(player);
    }

    Optional<bool> OnPlayerIsClass(Player const* player, Classes classe, ClassContext contexte) override
    {
        if (contexte != CLASS_CONTEXT_PET || player->getClass() == classe)
            return std::nullopt;
        Familiers const* f = player->CustomData.Get<Familiers>(CLE);
        if (!f)
            return std::nullopt;
        if (classe == CLASS_HUNTER && f->chasseur)
            return true;
        if (classe == CLASS_WARLOCK && f->demoniste)
            return true;
        return std::nullopt;
    }

    void OnPlayerBeforeGuardianInitStatsForLevel(Player* /*player*/, Guardian* gardien, CreatureTemplate const* modele, PetType& type) override
    {
        if (!gardien || !gardien->IsPet() || !modele || type != MAX_PET_TYPE)
            return;
        if (modele->type == CREATURE_TYPE_DEMON)
            type = SUMMON_PET;
        else if (modele->IsTameable(true))
            type = HUNTER_PET;
    }
};

void AddSC_solazeroth_familiers()
{
    new solazeroth_familiers();
}
