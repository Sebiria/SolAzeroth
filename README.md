# Sol'Azeroth

**World of Warcraft: Wrath of the Lich King (3.3.5a) en 100 % solo et hors ligne, sur [AzerothCore](https://www.azerothcore.org/).**

Pas de bots, pas de recherche de groupe, pas d'hôtel des ventes. Sol'Azeroth n'est pas le jeu d'origine réglé pour le solo : c'est un autre jeu sur le même monde. Il n'a ni niveau visible, ni ressource, ni soigneur, et la progression se mesure en **puissance**.

**Peu de touches, des objectifs exigeants.** Huit techniques au plus et un camp, rien de plus à presser : la difficulté n'est pas dans un cycle de sorts, mais dans les objectifs. Les zones sont remaniées autour de quelques pôles qui rassemblent leurs quêtes, et elles prennent du temps : **Durotar demande à lui seul de nombreuses heures** de quêtes, de primes, de contrats, d'épreuves, de reliques et de fabrication avant d'être prêt pour son donjon.

<p align="center">
  <a href="../../releases/latest"><b>⬇ Télécharger</b></a> ·
  <a href="INSTALLATION.md"><b>Guide d'installation</b></a> ·
  <a href="../../issues/new?template=bug.md"><b>Signaler un bug</b></a>
</p>

> ⚠️ Projet en cours, **testeurs bienvenus**. Durotar, son donjon et trois classes sont jouables ; beaucoup de systèmes sont construits et simulés, mais pas encore testés en jeu. Le jeu est **en français** et demande un client 3.3.5a français. *English summary: [README.en.md](README.en.md).*

<!-- Captures : images/combat.png, images/carnet.png, images/paroles.png, images/carte.png -->

## Comment ce projet est fait

Sol'Azeroth est conçu par une personne qui ne programme pas ; **le code est écrit avec Claude (une IA)**. On le dit d'emblée : les projets « vibecodés » aux résultats bancals sont nombreux, et tu as le droit de savoir. Ce qu'on fait pour rester sérieux :

- **Chaque chiffre vient d'une simulation.** Le serveur journalise les combats, et des outils Python rejouent un personnage journalisé contre n'importe quel monstre. Les scripts de calibrage écrivent eux-mêmes leurs migrations SQL (par exemple `outils/calibre_3c.py` → `sql/migrations/111_v3_calibre_3c.up.sql`, « ne pas modifier à la main ») : chaque valeur remonte à sa simulation et à sa cible.
- **Le modèle est confronté au jeu.** `outils/tests_equilibrage.py` rejoue un vrai combat journalisé et vérifie, sur au moins 30 combats réels, que les durées simulées restent à 15 % près de la réalité.
- **Chaque changement de la base se défait.** 130 migrations numérotées, chacune avec son `.down.sql` ; une migration qui change des valeurs existantes garde d'abord les valeurs d'origine.
- **La conception précède le code.** Le document de conception v3 (`docs/`) date et justifie chaque décision, et garde une liste de questions ouvertes. Une check-list décrit l'intégration d'une classe ; chaque classe se calibre contre le guerrier, aux mêmes pièces.
- **On s'audite soi-même.** Un jury de relecteurs IA (game designers et profils de joueurs) a conclu que le jeu « ne tient pas encore sa promesse de difficulté » (aucune mort légitime en 292 combats journalisés). Les lots correctifs qui ont suivi sont dans l'historique.

## Jouer

En résumé (détails et dépannage dans le **[guide d'installation](INSTALLATION.md)**) :

1. Il te faut **ton propre client World of Warcraft 3.3.5a (build 12340), en français (frFR)**. Il n'est pas fourni et ne peut pas l'être : il appartient à Blizzard.
2. Télécharge `SolAzeroth-<version>.zip` dans la [dernière version](../../releases/latest) et extrais-le où tu veux (évite Program Files).
3. Double-clique **`Sol'Azeroth.bat`**. La première fois, choisis le dossier de WoW (celui de `Wow.exe`) ; la base se prépare en une à deux minutes.
4. Clique **Jouer**. La connexion se fait toute seule.

Rien à installer à côté : le téléchargement contient le serveur, un MySQL portable (il ne tourne que pendant le jeu, sur le port 3310), la base de départ, les données de cartes et le patch du client. Tout reste sur ton PC : le serveur n'écoute que ta machine (127.0.0.1).

**Mises à jour :** télécharge le fichier `.solmaj` de la nouvelle version, puis dans le lanceur, « Appliquer une mise à jour… ». Tes personnages sont gardés, et sauvegardés avant.

**Bugs :** appuie sur **`!`** en jeu là où est le problème, décris-le, puis « Exporter » : Windows demande où enregistrer un fichier `.txt`, à joindre à un [ticket](../../issues/new?template=bug.md).

## Ce qui se joue aujourd'hui

| | État |
| --- | --- |
| **Durotar** (puissance 1 à 11) | Une histoire réécrite de 30 quêtes, de la Vallée des épreuves à Tranchecolline, Sen'jin, les Îles de l'Écho et la Lame ardente. Primes, contrats journaliers, lieux à nettoyer, défis contre la montre à médailles, épreuve de vagues, 16 reliques cachées, 3 rares secrets. Testé en jeu. |
| **Gouffre de Ragefeu** | Ouvert à 60 % de Durotar : difficultés 1 à 5, un composant de donjon et 31 pièces bleues à fabriquer. |
| **Guerrier Protection** (orc, troll) | Kit complet : le passif **Rempart** (une part de chaque coup reçu devient un bouclier que les techniques dépensent). Testé en jeu. |
| **Démoniste Affliction** (orc, troll) | Kit complet, tissu, dagues et bâtons, seulement des invocations temporaires (pas de familier permanent). Construit et simulé ; essais en jeu en cours. |
| **Voleur Assassinat** (orc, troll) | Kit complet, cuir, deux dagues, poisons, Éventail de couteaux qui devient Assommer en Camouflage. Construit et simulé ; **pas encore testé en jeu**. |
| Autres races, classes et zones | Grisées à la création. Le reste du monde existe mais n'est pas encore remanié. |

## Le principe

- **Niveau caché et fixe.** En coulisses, personnages et monstres restent au niveau 80 ; le joueur ne voit jamais de niveau. Un monstre garde la force de son niveau d'origine, qui devient sa **puissance**.
- **La puissance vient de l'équipement.** Celle du personnage est le niveau d'objet moyen de ce qu'il porte, augmenté par les rangs d'amélioration. Face à un monstre plus fort, on perd 2 % de dégâts par point de puissance manquant.
- **Un combat sans ressource.** Ni rage, ni mana, ni énergie : quatre techniques à temps de recharge au départ, jusqu'à huit équipées à mesure que la puissance monte, et un passif d'identité par spécialisation. Tout coup porte ; l'armure retire un montant fixe à chaque coup ; il n'y a plus de menace, les monstres n'ont que le joueur à frapper.
- **Chaque zone se suffit à elle-même, et elle est remaniée.** Ses quêtes sont réécrites et rassemblées autour de quelques pôles ; celles qui envoyaient dans une autre zone sont écartées. Elle a son histoire, ses activités annexes, son donjon et un pourcentage de complétion. À 60 %, le donjon s'ouvre ; à 100 %, on y entre avec l'équipement pour être serein.
- **Des zones longues.** Les quêtes d'histoire ne font que la moitié d'une zone : l'autre moitié, ce sont les primes, les contrats journaliers, les lieux à nettoyer, les épreuves contre la montre, les vagues et les reliques cachées. L'équipement pour y faire face se fabrique et s'améliore avec ce qu'on récolte sur place.
- **Exigeant, mais juste.** La vie ne remonte que par le feu de camp, une potion unique améliorable et la régénération hors combat : ni nourriture, ni bandages, ni potions de Blizzard.

## Premiers pas

- **Crée un orc ou un troll** guerrier, démoniste ou voleur : ce sont les seuls kits et la seule zone prêts (les autres choix sont grisés).
- **Pas de niveau** : ta force est ta **puissance**, la moyenne des niveaux d'objet de ce que tu portes. Chaque monstre a la sienne ; face à plus puissant, tes coups portent moins.
- **Écoute les PNJ de la vallée** : aux premiers moments clés (premier combat, première récolte, premier feu, première mort…), ils expliquent la règle dans une fenêtre de répliques.
- **Récolte et fabrique** : plantes, filons et cuir se récoltent sans métier et vont dans la Collection (touche B) ; l'équipement se fabrique dans le carnet Artisanat (touche P).
- **Survis sans nourriture** : la vie remonte hors combat, au feu de camp et par ta potion unique, en combat.
- **Le Lexique (touche J)** garde une page par règle ; la touche **`!`** signale un bug.

## Systèmes

| Système | En bref |
| --- | --- |
| Équipement | Fabrication avec les matériaux récoltés, rangs 1 à 5 (+10 % chacun), désenchantement et enchantement, joaillerie réinventée pour les rangs 4 et 5, une version de chaque pièce par classe |
| Collection | Un inventaire exhaustif et sans limite de tous les objets à collectionner (matériaux, composants, reliques), à côté d'un sac de 50 places |
| Camp | Feu de camp (Repos, régénération) et potion, améliorés par des listes de courses |
| Mort et âme | La mort ramène à la pierre de foyer sans perte, mais coûte de l'âme ; une âme à zéro met fin au personnage |
| Rang d'aventurier | Rang de compte nourri par tout ce qu'on accomplit : titres, pierre de foyer plus rapide, montures (de 60 % à 150 %), modes de zone, Marques du voyageur |
| Réputation des donjons | Réputation de compte commune à toutes les instances, qui ouvre des passifs à choisir avant chaque donjon ; des passifs du monde extérieur aussi |
| Monnaies | Trois, chacune son rôle : les Marques du voyageur (primes, défis, camp, montures), l'or (fabrication, rangs d'objet, réparations) et les éclats cadavériques (rangs d'objet, âme) |

## Interface v3

L'interface est réécrite **dans les fichiers du jeu** (FrameXML et GlueXML, livrés dans le patch client), et non en addons : ce code garde les droits de Blizzard en combat. Elle apporte ses propres cadres du personnage et de la cible, son journal de quêtes, son suivi et sa fenêtre de dialogue, des épingles sur la carte et la mini-carte (quêtes, quêtes à refaire, primes, reliques), un suivi de zone, et six carnets qui rassemblent toutes les fenêtres. Les sources sont dans `interface-v3` ; `outils/interface_v3.py` et `outils/construire_patch.py` fabriquent le patch.

## Contenu du dépôt

| Dossier | Contenu |
| --- | --- |
| `modules/mod-solazeroth` | Le module C++ d'AzerothCore : systèmes v3 (`v3_*.cpp`) et systèmes v2 encore utilisés |
| `interface-v3` | L'interface du jeu réécrite (FrameXML / GlueXML) |
| `sql/migrations` | Changements versionnés de la base (`NNN_nom.up.sql` / `.down.sql`) |
| `outils` | Outils Python : générateurs de quêtes, de zones et d'objets, simulations de combat, lecture et écriture des MPQ et DBC, patch client, fabrication des versions (`publier_version.py`) |
| `scripts` | Menu du lanceur, installation, mises à jour, export des signalements, migrations, sauvegardes, configuration du serveur (PowerShell) |
| `patches` | Correctifs locaux : mod-challenge-modes, et points d'accroche de combat v3 ajoutés au moteur d'AzerothCore |
| `addons` | Addons que le lanceur copie encore dans le jeu (ceux de la v2 sont retirés) |
| `lua_scripts` | Scripts ALE (Lua) |
| `docs` | Documents de conception (v3, et v2 pour l'historique), check-list d'intégration d'une classe, guides d'essai, guide des raids en solo |

La version précédente (v2 : grimoire universel, ligues, raids mis à l'échelle…) est gardée sous le repère [`v2-final`](../../tree/v2-final).

## Compiler soi-même (Windows)

Pour les développeurs ; les joueurs prennent la [version publiée](../../releases/latest). Les scripts marchent depuis leur propre dossier ; `C:\SolAzeroth` sert d'exemple ci-dessous.

1. **Prérequis** — suivre le [guide Windows d'AzerothCore](https://www.azerothcore.org/wiki/windows-requirements) : Visual Studio 2022 (C++ pour le bureau), CMake, MySQL 8.4 (service nommé `MySQL84`), OpenSSL 3, Boost 1.81. Installer aussi Git et Python 3, puis `py -m pip install mpyq`.
2. **AzerothCore et modules** — cloner dans `C:\SolAzeroth\azerothcore` (versions utilisées par ce projet) :

   | Dépôt | Commit |
   | --- | --- |
   | [azerothcore-wotlk](https://github.com/azerothcore/azerothcore-wotlk) | `e6d767b` |
   | [mod-ale](https://github.com/azerothcore/mod-ale) | `84b85cc` |
   | [mod-arac](https://github.com/azerothcore/mod-arac) | `3f605e0` |
   | [mod-autobalance](https://github.com/azerothcore/mod-autobalance) | `1d707cb` |
   | [mod-challenge-modes](https://github.com/ZhengPeiRu21/mod-challenge-modes) | `1930525` |
   | [mod-individual-xp](https://github.com/azerothcore/mod-individual-xp) | `503471f` |
   | [mod-transmog](https://github.com/azerothcore/mod-transmog) | `327753a` |

   Les modules vont dans `azerothcore\modules\`. Appliquer `patches\mod-challenge-modes.patch` dans mod-challenge-modes et `patches\azerothcore-v3-combat.patch` dans azerothcore (`git apply`). Lier notre module : `mklink /J C:\SolAzeroth\azerothcore\modules\mod-solazeroth C:\SolAzeroth\modules\mod-solazeroth`.
3. **Compilation** — configurer avec CMake dans `C:\SolAzeroth\build`, puis compiler en `RelWithDebInfo`.
4. **Données du client** — extraire dbc, maps, vmaps et mmaps de son client dans `C:\SolAzeroth\data`, puis copier les trois DBC de `mod-arac\patch-contents\DBFilesContent` dans `C:\SolAzeroth\data\dbc`.
5. **Base** — créer les bases d'AzerothCore comme dans son guide (le serveur de jeu les remplit à son premier démarrage). Copier `config\mysql-acore.cnf.example` en `config\mysql-acore.cnf` et y mettre son accès MySQL.
6. **Configuration** — lancer `powershell -NoProfile -File scripts\configurer.ps1`. Il crée les `.conf` et applique les réglages de Sol'Azeroth (les accès à la base dans `worldserver.conf` / `authserver.conf` restent à régler soi-même).
7. **Patch client** — copier les trois mêmes DBC de mod-arac dans `patch-client\fichiers\DBFilesClient`, puis lancer `py outils\construire_patch.py`.
8. **Chemin du client** — copier `config\client.txt.example` en `config\client.txt` et y écrire le dossier qui contient `Wow.exe`.
9. **Compte** — lancer une fois `build\bin\RelWithDebInfo\worldserver.exe`, taper `account create <nom> <mot de passe>` et `account set gmlevel <nom> 3 -1`, puis `server shutdown 1`.
10. **Jouer** — double-cliquer `Jouer.bat`. Il applique les migrations SQL, démarre tout, copie les addons et le patch dans le client, et sauvegarde les personnages à la fermeture. `Restaurer.bat` restaure la dernière sauvegarde.
11. **Publier une version** — `py outils\publier_version.py <version> --complet` fabrique l'archive des joueurs et la mise à jour `.solmaj` dans `dist\`.

## Contribuer

Les signalements (avec le `.txt` exporté), les retours de partie, les forks et les corrections sont les bienvenus. Le document de conception (`docs/`) explique chaque système et les décisions qui l'ont fait naître.

## Licence

[GPL-2.0](LICENSE), comme AzerothCore. L'archive des versions contient aussi MySQL Community Server (GPL-2.0, licence dans `mysql/LICENSE`). World of Warcraft est une marque de Blizzard Entertainment ; ce projet n'est affilié ni à Blizzard ni à AzerothCore, n'est pas un serveur public et ne rapporte rien. En dehors des données de cartes extraites du client 3.3.5a et des fichiers d'interface et de données modifiés du patch client, aucun fichier de Blizzard n'est distribué.
