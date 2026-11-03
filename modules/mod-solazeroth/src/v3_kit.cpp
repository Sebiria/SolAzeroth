// v3, F3 (31/10/2026) : kit du guerrier tank (document v3, partie 3 et F3).
// - La spécialisation se choisit à l'entrée en jeu (.kit spe tank, depuis la page Techniques de /sol). Pour l'instant,
//   seul le guerrier tank existe. Elle donne d'emblée le passif Rempart et les 4 premières techniques.
// - Lot 3b (02/11/2026, table validée par l'utilisateur) : les techniques s'ouvrent à des étapes du récit (quête rendue,
//   chef renforcé tombé), et non plus tous les 5 points de puissance. Durotar en ouvre 7 sur 16 ; les autres attendent
//   les zones suivantes. Les emplacements aussi s'ouvrent peu à peu : 3 au départ, 5 à la fin de Durotar, 8 plus tard.
//   Le choix se fait hors combat (.kit equiper). Les techniques équipées sont apprises et posées sur la barre, les
//   autres oubliées. Les anciens sorts du guerrier (postures, Frappe héroïque…) sont retirés.
// - Rempart : chaque coup encaissé, après l'armure, verse SolAzeroth.V3.Rempart.Part % de ses dégâts dans un bouclier
//   (aura 100010, absorption), plafonné à SolAzeroth.V3.Rempart.Plafond % de la vie maximale. Hors combat, il perd
//   SolAzeroth.V3.Rempart.Fuite % de la vie maximale toutes les 2 secondes. Riposte du rempart et Second souffle le
//   consomment, Vengeance le demande plein, Frappe du bouclier et Dernier rempart le remplissent, Cri de défi aussi
//   (SolAzeroth.V3.Rempart.CriDefi % de la vie maximale par ennemi attiré, à la place de la provocation, 31/10/2026).
// Les sorts eux-mêmes (copies retouchées de sorts de Blizzard) sont générés par outils\techniques_v3.py (migration 061).
// Démoniste, lot D1 (02/11/2026, « Démoniste — proposition.md ») : les spécialisations sont une table (SPECIALISATIONS) :
// classe, clé de « .kit spe », passif, techniques dans l'ordre du récit, armes de départ. Le démoniste Affliction y entre
// avec ses techniques au lot D2 (outils\demoniste_v3.py, migration 123, v3_demoniste.cpp). Ses anciens sorts sont
// retirés comme ceux du guerrier, et il n'a aucun familier permanent (règle de
// l'utilisateur : seulement des invocations temporaires, pour toutes les classes).

#include "SolAzeroth.h"
#include "Chat.h"
#include "CommandScript.h"
#include "Config.h"
#include "DatabaseEnv.h"
#include "ItemTemplate.h"
#include "MotionMaster.h"
#include "MovementTypedefs.h"
#include "Pet.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "SpellAuraEffects.h"
#include "SpellInfo.h"
#include "SpellMgr.h"
#include "SpellScript.h"
#include "SpellScriptLoader.h"
#include "StringFormat.h"
#include <cmath>
#include <sstream>

using namespace Acore::ChatCommands;

namespace
{
    char const* const PREFIXE = "SOLKIT";
    uint32 const TICK_KIT = 2000;
    uint32 const TICK_REMPART = 250;
    uint8 const SPE_AUCUNE = 0;
    uint8 const SPE_GUERRIER_TANK = 1;
    uint8 const SPE_DEMONISTE_AFFLICTION = 2;
    uint8 const SPE_VOLEUR_ASSASSINAT = 3;
    uint32 const PASSIF_REMPART = 100009;
    uint32 const PASSIF_MOISSON = 100200;
    uint32 const PASSIF_TOXINES = 100300;
    uint32 const SORT_EPEES_1M = 201;          // Épées à une main
    uint32 const EPEE_DE_DEPART = 25;          // Épée courte usée
    uint32 const BOUCLIER_DE_DEPART = 2362;    // Vieux bouclier en bois
    uint32 const SORT_DAGUES = 1180;           // Dagues
    uint32 const DAGUE_DE_DEPART = 2092;       // Dague usée
    uint32 const SORT_MASSES_1M = 198;         // Masses à une main
    uint32 const SORT_HACHES_1M = 196;         // Haches à une main
    uint32 const SORT_BATONS = 227;            // Bâtons
    uint32 const SORT_AMBIDEXTRIE = 674;       // Ambidextrie
    uint32 const REMPART = 100010;
    size_t const EMPLACEMENTS_DE_DEPART = 3;
    size_t const EQUIPEES_MAX = 8;
    uint32 const PLUS_TARD = 0xFFFFFFFF;       // étape d'une zone qui n'existe pas encore

    struct Technique
    {
        uint32 sort;
        char const* nom;
        uint32 quete;          // quête rendue qui l'ouvre (0 : aucune)
        uint32 lieu;           // lieu dont le chef renforcé l'ouvre (0 : aucun) ; ni l'un ni l'autre : dès le départ
        char const* maitre;    // qui l'enseigne, pour l'annonce
        bool emplacement;      // ouvre aussi un emplacement
    };

