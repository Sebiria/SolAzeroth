#ifndef SOLAZEROTH_H
#define SOLAZEROTH_H

#include <functional>
#include <string>
#include <vector>

class Creature;
class Item;
class Map;
class Player;
struct ItemTemplate;

namespace SolAzeroth
{
    // Message pour un addon Sol'Azeroth (addon.cpp)
    void EnvoyerAddon(Player* player, std::string const& prefixe, std::string const& message);
    // Dossier de l'installation (variable SOLAZEROTH_RACINE posée par le lanceur, sinon C:/SolAzeroth ; addon.cpp).
    std::string DossierRacine();
    // v3 : pourcentage d'une zone, en centièmes de % (v3_zone.cpp).
    unsigned int PourcentZone(Player* player, unsigned int zone);
    // v3 : objectifs de zone acquis, (zone, genre, clé) aux genres de solazeroth_v3_zone_parts, et zones qui ont des
    // parts (v3_zone.cpp ; rang d'aventurier).
    void ObjectifsAcquis(Player* player, std::function<void(unsigned int, unsigned char, unsigned int)> const& f);
    std::vector<unsigned int> ZonesAvecParts();
    // v3 : rang d'aventurier du compte (v3_aventurier.cpp) : modes de zone ouverts (0 aucun, 1 difficile, 2 cauchemar),
    // palier atteint et difficulté la plus haute ouverte dans un donjon (1 à 5 ; lot 5 : la suivante de la plus haute
    // réussie dans ce donjon).
    unsigned char ModesOuverts(Player* player);
    unsigned char PalierAventurier(Player* player);
    unsigned char DifficultesOuvertes(Player* player, unsigned int carte);
    // Lot 5 : objectifs d'artisan, une fois par compte (v3_aventurier.cpp ; les plats : la clé est l'entrée du plat).
    enum ObjectifArtisanCle : unsigned int { ARTISAN_VERTE = 1, ARTISAN_BLEUE, ARTISAN_RANG_3, ARTISAN_RANG_5,
        ARTISAN_TRANSFERT, ARTISAN_PLAN, ARTISAN_ENCHANTEMENT, ARTISAN_PIERRE_TAILLEE, ARTISAN_CONSOMMABLE };
    unsigned int const ARTISAN_NOMBRE = 9 + 5;   // et les 5 plats de Durotar
    void ObjectifArtisan(Player* player, unsigned int cle);
    // v3 : difficulté du donjon de cette carte (1 à 5 ; 0 hors donjon), techniques de ses monstres (masque) et verrou
    // (premier combat livré), et rang de réputation des donjons du compte (1 à 10) (v3_donjons.cpp).
    unsigned char DifficulteDonjon(Map* map);
    unsigned char TechniquesDonjon(Map* map);
    bool DonjonVerrouille(Map* map);
    unsigned char RangReputation(Player* player);
    unsigned int PointsReputation(Player* player);
    // v3 : passifs de donjon et du monde extérieur (v3_passifs.cpp ; numéros : outils\passifs_v3.py). PassifActif :
    // le passif est dans un emplacement du joueur et vaut là où il est (passifs de donjon en donjon, les autres dehors).
    enum Passif : unsigned char
    {
        PEAU_DE_BRAISE = 1, SOIF_DE_SANG, SECOND_SOUFFLE, EPINES, RECUPERATION, BOURREAU, ELAN, BRISE_CHEF,
        CONTRE_LA_MEUTE, FUREUR_DU_NOMBRE, PREMIER_SANG, CARRURE, MAIN_VIVE, CUIRASSE, PIED_SUR, FIN_DE_COMBAT,
        CONTRE_ATTAQUE, TENACE, DERNIER_REMPART, CHAROGNARD, PILLEUR_DE_FAILLE,
        EMBUSCADE = 31, CHASSEUR_DE_RARES, SOLITAIRE, NETTOYEUR, DEFI_TENU, MAUVAIS_OEIL, FIN_DE_TRAQUE, SECOND_VENT,
        INSTINCT_DE_FUITE, GORGEE_DE_PLUS, VEILLEE, GOURMET, AME_TENACE, CUEILLEUR, MAIN_EXPERTE, ECLATS_D_AVENTURE,
        CHASSEUR_DE_PRIMES, PAS_LEGER, RODEUR, FOYER_PROCHE, MARCHANDAGE
    };
    bool PassifActif(Player* player, unsigned char passif);
    // v3 : un monstre d'un lieu à nettoyer (v3_zone.cpp).
    bool MonstreDeLieu(unsigned int entree);
    // v3, lot T0 des Tarides : copie renforcée d'un chef de lieu (solazeroth_v3_lieux_chefs ; v3_zone.cpp).
    bool ChefRenforce(unsigned int entree);
    // v3, lot T0 des Tarides : ce qui empêche ce joueur d'entrer dans ce donjon (seuil de zone, quête : table
    // solazeroth_v3_donjons_seuils), message entier, ou une chaîne vide (v3_gouffre.cpp ; .teleportdonjon).
    std::string RefusDonjon(Player* player, unsigned int carte);
    // v3, lot 3b : chef renforcé du lieu tombé (v3_zone.cpp).
    bool LieuClos(Player* player, unsigned int lieu);
    // v3 : meilleure médaille d'un défi (0 aucune, 1 bronze, 2 argent, 3 or) et carte des reliques achetée (v3_annexes.cpp).
    unsigned char MedailleDefi(Player* player, unsigned int quete);
    // Lot 4a : défi répétable déjà payé plein tarif aujourd'hui (v3_annexes.cpp).
    bool DefiPayeAujourdhui(Player* player, unsigned int quete);
    bool CarteReliques(Player* player);
    // Lot 6b : rares secrets de la zone, « SECRETS;vaincus;total;noms » pour la fenêtre des objectifs, vide si la zone
    // n'en a pas (v3_rares_secrets.cpp) ; monture ajoutée aux montures du compte (v3_aventurier.cpp).
    std::string RaresSecrets(Player* player, unsigned int zone);
    void AjouterMontureCompte(Player* player, unsigned int sort);
    // Lot 4a : boucle de la semaine (v3_semaine.cpp) : affixe de la semaine (une technique de donjon, masque comme
    // TechniquesMonstre) et progrès de l'objectif de la semaine ; points de rang de l'objectif rempli (v3_aventurier.cpp).
    enum ObjectifSemaine : unsigned char { SEMAINE_DONJON = 1, SEMAINE_DEFIS, SEMAINE_ELITES };
    unsigned char AffixeSemaine();
    void ProgresSemaine(Player* player, unsigned char objectif);
    void PointsSemaine(Player* player, unsigned int semaine);
    // v3 : objets rangés dans la Collection, et retrait (v3_collection.cpp).
    unsigned int NombreEnCollection(Player* player, unsigned int objet);
    void RetirerDeCollection(Player* player, unsigned int objet, unsigned int nombre);
    // Range un objet collectionnable dans la Collection ; faux s'il ne l'est pas (v3_collection.cpp).
    bool AjouterACollection(Player* player, unsigned int objet, unsigned int nombre);
    // v3 : rang d'amélioration (0 à 5) d'une version d'équipement (v3_equipement.cpp).
    unsigned char RangEquipement(unsigned int entree);
    // v3 : caractéristique principale (STAT_STRENGTH, STAT_AGILITY ou STAT_INTELLECT) de la spécialisation (v3_kit.cpp).
    unsigned char CaracteristiquePrincipale(Player* player);
    // v3 : arme de mêlée que la spécialisation peut équiper (v3_kit.cpp ; règle appliquée par v3_armures.cpp).
    bool ArmePermise(Player* player, ItemTemplate const* modele);
    // v3 : la version d'une pièce du monde pour la classe du joueur, ou la pièce elle-même (v3_armures.cpp).
    unsigned int VersionDe(Player* player, unsigned int entree);
    // Ligue Destin (défi choisi au niveau 1, lua_scripts/defis.lua) : ni sorts ni talents d'une autre classe (formation.cpp).
    bool EstDestin(Player* player);
    // Ligue Remix (ligues.cpp) : monde à ton niveau imposé (echelle.cpp).
    bool EstRemix(Player* player);
    // Niveau d'objet moyen équipé (rangs de menace compris) et ilvl attendu à un niveau (ecart.cpp).
    float IlvlEquipe(Player* player);
    float IlvlAttenduNiveau(unsigned char niveau);

