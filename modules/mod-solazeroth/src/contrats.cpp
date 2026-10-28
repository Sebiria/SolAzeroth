// Tableau de contrats (section 6.1, V3) : chasse, donjon imposé, prime de zone et commande d'artisan.
// - Réserve par compte : 3 contrats par jour (bascule à 6 h, heure locale), 9 au plus. Accepter en coûte un.
// - Le joueur choisit son contrat dans des listes à son niveau (demande de l'utilisateur, plutôt qu'un tirage au sort).
//   Au plus 3 contrats en cours par personnage ; abandonner ne rend rien.
// - Chasse : tuer N monstres d'une famille dans une zone où cette famille est à son niveau (creature.zoneId).
// - Donjon imposé : finir un donjon de son niveau au rang de menace minimal indiqué (signalé par menace.cpp).
// - Prime de zone : tuer un rare, un élite rare ou un élite nommé (3 apparitions au plus) de son niveau, plus N monstres
//   hostiles de la même zone. Si la cible est morte quand le joueur arrive dans la zone, elle réapparaît.
// - Commande d'artisan : fabriquer et livrer N objets d'une recette connue qui n'est pas grise à sa compétence
//   (2 objets, ou 5 s'ils s'empilent). La livraison retire les objets des sacs.
// - Récompense (provisoire, mod_solazeroth.conf) : Marques, or selon le niveau, chance d'un objet de l'intendant au rang 3.
// - Thème de la semaine (V5, migration 040) : une famille de monstres et un métier, pris tour à tour dans
//   solazeroth_themes. Les contrats qui collent au thème (chasse ou prime sur cette famille, donjon peuplé surtout de
//   cette famille, commande de ce métier) passent en tête de liste et rapportent +50 % de Marques (provisoire).
//   Le thème est retenu quand on accepte le contrat : il compte encore si la semaine change avant la fin.
// Addon SolAzerothContrats (préfixe SOLCONTRAT) : « ETAT;charges;max;secondes_avant_recharge;marques;cuivre »,
// puis « THEME;nom;famille;métier;description;bonus_% » (s'il y a des thèmes),
// puis « CH;zone;famille;nom_zone;monstres;thème », « DJ;donjon;nom;rang_min;thème » et
// « PR;entrée;nom;classement;niveau;nom_zone;x:y,x:y;thème » (coordonnées de carte de zone, 0 à 100) et
// « AR;sort;objet;nombre;métier;thème » (choix possibles ; thème = 1 s'il colle au thème de la semaine),
// puis « C;slot;type;cible;nom;détail;objectif;progression;cible_tuée;nom_cible;x:y,…;largeur;hauteur;thème » (contrats en cours ; taille de la zone en mètres pour la minicarte), puis « FIN ».
// En cours de chasse : « P;slot;progression;objectif ».

#include "SolAzeroth.h"
#include "Chat.h"
#include "Config.h"
#include "Creature.h"
#include "DatabaseEnv.h"
#include "DBCStores.h"
#include "Formulas.h"
#include "GameTime.h"
#include "Map.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "Random.h"
#include "ScriptMgr.h"
#include "SpellInfo.h"
#include "SpellMgr.h"
#include "StringFormat.h"
#include "Timer.h"
#include "World.h"
#include "WorldSession.h"
#include <algorithm>
#include <array>
#include <cmath>
#include <ctime>
#include <map>
#include <unordered_map>
#include <vector>

using namespace Acore::ChatCommands;

namespace
{
    char const* const PREFIXE = "SOLCONTRAT";
    uint8 const EMPLACEMENTS = 3;

    enum TypeContrat : uint8 { AUCUN = 0, CHASSE = 1, DONJON = 2, PRIME = 3, ARTISAN = 4 };

    // Métiers de fabrication : alchimie, forge, enchantement, ingénierie, joaillerie, travail du cuir, couture,
    // calligraphie, cuisine, secourisme.
    std::array<uint32, 10> const METIERS_ARTISAN = { 171, 164, 333, 202, 755, 165, 197, 773, 185, 129 };

    struct Recette { uint32 sort; uint32 objet; uint16 nombre; uint32 metier; };

    // Recettes enseignées par les maîtres de métier (pas celles des marchands ni du butin) : sort -> compétence demandée.
    std::unordered_map<uint32, uint32> recettesDeMaitre;

    uint32 CompetenceMinimale(uint8 niveau);

    // Recettes connues du personnage, apprises chez un maître, qui fabriquent un objet, ne sont pas grises à sa
    // compétence et demandent au moins la compétence attendue à son niveau (pas de commandes de bas niveau).
    std::vector<Recette> RecettesArtisan(Player* player)
    {
        std::vector<Recette> recettes;
        uint32 minimum = CompetenceMinimale(player->GetLevel());
        for (auto const& [sort, info] : player->GetSpellMap())
        {
            if (info->State == PLAYERSPELL_REMOVED || !info->Active)
                continue;
            SpellInfo const* sortInfo = sSpellMgr->GetSpellInfo(sort);
            if (!sortInfo)
                continue;
            auto maitre = recettesDeMaitre.find(sort);
            if (maitre == recettesDeMaitre.end() || maitre->second < minimum)
                continue;
            uint32 objet = 0;
            for (SpellEffectInfo const& effet : sortInfo->GetEffects())
                if (effet.IsEffect(SPELL_EFFECT_CREATE_ITEM) && effet.ItemType)
                    objet = effet.ItemType;
            ItemTemplate const* modele = objet ? sObjectMgr->GetItemTemplate(objet) : nullptr;
            if (!modele)
                continue;
            SkillLineAbilityMapBounds bornes = sSpellMgr->GetSkillLineAbilityMapBounds(sort);
            for (auto it = bornes.first; it != bornes.second; ++it)
            {
                uint32 metier = it->second->SkillLine;
                if (std::find(METIERS_ARTISAN.begin(), METIERS_ARTISAN.end(), metier) == METIERS_ARTISAN.end())
                    continue;
                if (it->second->TrivialSkillLineRankHigh && player->GetBaseSkillValue(metier) >= it->second->TrivialSkillLineRankHigh)
                    continue;
                recettes.push_back({ sort, objet, uint16(modele->GetMaxStackSize() > 1 ? 5 : 2), metier });
                break;
            }
        }
        return recettes;
    }

