// v3, E1 (31/10/2026) : fabriquer et améliorer l'équipement (document v3, § 2.4 et F8 ; fenêtre « Équipement »,
// SolUI_Equipement.lua). Données générées par outils\equipement_v3.py (migration 078).
// - Fabrication : nos recettes (solazeroth_v3_recettes et _composants), payées en composants de la Collection (puis du
//   sac) et en or. Maille, bouclier et armes demandent d'être près d'une enclume ou d'une forge (choix de l'utilisateur :
//   le cuir et le tissu n'avaient pas de prérequis à l'origine). Une recette s'ouvre à une puissance donnée.
// - Rangs : chaque pièce existe en 6 versions, de 0 à 5 (solazeroth_v3_rangs), +10 % de caractéristiques par rang.
//   Améliorer remplace l'objet par la version suivante, à la même place. Coût à Durotar : 5, 10, 20, 35 puis 60 éclats
//   cadavériques et 20 c, 40 c, 80 c, 1 pa 60, 3 pa 20 ; davantage au-delà de la puissance 12, comme les éclats
//   (v3_collection.cpp). Les rangs 4 et 5 demanderont en plus un composant rare, avec la joaillerie (F8).
// - Cuisine (31/10/2026) : les plats de v3_cuisine.cpp (solazeroth_v3_plats, migration 079), payés en ingrédients,
//   près d'un feu (le Feu de camp v3 compte), en 5 s.
// - Messages d'addon SOLEQUIP : « FORGE;forge 0|1;feu 0|1 », puis « DEBUT », « OBJ;sac;case;entrée;rang;éclats;or » pour chaque pièce
//   améliorable (sac -1 : équipement porté, case 0 à 18 ; sac 0 à 4 : sacs du jeu, case à partir de 1) et « FIN ».
// Commandes de l'interface : .equipement, .equipement fabriquer <objet>, .equipement ameliorer <sac> <case>.
// - Fabrication en 10 s (31/10/2026, demande de l'utilisateur) : animation du métier (marteler à la forge, travailler
//   debout sinon) et barre de progression de l'interface (« FABRIQUE;objet;secondes », puis « FINI » ou « ANNULE »).
//   Bouger annule ; composants et or ne sont pris qu'à la fin, après une nouvelle vérification.
// - Désenchantement et enchantement (31/10/2026, demande de l'utilisateur ; outils\enchantement_v3.py, migration 081) :
//   « PIECE;sac;case;entrée;InventoryType;enchantement;table de désenchantement » pour chaque armure et arme.
//   .equipement desenchanter <sac> <case> : une pièce du sac, verte ou mieux, donne le butin de sa table, rangé dans la
//   Collection. .equipement enchanter <sac> <case> <id> : un enchantement de solazeroth_v3_enchantements, payé en
//   composants et en or, remplace celui de la pièce. Améliorer une pièce garde son enchantement.

#include "SolAzeroth.h"
#include "CellImpl.h"
#include "Chat.h"
#include "CommandScript.h"
#include "DatabaseEnv.h"
#include "GameObject.h"
#include "GridNotifiers.h"
#include "GridNotifiersImpl.h"
#include "Item.h"
#include "LootMgr.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "StringFormat.h"
#include <algorithm>
#include <unordered_map>
#include <vector>

using namespace Acore::ChatCommands;

namespace
{
    char const* const PREFIXE = "SOLEQUIP";
    uint32 const ECLAT = 910120;
    uint8 const RANG_MAX = 5;
    uint32 const ECLATS_PAR_RANG[RANG_MAX] = { 5, 10, 20, 35, 60 };
    uint32 const OR_PAR_RANG[RANG_MAX] = { 20, 40, 80, 160, 320 };   // en cuivre
    uint32 const ENCLUME = 1, FORGE = 3, FEU = 4;                    // spellFocus.focusId
    float const PORTEE_FORGE = 20.0f, PORTEE_FEU = 10.0f;

    struct Rang { uint32 base; uint8 rang; };
    struct Recette
    {
        bool forge = false;
        bool feu = false;   // plat de la cuisine
        uint8 puissance = 0;
        uint32 prix = 0;
        std::vector<std::pair<uint32, uint32>> composants;
    };

