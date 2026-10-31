// v3 (31/10/2026) : inventaire sans limite (document v3, § 2.8 ; fenêtre « Collection », SolUI_Collection.lua).
// Les objets à collectionner (acore_world.solazeroth_v3_collectionnables, migration 069, générée par
// outils\collection_v3.py) ne passent plus par le sac : ils sont rangés en base, sans limite de nombre
// (acore_characters.solazeroth_v3_collection).
// - Butin (monstres, filons, herbes, dépeçage, coffres) : juste avant l'ouverture de la fenêtre de butin, ces objets en
//   sont retirés et rangés. Un sac plein ne bloque donc jamais la collecte.
// - Autres arrivées (récompense de quête, marchand, courrier…) : l'objet est rangé juste après être entré dans le sac.
// - Exception : un objet demandé par une quête en cours reste dans le sac, pour que la quête le compte.
// - .collection retirer <objet> <nombre> remet des objets dans le sac (pour une quête ou un métier de Blizzard).
// - Objet de départ d'une quête (Matraque du contremaître des Péons paresseux…) : retiré du sac quand la quête est
//   rendue, s'il est lié à la quête et ne sert à aucune autre quête en cours (31/10/2026 ; le moteur le laisse).
// - Récolte (31/10/2026) : herboristerie et minage au maximum à la connexion, sans pioche ; plus de dépeçage, le cuir
//   est ajouté au butin du corps à la mort de la créature.
// L'interface reçoit l'état par messages d'addon SOLCOL : « LISTE;objet:nombre,… » (en plusieurs morceaux, puis
// « FIN ») à la connexion, et « MAJ;objet;total;changement » à chaque rangement ou retrait.

#include "SolAzeroth.h"
#include "Chat.h"
#include "CommandScript.h"
#include "DatabaseEnv.h"
#include "Item.h"
#include "LootMgr.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "StringFormat.h"
#include <algorithm>
#include <unordered_map>
#include <unordered_set>
#include <vector>

using namespace Acore::ChatCommands;

namespace
{
    char const* const PREFIXE = "SOLCOL";
    size_t const MORCEAU = 200;          // longueur d'un message d'addon, sous la limite de 255

    std::unordered_set<uint32> collectionnables;
    std::unordered_map<uint32, uint32> depecage;     // créature -> butin de dépeçage (retiré du modèle au démarrage)

    // Herboristerie et minage de grand maître, sorts de récolte de grand maître (le minage n'a plus besoin de pioche :
    // migration 073).
    std::pair<uint16, uint32> const RECOLTE[] = { { 182, 50300 }, { 186, 50310 } };
    // Bonus des métiers de Blizzard, appris avec la compétence : Robustesse du minage (+60 Endurance au rang 6),
    // Sang-de-vie de l'herboristerie. Retirés (31/10/2026 : 713 points de vie au lieu d'une centaine).
    uint32 const BONUS_METIERS[] = { 53120, 53121, 53122, 53123, 53124, 53040,
                                     55428, 55480, 55500, 55501, 55502, 55503 };
    uint16 const DEPECAGE = 393;   // plus de dépeçage : la compétence (et Maître en anatomie) est retirée

    // F6 (31/10/2026) : Éclat cadavérique, monnaie des rangs d'objet (F8). Monstre ordinaire : 0 (25 %), 1 (40 %),
    // 2 (25 %) ou 3 (10 %) ; élite ×3 ; rare, chef de donjon ou chef renforcé ×5 ; et davantage avec la puissance,
    // au-delà de celle de Durotar (niveau d'origine 12). Valeurs choisies par l'utilisateur, à calibrer avec F8.
    uint32 const ECLAT = 910120;
    uint32 const CHEF_RENFORCE_PREMIER = 910010, CHEF_RENFORCE_DERNIER = 910014;   // migration 075

    uint32 Eclats(Creature* creature)
    {
        CreatureTemplate const* modele = creature->GetCreatureTemplate();
        if (modele->type == CREATURE_TYPE_CRITTER)
            return 0;
        bool renforce = modele->Entry >= CHEF_RENFORCE_PREMIER && modele->Entry <= CHEF_RENFORCE_DERNIER;
        if (creature->IsSummon() && !renforce)   // les renforts appelés en combat ne donnent rien
            return 0;
        uint32 tirage = urand(1, 100);
        float nombre = tirage <= 25 ? 0 : tirage <= 65 ? 1 : tirage <= 90 ? 2 : 3;
        if (renforce || creature->IsDungeonBoss() || modele->rank == CREATURE_ELITE_WORLDBOSS
            || modele->rank == CREATURE_ELITE_RARE || modele->rank == CREATURE_ELITE_RAREELITE)
            nombre *= 5;
        else if (modele->rank == CREATURE_ELITE_ELITE)
            nombre *= 3;
        nombre *= 1.0f + std::max(0, int32(modele->maxlevel) - 12) / 12.0f;
        return uint32(nombre + 0.5f);
    }