    struct Reglages
    {
        uint32 parJour = 3;
        uint32 reserveMax = 9;
        uint32 marques = 15;
        uint32 orFacteur = 50;          // cuivre × niveau²
        uint32 chanceObjet = 25;        // %
        uint32 chasseMin = 15;
        uint32 chasseMax = 25;
        uint32 primeMin = 8;            // monstres de la zone en plus de la cible
        uint32 primeMax = 12;
        uint32 artisanEcart = 5;        // compétence attendue = (niveau − écart) × par niveau
        uint32 artisanParNiveau = 5;
        float bonusTheme = 0.5f;        // Marques en plus pour un contrat du thème de la semaine
    } reglages;

    // Thèmes de la semaine (solazeroth_themes), dans l'ordre de la rotation.
    struct Theme { std::string nom; uint8 famille; uint32 metier; std::string description; };
    std::vector<Theme> themes;

    // Même découpage des semaines que l'affixe de la semaine (menace.cpp).
    Theme const* ThemeDeLaSemaine()
    {
        if (themes.empty())
            return nullptr;
        return &themes[(GameTime::GetGameTime().count() / WEEK) % themes.size()];
    }

    // Famille la plus nombreuse parmi les monstres hostiles de chaque carte de donjon.
    std::unordered_map<uint32, uint8> familleDonjon;

    // Métier de fabrication d'une recette (0 si aucun).
    uint32 MetierDuSort(uint32 sort)
    {
        SkillLineAbilityMapBounds bornes = sSpellMgr->GetSkillLineAbilityMapBounds(sort);
        for (auto it = bornes.first; it != bornes.second; ++it)
            if (std::find(METIERS_ARTISAN.begin(), METIERS_ARTISAN.end(), it->second->SkillLine) != METIERS_ARTISAN.end())
                return it->second->SkillLine;
        return 0;
    }

    uint32 CompetenceMinimale(uint8 niveau)
    {
        return niveau > reglages.artisanEcart ? (niveau - reglages.artisanEcart) * reglages.artisanParNiveau : 0;
    }

    // Prime de zone : cibles nommées du monde extérieur et leurs points d'apparition.
    struct Apparition { ObjectGuid::LowType spawnId; uint32 map; float carteX; float carteY; };
    struct Cible
    {
        uint32 entree;
        uint8 classement;     // 1 élite, 2 élite rare, 4 rare
        uint8 famille;
        uint8 min, max;
        uint32 zone;
        std::string nom;
        std::vector<Apparition> apparitions;
    };
    std::map<uint32, Cible> cibles;

    // Chasse : pour chaque (zone, famille), les groupes de monstres hostiles apparus (niveaux, nombre).
    struct Groupe { uint8 min; uint8 max; uint32 nombre; };
    std::map<std::pair<uint32, uint32>, std::vector<Groupe>> chasses;

    // Donjons dont le dernier boss valide la réussite (identifiants LFGDungeons, mode normal).
    std::vector<LFGDungeonEntry const*> donjons;

    struct Contrat
    {
        uint8 type = AUCUN;
        uint32 cible = 0;
        uint32 detail = 0;
        uint16 objectif = 0;
        uint16 progression = 0;
        uint8 niveau = 1;
        bool cibleTuee = false;
        bool theme = false;   // pris au thème de la semaine
    };

    struct Donnees : DataMap::Base
    {
        std::array<Contrat, EMPLACEMENTS> contrats;
        uint32 attente = 0;                              // minuterie de la vérification des cibles de prime
        std::array<bool, EMPLACEMENTS> reveillee = {};   // cible déjà vérifiée lors de ce passage dans la zone
    };

    Donnees* DonneesDe(Player* player)
    {
        return player->CustomData.GetDefault<Donnees>("solazeroth_contrats");
    }

    // Jour local qui bascule à 6 h.
    uint32 Jour(time_t maintenant)
    {
        std::tm t = Acore::Time::TimeBreakdown(maintenant - 6 * HOUR);
        t.tm_hour = 12; t.tm_min = 0; t.tm_sec = 0;
        return uint32(std::mktime(&t) / DAY);
    }

    uint32 SecondesAvantRecharge(time_t maintenant)
    {
        std::tm t = Acore::Time::TimeBreakdown(maintenant - 6 * HOUR);
        return DAY - (t.tm_hour * HOUR + t.tm_min * MINUTE + t.tm_sec);
    }

    // Récompenses du Renom (section 7.2) : réserve de 3 contrats de plus au rang 3, 1 contrat de plus par jour au rang 6.
    uint32 ReserveMax(uint32 compte) { return reglages.reserveMax + (SolAzeroth::RangRenom(compte) >= 3 ? 3 : 0); }
    uint32 ParJour(uint32 compte) { return reglages.parJour + (SolAzeroth::RangRenom(compte) >= 6 ? 1 : 0); }

