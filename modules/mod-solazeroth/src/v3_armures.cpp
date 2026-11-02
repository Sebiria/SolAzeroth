// v3, lot D3 (02/11/2026) : armures par classe et pièces converties (« Démoniste — proposition.md », question 3, b).
// - Règle de l'utilisateur : le guerrier ne porte que de la maille (plus tard, de la plaque à partir de la puissance
//   40), le démoniste que du tissu. Les capes, en tissu, vont à tous ; boucliers, orbes, bijoux et armes ne sont pas
//   concernés (les compétences d'armes et de bouclier de la classe s'appliquent, v3_kit.cpp).
// - Une pièce du monde faite pour une autre classe devient sa version de même puissance et de même rang (table
//   solazeroth_v3_versions, une ligne par pièce et par classe, outils\tissu_v3.py, migration 130) : pour le démoniste
//   la maille en tissu, le bouclier en orbe, l'arme en dague ; pour le voleur la maille en cuir, le bouclier et l'arme
//   en dague. Récompense de quête : échangée dès qu'elle est donnée (le moteur ne sert plus de la pièce ensuite) ;
//   annexes : la version est donnée directement (SolAzeroth::VersionDe, v3_annexes.cpp).
// - Lot V3 (02/11/2026) : remplace la table solazeroth_v3_conversions (une seule version par pièce, échange à la mise à
//   jour suivante du joueur).

#include "SolAzeroth.h"
#include "DatabaseEnv.h"
#include "Item.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "ScriptMgr.h"
#include <map>

namespace
{
    std::map<std::pair<uint32, uint8>, uint32> versions;   // (pièce, classe) -> sa version pour la classe

    // Seul type d'armure que porte la classe (0 : aucune règle pour l'instant).
    uint32 TypeDe(Player const* player)
    {
        switch (player->getClass())
        {
            case CLASS_WARRIOR: return ITEM_SUBCLASS_ARMOR_MAIL;
            case CLASS_WARLOCK: return ITEM_SUBCLASS_ARMOR_CLOTH;
            case CLASS_ROGUE: return ITEM_SUBCLASS_ARMOR_LEATHER;
            default: return 0;
        }
    }

    bool Portable(Player const* player, ItemTemplate const* modele)
    {
        // Armes par spécialisation (02/11/2026) : tank sans arme à deux mains, démoniste en dague ou bâton, voleur en
        // dagues.
        if (!SolAzeroth::ArmePermise(const_cast<Player*>(player), modele))
            return false;
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

    // La version de la pièce pour sa classe, si la pièce ne lui va pas et que la version, elle, lui va ; sinon 0.
    uint32 VersionPour(Player* player, uint32 entree)
    {
        auto it = versions.find({ entree, player->getClass() });
        if (it == versions.end())
            return 0;
        ItemTemplate const* avant = sObjectMgr->GetItemTemplate(entree);
        ItemTemplate const* apres = sObjectMgr->GetItemTemplate(it->second);
        return avant && apres && !Va(player, avant) && Va(player, apres) ? it->second : 0;
    }
}

class solazeroth_v3_armures_monde : public WorldScript
{
public:
    solazeroth_v3_armures_monde() : WorldScript("solazeroth_v3_armures_monde", { WORLDHOOK_ON_STARTUP }) { }

    void OnStartup() override
    {
        versions.clear();
        if (QueryResult r = WorldDatabase.Query("SELECT origine, classe, version FROM solazeroth_v3_versions"))
            do
                versions[{ (*r)[0].Get<uint32>(), (*r)[1].Get<uint8>() }] = (*r)[2].Get<uint32>();
            while (r->NextRow());
        LOG_INFO("module", "Sol'Azeroth v3 : {} versions de pièces selon la classe", versions.size());
    }
};

class solazeroth_v3_armures_joueur : public PlayerScript
{
public:
    solazeroth_v3_armures_joueur() : PlayerScript("solazeroth_v3_armures_joueur", {
        PLAYERHOOK_CAN_USE_ITEM, PLAYERHOOK_ON_QUEST_REWARD_ITEM }) { }

    bool OnPlayerCanUseItem(Player* player, ItemTemplate const* modele, InventoryResult& resultat) override
    {
        if (Portable(player, modele))
            return true;
        resultat = EQUIP_ERR_NO_REQUIRED_PROFICIENCY;
        return false;
    }

    // Le moteur a rangé la récompense et l'a annoncée ; il ne s'en sert plus ensuite. Retirée d'abord : sa place dans
    // les sacs accueille la version. La fenêtre de quête montrait déjà la version (SolUI_Versions.lua).
    void OnPlayerQuestRewardItem(Player* player, Item* piece, uint32 nombre) override
    {
        uint32 version = piece ? VersionPour(player, piece->GetEntry()) : 0;
        if (!version)
            return;
        player->DestroyItem(piece->GetBagSlot(), piece->GetSlot(), true);
        player->AddItem(version, nombre);
    }
};

uint32 SolAzeroth::VersionDe(Player* player, uint32 entree)
{
    uint32 version = VersionPour(player, entree);
    return version ? version : entree;
}

void AddSC_solazeroth_v3_armures()
{
    new solazeroth_v3_armures_monde();
    new solazeroth_v3_armures_joueur();
}
