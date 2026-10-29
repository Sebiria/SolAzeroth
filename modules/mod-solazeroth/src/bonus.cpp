// Enchantement de bonus (section 4.5), prototype : un objet de boss obtenu au rang de menace R reçoit des
// caractéristiques en plus, pour approcher un objet de niveau « niveau d'origine + R ».
// - Moyen : un suffixe aléatoire existant du jeu (ItemRandomProperties.dbc), « d'Endurance », « de Force »,
//   « d'Agilité », « d'Intelligence » ou « d'Esprit », de +1 à +46. Le client n'affiche les caractéristiques de
//   l'emplacement des suffixes que si l'objet porte un vrai suffixe : un enchantement posé seul y restait invisible
//   (premier essai). L'objet prend donc le nom du suffixe, ex. « Gangrelame maudite d'Endurance ».
//   L'enchantement normal (emplacement permanent) reste libre. Un objet qui a déjà un suffixe aléatoire n'a pas de bonus.
// - Valeur : la somme des caractéristiques de l'objet × R × SolAzeroth.Bonus.PourcentParRang (au moins R), sur sa
//   caractéristique principale (Endurance si l'objet n'en a pas). Proportionnelle, comme la difficulté des rangs :
//   un rang pèse autant au niveau 13 qu'au niveau 80 (décision de l'utilisateur, remplace « + R niveaux d'objet »).
// - Le rang est mémorisé avec l'objet (solazeroth_objets_rang) pour l'écart d'équipement de V5.

#include "SolAzeroth.h"
#include "Config.h"
#include "DatabaseEnv.h"
#include "DBCStores.h"
#include "Creature.h"
#include "Item.h"
#include "Map.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "ScriptMgr.h"
#include <algorithm>
#include <cmath>
#include <map>
#include <unordered_map>

namespace
{
    // caractéristique -> (valeur -> suffixe aléatoire « +valeur caractéristique »)
    std::unordered_map<uint32, std::map<uint32, uint32>> suffixes;
    float pourcentParRang = 0.03f;

    bool EstPrincipale(uint32 stat)
    {
        return stat == ITEM_MOD_AGILITY || stat == ITEM_MOD_STRENGTH || stat == ITEM_MOD_INTELLECT
            || stat == ITEM_MOD_SPIRIT || stat == ITEM_MOD_STAMINA;
    }

    uint32 ChoisirSuffixe(ItemTemplate const* modele, uint8 rang, uint32& valeur)
    {
        uint32 somme = 0, principale = ITEM_MOD_STAMINA, meilleure = 0;
        for (uint32 i = 0; i < modele->StatsCount && i < MAX_ITEM_PROTO_STATS; ++i)
        {
            int32 v = modele->ItemStat[i].ItemStatValue;
            if (v <= 0)
                continue;
            somme += uint32(v);
            if (EstPrincipale(modele->ItemStat[i].ItemStatType) && uint32(v) > meilleure)
            {
                meilleure = uint32(v);
                principale = modele->ItemStat[i].ItemStatType;
            }
        }
        valeur = std::max<uint32>(rang, uint32(std::lround(double(somme) * rang * pourcentParRang)));

        auto liste = suffixes.find(principale);
        if (liste == suffixes.end() || liste->second.empty())
            return 0;
        auto it = liste->second.upper_bound(valeur);   // la plus grande valeur disponible <= valeur voulue
        if (it == liste->second.begin())
            return 0;
        --it;
        valeur = it->first;
        return it->second;
    }
}

Item* SolAzeroth::DonnerObjetDeRang(Player* player, unsigned int objet, unsigned char rang)
{
    ItemTemplate const* modele = sObjectMgr->GetItemTemplate(objet);
    if (!modele)
        return nullptr;
    ItemPosCountVec destination;
    if (player->CanStoreNewItem(NULL_BAG, NULL_SLOT, destination, objet, 1) != EQUIP_ERR_OK)
        return nullptr;

    int32 suffixe = Item::GenerateItemRandomPropertyId(objet);
    uint32 bonus = 0;
    if (rang > 0 && !suffixe && !modele->RandomSuffix)
    {
        uint32 valeur = 0;
        bonus = ChoisirSuffixe(modele, rang, valeur);
        suffixe = int32(bonus);
    }

    Item* item = player->StoreNewItem(destination, objet, true, suffixe);
    if (!item)
        return nullptr;
    if (bonus)
    {
        CharacterDatabase.Execute("REPLACE INTO solazeroth_objets_rang (item_guid, rang, enchantement) VALUES ({}, {}, {})",
            item->GetGUID().GetCounter(), rang, bonus);
        SolAzeroth::NoterRangObjet(item->GetGUID().GetCounter(), rang);
    }
    player->SendNewItem(item, 1, true, false);
    return item;
}