    // Guerrier tank. Ordre d'affichage, celui du récit.
    std::vector<Technique> const ORDRE_TANK =
    {
        { 100011, "Frappe du bouclier", 0, 0, nullptr, false },
        { 100013, "Charge", 0, 0, nullptr, false },
        { 100012, "Coup de tonnerre", 910002, 0, "Gornek", false },              // Les crocs de la Vallée
        { 100019, "Heurt de bouclier", 910005, 0, "Zureetha Fargaze", true },    // Les vils quasits, avant Yarrog
        { 100015, "Cri de défi", 910008, 0, "Gar'Thok", false },                 // Un rapport à Orgnil (Tranchecolline)
        { 100014, "Riposte du rempart", 0, 2, "Gar'Thok", true },               // chef renforcé de Tranchecolline
        { 100016, "Second souffle", 910019, 0, "Maître Gadrin", false },         // Le crâne de Minshina (Sen'jin)
        { 100020, "Fracasser armure", 910048, 0, "Thork", true },                // T08 Sarilus (la Croisée)
        { 100018, "Mur protecteur", 910059, 0, "Ruga Totem-de-rage", false },    // T19 Joyaux (Camp Taurajo)
        { 100021, "Désarmement", PLUS_TARD, 0, nullptr, false },                 // zone 3
        { 100017, "Ravage", PLUS_TARD, 0, nullptr, false },                      // zone 3
        { 100022, "Onde de choc", PLUS_TARD, 0, nullptr, true },                 // zone 4
        { 100024, "Renvoi de sort", PLUS_TARD, 0, nullptr, false },              // zone 5
        { 100023, "Bond héroïque", PLUS_TARD, 0, nullptr, false },               // zone 5
        { 100025, "Vengeance", PLUS_TARD, 0, nullptr, true },                    // zone 6
        { 100026, "Dernier rempart", PLUS_TARD, 0, nullptr, false },             // zone 7
    };

    // Démoniste Affliction (lot D2, v3_demoniste.cpp) : mêmes étapes du récit que le guerrier, maîtres du démoniste
    // (Nartok dans la Vallée, Dhugru Gorelust à Razor Hill). Emplacements ouverts aux mêmes étapes.
    std::vector<Technique> const ORDRE_AFFLICTION =
    {
        { 100201, "Trait de l'ombre", 0, 0, nullptr, false },
        { 100202, "Corruption", 0, 0, nullptr, false },
        { 100203, "Diablotin", 910002, 0, "Nartok", false },                     // Les crocs de la Vallée
        { 100205, "Drain de vie", 910005, 0, "Nartok", true },                   // Les vils quasits, avant Yarrog
        { 100206, "Peur", 910008, 0, "Dhugru Gorelust", false },                 // Un rapport à Orgnil (Tranchecolline)
        { 100207, "Marcheur du Vide", 0, 2, "Dhugru Gorelust", true },          // chef renforcé de Tranchecolline
        { 100204, "Malédiction d'agonie", 910019, 0, "Dhugru Gorelust", false }, // Le crâne de Minshina (Sen'jin)
        { 100208, "Malédiction de faiblesse", 910048, 0, "Gazrog", true },       // T08 Sarilus (la Croisée)
        { 100209, "Siphon de vie", 910059, 0, "Takar le Prophète", false },      // T19 Joyaux (Camp Taurajo)
        { 100213, "Voile mortel", PLUS_TARD, 0, nullptr, false },                // zone 3
        { 100211, "Graine de corruption", PLUS_TARD, 0, nullptr, false },        // zone 3
        { 100210, "Hurlement de terreur", PLUS_TARD, 0, nullptr, true },         // zone 4
        { 100214, "Drain d'âme", PLUS_TARD, 0, nullptr, false },                 // zone 5
        { 100215, "Pierre de soins", PLUS_TARD, 0, nullptr, false },             // zone 5
        { 100216, "Chasseur corrompu", PLUS_TARD, 0, nullptr, true },            // zone 6
        { 100217, "Affliction instable", PLUS_TARD, 0, nullptr, false },         // zone 7
    };

    // Voleur Assassinat (lot V2, v3_voleur.cpp) : mêmes étapes du récit, maîtres du voleur (Rwag dans la Vallée, Kaplak à
    // Razor Hill). Lot V6 (choix de l'utilisateur) : l'Éventail de couteaux vient à Sen'jin, pour les combats à deux
    // monstres ; la Rupture prend sa place en zone 4.
    std::vector<Technique> const ORDRE_ASSASSINAT =
    {
        { 100302, "Estropier", 0, 0, nullptr, false },
        { 100304, "Envenimer", 0, 0, nullptr, false },
        { 100305, "Coup de pied", 910002, 0, "Rwag", false },                    // Les crocs de la Vallée
        { 100307, "Évasion", 910005, 0, "Rwag", true },                          // Les vils quasits, avant Yarrog
        { 100308, "Camouflage", 910008, 0, "Kaplak", false },                    // Un rapport à Orgnil (Tranchecolline)
        { 100311, "Coup bas", 0, 2, "Kaplak", true },                            // chef renforcé de Tranchecolline
        { 100316, "Éventail de couteaux", 910019, 0, "Kaplak", false },          // Le crâne de Minshina (Sen'jin)
        { 100312, "Poison affaiblissant", 910048, 0, "Darsok Vivedague", true }, // T08 Sarilus (la Croisée)
        { 100313, "Lancer de couteau", 910059, 0, "Tatternack Forgacier", false }, // T19 Joyaux (Camp Taurajo)
        { 100314, "Sprint", PLUS_TARD, 0, nullptr, false },                      // zone 3
        { 100318, "Feinte", PLUS_TARD, 0, nullptr, false },                      // zone 3
        { 100306, "Rupture", PLUS_TARD, 0, nullptr, true },                      // zone 4
        { 100315, "Disparition", PLUS_TARD, 0, nullptr, false },                 // zone 5
        { 100320, "Aiguillon perfide", PLUS_TARD, 0, nullptr, false },           // zone 5
        { 100317, "Cape d'ombre", PLUS_TARD, 0, nullptr, true },                 // zone 6
        { 100319, "Vendetta", PLUS_TARD, 0, nullptr, false },                    // zone 7
    };

    struct Specialisation
    {
        uint8 id;
        uint8 classe;
        char const* cle;                                // .kit spe <clé>
        char const* nom;
        uint32 famille;                                 // SpellFamilyName des anciens sorts de la classe, retirés
        uint32 passif;                                  // passif d'identité (0 : aucun)
        uint8 caracteristique;                          // principale : repas, feu, puissance d'attaque (v3_niveau.cpp)
        std::vector<Technique> const* ordre;
        std::vector<uint32> competences;                // compétences d'arme, apprises au choix et à chaque application
        std::vector<std::pair<uint8, uint32>> armes;    // armes de départ, posées si les mains sont vides
        std::vector<uint32> permises;                   // sous-classes d'arme équipables, mêlée et distance (vide : toutes)
    };

