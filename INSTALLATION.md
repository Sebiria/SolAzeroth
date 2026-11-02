# Installer Sol'Azeroth

Cinq minutes, et rien d'autre à installer. Tout tient dans un dossier, et tout reste sur ton PC.

## Ce qu'il te faut

- **Windows 10 ou 11** (64 bits).
- **Ton propre client World of Warcraft 3.3.5a (build 12340), en français (frFR).** Il n'est pas fourni et ne le sera pas : il appartient à Blizzard. Pour vérifier le tien : il y a un `Wow.exe` et un dossier `Data\frFR`.
- **6 Go libres** sur le disque (l'archive pèse 1,4 Go, 3,7 Go une fois extraite, et la base grossit un peu au premier lancement).

Pas besoin d'Internet pour jouer, ni de compte, ni de MySQL ou d'autre logiciel : tout est dans l'archive.

## 1. Télécharger

Va sur la page de la **[dernière version](../../releases/latest)** et prends **`SolAzeroth-<version>.zip`** (dans « Assets », en bas de la page).

<!-- Capture : images/installation-1-telechargement.png (la page de la version, le zip entouré) -->

## 2. Extraire

Clic droit sur le zip → **Extraire tout…** → choisis un dossier, par exemple `C:\Jeux\SolAzeroth`.

- **Évite `Program Files`** (Windows y bloque l'écriture) et les dossiers synchronisés comme OneDrive.
- Le chemin peut contenir des espaces et des accents.

<!-- Capture : images/installation-2-dossier.png (le dossier extrait, Sol'Azeroth.bat en évidence) -->

## 3. Lancer

Double-clique **`Sol'Azeroth.bat`**.

Windows peut se méfier d'un fichier téléchargé : s'il affiche **« Windows a protégé votre ordinateur »**, clique **Informations complémentaires** puis **Exécuter quand même** ; s'il demande « Voulez-vous ouvrir ce fichier ? », clique **Exécuter**. Le lanceur n'est qu'un script PowerShell lisible, dont les sources sont dans ce dépôt (`scripts\menu.ps1`).

## 4. Première fois : choisir le dossier de WoW

Une fenêtre demande **le dossier de ton client WoW**, celui qui contient `Wow.exe`. Le lanceur vérifie que c'est bien un client 3.3.5a français, puis prépare la base de jeu : **une à deux minutes**, une seule fois.

<!-- Capture : images/installation-3-dossier-wow.png (la fenêtre de choix de dossier) -->

## 5. Jouer

La fenêtre du lanceur s'ouvre :

<!-- Capture : images/installation-4-lanceur.png (le menu du lanceur) -->

Clique **Jouer**. Le serveur démarre, puis le jeu s'ouvre et **se connecte tout seul** : tu arrives directement sur la liste des personnages.

- Crée un **orc ou un troll**, **guerrier, démoniste ou voleur** : ce sont les seuls kits et la seule zone prêts (les autres choix sont grisés).
- **Ne ferme pas la fenêtre noire** du lanceur pendant que tu joues : c'est elle qui fait tourner le serveur et les sauvegardes automatiques.
- Pour quitter, ferme le jeu normalement. Le lanceur arrête le serveur proprement et **sauvegarde tes personnages**.

Les fois suivantes, double-clique `Sol'Azeroth.bat` puis **Jouer** : c'est tout.

## Mettre à jour

Quand une nouvelle version sort, pas besoin de tout retélécharger :

1. Sur la page de la [dernière version](../../releases/latest), prends le fichier **`SolAzeroth-<version>.solmaj`** (quelques dizaines de Mo).
2. Dans le lanceur, clique **Appliquer une mise à jour…** et choisis ce fichier.

Le lanceur vérifie le fichier, sauvegarde tes personnages, met le jeu à jour puis affiche les nouveautés. Tes personnages sont gardés. Tu peux sauter des versions : chaque `.solmaj` contient tout depuis la première.

## Signaler un bug

1. En jeu, **là où est le problème**, appuie sur **`!`** et décris ce qui ne va pas. Le lieu, la cible et ton personnage sont notés tout seuls.
2. Quand tu veux les envoyer, clique **Exporter** dans cette même fenêtre (ou **Exporter les signalements** dans le lanceur). Windows demande où enregistrer un fichier `.txt`.
3. Joins ce fichier à un **[ticket](../../issues/new?template=bug.md)**.

Une fois exportés, les signalements quittent le jeu : tu repars d'une liste vide.

<!-- Capture : images/installation-5-signalement.png (la fenêtre « ! » en jeu, bouton Exporter) -->

## Les autres boutons du lanceur

| Bouton | Ce qu'il fait |
| --- | --- |
| **Restaurer la dernière sauvegarde** | Remet personnages et compte à l'état de la dernière fermeture du jeu (une sauvegarde est faite à chaque fois). |
| **Dossier du client WoW…** | Si tu as déplacé ou changé ton client. |
| **Ouvrir le dossier du jeu** | Ouvre le dossier de Sol'Azeroth (sauvegardes dans `backups`, journaux dans `logs`). |

## En cas de souci

| Problème | Solution |
| --- | --- |
| « Wow.exe est introuvable » | Choisis le dossier qui contient directement `Wow.exe`, pas un dossier au-dessus. |
| « n'est pas la version 3.3.5a (12340) » | Ton client est d'une autre version : il faut un client 3.3.5a. |
| « Ce client n'est pas en français » | Il faut un client frFR (dossier `Data\frFR`). Les autres langues ne sont pas encore prises en charge. |
| Une fenêtre du lanceur n'apparaît pas pendant le jeu (export d'un signalement) | Elle est derrière le jeu : **Alt+Tab**. |
| Le jeu reste sur l'écran de connexion | Attends une minute (le serveur finit de démarrer), puis clique **Connexion**. Le compte est `SOLAZEROTH`, mot de passe `solazeroth` : il n'existe que sur ton PC. |
| Tu veux l'écran de connexion au lieu de la connexion automatique | Garde **Maj** enfoncée pendant que le jeu s'ouvre. |
| Ton antivirus bloque `mysqld.exe` ou `worldserver.exe` | Ce sont le MySQL officiel et le serveur AzerothCore compilé depuis ce dépôt. Autorise le dossier de Sol'Azeroth. |
| Le port 3310 est déjà pris | Un autre programme l'utilise : ferme-le, ou redémarre l'ordinateur. |
| Autre chose | Ouvre un [ticket](../../issues/new?template=bug.md) en joignant les fichiers du dossier `logs`. |

## Désinstaller

Supprime le dossier de Sol'Azeroth. Rien d'autre n'a été installé sur ton PC. Dans ton client WoW, tu peux supprimer `Data\frFR\patch-frFR-4.MPQ` et remettre dans `Data\frFR\realmlist.wtf` l'adresse de ton ancien serveur si tu joues ailleurs avec ce client (le lanceur y écrit `set realmlist 127.0.0.1`).
