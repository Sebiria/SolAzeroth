# Sol'Azeroth

**World of Warcraft: Wrath of the Lich King (3.3.5a) en 100 % solo et hors ligne, sur [AzerothCore](https://www.azerothcore.org/).**

Pas de bots, pas de recherche de groupe, pas d'hôtel des ventes. Chaque donjon et chaque raid est réglé pour un seul joueur. Une progression longue remplace la boucle du MMO : rangs de menace, contrats, collections et trois fins.

> ⚠️ Projet en cours. Plusieurs fonctions sont construites mais pas encore testées en jeu. La feuille de route est dans `docs/`.

## Fonctions

**Personnage et compte**
- Toutes les races avec toutes les classes (mod-arac).
- Grimoire universel : on achète les sorts et les maîtrises d'armes et d'armures des autres classes. Chaque classe reçoit les ressources nécessaires (rage, énergie, puissance runique…).
- Talents d'une autre classe : des points dans un arbre d'une deuxième classe.
- Cinq spécialisations par personnage, chacune avec ses talents et ses glyphes.
- Métiers partagés sur le compte, bonus de compte, banque de compte.
- Ligues : Hardcore, Destin et Légende.

**Donjons et raids**
- Mise à l'échelle solo de tous les donjons et raids (mod-autobalance, réglé).
- **Rang de menace** du compte (rangs 0 à 5 et plus), avec Fortifié / Tyrannique, affixes de mécanique et affixes à points.
- Défis de boss avec récompense, butin des boss de donjon au choix, protection contre la malchance.
- Tous les raids du Norfendre étudiés boss par boss. Les mécaniques qui demandent un groupe sont adaptées pour un joueur seul (Naxxramas, Ulduar, l'épreuve du croisé, la citadelle de la Couronne de glace). Le guide de stratégie est dans `docs/`.
- Écart d'équipement : être sous-équipé ou bien équipé change les dégâts faits et reçus.

**Boucles de jeu**
- Tableau de contrats (chasses et donjons) avec réserve du compte, primes de zone, thème de la semaine.
- Mode défi en extérieur : monde plus dur, meilleures récompenses.
- Chaîne d'histoire en 16 chapitres jusqu'au Roi-liche, avec générique pour la fin « Histoire ».
- Codex, Renom, journal de collection, 50 hauts faits de compte, Marques du voyageur comme monnaie, intendants.
- PNJ d'ambiance qui font vivre Hurlevent. Les autres capitales suivront, puis les villes, les routes et les camps du monde entier.

**Confort**
- Lanceur en un clic : MySQL, connexion, monde, puis le jeu. Sauvegardes automatiques et manuelles, migrations SQL versionnées avec retour arrière.
- Une vingtaine d'addons (sacs, plaques de nom, grimoire, talents, contrats, journal de collection…) derrière un seul bouton de la minicarte. Une interface unifiée et redessinée est en cours.

## Contenu du dépôt

| Dossier | Contenu |
| --- | --- |
| `modules/mod-solazeroth` | Le module C++ pour AzerothCore (l'essentiel du jeu) |
| `lua_scripts` | Scripts ALE (Lua) |
| `sql/migrations` | Changements de base versionnés (`NNN_nom.up.sql` / `.down.sql`) |
| `addons` | Addons du client (copiés dans le jeu par le lanceur) |
| `scripts` | Lanceur, migrations, sauvegardes, configuration du serveur (PowerShell) |
| `outils` | Outils Python : lire et écrire les fichiers MPQ et DBC, construire le patch client |
| `patches` | Correctif local de mod-challenge-modes |
| `docs` | Document de conception et guide des raids en solo |

Aucun fichier de Blizzard n'est fourni : il faut son propre client 3.3.5a (build 12340).

## Installation

Les étapes sont détaillées dans [README.md](README.md#installation-windows) (en anglais). Le dépôt doit être cloné dans **`C:\SolAzeroth`**.

## Licence

[GPL-2.0](LICENSE), comme AzerothCore. World of Warcraft est une marque de Blizzard Entertainment ; ce projet n'est pas affilié à Blizzard et ne contient aucun de ses fichiers.