    // Charges du compte, après les recharges des jours écoulés.
    uint32 Charges(uint32 compte)
    {
        uint32 aujourdhui = Jour(time(nullptr));
        QueryResult r = CharacterDatabase.Query("SELECT charges, jour FROM solazeroth_contrats_reserve WHERE account = {}", compte);
        uint32 charges = ParJour(compte), jour = aujourdhui;
        if (r)
        {
            charges = (*r)[0].Get<uint32>();
            jour = (*r)[1].Get<uint32>();
            if (aujourdhui > jour)
                charges = std::min<uint32>(ReserveMax(compte), charges + ParJour(compte) * (aujourdhui - jour));
        }
        if (!r || aujourdhui > jour)
            CharacterDatabase.DirectExecute("REPLACE INTO solazeroth_contrats_reserve (account, charges, jour) VALUES ({}, {}, {})",
                compte, charges, aujourdhui);
        return charges;
    }

    std::string Nom(char const* const* noms)
    {
        std::string nom = noms[sWorld->GetDefaultDbcLocale()];
        if (nom.empty())
            nom = noms[0];
        nom.erase(std::remove(nom.begin(), nom.end(), ';'), nom.end());
        return nom;
    }

    std::string NomZone(uint32 zone)
    {
        AreaTableEntry const* z = sAreaTableStore.LookupEntry(zone);
        return z ? Nom(z->area_name) : "?";
    }

    std::string NomCible(Contrat const& c)
    {
        if (c.type == CHASSE || c.type == PRIME)
            return NomZone(c.cible);
        if (c.type == DONJON)
            if (LFGDungeonEntry const* donjon = sLFGDungeonStore.LookupEntry(c.cible))
                return Nom(donjon->Name);
        if (c.type == ARTISAN)
            if (ItemTemplate const* modele = sObjectMgr->GetItemTemplate(c.cible))
            {
                std::string nom = modele->Name1;
                if (ItemLocale const* traduction = sObjectMgr->GetItemLocale(c.cible))
                    ObjectMgr::GetLocaleString(traduction->Name, sWorld->GetDefaultDbcLocale(), nom);
                nom.erase(std::remove(nom.begin(), nom.end(), ';'), nom.end());
                return nom;
            }
        return "?";
    }

    uint32 RecompenseOr(uint8 niveau) { return reglages.orFacteur * niveau * niveau; }

    // Monstres d'une (zone, famille) dont toute la plage de niveau est proche du niveau du joueur.
    // (Un monstre « niveau 1 à 70 », comme les esprits draeneï de Terokkar, ne compte pas.)
    uint32 MonstresANiveau(std::vector<Groupe> const& groupes, uint8 niveau)
    {
        uint32 total = 0;
        for (Groupe const& g : groupes)
            if (g.min + 4 >= niveau && g.max <= niveau + 3)
                total += g.nombre;
        return total;
    }

    bool ChasseDisponible(uint8 niveau, uint32 zone, uint32 famille)
    {
        auto it = chasses.find({ zone, famille });
        return it != chasses.end() && MonstresANiveau(it->second, niveau) >= 20;
    }

    bool DonjonDisponible(uint8 niveau, LFGDungeonEntry const* d)
    {
        return d->MinLevel <= niveau && niveau <= d->MaxLevel;
    }

    bool CibleDisponible(uint8 niveau, Cible const& c)
    {
        return c.min + 4 >= niveau && c.max <= niveau + 3;
    }

    std::string Coordonnees(Cible const& c)
    {
        std::string texte;
        for (Apparition const& a : c.apparitions)
            texte += (texte.empty() ? "" : ",") + Acore::StringFormat("{:.0f}:{:.0f}", a.carteX, a.carteY);
        return texte;
    }

    // Taille de la carte de zone en mètres (« yards »), en largeur puis en hauteur : le client ne la connaît pas, et
    // l'addon en a besoin pour placer le crâne de la prime sur la minicarte. La table des cartes n'est pas exportée : on
    // convertit les coins 0 % et 100 % de la carte en coordonnées du monde (axes inversés, comme dans Map2ZoneCoordinates).
    std::string Dimensions(uint32 zone)
    {
        float x0 = 0.0f, y0 = 0.0f, x1 = 100.0f, y1 = 100.0f;
        Zone2MapCoordinates(x0, y0, zone);
        Zone2MapCoordinates(x1, y1, zone);
        if (x0 == 0.0f && y0 == 0.0f && x1 == 100.0f && y1 == 100.0f)   // zone sans carte
            return "0;0";
        return Acore::StringFormat("{:.0f};{:.0f}", std::fabs(y1 - y0), std::fabs(x1 - x0));
    }

    uint8 RangMinimal(Player* player)
    {
        uint8 debloque = SolAzeroth::RangMenaceDebloque(player->GetSession()->GetAccountId());
        return debloque > 0 ? debloque - 1 : 0;
    }

    void Sauver(Player* player, uint8 slot)
    {
        Contrat const& c = DonneesDe(player)->contrats[slot];
        if (c.type == AUCUN)
        {
            CharacterDatabase.DirectExecute("DELETE FROM solazeroth_contrats WHERE guid = {} AND slot = {}", player->GetGUID().GetCounter(), slot + 1);
            return;
        }
        CharacterDatabase.DirectExecute("REPLACE INTO solazeroth_contrats (guid, slot, type, cible, detail, objectif, progression, actif, niveau, cible_tuee, theme) "
            "VALUES ({}, {}, {}, {}, {}, {}, {}, 1, {}, {}, {})", player->GetGUID().GetCounter(), slot + 1, c.type, c.cible, c.detail,
            c.objectif, c.progression, c.niveau, c.cibleTuee ? 1 : 0, c.theme ? 1 : 0);
    }

