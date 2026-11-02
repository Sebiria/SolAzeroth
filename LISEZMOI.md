# Sol'Azeroth

**World of Warcraft: Wrath of the Lich King (3.3.5a) en 100 % solo et hors ligne, sur [AzerothCore](https://www.azerothcore.org/).**

Pas de bots, pas de recherche de groupe, pas d'hôtel des ventes. Depuis la version 3, Sol'Azeroth n'est plus le jeu d'origine réglé pour le solo : c'est un autre jeu sur le même monde. Il n'a ni niveau visible, ni ressource, ni soigneur, et la progression se mesure en **puissance**.

**Peu de touches, des objectifs exigeants.** Huit techniques au plus et un camp, rien de plus à presser : la difficulté n'est pas dans un cycle de sorts, mais dans les objectifs. Les zones sont remaniées autour de quelques pôles qui rassemblent leurs quêtes, et elles prennent du temps : **Durotar demande à lui seul de nombreuses heures** de quêtes, de primes, de contrats, d'épreuves, de reliques et de fabrication avant d'être prêt pour son donjon.

> ⚠️ Projet en cours. La première zone, Durotar, et son donjon sont jouables ; beaucoup de systèmes sont construits mais pas encore testés en jeu. La version précédente (v2 : grimoire universel, ligues, raids mis à l'échelle…) est gardée sous le repère [`v2-final`](../../tree/v2-final).

## Le principe

- **Niveau caché et fixe.** En coulisses, personnages et monstres restent au niveau 80 ; le joueur ne voit jamais de niveau. Un monstre garde la force de son niveau d'origine, qui devient sa **puissance**.
- **La puissance vient de l'équipement.** Celle du personnage est le niveau d'objet moyen de ce qu'il porte, augmenté par les rangs d'amélioration. Face à un monstre plus fort, on perd 2 % de dégâts par point de puissance manquant.
- **Un combat sans ressource.** Ni rage, ni mana, ni énergie : quatre techniques à temps de recharge au départ, jusqu'à huit équipées à mesure que la puissance monte, et un passif d'identité par spécialisation. Tout coup porte ; l'armure retire un montant fixe à chaque coup ; il n'y a plus de menace, les monstres n'ont que le joueur à frapper.
- **Chaque zone se suffit à elle-même, et elle est remaniée.** Ses quêtes sont réécrites et rassemblées autour de quelques pôles ; celles qui envoyaient dans une autre zone sont écartées. Elle a son histoire, ses activités annexes, son donjon et un pourcentage de complétion. À 60 %, le donjon s'ouvre ; à 100 %, on y entre avec l'équipement pour être serein.
- **Des zones longues.** Les quêtes d'histoire ne font que la moitié d'une zone : l'autre moitié, ce sont les primes, les contrats journaliers, les lieux à nettoyer, les épreuves contre la montre, les vagues et les reliques cachées. L'équipement pour y faire face se fabrique et s'améliore avec ce qu'on récolte sur place.
- **Exigeant, mais juste.** La vie ne remonte que par le feu de camp, une potion unique améliorable et la régénération hors combat : ni nourriture, ni bandages, ni potions de Blizzard. Tous les chiffres sont réglés par simulation de combat.

## Ce qui se joue aujourd'hui

**Durotar (puissance 1 à 11)**
- Une histoire réécrite de 30 quêtes, de la Vallée des épreuves à Tranchecolline, Sen'jin, les Îles de l'Écho et la Lame ardente, jusque dans le Gouffre de Ragefeu.
- Des activités annexes qui valent la moitié de la zone : lieux à nettoyer (avec chefs renforcés), primes, contrats journaliers, défis contre la montre avec médailles de bronze, d'argent et d'or, une épreuve de vagues avec record, et 16 reliques cachées (une carte qui les dévoile s'achète).
- **Le Gouffre de Ragefeu**, ouvert à 60 % : difficultés 1 à 5, chacune ouverte en réussissant la précédente, un composant de donjon (la Braise du Gouffre) et 31 pièces bleues à fabriquer avec.

**Guerrier tank**, première spécialisation au kit complet : le passif **Rempart** (une part de chaque coup reçu devient un bouclier que les techniques peuvent dépenser) et ses techniques.

## Premiers pas

- **Créer un orc ou un troll guerrier** : c'est le seul kit et la seule zone prêts (les autres choix sont grisés).
- **Pas de niveau** : ta force est ta **puissance**, la moyenne des niveaux d'objet de ce que tu portes. Chaque monstre a la sienne ; face à plus puissant, tes coups portent moins.
- **Écoute les PNJ de la vallée** : aux premiers moments clés (premier combat, première récolte, premier feu, première mort…), ils expliquent la règle dans une fenêtre de répliques, avec « Suivant » et « Fermer ».
- **Récolte et fabrique** : plantes, filons et cuir se récoltent sans métier et vont dans la Collection (touche B) ; l'équipement se fabrique dans le carnet Artisanat (touche P).
- **Survis sans nourriture** : la vie remonte hors combat, au feu de camp (assis une minute : le Repos au coin du feu et les charges de potion) et par ta potion unique, en combat.
- **Pas de monture tout de suite** : la monte s'ouvre au palier 10 du rang d'aventurier, vers la fin de Durotar.
- **Le Lexique (touche J)** garde une page par règle ; la touche « ! » signale un bug.

## Systèmes

| Système | En bref |
| --- | --- |
| Équipement | Fabrication avec les matériaux récoltés, rangs 1 à 5 (+10 % chacun), désenchantement et enchantement, joaillerie réinventée pour les rangs 4 et 5 |
| Collection | Un inventaire exhaustif et sans limite de tous les objets à collectionner (matériaux, composants, reliques), à côté d'un sac de 50 places |
| Camp | Feu de camp (Repos, régénération) et potion, améliorés par des listes de courses |
| Mort et âme | La mort ramène à la pierre de foyer sans perte, mais coûte de l'âme ; une âme à zéro met fin au personnage |
| Rang d'aventurier | Rang de compte nourri par tout ce qu'on accomplit : titres, pierre de foyer plus rapide, montures (de 60 % à 150 %), modes de zone, Marques du voyageur |
| Réputation des donjons | Réputation de compte commune à toutes les instances, qui ouvre des passifs à choisir avant chaque donjon ; des passifs du monde extérieur aussi |
| Monnaies | Trois, chacune son rôle : les Marques du voyageur (primes, défis, camp, montures), l'or (fabrication, rangs d'objet, réparations) et les éclats cadavériques (rangs d'objet, âme) |

## Interface v3

L'interface est réécrite **dans les fichiers du jeu** (FrameXML et GlueXML, livrés dans le patch client), et non en addons : ce code garde les droits de Blizzard en combat. Elle apporte ses propres cadres du personnage et de la cible, son journal de quêtes, son suivi et sa fenêtre de dialogue, des épingles sur la carte et la mini-carte (quêtes, quêtes à refaire, primes, reliques), un suivi de zone, et six carnets qui rassemblent toutes les fenêtres. Les sources sont dans `interface-v3` ; `outils/interface_v3.py` et `outils/construire_patch.py` fabriquent le patch.

## Équilibrage

Le serveur journalise les combats (`journaux/combat`), et les outils Python rejouent un personnage journalisé contre n'importe quel monstre : `outils/simulation_combat.py` et les outils bâtis dessus (camp, donjons, modes, âme, Gouffre de Ragefeu, primes). Les scripts de calibrage écrivent leurs propres migrations SQL : chaque chiffre remonte à une simulation.

## Contenu du dépôt

| Dossier | Contenu |
| --- | --- |
| `modules/mod-solazeroth` | Le module C++ d'AzerothCore : systèmes v3 (`v3_*.cpp`) et systèmes v2 encore utilisés |
| `interface-v3` | L'interface du jeu réécrite (FrameXML / GlueXML) |
| `sql/migrations` | Changements versionnés de la base (`NNN_nom.up.sql` / `.down.sql`) |
| `outils` | Outils Python : générateurs de quêtes, de zones et d'objets, simulations de combat, lecture et écriture des MPQ et DBC, patch client |
| `scripts` | Lanceur, migrations, sauvegardes, configuration du serveur (PowerShell) |
| `patches` | Correctifs locaux : mod-challenge-modes, et points d'accroche de combat v3 ajoutés au moteur d'AzerothCore |
| `addons` | Addons que le lanceur copie encore dans le jeu (ceux de la v2 sont retirés) |
| `lua_scripts` | Scripts ALE (Lua) |
| `docs` | Documents de conception (v3, et v2 pour l'historique) et guide des raids en solo |

Aucun fichier de Blizzard n'est inclus : il faut son propre client 3.3.5a (build 12340).

## Installation

Les étapes sont détaillées dans [README.md](README.md#installation-windows) (en anglais). Le dépôt doit être cloné dans **`C:\SolAzeroth`**.

## Licence

[GPL-2.0](LICENSE), comme AzerothCore. World of Warcraft est une marque de Blizzard Entertainment ; ce projet n'est pas affilié à Blizzard et ne contient aucun de ses fichiers.