    // F6 : le butin des monstres et des chefs ne garde que les composants (objets à collectionner), les objets de quête
    // et les clés. Plus d'équipement, de recettes ni de consommables : l'équipement vient des quêtes et des annexes.
    bool Garde(uint32 objet)
    {
        if (collectionnables.count(objet))
            return true;
        ItemTemplate const* modele = sObjectMgr->GetItemTemplate(objet);
        return modele && (modele->Class == ITEM_CLASS_QUEST || modele->Class == ITEM_CLASS_KEY || modele->StartQuest
            || modele->Bonding == BIND_QUEST_ITEM);
    }

    struct Collection : DataMap::Base
    {
        std::unordered_map<uint32, uint32> nombres;
        std::vector<std::pair<uint32, uint32>> enAttente;   // objets entrés dans le sac, rangés au prochain passage
        bool retrait = false;                               // .collection retirer : ne pas ranger ce qu'on retire
    };

    Collection* CollectionDe(Player* player)
    {
        return player->CustomData.GetDefault<Collection>("solazeroth_v3_collection");
    }

    bool Collectionnable(uint32 objet)
    {
        return collectionnables.count(objet) != 0;
    }

    void Envoyer(Player* player, uint32 objet, int32 changement)
    {
        SolAzeroth::EnvoyerAddon(player, PREFIXE,
            Acore::StringFormat("MAJ;{};{};{}", objet, CollectionDe(player)->nombres[objet], changement));
    }

    void EnvoyerTout(Player* player)
    {
        std::string message;
        for (auto const& [objet, nombre] : CollectionDe(player)->nombres)
        {
            if (!nombre)
                continue;
            std::string morceau = Acore::StringFormat("{}{}:{}", message.empty() ? "" : ",", objet, nombre);
            if (message.size() + morceau.size() > MORCEAU)
            {
                SolAzeroth::EnvoyerAddon(player, PREFIXE, "LISTE;" + message);
                message.clear();
                morceau = morceau.substr(1);
            }
            message += morceau;
        }
        if (!message.empty())
            SolAzeroth::EnvoyerAddon(player, PREFIXE, "LISTE;" + message);
        SolAzeroth::EnvoyerAddon(player, PREFIXE, "FIN");
    }

    void Modifier(Player* player, uint32 objet, int32 changement)
    {
        uint32& nombre = CollectionDe(player)->nombres[objet];
        nombre = uint32(std::max<int64>(0, int64(nombre) + changement));
        CharacterDatabase.Execute("REPLACE INTO solazeroth_v3_collection (guid, objet, nombre) VALUES ({}, {}, {})",
            player->GetGUID().GetCounter(), objet, nombre);
        Envoyer(player, objet, changement);
    }
}

unsigned int SolAzeroth::NombreEnCollection(Player* player, unsigned int objet)
{
    auto const& nombres = CollectionDe(player)->nombres;
    auto it = nombres.find(objet);
    return it == nombres.end() ? 0 : it->second;
}

void SolAzeroth::RetirerDeCollection(Player* player, unsigned int objet, unsigned int nombre)
{
    Modifier(player, objet, -int32(std::min(nombre, NombreEnCollection(player, objet))));
}

class solazeroth_v3_collection_joueur : public PlayerScript
{
public:
    solazeroth_v3_collection_joueur() : PlayerScript("solazeroth_v3_collection_joueur", {
        PLAYERHOOK_ON_LOGIN, PLAYERHOOK_ON_BEFORE_SEND_LOOT, PLAYERHOOK_ON_STORE_NEW_ITEM, PLAYERHOOK_ON_UPDATE,
        PLAYERHOOK_ON_DELETE, PLAYERHOOK_ON_PLAYER_COMPLETE_QUEST, PLAYERHOOK_ON_CREATURE_KILL_CREDIT }) { }

