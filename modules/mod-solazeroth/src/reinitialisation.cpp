// Réinitialisation libre des donjons (normaux et héroïques) et des raids, sans attente
// (sections 4.2 et 4.7 : pas de verrou de raid ni de donjon héroïque).
// .reinitialiser : délie le personnage de toutes ses instances ; la prochaine entrée crée une instance neuve.
// La limite de 5 instances par heure est levée dans worldserver.conf (AccountInstancesPerHour).

#include "SolAzeroth.h"
#include "Chat.h"
#include "InstanceSaveMgr.h"
#include "Map.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "StringFormat.h"
#include <vector>

using namespace Acore::ChatCommands;

class solazeroth_reinitialisation_commandes : public CommandScript
{
public:
    solazeroth_reinitialisation_commandes() : CommandScript("solazeroth_reinitialisation_commandes") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable commandes =
        {
            { "reinitialiser", HandleReinitialiser, SEC_PLAYER, Console::No },
        };
        return commandes;
    }

    static bool HandleReinitialiser(ChatHandler* handler)
    {
        Player* player = handler->GetSession()->GetPlayer();
        if (player->GetMap()->Instanceable())
        {
            handler->SendSysMessage("Sors de l'instance avant de réinitialiser.");
            return true;
        }

        uint32 nombre = 0;
        for (uint8 difficulte = 0; difficulte < MAX_DIFFICULTY; ++difficulte)
        {
            std::vector<uint32> cartes;
            for (auto const& [carte, lien] : sInstanceSaveMgr->PlayerGetBoundInstances(player->GetGUID(), Difficulty(difficulte)))
                cartes.push_back(carte);
            for (uint32 carte : cartes)
            {
                sInstanceSaveMgr->PlayerUnbindInstance(player->GetGUID(), carte, Difficulty(difficulte), true, player);
                ++nombre;
            }
        }
        handler->SendSysMessage(nombre ? Acore::StringFormat("{} instance(s) réinitialisée(s).", nombre)
                                       : std::string("Aucune instance à réinitialiser."));
        return true;
    }
};

void AddSC_solazeroth_reinitialisation()
{
    new solazeroth_reinitialisation_commandes();
}