    std::vector<Specialisation> const SPECIALISATIONS =
    {
        { SPE_GUERRIER_TANK, CLASS_WARRIOR, "tank", "guerrier tank", SPELLFAMILY_WARRIOR, PASSIF_REMPART, STAT_STRENGTH,
          &ORDRE_TANK, { SORT_EPEES_1M },
          { { EQUIPMENT_SLOT_MAINHAND, EPEE_DE_DEPART }, { EQUIPMENT_SLOT_OFFHAND, BOUCLIER_DE_DEPART } },
          // Règle de l'utilisateur (02/11/2026) : le tank n'équipe aucune arme à deux mains.
          { ITEM_SUBCLASS_WEAPON_AXE, ITEM_SUBCLASS_WEAPON_MACE, ITEM_SUBCLASS_WEAPON_SWORD, ITEM_SUBCLASS_WEAPON_FIST,
            ITEM_SUBCLASS_WEAPON_DAGGER } },
        // Lot D3 : l'arme ne compte que par ses caractéristiques. Règle de l'utilisateur (02/11/2026) : ni ambidextrie, ni
        // arme tranchante ou contondante (épée, masse, hache) ; dagues et bâtons seulement.
        { SPE_DEMONISTE_AFFLICTION, CLASS_WARLOCK, "affliction", "démoniste Affliction", SPELLFAMILY_WARLOCK,
          PASSIF_MOISSON, STAT_INTELLECT, &ORDRE_AFFLICTION, { SORT_DAGUES, SORT_BATONS },
          { { EQUIPMENT_SLOT_MAINHAND, DAGUE_DE_DEPART } },
          { ITEM_SUBCLASS_WEAPON_DAGGER, ITEM_SUBCLASS_WEAPON_STAFF } },
        // Lot V1 (« Voleur — proposition.md ») : deux dagues obligatoires, aucune autre arme. Kit et passif Toxines au
        // lot V2.
        { SPE_VOLEUR_ASSASSINAT, CLASS_ROGUE, "assassinat", "voleur Assassinat", SPELLFAMILY_ROGUE, PASSIF_TOXINES,
          STAT_AGILITY,
          &ORDRE_ASSASSINAT, { SORT_DAGUES, SORT_AMBIDEXTRIE },
          { { EQUIPMENT_SLOT_MAINHAND, DAGUE_DE_DEPART }, { EQUIPMENT_SLOT_OFFHAND, DAGUE_DE_DEPART } },
          { ITEM_SUBCLASS_WEAPON_DAGGER } },
    };

    Specialisation const* SpeParId(uint8 id)
    {
        for (Specialisation const& s : SPECIALISATIONS)
            if (s.id == id)
                return &s;
        return nullptr;
    }

    // Une classe qui a une spécialisation v3 : ses anciens sorts sont retirés et le kit s'applique.
    Specialisation const* PremiereDeLaClasse(uint8 classe)
    {
        for (Specialisation const& s : SPECIALISATIONS)
            if (s.classe == classe)
                return &s;
        return nullptr;
    }

    bool ClasseGeree(Player* player)
    {
        return PremiereDeLaClasse(player->getClass()) != nullptr;
    }

    struct Reglages
    {
        float part = 40.0f;
        float plafond = 30.0f;
        float fuite = 1.0f;
        float frappe = 5.0f;
        float criDefi = 3.0f;
    } reglages;

    struct Kit : DataMap::Base
    {
        uint8 spe = SPE_AUCUNE;
        std::vector<uint32> equipees;
        uint32 debloquees = 0;              // un bit par technique de l'ordre de la spécialisation
        bool applique = false;              // pas encore appliqué depuis la connexion
        uint32 attente = 0;
        uint32 attenteRempart = 0;
        std::string rempartEnvoye;
    };

    Kit* KitDe(Player* player)
    {
        return player->CustomData.GetDefault<Kit>("solazeroth_v3_kit");
    }

    std::vector<Technique> const& OrdreDe(Player* player)
    {
        static std::vector<Technique> const aucun;
        Specialisation const* s = SpeParId(KitDe(player)->spe);
        return s && s->classe == player->getClass() ? *s->ordre : aucun;
    }

    bool EstTechnique(std::vector<Technique> const& ordre, uint32 sort)
    {
        for (Technique const& t : ordre)
            if (t.sort == sort)
                return true;
        return false;
    }

    char const* NomDe(uint32 sort)
    {
        for (Specialisation const& s : SPECIALISATIONS)
            for (Technique const& t : *s.ordre)
                if (t.sort == sort)
                    return t.nom;
        return "?";
    }

    bool Ouverte(Player* player, Technique const& t)
    {
        if (t.quete == PLUS_TARD)
            return false;
        if (t.quete)
            return player->GetQuestRewardStatus(t.quete);
        if (t.lieu)
            return SolAzeroth::LieuClos(player, t.lieu);
        return true;
    }

    uint32 Debloquees(Player* player)
    {
        std::vector<Technique> const& ordre = OrdreDe(player);
        uint32 masque = 0;
        for (size_t i = 0; i < ordre.size(); ++i)
            if (Ouverte(player, ordre[i]))
                masque |= 1u << i;
        return masque;
    }

    size_t Emplacements(std::vector<Technique> const& ordre, uint32 debloquees)
    {
        size_t emplacements = EMPLACEMENTS_DE_DEPART;
        for (size_t i = 0; i < ordre.size(); ++i)
            if (ordre[i].emplacement && (debloquees & (1u << i)))
                ++emplacements;
        return std::min(emplacements, EQUIPEES_MAX);
    }

