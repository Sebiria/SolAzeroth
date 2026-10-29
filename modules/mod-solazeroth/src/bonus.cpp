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
// - Amélioration (calibrage final G6, 29/10/2026) : des Marques montent le rang d'un objet de 1, jusqu'au rang 5
//   (SolAzeroth.Amelioration.Prix par rang, SolAzeroth.Amelioration.RangMax). Arme ou armure verte ou mieux, hors
//   héritage, sans suffixe aléatoire du jeu ; un objet sans rang part du rang 0. Débouché des Marques au niveau 80.
//   Commandes de l'addon SolAzerothAmelioration : « .solameliorer liste » et « .solameliorer monter <sac> <case> »
//   (sac -1 : équipement porté, case 1 à 19 ; sac 0 à 4 : sacs du jeu, case à partir de 1).

#include "SolAzeroth.h"
#include "Bag.h"
#include "Chat.h"
#include "Config.h"
#include "DatabaseEnv.h"
#include "DBCStores.h"
#include "Creature.h"
#include "Item.h"
#include "Map.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "StringFormat.h"
#include "WorldSession.h"
#include <algorithm>
#include <cmath>
#include <map>
#include <unordered_map>

using namespace Acore::ChatCommands;

namespace
{
    // caractéristique -> (valeur -> suffixe aléatoire « +valeur caractéristique »)
    std::unordered_map<uint32, std::map<uint32, uint32>> suffixes;
    float pourcentParRang = 0.03f;
    uint32 prixAmelioration = 100;
    uint8 rangMaxAmelioration = 5;
    char const* const PREFIXE_AMELIORATION = "SOLAMELIO";

    bool EstPrincipale(uint32 stat)
    {
        return stat == ITEM_MOD_AGILITY || stat == ITEM_MOD_STRENGTH || stat == ITEM_MOD_INTELLECT
            || stat == ITEM_MOD_SPIRIT || stat == ITEM_MOD_STAMINA;
    }

    uint32 ChoisirSuffixe(ItemTemplate const* modele, uint8 rang, uint32& valeur, uint32* stat = nullptr)
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
        if (stat)
            *stat = principale;

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

namespace
{
    // Objet dont le rang peut monter d'un cran (rang actuel « rang »).
    bool Ameliorable(Item* item, uint8 rang)
    {
        ItemTemplate const* m = item ? item->GetTemplate() : nullptr;
        if (!m || (m->Class != ITEM_CLASS_WEAPON && m->Class != ITEM_CLASS_ARMOR)
            || m->Quality < ITEM_QUALITY_UNCOMMON || m->Quality == ITEM_QUALITY_HEIRLOOM || m->RandomProperty || m->RandomSuffix)
            return false;
        if (!rang && item->GetItemRandomPropertyId())
            return false;
        uint32 valeur = 0;
        return rang < rangMaxAmelioration && ChoisirSuffixe(m, rang + 1, valeur);
    }

    // Position vue par l'addon (sac -1 : équipement porté, case 1-19 ; sac 0 : sac à dos ; 1-4 : sacs) -> objet.
    Item* ObjetEn(Player* player, int32 sac, uint32 emplacement)
    {
        if (sac == -1 && emplacement >= 1 && emplacement <= EQUIPMENT_SLOT_END)
            return player->GetItemByPos(INVENTORY_SLOT_BAG_0, uint8(emplacement - 1));
        if (sac == 0 && emplacement >= 1 && emplacement <= INVENTORY_SLOT_ITEM_END - INVENTORY_SLOT_ITEM_START)
            return player->GetItemByPos(INVENTORY_SLOT_BAG_0, uint8(INVENTORY_SLOT_ITEM_START + emplacement - 1));
        if (sac >= 1 && sac <= 4 && emplacement >= 1 && emplacement <= MAX_BAG_SIZE)
            return player->GetItemByPos(uint8(INVENTORY_SLOT_BAG_START + sac - 1), uint8(emplacement - 1));
        return nullptr;
    }

