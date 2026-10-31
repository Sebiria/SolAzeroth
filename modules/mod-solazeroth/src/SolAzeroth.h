#ifndef SOLAZEROTH_H
#define SOLAZEROTH_H

#include <functional>
#include <string>
#include <vector>

class Creature;
class Item;
class Map;
class Player;

namespace SolAzeroth
{
    // Message pour un addon Sol'Azeroth (addon.cpp)
    void EnvoyerAddon(Player* player, std::string const& prefixe, std::string const& message);
    // v3 : pourcentage d'une zone, en centièmes de % (v3_zone.cpp).
    unsigned int PourcentZone(Player* player, unsigned int zone);
    // v3 : objets rangés dans la Collection, et retrait (v3_collection.cpp).
    unsigned int NombreEnCollection(Player* player, unsigned int objet);
    void RetirerDeCollection(Player* player, unsigned int objet, unsigned int nombre);
    // v3 : rang d'amélioration (0 à 5) d'une version d'équipement (v3_equipement.cpp).
    unsigned char RangEquipement(unsigned int entree);
    // Ligue Destin (défi choisi au niveau 1, lua_scripts/defis.lua) : ni sorts ni talents d'une autre classe (formation.cpp).
    bool EstDestin(Player* player);
    // Ligue Remix (ligues.cpp) : monde à ton niveau imposé (echelle.cpp).
    bool EstRemix(Player* player);
    // Niveau d'objet moyen équipé (rangs de menace compris) et ilvl attendu à un niveau (ecart.cpp).
    float IlvlEquipe(Player* player);
    float IlvlAttenduNiveau(unsigned char niveau);

    // v3 : puissance d'une créature = son niveau d'origine, avant d'être affichée au niveau 80 (v3_niveau.cpp).
    unsigned char PuissanceCreature(Creature const* creature);
    // v3 : puissance du personnage, moyenne de ses objets équipés (v3_combat.cpp).
    float PuissanceJoueur(Player* player);

    // Ajoute une ligne au journal de donjon de cette carte, s'il y en a un (journal.cpp)
    void Journaliser(Map const* map, std::string const& ligne);

    // Marque du voyageur (marques.cpp)
    unsigned int Marques(Player* player);
    bool DonnerMarques(Player* player, unsigned int nombre, std::string const& raison);
    bool RetirerMarques(Player* player, unsigned int nombre);

    // Donne un objet obtenu au rang de menace « rang », avec son enchantement de bonus (bonus.cpp).
    // nullptr si les sacs sont pleins.
    Item* DonnerObjetDeRang(Player* player, unsigned int objet, unsigned char rang);
    // Pose l'enchantement de bonus du rang sur un objet déjà reçu (butin de boss de raid ; bonus.cpp).
    void AppliquerRangObjet(Player* player, Item* item, unsigned char rang);

    // Intendant (intendant.cpp) : articles visibles « objet:niveau:marques:cuivre:emplacement:classe:sous-classe »,
    // et achat au rang 3.
    void ListerIntendant(Player* player, std::function<void(std::string const&)> const& ajouter);
    void AcheterIntendant(Player* player, unsigned int objet);

    // Marques d'une quête rendue, augmentées selon le niveau de défi en extérieur le plus bas tenu pendant
    // la quête (defi_exterieur.cpp).
    unsigned int MarquesDefiExterieur(Player* player, unsigned int quete, unsigned int nombre);

    // Multiplicateurs appliqués à une créature selon le rang de menace de son instance et l'affixe de la semaine.
    // pv : la créature subit les dégâts divisés par ce nombre (elle « tient » pv fois plus longtemps).
    // degats : les dégâts de la créature sont multipliés par ce nombre.
    struct Modificateurs
    {
        float pv = 1.0f;
        float degats = 1.0f;
    };

    Modificateurs ModificateursMenace(Creature const* creature);

    // Rang de menace choisi pour une instance (0 si aucun) et nom de l'affixe de la semaine.
    unsigned char RangInstance(unsigned int instanceId);
    // Affixes de mécanique cochés pour une instance (bits : 1 Enragé, 2 Renforçant, 4 Volcanique, 8 Explosif), et palier
    // de butin = rang + points des affixes (au plus autant que le rang, minimum 1), plafonné au rang maximal (menace.cpp).
    unsigned char AffixesInstance(unsigned int instanceId);
    unsigned char PalierButin(Map const* map);
    // Personnage épuisé dans le raid où il se trouve (raids.cpp) : butin rare, or et Éclats réduits ou coupés.
    bool EpuiseRaid(Player const* player);
    // Affixes de mécanique (affixes_mecanique.cpp) : points d'une combinaison, lignes « bit;nom;points;description »
    // pour la fenêtre du rang, et noms lisibles.
    unsigned int PointsAffixes(unsigned char affixes);
    std::vector<std::string> ListeAffixesMecanique();
    std::string NomsAffixesMecanique(unsigned char affixes);
    // Note dans le journal de donjon une créature d'affixe, une fois son niveau et ses PV donnés (journal.cpp).
    void JournalApparition(Creature* creature);
    char const* AffixeDeLaSemaine();
    // Dernier boss d'un donjon (sa mort valide le donjon).
    bool EstBossFinal(unsigned int entree);
    // Plus haut rang de menace débloqué par le compte.
    unsigned char RangMenaceDebloque(unsigned int compte);