    void OnPlayerCompleteQuest(Player* player, Quest const* quete) override
    {
        uint32 objet = quete->GetSrcItemId();
        ItemTemplate const* modele = objet ? sObjectMgr->GetItemTemplate(objet) : nullptr;
        if (!modele || modele->Bonding != BIND_QUEST_ITEM || modele->StartQuest || player->HasQuestForItem(objet))
            return;
        for (uint8 emplacement = 0; emplacement < MAX_QUEST_LOG_SIZE; ++emplacement)
            if (uint32 autre = player->GetQuestSlotQuestId(emplacement))
                if (Quest const* q = sObjectMgr->GetQuestTemplate(autre); q && q->GetSrcItemId() == objet &&
                    player->GetQuestStatus(autre) == QUEST_STATUS_INCOMPLETE)
                    return;
        player->DestroyItemCount(objet, 9999, true);
    }

    void OnPlayerLogin(Player* player) override
    {
        for (auto const& [metier, sort] : RECOLTE)
        {
            player->SetSkill(metier, 6, 450, 450);
            if (!player->HasSpell(sort))
                player->learnSpell(sort);
        }
        for (uint32 sort : BONUS_METIERS)
            if (player->HasSpell(sort))
                player->removeSpell(sort, SPEC_MASK_ALL, false);
        if (player->HasSkill(DEPECAGE))
            player->SetSkill(DEPECAGE, 0, 0, 0);
        Collection* c = CollectionDe(player);
        if (QueryResult r = CharacterDatabase.Query("SELECT objet, nombre FROM solazeroth_v3_collection WHERE guid = {}",
            player->GetGUID().GetCounter()))
        {
            do
                c->nombres[(*r)[0].Get<uint32>()] = (*r)[1].Get<uint32>();
            while (r->NextRow());
        }
        EnvoyerTout(player);
    }

    // Avant l'envoi de la fenêtre de butin : les objets à collectionner partent dans la Collection. Seuls les objets
    // ordinaires du butin sont pris (pas ceux de quête, ni ceux réservés à un joueur ou soumis à une condition).
    void OnPlayerBeforeSendLoot(Player* player, ObjectGuid /*lootGuid*/, Loot* loot) override
    {
        for (LootItem& objet : loot->items)
        {
            if (objet.is_looted || objet.freeforall || objet.is_blocked || !objet.conditions.empty()
                || !Collectionnable(objet.itemid) || player->HasQuestForItem(objet.itemid)
                || !objet.AllowedForPlayer(player, loot->sourceWorldObjectGUID))
                continue;
            Modifier(player, objet.itemid, int32(objet.count));
            objet.is_looted = true;
            if (loot->unlootedCount)
                --loot->unlootedCount;
        }
    }

    // Le cuir et les peaux sont dans le butin du corps : on n'a plus à dépecer. Les éclats cadavériques aussi.
    void OnPlayerCreatureKillCredit(Player* player, Creature* creature) override
    {
        if (creature->GetLootRecipient() != player)
            return;
        if (auto it = depecage.find(creature->GetEntry()); it != depecage.end())
            LootTemplates_Skinning.GetLootFor(it->second)->Process(creature->loot, LootTemplates_Skinning,
                creature->GetLootMode(), player);
        if (uint32 nombre = Eclats(creature))
            creature->loot.AddItem(LootStoreItem(ECLAT, 0, 100.0f, false, LOOT_MODE_DEFAULT, 0, nombre, nombre));
        if (!creature->loot.isLooted())
            creature->SetDynamicFlag(UNIT_DYNFLAG_LOOTABLE);
    }

    void OnPlayerStoreNewItem(Player* player, Item* item, uint32 count) override
    {
        Collection* c = CollectionDe(player);
        if (!c->retrait && item && Collectionnable(item->GetEntry()))
            c->enAttente.emplace_back(item->GetEntry(), count);
    }

    // Rangement différé : l'objet vient d'être créé, on ne le détruit pas pendant que le jeu le pose dans le sac.
    void OnPlayerUpdate(Player* player, uint32 /*diff*/) override
    {
        Collection* c = CollectionDe(player);
        if (c->enAttente.empty())
            return;
        std::vector<std::pair<uint32, uint32>> liste;
        liste.swap(c->enAttente);
        for (auto const& [objet, nombre] : liste)
        {
            if (player->HasQuestForItem(objet))
                continue;
            uint32 present = std::min(nombre, player->GetItemCount(objet));
            if (!present)
                continue;
            player->DestroyItemCount(objet, present, true);
            Modifier(player, objet, int32(present));
        }
    }

    void OnPlayerDelete(ObjectGuid guid, uint32 /*compte*/) override
    {
        CharacterDatabase.Execute("DELETE FROM solazeroth_v3_collection WHERE guid = {}", guid.GetCounter());
    }
};

