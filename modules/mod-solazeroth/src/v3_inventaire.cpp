// v3 (01/11/2026, demande de l'utilisateur) : un inventaire de 50 places, montré dans Collection › Inventaire
// (Interface\FrameXML\SolUI_Inventaire.lua).
// - Le sac à dos (16 places) et la Besace d'aventurier (910235, 34 places, migration 095), posée d'office à la connexion
//   dans le premier emplacement de sac. Elle ne s'enlève pas.
// - Aucun autre sac, carquois ou giberne ne s'équipe : l'inventaire reste à 50 places. Les objets déjà équipés au
//   chargement du personnage ne sont pas touchés.

#include "SolAzeroth.h"
#include "Item.h"
#include "Player.h"
#include "ScriptMgr.h"

namespace
{
    constexpr uint32 BESACE = 910235;

    bool EstSac(ItemTemplate const* proto)
    {
        return proto->Class == ITEM_CLASS_CONTAINER || proto->Class == ITEM_CLASS_QUIVER;
    }
}

class solazeroth_v3_inventaire : public PlayerScript
{
public:
    solazeroth_v3_inventaire() : PlayerScript("solazeroth_v3_inventaire",
        { PLAYERHOOK_ON_LOGIN, PLAYERHOOK_CAN_EQUIP_ITEM, PLAYERHOOK_CAN_UNEQUIP_ITEM }) { }

    void OnPlayerLogin(Player* player) override
    {
        if (player->GetItemByPos(INVENTORY_SLOT_BAG_0, INVENTORY_SLOT_BAG_START))
            return;
        uint16 dest;
        if (player->CanEquipNewItem(INVENTORY_SLOT_BAG_START, dest, BESACE, false) == EQUIP_ERR_OK)
            player->EquipNewItem(dest, BESACE, true);
    }

    bool OnPlayerCanEquipItem(Player* /*player*/, uint8 /*slot*/, uint16& /*dest*/, Item* item, bool /*swap*/,
        bool notLoading) override
    {
        return !notLoading || item->GetEntry() == BESACE || !EstSac(item->GetTemplate());
    }

    bool OnPlayerCanUnequipItem(Player* player, uint16 pos, bool /*swap*/) override
    {
        Item* item = player->GetItemByPos(pos);
        return !item || item->GetEntry() != BESACE || !player->IsBagPos(pos);
    }
};

void AddSC_solazeroth_v3_inventaire()
{
    new solazeroth_v3_inventaire();
}
