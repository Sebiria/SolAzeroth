// v3, lot D3 (02/11/2026) : armures par classe et pièces converties (« Démoniste — proposition.md », question 3, b).
// - Règle de l'utilisateur : le guerrier ne porte que de la maille (plus tard, de la plaque à partir de la puissance
//   40), le démoniste que du tissu. Les capes, en tissu, vont à tous ; boucliers, orbes, bijoux et armes ne sont pas
//   concernés (les compétences d'armes et de bouclier de la classe s'appliquent, v3_kit.cpp).
// - Une pièce du monde reçue dans le mauvais type (récompense de quête ou d'annexe, butin) devient sa version de même
//   puissance et de même rang (table solazeroth_v3_conversions, outils\tissu_v3.py, migration 124) : la maille en
//   tissu, le bouclier en orbe, et l'inverse. L'échange attend la mise à jour suivante du joueur, car celui qui range
//   la pièce s'en sert encore juste après.

#include "SolAzeroth.h"
#include "DatabaseEnv.h"
#include "Item.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "ScriptMgr.h"
#include <unordered_map>
#include <vector>

namespace
{
    std::unordered_map<uint32, uint32> conversions;   // pièce -> sa version dans l'autre type

    struct AConvertir : public DataMap::Base
    {
        std::vector<ObjectGuid> pieces;
    };

    // Seul type d'armure que porte la classe (0 : aucune règle pour l'instant).
    uint32 TypeDe(Player const* player)
    {
        switch (player->getClass())
        {
            case CLASS_WARRIOR: return ITEM_SUBCLASS_ARMOR_MAIL;
            case CLASS_WARLOCK: return ITEM_SUBCLASS_ARMOR_CLOTH;
            default: return 0;
        }
    }

    bool Portable(Player const* player, ItemTemplate const* modele)
    {
        if (!modele || modele->Class != ITEM_CLASS_ARMOR || modele->InventoryType == INVTYPE_CLOAK)
            return true;
        switch (modele->SubClass)
        {
            case ITEM_SUBCLASS_ARMOR_CLOTH: case ITEM_SUBCLASS_ARMOR_LEATHER: case ITEM_SUBCLASS_ARMOR_MAIL:
            case ITEM_SUBCLASS_ARMOR_PLATE:
                break;
            default:
                return true;
        }
        uint32 type = TypeDe(player);
        return !type || modele->SubClass == type;
    }

    // Portable, et la compétence voulue (bouclier) : CanUseItem sur le seul modèle ne la vérifie pas.
    bool Va(Player const* player, ItemTemplate const* modele)
    {
        return Portable(player, modele) && player->CanUseItem(modele) == EQUIP_ERR_OK
            && (!modele->GetSkill() || player->GetSkillValue(modele->GetSkill()));
    }

    // Une pièce qu'il ne peut pas porter, et dont la version, elle, lui va (maille et tissu ; bouclier et orbe).
    uint32 VersionPour(Player const* player, Item const* piece)
    {
        auto it = conversions.find(piece->GetEntry());
        if (it == conversions.end())
            return 0;
        ItemTemplate const* avant = piece->GetTemplate();
        ItemTemplate const* apres = sObjectMgr->GetItemTemplate(it->second);
        if (!apres)
            return 0;
        return !Va(player, avant) && Va(player, apres) ? it->second : 0;
    }
}

class solazeroth_v3_armures_monde : public WorldScript
{
public:
    solazeroth_v3_armures_monde() : WorldScript("solazeroth_v3_armures_monde", { WORLDHOOK_ON_STARTUP }) { }

    void OnStartup() override
    {
        conversions.clear();
        if (QueryResult r = WorldDatabase.Query("SELECT origine, version FROM solazeroth_v3_conversions"))
            do
                conversions[(*r)[0].Get<uint32>()] = (*r)[1].Get<uint32>();
            while (r->NextRow());
        LOG_INFO("module", "Sol'Azeroth v3 : {} pièces converties selon la classe", conversions.size());
    }
};

class solazeroth_v3_armures_joueur : public PlayerScript
{
public:
    solazeroth_v3_armures_joueur() : PlayerScript("solazeroth_v3_armures_joueur", {
        PLAYERHOOK_CAN_USE_ITEM, PLAYERHOOK_ON_STORE_NEW_ITEM, PLAYERHOOK_ON_UPDATE }) { }

    bool OnPlayerCanUseItem(Player* player, ItemTemplate const* modele, InventoryResult& resultat) override
    {
        if (Portable(player, modele))
            return true;
        resultat = EQUIP_ERR_NO_REQUIRED_PROFICIENCY;
        return false;
    }

    void OnPlayerStoreNewItem(Player* player, Item* piece, uint32 /*nombre*/) override
    {
        if (piece && VersionPour(player, piece))
            player->CustomData.GetDefault<AConvertir>("solazeroth_v3_conversions")->pieces.push_back(piece->GetGUID());
    }

    void OnPlayerUpdate(Player* player, uint32 /*diff*/) override
    {
        AConvertir* a = player->CustomData.Get<AConvertir>("solazeroth_v3_conversions");
        if (!a || a->pieces.empty())
            return;
        std::vector<ObjectGuid> pieces;
        pieces.swap(a->pieces);
        for (ObjectGuid guid : pieces)
        {
            Item* piece = player->GetItemByGuid(guid);
            uint32 version = piece ? VersionPour(player, piece) : 0;
            if (!version)
                continue;
            uint32 nombre = piece->GetCount();
            // Retirée d'abord : sa place dans les sacs accueille la version. Sans message : la fenêtre de quête montrait
            // déjà la version (SolUI_Versions.lua).
            player->DestroyItem(piece->GetBagSlot(), piece->GetSlot(), true);
            player->AddItem(version, nombre);
        }
    }
};

void AddSC_solazeroth_v3_armures()
{
    new solazeroth_v3_armures_monde();
    new solazeroth_v3_armures_joueur();
}