    std::unordered_map<uint32, Rang> rangs;                     // entrée -> pièce de base et rang
    std::unordered_map<uint64, uint32> versions;                // (base << 8 | rang) -> entrée
    std::unordered_map<uint32, Recette> recettes;

    struct Enchantement
    {
        uint32 enchantement = 0;   // SpellItemEnchantment.dbc
        uint32 prix = 0;
        std::vector<uint8> types;  // InventoryType
        std::vector<std::pair<uint32, uint32>> composants;
    };
    std::unordered_map<uint32, Enchantement> enchantements;

    uint32 Version(uint32 base, uint8 rang)
    {
        auto it = versions.find(uint64(base) << 8 | rang);
        return it == versions.end() ? 0 : it->second;
    }

    // Coût du passage au rang « vers » (1 à 5) d'une pièce de cette puissance.
    std::pair<uint32, uint32> Cout(uint32 puissance, uint8 vers)
    {
        float facteur = 1.0f + std::max(0, int32(puissance) - 12) / 12.0f;
        return { uint32(ECLATS_PAR_RANG[vers - 1] * facteur + 0.5f), uint32(OR_PAR_RANG[vers - 1] * facteur + 0.5f) };
    }

    bool PresDe(Player* player, std::initializer_list<uint32> foyers, float portee)
    {
        for (uint32 focus : foyers)
        {
            GameObject* trouve = nullptr;
            Acore::GameObjectFocusCheck verif(player, focus);
            Acore::GameObjectSearcher<Acore::GameObjectFocusCheck> chercheur(player, trouve, verif);
            Cell::VisitObjects(player, chercheur, portee);
            if (trouve)
                return true;
        }
        return false;
    }

    bool PresDUneForge(Player* player)
    {
        return PresDe(player, { ENCLUME, FORGE }, PORTEE_FORGE);
    }

    bool PresDUnFeu(Player* player)
    {
        return PresDe(player, { FEU }, PORTEE_FEU);
    }

    // Position de l'interface -> position du jeu. sac -1 : porté (case 0 à 18) ; 0 : sac à dos ; 1 à 4 : sacs.
    bool PositionDuJeu(int32 sac, uint32 caseInterface, uint8& bag, uint8& slot)
    {
        if (sac == -1 && caseInterface < EQUIPMENT_SLOT_END)
        {
            bag = INVENTORY_SLOT_BAG_0;
            slot = uint8(caseInterface);
            return true;
        }
        if (caseInterface < 1 || caseInterface > 36)
            return false;
        if (sac == 0)
        {
            bag = INVENTORY_SLOT_BAG_0;
            slot = uint8(INVENTORY_SLOT_ITEM_START + caseInterface - 1);
            return slot < INVENTORY_SLOT_ITEM_END;
        }
        if (sac >= 1 && sac <= 4)
        {
            bag = uint8(INVENTORY_SLOT_BAG_START + sac - 1);
            slot = uint8(caseInterface - 1);
            return true;
        }
        return false;
    }

    void EnvoyerPiece(Player* player, Item* item, int32 sac, uint32 caseInterface)
    {
        auto it = item ? rangs.find(item->GetEntry()) : rangs.end();
        if (it == rangs.end())
            return;
        uint8 rang = it->second.rang;
        auto [eclats, prix] = rang < RANG_MAX ? Cout(item->GetTemplate()->ItemLevel, rang + 1) : std::pair<uint32, uint32>{ 0, 0 };
        SolAzeroth::EnvoyerAddon(player, PREFIXE, Acore::StringFormat("OBJ;{};{};{};{};{};{}", sac, caseInterface,
            item->GetEntry(), rang, eclats, prix));
    }

    bool Desenchantable(Item* item)
    {
        ItemTemplate const* modele = item->GetTemplate();
        return modele->DisenchantID && modele->Quality >= ITEM_QUALITY_UNCOMMON && modele->Quality <= ITEM_QUALITY_EPIC;
    }

