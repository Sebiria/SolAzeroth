// v3, E1 (31/10/2026) : fabriquer et améliorer l'équipement (document v3, § 2.4 et F8 ; fenêtre « Équipement »,
// SolUI_Equipement.lua). Données générées par outils\equipement_v3.py (migration 078).
// - Fabrication : nos recettes (solazeroth_v3_recettes et _composants), payées en composants de la Collection (puis du
//   sac) et en or. Maille, bouclier et armes demandent d'être près d'une enclume ou d'une forge (choix de l'utilisateur :
//   le cuir et le tissu n'avaient pas de prérequis à l'origine). Une recette s'ouvre à une puissance donnée.
// - Rangs : chaque pièce existe en 6 versions, de 0 à 5 (solazeroth_v3_rangs), +10 % de caractéristiques par rang.
//   Améliorer remplace l'objet par la version suivante, à la même place. Coût à Durotar : 5, 10, 20, 35 puis 60 éclats
//   cadavériques et 20 c, 40 c, 80 c, 1 pa 60, 3 pa 20 ; davantage au-delà de la puissance 12, comme les éclats
//   (v3_collection.cpp). Les rangs 4 et 5 demandent en plus des pierres taillées (solazeroth_v3_rangs_pierres).
// - Joaillerie (01/11/2026, demande de l'utilisateur ; outils\joaillerie_v3.py, migration 085) : .equipement prospecter
//   prend 5 Minerais de cuivre et range une gemme brute tirée au sort (solazeroth_v3_prospection) ; .equipement tailler
//   <pierre> prend 2 gemmes brutes et range la pierre taillée (solazeroth_v3_tailles).
// - Cuisine (31/10/2026) : les plats de v3_cuisine.cpp (solazeroth_v3_plats, migration 079), payés en ingrédients,
//   près d'un feu (le Feu de camp v3 compte), en 5 s.
// - Messages d'addon SOLEQUIP : « FORGE;forge 0|1;feu 0|1 », puis « DEBUT »,
//   « OBJ;sac;case;entrée;rang;éclats;or;éclats jusqu'au rang 4;or jusqu'au 4;éclats jusqu'au 5;or jusqu'au 5 » pour
//   chaque pièce améliorable (sac -1 : équipement porté, case 0 à 18 ; sac 0 à 4 : sacs du jeu, case à partir de 1) et
//   « FIN ». Les pierres des rangs 4 et 5 sont dans SolUI_Joaillerie.lua (liste de courses de l'interface).
// Commandes de l'interface : .equipement, .equipement fabriquer <objet>, .equipement ameliorer <sac> <case>.
// - Fabrication en 10 s (31/10/2026, demande de l'utilisateur) : animation du métier (marteler à la forge, travailler
//   debout sinon) et barre de progression de l'interface (« FABRIQUE;objet;secondes », puis « FINI » ou « ANNULE »).
//   Bouger annule ; composants et or ne sont pris qu'à la fin, après une nouvelle vérification.
// - Désenchantement et enchantement (31/10/2026, demande de l'utilisateur ; outils\enchantement_v3.py, migration 081) :
//   « PIECE;sac;case;entrée;InventoryType;enchantement;table de désenchantement » pour chaque armure et arme.
//   .equipement desenchanter <sac> <case> : une pièce du sac, verte ou mieux, donne le butin de sa table, rangé dans la
//   Collection. .equipement enchanter <sac> <case> <id> : un enchantement de solazeroth_v3_enchantements, payé en
//   composants et en or, remplace celui de la pièce. Améliorer une pièce garde son enchantement.
// - Audit du jeu, lot 4b (02/11/2026, C6 du consensus ; outils\fabrication_v3.py, migration 116) :
//   - une recette s'ouvre à la puissance de la pièce moins 2 (« fabrication limitée au secteur + 2 ») ;
//   - recettes hautes (solazeroth_v3_recettes_hautes) : la pièce la plus forte de chaque palier demande un composant de
//     plus, rare dans son secteur, sauf avec son plan, acheté une fois en or (.equipement plan <objet>, au personnage,
//     solazeroth_v3_plans). Interface : « HAUTE;objet;composant;nombre;prix du plan;plan possédé 0|1 » après « DEBUT » ;
//   - transfert de rang (choix de l'utilisateur : un rang de moins et une Braise du Gouffre) : .equipement transferer
//     <sac> <case> <sac> <case> pose sur la seconde pièce (même emplacement) le rang de la première moins un ; la
//     première revient au rang 0. Les pierres taillées des rangs 4 et 5 ne sont pas redemandées. Le champ 12 de « OBJ »
//     donne l'emplacement (InventoryType, la robe comptée comme un torse) pour l'aperçu de l'interface.
// - Audit du jeu, lot 4c (02/11/2026, choix de l'utilisateur ; sorts : outils\bonus_v3.py, migration 117 ; chiffres :
//   outils\simulation_lot4c.py) :
//   - variantes, choisies à la fabrication d'une pièce (.equipement fabriquer <objet> <1 Critique|2 Hâte|3 Vol de vie>),
//     gardées à l'amélioration et au transfert (solazeroth_v3_variantes, par objet) : par pièce portée, + 1 % de
//     critique, + 2 % de hâte ou 0,5 % de vol de vie (une aura à cumuls par variante). Champ 13 de « OBJ » : la variante ;
//   - panoplie du Gouffre (pièces bleues à Braise, rangs compris) : 2 pièces + 3 % de dégâts, 4 pièces − 5 % de dégâts
//     subis, 6 pièces 3 % de vol de vie. Recompté chaque seconde.

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
#include "Random.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "SpellAuras.h"
#include "StringFormat.h"
#include <algorithm>
#include <set>
#include <unordered_map>
#include <vector>

