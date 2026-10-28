// Pistage de toutes les ressources de récolte en même temps (demande de l'utilisateur, V2)
// Le jeu n'autorise qu'un pistage actif. Ici, chaque pistage de ressource que le personnage connaît
// (minerais, herbes, trésors) reste allumé en permanence dans le champ PLAYER_TRACK_RESOURCES.

#include "SolAzeroth.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "SpellInfo.h"
#include "SpellMgr.h"
#include <array>

namespace
{
    // Découverte de minerais, Découverte d'herbes, Découverte de trésors (nains).
    std::array<uint32, 3> const PISTAGES = { 2580, 2383, 2481 };

    uint32 Masque(Player const* player)
    {
        uint32 masque = 0;
        for (uint32 sort : PISTAGES)
        {
            if (!player->HasSpell(sort))
                continue;
            if (SpellInfo const* info = sSpellMgr->GetSpellInfo(sort))
                for (SpellEffectInfo const& effet : info->GetEffects())
                    if (effet.ApplyAuraName == SPELL_AURA_TRACK_RESOURCES && effet.MiscValue > 0)
                        masque |= uint32(1) << (effet.MiscValue - 1);
        }
        return masque;
    }
}

class solazeroth_pistage : public PlayerScript
{
public:
    solazeroth_pistage() : PlayerScript("solazeroth_pistage", { PLAYERHOOK_ON_UPDATE }) { }

    // Remet les pistages connus s'ils ont été éteints (changement de pistage, mort, reconnexion).
    void OnPlayerUpdate(Player* player, uint32 /*temps*/) override
    {
        uint32 masque = Masque(player);
        if (masque && (player->GetUInt32Value(PLAYER_TRACK_RESOURCES) & masque) != masque)
            player->SetFlag(PLAYER_TRACK_RESOURCES, masque);
    }
};

void AddSC_solazeroth_pistage()
{
    new solazeroth_pistage();
}