    void EnvoyerArmureOuArme(Player* player, Item* item, int32 sac, uint32 caseInterface)
    {
        if (!item || (item->GetTemplate()->Class != ITEM_CLASS_ARMOR && item->GetTemplate()->Class != ITEM_CLASS_WEAPON))
            return;
        SolAzeroth::EnvoyerAddon(player, PREFIXE, Acore::StringFormat("PIECE;{};{};{};{};{};{}", sac, caseInterface,
            item->GetEntry(), item->GetTemplate()->InventoryType, item->GetEnchantmentId(PERM_ENCHANTMENT_SLOT),
            Desenchantable(item) ? item->GetTemplate()->DisenchantID : 0));
    }

    void EnvoyerPieces(Player* player, Item* item, int32 sac, uint32 caseInterface)
    {
        EnvoyerPiece(player, item, sac, caseInterface);
        EnvoyerArmureOuArme(player, item, sac, caseInterface);
    }

    // Pose l'enchantement permanent d'une pièce, en retirant puis rendant ses effets si elle est portée.
    void Enchanter(Player* player, Item* item, uint32 enchantement)
    {
        player->ApplyEnchantment(item, PERM_ENCHANTMENT_SLOT, false);
        item->SetEnchantment(PERM_ENCHANTMENT_SLOT, enchantement, 0, 0, player->GetGUID());
        player->ApplyEnchantment(item, PERM_ENCHANTMENT_SLOT, true);
    }

    void Envoyer(Player* player)
    {
        SolAzeroth::EnvoyerAddon(player, PREFIXE, Acore::StringFormat("FORGE;{};{}", PresDUneForge(player) ? 1 : 0,
            PresDUnFeu(player) ? 1 : 0));
        SolAzeroth::EnvoyerAddon(player, PREFIXE, "DEBUT");
        for (uint8 slot = EQUIPMENT_SLOT_START; slot < EQUIPMENT_SLOT_END; ++slot)
            EnvoyerPieces(player, player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot), -1, slot);
        for (uint8 slot = INVENTORY_SLOT_ITEM_START; slot < INVENTORY_SLOT_ITEM_END; ++slot)
            EnvoyerPieces(player, player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot), 0, slot - INVENTORY_SLOT_ITEM_START + 1);
        for (uint8 sac = 1; sac <= 4; ++sac)
            if (Bag* b = player->GetBagByPos(INVENTORY_SLOT_BAG_START + sac - 1))
                for (uint32 slot = 0; slot < b->GetBagSize(); ++slot)
                    EnvoyerPieces(player, b->GetItemByPos(uint8(slot)), sac, slot + 1);
        SolAzeroth::EnvoyerAddon(player, PREFIXE, "FIN");
    }

    uint32 Possede(Player* player, uint32 objet)
    {
        return SolAzeroth::NombreEnCollection(player, objet) + player->GetItemCount(objet);
    }

    // Prend d'abord dans la Collection, puis dans le sac.
    void Prendre(Player* player, uint32 objet, uint32 nombre)
    {
        uint32 range = std::min(nombre, SolAzeroth::NombreEnCollection(player, objet));
        if (range)
            SolAzeroth::RetirerDeCollection(player, objet, range);
        if (nombre > range)
            player->DestroyItemCount(objet, nombre - range, true);
    }

    std::string Nom(uint32 objet)
    {
        ItemTemplate const* modele = sObjectMgr->GetItemTemplate(objet);
        return modele ? modele->Name1 : std::to_string(objet);
    }

    uint32 const DUREE_FABRICATION = 10000, DUREE_CUISINE = 5000;
    char const* const CLE_FABRICATION = "solazeroth_v3_fabrication";

    struct Fabrication : DataMap::Base
    {
        uint32 objet = 0;   // 0 : aucune fabrication en cours
        uint32 reste = 0;
        Position depart;
    };

    // Tout ce que demande la recette ; dest reçoit la place de l'objet dans le sac.
    bool PeutFabriquer(Player* player, uint32 objet, ChatHandler& chat, ItemPosCountVec& dest)
    {
        auto it = recettes.find(objet);
        if (it == recettes.end())
        {
            chat.SendErrorMessage("Recette inconnue.");
            return false;
        }
        Recette const& recette = it->second;
        bool mj = player->IsGameMaster();
        if (!mj && SolAzeroth::PuissanceJoueur(player) + 0.05f < recette.puissance)
        {
            chat.SendErrorMessage("Il faut une puissance de {} pour cette recette.", recette.puissance);
            return false;
        }
        if (recette.forge && !PresDUneForge(player))
        {
            chat.SendErrorMessage("La maille, les boucliers et les armes se forgent près d'une enclume ou d'une forge.");
            return false;
        }
        if (recette.feu && !PresDUnFeu(player))
        {
            chat.SendErrorMessage("La cuisine se fait près d'un feu (ton Feu de camp compte).");
            return false;
        }
        for (auto const& [composant, nombre] : recette.composants)
            if (Possede(player, composant) < nombre)
            {
                chat.SendErrorMessage("Il manque {} × {}.", nombre - Possede(player, composant), Nom(composant));
                return false;
            }
        if (!player->HasEnoughMoney(recette.prix))
        {
            chat.SendErrorMessage("Pas assez d'or.");
            return false;
        }
        if (player->CanStoreNewItem(NULL_BAG, NULL_SLOT, dest, objet, 1) != EQUIP_ERR_OK)
        {
            chat.SendErrorMessage("Pas assez de place dans le sac.");
            return false;
        }
        return true;
    }

    void ArreterFabrication(Player* player, Fabrication& fabrication, char const* fin)
    {
        fabrication.objet = 0;
        player->SetUInt32Value(UNIT_NPC_EMOTESTATE, EMOTE_ONESHOT_NONE);
        SolAzeroth::EnvoyerAddon(player, PREFIXE, fin);
    }

    void TerminerFabrication(Player* player, uint32 objet)
    {
        ChatHandler chat(player->GetSession());
        ItemPosCountVec dest;
        if (!PeutFabriquer(player, objet, chat, dest))
            return;
        Recette const& recette = recettes.at(objet);
        for (auto const& [composant, nombre] : recette.composants)
            Prendre(player, composant, nombre);
        player->ModifyMoney(-int32(recette.prix));
        if (Item* item = player->StoreNewItem(dest, objet, true))
            player->SendNewItem(item, 1, false, true);
        Envoyer(player);
    }
}