    // Seuls les contrats acceptés sont gardés (les anciennes propositions tirées au sort sont oubliées).
    void Charger(Player* player)
    {
        Donnees* d = DonneesDe(player);
        uint32 guid = player->GetGUID().GetCounter();
        CharacterDatabase.DirectExecute("DELETE FROM solazeroth_contrats WHERE guid = {} AND actif = 0", guid);
        if (QueryResult r = CharacterDatabase.Query("SELECT slot, type, cible, detail, objectif, progression, niveau, cible_tuee, theme "
            "FROM solazeroth_contrats WHERE guid = {}", guid))
        {
            do
            {
                Field* f = r->Fetch();
                uint8 slot = f[0].Get<uint8>();
                if (slot < 1 || slot > EMPLACEMENTS)
                    continue;
                Contrat& c = d->contrats[slot - 1];
                c.type = f[1].Get<uint8>();
                c.cible = f[2].Get<uint32>();
                c.detail = f[3].Get<uint32>();
                c.objectif = f[4].Get<uint16>();
                c.progression = f[5].Get<uint16>();
                c.niveau = f[6].Get<uint8>();
                c.cibleTuee = f[7].Get<uint8>() != 0;
                c.theme = f[8].Get<uint8>() != 0;
            } while (r->NextRow());
        }
    }

    // Le contrat (type, cible, détail, comme dans Contrat) colle-t-il au thème de la semaine ?
    bool AuTheme(uint8 type, uint32 cible, uint32 detail)
    {
        Theme const* theme = ThemeDeLaSemaine();
        if (!theme)
            return false;
        switch (type)
        {
            case CHASSE:
                return detail == theme->famille;
            case DONJON:
                if (LFGDungeonEntry const* d = sLFGDungeonStore.LookupEntry(cible))
                {
                    auto it = familleDonjon.find(d->MapID);
                    return it != familleDonjon.end() && it->second == theme->famille;
                }
                return false;
            case PRIME:
            {
                auto it = cibles.find(detail);
                return it != cibles.end() && it->second.famille == theme->famille;
            }
            case ARTISAN:
                return MetierDuSort(detail) == theme->metier;
        }
        return false;
    }

    void EnvoyerEtat(Player* player)
    {
        uint8 niveau = player->GetLevel();
        SolAzeroth::EnvoyerAddon(player, PREFIXE, Acore::StringFormat("ETAT;{};{};{};{};{};{}",
            Charges(player->GetSession()->GetAccountId()), ReserveMax(player->GetSession()->GetAccountId()), SecondesAvantRecharge(time(nullptr)),
            reglages.marques, uint32(RecompenseOr(niveau) * (1.0f + SolAzeroth::BonusOrContrats(player))), ParJour(player->GetSession()->GetAccountId())));
        if (Theme const* theme = ThemeDeLaSemaine())
            SolAzeroth::EnvoyerAddon(player, PREFIXE, Acore::StringFormat("THEME;{};{};{};{};{:.0f}",
                theme->nom, theme->famille, theme->metier, theme->description, reglages.bonusTheme * 100));

        for (auto const& [cle, groupes] : chasses)
        {
            uint32 nombre = MonstresANiveau(groupes, niveau);
            if (nombre >= 20)
                SolAzeroth::EnvoyerAddon(player, PREFIXE, Acore::StringFormat("CH;{};{};{};{};{}", cle.first, cle.second, NomZone(cle.first), nombre,
                    AuTheme(CHASSE, cle.first, cle.second) ? 1 : 0));
        }
        uint8 rang = RangMinimal(player);
        for (LFGDungeonEntry const* d : donjons)
            if (DonjonDisponible(niveau, d))
                SolAzeroth::EnvoyerAddon(player, PREFIXE, Acore::StringFormat("DJ;{};{};{};{}", d->ID, Nom(d->Name), rang,
                    AuTheme(DONJON, d->ID, 0) ? 1 : 0));
        for (auto const& [entree, cible] : cibles)
            if (CibleDisponible(niveau, cible))
                SolAzeroth::EnvoyerAddon(player, PREFIXE, Acore::StringFormat("PR;{};{};{};{};{};{};{}", entree, cible.nom,
                    cible.classement, cible.max, NomZone(cible.zone), Coordonnees(cible), AuTheme(PRIME, cible.zone, entree) ? 1 : 0));
        for (Recette const& r : RecettesArtisan(player))
            SolAzeroth::EnvoyerAddon(player, PREFIXE, Acore::StringFormat("AR;{};{};{};{};{}", r.sort, r.objet, r.nombre, r.metier,
                AuTheme(ARTISAN, r.objet, r.sort) ? 1 : 0));

        Donnees* donnees = DonneesDe(player);
        for (uint8 i = 0; i < EMPLACEMENTS; ++i)
        {
            Contrat const& c = donnees->contrats[i];
            if (c.type == AUCUN)
                continue;
            auto cible = c.type == PRIME ? cibles.find(c.detail) : cibles.end();
            SolAzeroth::EnvoyerAddon(player, PREFIXE, Acore::StringFormat("C;{};{};{};{};{};{};{};{};{};{};{};{}",
                i + 1, c.type, c.cible, NomCible(c), c.detail, c.objectif, c.progression, c.cibleTuee ? 1 : 0,
                cible != cibles.end() ? cible->second.nom : "", cible != cibles.end() ? Coordonnees(cible->second) : "",
                c.type == PRIME ? Dimensions(c.cible) : "0;0", c.theme ? 1 : 0));
        }
        SolAzeroth::EnvoyerAddon(player, PREFIXE, "FIN");
    }