    // v3 : puissance d'une créature = son niveau d'origine, avant d'être affichée au niveau 80 (v3_niveau.cpp).
    unsigned char PuissanceCreature(Creature const* creature);
    // v3 : puissance haute conseillée d'une zone, 0 sans puissance conseillée (v3_niveau.cpp).
    unsigned char PuissanceHauteZone(unsigned int zone);
    // v3 : puissance du personnage, moyenne de ses objets équipés (v3_combat.cpp) ; de base : sans les rangs.
    float PuissanceJoueur(Player* player);
    float PuissanceDeBase(Player* player);
    // Lot 4a : la plus haute atteinte, sur laquelle les modes de zone se calent (v3_combat.cpp).
    float PuissanceDeBaseMax(Player* player);
    // v3, F9 : change la puissance d'une créature (v3_niveau.cpp) ; éclats du mode de zone et rare appelé par le
    // cauchemar (v3_modes.cpp).
    void FixerPuissanceCreature(Creature* creature, unsigned char puissance);
    float FacteurEclatsMode(Creature* creature);
    bool RareDeCauchemar(Creature* creature);
    // Lot 3a (02/11/2026) : techniques d'un monstre de mode (masque : 1 Enragé, 2 Renforçant, 4 Volcanique, 8 Explosif)
    // et leur force (1 ; 1,5 en cauchemar), pour l'interface (v3_modes.cpp).
    unsigned char TechniquesMonstre(Creature* creature);
    // Lot 5 : mode de zone d'un monstre du monde extérieur (2 difficile, 3 cauchemar ; 0 sinon) (v3_modes.cpp).
    unsigned char ModeMonstre(Creature* creature);
    float ForceTechniques(Creature* creature);

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
    // Charge les derniers boss (menace.cpp ; appelé aussi par v3_donjons.cpp, la v3 ne chargeant pas menace.cpp).
    void ChargerBossFinaux();
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
void AddSC_solazeroth_v3_cuisine();
void AddSC_solazeroth_v3_kit();
void AddSC_solazeroth_v3_fournisseur();
void AddSC_solazeroth_v3_semaine();
void AddSC_solazeroth_v3_paroles();
void AddSC_solazeroth_v3_rares_secrets();
void AddSC_solazeroth_v3_filons();
void AddSC_solazeroth_v3_demoniste();
void AddSC_solazeroth_v3_voleur();
void AddSC_solazeroth_v3_armures();
void AddSC_solazeroth_v3_journal();
void AddSC_solazeroth_v3_mort();
void AddSC_solazeroth_v3_bivouac();
void AddSC_solazeroth_v3_collection();
void AddSC_solazeroth_v3_carte();
void AddSC_solazeroth_v3_zone();
void AddSC_solazeroth_v3_annexes();
void AddSC_solazeroth_v3_gouffre();
void AddSC_solazeroth_v3_equipement();
void AddSC_solazeroth_v3_ame();
void AddSC_solazeroth_v3_modes();
void AddSC_solazeroth_v3_aventurier();
void AddSC_solazeroth_v3_donjons();
void AddSC_solazeroth_v3_passifs();
void AddSC_solazeroth_v3_inventaire();
void AddSC_solazeroth_v3_signalement();

#endif