    bool EstDebloquee(std::vector<Technique> const& ordre, uint32 sort, uint32 debloquees)
    {
        for (size_t i = 0; i < ordre.size(); ++i)
            if (ordre[i].sort == sort)
                return debloquees & (1u << i);
        return false;
    }

    void Sauver(Player* player)
    {
        Kit* kit = KitDe(player);
        std::string liste;
        for (uint32 sort : kit->equipees)
            liste += (liste.empty() ? "" : " ") + std::to_string(sort);
        CharacterDatabase.Execute("REPLACE INTO solazeroth_v3_kit (guid, spe, equipees) VALUES ({}, {}, '{}')",
            player->GetGUID().GetCounter(), kit->spe, liste);
    }

    // ---------------------------------------------------------------- Rempart

    int32 Plafond(Unit* unite)
    {
        return int32(unite->GetMaxHealth() * reglages.plafond / 100.0f);
    }

    AuraEffect* Bouclier(Unit* unite)
    {
        return unite->GetAuraEffect(REMPART, EFFECT_0);
    }

    int32 Montant(Unit* unite)
    {
        AuraEffect* effet = Bouclier(unite);
        return effet ? std::max(0, effet->GetAmount()) : 0;
    }

    void Fixer(Unit* unite, int32 montant)
    {
        montant = std::min(montant, Plafond(unite));
        AuraEffect* effet = Bouclier(unite);
        if (montant <= 0)
        {
            if (effet)
                unite->RemoveAurasDueToSpell(REMPART);
            return;
        }
        if (!effet)
        {
            Aura* aura = unite->AddAura(REMPART, unite);
            effet = aura ? aura->GetEffect(EFFECT_0) : nullptr;
            if (!effet)
                return;
        }
        effet->SetAmount(montant);
    }

    void Ajouter(Unit* unite, int32 montant)
    {
        if (montant > 0)
            Fixer(unite, Montant(unite) + montant);
    }

    int32 Vider(Unit* unite)
    {
        int32 montant = Montant(unite);
        Fixer(unite, 0);
        return montant;
    }

    bool PorteLeRempart(Unit* unite)
    {
        Player* player = unite ? unite->ToPlayer() : nullptr;
        return player && KitDe(player)->spe == SPE_GUERRIER_TANK;
    }

    // ---------------------------------------------------------------- Techniques apprises et barre d'action

    void Envoyer(Player* player)
    {
        Kit* kit = KitDe(player);
        std::vector<Technique> const& ordre = OrdreDe(player);
        uint32 debloquees = Debloquees(player);
        std::string message = Acore::StringFormat("ETAT;{};{:.0f};{};", kit->spe, SolAzeroth::PuissanceJoueur(player),
            Emplacements(ordre, debloquees));
        for (size_t i = 0; i < ordre.size(); ++i)
        {
            bool equipee = std::find(kit->equipees.begin(), kit->equipees.end(), ordre[i].sort) != kit->equipees.end();
            message += Acore::StringFormat("{}{}:{}", i ? "," : "", ordre[i].sort,
                !(debloquees & (1u << i)) ? 0 : (equipee ? 2 : 1));
        }
        SolAzeroth::EnvoyerAddon(player, PREFIXE, message);
    }

    void PoserSurLaBarre(Player* player)
    {
        Kit* kit = KitDe(player);
        // Boutons des sorts oubliés (anciens sorts du guerrier, techniques retirées) : vidés.
        for (uint8 bouton = 0; bouton < MAX_ACTION_BUTTONS; ++bouton)
            if (ActionButton const* b = player->GetActionButton(bouton))
                if (b->GetType() == ACTION_BUTTON_SPELL && !player->HasSpell(b->GetAction()))
                    player->removeActionButton(bouton);
        for (uint32 sort : kit->equipees)
        {
            bool posee = false;
            for (uint8 bouton = 0; bouton < MAX_ACTION_BUTTONS && !posee; ++bouton)
                if (ActionButton const* b = player->GetActionButton(bouton))
                    posee = b->GetType() == ACTION_BUTTON_SPELL && b->GetAction() == sort;
            for (uint8 bouton = 0; bouton < MAX_ACTION_BUTTONS && !posee; ++bouton)
                if (!player->GetActionButton(bouton))
                    posee = player->addActionButton(bouton, sort, ACTION_BUTTON_SPELL) != nullptr;
        }
        player->SendActionButtons(1);
    }

