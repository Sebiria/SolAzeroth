// v3, F5a (31/10/2026) : la mort (document v3, §2.6) : retour à la pierre de foyer, sans aucune perte.
// Quand le joueur libère son esprit, il n'erre pas en fantôme jusqu'à un cimetière : il est ranimé aussitôt à sa pierre
// de foyer, vie pleine, sans mal de résurrection ni course au cadavre. L'usure à la mort est coupée à part
// (DurabilityLoss.OnDeath = 0, scripts\configurer.ps1).
// Les champs de bataille gardent leur règle (cimetières du champ de bataille).

#include "SolAzeroth.h"
#include "Player.h"
#include "ScriptMgr.h"

class solazeroth_v3_mort : public PlayerScript
{
public:
    solazeroth_v3_mort() : PlayerScript("solazeroth_v3_mort", { PLAYERHOOK_CAN_REPOP_AT_GRAVEYARD }) { }

    // Appelé juste après la libération de l'esprit (et parfois pour un joueur vivant tombé sous la carte : on laisse
    // alors faire le jeu).
    bool OnPlayerCanRepopAtGraveyard(Player* player) override
    {
        if (player->IsAlive() || player->GetBattleground())
            return true;

        player->ResurrectPlayer(1.0f, false);
        if (!player->IsAlive())
            return true;   // résurrection refusée par un autre module (mort Hardcore) : règle du jeu
        player->SpawnCorpseBones();
        player->TeleportTo(player->m_homebindMapId, player->m_homebindX, player->m_homebindY, player->m_homebindZ,
            player->GetOrientation());
        return false;
    }
};

void AddSC_solazeroth_v3_mort()
{
    new solazeroth_v3_mort();
}