void SolAzeroth::AppliquerRangObjet(Player* player, Item* item, unsigned char rang)
{
    ItemTemplate const* modele = item ? item->GetTemplate() : nullptr;
    if (!modele || !rang || item->GetItemRandomPropertyId() || modele->RandomProperty || modele->RandomSuffix)
        return;
    uint32 valeur = 0;
    uint32 bonus = ChoisirSuffixe(modele, rang, valeur);
    if (!bonus)
        return;
    item->SetItemRandomProperties(int32(bonus));
    item->SetState(ITEM_CHANGED, player);
    CharacterDatabase.Execute("REPLACE INTO solazeroth_objets_rang (item_guid, rang, enchantement) VALUES ({}, {}, {})",
        item->GetGUID().GetCounter(), rang, bonus);
    SolAzeroth::NoterRangObjet(item->GetGUID().GetCounter(), rang);
}

// Butin d'un boss de raid ramassé : l'équipement prend l'enchantement de bonus du rang de menace de l'instance
// (calibrage final, 29/10/2026). Les donjons à 5 passent par le butin choisi (butin.cpp).
class solazeroth_bonus_raid : public PlayerScript
{
public:
    solazeroth_bonus_raid() : PlayerScript("solazeroth_bonus_raid", { PLAYERHOOK_ON_LOOT_ITEM }) { }

    void OnPlayerLootItem(Player* player, Item* item, uint32 /*nombre*/, ObjectGuid source) override
    {
        Map* map = player->GetMap();
        if (!item || !map || !map->IsRaid() || !source.IsCreature())
            return;
        ItemTemplate const* modele = item->GetTemplate();
        if (!modele || (modele->Class != ITEM_CLASS_WEAPON && modele->Class != ITEM_CLASS_ARMOR) || modele->Quality < ITEM_QUALITY_UNCOMMON)
            return;
        Creature* boss = map->GetCreature(source);
        if (!boss || !boss->IsDungeonBoss())
            return;
        SolAzeroth::AppliquerRangObjet(player, item, SolAzeroth::PalierButin(map));
    }
};

class solazeroth_bonus_monde : public WorldScript
{
public:
    solazeroth_bonus_monde() : WorldScript("solazeroth_bonus_monde", { WORLDHOOK_ON_AFTER_CONFIG_LOAD, WORLDHOOK_ON_STARTUP }) { }

    void OnAfterConfigLoad(bool /*rechargement*/) override
    {
        pourcentParRang = sConfigMgr->GetOption<float>("SolAzeroth.Bonus.PourcentParRang", 0.03f);
    }

    // Suffixes aléatoires à un seul enchantement « +N caractéristique » simple (sans condition, gemme ni niveau requis).
    void OnStartup() override
    {
        for (uint32 i = 0; i < sItemRandomPropertiesStore.GetNumRows(); ++i)
        {
            ItemRandomPropertiesEntry const* p = sItemRandomPropertiesStore.LookupEntry(i);
            if (!p || !p->Enchantment[0] || p->Enchantment[1] || p->Enchantment[2] || p->Enchantment[3] || p->Enchantment[4])
                continue;
            SpellItemEnchantmentEntry const* e = sSpellItemEnchantmentStore.LookupEntry(p->Enchantment[0]);
            if (!e || e->type[0] != ITEM_ENCHANTMENT_TYPE_STAT || e->type[1] || e->type[2] || !e->amount[0]
                || e->GemID || e->EnchantmentCondition || e->requiredLevel || e->requiredSkill || !EstPrincipale(e->spellid[0]))
                continue;
            suffixes[e->spellid[0]].emplace(e->amount[0], p->ID);   // garde le premier trouvé pour chaque valeur
        }
        size_t total = 0;
        for (auto const& [stat, liste] : suffixes)
            total += liste.size();
        LOG_INFO("module", "Sol'Azeroth enchantement de bonus : {} suffixes de caractéristique chargés", total);
    }
};

void AddSC_solazeroth_bonus()
{
    new solazeroth_bonus_monde();
    new solazeroth_bonus_raid();
}