unsigned char SolAzeroth::RangEquipement(unsigned int entree)
{
    auto it = rangs.find(entree);
    return it == rangs.end() ? 0 : it->second.rang;
}

class solazeroth_v3_equipement_monde : public WorldScript
{
public:
    solazeroth_v3_equipement_monde() : WorldScript("solazeroth_v3_equipement_monde", { WORLDHOOK_ON_STARTUP }) { }

    void OnStartup() override
    {
        rangs.clear();
        versions.clear();
        recettes.clear();
        enchantements.clear();
        if (QueryResult r = WorldDatabase.Query("SELECT entree, base, rang FROM solazeroth_v3_rangs"))
        {
            do
            {
                Field* f = r->Fetch();
                rangs[f[0].Get<uint32>()] = { f[1].Get<uint32>(), f[2].Get<uint8>() };
                versions[uint64(f[1].Get<uint32>()) << 8 | f[2].Get<uint8>()] = f[0].Get<uint32>();
            } while (r->NextRow());
        }
        if (QueryResult r = WorldDatabase.Query("SELECT objet, forge, puissance, prix FROM solazeroth_v3_recettes"))
        {
            do
            {
                Field* f = r->Fetch();
                Recette& recette = recettes[f[0].Get<uint32>()];
                recette.forge = f[1].Get<uint8>() != 0;
                recette.puissance = f[2].Get<uint8>();
                recette.prix = f[3].Get<uint32>();
            } while (r->NextRow());
        }
        if (QueryResult r = WorldDatabase.Query("SELECT objet FROM solazeroth_v3_plats"))
        {
            do
            {
                recettes[r->Fetch()[0].Get<uint32>()].feu = true;
            } while (r->NextRow());
        }
        if (QueryResult r = WorldDatabase.Query("SELECT objet, composant, nombre FROM solazeroth_v3_recettes_composants "
            "UNION ALL SELECT objet, composant, nombre FROM solazeroth_v3_plats_composants"))
        {
            do
            {
                Field* f = r->Fetch();
                recettes[f[0].Get<uint32>()].composants.emplace_back(f[1].Get<uint32>(), f[2].Get<uint32>());
            } while (r->NextRow());
        }
        if (QueryResult r = WorldDatabase.Query("SELECT id, enchantement, prix FROM solazeroth_v3_enchantements"))
        {
            do
            {
                Field* f = r->Fetch();
                Enchantement& enchantement = enchantements[f[0].Get<uint32>()];
                enchantement.enchantement = f[1].Get<uint32>();
                enchantement.prix = f[2].Get<uint32>();
            } while (r->NextRow());
        }
        if (QueryResult r = WorldDatabase.Query("SELECT id, type FROM solazeroth_v3_enchantements_types"))
        {
            do
            {
                Field* f = r->Fetch();
                enchantements[f[0].Get<uint32>()].types.push_back(f[1].Get<uint8>());
            } while (r->NextRow());
        }
        if (QueryResult r = WorldDatabase.Query("SELECT id, composant, nombre FROM solazeroth_v3_enchantements_composants"))
        {
            do
            {
                Field* f = r->Fetch();
                enchantements[f[0].Get<uint32>()].composants.emplace_back(f[1].Get<uint32>(), f[2].Get<uint32>());
            } while (r->NextRow());
        }
        LOG_INFO("module", ">> Sol'Azeroth v3 : {} recettes, {} versions d'équipement par rang, {} enchantements",
            recettes.size(), rangs.size(), enchantements.size());
    }
};

