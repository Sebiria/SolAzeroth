// Mascotte ramasseuse (demande de l'utilisateur, V2) : quand la Bombinette ramasseuse (mascotte Bombinette,
// créature 9656) est sortie, et que le compte a acheté le ramasseur à la
// boutique de marques, tout monstre tué par le joueur est ramassé automatiquement : or et objets dans les sacs.
// Ce qui ne rentre pas (sacs pleins) reste sur le cadavre. Le confort, pas la puissance.

#include "SolAzeroth.h"
#include "Creature.h"
#include "LootMgr.h"
#include "Map.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "WorldSession.h"
#include <unordered_map>
#include <vector>

namespace
{
    uint32 const MASCOTTE_RAMASSEUSE = 9656;
    uint32 const DELAI = 400;   // ms : le temps que le butin du cadavre soit prêt

    struct Cadavre
    {
        ObjectGuid guid;
        uint32 attente;
    };

    std::unordered_map<ObjectGuid::LowType, std::vector<Cadavre>> enAttente;   // par joueur (fil de sa carte)
    std::unordered_map<uint32, bool> comptesAvecRamasseur;                     // cache des achats de compte

    bool RamasseurActif(Player* player)
    {
        ObjectGuid critter = player->GetCritterGUID();
        if (critter.IsEmpty() || critter.GetEntry() != MASCOTTE_RAMASSEUSE)
            return false;
        uint32 compte = player->GetSession()->GetAccountId();
        auto it = comptesAvecRamasseur.find(compte);
        if (it == comptesAvecRamasseur.end())
            it = comptesAvecRamasseur.emplace(compte, SolAzeroth::AchatDeCompte(compte, "ramasseur")).first;
        return it->second;
    }

    void Ramasser(Player* player, Creature* creature)
    {
        if (!creature || creature->IsAlive() || !creature->HasDynamicFlag(UNIT_DYNFLAG_LOOTABLE))
            return;
        if (creature->GetLootRecipient() != player)
            return;
        Loot& loot = creature->loot;
        if (loot.isLooted())
            return;

        if (loot.gold)
        {
            player->ModifyMoney(loot.gold);
            player->UpdateAchievementCriteria(ACHIEVEMENT_CRITERIA_TYPE_LOOT_MONEY, loot.gold);
            loot.gold = 0;
        }
        loot.FillNotNormalLootFor(player);
        uint32 places = loot.GetMaxSlotInLootFor(player);
        for (uint32 i = 0; i < places; ++i)
        {
            InventoryResult resultat;
            player->StoreLootItem(uint8(i), &loot, resultat);
        }
        if (loot.isLooted())
        {
            creature->AllLootRemovedFromCorpse();
            creature->RemoveDynamicFlag(UNIT_DYNFLAG_LOOTABLE);
            loot.clear();
        }
    }
}

void SolAzeroth::OublierCacheRamasseur(unsigned int compte)
{
    comptesAvecRamasseur.erase(compte);
}

class solazeroth_ramasseur : public PlayerScript
{
public:
    solazeroth_ramasseur() : PlayerScript("solazeroth_ramasseur", {
        PLAYERHOOK_ON_CREATURE_KILL, PLAYERHOOK_ON_CREATURE_KILLED_BY_PET, PLAYERHOOK_ON_UPDATE, PLAYERHOOK_ON_LOGOUT }) { }

    void OnPlayerCreatureKill(Player* player, Creature* tue) override { Noter(player, tue); }
    void OnPlayerCreatureKilledByPet(Player* player, Creature* tue) override { Noter(player, tue); }

    void OnPlayerUpdate(Player* player, uint32 temps) override
    {
        auto it = enAttente.find(player->GetGUID().GetCounter());
        if (it == enAttente.end())
            return;
        std::vector<Cadavre>& liste = it->second;
        for (auto c = liste.begin(); c != liste.end();)
        {
            if (c->attente > temps)
            {
                c->attente -= temps;
                ++c;
                continue;
            }
            Ramasser(player, player->GetMap()->GetCreature(c->guid));
            c = liste.erase(c);
        }
        if (liste.empty())
            enAttente.erase(it);
    }

    void OnPlayerLogout(Player* player) override
    {
        enAttente.erase(player->GetGUID().GetCounter());
    }

private:
    static void Noter(Player* player, Creature* tue)
    {
        if (player && tue && RamasseurActif(player))
            enAttente[player->GetGUID().GetCounter()].push_back({ tue->GetGUID(), DELAI });
    }
};

void AddSC_solazeroth_ramasseur()
{
    new solazeroth_ramasseur();
}