    void Terminer(Player* player, uint8 slot)
    {
        Contrat& c = DonneesDe(player)->contrats[slot];
        ChatHandler chat(player->GetSession());
        chat.SendSysMessage(Acore::StringFormat("|cff00ff00Contrat rempli : {} !|r", NomCible(c)));

        // Compteurs des hauts faits (section 7.4).
        SolAzeroth::AjouterCompteur(player, "contrats");
        if (c.type == CHASSE)
            SolAzeroth::AjouterCompteur(player, "chasses");
        else if (c.type == PRIME)
            SolAzeroth::AjouterCompteur(player, "primes");

        uint32 marques = reglages.marques;
        if (c.theme)
        {
            marques = uint32(std::lround(marques * (1.0f + reglages.bonusTheme)));
            chat.SendSysMessage(Acore::StringFormat("|cffffd100Contrat du thème de la semaine : +{:.0f} % de Marques.|r", reglages.bonusTheme * 100));
        }
        SolAzeroth::DonnerMarques(player, marques, "contrat");
        player->ModifyMoney(int32(RecompenseOr(c.niveau) * (1.0f + SolAzeroth::BonusOrContrats(player))));   // bonus de haut fait
        if (urand(1, 100) <= reglages.chanceObjet)
        {
            if (uint32 objet = SolAzeroth::ObjetIntendantAuHasard(player))
            {
                if (SolAzeroth::DonnerObjetDeRang(player, objet, 3))
                    chat.SendSysMessage("|cffa335eeLe coffre du contrat contenait un objet !|r");
                else
                {
                    SolAzeroth::DonnerMarques(player, reglages.marques, "objet du contrat, sacs pleins");
                    chat.SendSysMessage("Sacs pleins : l'objet du coffre est remplacé par des Marques.");
                }
            }
        }

        c = Contrat();
        Sauver(player, slot);
        EnvoyerEtat(player);
    }

    // Avance un contrat ; une prime de zone n'est finie qu'avec la cible tuée.
    void Progresser(Player* player, uint8 slot, uint16 quantite, bool cibleTuee = false)
    {
        Contrat& c = DonneesDe(player)->contrats[slot];
        c.progression = std::min<uint16>(c.objectif, c.progression + quantite);
        if (cibleTuee)
        {
            c.cibleTuee = true;
            ChatHandler(player->GetSession()).SendSysMessage("|cffffd100Prime de zone : cible abattue !|r");
        }
        if (c.progression >= c.objectif && (c.type != PRIME || c.cibleTuee))
        {
            Terminer(player, slot);
            return;
        }
        Sauver(player, slot);
        SolAzeroth::EnvoyerAddon(player, PREFIXE, Acore::StringFormat("P;{};{};{};{}", slot + 1, c.progression, c.objectif, c.cibleTuee ? 1 : 0));
    }

    // Si la cible d'une prime est morte (ou en attente de réapparition) quand le joueur est dans sa zone,
    // elle réapparaît. Appelé depuis la mise à jour du joueur, donc dans le fil de sa carte.
    void ReveillerCible(Player* player, Cible const& cible)
    {
        Map* map = player->GetMap();
        bool vivante = false;
        Creature* morte = nullptr;
        for (Apparition const& a : cible.apparitions)
        {
            if (a.map != map->GetId())
                continue;
            auto bornes = map->GetCreatureBySpawnIdStore().equal_range(a.spawnId);
            for (auto it = bornes.first; it != bornes.second; ++it)
            {
                if (it->second->IsAlive())
                    vivante = true;
                else if (!morte)
                    morte = it->second;
            }
        }
        if (vivante)
            return;
        if (morte)
            morte->Respawn(true);
        else
            for (Apparition const& a : cible.apparitions)
                if (a.map == map->GetId())
                    map->RemoveCreatureRespawnTime(a.spawnId);
    }

    // Prend un contrat : un emplacement libre et une charge de la réserve. Renvoie l'emplacement, ou -1.
    int Prendre(ChatHandler* handler, Contrat const& nouveau)
    {
        Player* player = handler->GetPlayer();
        Donnees* d = DonneesDe(player);
        int slot = -1;
        for (uint8 i = 0; i < EMPLACEMENTS && slot < 0; ++i)
        {
            Contrat const& c = d->contrats[i];
            if (c.type == nouveau.type && c.cible == nouveau.cible && c.detail == nouveau.detail)
            {
                handler->SendSysMessage("Ce contrat est déjà en cours.");
                return -1;
            }
            if (c.type == AUCUN)
                slot = i;
        }
        if (slot < 0)
        {
            handler->SendSysMessage("|cffff0000Trois contrats sont déjà en cours.|r Finis-en ou abandonnes-en un.");
            return -1;
        }
        uint32 compte = player->GetSession()->GetAccountId();
        uint32 charges = Charges(compte);
        if (!charges)
        {
            handler->SendSysMessage("|cffff0000Plus de contrat en réserve.|r Il en revient 3 chaque jour à 6 h.");
            return -1;
        }
        CharacterDatabase.DirectExecute("UPDATE solazeroth_contrats_reserve SET charges = {} WHERE account = {}", charges - 1, compte);
        d->contrats[slot] = nouveau;
        d->contrats[slot].niveau = player->GetLevel();
        d->contrats[slot].theme = AuTheme(nouveau.type, nouveau.cible, nouveau.detail);
        Sauver(player, slot);
        handler->SendSysMessage(Acore::StringFormat("|cffffd100Contrat accepté : {}.|r", NomCible(d->contrats[slot])));
        return slot;
    }
}

void SolAzeroth::ContratDonjonReussi(Player* player, unsigned int donjon, unsigned char rang)
{
    Donnees* d = DonneesDe(player);
    for (uint8 i = 0; i < EMPLACEMENTS; ++i)
    {
        Contrat const& c = d->contrats[i];
        if (c.type != DONJON || c.cible != donjon)
            continue;
        if (rang >= c.detail)
            Progresser(player, i, 1);
        else
            ChatHandler(player->GetSession()).SendSysMessage(Acore::StringFormat(
                "Contrat non rempli : il fallait le rang de menace {} au moins.", c.detail));
    }
}