    // « OBJET;sac;case;objet;rang;bonus actuel;bonus suivant;caractéristique » pour chaque objet améliorable,
    // puis « FIN;prix;rang max ».
    void ListerAmeliorables(Player* player)
    {
        auto Envoyer = [&](Item* item, int32 sac, uint32 emplacement)
        {
            if (!item)
                return;
            uint8 rang = SolAzeroth::RangDObjet(item->GetGUID().GetCounter());
            if (!Ameliorable(item, rang))
                return;
            uint32 avant = 0, apres = 0, stat = 0;
            if (rang)
                ChoisirSuffixe(item->GetTemplate(), rang, avant);
            ChoisirSuffixe(item->GetTemplate(), rang + 1, apres, &stat);
            SolAzeroth::EnvoyerAddon(player, PREFIXE_AMELIORATION, Acore::StringFormat("OBJET;{};{};{};{};{};{};{}",
                sac, emplacement, item->GetEntry(), rang, avant, apres, stat));
        };
        SolAzeroth::EnvoyerAddon(player, PREFIXE_AMELIORATION, "DEBUT");
        for (uint8 i = EQUIPMENT_SLOT_START; i < EQUIPMENT_SLOT_END; ++i)
            Envoyer(player->GetItemByPos(INVENTORY_SLOT_BAG_0, i), -1, i + 1);
        for (uint8 i = INVENTORY_SLOT_ITEM_START; i < INVENTORY_SLOT_ITEM_END; ++i)
            Envoyer(player->GetItemByPos(INVENTORY_SLOT_BAG_0, i), 0, i - INVENTORY_SLOT_ITEM_START + 1);
        for (uint8 i = INVENTORY_SLOT_BAG_START; i < INVENTORY_SLOT_BAG_END; ++i)
            if (Bag* b = player->GetBagByPos(i))
                for (uint32 j = 0; j < b->GetBagSize(); ++j)
                    Envoyer(b->GetItemByPos(uint8(j)), i - INVENTORY_SLOT_BAG_START + 1, j + 1);
        SolAzeroth::EnvoyerAddon(player, PREFIXE_AMELIORATION, Acore::StringFormat("FIN;{};{}", prixAmelioration, rangMaxAmelioration));
    }

    // Rang des objets pour l'infobulle : « RANGS;objet:suffixe:rang:valeur:caractéristique,… ». Le client reconnaît
    // l'objet à son numéro et à son suffixe (lien de l'objet), écrit le rang sous la ligne du bonus (« +18 Endurance »)
    // et garde la correspondance d'une session à l'autre.
    std::string EntreeRang(Item* item, uint8 rang)
    {
        uint32 valeur = 0, stat = 0;
        int32 suffixe = item->GetItemRandomPropertyId();
        if (ItemRandomPropertiesEntry const* p = suffixe > 0 ? sItemRandomPropertiesStore.LookupEntry(uint32(suffixe)) : nullptr)
            if (SpellItemEnchantmentEntry const* e = sSpellItemEnchantmentStore.LookupEntry(p->Enchantment[0]))
            {
                valeur = e->amount[0];
                stat = e->spellid[0];
            }
        return Acore::StringFormat("{}:{}:{}:{}:{}", item->GetEntry(), suffixe, rang, valeur, stat);
    }

    void EnvoyerRang(Player* player, Item* item, uint8 rang)
    {
        SolAzeroth::EnvoyerAddon(player, PREFIXE_AMELIORATION, "RANGS;" + EntreeRang(item, rang));
    }