    void Appliquer(Player* player)
    {
        Kit* kit = KitDe(player);
        Specialisation const* classe = PremiereDeLaClasse(player->getClass());
        if (!classe)
            return;

        // Anciens sorts de la classe : postures, Frappe héroïque, Trait de l'ombre de Blizzard… Les techniques v3 sont hors
        // de la famille de la classe.
        std::vector<uint32> anciens;
        for (auto const& [sort, etat] : player->GetSpellMap())
            if (etat->State != PLAYERSPELL_REMOVED)
                if (SpellInfo const* info = sSpellMgr->GetSpellInfo(sort))
                    if (info->SpellFamilyName == classe->famille)
                        anciens.push_back(sort);
        for (uint32 sort : anciens)
            player->removeSpell(sort, SPEC_MASK_ALL, false);
        // Aucun familier permanent (règle de l'utilisateur, 02/11/2026) : les invocations seront des techniques.
        if (Pet* familier = player->GetPet())
            player->RemovePet(familier, PET_SAVE_AS_DELETED);

        std::vector<Technique> const& ordre = OrdreDe(player);
        uint32 debloquees = kit->spe != SPE_AUCUNE ? Debloquees(player) : 0;
        size_t emplacements = Emplacements(ordre, debloquees);
        if (kit->applique)
            for (size_t i = 0; i < ordre.size(); ++i)
                if ((debloquees & (1u << i)) && !(kit->debloquees & (1u << i)))
                    ChatHandler(player->GetSession()).PSendSysMessage("|cff40c0ff{} t'enseigne une nouvelle technique : {}.{}|r "
                        "Équipe-la : carnet Techniques (touche K), onglet Techniques équipées.",
                        ordre[i].maitre ? ordre[i].maitre : "On", ordre[i].nom,
                        ordre[i].emplacement ? Acore::StringFormat(" Un emplacement de plus ({}).", emplacements) : "");
        kit->debloquees = debloquees;
        kit->applique = true;

        // Techniques équipées : seulement celles qui sont débloquées, complétées dans l'ordre jusqu'aux emplacements.
        std::vector<uint32> equipees;
        for (uint32 sort : kit->equipees)
            if (EstDebloquee(ordre, sort, debloquees) && std::find(equipees.begin(), equipees.end(), sort) == equipees.end()
                && equipees.size() < emplacements)
                equipees.push_back(sort);
        for (size_t i = 0; i < ordre.size() && equipees.size() < emplacements; ++i)
            if ((debloquees & (1u << i)) && std::find(equipees.begin(), equipees.end(), ordre[i].sort) == equipees.end())
                equipees.push_back(ordre[i].sort);
        if (equipees != kit->equipees)
        {
            kit->equipees = equipees;
            Sauver(player);
        }

        for (Technique const& t : ordre)
        {
            bool equipee = std::find(equipees.begin(), equipees.end(), t.sort) != equipees.end();
            if (equipee && !player->HasSpell(t.sort))
                player->learnSpell(t.sort);
            else if (!equipee && player->HasSpell(t.sort))
                player->removeSpell(t.sort, SPEC_MASK_ALL, false);
        }
        if (Specialisation const* s = SpeParId(kit->spe))
            if (s->classe == player->getClass())
                for (uint32 competence : s->competences)
                    if (!player->HasSpell(competence))
                        player->learnSpell(competence);
        for (Specialisation const& s : SPECIALISATIONS)
        {
            if (!s.passif || s.classe != player->getClass())
                continue;
            bool passif = s.id == kit->spe;
            if (passif && !player->HasSpell(s.passif))
                player->learnSpell(s.passif);
            else if (!passif && player->HasSpell(s.passif))
                player->removeSpell(s.passif, SPEC_MASK_ALL, false);
        }

        PoserSurLaBarre(player);
        Envoyer(player);
    }
}

// ---------------------------------------------------------------- Sorts

// Caractéristique principale de la spécialisation (repas, feu, puissance d'attaque) ; sans spécialisation, celle de
// la classe.
unsigned char SolAzeroth::CaracteristiquePrincipale(Player* player)
{
    if (Specialisation const* s = SpeParId(KitDe(player)->spe))
        if (s->classe == player->getClass())
            return s->caracteristique;
    switch (player->getClass())
    {
        case CLASS_WARRIOR:
        case CLASS_PALADIN:
        case CLASS_DEATH_KNIGHT:
            return STAT_STRENGTH;
        case CLASS_HUNTER:
        case CLASS_ROGUE:
            return STAT_AGILITY;
        default:
            return STAT_INTELLECT;
    }
}

// Arme de mêlée que la spécialisation peut équiper (v3_armures.cpp) ; sans spécialisation, toutes. Les armes à distance,
// cannes à pêche et outils ne sont pas concernés. Une spécialisation ambidextre (voleur) tient une arme dans chaque
// main : ni bouclier ni objet de main gauche (orbe).
bool SolAzeroth::ArmePermise(Player* player, ItemTemplate const* modele)
{
    if (!modele)
        return true;
    Specialisation const* s = SpeParId(KitDe(player)->spe);
    if (!s || s->classe != player->getClass())
        return true;
    if (modele->InventoryType == INVTYPE_HOLDABLE || modele->InventoryType == INVTYPE_SHIELD)
        return std::find(s->competences.begin(), s->competences.end(), SORT_AMBIDEXTRIE) == s->competences.end();
    if (modele->Class != ITEM_CLASS_WEAPON)
        return true;
    switch (modele->SubClass)
    {
        case ITEM_SUBCLASS_WEAPON_AXE: case ITEM_SUBCLASS_WEAPON_AXE2: case ITEM_SUBCLASS_WEAPON_MACE:
        case ITEM_SUBCLASS_WEAPON_MACE2: case ITEM_SUBCLASS_WEAPON_POLEARM: case ITEM_SUBCLASS_WEAPON_SWORD:
        case ITEM_SUBCLASS_WEAPON_SWORD2: case ITEM_SUBCLASS_WEAPON_STAFF: case ITEM_SUBCLASS_WEAPON_EXOTIC:
        case ITEM_SUBCLASS_WEAPON_EXOTIC2: case ITEM_SUBCLASS_WEAPON_FIST: case ITEM_SUBCLASS_WEAPON_DAGGER:
        case ITEM_SUBCLASS_WEAPON_SPEAR:
        // Lot T0 des Tarides (décision 2 du comparatif) : les armes à distance passent aussi par « permises ». Aucune
        // spécialisation actuelle ne les permet ; le futur chasseur les permettra.
        case ITEM_SUBCLASS_WEAPON_BOW: case ITEM_SUBCLASS_WEAPON_GUN: case ITEM_SUBCLASS_WEAPON_CROSSBOW:
        case ITEM_SUBCLASS_WEAPON_THROWN: case ITEM_SUBCLASS_WEAPON_WAND:
            break;
        default:
            return true;
    }
    if (s->permises.empty())
        return true;
    return std::find(s->permises.begin(), s->permises.end(), modele->SubClass) != s->permises.end();
}

class spell_solazeroth_v3_rempart : public AuraScript
{
    PrepareAuraScript(spell_solazeroth_v3_rempart);