    // Contrats (contrats.cpp) : donjon réussi (identifiant LFGDungeons) au rang de menace « rang ».
    void ContratDonjonReussi(Player* player, unsigned int donjon, unsigned char rang);
    // Intendant : un objet au hasard parmi ceux que le personnage peut acheter (0 si aucun).
    unsigned int ObjetIntendantAuHasard(Player* player);

    // Hauts faits (hauts_faits.cpp) : fait avancer un compteur du compte, puis vérifie les hauts faits.
    void AjouterCompteur(Player* player, std::string const& cle, unsigned int nombre = 1);

    // Talents (talents_etrangers.cpp) : apprend un talent jusqu'au rang « rang » (0 = premier), de sa classe ou d'un
    // arbre étranger. Renvoie un message d'erreur, vide si le talent est appris.
    std::string ApprendreTalent(Player* player, unsigned int talentId, unsigned char rang);

    // Éclats de raid (malchance.cpp) : articles « objet:boss:éclats:prix:nom_boss », et échange.
    void ListerEclats(Player* player, std::function<void(std::string const&)> const& ajouter);
    void AcheterEclats(Player* player, unsigned int objet);

    // Hauts faits du compte obtenus et définis, sans ceux des fins du Codex (hauts_faits.cpp).
    void HautsFaitsDuCompte(unsigned int compte, unsigned int& obtenus, unsigned int& total);
    // Codex (codex.cpp) : pourcentage d'une fin (1 Histoire, 2 Maître, 3 100 %) pour le compte du joueur.
    float PourcentFinCodex(Player* player, unsigned char fin);
    // Heures du Codex accomplies par le compte (codex.cpp), source du Renom.
    float HeuresCodex(Player* player);
    // Renom du compte (renom.cpp) : rang de 0 à 10.
    unsigned char RangRenom(unsigned int compte);
    // Affixe choisi au menu par le compte (rang de Renom 5) : 0 alternance, 1 Fortifié, 2 Tyrannique.
    unsigned char AffixeChoisi(unsigned int compte);
    // Journal de collection (journal_collection.cpp) : objet de boss obtenu (corps, choix de butin, Éclats), et
    // objets collectionnés par le compte sur le total du journal.
    void Collectionner(Player* player, unsigned int objet);
    void JournalDeCollection(unsigned int compte, unsigned int& obtenus, unsigned int& total);
    // Bonus permanents des hauts faits (bonus_hauts_faits.cpp) : or des contrats en plus (0,10 = +10 %) et lignes pour « /hf ».
    float BonusOrContrats(Player* player);
    std::vector<std::string> LignesBonusHautsFaits(Player* player);
    // Écart d'équipement (ecart.cpp) : rang de menace d'un objet obtenu avec un enchantement de bonus.
    void NoterRangObjet(unsigned int guid, unsigned char rang);
    unsigned char RangDObjet(unsigned int guid);
}

void AddSC_solazeroth_menace();
void AddSC_solazeroth_bonus_solo();
void AddSC_solazeroth_reinitialisation();
void AddSC_solazeroth_butin();
void AddSC_solazeroth_journal();
void AddSC_solazeroth_formation();
void AddSC_solazeroth_banque();
void AddSC_solazeroth_pistage();
void AddSC_solazeroth_marques();
void AddSC_solazeroth_bonus();
void AddSC_solazeroth_defis_boss();
void AddSC_solazeroth_metiers();
void AddSC_solazeroth_specialisations();
void AddSC_solazeroth_defi_exterieur();
void AddSC_solazeroth_intendant();
void AddSC_solazeroth_contrats();
void AddSC_solazeroth_malchance();
void AddSC_solazeroth_ressources();
void AddSC_solazeroth_familiers();
void AddSC_solazeroth_talents_etrangers();
void AddSC_solazeroth_hauts_faits();
void AddSC_solazeroth_codex();
void AddSC_solazeroth_renom();
void AddSC_solazeroth_journal_collection();
void AddSC_solazeroth_bonus_hauts_faits();
void AddSC_solazeroth_ecart();
void AddSC_solazeroth_affixes_mecanique();
void AddSC_solazeroth_hardcore();
void AddSC_solazeroth_ambiance();
void AddSC_solazeroth_citadelle();
void AddSC_solazeroth_naxxramas();
void AddSC_solazeroth_ulduar();
void AddSC_solazeroth_croise();
void AddSC_solazeroth_histoire();
void AddSC_solazeroth_raids();
void AddSC_solazeroth_addon();
void AddSC_solazeroth_echelle();
void AddSC_solazeroth_ligues();
void AddSC_solazeroth_raids_anciens();
void AddSC_solazeroth_v3_niveau();
void AddSC_solazeroth_v3_combat();
void AddSC_solazeroth_v3_kit();
void AddSC_solazeroth_v3_journal();
void AddSC_solazeroth_v3_mort();
void AddSC_solazeroth_v3_bivouac();
void AddSC_solazeroth_v3_collection();
void AddSC_solazeroth_v3_carte();
void AddSC_solazeroth_v3_zone();
void AddSC_solazeroth_v3_gouffre();
void AddSC_solazeroth_v3_equipement();

#endif