class solazeroth_v3_collection_butin : public MiscScript
{
public:
    solazeroth_v3_collection_butin() : MiscScript("solazeroth_v3_collection_butin",
        { MISCHOOK_ON_AFTER_LOOT_TEMPLATE_PROCESS }) { }

    void OnAfterLootTemplateProcess(Loot* loot, LootTemplate const* /*table*/, LootStore const& store, Player* joueur,
        bool /*personnel*/, bool /*sansErreur*/, uint16 /*mode*/) override
    {
        if (&store != &LootTemplates_Creature)
            return;
        auto fin = std::remove_if(loot->items.begin(), loot->items.end(), [&](LootItem const& objet)
        {
            if (Garde(objet.itemid))
                return false;
            if (loot->unlootedCount && joueur && objet.AllowedForPlayer(joueur, loot->sourceWorldObjectGUID))
                --loot->unlootedCount;
            return true;
        });
        loot->items.erase(fin, loot->items.end());
        for (size_t i = 0; i < loot->items.size(); ++i)
            loot->items[i].itemIndex = i;
    }
};

class solazeroth_v3_collection_monde : public WorldScript
{
public:
    solazeroth_v3_collection_monde() : WorldScript("solazeroth_v3_collection_monde", { WORLDHOOK_ON_STARTUP }) { }

    void OnStartup() override
    {
        collectionnables.clear();
        if (QueryResult r = WorldDatabase.Query("SELECT entry FROM solazeroth_v3_collectionnables"))
        {
            do
                collectionnables.insert((*r)[0].Get<uint32>());
            while (r->NextRow());
        }
        LOG_INFO("module", ">> Sol'Azeroth v3 : {} objets à collectionner", collectionnables.size());
        // Sans butin de dépeçage, le corps vidé n'est plus marqué « à dépecer ».
        for (auto const& [entree, modele] : *sObjectMgr->GetCreatureTemplates())
            if (modele.SkinLootId && LootTemplates_Skinning.HaveLootFor(modele.SkinLootId))
            {
                depecage[entree] = modele.SkinLootId;
                const_cast<CreatureTemplate&>(modele).SkinLootId = 0;
            }
        LOG_INFO("module", ">> Sol'Azeroth v3 : {} créatures donnent leur cuir sans dépeçage", depecage.size());
    }
};

class solazeroth_v3_collection_commandes : public CommandScript
{
public:
    solazeroth_v3_collection_commandes() : CommandScript("solazeroth_v3_collection_commandes") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable collection =
        {
            { "",        HandleEtat,    SEC_PLAYER, Console::No },
            { "retirer", HandleRetirer, SEC_PLAYER, Console::No },
        };
        static ChatCommandTable commandes =
        {
            { "collection", collection },
        };
        return commandes;
    }

    // .collection : renvoie tout l'état à l'interface (après un /reload).
    static bool HandleEtat(ChatHandler* handler)
    {
        EnvoyerTout(handler->GetPlayer());
        return true;
    }

    // .collection retirer <objet> <nombre> : remet des objets de la Collection dans le sac, s'il y a la place.
    static bool HandleRetirer(ChatHandler* handler, uint32 objet, uint32 nombre)
    {
        Player* player = handler->GetPlayer();
        Collection* c = CollectionDe(player);
        uint32 possede = c->nombres[objet];
        nombre = std::min(nombre, possede);
        if (!nombre)
        {
            handler->SendErrorMessage("Tu n'en as pas dans ta Collection.");
            return false;
        }
        ItemPosCountVec dest;
        uint32 manque = 0;
        if (player->CanStoreNewItem(NULL_BAG, NULL_SLOT, dest, objet, nombre, &manque) != EQUIP_ERR_OK)
            nombre -= manque;
        if (!nombre || dest.empty())
        {
            handler->SendErrorMessage("Pas assez de place dans le sac.");
            return false;
        }
        c->retrait = true;
        Item* item = player->StoreNewItem(dest, objet, true);
        c->retrait = false;
        if (!item)
            return false;
        player->SendNewItem(item, nombre, true, false);
        Modifier(player, objet, -int32(nombre));
        return true;
    }
};

void AddSC_solazeroth_v3_collection()
{
    new solazeroth_v3_collection_joueur();
    new solazeroth_v3_collection_butin();
    new solazeroth_v3_collection_monde();
    new solazeroth_v3_collection_commandes();
}