    // Un coup absorbé remplit aussi le Rempart (le moteur retire ensuite la part absorbée).
    void Absorbe(AuraEffect* effet, DamageInfo& /*degats*/, uint32& absorbe)
    {
        Unit* cible = GetTarget();
        int32 apport = int32(std::lround(absorbe * reglages.part / 100.0f));
        effet->SetAmount(std::min(effet->GetAmount() + apport, Plafond(cible) + int32(absorbe)));
    }

    void Register() override
    {
        AfterEffectAbsorb += AuraEffectAbsorbFn(spell_solazeroth_v3_rempart::Absorbe, EFFECT_0);
    }
};

class spell_solazeroth_v3_frappe_bouclier : public SpellScript
{
    PrepareSpellScript(spell_solazeroth_v3_frappe_bouclier);

    void Remplir()
    {
        if (Unit* lanceur = GetCaster())
            Ajouter(lanceur, int32(std::lround(lanceur->GetMaxHealth() * reglages.frappe / 100.0f)));
    }

    void Register() override
    {
        AfterHit += SpellHitFn(spell_solazeroth_v3_frappe_bouclier::Remplir);
    }
};

// Cri de défi : chaque ennemi attiré remplit le Rempart. Il atterrit au contact, de son côté, et non sur le guerrier
// (l'attraction du moteur le posait sur sa tête, essai du 31/10/2026).
class spell_solazeroth_v3_cri_defi : public SpellScript
{
    PrepareSpellScript(spell_solazeroth_v3_cri_defi);

    void Remplir(SpellEffIndex effet)
    {
        Unit* lanceur = GetCaster();
        Unit* cible = GetHitUnit();
        if (!lanceur || !cible)
            return;
        PreventHitDefaultEffect(effet);
        float x, y, z;
        lanceur->GetContactPoint(cible, x, y, z, 1.0f);
        float vitesse = GetSpellInfo()->Effects[effet].MiscValue * 0.1f;
        cible->GetMotionMaster()->MoveJump(x, y, z, vitesse, cible->GetExactDist(x, y, z) / vitesse * 0.5f * Movement::gravity);
        Ajouter(lanceur, int32(std::lround(lanceur->GetMaxHealth() * reglages.criDefi / 100.0f)));
    }

    void Register() override
    {
        OnEffectHitTarget += SpellEffectFn(spell_solazeroth_v3_cri_defi::Remplir, EFFECT_0, SPELL_EFFECT_PULL_TOWARDS);
    }
};

// Riposte du rempart et Second souffle : consomment tout le Rempart au lancement.
class ConsommeLeRempart : public SpellScript
{
protected:
    int32 consomme = 0;

    SpellCastResult Verifier()
    {
        return GetCaster() && Montant(GetCaster()) > 0 ? SPELL_CAST_OK : SPELL_FAILED_CASTER_AURASTATE;
    }

    void Consommer()
    {
        if (Unit* lanceur = GetCaster())
            consomme = Vider(lanceur);
    }
};

class spell_solazeroth_v3_riposte : public ConsommeLeRempart
{
    PrepareSpellScript(spell_solazeroth_v3_riposte);

    void Frapper()
    {
        SetHitDamage(int32(consomme * 1.5f));
    }

    void Register() override
    {
        OnCheckCast += SpellCheckCastFn(spell_solazeroth_v3_riposte::Verifier);
        BeforeCast += SpellCastFn(spell_solazeroth_v3_riposte::Consommer);
        OnHit += SpellHitFn(spell_solazeroth_v3_riposte::Frapper);
    }
};

class spell_solazeroth_v3_second_souffle : public ConsommeLeRempart
{
    PrepareSpellScript(spell_solazeroth_v3_second_souffle);

    void Soigner()
    {
        SetHitHeal(consomme);
    }

    void Register() override
    {
        OnCheckCast += SpellCheckCastFn(spell_solazeroth_v3_second_souffle::Verifier);
        BeforeCast += SpellCastFn(spell_solazeroth_v3_second_souffle::Consommer);
        OnHit += SpellHitFn(spell_solazeroth_v3_second_souffle::Soigner);
    }
};

class spell_solazeroth_v3_ravage : public SpellScript
{
    PrepareSpellScript(spell_solazeroth_v3_ravage);

    size_t touches = 0;

    void Compter(std::list<WorldObject*>& cibles)
    {
        touches = cibles.size();
    }

    void Frapper()
    {
        SetHitDamage(int32(GetHitDamage() * (1.0f + 0.1f * std::min<size_t>(touches, 5))));
    }

    void Register() override
    {
        OnObjectAreaTargetSelect += SpellObjectAreaTargetSelectFn(spell_solazeroth_v3_ravage::Compter, EFFECT_0, TARGET_UNIT_SRC_AREA_ENEMY);
        OnHit += SpellHitFn(spell_solazeroth_v3_ravage::Frapper);
    }
};

class spell_solazeroth_v3_vengeance : public SpellScript
{
    PrepareSpellScript(spell_solazeroth_v3_vengeance);

    SpellCastResult Verifier()
    {
        Unit* lanceur = GetCaster();
        return lanceur && Montant(lanceur) > 0 && Montant(lanceur) >= Plafond(lanceur) - 1
            ? SPELL_CAST_OK : SPELL_FAILED_CASTER_AURASTATE;
    }

    void Register() override
    {
        OnCheckCast += SpellCheckCastFn(spell_solazeroth_v3_vengeance::Verifier);
    }
};

class spell_solazeroth_v3_dernier_rempart : public SpellScript
{
    PrepareSpellScript(spell_solazeroth_v3_dernier_rempart);

    void Remplir()
    {
        if (Unit* lanceur = GetCaster())
            Fixer(lanceur, Plafond(lanceur));
    }

    void Register() override
    {
        AfterHit += SpellHitFn(spell_solazeroth_v3_dernier_rempart::Remplir);
    }
};

// ---------------------------------------------------------------- Joueur