using namespace Acore::ChatCommands;

namespace
{
    char const* const PREFIXE = "SOLEQUIP";
    uint32 const ECLAT = 910120;
    uint8 const RANG_MAX = 5;
    uint32 const ECLATS_PAR_RANG[RANG_MAX] = { 15, 30, 60, 105, 180 };
    uint32 const OR_PAR_RANG[RANG_MAX] = { 60, 120, 240, 480, 960 };   // en cuivre ; x3 le 01/11/2026 (outils\simulation_rangs.py)
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

    std::unordered_map<uint8, std::vector<std::pair<uint32, uint32>>> pierresDuRang;   // rang -> (pierre, nombre)
    std::unordered_map<uint32, std::pair<uint32, uint32>> tailles;                    // pierre -> (brute, nombre)
    struct Prospection { uint32 minerai = 0, nombre = 0; std::vector<std::pair<uint32, uint32>> gemmes; };   // (gemme, %)
    Prospection prospection;

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

    uint8 VarianteDe(Item const* item);

    void EnvoyerPiece(Player* player, Item* item, int32 sac, uint32 caseInterface)
    {
        auto it = item ? rangs.find(item->GetEntry()) : rangs.end();
        if (it == rangs.end())
            return;
        uint8 rang = it->second.rang;
        uint32 niveau = item->GetTemplate()->ItemLevel;
        auto [eclats, prix] = rang < RANG_MAX ? Cout(niveau, rang + 1) : std::pair<uint32, uint32>{ 0, 0 };
        // Liste de courses : tout ce qu'il faut jusqu'au rang 4, puis jusqu'au rang 5.
        uint32 cumul[2][2] = {};
        for (uint8 vers = rang + 1; vers <= RANG_MAX; ++vers)
        {
            auto [e, o] = Cout(niveau, vers);
            for (uint8 cible = 4; cible <= 5; ++cible)
                if (vers <= cible)
                {
                    cumul[cible - 4][0] += e;
                    cumul[cible - 4][1] += o;
                }
        }
        SolAzeroth::EnvoyerAddon(player, PREFIXE, Acore::StringFormat("OBJ;{};{};{};{};{};{};{};{};{};{};{};{}", sac,
            caseInterface, item->GetEntry(), rang, eclats, prix, cumul[0][0], cumul[0][1], cumul[1][0], cumul[1][1],
            uint32(item->GetTemplate()->InventoryType == INVTYPE_ROBE ? INVTYPE_CHEST : item->GetTemplate()->InventoryType),
            uint32(VarianteDe(item))));
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

    void EnvoyerHautes(Player* player);

    void Envoyer(Player* player)
    {
        SolAzeroth::EnvoyerAddon(player, PREFIXE, Acore::StringFormat("FORGE;{};{}", PresDUneForge(player) ? 1 : 0,
            PresDUnFeu(player) ? 1 : 0));
        SolAzeroth::EnvoyerAddon(player, PREFIXE, "DEBUT");
        EnvoyerHautes(player);
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

    // Lot 4b : recettes hautes et plans.
    struct Haute { uint32 composant = 0, nombre = 0, plan = 0; };
    std::unordered_map<uint32, Haute> hautes;
    uint32 const BRAISE = 910190;

    // Lot 4c : variantes et panoplie du Gouffre (outils\bonus_v3.py).
    uint32 const PANOPLIE_2 = 101600, PANOPLIE_4 = 101601, PANOPLIE_6 = 101602;
    uint32 const SORTS_VARIANTES[] = { 0, 101603, 101604, 101605 };   // Critique, Hâte, Vol de vie
    uint8 const VARIANTES = 3;
    uint32 const GOUFFRE_PREMIERE = 910241, GOUFFRE_DERNIERE = 910271;
    float const VOL_PAR_PIECE = 0.005f, VOL_PANOPLIE = 0.03f;
    uint32 const RECOMPTE = 1000;
    std::unordered_map<uint32, uint8> variantes;   // objet (guid) -> variante

    uint8 VarianteDe(Item const* item)
    {
        auto it = variantes.find(item->GetGUID().GetCounter());
        return it == variantes.end() ? 0 : it->second;
    }

    void FixerVariante(uint32 item, uint8 variante)
    {
        if (variante)
        {
            variantes[item] = variante;
            CharacterDatabase.Execute("REPLACE INTO solazeroth_v3_variantes (item, variante) VALUES ({}, {})", item, variante);
        }
        else if (variantes.erase(item))
            CharacterDatabase.Execute("DELETE FROM solazeroth_v3_variantes WHERE item = {}", item);
    }

    // Cumuls d'une aura : n (0 la retire).
    void Cumuls(Player* player, uint32 sort, uint8 n)
    {
        Aura* aura = player->GetAura(sort);
        if (!n)
        {
            if (aura)
                player->RemoveAurasDueToSpell(sort);
            return;
        }
        if (!aura)
            aura = player->AddAura(sort, player);
        if (aura && aura->GetStackAmount() != n)
            aura->SetStackAmount(n);
    }

    // Pièces portées : panoplie du Gouffre et variantes.
    void Recompter(Player* player)
    {
        uint8 gouffre = 0, parVariante[VARIANTES + 1] = {};
        for (uint8 slot = EQUIPMENT_SLOT_START; slot < EQUIPMENT_SLOT_END; ++slot)
        {
            Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot);
            auto it = item ? rangs.find(item->GetEntry()) : rangs.end();
            if (it == rangs.end())
                continue;
            if (it->second.base >= GOUFFRE_PREMIERE && it->second.base <= GOUFFRE_DERNIERE)
                ++gouffre;
            ++parVariante[VarianteDe(item)];
        }
        bool vivant = player->IsAlive();
        Cumuls(player, PANOPLIE_2, vivant && gouffre >= 2 ? 1 : 0);
        Cumuls(player, PANOPLIE_4, vivant && gouffre >= 4 ? 1 : 0);
        Cumuls(player, PANOPLIE_6, vivant && gouffre >= 6 ? 1 : 0);
        for (uint8 v = 1; v <= VARIANTES; ++v)
            Cumuls(player, SORTS_VARIANTES[v], vivant ? parVariante[v] : 0);
    }

    struct Plans : DataMap::Base
    {
        std::set<uint32> objets;
        bool lus = false;
    };

    Plans* PlansDe(Player* player)
    {
        Plans* plans = player->CustomData.GetDefault<Plans>("solazeroth_v3_plans");
        if (!plans->lus)
        {
            plans->lus = true;
            if (QueryResult r = CharacterDatabase.Query("SELECT objet FROM solazeroth_v3_plans WHERE guid = {}",
                player->GetGUID().GetCounter()))
            {
                do
                    plans->objets.insert((*r)[0].Get<uint32>());
                while (r->NextRow());
            }
        }
        return plans;
    }

    void EnvoyerHautes(Player* player)
    {
        for (auto const& [objet, h] : hautes)
            SolAzeroth::EnvoyerAddon(player, PREFIXE, Acore::StringFormat("HAUTE;{};{};{};{};{}", objet, h.composant,
                h.nombre, h.plan, PlansDe(player)->objets.count(objet) ? 1 : 0));
    }

    // Composant de plus d'une recette haute ; aucun avec son plan.
    Haute const* HauteSansPlan(Player* player, uint32 objet)
    {
        auto it = hautes.find(objet);
        return it == hautes.end() || PlansDe(player)->objets.count(objet) ? nullptr : &it->second;
    }

    uint8 Emplacement(ItemTemplate const* modele)
    {
        return modele->InventoryType == INVTYPE_ROBE ? uint8(INVTYPE_CHEST) : uint8(modele->InventoryType);
    }

    bool Porte(uint8 bag, uint8 slot)
    {
        return bag == INVENTORY_SLOT_BAG_0 && slot < EQUIPMENT_SLOT_END;
    }

    bool PeutRemplacer(Player* player, uint8 bag, uint8 slot, uint32 entree)
    {
        uint16 dest = 0;
        return !Porte(bag, slot) || player->CanEquipNewItem(slot, dest, entree, true) == EQUIP_ERR_OK;
    }

    // Remplace une pièce par une autre de ses versions, à la même place, en gardant son enchantement (amélioration,
    // transfert). Vérifier PeutRemplacer avant.
    Item* Remplacer(Player* player, uint8 bag, uint8 slot, Item* item, uint32 entree)
    {
        uint16 destPorte = 0;
        bool porte = Porte(bag, slot) && player->CanEquipNewItem(slot, destPorte, entree, true) == EQUIP_ERR_OK;
        uint32 enchantement = item->GetEnchantmentId(PERM_ENCHANTMENT_SLOT);
        uint8 variante = VarianteDe(item);
        FixerVariante(item->GetGUID().GetCounter(), 0);
        player->DestroyItem(bag, slot, true);
        Item* nouveau = nullptr;
        if (porte)
            nouveau = player->EquipNewItem(destPorte, entree, true);
        else
        {
            ItemPosCountVec dest;
            if (player->CanStoreNewItem(bag, slot, dest, entree, 1) == EQUIP_ERR_OK
                || player->CanStoreNewItem(NULL_BAG, NULL_SLOT, dest, entree, 1) == EQUIP_ERR_OK)
                nouveau = player->StoreNewItem(dest, entree, true);
        }
        if (nouveau && enchantement)
            Enchanter(player, nouveau, enchantement);
        if (nouveau)
            FixerVariante(nouveau->GetGUID().GetCounter(), variante);
        else
            LOG_ERROR("module", "Sol'Azeroth v3 : version {} perdue pour {}", entree, player->GetName());
        return nouveau;
    }

    uint32 const DUREE_FABRICATION = 10000, DUREE_CUISINE = 5000;
    char const* const CLE_FABRICATION = "solazeroth_v3_fabrication";

    struct Fabrication : DataMap::Base
    {
        uint32 objet = 0;   // 0 : aucune fabrication en cours
        uint32 reste = 0;
        uint8 variante = 0;   // lot 4c
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
        if (Haute const* h = HauteSansPlan(player, objet); h && Possede(player, h->composant) < h->nombre)
        {
            chat.SendErrorMessage("Recette haute : il faut aussi {} × {}, ou son plan.", h->nombre, Nom(h->composant));
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

    void TerminerFabrication(Player* player, uint32 objet, uint8 variante)
    {
        ChatHandler chat(player->GetSession());
        ItemPosCountVec dest;
        if (!PeutFabriquer(player, objet, chat, dest))
            return;
        Recette const& recette = recettes.at(objet);
        for (auto const& [composant, nombre] : recette.composants)
            Prendre(player, composant, nombre);
        if (Haute const* h = HauteSansPlan(player, objet))
            Prendre(player, h->composant, h->nombre);
        player->ModifyMoney(-int32(recette.prix));
        if (Item* item = player->StoreNewItem(dest, objet, true))
        {
            player->SendNewItem(item, 1, false, true);
            if (rangs.count(objet))
                FixerVariante(item->GetGUID().GetCounter(), variante);
        }
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
        variantes.clear();
        if (QueryResult r = CharacterDatabase.Query("SELECT item, variante FROM solazeroth_v3_variantes"))
        {
            do
                variantes[(*r)[0].Get<uint32>()] = (*r)[1].Get<uint8>();
            while (r->NextRow());
        }
        hautes.clear();
        if (QueryResult r = WorldDatabase.Query("SELECT objet, composant, nombre, plan FROM solazeroth_v3_recettes_hautes"))
        {
            do
                hautes[(*r)[0].Get<uint32>()] = { (*r)[1].Get<uint32>(), (*r)[2].Get<uint32>(), (*r)[3].Get<uint32>() };
            while (r->NextRow());
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
        pierresDuRang.clear();
        tailles.clear();
        prospection = Prospection();
        if (QueryResult r = WorldDatabase.Query("SELECT rang, pierre, nombre FROM solazeroth_v3_rangs_pierres"))
        {
            do
                pierresDuRang[(*r)[0].Get<uint8>()].emplace_back((*r)[1].Get<uint32>(), (*r)[2].Get<uint32>());
            while (r->NextRow());
        }
        if (QueryResult r = WorldDatabase.Query("SELECT pierre, brute, nombre FROM solazeroth_v3_tailles"))
        {
            do
                tailles[(*r)[0].Get<uint32>()] = { (*r)[1].Get<uint32>(), (*r)[2].Get<uint32>() };
            while (r->NextRow());
        }
        if (QueryResult r = WorldDatabase.Query("SELECT minerai, nombre, gemme, chance FROM solazeroth_v3_prospection "
            "ORDER BY chance DESC"))
        {
            do
            {
                prospection.minerai = (*r)[0].Get<uint32>();
                prospection.nombre = (*r)[1].Get<uint32>();
                prospection.gemmes.emplace_back((*r)[2].Get<uint32>(), (*r)[3].Get<uint32>());
            } while (r->NextRow());
        }
        LOG_INFO("module", ">> Sol'Azeroth v3 : {} recettes, {} versions d'équipement par rang, {} enchantements, "
            "{} pierres taillées", recettes.size(), rangs.size(), enchantements.size(), tailles.size());
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
            { "prospecter", HandleProspecter, SEC_PLAYER, Console::No },
            { "tailler",   HandleTailler,   SEC_PLAYER, Console::No },
            { "plan",      HandlePlan,      SEC_PLAYER, Console::No },
            { "transferer", HandleTransferer, SEC_PLAYER, Console::No },
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

    static bool HandleFabriquer(ChatHandler* handler, uint32 objet, Optional<uint8> variante)
    {
        if (variante && *variante > VARIANTES)
        {
            handler->SendErrorMessage("Variante : 1 Critique, 2 Hâte, 3 Vol de vie.");
            return false;
        }
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
        fabrication->variante = variante.value_or(0);
        fabrication->reste = recette.feu ? DUREE_CUISINE : DUREE_FABRICATION;
        fabrication->depart = player->GetPosition();
        // Assis au coin du feu, on cuisine sans se lever (se lever éteindrait le Feu de camp).
        if (!player->IsSitState())
            player->SetUInt32Value(UNIT_NPC_EMOTESTATE, recette.forge ? EMOTE_STATE_WORK_MINING : EMOTE_STATE_USE_STANDING);
        SolAzeroth::EnvoyerAddon(player, PREFIXE, Acore::StringFormat("FABRIQUE;{};{}", objet, fabrication->reste / 1000));
        return true;
    }

    // .equipement prospecter : 5 Minerais de cuivre -> une gemme brute, rangée dans la Collection.
    static bool HandleProspecter(ChatHandler* handler)
    {
        Player* player = handler->GetPlayer();
        if (!prospection.minerai || prospection.gemmes.empty())
            return false;
        if (Possede(player, prospection.minerai) < prospection.nombre)
        {
            handler->SendErrorMessage("Il faut {} × {} pour prospecter (tu en as {}).", prospection.nombre,
                Nom(prospection.minerai), Possede(player, prospection.minerai));
            return false;
        }
        Prendre(player, prospection.minerai, prospection.nombre);
        uint32 tirage = urand(1, 100), cumul = 0, gemme = prospection.gemmes.back().first;
        for (auto const& [g, chance] : prospection.gemmes)
            if (tirage <= (cumul += chance))
            {
                gemme = g;
                break;
            }
        SolAzeroth::AjouterACollection(player, gemme, 1);
        handler->SendSysMessage(Acore::StringFormat("|cff8cc4a6Prospection :|r {}.", Nom(gemme)));
        Envoyer(player);
        return true;
    }

    // .equipement tailler <pierre> : 2 gemmes brutes -> la pierre taillée, rangée dans la Collection.
    static bool HandleTailler(ChatHandler* handler, uint32 pierre)
    {
        Player* player = handler->GetPlayer();
        auto it = tailles.find(pierre);
        if (it == tailles.end())
        {
            handler->SendErrorMessage("Cette pierre ne se taille pas.");
            return false;
        }
        auto [brute, nombre] = it->second;
        if (Possede(player, brute) < nombre)
        {
            handler->SendErrorMessage("Il faut {} × {} (tu en as {}).", nombre, Nom(brute), Possede(player, brute));
            return false;
        }
        Prendre(player, brute, nombre);
        SolAzeroth::AjouterACollection(player, pierre, 1);
        handler->SendSysMessage(Acore::StringFormat("|cff8cc4a6Taille :|r {}.", Nom(pierre)));
        Envoyer(player);
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
        auto const& pierres = pierresDuRang[actuel.rang + 1];
        for (auto const& [pierre, nombre] : pierres)
            if (Possede(player, pierre) < nombre)
            {
                handler->SendErrorMessage("Il manque {} × {} (joaillerie).", nombre - Possede(player, pierre), Nom(pierre));
                return false;
            }
        if (!PeutRemplacer(player, bag, slot, suivant))
        {
            handler->SendErrorMessage("Impossible de porter la nouvelle version.");
            return false;
        }
        Prendre(player, ECLAT, eclats);
        for (auto const& [pierre, nombre] : pierres)
            Prendre(player, pierre, nombre);
        player->ModifyMoney(-int32(prix));
        if (Remplacer(player, bag, slot, item, suivant))
            ChatHandler(player->GetSession()).SendSysMessage(Acore::StringFormat("|cff8cc4a6Amélioration :|r {} passe au rang {}.",
                Nom(actuel.base), actuel.rang + 1));
        Envoyer(player);
        return true;
    }

    // Lot 4b : .equipement plan <objet> : la recette haute se fabrique sans son composant de plus.
    static bool HandlePlan(ChatHandler* handler, uint32 objet)
    {
        Player* player = handler->GetPlayer();
        auto it = hautes.find(objet);
        if (it == hautes.end())
        {
            handler->SendErrorMessage("Cette recette n'a pas de plan.");
            return false;
        }
        Plans* plans = PlansDe(player);
        if (plans->objets.count(objet))
        {
            handler->SendErrorMessage("Tu as déjà ce plan.");
            return false;
        }
        if (!player->HasEnoughMoney(it->second.plan))
        {
            handler->SendErrorMessage("Pas assez d'or.");
            return false;
        }
        player->ModifyMoney(-int32(it->second.plan));
        plans->objets.insert(objet);
        CharacterDatabase.Execute("INSERT IGNORE INTO solazeroth_v3_plans (guid, objet) VALUES ({}, {})",
            player->GetGUID().GetCounter(), objet);
        handler->SendSysMessage(Acore::StringFormat("|cff8cc4a6Plan appris :|r {} se fabrique sans {}.", Nom(objet),
            Nom(it->second.composant)));
        Envoyer(player);
        return true;
    }

    // Lot 4b : .equipement transferer <sac> <case> <sac> <case> : le rang de la première pièce, moins un, passe sur la
    // seconde (même emplacement) ; la première revient au rang 0. Coût : une Braise du Gouffre.
    static bool HandleTransferer(ChatHandler* handler, int32 sacSource, uint32 caseSource, int32 sacCible, uint32 caseCible)
    {
        Player* player = handler->GetPlayer();
        uint8 bagS, slotS, bagC, slotC;
        Item* source = PositionDuJeu(sacSource, caseSource, bagS, slotS) ? player->GetItemByPos(bagS, slotS) : nullptr;
        Item* cible = PositionDuJeu(sacCible, caseCible, bagC, slotC) ? player->GetItemByPos(bagC, slotC) : nullptr;
        auto is = source ? rangs.find(source->GetEntry()) : rangs.end();
        auto ic = cible ? rangs.find(cible->GetEntry()) : rangs.end();
        if (is == rangs.end() || ic == rangs.end() || source == cible)
        {
            handler->SendErrorMessage("Choisis deux pièces améliorables.");
            return false;
        }
        if (Emplacement(source->GetTemplate()) != Emplacement(cible->GetTemplate()))
        {
            handler->SendErrorMessage("Les deux pièces doivent aller au même emplacement.");
            return false;
        }
        if (is->second.rang < 2)
        {
            handler->SendErrorMessage("La pièce d'origine doit être au moins au rang 2.");
            return false;
        }
        uint8 rang = is->second.rang - 1;
        if (ic->second.rang >= rang)
        {
            handler->SendErrorMessage("La nouvelle pièce est déjà au rang {} ou mieux.", rang);
            return false;
        }
        if (player->IsInCombat())
        {
            handler->SendErrorMessage("Pas pendant un combat.");
            return false;
        }
        if (Possede(player, BRAISE) < 1)
        {
            handler->SendErrorMessage("Il faut une Braise du Gouffre.");
            return false;
        }
        uint32 versionCible = Version(ic->second.base, rang), versionSource = Version(is->second.base, 0);
        if (!versionCible || !versionSource || !PeutRemplacer(player, bagC, slotC, versionCible)
            || !PeutRemplacer(player, bagS, slotS, versionSource))
        {
            handler->SendErrorMessage("Impossible de porter la nouvelle version.");
            return false;
        }
        Prendre(player, BRAISE, 1);
        Remplacer(player, bagC, slotC, cible, versionCible);
        Remplacer(player, bagS, slotS, source, versionSource);
        handler->SendSysMessage(Acore::StringFormat("|cff8cc4a6Transfert :|r {} passe au rang {} ; {} revient au rang 0.",
            Nom(ic->second.base), rang, Nom(is->second.base)));
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
    solazeroth_v3_equipement_joueur() : PlayerScript("solazeroth_v3_equipement_joueur", { PLAYERHOOK_ON_UPDATE,
        PLAYERHOOK_ON_DELETE }) { }

    struct Recompte : DataMap::Base
    {
        uint32 attente = 0;
    };

    void OnPlayerDelete(ObjectGuid guid, uint32 /*compte*/) override
    {
        CharacterDatabase.Execute("DELETE FROM solazeroth_v3_plans WHERE guid = {}", guid.GetCounter());
    }

    void OnPlayerUpdate(Player* player, uint32 diff) override
    {
        Recompte* recompte = player->CustomData.GetDefault<Recompte>("solazeroth_v3_recompte");
        if (recompte->attente > diff)
            recompte->attente -= diff;
        else
        {
            recompte->attente = RECOMPTE;
            Recompter(player);
        }
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
        uint8 variante = fabrication->variante;
        ArreterFabrication(player, *fabrication, "FINI");
        TerminerFabrication(player, objet, variante);
    }
};

// Lot 4c : vol de vie de la variante et du palier 6 de la panoplie du Gouffre.
class solazeroth_v3_equipement_unites : public UnitScript
{
public:
    solazeroth_v3_equipement_unites() : UnitScript("solazeroth_v3_equipement_unites", true, { UNITHOOK_ON_DAMAGE }) { }

    void OnDamage(Unit* attaquant, Unit* victime, uint32& degats) override
    {
        Player* player = attaquant ? attaquant->ToPlayer() : nullptr;
        if (!player || !victime || !victime->ToCreature() || !degats || !player->IsAlive())
            return;
        float part = 0.0f;
        if (Aura const* aura = player->GetAura(SORTS_VARIANTES[3]))
            part += VOL_PAR_PIECE * aura->GetStackAmount();
        if (player->HasAura(PANOPLIE_6))
            part += VOL_PANOPLIE;
        if (part > 0.0f)
            player->ModifyHealth(int32(std::min(degats, victime->GetHealth()) * part));
    }
};

void AddSC_solazeroth_v3_equipement()
{
    new solazeroth_v3_equipement_unites();
    new solazeroth_v3_equipement_joueur();
    new solazeroth_v3_equipement_monde();
    new solazeroth_v3_equipement_commandes();
}