class solazeroth_contrats_joueur : public PlayerScript
{
public:
    solazeroth_contrats_joueur() : PlayerScript("solazeroth_contrats_joueur", {
        PLAYERHOOK_ON_LOGIN, PLAYERHOOK_ON_CREATURE_KILL_CREDIT, PLAYERHOOK_ON_UPDATE }) { }

    void OnPlayerLogin(Player* player) override
    {
        Charger(player);
    }

    // Toutes les 5 secondes : cible de prime à réveiller si le joueur est dans sa zone (une fois par passage).
    void OnPlayerUpdate(Player* player, uint32 temps) override
    {
        Donnees* d = DonneesDe(player);
        d->attente += temps;
        if (d->attente < 5 * IN_MILLISECONDS)
            return;
        d->attente = 0;
        for (uint8 i = 0; i < EMPLACEMENTS; ++i)
        {
            Contrat const& c = d->contrats[i];
            bool dansLaZone = c.type == PRIME && !c.cibleTuee && player->GetZoneId() == c.cible;
            if (!dansLaZone)
            {
                d->reveillee[i] = false;
                continue;
            }
            if (d->reveillee[i])
                continue;
            d->reveillee[i] = true;
            auto cible = cibles.find(c.detail);
            if (cible != cibles.end())
                ReveillerCible(player, cible->second);
        }
    }

    // Monstres tués par le joueur, son familier ou ses totems ; les monstres gris ne comptent pas.
    void OnPlayerCreatureKillCredit(Player* player, Creature* tue) override
    {
        if (!tue || tue->GetLevel() <= Acore::XP::GetGrayLevel(player->GetLevel()))
            return;
        Donnees* d = DonneesDe(player);
        for (uint8 i = 0; i < EMPLACEMENTS; ++i)
        {
            Contrat const& c = d->contrats[i];
            if (c.type == CHASSE && c.cible == tue->GetZoneId() && c.detail == tue->GetCreatureTemplate()->type)
                Progresser(player, i, 1);
            else if (c.type == PRIME && c.cible == tue->GetZoneId())
            {
                if (tue->GetEntry() == c.detail)
                    Progresser(player, i, 0, true);
                else if (c.progression < c.objectif)
                    Progresser(player, i, 1);
            }
        }
    }
};

class solazeroth_contrats_commandes : public CommandScript
{
public:
    solazeroth_contrats_commandes() : CommandScript("solazeroth_contrats_commandes") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable sousCommandes =
        {
            { "etat",       HandleEtat,       SEC_PLAYER, Console::No },
            { "chasse",     HandleChasse,     SEC_PLAYER, Console::No },
            { "donjon",     HandleDonjon,     SEC_PLAYER, Console::No },
            { "prime",      HandlePrime,      SEC_PLAYER, Console::No },
            { "artisan",    HandleArtisan,    SEC_PLAYER, Console::No },
            { "livrer",     HandleLivrer,     SEC_PLAYER, Console::No },
            { "abandonner", HandleAbandonner, SEC_PLAYER, Console::No },
        };
        static ChatCommandTable commandes =
        {
            { "solcontrat", sousCommandes },
        };
        return commandes;
    }

    static bool HandleEtat(ChatHandler* handler)
    {
        EnvoyerEtat(handler->GetPlayer());
        return true;
    }

    static bool HandleChasse(ChatHandler* handler, uint32 zone, uint32 famille)
    {
        Player* player = handler->GetPlayer();
        if (!ChasseDisponible(player->GetLevel(), zone, famille))
            return true;
        Contrat c;
        c.type = CHASSE;
        c.cible = zone;
        c.detail = famille;
        c.objectif = uint16(urand(reglages.chasseMin, reglages.chasseMax));
        Prendre(handler, c);
        EnvoyerEtat(player);
        return true;
    }

    static bool HandleDonjon(ChatHandler* handler, uint32 donjon)
    {
        Player* player = handler->GetPlayer();
        LFGDungeonEntry const* d = sLFGDungeonStore.LookupEntry(donjon);
        if (!d || std::find(donjons.begin(), donjons.end(), d) == donjons.end() || !DonjonDisponible(player->GetLevel(), d))
            return true;
        Contrat c;
        c.type = DONJON;
        c.cible = donjon;
        c.detail = RangMinimal(player);
        c.objectif = 1;
        Prendre(handler, c);
        EnvoyerEtat(player);
        return true;
    }

    static bool HandlePrime(ChatHandler* handler, uint32 entree)
    {
        Player* player = handler->GetPlayer();
        auto cible = cibles.find(entree);
        if (cible == cibles.end() || !CibleDisponible(player->GetLevel(), cible->second))
            return true;
        Contrat c;
        c.type = PRIME;
        c.cible = cible->second.zone;
        c.detail = entree;
        c.objectif = uint16(urand(reglages.primeMin, reglages.primeMax));
        int slot = Prendre(handler, c);
        if (slot >= 0)
            DonneesDe(player)->reveillee[slot] = false;
        EnvoyerEtat(player);
        return true;
    }

    static bool HandleArtisan(ChatHandler* handler, uint32 sort)
    {
        Player* player = handler->GetPlayer();
        std::vector<Recette> recettes = RecettesArtisan(player);
        auto r = std::find_if(recettes.begin(), recettes.end(), [&](Recette const& x) { return x.sort == sort; });
        if (r == recettes.end())
            return true;
        Contrat c;
        c.type = ARTISAN;
        c.cible = r->objet;
        c.detail = r->sort;
        c.objectif = r->nombre;
        Prendre(handler, c);
        EnvoyerEtat(player);
        return true;
    }

    // Livraison d'une commande d'artisan : les objets sont retirés des sacs.
    static bool HandleLivrer(ChatHandler* handler, uint8 slot)
    {
        Player* player = handler->GetPlayer();
        if (slot < 1 || slot > EMPLACEMENTS)
            return true;
        Contrat& c = DonneesDe(player)->contrats[slot - 1];
        if (c.type != ARTISAN)
            return true;
        if (player->GetItemCount(c.cible) < c.objectif)
        {
            handler->SendSysMessage(Acore::StringFormat("|cffff0000Il faut {} {} dans tes sacs.|r", c.objectif, NomCible(c)));
            return true;
        }
        player->DestroyItemCount(c.cible, c.objectif, true);
        Progresser(player, slot - 1, c.objectif);
        return true;
    }

    static bool HandleAbandonner(ChatHandler* handler, uint8 slot)
    {
        Player* player = handler->GetPlayer();
        if (slot < 1 || slot > EMPLACEMENTS)
            return true;
        Contrat& c = DonneesDe(player)->contrats[slot - 1];
        if (c.type == AUCUN)
            return true;
        c = Contrat();
        Sauver(player, slot - 1);
        handler->SendSysMessage("Contrat abandonné.");
        EnvoyerEtat(player);
        return true;
    }
};