class solazeroth_v3_kit_unites : public UnitScript
{
public:
    solazeroth_v3_kit_unites() : UnitScript("solazeroth_v3_kit_unites", true, { UNITHOOK_ON_DAMAGE }) { }

    // Dégâts réellement subis (après l'armure et le Rempart) : la part absorbée passe par l'AuraScript.
    void OnDamage(Unit* attaquant, Unit* victime, uint32& degats) override
    {
        if (degats && attaquant && attaquant != victime && victime->IsAlive() && PorteLeRempart(victime))
            Ajouter(victime, int32(std::lround(degats * reglages.part / 100.0f)));
    }
};

class solazeroth_v3_kit_joueur : public PlayerScript
{
public:
    solazeroth_v3_kit_joueur() : PlayerScript("solazeroth_v3_kit_joueur", {
        PLAYERHOOK_ON_CREATE, PLAYERHOOK_ON_LOGIN, PLAYERHOOK_ON_FIRST_LOGIN, PLAYERHOOK_ON_UPDATE, PLAYERHOOK_ON_DELETE }) { }

    // F5d (31/10/2026) : le guerrier naît sans ses anciens sorts (Frappe héroïque, Posture de combat…) ni barre
    // d'action. Sinon Appliquer les retire à la première connexion, et le jeu l'annonce dans la discussion.
    // Le personnage est déjà enregistré : on corrige la base avant sa première connexion. Lot D1 : le démoniste aussi.
    void OnPlayerCreate(Player* player) override
    {
        Specialisation const* classe = PremiereDeLaClasse(player->getClass());
        if (!classe)
            return;
        uint32 guid = player->GetGUID().GetCounter();
        std::string sorts;
        for (auto const& [sort, etat] : player->GetSpellMap())
            if (SpellInfo const* info = sSpellMgr->GetSpellInfo(sort))
                if (info->SpellFamilyName == classe->famille)
                    sorts += (sorts.empty() ? "" : ",") + std::to_string(sort);
        if (!sorts.empty())
            CharacterDatabase.DirectExecute("DELETE FROM character_spell WHERE guid = {} AND spell IN ({})", guid, sorts);
        CharacterDatabase.DirectExecute("DELETE FROM character_action WHERE guid = {}", guid);
    }

    // F5d (31/10/2026) : le personnage commence sans arme ; la première vient des quêtes de Durotar.
    void OnPlayerFirstLogin(Player* player) override
    {
        for (uint8 emplacement : { EQUIPMENT_SLOT_MAINHAND, EQUIPMENT_SLOT_OFFHAND, EQUIPMENT_SLOT_RANGED })
            if (player->GetItemByPos(INVENTORY_SLOT_BAG_0, emplacement))
                player->DestroyItem(INVENTORY_SLOT_BAG_0, emplacement, true);
    }

    void OnPlayerLogin(Player* player) override
    {
        Kit* kit = KitDe(player);
        if (QueryResult r = CharacterDatabase.Query("SELECT spe, equipees FROM solazeroth_v3_kit WHERE guid = {}",
            player->GetGUID().GetCounter()))
        {
            kit->spe = (*r)[0].Get<uint8>();
            std::istringstream flux((*r)[1].Get<std::string>());
            for (uint32 sort; flux >> sort;)
                kit->equipees.push_back(sort);
        }
        // Le kit s'applique au premier passage de OnPlayerUpdate, une fois la puissance calculée (v3_combat.cpp).
        if (ClasseGeree(player) && kit->spe == SPE_AUCUNE)
            ChatHandler(player->GetSession()).SendSysMessage("|cff40c0ffChoisis ta spécialisation : carnet Techniques (touche K), onglet Spécialisation.|r");
    }

    void OnPlayerUpdate(Player* player, uint32 diff) override
    {
        Kit* kit = KitDe(player);
        kit->attente += diff;
        kit->attenteRempart += diff;

        if (kit->attenteRempart >= TICK_REMPART && kit->spe == SPE_GUERRIER_TANK)
        {
            kit->attenteRempart = 0;
            std::string message = Acore::StringFormat("REMPART;{};{}", Montant(player), Plafond(player));
            if (message != kit->rempartEnvoye)
            {
                kit->rempartEnvoye = message;
                SolAzeroth::EnvoyerAddon(player, PREFIXE, message);
            }
        }

        if (kit->attente < TICK_KIT)
            return;
        kit->attente = 0;
        // Le Rempart est renvoyé au moins toutes les 2 s : l'interface v3 (F4) le retrouve après un /reload.
        kit->rempartEnvoye.clear();
        if (!ClasseGeree(player))
            return;
        if (!kit->applique || (kit->spe != SPE_AUCUNE && Debloquees(player) != kit->debloquees))
            Appliquer(player);
        if (kit->spe == SPE_GUERRIER_TANK && !player->IsInCombat() && player->IsAlive())
            Fixer(player, Montant(player) - std::max(1, int32(player->GetMaxHealth() * reglages.fuite / 100.0f)));
    }

    void OnPlayerDelete(ObjectGuid guid, uint32 /*compte*/) override
    {
        CharacterDatabase.Execute("DELETE FROM solazeroth_v3_kit WHERE guid = {}", guid.GetCounter());
    }
};

class solazeroth_v3_kit_monde : public WorldScript
{
public:
    solazeroth_v3_kit_monde() : WorldScript("solazeroth_v3_kit_monde", { WORLDHOOK_ON_AFTER_CONFIG_LOAD }) { }

    void OnAfterConfigLoad(bool /*reload*/) override
    {
        reglages.part = sConfigMgr->GetOption<float>("SolAzeroth.V3.Rempart.Part", 40.0f);
        reglages.plafond = sConfigMgr->GetOption<float>("SolAzeroth.V3.Rempart.Plafond", 30.0f);
        reglages.fuite = sConfigMgr->GetOption<float>("SolAzeroth.V3.Rempart.Fuite", 1.0f);
        reglages.frappe = sConfigMgr->GetOption<float>("SolAzeroth.V3.Rempart.FrappeBouclier", 8.0f);
        reglages.criDefi = sConfigMgr->GetOption<float>("SolAzeroth.V3.Rempart.CriDefi", 3.0f);
    }
};