class solazeroth_v3_equipement_commandes : public CommandScript
{
public:
    solazeroth_v3_equipement_commandes() : CommandScript("solazeroth_v3_equipement_commandes") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable equipement =
        {
            { "",          HandleEtat,      SEC_PLAYER, Console::No },
            { "fabriquer", HandleFabriquer, SEC_PLAYER, Console::No },
            { "ameliorer", HandleAmeliorer, SEC_PLAYER, Console::No },
            { "desenchanter", HandleDesenchanter, SEC_PLAYER, Console::No },
            { "enchanter", HandleEnchanter, SEC_PLAYER, Console::No },
        };
        static ChatCommandTable commandes =
        {
            { "equipement", equipement },
        };
        return commandes;
    }

    static bool HandleEtat(ChatHandler* handler)
    {
        Envoyer(handler->GetPlayer());
        return true;
    }

    static bool HandleFabriquer(ChatHandler* handler, uint32 objet)
    {
        Player* player = handler->GetPlayer();
        Fabrication* fabrication = player->CustomData.GetDefault<Fabrication>(CLE_FABRICATION);
        if (fabrication->objet)
        {
            handler->SendErrorMessage("Une fabrication est déjà en cours.");
            return false;
        }
        ItemPosCountVec dest;
        if (!PeutFabriquer(player, objet, *handler, dest))
            return false;
        if (player->isMoving())
        {
            handler->SendErrorMessage("Il faut rester immobile pour fabriquer.");
            return false;
        }
        Recette const& recette = recettes.at(objet);
        fabrication->objet = objet;
        fabrication->reste = recette.feu ? DUREE_CUISINE : DUREE_FABRICATION;
        fabrication->depart = player->GetPosition();
        // Assis au coin du feu, on cuisine sans se lever (se lever éteindrait le Feu de camp).
        if (!player->IsSitState())
            player->SetUInt32Value(UNIT_NPC_EMOTESTATE, recette.forge ? EMOTE_STATE_WORK_MINING : EMOTE_STATE_USE_STANDING);
        SolAzeroth::EnvoyerAddon(player, PREFIXE, Acore::StringFormat("FABRIQUE;{};{}", objet, fabrication->reste / 1000));
        return true;
    }

    static bool HandleAmeliorer(ChatHandler* handler, int32 sac, uint32 caseInterface)
    {
        Player* player = handler->GetPlayer();
        uint8 bag, slot;
        Item* item = PositionDuJeu(sac, caseInterface, bag, slot) ? player->GetItemByPos(bag, slot) : nullptr;
        auto it = item ? rangs.find(item->GetEntry()) : rangs.end();
        if (it == rangs.end())
        {
            handler->SendErrorMessage("Cet objet ne s'améliore pas.");
            return false;
        }
        Rang const actuel = it->second;
        uint32 suivant = actuel.rang < RANG_MAX ? Version(actuel.base, actuel.rang + 1) : 0;
        if (!suivant)
        {
            handler->SendErrorMessage("Cet objet est déjà au rang maximum.");
            return false;
        }
        if (player->IsInCombat())
        {
            handler->SendErrorMessage("Pas pendant un combat.");
            return false;
        }
        auto [eclats, prix] = Cout(item->GetTemplate()->ItemLevel, actuel.rang + 1);
        if (Possede(player, ECLAT) < eclats)
        {
            handler->SendErrorMessage("Il faut {} éclats cadavériques (tu en as {}).", eclats, Possede(player, ECLAT));
            return false;
        }
        if (!player->HasEnoughMoney(prix))
        {
            handler->SendErrorMessage("Pas assez d'or.");
            return false;
        }
        bool porte = bag == INVENTORY_SLOT_BAG_0 && slot < EQUIPMENT_SLOT_END;
        uint16 destPorte = 0;
        if (porte && player->CanEquipNewItem(slot, destPorte, suivant, true) != EQUIP_ERR_OK)
        {
            handler->SendErrorMessage("Impossible de porter la nouvelle version.");
            return false;
        }
        Prendre(player, ECLAT, eclats);
        player->ModifyMoney(-int32(prix));
        uint32 enchantement = item->GetEnchantmentId(PERM_ENCHANTMENT_SLOT);
        player->DestroyItem(bag, slot, true);
        Item* nouveau = nullptr;
        if (porte)
            nouveau = player->EquipNewItem(destPorte, suivant, true);
        else
        {
            ItemPosCountVec dest;
            if (player->CanStoreNewItem(bag, slot, dest, suivant, 1) == EQUIP_ERR_OK
                || player->CanStoreNewItem(NULL_BAG, NULL_SLOT, dest, suivant, 1) == EQUIP_ERR_OK)
                nouveau = player->StoreNewItem(dest, suivant, true);
        }
        if (nouveau && enchantement)
            Enchanter(player, nouveau, enchantement);
        if (!nouveau)
            LOG_ERROR("module", "Sol'Azeroth v3 : amélioration de {} perdue pour {}", suivant, player->GetName());
        else
            ChatHandler(player->GetSession()).SendSysMessage(Acore::StringFormat("|cff8cc4a6Amélioration :|r {} passe au rang {}.",
                Nom(actuel.base), actuel.rang + 1));
        Envoyer(player);
        return true;
    }

    static bool HandleDesenchanter(ChatHandler* handler, int32 sac, uint32 caseInterface)
    {
        Player* player = handler->GetPlayer();
        uint8 bag, slot;
        Item* item = sac >= 0 && PositionDuJeu(sac, caseInterface, bag, slot) ? player->GetItemByPos(bag, slot) : nullptr;
        if (!item || !Desenchantable(item))
        {
            handler->SendErrorMessage("Cet objet ne se désenchante pas (une pièce du sac, verte ou mieux).");
            return false;
        }
        if (player->IsInCombat())
        {
            handler->SendErrorMessage("Pas pendant un combat.");
            return false;
        }
        std::string nom = Nom(item->GetEntry());
        Loot butin;
        butin.FillLoot(item->GetTemplate()->DisenchantID, LootTemplates_Disenchant, player, true);
        player->DestroyItem(bag, slot, true);
        std::string produits;
        for (LootItem const& produit : butin.items)
        {
            if (!SolAzeroth::AjouterACollection(player, produit.itemid, produit.count))
            {
                ItemPosCountVec dest;
                if (player->CanStoreNewItem(NULL_BAG, NULL_SLOT, dest, produit.itemid, produit.count) == EQUIP_ERR_OK)
                    player->StoreNewItem(dest, produit.itemid, true);
                else
                    LOG_ERROR("module", "Sol'Azeroth v3 : désenchantement, {} × {} perdu pour {}", produit.count,
                        produit.itemid, player->GetName());
            }
            produits += Acore::StringFormat("{}{} × {}", produits.empty() ? "" : ", ", produit.count, Nom(produit.itemid));
        }
        handler->SendSysMessage(Acore::StringFormat("|cff8cc4a6Désenchantement :|r {} donne {}.", nom,
            produits.empty() ? "rien" : produits));
        Envoyer(player);
        return true;
    }

    static bool HandleEnchanter(ChatHandler* handler, int32 sac, uint32 caseInterface, uint32 id)
    {
        Player* player = handler->GetPlayer();
        uint8 bag, slot;
        Item* item = PositionDuJeu(sac, caseInterface, bag, slot) ? player->GetItemByPos(bag, slot) : nullptr;
        auto it = enchantements.find(id);
        if (!item || it == enchantements.end())
        {
            handler->SendErrorMessage("Enchantement ou pièce inconnus.");
            return false;
        }
        Enchantement const& enchantement = it->second;
        if (std::find(enchantement.types.begin(), enchantement.types.end(), uint8(item->GetTemplate()->InventoryType))
            == enchantement.types.end())
        {
            handler->SendErrorMessage("Cet enchantement ne va pas sur cette pièce.");
            return false;
        }
        if (item->GetEnchantmentId(PERM_ENCHANTMENT_SLOT) == enchantement.enchantement)
        {
            handler->SendErrorMessage("La pièce porte déjà cet enchantement.");
            return false;
        }
        if (player->IsInCombat())
        {
            handler->SendErrorMessage("Pas pendant un combat.");
            return false;
        }
        for (auto const& [composant, nombre] : enchantement.composants)
            if (Possede(player, composant) < nombre)
            {
                handler->SendErrorMessage("Il manque {} × {}.", nombre - Possede(player, composant), Nom(composant));
                return false;
            }
        if (!player->HasEnoughMoney(enchantement.prix))
        {
            handler->SendErrorMessage("Pas assez d'or.");
            return false;
        }
        for (auto const& [composant, nombre] : enchantement.composants)
            Prendre(player, composant, nombre);
        player->ModifyMoney(-int32(enchantement.prix));
        Enchanter(player, item, enchantement.enchantement);
        handler->SendSysMessage(Acore::StringFormat("|cff8cc4a6Enchantement :|r {} est enchanté.", Nom(item->GetEntry())));
        Envoyer(player);
        return true;
    }
};

class solazeroth_v3_equipement_joueur : public PlayerScript
{
public:
    solazeroth_v3_equipement_joueur() : PlayerScript("solazeroth_v3_equipement_joueur", { PLAYERHOOK_ON_UPDATE }) { }

    void OnPlayerUpdate(Player* player, uint32 diff) override
    {
        Fabrication* fabrication = player->CustomData.Get<Fabrication>(CLE_FABRICATION);
        if (!fabrication || !fabrication->objet)
            return;
        if (!player->IsAlive() || player->isMoving() || player->GetExactDist(&fabrication->depart) > 0.5f)
        {
            ArreterFabrication(player, *fabrication, "ANNULE");
            ChatHandler(player->GetSession()).SendSysMessage("|cfff0918aFabrication annulée : il faut rester immobile.|r");
            return;
        }
        if (fabrication->reste > diff)
        {
            fabrication->reste -= diff;
            return;
        }
        uint32 objet = fabrication->objet;
        ArreterFabrication(player, *fabrication, "FINI");
        TerminerFabrication(player, objet);
    }
};

void AddSC_solazeroth_v3_equipement()
{
    new solazeroth_v3_equipement_joueur();
    new solazeroth_v3_equipement_monde();
    new solazeroth_v3_equipement_commandes();
}