class solazeroth_contrats_monde : public WorldScript
{
public:
    solazeroth_contrats_monde() : WorldScript("solazeroth_contrats_monde", { WORLDHOOK_ON_AFTER_CONFIG_LOAD, WORLDHOOK_ON_STARTUP }) { }

    void OnAfterConfigLoad(bool /*rechargement*/) override
    {
        reglages.parJour = sConfigMgr->GetOption<uint32>("SolAzeroth.Contrats.ParJour", 3);
        reglages.reserveMax = sConfigMgr->GetOption<uint32>("SolAzeroth.Contrats.ReserveMax", 9);
        reglages.marques = sConfigMgr->GetOption<uint32>("SolAzeroth.Contrats.Marques", 15);
        reglages.orFacteur = sConfigMgr->GetOption<uint32>("SolAzeroth.Contrats.OrFacteur", 50);
        reglages.chanceObjet = sConfigMgr->GetOption<uint32>("SolAzeroth.Contrats.ChanceObjet", 25);
        reglages.chasseMin = sConfigMgr->GetOption<uint32>("SolAzeroth.Contrats.ChasseMin", 15);
        reglages.chasseMax = std::max(reglages.chasseMin, sConfigMgr->GetOption<uint32>("SolAzeroth.Contrats.ChasseMax", 25));
        reglages.primeMin = sConfigMgr->GetOption<uint32>("SolAzeroth.Contrats.PrimeMin", 8);
        reglages.primeMax = std::max(reglages.primeMin, sConfigMgr->GetOption<uint32>("SolAzeroth.Contrats.PrimeMax", 12));
        reglages.artisanEcart = sConfigMgr->GetOption<uint32>("SolAzeroth.Contrats.ArtisanEcart", 5);
        reglages.artisanParNiveau = sConfigMgr->GetOption<uint32>("SolAzeroth.Contrats.ArtisanParNiveau", 5);
        reglages.bonusTheme = sConfigMgr->GetOption<float>("SolAzeroth.Contrats.BonusTheme", 0.5f);
    }