class solazeroth_v3_kit_commandes : public CommandScript
{
public:
    solazeroth_v3_kit_commandes() : CommandScript("solazeroth_v3_kit_commandes") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable kit =
        {
            { "",        HandleEtat,    SEC_PLAYER, Console::No },
            { "spe",     HandleSpe,     SEC_PLAYER, Console::No },
            { "equiper", HandleEquiper, SEC_PLAYER, Console::No },
        };
        static ChatCommandTable commandes =
        {
            { "kit", kit },
        };
        return commandes;
    }

    static bool HandleEtat(ChatHandler* handler)
    {
        Envoyer(handler->GetPlayer());
        return true;
    }

    // .kit spe tank|affliction : choix de la spécialisation, une fois pour toutes (le changement viendra plus tard).
    static bool HandleSpe(ChatHandler* handler, std::string nom)
    {
        Player* player = handler->GetPlayer();
        Kit* kit = KitDe(player);
        Specialisation const* choisie = nullptr;
        for (Specialisation const& s : SPECIALISATIONS)
            if (s.classe == player->getClass() && nom == s.cle)
                choisie = &s;
        if (!choisie)
        {
            handler->SendErrorMessage("Spécialisations prêtes : guerrier tank (.kit spe tank), démoniste Affliction "
                "(.kit spe affliction), voleur Assassinat (.kit spe assassinat).");
            return false;
        }
        if (kit->spe != SPE_AUCUNE)
        {
            handler->SendErrorMessage("Ta spécialisation est déjà choisie.");
            return false;
        }
        kit->spe = choisie->id;
        // Armes de la spécialisation, si les mains sont vides : Épée courte usée et Vieux bouclier en bois ; Dague usée ;
        // deux Dagues usées.
        for (uint32 competence : choisie->competences)
            if (!player->HasSpell(competence))
                player->learnSpell(competence);
        for (auto [emplacement, objet] : choisie->armes)
        {
            uint16 destination;
            if (!player->GetItemByPos(INVENTORY_SLOT_BAG_0, emplacement)
                && player->CanEquipNewItem(emplacement, destination, objet, false) == EQUIP_ERR_OK)
                player->EquipNewItem(destination, objet, true);
        }
        kit->equipees.clear();
        kit->debloquees = 0;
        kit->applique = false;
        Sauver(player);
        // La première barre (boutons 1 à 12) ne garde que les techniques : Attaque et sorts de départ en sont retirés.
        for (uint8 bouton = 0; bouton < 12; ++bouton)
            player->removeActionButton(bouton);
        Appliquer(player);
        handler->PSendSysMessage("|cff40c0ffSpécialisation choisie : {}. {} et tes premières techniques sont prêts.|r",
            choisie->nom, choisie->id == SPE_GUERRIER_TANK ? "Le Rempart"
                : choisie->id == SPE_DEMONISTE_AFFLICTION ? "La Moisson" : "Les Toxines");
        return true;
    }

    // .kit equiper <sort> … : autant de techniques débloquées que d'emplacements, hors combat. Les places libres se
    // remplissent dans l'ordre.
    static bool HandleEquiper(ChatHandler* handler, Tail liste)
    {
        Player* player = handler->GetPlayer();
        Kit* kit = KitDe(player);
        if (kit->spe == SPE_AUCUNE)
        {
            handler->SendErrorMessage("Choisis d'abord ta spécialisation.");
            return false;
        }
        if (player->IsInCombat())
        {
            handler->SendErrorMessage("Les techniques se changent hors combat.");
            return false;
        }
        std::vector<Technique> const& ordre = OrdreDe(player);
        uint32 debloquees = Debloquees(player);
        size_t emplacements = Emplacements(ordre, debloquees);
        std::vector<uint32> equipees;
        std::istringstream flux{ std::string(liste) };
        for (uint32 sort; flux >> sort;)
        {
            if (!EstTechnique(ordre, sort) || !EstDebloquee(ordre, sort, debloquees))
            {
                handler->SendErrorMessage("Technique inconnue ou pas encore débloquée.");
                return false;
            }
            if (std::find(equipees.begin(), equipees.end(), sort) == equipees.end())
                equipees.push_back(sort);
        }
        if (equipees.size() > emplacements)
        {
            handler->SendErrorMessage("{} techniques au plus pour l'instant : d'autres emplacements s'ouvriront.", emplacements);
            return false;
        }
        kit->equipees = equipees;
        Sauver(player);
        Appliquer(player);
        std::string noms;
        for (uint32 sort : kit->equipees)
            noms += (noms.empty() ? "" : ", ") + std::string(NomDe(sort));
        handler->PSendSysMessage("Techniques équipées : {}.", noms);
        return true;
    }
};

void AddSC_solazeroth_v3_kit()
{
    new solazeroth_v3_kit_unites();
    new solazeroth_v3_kit_joueur();
    new solazeroth_v3_kit_monde();
    new solazeroth_v3_kit_commandes();
    RegisterSpellScript(spell_solazeroth_v3_rempart);
    RegisterSpellScript(spell_solazeroth_v3_frappe_bouclier);
    RegisterSpellScript(spell_solazeroth_v3_cri_defi);
    RegisterSpellScript(spell_solazeroth_v3_riposte);
    RegisterSpellScript(spell_solazeroth_v3_second_souffle);
    RegisterSpellScript(spell_solazeroth_v3_ravage);
    RegisterSpellScript(spell_solazeroth_v3_vengeance);
    RegisterSpellScript(spell_solazeroth_v3_dernier_rempart);
}