    // Tous les objets de rang du personnage : porté, sacs, banque et ses sacs.
    void EnvoyerRangs(Player* player)
    {
        std::string paquet;
        auto Ajouter = [&](Item* item)
        {
            uint8 rang = item ? SolAzeroth::RangDObjet(item->GetGUID().GetCounter()) : 0;
            if (!rang)
                return;
            if (paquet.size() > 200)
            {
                SolAzeroth::EnvoyerAddon(player, PREFIXE_AMELIORATION, "RANGS;" + paquet);
                paquet.clear();
            }
            paquet += (paquet.empty() ? "" : ",") + EntreeRang(item, rang);
        };
        for (uint8 i = EQUIPMENT_SLOT_START; i < INVENTORY_SLOT_ITEM_END; ++i)
            Ajouter(player->GetItemByPos(INVENTORY_SLOT_BAG_0, i));
        for (uint8 i = BANK_SLOT_ITEM_START; i < BANK_SLOT_ITEM_END; ++i)
            Ajouter(player->GetItemByPos(INVENTORY_SLOT_BAG_0, i));
        for (uint8 sac = INVENTORY_SLOT_BAG_START; sac < INVENTORY_SLOT_BAG_END; ++sac)
            if (Bag* b = player->GetBagByPos(sac))
                for (uint32 j = 0; j < b->GetBagSize(); ++j)
                    Ajouter(b->GetItemByPos(uint8(j)));
        for (uint8 sac = BANK_SLOT_BAG_START; sac < BANK_SLOT_BAG_END; ++sac)
            if (Bag* b = player->GetBagByPos(sac))
                for (uint32 j = 0; j < b->GetBagSize(); ++j)
                    Ajouter(b->GetItemByPos(uint8(j)));
        if (!paquet.empty())
            SolAzeroth::EnvoyerAddon(player, PREFIXE_AMELIORATION, "RANGS;" + paquet);
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
        EnvoyerRang(player, item, rang);
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
    EnvoyerRang(player, item, rang);
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

class solazeroth_bonus_amelioration : public CommandScript
{
public:
    solazeroth_bonus_amelioration() : CommandScript("solazeroth_bonus_amelioration") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable sousCommandes =
        {
            { "liste",  HandleListe,  SEC_PLAYER, Console::No },
            { "monter", HandleMonter, SEC_PLAYER, Console::No },
            { "rangs",  HandleRangs,  SEC_PLAYER, Console::No },
        };
        static ChatCommandTable commandes =
        {
            { "solameliorer", sousCommandes },
        };
        return commandes;
    }

    static bool HandleListe(ChatHandler* handler)
    {
        ListerAmeliorables(handler->GetSession()->GetPlayer());
        return true;
    }

    static bool HandleRangs(ChatHandler* handler)
    {
        EnvoyerRangs(handler->GetSession()->GetPlayer());
        return true;
    }

    static bool HandleMonter(ChatHandler* handler, int32 sac, uint32 emplacement)
    {
        Player* player = handler->GetSession()->GetPlayer();
        Item* item = ObjetEn(player, sac, emplacement);
        uint8 rang = item ? SolAzeroth::RangDObjet(item->GetGUID().GetCounter()) : 0;
        if (!item || !Ameliorable(item, rang))
        {
            handler->SendSysMessage("|cffff6060Cet objet ne peut pas monter de rang.|r");
            ListerAmeliorables(player);
            return true;
        }
        if (player->IsInCombat())
        {
            handler->SendSysMessage("|cffff6060Impossible en combat.|r");
            return true;
        }
        uint32 valeur = 0;
        uint32 bonus = ChoisirSuffixe(item->GetTemplate(), rang + 1, valeur);
        if (!SolAzeroth::RetirerMarques(player, prixAmelioration))
        {
            handler->PSendSysMessage("|cffff6060Il faut {} Marques du voyageur.|r", prixAmelioration);
            return true;
        }
        // Objet porté : ses caractéristiques sont retirées puis remises, avec le nouveau suffixe.
        bool porte = item->IsEquipped();
        if (porte)
            player->_ApplyItemMods(item, item->GetSlot(), false);
        item->SetItemRandomProperties(int32(bonus));
        item->SetState(ITEM_CHANGED, player);
        if (porte)
            player->_ApplyItemMods(item, item->GetSlot(), true);
        ++rang;
        CharacterDatabase.Execute("REPLACE INTO solazeroth_objets_rang (item_guid, rang, enchantement) VALUES ({}, {}, {})",
            item->GetGUID().GetCounter(), rang, bonus);
        SolAzeroth::NoterRangObjet(item->GetGUID().GetCounter(), rang);
        EnvoyerRang(player, item, rang);
        handler->PSendSysMessage("|cffffd100Objet porté au rang {}|r (+{} au total).", rang, valeur);
        ListerAmeliorables(player);
        return true;
    }
};

class solazeroth_bonus_monde : public WorldScript
{
public:
    solazeroth_bonus_monde() : WorldScript("solazeroth_bonus_monde", { WORLDHOOK_ON_AFTER_CONFIG_LOAD, WORLDHOOK_ON_STARTUP }) { }

    void OnAfterConfigLoad(bool /*rechargement*/) override
    {
        pourcentParRang = sConfigMgr->GetOption<float>("SolAzeroth.Bonus.PourcentParRang", 0.03f);
        prixAmelioration = sConfigMgr->GetOption<uint32>("SolAzeroth.Amelioration.Prix", 100);
        rangMaxAmelioration = uint8(sConfigMgr->GetOption<uint32>("SolAzeroth.Amelioration.RangMax", 5));
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
    new solazeroth_bonus_amelioration();
}