    void OnStartup() override
    {
        // Recettes des maîtres de métier (type 2), avec la compétence demandée pour les apprendre.
        if (QueryResult r = WorldDatabase.Query("SELECT ts.SpellId, MIN(ts.ReqSkillRank) FROM trainer_spell ts "
            "JOIN trainer t ON t.Id = ts.TrainerId WHERE t.Type = 2 GROUP BY ts.SpellId"))
        {
            do
                recettesDeMaitre[(*r)[0].Get<uint32>()] = (*r)[1].Get<uint32>();
            while (r->NextRow());
        }

        // Monstres hostiles (ni amis des joueurs, ni d'une faction de joueur), ordinaires, sans fonction de PNJ.
        if (QueryResult r = WorldDatabase.Query(
            "SELECT c.zoneId, t.type, t.minlevel, t.maxlevel, t.faction, COUNT(*) FROM creature c "
            "JOIN creature_template t ON t.entry = c.id WHERE c.map IN (0, 1, 530, 571) AND c.zoneId <> 0 "
            "AND t.`rank` = 0 AND t.type IN (1, 2, 3, 4, 5, 6, 7, 9) AND t.npcflag = 0 "
            "GROUP BY c.zoneId, t.type, t.minlevel, t.maxlevel, t.faction"))
        {
            do
            {
                Field* f = r->Fetch();
                FactionTemplateEntry const* faction = sFactionTemplateStore.LookupEntry(f[4].Get<uint32>());
                if (!faction || (faction->friendlyMask & FACTION_MASK_PLAYER)
                    || (faction->ourMask & (FACTION_MASK_ALLIANCE | FACTION_MASK_HORDE)))
                    continue;
                AreaTableEntry const* zone = sAreaTableStore.LookupEntry(f[0].Get<uint32>());
                if (!zone || zone->IsSanctuary())
                    continue;
                chasses[{ f[0].Get<uint32>(), f[1].Get<uint32>() }].push_back(
                    { f[2].Get<uint8>(), f[3].Get<uint8>(), uint32(f[5].Get<uint64>()) });
            } while (r->NextRow());
        }

        if (QueryResult r = WorldDatabase.Query("SELECT DISTINCT lastEncounterDungeon FROM instance_encounters WHERE lastEncounterDungeon > 0"))
        {
            do
            {
                LFGDungeonEntry const* d = sLFGDungeonStore.LookupEntry(r->Fetch()[0].Get<uint32>());
                if (d && d->TypeID == 1 /*LFG_TYPE_DUNGEON*/ && d->Difficulty == 0)
                    donjons.push_back(d);
            } while (r->NextRow());
        }
        // Cibles de prime : rares et élites rares (3 apparitions au plus), élites nommés (une seule apparition).
        if (QueryResult r = WorldDatabase.Query(
            "SELECT t.entry, t.`rank`, t.minlevel, t.maxlevel, t.faction, c.guid, c.map, c.zoneId, c.position_x, c.position_y, t.type "
            "FROM creature c JOIN creature_template t ON t.entry = c.id WHERE c.map IN (0, 1, 530, 571) AND c.zoneId <> 0 "
            "AND t.`rank` IN (1, 2, 4) AND t.npcflag = 0 AND t.type IN (1, 2, 3, 4, 5, 6, 7, 9) AND t.minlevel >= 5"))
        {
            do
            {
                Field* f = r->Fetch();
                uint32 entree = f[0].Get<uint32>();
                FactionTemplateEntry const* faction = sFactionTemplateStore.LookupEntry(f[4].Get<uint32>());
                if (!faction || (faction->friendlyMask & FACTION_MASK_PLAYER)
                    || (faction->ourMask & (FACTION_MASK_ALLIANCE | FACTION_MASK_HORDE)))
                    continue;
                AreaTableEntry const* zone = sAreaTableStore.LookupEntry(f[7].Get<uint32>());
                if (!zone || zone->IsSanctuary())
                    continue;
                Cible& c = cibles[entree];
                if (c.apparitions.empty())
                {
                    c.entree = entree;
                    c.classement = f[1].Get<uint8>();
                    c.min = f[2].Get<uint8>();
                    c.max = f[3].Get<uint8>();
                    c.zone = f[7].Get<uint32>();
                    c.famille = f[10].Get<uint8>();
                }
                float x = f[8].Get<float>(), y = f[9].Get<float>();
                Map2ZoneCoordinates(x, y, c.zone);   // monde -> pourcentage de la carte de zone
                c.apparitions.push_back({ f[5].Get<uint32>(), f[6].Get<uint32>(), x, y });
            } while (r->NextRow());
        }
        // Trop d'apparitions : ce n'est pas un monstre nommé, mais un camp d'élites.
        LocaleConstant langue = sWorld->GetDefaultDbcLocale();
        for (auto it = cibles.begin(); it != cibles.end();)
        {
            Cible& c = it->second;
            size_t maximum = c.classement == 1 ? 1 : 3;
            CreatureTemplate const* modele = sObjectMgr->GetCreatureTemplate(c.entree);
            if (c.apparitions.size() > maximum || !modele)
            {
                it = cibles.erase(it);
                continue;
            }
            c.nom = modele->Name;
            if (CreatureLocale const* traduction = sObjectMgr->GetCreatureLocale(c.entree))
                ObjectMgr::GetLocaleString(traduction->Name, langue, c.nom);
            c.nom.erase(std::remove(c.nom.begin(), c.nom.end(), ';'), c.nom.end());
            ++it;
        }

        // Famille dominante de chaque donjon : monstres hostiles (même filtre que les chasses), boss compris.
        std::map<uint32, std::map<uint8, uint64>> comptes;
        for (LFGDungeonEntry const* d : donjons)
            comptes[d->MapID];
        if (QueryResult r = WorldDatabase.Query(
            "SELECT c.map, t.type, t.faction, COUNT(*) FROM creature c JOIN creature_template t ON t.entry = c.id "
            "WHERE t.type IN (1, 2, 3, 4, 5, 6, 7, 9) AND t.npcflag = 0 GROUP BY c.map, t.type, t.faction"))
        {
            do
            {
                Field* f = r->Fetch();
                auto carte = comptes.find(f[0].Get<uint32>());
                if (carte == comptes.end())
                    continue;
                FactionTemplateEntry const* faction = sFactionTemplateStore.LookupEntry(f[2].Get<uint32>());
                if (!faction || (faction->friendlyMask & FACTION_MASK_PLAYER)
                    || (faction->ourMask & (FACTION_MASK_ALLIANCE | FACTION_MASK_HORDE)))
                    continue;
                carte->second[f[1].Get<uint8>()] += f[3].Get<uint64>();
            } while (r->NextRow());
        }
        for (auto const& [carte, familles] : comptes)
        {
            auto plus = std::max_element(familles.begin(), familles.end(),
                [](auto const& a, auto const& b) { return a.second < b.second; });
            if (plus != familles.end())
                familleDonjon[carte] = plus->first;
        }

        if (QueryResult r = WorldDatabase.Query("SELECT nom, famille, metier, description FROM solazeroth_themes ORDER BY ordre"))
        {
            do
            {
                Field* f = r->Fetch();
                Theme t{ f[0].Get<std::string>(), f[1].Get<uint8>(), f[2].Get<uint32>(), f[3].Get<std::string>() };
                t.nom.erase(std::remove(t.nom.begin(), t.nom.end(), ';'), t.nom.end());
                t.description.erase(std::remove(t.description.begin(), t.description.end(), ';'), t.description.end());
                themes.push_back(t);
            } while (r->NextRow());
        }
        Theme const* theme = ThemeDeLaSemaine();
        LOG_INFO("module", "Sol'Azeroth contrats : {} chasses (zone et famille), {} donjons, {} cibles de prime, {} thèmes (cette semaine : {})",
            chasses.size(), donjons.size(), cibles.size(), themes.size(), theme ? theme->nom : "aucun");
    }
};

void AddSC_solazeroth_contrats()
{
    new solazeroth_contrats_joueur();
    new solazeroth_contrats_commandes();
    new solazeroth_contrats_monde();
}
