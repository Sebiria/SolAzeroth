// Mort Hardcore sauvegardée tout de suite (section 3.3, demande de l'utilisateur du 30/10/2026).
// mod-challenge-modes ne note la mort qu'en mémoire : elle n'atteint la base qu'à la prochaine sauvegarde du personnage.
// Un serveur arrêté ou planté juste après la mort rendait donc un personnage vivant à la reconnexion.
// Ici, toute mort d'un personnage Hardcore (monstre, chute, noyade, lave…) est marquée et le personnage sauvegardé
// aussitôt, sans attendre la file de la base.
// Il gère aussi la connexion d'un personnage Hardcore mort : celle de mod-challenge-modes ne marche pas, car son
// challengeEnabledForPlayer(HARDCORE_DEAD) répond toujours non (HARDCORE_DEAD n'est pas un défi activable).

#include "SolAzeroth.h"
#include "ChallengeModes.h"
#include "DatabaseEnv.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "WorldSession.h"

class solazeroth_hardcore : public PlayerScript
{
public:
    solazeroth_hardcore() : PlayerScript("solazeroth_hardcore", { PLAYERHOOK_ON_LOGIN, PLAYERHOOK_ON_PLAYER_JUST_DIED }) { }

    static bool Mort(Player* player)
    {
        return player->GetPlayerSetting("mod-challenge-modes", HARDCORE_DEAD).value;
    }

    void OnPlayerLogin(Player* player) override
    {
        if (!sChallengeModes->challengeEnabledForPlayer(SETTING_HARDCORE, player) || !Mort(player))
            return;
        player->KillPlayer();
        player->GetSession()->KickPlayer(std::string("Personnage Hardcore mort : il ne peut plus jouer."));
    }

    void OnPlayerJustDied(Player* player) override
    {
        // Déjà marqué mort (tué à nouveau à la connexion) : rien à sauver.
        if (!sChallengeModes->challengeEnabledForPlayer(SETTING_HARDCORE, player) || Mort(player))
            return;
        player->UpdatePlayerSetting("mod-challenge-modes", HARDCORE_DEAD, 1);
        CharacterDatabaseTransaction trans = CharacterDatabase.BeginTransaction();
        player->SaveToDB(trans, false, false);
        CharacterDatabase.DirectCommitTransaction(trans);
    }
};

void AddSC_solazeroth_hardcore()
{
    new solazeroth_hardcore();
}
