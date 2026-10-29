# WoW Solo — Document de conception v2

Oct 27, 2026 · @Sebiria

## 0. Instructions pour Claude Code

Ce document est la **seule source de vérité** du projet. Il remplace « WoW-Solo-Design » (v1) et les deux documents « Pistes pour un mode plus attrayant ». En cas de doute, c'est ce document qui fait foi.

**Statut des informations**

- Les noms de modules, clés de config, hooks et fichiers DBC cités sont des pistes à **vérifier dans le dépôt AzerothCore actuel** avant usage. Si quelque chose a changé ou n'existe pas, signale-le à l'utilisateur au lieu d'inventer.
- Les lignes marquées **(provisoire)** sont des décisions prises par défaut pour combler un trou. Elles sont listées en section 11 et peuvent changer.

**Boucle de travail**

- Avance étape par étape (section 10). On ne passe à l'étape suivante qu'une fois la précédente validée en jeu par l'utilisateur.
- Tu codes, l'utilisateur teste en jeu et te renvoie les logs (`worldserver`, `Server.log`, `Errors.log`, crash dumps) ou décrit le problème. Tu ne vois pas le client WoW.
- L'utilisateur ne sait pas programmer. Explique ce qu'il doit faire en étapes concrètes (quel fichier, quel bouton, quelle commande), sans jargon non expliqué.

**Ordre de préférence technique**

1. Une clé de config.
2. Un module existant.
3. Du custom en **Lua (ALE)** et SQL.
4. Un module C++ custom, seulement si ALE ne suffit pas.
5. Une modification du core, en tout dernier recours.

**Règles fixes**

- Utilise **ALE** (AzerothCore Lua Engine), pas l'ancienne API Eluna : les deux ont divergé.
- Reste sur le **core officiel d'AzerothCore**. Ne propose jamais mod-playerbots, NPCBots, leurs forks, ni mod-mythic-plus (inachevé et dépendant de NPCBots).
- Protège les sauvegardes : migrations SQL versionnées, et sauvegarde automatique avant chaque mise à jour.
- Le client WoW 3.3.5a est fourni par l'utilisateur. Ne propose jamais de le télécharger.
- Rien ne doit demander internet pour jouer. Tout tourne sur `127.0.0.1`. Les téléchargements nécessaires à l'installation et aux mises à jour (AzerothCore, MySQL, outils de compilation, modules) sont acceptés.
- L'utilisateur est sous **Windows 11**.
- Pas de patch client custom avant V7. Seule exception : le patch fourni avec mod-arac (section 3.1).
- Les **addons d'interface** (dossiers dans `Interface\AddOns` du client) sont acceptés : ce ne sont pas des patchs MPQ. Premier usage : le bouton « Sauvegarder » du menu Échap (section 2.4).

## 1. Vision et trois fins

WoW WotLK 3.3.5a (AzerothCore) devient un jeu **100 % solo, hors ligne et local**, avec trois fins emboîtées : Histoire (\~250 h), Maître (\~820 h) et 100 % (\~2 550 h).

### 1.1 Piliers

| Pilier | Description |
| --- | --- |
| Solo à 100 % | Tout le contenu se fait seul. Aucun bot joueur, même à terme. Des PNJ d'ambiance muets peuplent les villes (section 6.5). |
| Hors ligne | Serveur local, lancé en un clic. |
| L'équipement compte | Un équipement en retard se ressent en combat, présenté surtout comme un bonus quand on est bien équipé (section 5). |
| Liberté | Toutes les races avec toutes les classes. Sorts, armes et armures des autres classes achetables (section 3.9). Cinq spécialisations. Métiers partagés sur le compte. |
| Objectifs multiples | Quêtes, contrats, donjons à rang de menace, défis, collections, ligues. Tout alimente le Codex. |
| Rejouabilité plutôt que remplissage | La durée vient du choix et de la variété, pas d'un contenu étiré. Aucune obligation quotidienne qui se perd. |
| Économie sans hôtel des ventes | L'or vient des activités et reste cohérent avec les coûts. |

### 1.2 Les trois fins

Chaque fin est un vrai générique, avec un haut fait et un titre. Les heures sont cumulées et estimées à ±30 %. Au rythme probable de l'utilisateur (1,5 à 2 h par jour), c'est la fin « Maître » qui tombe vers un an.

| Fin | Heures cumulées | À 2 h/jour | Ce qu'il faut avoir fait |
| --- | --- | --- | --- |
| Histoire | \~250 h | \~4 mois | Un personnage niveau 80, la chaîne d'histoire, le Roi-liche vaincu en rang de menace 0 |
| Maître | \~820 h | \~13 mois | Donjons en rang 1-5, raids WotLK en rang 0-3, exploration et réputations principales, tous les métiers à 450, défis de base |
| 100 % | \~2 550 h | \~3 ans et demi | Tout le Codex, facultatif |

Au-delà du 100 %, les rangs de menace continuent sans butin supplémentaire, pour le score et les titres. La liste du 100 % reste finie.

### 1.3 Budget du Codex

Chaque ligne se découpe en morceaux de moins de 5 h. Ces heures sont à recaler après un mois de jeu réel, grâce à la mesure du temps par activité (dès V1).

| Ligne du Codex | Contenu | Heures | Fin |
| --- | --- | --- | --- |
| Histoire | Premier personnage 1-80, Roi-liche en rang 0 | 250 | Histoire |
| Donjons | Rang de menace 1-5 | 150 | Maître |
| Raids | Raids WotLK, rang 0-3 | 120 | Maître |
| Monde | Exploration, réputations principales, primes | 150 | Maître |
| Métiers | Les 11 métiers principaux et les 3 secondaires à 450 | 100 | Maître |
| Défis et hauts faits | Défis de boss de base | 50 | Maître |
| Donjons | Rang de menace 6-10 | 200 | 100 % |
| Raids | Rang 4-5 et anciens raids | 180 | 100 % |
| Monde | Toutes les réputations, élites rares, quêtes cachées, thèmes du mois | 250 | 100 % |
| Métiers | Recettes rares | 100 | 100 % |
| Classes | 9 classes secondaires au niveau 80, via les ligues | 500 | 100 % |
| Collections | Journal de collection à 80 %, montures, mascottes, apparences | 300 | 100 % |
| Défis et hauts faits | Défis restants, hauts faits cachés | 200 | 100 % |

- La ligne Raids compte les raids **en rang 0 avec un bonus solo**, pas des réécritures. Elle s'agrandit à chaque boss réécrit, et le pourcentage est recalculé.
- La ligne Monde « Maître » tient sans la mise à l'échelle du monde.

## 2. Socle technique

Le projet tourne sur le core officiel d'AzerothCore, sous Windows 11, avec ALE pour le custom et un seul patch client custom en V7.

### 2.1 Composants

- **Émulateur :** AzerothCore (WotLK 3.3.5a), core officiel.
- **Composants locaux :** MySQL ou MariaDB, `authserver`, `worldserver`, et le client WoW 3.3.5a de l'utilisateur.
- **Scripting :** ALE (AzerothCore Lua Engine) et SQL en priorité. Modules C++ seulement si ALE ne suffit pas.
- **Données :** extraction des maps, vmaps et mmaps depuis le client de l'utilisateur.
- **Plage d'ID réservée** à tout ce qui est custom (objets, PNJ, sorts, hauts faits) : à partir de 900000.
- **Migrations SQL versionnées :** chaque changement de base est un fichier numéroté, rejouable, et accompagné de son retour arrière.

### 2.2 Patch client (V7 uniquement)

- Un seul `patch-X.MPQ` custom, placé dans `Data/` du client, regroupant : monnaie visible (`CurrencyTypes.dbc`), hauts faits (`Achievement.dbc` et critères), onglet Codex, coûts étendus (`ItemExtendedCost.dbc`).
- Outils à évaluer : un éditeur DBC (WDBX Editor ou équivalent) et un éditeur MPQ (Ladik's MPQ Editor).
- **Règle :** tout DBC modifié côté client doit l'être à l'identique côté serveur (`data/dbc` et/ou tables `*_dbc` en base, selon le mécanisme d'AzerothCore).
- Avant V7, tout passe par des jetons dans les sacs, des PNJ et des menus (gossip).

### 2.3 Lanceur en un clic

Un script Windows (`.bat` ou PowerShell) qui :

1. démarre MySQL s'il ne tourne pas ;
2. démarre `authserver`, puis `worldserver` ;
3. attend que le worldserver soit prêt ;
4. lance `Wow.exe` avec `realmlist` réglé sur `127.0.0.1` ;
5. à la fermeture du jeu, arrête proprement le serveur et lance la sauvegarde (2.4).

### 2.3 bis Journal de donjon pour l'équilibrage (V2)

- Module C++ `mod-solazeroth` (`journal.cpp`). À chaque **nouvelle instance** de donjon ou de raid, le fichier `C:\SolAzeroth\journaux\<carte>_<nom>.log` est remplacé.
- Il contient : le personnage à l'entrée (niveau, talents, statistiques, chaque pièce d'équipement et niveau d'objet moyen), les réglages de difficulté (rang, affixe, autobalance), chaque monstre engagé avec ses PV et sa mana **actuels et d'origine**, chaque combat (durée, dégâts infligés et subis par seconde, soins reçus, PV restants), les sorts lancés par chaque monstre, les morts, et un résumé à la mort du dernier boss.
- **Boucle de travail :** l'utilisateur fait le donjon et le signale ; Claude lit le journal, compare avec le jeu d'origine et ne propose un réglage que s'il est vraiment nécessaire.
- Le lanceur se ferme seul quand on quitte WoW ; il ne reste ouvert qu'en cas d'erreur.
- **Affichage imposé à chaque lancement (demande de l'utilisateur du 29/10/2026)**, dans `Config.wtf` :
  - mode fenêtré agrandi (`gxWindow 1`, `gxMaximize 1`), parce que le plein écran donnait un écran noir au changement de fenêtre ;
  - curseur matériel (`gxCursor 1`) et images par seconde plafonnées (`maxFPS 120`, `maxFPSBk 30` en arrière-plan), contre les gels de l'écran de connexion quand la souris bouge.
  - **Vraie cause, trouvée ensuite** : l'onglet Mouzz de la Boîte à outils de l'utilisateur (halo et traînée du pointeur), lancé au démarrage de Windows. Il redessine une couche transparente sur les deux écrans à chaque mouvement de souris, et se remet au premier plan toutes les secondes. Corrigé dans la Boîte à outils : Mouzz se met en pause quand un jeu (plein écran, ou WoW) est au premier plan. Les réglages ci-dessus sont gardés : le fenêtré agrandi donne une fenêtre sans bordure, et Alt+Tab y est instantané.

### 2.4 Sauvegardes

- `mysqldump` des bases `acore_characters` et `acore_auth` à chaque fermeture.
- **Sauvegarde automatique pendant le jeu**, à un intervalle réglable par le joueur : 5 min, 10 min, 15 min, 30 min ou 1 h. Le réglage est stocké côté serveur et lu par le lanceur.
- **Sauvegarde manuelle** par un bouton « Sauvegarder » ajouté au menu Échap, via un addon d'interface.
- Avant chaque sauvegarde, le serveur enregistre tous les personnages en base, pour que la copie contienne les dernières minutes de jeu.
- Une sauvegarde complète (y compris `acore_world`) **avant chaque mise à jour** du serveur ou d'un module.
- Rotation : garder les 10 dernières sauvegardes automatiques ou manuelles, et toutes les sauvegardes d'avant mise à jour.
- Un script de restauration en une commande.

## 3. Personnage et compte

Toutes les races jouent toutes les classes, les métiers sont partagés sur le compte, et les ligues donnent une raison de recommencer un personnage.

### 3.1 Combinaisons race / classe libres (V1)

- Module existant : **mod-arac**. Il contient la partie serveur et un patch client, accepté dès V1 comme seule exception à la règle « pas de patch avant V7 » **(provisoire)**.
- En V7, le patch de mod-arac est fusionné dans le patch unique, pour n'avoir qu'un seul fichier MPQ custom.
- Défauts acceptés : quelques animations ou tenues de départ imparfaites.
- **Validation :** l'écran de création propose toutes les combinaisons, et un personnage atypique (Tauren mage, Gnome chaman) se crée, entre en jeu et apprend ses sorts.
- **Équipement sans faction (demande de l'utilisateur du 29/10/2026, migration 039)** : en solo, réserver une arme ou une armure à la Horde ou à l'Alliance n'a pas de sens, et des objets reçus refusaient de s'équiper (bagues de PvP « de légionnaire » ou « de protecteur », etc.). 2 499 armes et armures perdent leur limite de faction : drapeaux « Horde / Alliance seulement » retirés, races « toute l'Alliance » ou « toute la Horde » remplacées par « toutes ». Les limites de race unique, de classe, de niveau, de métier et de réputation restent. Valeurs d'origine gardées pour le retour arrière (`solazeroth_objets_faction_origine`).

### 3.2 Métiers partagés sur le compte (V0 puis V2)

- **Par config (V0) :** autoriser les 11 métiers principaux sur un personnage (`MaxPrimaryTradeSkill` dans `worldserver.conf`).
- **Progression ×2 (V0) :** `SkillGain.Crafting = 2`, `SkillGain.Gathering = 2` (noms exacts à vérifier). Éventuellement, ajuster `SkillChance.*` pour que les recettes jaunes et vertes montent plus souvent.
- **Partage sur le compte (V2), en ALE et SQL :**
  - une table `account_professions` (account\_id, skill\_id, valeur, max) et une table `account_recipes` (account\_id, spell\_id) ;
  - à chaque montée de compétence ou recette apprise, on écrit dans ces tables ;
  - à la connexion d'un personnage, on lui applique les métiers et recettes du compte ;
  - les métiers secondaires (cuisine, secourisme, pêche) sont partagés aussi.
- **Validation :** un personnage monte la forge à 150, un deuxième personnage du compte se connecte et a la forge à 150 avec les mêmes recettes.
- **Validé en jeu le 27/10/2026.** En C++ (`metiers.cpp`) plutôt qu'en ALE : ALE n'a pas d'événement de montée de compétence. Migration 024 : tables `solazeroth_metiers_compte` et `solazeroth_recettes_compte`.
  - Le personnage envoie ses métiers au compte à chaque sauvegarde, à la déconnexion et à la connexion. Le compte garde la meilleure valeur.
  - À la connexion, il reçoit tous les métiers et recettes du compte. Les spécialisations (armurier, ingénieur gnome…) sont partagées aussi. Les bonus raciaux de métier ne le sont pas.
  - Limite : un métier abandonné revient à la connexion suivante, puisque le compte le connaît encore.

### 3.3 Ligues (V1, V5, V8)

Le joueur lance quand il veut un personnage de saison avec une règle. Huit semaines sont un rythme conseillé, pas une date limite. À la fin, le personnage rejoint le compte avec ses récompenses.

| Ligue | Règle | Étape |
| --- | --- | --- |
| Hardcore | Mort définitive | V1 |
| Destin | Race et classe tirées au sort | V5 |
| Remix et Chaos | Règles changeantes, à définir | V8+ (après la mise à l'échelle du monde) |

- **mod-challenge-modes** (dépôt ZhengPeiRu21, installé en V1) fournit Hardcore. Il a été corrigé localement (signature d'un hook incompatible avec le core actuel) et traduit en français ; le correctif est dans `C:\SolAzeroth\patches\`.
- **Mort Hardcore sûre** (`hardcore.cpp`, 30/10/2026) : toute mort d'un personnage Hardcore (monstre, chute, noyade, lave…) est marquée et le personnage sauvegardé aussitôt dans la base. Ainsi, un serveur arrêté ou planté juste après la mort ne rend pas le personnage vivant. À la connexion, un personnage Hardcore mort est renvoyé à l'écran des personnages : la vérification du module ne fonctionnait pas.
- **Ligue Destin (construite le 30/10/2026, à valider en jeu)** : `lua_scripts/defis.lua`, addon `SolAzerothDefis`, migration 041 (`solazeroth_destin`), blocages dans `formation.cpp` et `talents_etrangers.cpp`. Décisions de l'utilisateur :
  - **tirer puis créer** : le client ne laisse pas modifier l'écran de création. Depuis n'importe quel personnage, la fenêtre des défis (`/defis`) a une ligne Destin avec un bouton « Tirer mon destin » qui tire une race et une classe. Les 90 combinaisons de mod-arac sont possibles, sans le chevalier de la mort, qui commence au niveau 55. On crée ensuite ce personnage : au niveau 1, sa fenêtre des défis propose le défi Destin, et le choisir utilise le tirage ;
  - un tirage par compte ; nouveau tirage possible **24 h après le précédent**, une fois celui-ci utilisé ou abandonné (bouton « Abandonner », avec confirmation). Le tirage est écrit en base **immédiatement** : se déconnecter ou arrêter le serveur ne permet pas de retirer ;
  - **pas de grimoire universel** : un personnage Destin ne peut ni acheter les sorts ni prendre les talents d'une autre classe. Les spécialisations et les maîtrises d'armes restent permises ;
  - **récompense comme les défis** : Destin est un défi de **4 points (provisoire)**, cumulable avec Hardcore et les autres. Il compte dans la note, donc dans l'or, les Marques et les titres des paliers.
- Le module propose aussi des défis cumulables, laissés actifs : Semi-Hardcore (perte de l'équipement et de l'or à la mort), Artisan (équipement fabriqué uniquement), Équipement modeste (qualité commune ou médiocre), XP lente (×0,5), XP très lente (×0,25), XP de quêtes uniquement. Son mode Iron Man est désactivé (section 9.2).

**Choix des défis (V1)**

- Une **fenêtre en addon** (`SolAzerothDefis`) s'ouvre seule à la première connexion d'un personnage de niveau 1 (55 pour le chevalier de la mort) : une ligne par défi avec icône, règle et points, des médaillons de récompenses, la note et le palier. Le choix est définitif ; « Plus tard » la referme jusqu'à la prochaine connexion.
- On la rouvre à tout moment par un **bouton autour de la minicarte**, déplaçable à la souris (position mémorisée par personnage), ou par `/defis`. Après le choix, elle affiche les défis en lecture seule.
- Les **Autels du défi** du module sont retirés (migration 010) : tout passe par l'addon et `lua_scripts/defis.lua`.
- **Note de difficulté** = somme des points des défis choisis **(provisoire)** : Hardcore 5, Destin 4, Semi-Hardcore 3, Artisan 3, Équipement modeste 2, XP très lente 2, XP de quêtes uniquement 2, XP lente 1. Ce n'est pas une monnaie : elle fixe le palier.
- **Paliers (provisoires)**, récompenses versées aux niveaux 20, 40, 60 et 80 :

| Palier | Note | Or (20 / 40 / 60 / 80) | En plus |
| --- | --- | --- | --- |
| Bronze | 3+ | 20 / 100 / 400 / 1 000 po | — |
| Argent | 6+ | × 2 | Titre « l'increvable » au 80 |
| Or | 10+ | × 3 | Titre « l'immortel » au 80 |
| Légende | 15+ | × 5 | Titre « l'infaillible vainqueur » au 80 (ajouté le 30/10/2026 : avec Destin, la note peut monter à 18) |

- À chaque niveau récompensé, le compte gagne aussi **note × 10 jetons**. Avant V2, ils sont comptés dans `solazeroth_jetons_dus` et seront versés à l'arrivée de la monnaie. Le Renom (V4) pourra s'y ajouter.

### 3.4 Bonus de compte (V1)

- **XP :** +25 % pour les personnages secondaires, par classe déjà montée au niveau 80, plafonné à +150 %. Fait en ALE (`compte_bonus.lua`) : mod-individual-xp ne gère pas ce bonus. **V6 :** plus +5 % par chapitre de l'histoire terminé par un autre personnage du compte (4.7).
- **Vitesse d'XP au choix :** mod-individual-xp, commande `.xp set 1` à `10`. Le joueur garde la vitesse d'origine ou l'accélère.
- **Réputation :** doublée sur les autres personnages une fois une faction exaltée.

### 3.5 Équilibrage solo par spécialisation (V2)

- En solo, soigneurs et tanks sont nettement plus lents que chasseur ou démoniste.
- Un bonus « solo » par spécialisation (dégâts, soins reçus, réduction des dégâts), réglable en config sans recompiler.
- Objectif : les combinaisons atypiques de mod-arac restent amusantes.
- **Implémentation (V2) :** module C++ `mod-solazeroth` (`bonus_solo.cpp`). La spécialisation est l'arbre de talents qui a le plus de points. Réglages `SolAzeroth.Solo.<Classe>.<Arbre> = "dégâts soins réduction"` dans `mod_solazeroth.conf`.
- **Valeurs de départ (provisoires)**, en % de dégâts infligés en plus : Protection guerrier 30, Sacré paladin 50, Protection paladin 25, Discipline 40, Sacré prêtre 50, Sang 15, Restauration chaman 50, Farouche 10, Restauration druide 50. Les autres arbres : 0.

### 3.6 Autres partages (sans priorité)

Montures, mascottes, or et banque partagés sur le compte, si l'effort est raisonnable. Après tout le reste.

- **Fait en V2 :** marchandises (classe 7) et composants (classe 5) empilables par **99** (migration 015) ; comparaison avec l'équipement porté affichée d'office au survol, sans Maj (addon de butin et option `alwaysCompareItems`).
- **Coffre du compte (V2) :** module C++ `banque.cpp`. À la connexion, chaque personnage sans guilde rejoint la guilde personnelle du compte, « Coffre de <nom du premier personnage> », comme maître de guilde (`Guild.AllowMultipleGuildMaster = 1`) : la banque de guilde devient une **banque partagée entre tous les personnages**. Onglets au prix de `Guild.BankTabCost0` à `5` : 100, 250, 500, 1 000, 2 500 et 5 000 po, soit 9 350 po **(provisoire)**. Accès aux coffres de guilde des capitales, ou partout avec **`.coffre`** (coffre pendant 2 minutes, hors combat et hors instance).
- **Pistage de toutes les ressources (V2) :** module C++ `pistage.cpp`. Les pistages de ressources connus (minerais, herbes, trésors) restent tous allumés en même temps. À vérifier en jeu : l'affichage de plusieurs types sur la minicarte.
- **Pas de mal de résurrection (V2, décision de l'utilisateur) :** `lua_scripts/sans_mal_de_rez.lua` retire le « Mal de résurrection » juste après une résurrection par l'esprit guérisseur. La perte de durabilité ne change pas.
- **Sacs unifiés (V2) :** addon `SolAzerothSacs`, écrit pour le projet sur le principe de Bagnon. Une fenêtre pour tous les sacs (touche B ou `/sacs`), une pour la banque et ses sacs, une recherche par nom, la bordure de qualité, les places libres, et dans l'infobulle le nombre d'exemplaires détenus par les autres personnages. Pas encore de tri automatique.
- **Fait en V2 (décision de l'utilisateur) :** les objets « Lié quand équipé » et « Lié quand utilisé » ne sont plus liés (migration 013) : plus de fenêtre de confirmation, et ils peuvent passer d'un personnage à l'autre par courrier. « Lié quand ramassé » ne change pas. Le lanceur vide le cache du client (`Cache\WDB`) à chaque démarrage pour qu'il reprenne les données du serveur.

### 3.6 bis Apprentissage à distance (V2, décision de l'utilisateur)

- **Plus de PNJ bonus ni retravaillés :** tout s'achète dans un addon, `SolAzerothFormation` (bouton déplaçable autour de la minicarte, ou `/apprendre`). L'Instructeur des maîtrises est retiré (migration 014).
- Onglets : **Sorts** (sorts et rangs de sa classe, prix d'origine des entraîneurs), **Métiers** (rangs Apprenti à Grand maître, métiers secondaires compris), **Recettes** (uniquement celles des entraîneurs de métier, filtrables par métier), **Compétences** (maîtrises d'armes et d'armures, section 3.7), **Outils** (outils de base au prix du marchand).
- Les règles sont celles des entraîneurs du jeu : niveau, rang précédent, valeur de métier requise. Recherche par nom, et option pour afficher ce qui est déjà appris.
- Serveur : module C++ `mod-solazeroth` (`formation.cpp`), qui charge au démarrage 2 021 sorts de classe, 84 rangs de métier et 1 487 recettes depuis les tables d'entraîneurs.
- Les sorts des **autres classes** (×10) s'y ajouteront en V3b, avec le module des ressources (section 3.9). Les achats de spés (3.8) passeront aussi par l'addon.

### 3.7 Maîtrises d'armes et d'armures (V1)

- **Correction V2 :** le serveur effaçait à chaque connexion les compétences « interdites » à la race et à la classe par `SkillRaceClassInfo.dbc` (dagues, bâtons, ambidextrie… pour un paladin) : les achats disparaissaient. La migration 017 autorise les 23 compétences d'armes et d'armures à tout le monde (table de surcharge `skillraceclassinfo_dbc`), et `formation.cpp` répare à la connexion les maîtrises déjà achetées. Indispensable aussi pour le Grimoire universel (3.9).
- Vendues dans l'onglet Compétences de l'addon d'apprentissage (3.6 bis) ; à l'origine par un PNJ, retiré en V2. Les maîtrises sont celles que la classe n'a pas nativement : armures (cuir, mailles, plaques, bouclier) et armes (bâton, arc, arme à feu, arbalète, armes d'hast, ambidextrie…).
- Les compétences d'armes et de Défense sont **toujours au maximum** du niveau : clé `AlwaysMaxSkillForLevel = 1` (vérifiée dans `worldserver.conf`). Les métiers ne sont pas concernés et se montent à la main.
- Prix modéré **(provisoire)** : c'est un confort, pas l'investissement principal.
- **Validation :** un mage achète les plaques et l'arc, les équipe, et sa compétence Arcs est au maximum dès l'achat et après chaque niveau.

### 3.8 Cinq spécialisations (V2)

- Le jeu n'en gère que 2 (`MAX_TALENT_SPECS = 2` dans le core, et l'interface du client). On ne modifie ni l'un ni l'autre.
- **Côté serveur (ALE) :** 5 emplacements de spé par personnage, stockés en base (talents et glyphes). Changer de spé = réinitialiser les talents, puis réappliquer ceux de l'emplacement choisi. Interdit en combat, comme dans le jeu d'origine.
- **Côté client (addon) :** une interface avec 5 emplacements identiques, nommables. L'addon enregistre et restaure aussi les barres d'action de chaque emplacement.
- **Prix croissants (provisoire) :** 2e spé 50 po, 3e 250 po, 4e 1 000 po, 5e 2 500 po. Achat dans l'addon d'apprentissage (3.6 bis), pas de PNJ.
- **Validation :** 5 spés différentes enregistrées sur un personnage ; passer de l'une à l'autre restaure talents, glyphes et barres d'action.
- **Validé en jeu le 27/10/2026.** Module C++ `specialisations.cpp` (ALE ne permet pas d'apprendre un talent proprement), migration 025, addon `SolAzerothSpes` (bouton de la minicarte ou `/spe`). Écarts avec le plan :
  - les **barres d'action sont enregistrées par le serveur**, pas par l'addon : plus simple et plus fiable. Un emplacement jamais utilisé garde les barres actuelles ;
  - **l'achat se fait dans la fenêtre des spécialisations** (bouton « 50 po »…), pas dans l'addon d'apprentissage : tout est au même endroit ;
  - prix réglables : `SolAzeroth.Specialisations.Prix = "50 250 1000 2500"` (po) ;
  - la double spécialisation d'origine du jeu reste à part : le système agit sur la spé active.
- Changement : la spé active est recopiée dans son emplacement, puis les talents sont réinitialisés gratuitement, et les talents (dans l'ordre des rangées), les glyphes et les barres de l'emplacement choisi sont réappliqués. Interdit en combat et mort.

### 3.9 Grimoire universel (V3b)

Le personnage peut acheter les sorts de toutes les autres classes, et utiliser toutes les ressources.

**Ressources pour toutes les classes (module C++)**

- Rage, énergie, points de combo et puissance runique fonctionnent pour toutes les classes : génération, coût vérifié, barres affichées par l'addon.
- Constaté en V0 : Toucher de glace appris par un mage fonctionne mais **sans payer son coût** en puissance runique. Les coûts doivent être appliqués avant toute vente.
- ~~**Runes :** hors chevalier de la mort, les sorts qui consomment des runes coûtent de la puissance runique à la place.~~ **Abandonné le 27/10/2026** : la puissance runique se gagne en dépensant des runes, donc une classe sans runes ne pourrait jamais la produire.
- **Runes (décision de l'utilisateur du 27/10/2026) : vraies runes.** Un personnage qui achète un sort à runes reçoit les 6 runes du chevalier de la mort, leur recharge et la puissance runique qu'elles génèrent. L'addon affiche les runes, que le client ne montre qu'au chevalier de la mort.
- **Faisabilité vérifiée le 27/10/2026, sans modifier le core :** AzerothCore a deux crochets prévus pour ce cas. `OnPlayerHasActivePowerType` déclare qu'un personnage utilise aussi une ressource : jauge maximale, régénération, rage gagnée et coûts suivent d'office. `OnPlayerIsClass` (contexte `CLASS_CONTEXT_ABILITY`) le fait compter comme chevalier de la mort pour les runes. Aucun module existant ne fait déjà ce travail.
- **Découpage (ordre choisi par l'utilisateur) :** (1) ressources pour toutes les classes et barres de l'addon, testées avec des sorts appris par commande MJ ; (2) runes ; (3) achat des sorts des autres classes ; (4) nouveau grimoire ; (5) familiers.
- **Étape 1 validée en jeu le 27/10/2026** (paladin avec Frappe héroïque, Attaque pernicieuse et Éviscération : rage gagnée et consommée, énergie, points de combo) : `ressources.cpp` et addon `SolAzerothRessources`.
  - Constat : le serveur donne déjà à tout personnage une jauge de rage (100), d'énergie (100) et de puissance runique (100), et l'énergie se régénère pour tous. Il ne manquait que le gain de rage (coups donnés et reçus), réservé aux classes dont la rage est « active ».
  - Une ressource devient active dès que le personnage connaît un sort qui la consomme.
  - L'addon affiche sous le cadre du joueur une barre pour chaque ressource consommée par un sort du grimoire, autre que la ressource principale, et les points de combo si le cadre d'origine ne les montre pas. Le cadre se déplace à la souris.
- **Étape 2, runes (validée en jeu le 27/10/2026** : paladin avec Toucher de glace, Frappe de peste, Frappe de sang et Voile mortel) :
  - tout personnage compte comme chevalier de la mort pour le seul contexte « capacités » (`OnPlayerIsClass`, `CLASS_CONTEXT_ABILITY`) : 6 runes, recharge, coût en runes vérifié, puissance runique gagnée. Les runes sont créées au chargement du personnage, avant ses sorts : les réserver aux acheteurs ferait planter le serveur après un achat en cours de jeu. Les sorts des autres classes n'ont pas de coût en runes, donc rien ne change pour eux. Niveau de départ, Achérus, reliques, armures et familiers du chevalier de la mort utilisent d'autres contextes et restent réservés ;
  - le client n'affiche les runes qu'au chevalier de la mort : le serveur envoie leur état à l'addon `SolAzerothRessources` à chaque changement, et l'addon affiche les 6 runes avec leur recharge, plus la barre de puissance runique.
- **Étape 3, achat des sorts des autres classes (validée en jeu le 27/10/2026)** : onglet « Classes » de l'addon d'apprentissage, avec une colonne des autres classes à gauche.
  - Les sorts d'une classe ne sont envoyés que quand on l'ouvre (environ 1 800 sorts en tout : les renvoyer à chaque achat ralentirait l'addon).
  - Mêmes règles que l'entraîneur (niveau requis, rang précédent, sorts requis), sans vérifier ni la classe ni la race. Les sorts de talents n'y sont pas, sauf les rangs supérieurs d'un talent, qui restent « Pas encore » sans le talent.
  - Prix = prix d'entraîneur × 10 (`SolAzeroth.Formation.MultiplicateurAutresClasses`).
- **Étape 4, nouveau grimoire (validée en jeu le 27/10/2026)** : addon `SolAzerothGrimoire`, bouton « Autres classes » sur le grimoire d'origine, ou `/grimoire`.
  - Le client ne sait pas à quelle classe appartient un sort : le serveur envoie la liste des sorts connus des autres classes (`.solform grimoire`), tirée des listes d'entraîneurs.
  - Un onglet par classe dont au moins un sort est connu, sorts au plus haut rang, 14 par page. Clic : lancer le sort ; glisser : le poser sur une barre d'action ; infobulle et recharge comme le grimoire d'origine.
  - **Écart avec le plan :** un addon ne peut pas retirer des sorts du grimoire d'origine. Les sorts achetés restent aussi dans son onglet Général ; le nouveau grimoire en est la vue rangée. Les retirer demanderait un patch client (V7).
  - Les onglets verticaux des familiers viendront avec l'étape 5.
- **Étape 5, familiers (validée en jeu le 27/10/2026, sorts appris par commande MJ)** : `familiers.cpp`.
  - **Ajout (demande de l'utilisateur) :** les sorts de familier obtenus par quête dans le jeu d'origine, absents des entraîneurs, sont vendus dans le catalogue de leur classe (onglet Classes, et onglet Sorts pour la classe elle-même), au niveau de la quête et au prix d'un sort d'entraîneur de ce niveau (niveau × 60 pièces de cuivre, × 10 pour une autre classe) : Dressage, Appel du familier, Renvoyer le familier, Ressusciter le familier, Nourrir le familier (niveau 10) ; Invocation d'un marcheur du Vide (10), d'une succube (20), d'un chasseur corrompu (30). À vérifier en jeu.
  - Familier de chasseur (apprivoiser, appeler, ressusciter, maître des écuries) : `IsClass(CLASS_HUNTER, CLASS_CONTEXT_PET)` activé pour qui connaît Dressage ou Appel du familier.
  - Démons (permanence, rappel du dernier démon) : `IsClass(CLASS_WARLOCK, CLASS_CONTEXT_PET)` activé pour qui connaît une invocation de démon.
  - Le type de familier dépend de la créature (démon : démon invoqué ; bête apprivoisable : familier de chasseur), par le crochet `OnPlayerBeforeGuardianInitStatsForLevel`. Les autres familiers (goule, élémentaires) gardent le choix du serveur.
  - **Écart avec le plan :** pas d'onglets verticaux de familiers dans le nouveau grimoire. Le grimoire d'origine a déjà un onglet « Familier » pour toutes les classes dès qu'un familier est présent.
- **Sorts manquants, postures et totems (30/10/2026, à valider en jeu)** : `formation.cpp` et addon `SolAzerothFormation`. Constat de l'utilisateur : des sorts de guerrier achetés étaient inutilisables faute de posture, car Posture de combat est un sort de départ et Posture défensive et Posture berserker viennent de quêtes de guerrier.
  - Sont maintenant vendus, dans le catalogue de leur classe (et de la classe elle-même), au prix d'un sort d'entraîneur de ce niveau :
    - les **sorts de départ** de chaque classe, au niveau 1 : Posture de combat, Frappe héroïque, Boule de feu, Éclair, Présence de sang… ;
    - les **sorts des quêtes de classe**, au niveau minimal de la quête : Posture défensive avec Provocation et Fracasser armure (10), Posture berserker avec Interception (30), Forme d'ours avec Grondement et Mutiler (10), Guérison du poison, Rédemption, Totems de peau de pierre, incendiaire et guérisseur, Inferno, montures de classe… L'équitation apprise avec certaines montures n'est pas vendue.
  - Le catalogue passe de 2 029 à 2 072 sorts de classe.
  - **Posture, forme ou camouflage exigés** : un sort qui ne se lance qu'en posture, en forme ou camouflé ne s'achète qu'avec une posture, une forme ou un camouflage qui convient (201 sorts). La fenêtre affiche « Requiert : Posture de combat ».
  - **Totems du chaman** : acheter un sort qui demande un totem (objet) donne ce totem s'il manque.
- **Barres de postures et de totems (30/10/2026, à valider en jeu)** : addon `SolAzerothBarres`. Le jeu place la barre de totems à l'endroit de la barre de postures, auras et formes, car un chaman n'a pas de postures ; un paladin avec des totems avait les deux barres superposées. La barre de totems se place maintenant au-dessus de celle des postures. `/barres` déverrouille les deux barres pour les déplacer à la souris (positions gardées par personnage, jamais en combat) ; `/barres reset` remet les places d'origine.
  - Les postures du guerrier n'ont pas d'icône de buff, même pour un vrai guerrier : la posture active est le bouton allumé de la barre de postures.
- C'est la partie la plus risquée du projet : ALE ne suffit pas (ordre de préférence technique, étape 4).

**Sorts des autres classes (addon d'apprentissage)**

- Dans l'addon d'apprentissage (3.6 bis), pas de PNJ : **un onglet par classe**, sorts **triés par niveau requis, donc par prix**.
- Liste tirée des tables d'entraîneurs (`trainer`, `trainer_spell` : niveau requis et prix d'origine, vérifiées en base). Les sorts de talents ne sont pas vendus.
- Prix = prix d'entraîneur **× 10 (provisoire)**, réglable en config. Exemple : un rang à 30 po coûte 300 po.
- Niveau requis identique à celui de l'entraîneur d'origine.

**Nouveau grimoire (addon)**

- Un **onglet horizontal par classe** dont au moins un sort est acheté, en plus de la classe d'origine. Les sorts achetés n'apparaissent plus en vrac dans l'onglet Général.
- Des **onglets verticaux pour les familiers**.
- Les sorts se glissent sur les barres d'action comme avec le grimoire d'origine.

**Validation :** un mage achète Frappe héroïque et Toucher de glace ; ils apparaissent dans les onglets Guerrier et Chevalier de la mort ; Frappe héroïque consomme de la rage générée en combat, Toucher de glace consomme de la puissance runique et ne peut plus être lancé sans.

**V3b validée en jeu le 27/10/2026** (les cinq étapes).

### 3.10 Talents d'une autre classe (V3c, idée de l'utilisateur du 27/10/2026)

- Le personnage peut placer des points dans **un seul arbre de talents d'une autre classe**, en plus de ses trois arbres, **sans limite de points** dans cet arbre (décision de l'utilisateur). Le personnage n'a pas plus de points au total (71, plus les 50 points de hauts faits de 7.4) : ce qu'il met en défense manque en attaque, donc les combats durent plus longtemps. L'utilisateur juge l'équilibre acceptable, le tank étant le cas le plus fort.
- Changer d'arbre étranger = réinitialiser ses talents. Chacune des cinq spécialisations (3.8) peut avoir son propre arbre étranger.
- **Faisabilité vérifiée, sans modifier le core :** la fonction d'apprentissage du jeu refuse un talent d'une autre classe (vérification de la classe de l'arbre, que le crochet existant ne permet pas de contourner). Le module aura sa propre fonction d'apprentissage, reprise de celle du jeu sans cette vérification (points disponibles, 5 points par rangée dans l'arbre, prérequis, rangs), utilisée aussi par les cinq spécialisations.
- **Interface :** la fenêtre de talents du jeu n'affiche que les arbres de sa classe, et l'interface des addons ne donne pas accès aux autres. Un **nouvel addon de talents** affichera l'arbre étranger : le serveur envoie sa structure (positions, rangs, prérequis) ; le client affiche icônes, noms et infobulles.
- Les talents qui donnent un sort (ex. Frappe mortelle) s'obtiennent par cette voie : ils ne sont pas vendus dans l'onglet Classes. **(Provisoire, à confirmer.)**
- **Validé en jeu le 27/10/2026** : `talents_etrangers.cpp`, addon `SolAzerothTalents` (bouton « Autre classe » de la fenêtre des talents, ou `/arbre`).
  - `SolAzeroth::ApprendreTalent` : talent de sa classe, fonction du jeu ; talent d'une autre classe, mêmes règles (points libres, 5 points par rangée dans l'arbre, prérequis, rangs, sorts ajoutés au grimoire) sans la vérification de classe, et refus si un autre arbre étranger a déjà des points. Le chargement des talents à la connexion ne vérifie pas la classe : rien à contourner.
  - Les cinq spécialisations (3.8) réappliquent les talents par cette fonction : chaque spé garde son arbre étranger. Leur résumé « a/b/c » ne compte que les trois arbres de la classe.
  - L'addon affiche l'arbre choisi en grille (4 colonnes, 11 rangées), avec rang, infobulle du sort, et raison si un talent n'est pas encore accessible. Le serveur envoie la structure de l'arbre ; les noms des arbres sont dans l'addon.
  - Réinitialisation : celle du jeu efface aussi les talents étrangers et rend leurs points.
- **Réinitialisation payante depuis l'interface (demande de l'utilisateur du 27/10/2026 : coût cohérent, punitif et croissant)** : sans entraîneur, bouton **« Réinitialiser »** dans la fenêtre des talents du jeu et dans `/arbre`, avec confirmation qui affiche le prix et celui de la suivante. **Validé en jeu le 27/10/2026.**
  - Prix = niveau × 1 po × 2^n, où n = réinitialisations déjà faites par ce personnage ; n baisse de 1 par semaine sans réinitialisation. Exemple au niveau 40 : 40, 80, 160, 320 po… (au niveau 80 : 80, 160, 320, 640 po). Réglable : `SolAzeroth.Talents.ReinitOrParNiveau`, `ReinitMultiplicateur`, `ReinitBaisseJours`.
  - Changer de spécialisation (3.8) reste gratuit : c'est l'emplacement acheté qui paie la souplesse.
  - Technique : commandes `.soltalent prix` et `.soltalent reinitialiser` (`talents_etrangers.cpp`), compteur par personnage dans `solazeroth_reinit_talents` (migration 032). Les points bonus des hauts faits (7.4) sont rendus.

## 4. Donjons et raids

Chaque instance garde son niveau d'origine, est ramenée à 1 joueur, et se joue à un rang de menace de 0 à 10 qui augmente la difficulté et améliore le butin.

### 4.1 Mise à l'échelle par nombre de joueurs (V1)

- **mod-autobalance** réglé sur 1 joueur, avec la mise à l'échelle **par niveau désactivée** : un donjon de niveau 13 reste de niveau 13 (`AutoBalance.LevelScaling = 0`). L'or reste celui d'origine (`AutoBalance.RewardScaling.Money = 0`).
- **Réglage après le premier test (V2, provisoire) :** Ragefeu au rang 0 était beaucoup trop facile et rapportait trop d'XP.
  - **Mesuré en jeu** (Chaman de Ragefeu, script d'observation) : pour 1 joueur dans un donjon à 5, mod-autobalance ramène PV, mana et dégâts à environ **12 %** de l'original (le point de bascule `InflectionPoint = 0.5` vaut 2,5 joueurs). Conséquences : monstres tués en 2 coups, et lanceurs de sorts sans assez de mana pour lancer quoi que ce soit (36 de mana pour un Éclair à 90).
  - **Réglage retenu (provisoire)**, 1 joueur (`AutoBalance.MinPlayers = 1`), multiplicateurs appliqués à ces 12 % :

| Réglage | Monstres | Boss | Résultat environ |
| --- | --- | --- | --- |
| `StatModifier(.Boss).Health` | 2.45 | 3.0 | PV 30 % (boss 37 %) |
| `StatModifier(.Boss).Damage` | 2.0 | 2.0 | dégâts 25 % |
| `StatModifier(.Boss).Mana` | 8.0 | 8.0 | mana environ 100 % (les lanceurs lancent leurs sorts) |

  - Mêmes valeurs pour les donjons héroïques (`StatModifierHeroic.*`). Les raids seront réglés en V6.
  - **Ajustements par créature** (`SolAzeroth.Ajustement.Creatures` dans `mod_solazeroth.conf`, valables partout) : pour les boss de fête prévus pour 5 joueurs, qu'autobalance ne touche pas. Premier cas, trouvé par le journal du Cimetière écarlate : le **Cavalier sans tête** (Sanssaint, niveau 80, 126 000 PV, modificateur de dégâts 19,5) a tué un paladin 33 en 3,3 s. Réglé pour un solo à son niveau (75-80) **(provisoire)** : 50 % des PV et 30 % des dégâts pour lui, sa tête et les Démons-citrouilles ; 50 % des PV pour les Citrouilles palpitantes. Avant le niveau 75, il reste mortel, comme dans le jeu d'origine.
  - **Premier journal analysé** (Ragefeu, rang 0, paladin 13, niveau d'objet moyen 17, 4 talents) : donjon fini en 23 min sans mourir ; monstres seuls tués en 5 à 15 s pour 2 à 4 dégâts/s subis ; groupes de 3 à 5 tenus jusqu'à 36 % de PV au pire ; lanceurs de sorts actifs. Seuls les **boss** étaient trop faciles (21 à 36 s, 21 à 33 % de PV perdus). Ajustement : `StatModifier.Boss.Health = 4.5` (≈ 55 % des PV d'origine) et `StatModifier.Boss.Damage = 3.0` (≈ 37 % des dégâts), héroïques compris.
  - L'XP des monstres de donjon est **divisée par 2** : un élite de donjon rapporte autant qu'un monstre normal de même niveau en extérieur. L'XP des quêtes n'est pas touchée. **Correction après le Monastère :** en mode `fixed`, mod-autobalance multiplie aussi par (joueurs présents / places du donjon), soit 1/5 en solo ; le réglage 0,5 donnait donc 10 % de l'XP normale (55 XP par monstre au niveau 33). Réglage corrigé : `AutoBalance.RewardScaling.XP.Modifier = 2.5` (× 1/5 = 0,5).
  - **Monastère écarlate, Bibliothèque** (paladin 33, monstres 33-35, au niveau) : 30 min, 75 monstres, 1 mort sur un groupe de 6 élites engagés d'un coup ; groupes de 3-4 tenus à 55-79 % de PV ; boss Loksey (56 s, 47 % de PV perdus) et Doan (63 s, 56 % perdus, 7 Explosions des arcanes). **Équilibre jugé bon, aucun changement.**
- Alternative : **mod-dungeon-scale**, un dérivé de mod-autobalance qui ajuste aussi selon le nombre de joueurs. Il sait aussi changer le niveau des créatures : cette option doit rester désactivée.
- Choisir un seul des deux modules, jamais les deux ensemble.

### 4.2 Rang de menace de compte (V2)

- Le rang de menace est **un niveau de compte**, pas un réglage par donjon.
- Pour débloquer le rang N+1, il faut réussir le rang N dans **2 donjons différents** (3 au départ, abaissé à 2 le 27/10/2026 pour que la progression suive la montée en niveau).
- Le rang maximal réussi dans chaque donjon est affiché dans le Codex.
- Plafond à **5** pour les donjons Classic et TBC, à **10** pour les donjons WotLK.
- **Choix à l'entrée :** une pierre (PNJ) à l'entrée de chaque instance, avec un menu de 0 au rang débloqué. Le rang est stocké dans les données de l'instance et ne peut plus changer une fois le premier monstre engagé.
- **Implémentation (V2) :** module C++ `mod-solazeroth` (`menace.cpp`), sources dans `C:\SolAzeroth\modules`.
  - **Choix du rang par fenêtre** (décision de l'utilisateur, remplace la Pierre de menace, migration 020) : addon `SolAzerothMenace` (bouton de la minicarte ou `/rang`). On règle à l'avance le rang du **prochain donjon réinitialisé** (`solazeroth_menace_compte`). Une instance neuve prend ce rang à la première entrée et la fenêtre s'ouvre ; le rang reste modifiable jusqu'au premier combat, qui le verrouille. Un changement de réglage ensuite ne touche que le prochain donjon. La fenêtre montre le rang débloqué, l'affixe de la semaine et l'effet de chaque rang.
  - **Réussite d'un donjon** = mort du dernier boss (table `instance_encounters`, ligne marquée `lastEncounterDungeon`). Une réussite se compte **par donjon du jeu** (identifiant `lastEncounterDungeon`), pas par carte : les 4 ailes du Monastère écarlate comptent pour 4 donjons (migration 019).
  - Les quelques donjons dont la fin est validée par un sort ne comptent pas encore.
  - Rang par instance dans `solazeroth_menace_instance`, réussites par compte dans `solazeroth_menace_reussites`. Une instance réinitialisée oublie son rang.
  - Commande **`.menace`** : rang débloqué, nombre de donjons réussis, affixe de la semaine, rang de l'instance actuelle.
  - Pour l'instant, donjons à 5 uniquement ; les raids viendront avec la section 4.7.

### 4.3 Formules de difficulté (à équilibrer)

- PV des monstres × (1 + 0,12 × rang). **Décidé en V2 :** appliqué en divisant les dégâts que le monstre subit (effet identique sur la durée du combat), sans toucher aux PV affichés, pour ne pas entrer en conflit avec mod-autobalance.
- Dégâts des monstres × (1 + 0,08 × rang).
- Or ramassé dans l'instance qui augmente avec le rang (coefficient en config).
- Toutes les valeurs sont en config, pour équilibrer sans recompiler.

### 4.4 Affixes

**V2, affixes de stats :** Fortifié (trash +20 % PV et dégâts) et Tyrannique (boss +30 % PV, +15 % dégâts), en alternance chaque semaine, actifs à partir du rang 2. Fortifié les semaines paires, Tyrannique les impaires (semaines comptées depuis 1970) ; affiché par la pierre et par `.menace`.

**V5, affixes de mécanique :** 3 ou 4 affixes parmi cette liste, avec uniquement des sorts et visuels qui existent déjà dans le jeu.

| Rang d'apparition | Affixe | Effet |
| --- | --- | --- |
| 4 | Enragé | Les monstres sous 30 % de vie font +50 % de dégâts |
| 4 | Renforçant | Un monstre qui meurt renforce ses voisins |
| 7 | Volcanique | Zones de feu au sol sous le joueur |
| 7 | Explosif | Des orbes à détruire apparaissent pendant les combats |
| 10 | Implacable | Les boss gagnent une capacité supplémentaire tirée de leur palette |

**V5, affixes à points (façon Wakfu) :** au lieu d'imposer les affixes selon le rang, le joueur coche une liste d'affixes, chacun valant des points (Volcanique = 2, Enragé = 1…). Le total des points donne le palier de butin. La formule de butin ne change pas, seul le moyen d'atteindre le palier change.

**Construit le 29/10/2026 (V5 étape 2), à valider en jeu.** Décisions de l'utilisateur : affixes **à cocher avec points** tout de suite (le tableau « rang d'apparition » ci-dessus n'est plus suivi). Les quatre affixes recommandés par Claude sont construits ; Implacable est écarté (il faudrait une capacité choisie à la main pour chaque boss). Valeurs provisoires (`SolAzeroth.Mecanique.*`), à recaler par l'équipe de calibrage (10.3) :

| Affixe | Points | Effet construit |
| --- | --- | --- |
| Enragé | 1 | Un monstre hors boss sous 30 % de vie fait +50 % de dégâts ; il l'annonce par une émote (« devient enragé ! ») |
| Renforçant | 1 | Un monstre hors boss qui meurt donne aux monstres hors boss à 30 m +20 % de dégâts et de PV par cumul, **5 cumuls au plus** (PV : dégâts subis divisés, comme le rang) ; ils grandissent de 10 % par cumul. **Buff visible** sur le monstre (demande de l'utilisateur du 29/10/2026) : « Renforcement chancreux » (sort existant 59449, icône avec le nombre de cumuls), qui porte lui-même les dégâts en plus |
| Volcanique | 2 | En combat, toutes les 10 s, une Pluie de feu (sort existant 43440, visuel seulement) tombe sous un joueur ; 2 s plus tard, la fissure explose (Nova de feu, sort 12470) : 15 % des PV max de qui est resté à 5 m |
| Explosif | 2 | En combat, toutes les 12 s, une Sphère instable (modèle de l'Oculus, aura d'apparence 50756) apparaît à 6 m d'un joueur, en l'air ; elle a 5 % des PV max du joueur (mod-autobalance l'ignore, sinon il lui imposerait les PV de son modèle de niveau 80) ; non détruite en 6 s, elle explose (15 % des PV max de chaque joueur à 30 m). Annonce en grand au centre de l'écran |

- **Corrigé après Ragefeu au rang 4, tous affixes cochés (29/10/2026)** : la sphère avait 12 600 PV (mod-autobalance remet les PV du modèle, niveau 80) et ne se détruisait pas ; elle gardait le joueur en combat et en faisait apparaître d'autres ; la pluie de feu restait 10 s (5 impulsions de 8 %). Le joueur a fini un combat contre deux monstres de niveau 14 à 22 % de PV. Maintenant : la sphère compte les dégâts reçus (seuil 5 % des PV max du joueur) ; seuls les combats contre de vrais monstres déclenchent les affixes ; la pluie de feu ne frappe qu'une fois, plus fort (15 %).

- **Choix** dans la fenêtre du rang (`/rang`) : cases à cocher sous les rangs, infobulle avec l'effet et les points. Comme le rang, les affixes cochés valent pour le prochain donjon réinitialisé, restent modifiables jusqu'au premier combat, puis se verrouillent. Utilisables à tout rang, même 0.
- **Palier de butin = rang + points des affixes, plafonné au rang maximal du donjon** (5 en Classic et TBC, 10 en WotLK). Il sert à l'enchantement de bonus de l'objet choisi sur un boss et aux Marques des boss (règle 7.5 : on paie les paliers pas encore payés). Le rang seul garde le reste : difficulté de base, or ramassé, réussite et déblocage des rangs, contrats, écart d'équipement. Exemple : rang 3 + Volcanique dans un donjon Classic = butin et Marques de rang 5.
- **Code** : `affixes_mecanique.cpp`, `menace.cpp` (colonnes `affixes_prochain` et `affixes`, commande `.solmenace affixes`, `.menace` affiche affixes et palier), migration 038 (colonnes + créatures 900100 « Sphère instable » sans XP et 900101 « Fissure volcanique » invisible).

### 4.5 Butin amélioré par enchantement de bonus (V2, à prototyper)

- Un objet tombé au rang R reçoit un **enchantement de bonus** qui ajoute les stats correspondant à « ilvl d'origine + R » selon les budgets de stats de WotLK. L'objet de base ne change pas en base de données.
- L'infobulle affiche « Affixe R ». Le palier est stocké en base avec l'objet.
- **Ilvl effectif** d'un objet = ilvl d'origine + palier de son enchantement de bonus. C'est cette valeur que lit l'écart d'équipement (section 5).
- L'enchantement de bonus doit utiliser un emplacement qui **n'empêche pas** le joueur d'enchanter l'objet normalement (emplacement à identifier dans le core). Les emplacements de gemmes restent ceux de l'objet d'origine.
- Niveau requis inchangé : l'objet s'équipe dès le niveau du donjon.
- **Butin garanti** au premier passage de chaque palier dans chaque donjon.
- **Repli si l'enchantement ne fonctionne pas :** 4 paliers seulement (+0, +3, +6, +10), avec des variantes d'objets générées dans la plage d'ID 900000+.
- **Prototype V2, validé en jeu le 27/10/2026** (« Gangrelame maudite d'Endurance », +2 Endurance au rang 2) (`bonus.cpp`, migration 023), appliqué à l'objet choisi sur un boss de donjon (4.5 bis) :
  - **suffixe aléatoire existant du jeu** (`ItemRandomProperties.dbc`) : « d'Endurance », « de Force », « d'Agilité », « d'Intelligence » ou « d'Esprit », de +1 à +46. L'objet prend le nom du suffixe (« Gangrelame maudite d'Endurance ») et le client affiche le bonus nativement. Premier essai abandonné : un enchantement posé seul dans l'emplacement des suffixes était appliqué par le serveur mais **invisible** dans l'infobulle. L'enchantement normal reste possible ; un objet qui a déjà un suffixe aléatoire n'a pas de bonus ; « Affixe R » ne peut pas s'afficher avant V7 ;
  - valeur = somme des caractéristiques de l'objet × R × **3 %** (`SolAzeroth.Bonus.PourcentParRang`), au moins R, sur la caractéristique principale de l'objet (Endurance s'il n'en a pas). **Changé le 27/10/2026 (décision de l'utilisateur)** : la première formule (« + R niveaux d'objet ») donnait environ +R à tous les niveaux, alors que la difficulté d'un rang est proportionnelle. Le bonus l'est maintenant aussi : au rang 2, environ +2 au niveau 40 et +15 sur un torse de Norfendre ; plafond +46 (suffixes du jeu). Les objets déjà obtenus gardent leur ancien bonus. Conséquence pour l'écart d'équipement (V5) : l'ilvl effectif ne vaut plus exactement « ilvl + R », à recalculer d'après le bonus réel ;
  - rang mémorisé avec l'objet (`solazeroth_objets_rang`) pour l'écart d'équipement de V5 ;
  - non encore couvert : butin des raids et objets tombés hors du choix de boss.

| Ragefeu, exemple | Rang 0 | Rang 5 | Rang 10 |
| --- | --- | --- | --- |
| Ilvl attendu | \~16 | \~21 | Non disponible (plafond 5 en Classic) |
| Ilvl effectif du butin | \~16 (butin d'origine) | \~21 | Non disponible |

### 4.5 bis Butin des boss de donjon au choix (V2)

- Décidé par l'utilisateur : sur les **boss de donjon à 5** (pas les raids), l'équipement ne tombe plus au hasard. À la mort du boss, une fenêtre propose **tout l'équipement possible** du boss (armes et armures, qualité inhabituelle ou mieux, tables de référence comprises) ; le joueur en **choisit un**.
- Le reste du butin ne change pas : or, objets de quête, composants.
- **Correction après Ragefeu au rang 2 :** certains boss (Oggleflint) n'ont presque pas d'objets propres et renvoient vers des **réserves d'objets aléatoires du monde** (tables de référence de 40 à 160 objets). Ces réserves restent tirées au hasard ; seules les références de 25 objets ou moins, propres au boss, sont proposées au choix.
- Module C++ `mod-solazeroth` (`butin.cpp`) et addon `SolAzerothButin` (`/butin`). Les choix non faits sont gardés en base (`solazeroth_butin_attente`) et reproposés à la connexion. Sacs pleins : le choix reste disponible.
- L'enchantement de bonus (4.5) s'appliquera à l'objet choisi quand il existera.
- **Conséquence :** avec la réinitialisation libre (4.7), on peut obtenir tout l'équipement d'un boss en quelques passages. Le journal de collection (7.3) et la protection contre la malchance (6.3) concernent donc surtout les raids et les butins rares hors boss de donjon.

### 4.6 Défis de boss façon Dofus (V2)

- Au début de chaque combat de boss, un défi est tiré au sort : sans potion, en moins de 90 secondes, tuer l'adjoint en premier, sans se soigner, ne pas bouger 10 secondes…
- Réussi, il donne un bonus de butin ou de monnaie.
- Implémentation : un compteur et des hooks (début de combat, mort, utilisation d'objet).
- **Prototype V2, validé à Uldaman le 27/10/2026** (5 défis sur 5 déclenchés et réussis) (`defis_boss.cpp`, addon `SolAzerothMenace`). Seuls les défis que le serveur vérifie de façon fiable sont retenus :
  - **Sobriété** : ne boire aucune potion pendant le combat ;
  - **Contre la montre** : tuer le boss en moins de 60 secondes ;
  - **Sans filet** : ne lancer aucun soin sur soi-même ;
  - **Intouchable** : ne jamais descendre sous 50 % de ses PV.
- Tous les boss de donjon sont concernés, à tous les rangs de menace. Le défi s'annonce dans la discussion et dans un petit cadre déplaçable (avec compte à rebours pour « Contre la montre »). Il est annulé si le combat s'arrête sans que le boss meure (fuite, mort du joueur).
- Récompense : **3 Marques du voyageur** par défi réussi. Le résultat est noté dans le journal de donjon (ligne `EVENEMENT`).
- Réglages dans `mod_solazeroth.conf` : `SolAzeroth.DefisBoss.Enable`, `.Marques` (3), `.Chrono` (60 s), `.SeuilPV` (50 %).
- « Tuer l'adjoint en premier » et « ne pas bouger » sont écartés pour l'instant : trop dépendants de chaque boss.

### 4.7 Raids

- Même système que les donjons : niveau d'origine, ramenés à 1 joueur, rang de menace de 0 à 5. Le butin des raids plafonne donc à +5 ilvl.
- **Bonus solo** sur les boss trop difficiles seul, par affaiblissement ciblé. Module à évaluer : **mod-zone-difficulty**. C'est un module de soutien à mod-progression-system : vérifier qu'il fonctionne seul avant de s'en servir.
- **Pas de verrou hebdomadaire.** Le premier passage de chaque raid dans la semaine donne un coffre bonus, cumulable sur 2 semaines.
- **Réinitialisation libre (V2, décidé par l'utilisateur)** pour les donjons normaux, les donjons héroïques et les raids : commande **`.reinitialiser`** hors instance (délie le personnage de toutes ses instances ; la prochaine entrée en crée une neuve). La limite de 5 instances par heure est levée (`AccountInstancesPerHour = 1000`). Le rang de menace d'une instance réinitialisée est oublié.
- **Rendements décroissants affichés :** au-delà de 3 passages par jour du même raid, le butin rare baisse de 50 %. Une aura « Raid épuisé » et un compteur l'annoncent.
- **Liste de faisabilité :** classer chaque boss WotLK en facile, à régler (bonus solo) ou à réécrire. Seuls les deux premiers comptent dans le Codex au départ.
- **Fin de l'histoire (V6) :** après la chaîne d'histoire, un téléport mène directement au Trône de glace. Le Roi-liche est **réglé** (bonus solo), pas réécrit. Le reste de la Citadelle (Canonnière, Valithria, Putricide) n'est pas requis pour la fin « Histoire ».
- Les boss réécrits un par un sont repoussés à V8+.
- **Décisions de l'utilisateur (28/10/2026, début de V6)** :
  - on commence par le Roi-liche, puis la chaîne d'histoire, les rendements décroissants et la liste de faisabilité ;
  - **pas de raccourci** : le téléport direct au Trône de glace est abandonné. Le Roi-liche (et son film) n'est accessible qu'après **toutes les ailes de la Citadelle**, comme dans le jeu d'origine. Chaque étape de l'histoire est conditionnée proprement de la même façon ;
  - la chaîne d'histoire doit être **assez longue** : le bonus d'XP dépend de l'avancement de l'histoire, et l'accès aux paliers d'histoire est conditionné par le **niveau** et le **niveau d'objet** ;
  - récompense de fin : film, titre et haut fait **d'origine**, plus le haut fait du compte « Fin : Histoire ».
  - Conséquence : **toute la Citadelle** doit être faisable seul, ce qui demande une recherche boss par boss (liste de faisabilité, en premier).
- **Recherche du 28/10/2026 : la Citadelle seul (lecture des scripts, à confirmer en jeu)**
  - Préalable : `Instance.IgnoreRaid = 1` dans `worldserver.conf` (aujourd'hui à 0 : il faut un groupe de raid pour entrer). Les raids sont déjà ramenés à 1 joueur par mod-autobalance, sans multiplicateurs propres (`StatModifierRaid.* = 1`, à régler).
  - **Facile ou à régler par les chiffres** : Gargamoelle (Pointes d'os à vérifier : le joueur empalé doit pouvoir frapper sa pointe), Dame Murmemort, Saurcroc le Porte-mort, Trognepus, Conseil des princes de sang, Reine Lana'thel (la Morsure vampirique évite la cible du boss : seul, pas de contrôle mental, **sauf si un familier tient le boss**).
  - **Bataille des canonnières** : faisable en principe (canons, réacteur dorsal pour aborder le navire ennemi), à tester.
  - **À régler par une petite adaptation (C++)** :
    - Pulentraille : le **Gonflement gastrique** s'empile sur la cible du boss, prévu pour un changement de tank ; seul, l'explosion à 10 piles est inévitable ;
    - Professeur Putricide : la **Peste mutée** s'empile de la même façon en phase 3 ;
    - Sindragosa : en phase aérienne, les **Tombeaux de glace** frappent des joueurs au hasard ; seul, le joueur est enfermé sans personne pour le libérer. En phase 3, le Déchaînement mystique s'empile sans tombeau pour s'abriter ;
    - Roi-liche : les **Val'kyrs** saisissent le joueur et l'emportent hors de la plateforme ; seul, personne ne les arrête.
  - **À réécrire en partie** : Valithria Marcherêve, combat de **soins** (il faut la remonter à 100 %). Impossible pour une classe sans soins.
  - **Classement provisoire** : 7 boss faciles ou à régler, 4 à adapter (Pulentraille, Putricide, Sindragosa, Roi-liche), 1 à réécrire en partie (Valithria).
- **Décisions suivantes (28/10/2026)** : adapter chaque mécanique impossible seul ; histoire « fil du Fléau » de 1 à 80 ; bonus d'XP de compte par chapitre. L'utilisateur a ensuite laissé Claude décider seul pendant son absence (« globalement j'ai toujours suivi tes recommandations »).
- **Construit le 28/10/2026 en son absence, à tester en jeu** :
  - **Entrée seul dans les raids** : `Instance.IgnoreRaid = 1` (`worldserver.conf`).
  - **Adaptations de la Citadelle** (`citadelle.cpp`, seulement quand un seul joueur est dans l'instance) :
    - Pulentraille : Gonflement gastrique plafonné à 6 piles (l'explosion vient à 10). Les noms Pulentraille et Trognepus étaient inversés dans ce document jusqu'au 28/10/2026 ; le code visait déjà le bon sort ;
    - Putricide : Peste mutée plafonnée à 4 piles ;
    - Lana'thel : si un familier tient la reine et que le joueur est mordu, la Soif de sang frénétique est retirée (pas de contrôle mental) ;
    - Valithria : chaque créature du combat tuée la soigne de 6 % de sa vie (1 % pour un ver putride) ; les soins du joueur comptent toujours ;
    - Sindragosa : un Tombeau de glace se brise seul au bout de 5 s ;
    - Roi-liche : une Val'kyr qui saisit le joueur le lâche au bout de 3 s, il revient au centre de la plateforme et la Val'kyr disparaît.
    - Pas de raccourci : le Roi-liche demande toujours les quatre ailes (script d'origine).
  - **Chaîne d'histoire « Le fil du Fléau »** (`histoire.cpp`, migration 045) : un **chroniqueur de la Croisade** à Hurlevent et à Orgrimmar (places choisies par l'utilisateur, migration 048) donne **16 chapitres** l'un après l'autre (quêtes 900200 à 900215). Il ne propose le suivant que si le personnage a le **niveau** et le **niveau d'objet moyen** du chapitre (provisoire, table `solazeroth_histoire`) ; sinon il affiche ce qui manque.

| Ch. | Niveau | Ilvl | Titre | Ce qu'il faut faire |
| --- | --- | --- | --- | --- |
| 1 | 20 | auto | Ombres sur Lordaeron | Arugal (Ombrecroc) |
| 2 | 35 | auto | La Croisade écarlate | Hérode, Blanchetête (Monastère écarlate) |
| 3 | 37 | auto | Le Porte-froid | Tuten'kash, Amnennar (Souilles de Tranchebauge) |
| 4 | 58 | auto | Les Maleterres | Gandling (Scholomance), Vaillefendre et Balnazzar (Stratholme) |
| 5 | 68 | auto | Les ennemis du Roi-liche | Exarque Maladaar (cryptes Auchenaï), Kael'thas (Terrasse des Magistères) |
| 6 | 70 | auto | Les rivages du Norfendre | Ingvar (Utgarde), Keristrasza (Nexus) |
| 7 | 73 | auto | Les royaumes souterrains | Anub'arak (Azjol-Nérub), Tharon'ja (Drak'Tharon) |
| 8 | 74 | auto | Le Portail du Courroux | quêtes « Retour à Angrathar » et « La bataille pour Fossoyeuse » |
| 9 | 76 | auto | Les échos du passé | Mal'Ganis (Épuration de Stratholme), Volazj (Ahn'kahet) |
| 10 | 77 | auto | La Couronne de glace | quête « Le gambit de Tirion » |
| 11 | 80 | 175 | Naxxramas | Kel'Thuzad |
| 12 | 80 | 185 | Le tournoi d'Argent | Chevalier noir, quête « La chute du Chevalier noir » |
| 13 | 80 | 200 | Les portes de la Citadelle | Dévoreur d'âmes, Tyrannus, fuite des salles des Reflets |
| 14 | 80 | 213 | La Flèche inférieure | Gargamoelle, Murmemort, Saurcroc |
| 15 | 80 | 219 | Les trois ailes | Putricide, prince Valanar, Lana'thel, Sindragosa |
| 16 | 80 | 225 | Le Trône de glace | le Roi-liche |

    - « auto » : 90 % de l'ilvl attendu au niveau du chapitre (courbe de l'écart d'équipement, 5.1).
    - Les quêtes d'origine (chapitres 8, 10, 12, 13) se valident par des « témoins » (900121 à 900125) que le serveur crédite à la fin de la quête d'origine, à l'acceptation du chapitre, ou à chaque visite au chroniqueur si elle était déjà faite.
    - Naxxramas (chapitre 11) n'a pas encore été étudié pour le jeu seul : à tester.
  - **Bonus d'XP de compte par chapitre** (`compte_bonus.lua`) : **+5 % par chapitre** terminé par un autre personnage du compte (16 chapitres : +80 %, provisoire), en plus du bonus des classes au 80 (3.4).
  - **Rendements décroissants** (`raids.cpp`, migration 046) : chaque entrée dans une nouvelle instance d'un raid compte un passage du jour (par personnage et par raid). Message à l'entrée (« passage 2 sur 3 aujourd'hui »). Au **4e passage**, le personnage est épuisé dans ce raid jusqu'au lendemain : les références de butin des boss donnent **deux fois moins d'objets** et chaque objet bleu ou mieux a deux fois moins de chances de tomber. Aura affichée : « Épuisement spectral » (44867, sans effet ; vrai nom avec le patch client de V7). Réglages `SolAzeroth.Raids.*` (provisoires).
- **Guide de jeu** : `Stratégies des raids seul.md` (dossier du projet), boss par boss pour Naxxramas et la Citadelle, avec les adaptations Sol'Azeroth. Décision de l'utilisateur du 28/10/2026 : Claude programme les adaptations d'après sa lecture des scripts, sans test dédié ; les retours viendront des vrais essais.
- **Naxxramas seul (recherche et adaptations du 28/10/2026, à tester en jeu)** — demandé par le chapitre 11 (Kel'Thuzad). Lecture des 15 scripts de boss :
  - **Faciles ou à régler par les chiffres** : Anub'Rekhan, Grande veuve Faerlina, Maexxna (l'Entoilage évite la cible du boss : seul, il ne touche jamais), Noth le Porte-peste, Heigan l'Impur (danse), Horreb, Grobbulus, Saphiron (le joueur gelé par l'Éclair de glace est protégé du Souffle de givre), Gothik le Moissonneur.
  - **À vérifier en jeu** : Instructeur Razuvious (les doublures se contrôlent au cristal d'obéissance) ; Kel'Thuzad (deux gardiens de la Couronne de glace en phase 3, prévus pour être entravés).
  - **Adaptés** (`naxxramas.cpp`, seulement quand un seul joueur est dans l'instance) :
    - Le Recousu : la Frappe haineuse frappe d'habitude le deuxième en menace ; seul, elle tombe chaque seconde sur le joueur. Elle ne fait que 25 % de ses dégâts ;
    - Gluth : la Décimation laisse le joueur à 50 % de sa vie au lieu de 5 % (les monstres restent à 5 %) ;
    - Thaddius : Stalagg et Feugen doivent tomber à moins de 5 s d'écart sur deux plates-formes séparées. Seul, les dégâts faits à l'un sont faits aussi à l'autre ; le Choc de la bobine Tesla (quand un serviteur quitte sa plate-forme) ne touche plus le joueur ;
    - Les quatre cavaliers : les marques sont prévues pour tourner entre quatre tanks. Seul, une marque ne fait jamais plus de 1 500 dégâts (le coût de la troisième pile).
  - **Classement provisoire** : 9 faciles, 2 à vérifier, 4 adaptés.
- **Autres raids du Norfendre (recherche et adaptations du 28/10/2026, à tester en jeu)** :
  - **Sans adaptation** : Onyxia, Caveau d'Archavon (4 boss), Sartharion, Malygos (phase 3 en drake à vérifier), bêtes du Norfendre, Jaraxxus, Anub'arak, et à Ulduar : Ignis (le Chaudron de scories évite la cible du boss), Tranchécaille, XT-002, Assemblée du Fer, Kologarn (la Poigne de pierre évite la cible du boss), Auriaya, Thorim, Vezax. Léviathan des flammes : combat en véhicules, le plus incertain, à vérifier.
  - **Adaptés** (`ulduar.cpp`, `croise.cpp`, seulement quand un seul joueur est dans l'instance) :
    - Freya : le trio de la première vague revit si les trois ne tombent pas à moins de 11 s d'écart. Seul, les dégâts faits à l'un sont faits aux deux autres, en proportion de leur vie ;
    - Mimiron : même partage entre les trois machines, en phase 4 seulement ;
    - Hodir : un joueur pris dans le Gel instantané est libéré au bout de 5 s ;
    - Yogg-Saron : un tentacule constricteur qui serre le joueur meurt au bout de 3 s ;
    - Algalon : le Coup de phase plafonne à 4 piles (à 5, le tank change de phase) ;
    - Champions de faction : les deux soigneurs et un des quatre autres meurent dès leur arrivée (il en reste trois). Ils sont tués et non retirés : le script compte les morts ;
    - Val'kyrs jumelles : le bouclier du Pacte des jumelles n'absorbe que 25 % de sa valeur.
  - Tous les raids du Norfendre sont dans le guide `Stratégies des raids seul.md`.
  - Pas encore fait : multiplicateurs propres aux raids dans mod-autobalance (à régler après de vrais essais).

### 4.8 Validation

Ragefeu en rang 0 se termine seul au niveau 13 avec un équipement de quête et donne son butin d'origine. En rang 5, le donjon est nettement plus dur, l'aura d'écart apparaît si l'équipement est trop faible, et le butin affiche « Affixe 5 » avec des stats correspondant à +5 ilvl.

## 5. Écart d'équipement (V5)

L'écart entre l'ilvl du joueur et l'ilvl attendu modifie ses dégâts et soins, avec un malus plafonné à −20 % et un bonus présenté en avant.

### 5.1 Calcul

- **Ilvl attendu :** une table `niveau de créature → ilvl attendu`, calibrée sur l'équipement d'origine du jeu (ilvl moyen des récompenses de quêtes vertes et bleues à ce niveau).
- **En donjon et en raid :** ilvl attendu = `ilvl_attendu(niveau du monstre) + rang de menace`.
- **Ilvl du joueur :** moyenne des ilvl **effectifs** de l'équipement porté (ilvl d'origine + palier d'enchantement de bonus, section 4.5), recalculée à chaque changement d'équipement.
- **Écart** = `ilvl_joueur − ilvl_attendu`.

### 5.2 Effets (valeurs de départ)

| Écart | Effet sur les dégâts et soins infligés | Effet sur les dégâts subis | Aura affichée |
| --- | --- | --- | --- |
| Inférieur à −3 | −2 % par point, plafond −20 % | +2 % par point, plafond +20 % | « Sous-équipé −X % » |
| De −3 à +3 | Aucun | Aucun | Aucune |
| Supérieur à +3 | +1 % par point, plafond +10 % | Aucun | « Bien équipé +X % » |

- La zone neutre évite de pénaliser le joueur qui vient de prendre un niveau.
- Les auras réutilisent l'icône d'un sort existant et affichent le pourcentage, pour que le joueur comprenne pourquoi le combat est dur ou facile.
- Toutes les valeurs sont en config.

### 5.3 Implémentation

Hooks de modification des dégâts et des soins d'AzerothCore (`UnitScript` ou équivalent ALE, noms exacts à vérifier).

### 5.4 Validation

Un personnage de niveau 40 avec un équipement d'ilvl 25 aux Serres-Rocheuses porte l'aura « Sous-équipé » et ses combats sont nettement plus longs. Avec un équipement de son niveau, l'aura disparaît. En donjon au rang 5 avec un équipement de rang 5, l'aura disparaît aussi.

### 5.5 Construit (V5 étape 1, 29/10/2026, à valider en jeu)

- **Décisions de l'utilisateur (29/10/2026)** : l'écart d'équipement est le premier morceau de V5. En donjon, l'ilvl attendu monte **proportionnellement** avec le rang (× (1 + 3 % × rang), comme le butin et la difficulté). Le niveau de défi extérieur ne change pas l'ilvl attendu.
- **Choix de Claude, provisoires, à recaler par l'équipe de calibrage (10.3)** :
  - **écart mesuré en %** de l'ilvl attendu, pas en points : 3 points pèsent 15 % au niveau 20 mais 2 % au niveau 80. Les valeurs de 5.2 deviennent : zone neutre ±5 % ; en dessous, −1 % de dégâts et soins et +1 % de dégâts subis par point au-delà de la zone neutre (plafonds −20 % / +20 %) ; au-dessus, +0,5 % par point (plafond +10 %). Le malus démarre au bord de la zone neutre, sans saut ;
  - **ilvl attendu** au niveau N = moyenne des récompenses de quête vertes et bleues (armes et armures) des quêtes de niveau N−5 à N, calculée au démarrage du serveur depuis la base du jeu. Environ 20 au niveau 20, 60 au 60, 105 au 70, 163 au 80. Les boss de monde comptent pour leur niveau − 3 ;
  - **ilvl du joueur** = moyenne des objets portés, chemise et tabard exclus, **emplacements vides ignorés** (sinon un personnage de bas niveau sans bague ni bijou serait puni). Un objet de rang R compte pour ilvl × (1 + 3 % × R) ;
  - les dégâts sont calculés à chaque coup selon le monstre touché ou qui frappe, familier compris. Les soins suivent l'écart face à la cible ou à l'adversaire du moment.
- **Affichage** : pas d'aura (un nom d'aura nouveau demande un patch client, V7). Un petit cadre d'addon `SolAzerothEcart`, déplaçable, affiche « Sous-équipé −X % » en rouge ou « Bien équipé +X % » en vert face au monstre ciblé ou combattu ; son infobulle donne les deux ilvl, l'écart et les effets. Il disparaît dans la zone neutre.
- **Code** : `ecart.cpp` (pas de migration), réglages `SolAzeroth.Ecart.*` ; le rang des objets est lu dans `solazeroth_objets_rang` (chargé au démarrage, tenu à jour par `bonus.cpp`).

## 6. Boucles de jeu

Chaque soirée de 1 à 2 h offre un choix au départ, un objectif clair, une récompense visible et une barre du Codex qui avance.

### 6.1 La soirée : le tableau de contrats (V3)

- **Pas de PNJ (décision du 27/10/2026, comme 3.6 bis) : les contrats se prennent dans une fenêtre d'addon.**
- Un PNJ par capitale propose **3 contrats de 20 à 45 minutes** : une prime de zone (élite rare), un donjon avec des affixes imposés, ou une commande d'artisan.
- Chaque contrat donne un coffre : monnaie, chance de butin de collection, points de Renom.
- On gagne 3 contrats par jour réel et on en stocke **jusqu'à 9** : une soirée sautée n'est pas perdue.
- **Thème de la semaine** (V5 ; d'abord prévu au mois, **passé à la semaine par décision de l'utilisateur du 30/10/2026**) : une table SQL de rotation, préparée une fois, oriente les contrats.
  - **Construit le 30/10/2026, à valider en jeu** : `contrats.cpp`, addon `SolAzerothContrats`, migration 040 (table `acore_world.solazeroth_themes`, colonne `theme` des contrats).
  - Un thème = **une famille de monstres + un métier**. Les 8 thèmes tournent dans l'ordre de la table, au même changement de semaine que l'affixe de la semaine : La grande traque (bêtes, travail du cuir), L'ombre du Fléau (morts-vivants, alchimie), Les portes de la Légion (démons, enchantement), Les éléments déchaînés (élémentaires, joaillerie), Le pas des géants (géants, forge), Bandits et renégats (humanoïdes, couture), Le vol des dragons (draconiens, calligraphie), La révolte des machines (mécaniques, ingénierie).
  - **Décisions de l'utilisateur** : les contrats du thème sont **mis en avant et payés plus** ; le thème n'agit **que sur les contrats**. Un contrat colle au thème si c'est une chasse ou une prime sur cette famille, un donjon dont la famille la plus nombreuse est celle du thème, ou une commande de ce métier.
  - Dans la fenêtre : une étoile devant le nom, en tête de liste, et une ligne « Thème de la semaine » avec sa description. Un contrat du thème rapporte **+50 % de Marques** (`SolAzeroth.Contrats.BonusTheme`, provisoire). Le thème est retenu à l'acceptation : il compte encore si la semaine change avant la fin.
- **Décisions de l'utilisateur (27/10/2026) :**
  - **quatre types de contrats**, tous tirés au niveau du personnage :
    - **chasse** : tuer N monstres d'une famille (bêtes, démons, morts-vivants…) dans une zone de son niveau ;
    - **donjon imposé** : finir un donjon précis de son niveau, à un rang de menace minimal ;
    - **prime de zone** : tuer un élite ou un rare nommé d'une zone de son niveau, plus une série de monstres de cette zone ;
    - **commande d'artisan** : fabriquer et livrer N objets d'un métier connu, à sa compétence actuelle ;
  - **réserve par compte** : les 3 contrats du jour (jusqu'à 9 en réserve) servent à n'importe quel personnage ;
  - **récompense** : environ 15 Marques et de l'or à son niveau, plus **25 % de chance d'un objet bleu de donjon** de son niveau au rang 3 (catalogue de l'intendant, 7.7). Les points de Renom viendront en V4.
- **Construction en trois étapes**, chacune testée en jeu : (1) tableau, réserve, récompense, chasse et donjon imposé ; (2) prime de zone ; (3) commande d'artisan.
- **Étape 1 construite le 27/10/2026, à valider en jeu** : `contrats.cpp`, migration 027, addon `SolAzerothContrats` (bouton de la minicarte ou `/contrats`).
  - Zones des monstres : la colonne `creature.zoneId` était vide pour 99 % des monstres. Elle a été remplie une fois avec l'option `Calculate.Creature.Zone.Area.Data` du serveur (un démarrage lent, sauvegarde avant), puis l'option a été remise à 0.
  - **Tableau** (refait le 27/10/2026 à la demande de l'utilisateur, au lieu de propositions tirées au sort) : onglets **Chasse** (toutes les zones et familles à son niveau), **Donjon** (tous les donjons à son niveau, avec le rang demandé) et **En cours** (3 contrats au plus). Accepter coûte un contrat de la réserve du compte ; abandonner ne rend rien.
  - **Étape 2, prime de zone (construite le 27/10/2026, à valider en jeu)**, onglet « Prime de zone » (migration 029) :
    - 551 cibles : les rares et élites rares du monde extérieur (3 apparitions au plus) et les élites nommés (une seule apparition), hostiles, à son niveau (même règle de plage de niveau que la chasse) ;
    - objectif : abattre la cible, plus 8 à 12 monstres hostiles non gris de la même zone (`SolAzeroth.Contrats.PrimeMin` et `PrimeMax`) ;
    - position donnée en coordonnées de carte (`Zone2MapCoordinates` du serveur) dans la liste, le contrat et le suivi, et **crâne sur la carte du monde** quand elle affiche la zone ;
    - un rare peut mettre des heures à réapparaître : si la cible est morte (ou attend sa réapparition) quand le joueur arrive dans sa zone avec le contrat, elle réapparaît ;
    - même récompense que les autres contrats.
  - **Étape 3, commande d'artisan (construite le 27/10/2026, à valider en jeu)**, onglet « Artisan » :
    - choix parmi les recettes connues qui fabriquent un objet et **ne sont pas grises** à sa compétence (métiers de fabrication, cuisine et secourisme) ;
    - **5 objets** s'ils s'empilent (potions, plats, bandages…), sinon **2** ;
    - l'onglet En cours et le suivi affichent le nombre déjà en sac ; le bouton « Livrer » retire les objets et remplit le contrat. Le serveur ne vérifie pas que les objets ont été fabriqués (achetés ou trouvés, ils comptent aussi).
    - **Depuis le 29/10/2026 (demande de l'utilisateur, contre les commandes de bas niveau)** : seules les recettes **enseignées par un maître de métier** (pas celles des marchands ni du butin) et demandant au moins **(niveau − 5) × 5** de compétence sont proposées. Cela fait 75 au niveau 20, 200 au niveau 45 (tisse-mage), 375 au niveau 80. Réglages `SolAzeroth.Contrats.ArtisanEcart` et `ArtisanParNiveau`.
  - **Correctif :** une chasse à Terokkar était proposée au niveau 40, à cause de monstres « niveau 1 à 70 ». Un groupe de monstres ne compte plus que si toute sa plage de niveau est entre niveau − 4 et niveau + 3.
  - **Réserve** : +3 par jour à 6 h (heure locale), 9 au plus.
  - **Chasse** : 15 à 25 monstres d'une famille dans une zone où au moins 20 monstres hostiles de cette famille sont proches du niveau du personnage (331 couples zone et famille). Les monstres gris ne comptent pas ; ceux tués par le familier comptent.
  - **Donjon imposé** : un des 60 donjons normaux dont le dernier boss valide la réussite, dans la tranche de niveau du personnage, au rang minimal « rang débloqué − 1 ».
  - **Récompense (provisoire, `mod_solazeroth.conf`)** : 15 Marques, niveau² × 50 pièces de cuivre (8 po au niveau 40), 25 % de chance d'un objet de l'intendant au rang 3 (remplacé par 15 Marques si les sacs sont pleins). Donnée directement, sans coffre à ouvrir.
  - Chasse testée en jeu le 27/10/2026. **Suivi en temps réel (demande de l'utilisateur)** : plutôt qu'une vraie quête (les objectifs « n'importe quelle bête d'une zone » n'entrent pas dans le format des quêtes du jeu), un petit cadre déplaçable, comme le suivi des quêtes. Il apparaît dès qu'un contrat est en cours, avec la progression (ex. « Bêtes (Strangleronce) 12 / 20 ») ; clic droit pour ouvrir le tableau. Le message de progression dans la discussion est retiré.

### 6.2 La semaine

- Rotation Fortifié / Tyrannique (section 4.4).
- Un **donjon vedette** à butin double.
- Le coffre bonus hebdomadaire de raid, cumulable sur 2 semaines (section 4.7).

### 6.3 Protection contre la malchance (V3)

- **Butin rare :** une monture à 1 % passe à 2 % après 20 passages, 5 % après 40, et elle est garantie au 60e.
- **Éclats :** un Éclat par boss vaincu sans l'objet voulu. 30 Éclats échangés contre l'objet au choix dans la table de ce boss.
- S'applique à tous les butins rares.
- **Décisions de l'utilisateur (27/10/2026) :** les boss de donjon laissant déjà choisir leur équipement (4.5 bis), les **Éclats ne concernent que les raids**, dont le butin reste au hasard. La protection des objets rares garde les paliers prévus (20, 40, 60).
- **Construit le 27/10/2026, à valider en jeu** : `malchance.cpp`, migration 030, onglet « Éclats » de l'addon d'apprentissage.
  - **Objets rares protégés** : tout objet (équipement, monture ou mascotte, qualité rare ou mieux) qu'un boss de donjon ou de raid laisse à **3 % ou moins** : 52 objets, dont les montures d'Anzu, Rivendare, Attumen, Onyxia, Al'ar et Zul'Gurub. Compteur par compte et par objet : la chance double à partir de 20 tirages ratés, vaut au moins 5 % à partir de 40, et l'objet est garanti au 60e. Le compteur repart à 0 quand l'objet est ramassé.
  - **Éclats** : chaque boss de raid vaincu (129 boss) donne **1 Éclat de ce boss** au compte, à chaque victoire (le serveur ne sait pas quel objet le joueur voulait). Avec **30 Éclats**, on échange l'objet de son choix dans la table du boss (équipement, monture, mascotte), donné au rang 0.
  - Réglages `SolAzeroth.Malchance.*` et `SolAzeroth.Eclats.Prix` dans `mod_solazeroth.conf` **(provisoires)**.
  - À tester plus tard : les raids ne sont pas encore au programme du joueur (V6). Ajouté à la liste 10.1.

### 6.4 Mesure du temps par activité (V1)

- Enregistrer en base le temps passé par activité (quêtes, donjons par rang, raids, métiers, contrats, ligues).
- Sert à recaler le budget du Codex (section 1.3) après un mois de jeu réel.

### 6.5 Le monde vivant (V5)

Des silhouettes aux apparences de joueurs peuplent les villes et les camps. Ce ne sont **pas des bots**, mais des PNJ ordinaires compatibles avec le core officiel.

- Assises, debout, seules ou en petits groupes. Elles marchent ou courent d'un point à l'autre.
- Elles « discutent » **uniquement par gestes et animations**, sans aucun mot : ni bulle, ni message dans la discussion.
- Elles ne combattent pas et ne peuvent être ni ciblées ni abordées (drapeau « non sélectionnable »).
- Apparences variées tirées au hasard parmi les modèles humanoïdes existants, armes en main, trajets en points de passage (waypoints).
- Un script ALE fait varier leur nombre et leurs places selon l'heure : plus de monde le soir en ville, des voyageurs sur les routes la journée.
- Coût faible à moyen, surtout du SQL. Risque faible.
- **Décisions de l'utilisateur (28/10/2026) :** **Hurlevent d'abord** (les autres capitales ensuite), densité **« animée »** (environ 80 silhouettes le soir, 30 le jour), **voyageurs sur les routes plus tard**.
- **Construit le 28/10/2026, à valider en jeu** : module C++ `ambiance.cpp` plutôt qu'ALE (la population suit le joueur, un tick par seconde), migration 042.
  - Un seul PNJ, **900110 « Aventurier »** : faction neutre, non sélectionnable, ni IA ni script. Son apparence est tirée parmi **742 modèles de joueurs** (table `solazeroth_ambiance_apparences`), ses armes parmi **220 jeux** (`solazeroth_ambiance_armes`, une silhouette sur deux est armée).
  - **Marcheurs** (environ la moitié) : ils marchent sur des tronçons des **63 trajets de patrouille** de Hurlevent (`waypoint_data`, 8 points ou plus), font demi-tour au bout. Durée de vie 3 à 6 min.
  - **Groupes de 2 à 4** : en cercle face au centre, un geste au hasard toutes les 4 à 9 s (parler, rire, montrer, saluer, s'interroger, approuver, refuser, acclamer). **Un groupe sur trois est assis**, sans gestes. Durée de vie 2 à 6 min.
  - Ils apparaissent entre **40 et 130 m** du joueur (jamais sous ses yeux), disparaissent au-delà de **170 m** ou au bout de leur temps ; tout disparaît 30 s après que le joueur a quitté Hurlevent.
  - Nombre selon l'heure de l'ordinateur **(provisoire, `mod_solazeroth.conf`)** : `SolAzeroth.Ambiance.Soir = 240` (18 h - minuit), `Jour = 90` (8 h - 18 h), `Nuit = 30`. `SolAzeroth.Ambiance.Enable = 0` coupe tout.
  - **Premier test en jeu (28/10/2026)** : cohérent dans l'ensemble (un gnome marchait un peu dans le sol). 80 / 30 / 10 jugé bien trop peu pour une capitale : **nombres multipliés par 3** à la demande de l'utilisateur. Apparitions accélérées : jusqu'à 10 marcheurs ou groupes par seconde (au lieu de 3), soit la ville pleine en 15 à 30 s.
  - **Deuxième retour (28/10/2026) : « ce qui rend vivant, c'est le mouvement »**. Neuf apparitions sur dix sont désormais des passants (environ **3 silhouettes sur 4 bougent**), **six passants sur dix courent**, et **un groupe sur cinq** seulement est assis (au lieu d'un sur trois).
  - **Troisième retour :** les coureurs semblaient accélérés (vitesse de course du garde copié, 1,43). Migration 043 : **vitesse d'un joueur** (course 7 m/s).
  - **Cavaliers immobiles** (demande du 28/10/2026, migration 044) : **40 silhouettes en selle**, à toute heure, à 2-5 m des trajets, **à l'extérieur seulement**. Montures tirées parmi **184 montures terrestres de joueur** (`solazeroth_ambiance_montures`, tirées de Spell.dbc : sorts appris par un objet, sans vol). Durée de vie 3 à 8 min. Réglage `SolAzeroth.Ambiance.Montures = 40` (provisoire).
  - **Dernière passe :** parmi les 40, **25 cavaliers se déplacent** sur les trajets (moitié au pas, moitié au galop à la vitesse d'une monture épique), les 15 autres restent immobiles. Réglage `SolAzeroth.Ambiance.MonturesMobiles = 25` (provisoire).
  - **Hurlevent validé en jeu par l'utilisateur le 28/10/2026.** Restent pour plus tard : autres capitales, voyageurs sur les routes, camps.
  - **Reste à faire :** autres capitales, voyageurs sur les routes, camps.
  - **Toutes les capitales, Shattrath et Dalaran (V8, 29/10/2026, construit, à valider en jeu)** : migration 051. `ambiance.cpp` anime maintenant chaque lieu de la table `solazeroth_ambiance_lieux` (carte, zone, camp, densité), avec ses propres trajets de patrouille (13 à 63 par ville). Mêmes règles qu'à Hurlevent.
    - **Apparences par camp** : la colonne `camp` sépare les 742 apparences de l'Alliance (042) et **762 apparences de la Horde** : orcs, morts-vivants, taurens, trolls et elfes de sang, tirées des PNJ d'Orgrimmar, des Pitons, de Fossoyeuse et de Lune-d'Argent, sans gardes, Kor'kron ni enfants. Shattrath et Dalaran mélangent les deux camps.
    - **Densité (provisoire)**, qui multiplie les nombres de la configuration : Hurlevent et Orgrimmar 1 ; Forgefer, Fossoyeuse et Lune-d'Argent 0,7 ; Shattrath et Dalaran 0,8 ; Darnassus, l'Exodar et les Pitons-du-Tonnerre 0,5. Elle s'applique aussi aux cavaliers. Fossoyeuse étant souterraine, elle n'aura presque pas de cavaliers (extérieur seulement).
    - Les montures restent communes aux deux camps.
    - **Retour de l'utilisateur (29/10/2026)** : capitales « ok », mais des cavaliers entraient à cheval dans les bâtiments. Les cavaliers qui bougent s'arrêtent maintenant avant le premier point en intérieur de leur trajet et font demi-tour (même test que le jeu pour les montures). Construit, à revoir en jeu.
  - **Villes, villages et relais de quêtes (V8, 29/10/2026, construit, à valider en jeu)** : migration 052, demande « build suivant » de l'utilisateur.
    - Un lieu peut maintenant être une **aire** (sous-zone, colonne `aire`) : le joueur doit s'y trouver.
    - **155 aires** hors capitales, avec un aubergiste ou un maître de vol et au moins 3 PNJ de service. Les aires qui couvrent toute une zone sont écartées. Répartition : 56 Alliance, 54 Horde, 45 mixtes (Baie-du-Butin, Gadgetzan…). Le camp vient de l'aubergiste et des maîtres de vol.
    - **Déplacement** : ces lieux n'ont presque pas de trajets de patrouille. Les passants vont donc d'un PNJ de service à un autre (aubergiste, marchands, maître de vol, donneurs de quêtes), à 8-100 m, en suivant le navmesh. Ils s'arrêtent à 2-4 m du PNJ. Les cavaliers ne visent que des points en extérieur. Les groupes se forment à 4-7 m d'un PNJ de service.
    - Apparition entre **20 et 90 m** du joueur (les villages sont petits), au lieu de 40-130 m.
    - **Densité provisoire** : 0,12 avec une auberge (environ 29 silhouettes le soir, 11 le jour, 5 cavaliers), 0,06 pour un relais sans auberge.
    - **Validé en jeu par l'utilisateur le 29/10/2026** (« ça a l'air cohérent »).
  - **Routes et campements (V8, 29/10/2026, validés par l'utilisateur le 29/10/2026)** : migration 053, dernière étape du chantier ambiance.
    - **Trajets** : table `solazeroth_ambiance_routes`, **494 trajets dans 54 zones**. Ce sont les patrouilles de PNJ humanoïdes non hostiles aux joueurs (gardes de route, caravanes), de 8 points et 150 m au moins, hors capitales. Les bêtes neutres sont écartées, car elles errent dans les champs. Chaque trajet garde le camp de son PNJ (244 Alliance, 134 Horde, 116 neutres). Une ligne « routes » (`genre = 1`) par zone dans `solazeroth_ambiance_lieux`.
    - **Où** : dans la zone, mais pas dans une de ses villes ou relais (qui ont leurs propres silhouettes), ni en vol.
    - **Qui (provisoire, `mod_solazeroth.conf`)** :
      - `Voyageurs = 8` voyageurs à pied par zone le jour, les deux tiers le soir, un tiers la nuit. Ils marchent, trois sur dix pressent le pas ;
      - `CavaliersRoute = 4` cavaliers à toute heure, au pas ou au galop, qui ne quittent pas l'extérieur ;
      - `Campements = 2` campements à toute heure : 2 à 4 silhouettes d'un même camp autour d'un feu de camp (objet 1798), à 8-14 m du trajet et dehors. Deux sur trois sont assises, les autres discutent par gestes. Le feu disparaît avec le campement.
    - Mêmes distances qu'en capitale : apparition entre 40 et 130 m, disparition au-delà de 170 m.
    - Après cette étape, le chantier ambiance est terminé, sauf retours en jeu. Les zones sans patrouille amicale (54 zones sur toutes celles du jeu) n'ont pas de voyageurs.
    - **Défaut connu, sans priorité (29/10/2026)** : un cavalier est encore entré dans la banque d'Orgrimmar dès les premières secondes. L'utilisateur juge que ce n'est pas important. Piste si besoin : les points du trajet sont dehors, mais la ligne droite entre deux points traverse l'entrée.
    - Ajouter un lieu (village, relais) = une ligne dans `solazeroth_ambiance_lieux`, à condition que la zone ait des trajets de patrouille.
  - **Objectif confirmé par l'utilisateur le 28/10/2026 : à terme, tout le monde.** Le monde entier doit être animé, pas seulement Hurlevent : toutes les capitales des deux factions, Shattrath et Dalaran, puis les villes, villages et relais de quêtes, les voyageurs sur les routes et les camps. La densité est adaptée à chaque lieu. Hurlevent sert de modèle.

### 6.6 Mode défi en extérieur (V3)

- Activable et désactivable à tout moment chez un PNJ en capitale, hors instance et hors raid.
- Le joueur choisit des affixes (mêmes principes que les donjons, section 4.4) : monstres extérieurs plus résistants et plus forts.
- En échange : bonus d'XP, d'or et de monnaie proportionnel aux affixes choisis **(valeurs provisoires, à équilibrer)**. Toutes les valeurs sont en config.
- Le niveau des monstres ne change pas : ce n'est pas la mise à l'échelle du monde (section 9.1), c'est un choix de difficulté.
- Implémentation probable : module C++ pour modifier les dégâts et les PV, ALE pour le PNJ et les bonus.
- **Validation :** avec le mode défi activé, un monstre de quête est nettement plus dur, et l'XP, l'or et les jetons gagnés augmentent du bonus annoncé.
- **Décisions de l'utilisateur (27/10/2026, début de V3) :**
  - pas de PNJ : tout passe par une **fenêtre d'addon** (comme 3.6 bis) ;
  - un **niveau de défi de 0 à 5** par personnage, sur le principe du rang de menace, plutôt que des affixes à cocher ;
  - on ne peut changer de niveau **qu'en zone de repos** (auberge, capitale) et hors combat ;
  - premier morceau construit de V3, avant les intendants, puis les contrats, puis la protection contre la malchance.
- **Construit le 27/10/2026, à valider en jeu** : module C++ `defi_exterieur.cpp` (migration 026), fenêtre dans l'addon `SolAzerothMenace` (clic droit sur son bouton de minicarte, ou `/exterieur`).
  - S'applique **hors instance** seulement, aux monstres que le personnage ou son familier combat. Ne se cumule donc jamais avec le rang de menace.
  - **Marques :** le défi extérieur n'en donne que par les **quêtes rendues** (pas par les monstres tués).
  - **Parade contre « faire la quête au niveau 0, la rendre au niveau 5 » (migration 028)** : chaque quête retient le niveau de défi le plus bas tenu depuis qu'elle a été prise (table `solazeroth_defi_quetes`). Le bonus de Marques et d'XP d'une quête rendue utilise ce niveau. Une quête prise avant ce suivi compte au niveau 0.
  - Premier réglage (+12 % de résistance et +8 % de dégâts par niveau) jugé **trop doux** par l'utilisateur. **Objectif du niveau 5 : avec deux monstres sur le dos, il faut jouer tactique** (mouton, immobilisation, ralentissement, mise à distance…).
  - D'où des **multiplicateurs propres à chaque niveau (provisoire, `mod_solazeroth.conf`)**, avec une courbe qui monte fort en haut. Le gain d'XP s'applique à toute l'XP gagnée hors instance, quêtes comprises.

| Niveau | Résistance | Dégâts | Danger (résistance × dégâts) | XP | Or ramassé | Marques des quêtes |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | ×1,15 | ×1,10 | ×1,3 | ×1,10 | ×1,10 | ×1,1 |
| 2 | ×1,35 | ×1,25 | ×1,7 | ×1,20 | ×1,20 | ×1,2 |
| 3 | ×1,55 | ×1,45 | ×2,2 | ×1,35 | ×1,35 | ×1,3 |
| 4 | ×1,75 | ×1,70 | ×3 | ×1,50 | ×1,50 | ×1,4 |
| 5 | ×2 | ×2 | ×4 | ×1,75 | ×1,75 | ×1,5 |

  - Bonus de Marques baissé le 27/10/2026 (d'abord ×1,2 à ×3) : voir l'équilibre des Marques en 7.5.

## 7. Codex, Renom, monnaie, quêtes et marchands

Le Codex rend la progression lisible, le Renom récompense le compte en confort, et la monnaie fait des quêtes une voie d'équipement aussi valable que les donjons en rang 0.

### 7.1 Codex et Archiviste (V4)

- Un PNJ, l'Archiviste, affiche le pourcentage de chaque ligne du Codex (section 1.3) et de chaque fin.
- Chaque entrée se découpe en morceaux de moins de 5 h.
- À chaque fin atteinte : haut fait, titre et générique.
- Avant V7, le Codex se lit dans le menu de l'Archiviste. En V7, il devient un onglet natif de l'interface.
- **Mesure du Codex (V4 étape 3, proposée par Claude et validée par l'utilisateur le 28/10/2026)** :
  - Pas de PNJ : fenêtre d'addon `SolAzerothCodex` (menu Sol'Azeroth, ou `/codex`). En haut, les trois fins ; dessous, les 13 lignes avec barre et détail.
  - Une ligne vaut ses heures (1.3) ; son pourcentage est la part accomplie de **ce qui existe aujourd'hui**. Ce qui n'existe pas encore (chaîne d'histoire, rangs de menace des raids, ligues, quêtes cachées, thèmes du mois, journal de collection) n'est pas compté : la ligne se recalcule quand il arrive. Fins emboîtées : Histoire = 250 h, Maître = 820 h (Histoire comprise), 100 % = 2 550 h. Meilleur résultat du compte, tous personnages confondus.
  - Histoire : expérience cumulée du meilleur personnage vers 80 (230 h ; le chevalier de la mort part du 55) + Roi-liche vaincu (20 h).
  - Donjons 1-5 et 6-10 : une case par donjon (carte) et par rang réussi, plafond selon l'extension (5 pour classique et Outreterre, 10 pour le Norfendre). Les réussites déjà enregistrées comptent. 51 donjons.
  - Raids du Norfendre (Maître) : les 8 raids terminés au rang 0. Raids anciens (100 %) : les 15 raids classiques et de l'Outreterre terminés. Un raid est terminé quand son dernier boss meurt (`solazeroth_raids_reussis`, à partir de maintenant).
  - Monde (Maître) : exploration des 4 continents (hauts faits du jeu, 60 h), 6 réputations principales du Norfendre exaltées (60 h), 50 primes de zone (30 h).
  - Métiers : 14 métiers, chacun selon sa valeur sur 450.
  - Défis de base : 274 boss de donjon dont le défi est réussi au moins une fois (`solazeroth_defis_reussis`, à partir de maintenant).
  - Monde (100 %) : 50 réputations exaltées (100 h), 100 élites rares tuées (50 h, compteur à partir de maintenant), 3 000 quêtes distinctes du compte (100 h).
  - Recettes rares : recettes apprises par objet et absentes des entraîneurs (1 722).
  - Classes : les 9 autres classes vers le niveau 80, la classe la plus avancée étant la principale (répond à la question ouverte de 11.2 : pas de ligues pour l'instant).
  - Collections : journal de collection à 80 % (150 h), 100 montures (75 h) et 100 mascottes (75 h) (journal ajouté le 28/10/2026, 7.3).
  - Défis et hauts faits : 100 défis « Sans filet » (100 h) et tous les hauts faits du compte (100 h).
  - Fin atteinte : haut fait du compte « Fin : Histoire / Maître / 100 % » (critère 6, migration 033). Titre et générique en V6.
  - Objectifs en nombre réglables : `SolAzeroth.Codex.*`. Technique : `codex.cpp`, commande `.solcodex` (préfixe SOLCODEX). **Validé en jeu le 28/10/2026.**

### 7.2 Renom du compte (V4)

- Chaque entrée du Codex donne des points de Renom.
- Les rangs de Renom débloquent du **confort, très peu de puissance brute** : sacs, contrat en réserve supplémentaire, affixes au menu, vol tardif (V8+).
- **Construit (V4 étape 4, proposé par Claude et validé par l'utilisateur le 28/10/2026)** : `renom.cpp`, migration 034, onglet « Renom » de la fenêtre du Codex (`/codex`, menu « Codex et Renom »). **Validé en jeu le 28/10/2026** (sac lié reçu, Marques en monnaie).
  - Points : **10 par heure de Codex accomplie + 5 par contrat terminé** (contrats comptés depuis V4). Le Renom ne redescend jamais (on garde le maximum atteint), même si le Codex baisse quand du contenu arrive.
  - Rangs (noms tranchés, question de 11.2) et récompenses :

    | Rang | Points | Récompense |
    | --- | --- | --- |
    | 1 Voyageur | 100 | Sac en tisse-néant (16 places) |
    | 2 Aventurier | 300 | Pierre de foyer : 15 min de recharge au lieu de 30 |
    | 3 Explorateur | 600 | Réserve de contrats 12 au lieu de 9 |
    | 4 Vétéran | 1 000 | Sac en tisse-givre (20 places) |
    | 5 Renommé | 1 600 | Affixe au menu : Fortifié ou Tyrannique au choix (sinon celui de la semaine), fixé à la création de l'instance |
    | 6 Héros | 2 500 | 4 contrats par jour au lieu de 3 |
    | 7 Champion | 4 000 | Sac glaciaire (22 places) |
    | 8 Légende | 6 000 | 500 Marques, une fois par compte |
    | 9 Mythe | 8 200 | 1 000 Marques, une fois par compte |
    | 10 Éternel | 12 000 | Vol en Kalimdor et Royaumes de l'Est (V8+). Renommé d'« Immortel » le 28/10/2026 pour ne pas se confondre avec le titre « l'immortel » du défi Or (3.3) |

  - Les sacs se réclament une fois **par personnage** et sont **liés au personnage** (demande de l'utilisateur : pas de personnage créé exprès pour transférer les sacs).

### 7.3 Journal de collection (V4)

- Façon OSRS : une case par objet de chaque boss.
- La ligne Collections du Codex compte le journal à 80 %, plus les montures, mascottes et apparences.
- **Construit le 28/10/2026 (V4 étape 5), en l'absence de l'utilisateur : choix de Claude, provisoires, à valider avec le test en jeu** : `journal_collection.cpp`, migration 036, addon `SolAzerothJournal` (menu Sol'Azeroth, ou `/journal`).
  - **Cases** : pour chacun des 393 boss de rencontre (donjons et raids, toutes difficultés), les objets de sa table de butin et des réserves qui lui sont propres (les réserves du monde, partagées par plus de 4 tables, sont écartées). Gardés : armes, armures, recettes et divers (jetons de set) de qualité rare ou mieux, plus montures et mascottes. **5 355 objets, 72 instances.** Un objet laissé par plusieurs boss coche la case de chacun.
  - **Ce qui coche une case** : objet pris sur un corps, objet choisi dans le butin de donjon, objet échangé contre des Éclats. **Pas** les achats chez l'intendant ni l'objet des contrats (sinon le journal s'achète). Collection par compte (`solazeroth_collection`).
  - **Pas de rattrapage** : ce qui a été obtenu avant le 28/10/2026 n'est pas compté (on ne sait pas distinguer un objet acheté d'un objet trouvé). À trancher : rattrapage à partir des objets possédés ?
  - **Fenêtre** : onglets Donjons et Raids, liste des instances avec « obtenus / total », puis chaque boss et la grille de ses objets (icône grisée si pas encore obtenu, coche sinon), infobulle de l'objet, case « Masquer les obtenus ». Message « Journal de collection : … ! » à chaque nouvel objet.
  - **Codex, ligne Collections (300 h)** : journal à 80 % (150 h), 100 montures (75 h), 100 mascottes (75 h). Les apparences ne sont pas comptées.

### 7.4 Hauts faits custom

- Avant V7 : suivis par ALE en base et affichés par l'Archiviste.
- En V7 : ajoutés à `Achievement.dbc` (et critères) côté client et serveur, pour apparaître dans l'interface native.
- Exemples : « Terminer toutes les quêtes de la Marche de l'Ouest », « Tuer 50 élites en Norfendre », « Réussir 3 donjons au rang 5 », « Explorer tous les Royaumes de l'Est ».
- Des **hauts faits cachés** et des **quêtes non signalées sur la carte** nourrissent la ligne Monde et la découverte.
- Chaque haut fait rapporte de la monnaie et une prime en or. **Fait le 28/10/2026** : 10 Marques et **1 po × niveau du personnage** (provisoire, `SolAzeroth.HautsFaits.OrParNiveau`).
- Certains hauts faits donnent un **bonus permanent** au compte **(valeurs provisoires)**.
  - **Bonus de compte (proposés par Claude le 28/10/2026, revus par l'utilisateur le 29/10/2026). Construits le 29/10/2026 (V4), à valider en jeu** :

    | Haut fait | Bonus |
    | --- | --- |
    | Explorer chaque continent | **+5 %** de vitesse de course hors combat par continent (20 % au plus) |
    | 25 / 50 / 100 contrats rendus | **+10 % / +20 % / +100 %** d'or des contrats |
    | Défis de boss réussis **sur un boss non gris pour le personnage**, par palier de 10 | **+2 % de points de vie par palier**, jusqu'à **+20 % à 100 défis** (décidé le 29/10/2026) |
    | Chaque métier de récolte à 375 (herboristerie, minage, dépeçage) | **+1 unité** à chaque récolte de ce métier |
    | Codex | **% d'XP de quête = le pourcentage de la fin « Histoire » du Codex** (décidé le 29/10/2026) |

    - Retirés par l'utilisateur : primes de zone, exalté auprès de 10 factions, « Sans filet » (+2 % de dégâts).
    - Le pourcentage du Codex s'applique à pleine valeur : Histoire à 40 % donne +40 % d'XP de quête. Réglable par `SolAzeroth.BonusHF.XpCodex`.
    - **Construction** : `bonus_hauts_faits.cpp`, réglages `SolAzeroth.BonusHF.*`, onglet **« Bonus »** de la fenêtre des hauts faits (`/hf`), qui donne chaque bonus avec sa valeur actuelle.
      - Bonus recalculés à la connexion puis toutes les 30 secondes.
      - Valeurs prises sur les compteurs du compte (contrats, défis de boss) et les hauts faits natifs d'exploration de n'importe quel personnage, pas sur les hauts faits custom.
      - **Défis de boss gris (décision de l'utilisateur du 29/10/2026)** : un défi réussi sur un boss gris pour le personnage (pas d'XP) ne compte pas pour les PV. Le bonus suit le compteur à part `defis_boss_niveau`, qui part de 0 le 29/10/2026. Les hauts faits « 10 / 25 / 40 / 200 défis » gardent le compteur `defis_boss`, qui compte tous les défis.
      - **Vitesse** : aura du sort 17498 « Vitesse », passive, réglée à la bonne valeur, retirée en combat et remise ensuite. Comme toutes les auras de vitesse de course, elle ne se cumule pas avec une autre (bottes enchantées, talents) : la plus forte l'emporte. Elle n'agit pas sur une monture.
      - **Points de vie** : crochet sur le calcul des PV maximum.
      - **XP de quête** : multiplie l'XP de la quête, en plus du défi extérieur.
      - **Récolte** : herbe ou minerai pris sur un objet du monde, cuir pris sur un monstre dépecé. Une unité de plus de l'objet récolté (pas des gemmes ni des éléments).
      - **Or des contrats** : appliqué à la récompense et affiché dans la fenêtre des contrats.
    - Choix de Claude : seuls les métiers de **récolte** comptent (l'utilisateur a parlé de « collectible »). Les métiers de fabrication ne donnent rien.
- **Points de talent de haut fait (V4, décision de l'utilisateur du 27/10/2026) :**
  - **50 hauts faits custom**, chacun rapporte **1 point de talent supplémentaire**. Ils sont **plutôt ardus**, et répartis **à tous les niveaux** (pas seulement au 80).
  - Hauts faits et points sont **partagés sur le compte** : un HF fait par un personnage vaut pour tous.
  - **Plafond : 1 point bonus par niveau** à partir du niveau 10, soit au plus 2 points de talent par niveau. Points bonus utilisables = min(points gagnés, niveau − 9). Les 50 sont donc utilisables dès le niveau 59 si les HF sont faits.
  - Une **réinitialisation des talents rend aussi les points bonus**. Moyen : le crochet `OnPlayerCalculateTalentsPoints` ajoute les points bonus au total calculé par le serveur ; la réinitialisation et les cinq spécialisations (3.8) les comptent donc d'office.
  - Les 50 hauts faits restent à définir.
- **Décisions de l'utilisateur au début de V4 (27/10/2026) :**
  - ordre : (1) moteur de hauts faits du compte, (2) les 50 hauts faits à point de talent, (3) Codex et Archiviste (en addon, comme le reste), (4) Renom, (5) journal de collection, (6) tableur d'équilibrage de l'or ;
  - la liste des 50 est proposée par Claude et validée par l'utilisateur ;
  - un **haut fait natif** du jeu obtenu par n'importe quel personnage compte pour tout le compte (critère possible de nos hauts faits et du Codex).
- **Les 50 hauts faits à point de talent (validés par l'utilisateur le 27/10/2026, rangés par type et non par niveau) :**

| Type | Hauts faits |
| --- | --- |
| **Donjons** (18) | Ragefeu rang 3 · Les Mortemines rang 3 · Cavernes des lamentations rang 3 · Ombrecroc rang 4 · les 4 ailes du Monastère écarlate rang 3 · Gnomeregan rang 4 · Uldaman rang 5 · Zul'Farrak rang 5 · Maraudon rang 5 · Temple englouti rang 5 · Profondeurs de Rochenoire rang 5 · Stratholme rang 5 · Scholomance rang 5 · Pic Rochenoire inférieur rang 5 · Hache-tripes rang 5 · 5 donjons d'Outreterre différents rang 5 · 5 donjons du Norfendre rang 5 · tous les donjons du Norfendre rang 3 |
| **Défis de boss** (5) | 10 réussis · 25 · 40 · 200 · 50 « Sans filet » |
| **Défi extérieur** (5) | 50 quêtes rendues en défi ≥ 3 · 150 · 500 · 300 monstres tués en défi 5 · 1 000 |
| **Contrats** (7) | 5 chasses · 15 contrats · 40 · 100 · 3 primes de zone · 10 · 25 |
| **Métiers** (6) | un métier principal à 150 · deux à 225 · deux à 300 · deux à 375 · cuisine, secourisme et pêche à 300 · tous les métiers à 450 |
| **Monde** (5, hauts faits natifs) | Explorer Kalimdor · Explorer les Royaumes de l'Est · Explorer l'Outreterre · Explorer le Norfendre · Exalté auprès de 10 factions (sur un personnage) |
| **Exploits** (4) | niveau 40 avec un personnage Hardcore · monture du baron Rivendare · Karazhan vaincu au rang 0 · le Roi-liche vaincu au rang 0 |

  - Nouveaux compteurs nécessaires (défis de boss par type, contrats, primes, quêtes rendues en défi, monstres tués en défi 5) : ils démarrent à la mise en service ; seuls les rangs de menace déjà enregistrés comptent rétroactivement.
- **Étapes 1 et 2 validées en jeu le 27/10/2026** : `hauts_faits.cpp`, migration 031, addon `SolAzerothHautsFaits` (menu Sol'Azeroth, ou `/hf`).
  - Définitions en base (`acore_world.solazeroth_hauts_faits`), réglables sans recompiler. Cinq critères : donjons à un rang de menace (`solazeroth_menace_reussites`), compteur du compte, haut fait natif d'un personnage du compte, métiers (meilleure valeur du compte), sort connu d'un personnage du compte.
  - Compteurs alimentés par les défis de boss, les contrats, le défi extérieur, le passage au niveau 40 d'un personnage Hardcore et la mort du prince Malchezaar et du Roi-liche.
  - Vérification à la connexion, toutes les 30 secondes et à chaque avancée d'un compteur. Chaque haut fait obtenu donne aussi **10 Marques** (`SolAzeroth.HautsFaits.Marques`, provisoire).
  - **Points de talent** : crochet `OnPlayerCalculateTalentsPoints`, bonus = min(hauts faits « talent » obtenus, niveau − 9). Le bonus est calculé dès le chargement du personnage : sinon le jeu, qui recalcule les points avant la fin de la connexion, réinitialiserait les talents d'un personnage qui a déjà dépensé ses points bonus.

### 7.5 Monnaie

- Nom : **Marque du voyageur** (choisi en V2).
- **Fait en V2** (`marques.cpp`, migration 018) : objet 900100 rangé dans les sacs, empilable par 5 000. **Depuis le 28/10/2026 (migration 035, demande de l'utilisateur : l'objet 900100, inconnu du client, s'affichait avec un « ? »)** : la Marque reprend l'objet 37711, jeton de test de Blizzard jamais utilisé et déjà connu du client comme monnaie (catégorie « Divers ») : vraie icône, onglet Monnaie de la fiche de personnage, sans patch client. Les Marques existantes ont été rendues à la connexion sous la nouvelle forme. Sources **(provisoires, `mod_solazeroth.conf`)** : boss de donjon 2 marques + le rang de menace, dernier boss + 5 ; quête rendue 1 marque + 1 tous les 20 niveaux du personnage (7.6) ; récompenses de défis (3.3) versées directement, ou à la connexion si les sacs sont pleins.
- **Boutique de marques** : onglet « Marques » de l'addon d'apprentissage (3.6 bis). Achats **de compte** : une fois payé, l'objet est gratuit pour les autres personnages du compte. Premier article : l'**Alarme-bombe ramasseuse**, 250 marques **(provisoire)**.
- **Bombinette ramasseuse** (`ramasseur.cpp`) : une vraie mascotte, la Bombinette (créature 9656, objet 11825), avec son apparence d'origine. Essayée d'abord avec l'apparence de l'Alarme-bombe 2600 de Gnomeregan, abandonnée (migration 022) car son animation de repos sonne l'alarme en permanence. Quand elle est sortie et que le compte l'a achetée à la boutique, tout monstre tué est ramassé automatiquement (or et objets ; ce qui ne rentre pas reste sur le cadavre). Une Bombinette fabriquée par un ingénieur reste décorative. Confort, pas puissance.
- **Marques des boss de donjon, une seule fois (décision de l'utilisateur du 29/10/2026, migration 037)** : par personnage, par boss et par rang de menace.
  - Une victoire à un rang plus haut que le dernier payé rapporte aussi les rangs inférieurs pas encore payés. Exemple : un premier passage direct au rang 3 paie les rangs 0, 1, 2 et 3.
  - Un rang déjà payé, ou plus bas, ne rapporte plus de Marques. Le butin ne change pas.
  - Les personnages existants touchent ce rattrapage une fois, à leur prochaine victoire sur chaque boss.
- **Équilibre des Marques (décision de l'utilisateur du 27/10/2026, après simulation au niveau 40) :** au départ, 5 ou 6 quêtes en défi extérieur suffisaient pour un objet de rang 3 chez l'intendant (environ 100 Marques par heure de quêtes en défi 5, objet à 40 Marques), ce qui rendait les donjons inutiles.
  - Quête rendue : **1 Marque, 2 dès le niveau 40, 3 au niveau 80** (`SolAzeroth.Marques.QueteNiveaux = 40`).
  - Défi extérieur : Marques des quêtes ×1,1 à ×1,5 (au lieu de ×1,2 à ×3).
  - Intendant : **40 + 1,5 × niveau requis** (100 Marques au niveau 40, 160 au niveau 80).
  - Résultat attendu au niveau 40 : quêtes ~22 Marques/h (défi 0) à ~33/h (défi 5), donjon au rang 2 ~40/h plus ses propres objets. Un objet d'intendant coûte 2,5 à 4,5 h : le donjon est la voie la plus rapide, l'intendant sert à viser un objet précis. Contrats inchangés (15 Marques, environ 7 par objet). La Bombinette (250 Marques) passe d'environ 8 h à 11 h de quêtes.
- **V2 :** un jeton dans les sacs.
- **V7 :** une vraie monnaie visible dans l'onglet Monnaie (`CurrencyTypes.dbc`). Les jetons déjà gagnés sont convertis.
- Sources : contrats, hauts faits, quêtes, défis de boss, un peu dans les donjons.

### 7.6 Quêtes sans mise à l'échelle du monde (provisoire)

Sans l'option de mise à l'échelle du monde (section 9.3), les quêtes gardent leur niveau d'origine. Avec l'option, une quête trop basse rapporte l'XP d'une quête du niveau du joueur moins 2.

- Les quêtes à leur niveau donnent leurs récompenses d'origine (XP, or, objets).
- Toute quête rendue rapporte aussi des jetons, **en quantité calculée sur le niveau du joueur**. Une quête grise garde donc un intérêt.
- Les quêtes restent comptées dans la ligne Monde du Codex, quel que soit leur niveau.

### 7.7 Intendants

- Un intendant par grande ville.
- Équipement par **paliers de 5 niveaux**, payé en jetons plus un peu d'or.
- Ilvl de cet équipement = celui du butin d'un donjon du même niveau en rang 0.
- Avant V7 : achat par menu (gossip) en ALE, qui retire les jetons et donne l'objet. En V7 : coûts natifs via `ItemExtendedCost.dbc`.
- **Décisions de l'utilisateur (27/10/2026) :**
  - pas de PNJ : un **onglet d'addon** remplace le menu ;
  - les objets sont le **butin bleu existant des boss de donjon** de chaque palier, aucun objet inventé ;
  - tous les objets d'intendant sont vendus **au rang 3** (avec l'enchantement de bonus du rang 3, section 4.5), pour ne pas multiplier les variantes ;
  - **équilibre du prix** en Marques et en temps : l'intendant doit être un vrai choix selon les goûts du joueur (quêtes et Marques contre donjons et choix du boss), pas la voie la plus rentable. Coût à caler sur le nombre de Marques gagnées par heure de jeu (journal d'activité, 6.4).
- **Construit le 27/10/2026, à valider en jeu** : `intendant.cpp`, onglet « Intendant » de l'addon d'apprentissage (`/apprendre`).
  - Catalogue calculé au démarrage : 1 453 objets bleus (armes et armures) propres aux boss de donjon, avec les mêmes règles que le choix de butin (4.5 bis).
  - Le joueur voit les objets de **son palier de 5 niveaux et des deux précédents**, jusqu'à son niveau. Le type d'armure ou d'arme n'est pas filtré (un prêtre peut acheter des plaques, section 3.7) ; seuls les objets réservés à d'autres classes par le jeu (« Classes : … ») sont cachés, car le serveur refuse de les équiper (décision : on garde ces restrictions). Chaque ligne indique le niveau, l'emplacement et le type d'objet.
  - Achat validé en jeu le 27/10/2026. **Filtres et tri (demande de l'utilisateur, à valider en jeu)** : colonne d'emplacements à gauche, bouton « Matière » (tissu, cuir, mailles, plaques ; n'écarte que les armures), bouton « Tri » (niveau décroissant ou croissant, prix, nom), plus la recherche par nom.
  - **Prix (provisoires, `mod_solazeroth.conf`) :** Marques = 40 + 1,5 × niveau requis (70 au niveau 20, 100 au niveau 40, 160 au niveau 80 ; relevé le 27/10/2026, d'abord 20 + 0,5 × niveau, voir 7.5) ; or = niveau requis² × 25 pièces de cuivre (1 po au niveau 20, 4 po au niveau 40, 16 po au niveau 80).
  - **Repère d'équilibre :** voir 7.5 (2,5 à 4,5 h de jeu par objet d'intendant au niveau 40).

### 7.8 Validation

Un haut fait custom s'affiche chez l'Archiviste (puis dans l'interface en V7), rapporte des jetons, et ces jetons permettent d'acheter un objet chez l'intendant.

## 8. Économie de l'or (sans hôtel des ventes)

Cible : chaque monture s'achète à son niveau de déblocage sans farmer l'or volontairement.

### 8.1 Sources

- **Quêtes :** or d'origine (section 7.6).
- **Contrats et hauts faits :** une prime en or.
- **Donjons et raids :** or qui augmente avec le rang de menace.
- **Butin et revente :** `Rate.Drop.Money` et prix de revente des objets et composants à ajuster.

### 8.2 Dépenses

- Ce qui existe déjà : formations, réparations, montures, sacs.
- **Marchand de composants rares :** il vend cher les matériaux difficiles à obtenir sans hôtel des ventes. Il sert à la fois de dépense d'or et de raccourci.
- La part d'or dans le prix des objets des intendants.

### 8.3 Méthode

- Un **tableur d'équilibrage** : revenu par heure selon l'activité (quêtes, contrats, donjons à chaque rang, récolte) et la tranche de niveau, comparé aux coûts de chaque tranche (formations, montures à 20, 40, 60, 70, 77 et 80, réparations).
- **Fait le 28/10/2026 (V4 étape 6), en l'absence de l'utilisateur, à relire** : `Equilibrage de l'or.xlsx` (dossier du projet). Quatre feuilles :
  - « Synthèse » : revenu, dépense et solde par palier de 10 niveaux ;
  - « Hypothèses » : réglages en bleu sur fond jaune (rythme de jeu, contrats, prix de la conf, niveaux d'achat des spés, réinitialisations) ;
  - « Par niveau » : une ligne par niveau, tout en formules ;
  - « Données » : moyennes extraites de la base (or des quêtes, or des monstres, coût des sorts de classe, XP).
  - Les heures de montée sont réparties selon le nombre de monstres à tuer par niveau (XP du niveau ÷ XP d'un monstre de même niveau), sur 230 h au total.
  - **Résultats avec les hypothèses de départ** (8 quêtes et 60 monstres par heure, 3 contrats par jour, 1 haut fait par niveau, une réinitialisation de talents tous les 20 niveaux, un quart des sorts d'une autre classe, spés achetées aux niveaux 10, 30, 60 et 80) : environ 18 400 po gagnées et 15 500 po dépensées de 1 à 80.
    - Le seul déficit est au niveau 70 (−316 po), dû au vol à 5 000 po, bloqué avant V8. Sans les trois formations de vol, il reste environ 9 000 po au niveau 80.
    - Toutes les montures au sol s'achètent à leur niveau sans farmer.
    - Les paliers 21-30 et 51-60 dépensent à peu près ce qu'ils gagnent (emplacements de spé à 250 et 1 000 po). Les réinitialisations de talents (≈ 1 000 po au total) et les sorts d'une autre classe (≈ 900 po) pèsent peu.
    - **Piste (à décider en V8)** : baisser le vol à 70, ou le faire payer en partie en Marques, pour que la cible de 8 (« chaque monture à son niveau ») tienne.
  - Non modélisé : métiers, réparations, consommables, or des donjons selon le rang de menace. À recaler sur les mesures réelles (6.4).
- Les revenus réels viennent de la mesure du temps par activité (section 6.4), une fois quelques semaines de jeu enregistrées.
- Ajustements par config et SQL, jamais en dur dans le code.

## 9. Repoussé et abandonné

Ces éléments ne doivent pas être commencés avant V8, et ceux de la liste « abandonné » ne doivent jamais être reproposés.

### 9.1 Repoussé à V8+

| Élément | Raison | Notes |
| --- | --- | --- |
| Mise à l'échelle du monde | Si les monstres montent avec le joueur, il ne se sent jamais plus fort | En option, **avec retard** : monstres 2 à 3 niveaux sous le joueur. Villes, PNJ de service, gardes et boss de monde exclus. XP et or des quêtes alors calculés sur le niveau du joueur. **Construite le 29/10/2026 (V8), à valider en jeu** : détail en 9.3 |
| PNJ d'ambiance dans le monde entier | Hurlevent fait (V5) ; toutes les capitales, Shattrath et Dalaran construits le 29/10/2026 (migration 051, validés en jeu), puis 155 villes, villages et relais (migration 052, validés), puis routes et campements de 54 zones (migration 053, à valider) | Section 6.5. Par étapes : capitales, puis Shattrath et Dalaran, puis villes et relais, puis routes et camps |
| Ligues Remix et Chaos | Dépendent de la mise à l'échelle du monde | Section 3.3 |
| Raids réécrits boss par boss | Très cher pour un gain modeste | Un boss à la fois, en ALE ou C++, en partant de la liste de faisabilité (section 4.7) |
| Vol dans Kalimdor et les Royaumes de l'Est | Très cher, défauts visibles | Récompense de Renom. Patch `AreaTable.dbc` et retrait de la restriction serveur sur les cartes 0 et 1. Défauts acceptés : zones inachevées, trous, murs invisibles |
| Extensions de contenu façon « Curator » | À étudier | L'utilisateur fournira la référence |

### 9.3 Mise à l'échelle du monde avec retard (V8, construite le 29/10/2026, à valider en jeu)

- **Décisions de l'utilisateur (29/10/2026)** :
  - **option par personnage**, désactivée par défaut, changeable à tout moment : `/sol` > Réglages > **Monde**, ou `.solechelle on` / `off` ;
  - **toute zone sous le niveau du joueur** : pas de notion de zone « terminée ».
- **Règle** (`echelle.cpp`, migration 054 `solazeroth_echelle`) :
  - hors instance, un monstre plus bas que le niveau du joueur moins 2 ou 3 remonte à ce niveau. Le retard (2 ou 3) est fixe pour chaque monstre ;
  - le jeu recalcule alors sa vie, ses dégâts, son armure et l'XP qu'il rapporte ;
  - jamais vers le bas : un monstre plus fort que le joueur le reste.
- **Exclus** : PNJ de service, gardes, civils, déclencheurs, bestioles, boss de monde, familiers et totems des joueurs, et tout ce qui est amical. Donjons, raids et champs de bataille ne sont pas touchés (autobalance s'en charge).
- **Quand** :
  - à l'apparition du monstre, d'après le joueur le plus proche qui a l'option ;
  - toutes les 3 s pour les monstres déjà présents à 200 m (option changée, montée de niveau), seulement hors combat, en pleine santé et **hors de la vue du joueur**. Couper l'option ramène les monstres remontés à leur niveau, eux aussi hors de vue. **Retour de l'utilisateur (29/10/2026)** : le changement de niveau doit être invisible, sans l'animation de gain de niveau. Donc un monstre ne change jamais de niveau sous les yeux du joueur ; un monstre remonté qui réapparaît devant lui garde son niveau ; l'option est lue avant l'entrée dans le monde, pour que les monstres chargés à la connexion apparaissent directement au bon niveau.
- **Quêtes** : une quête de niveau inférieur au niveau du joueur moins 2 rapporte l'XP d'une quête de ce niveau. L'or des quêtes du jeu suit déjà le niveau du joueur (récompense par niveau du core). Les Marques des quêtes (7.6) suivaient déjà le niveau du joueur.
- **Or et sorts (demande de l'utilisateur du 29/10/2026, construits le 29/10/2026, à valider en jeu)** :
  - l'or ramassé sur un monstre remonté est multiplié par le rapport entre l'or moyen des monstres normaux de son nouveau niveau et celui de son niveau d'origine (calculé au démarrage d'après la base). Exemple : un monstre de niveau 10 (10 pc) remonté au niveau 78 donne environ 21 pa ;
  - ses sorts (dégâts directs, dégâts sur la durée, soins) sont multipliés par le rapport de ses dégâts de base entre les deux niveaux, comme sa mêlée. Les sorts à dégâts d'arme suivent déjà la mêlée et ne sont pas touchés deux fois.

### 9.2 Abandonné

- **Bots joueurs** (mod-playerbots, NPCBots, leurs forks), même d'ambiance, même à terme.
- **Chat par IA** (il demande internet et une clé d'API).
- **mod-mythic-plus** (inachevé et dépendant de NPCBots).
- **10 variantes de chaque objet** dans `item_template` (remplacées par l'enchantement de bonus, section 4.5).
- **Déblocage des affixes donjon par donjon** (remplacé par le rang de menace de compte).
- **Verrou hebdomadaire de raid** (remplacé par le coffre bonus et les rendements décroissants).
- **Malus d'équipement de −40 %** (plafonné à −20 %).
- **Mise à l'échelle du monde dès le départ** (repoussée, voir 9.1).
- **Chapitres de contenu mensuels** écrits à la main (remplacés par le thème du mois piloté par données).
- **Ligue Ironman**, dans sa version du document comme dans celle de mod-challenge-modes : en solo il n'y a ni échange ni groupe, et tout l'équipement se ramasse ou se fabrique.

## 10. Feuille de route

Une première version complète et amusante arrive en V1, avec les seuls modules existants. La fin « Histoire » est jouable en V6. Les durées sont des estimations pour un travail avec Claude Code.

| Étape | Durée | Contenu | Validation en jeu |
| --- | --- | --- | --- |
| V0 ✔ (validée le 27/10/2026) | 1-2 sem. | AzerothCore compilé sous Windows, base de données, extraction maps/vmaps/mmaps, ALE. Config métiers (`MaxPrimaryTradeSkill`, `SkillGain.*`). Lanceur et sauvegardes (2.3, 2.4) | Un double-clic lance tout et connecte sur `127.0.0.1`. Un personnage apprend 3 métiers principaux et la compétence monte de 2. Une sauvegarde apparaît à la fermeture, à l'intervalle choisi, et quand on clique sur « Sauvegarder » dans le menu Échap |
| V1 ✔ (validée le 27/10/2026) | 1-2 sem. | mod-autobalance (1 joueur, niveau d'origine) ou mod-dungeon-scale, mod-arac et son patch, mod-transmog, mod-challenge-modes, mod-individual-xp. Mesure du temps par activité. Bonus d'XP et de réputation de compte. Ligue Hardcore. Maîtrises d'armes et d'armures (3.7) | Tauren mage créé (3.1). Transmogrification possible. Ragefeu terminé seul au niveau 13. Un personnage Hardcore qui meurt ne peut plus jouer. Critère 3.7 |
| V2 ✔ (validée le 27/10/2026) | 3 sem. | Rang de menace de compte, pierre d'entrée, formules, Fortifié / Tyrannique. Prototype de l'enchantement de bonus (ou repli à 4 paliers). Jeton de monnaie. Défis de boss. Métiers partagés sur le compte. Bonus solo par spécialisation. Cinq spécialisations (3.8) | Critère 4.8, sauf l'aura. Critère 3.2. Un défi de boss réussi donne son bonus. Critère 3.8 |
| V3 (construite ; passage à V4 décidé par l'utilisateur le 27/10/2026, tests restants en 10.1) | 3-4 sem. | Tableau de contrats et réserve, primes de zone, protection contre la malchance et Éclats. Intendants par menu. Mode défi en extérieur (6.6) | Une soirée type : 3 contrats faits, coffres reçus. Après un jour sauté, la réserve contient bien les contrats. Des jetons achètent un objet chez l'intendant. Critère 6.6 |
| V3b | 6-8 sem. | Grimoire universel (3.9) : module C++ des ressources pour toutes les classes, PNJ de sorts à onglets, nouveau grimoire en addon | Critère 3.9 |
| V3c | 2 sem. | Talents d'une autre classe (3.10) : fonction d'apprentissage du module, nouvel addon de talents, lien avec les cinq spécialisations | Un paladin place des points dans l'arbre Armes du guerrier ; il ne peut pas en placer dans un deuxième arbre étranger ; une réinitialisation rend tous les points ; passer d'une spécialisation à l'autre restaure l'arbre étranger |
| V4 | 3 sem. | Codex et Archiviste, journal de collection, Renom du compte, hauts faits custom en ALE (dont bonus mineurs et 50 points de talent de compte, 7.4), affichage des 3 fins. Tableur d'équilibrage de l'or, prix des sorts et des spés inclus | L'Archiviste affiche le pourcentage par ligne et par fin. Un haut fait custom rapporte jetons, or et Renom |
| V5 ✔ (validée le 28/10/2026) | 3-4 sem. | Écart d'équipement, 3-4 affixes de mécanique, affixes à points, thème du mois, ligue Destin, PNJ d'ambiance | Critère 5.4. Des PNJ d'ambiance animés et non ciblables sont visibles à Hurlevent le soir |
| V6 (commencée le 28/10/2026) | 4 sem. | Chaîne d'histoire (16 chapitres, sans raccourci : toute la Citadelle), Roi-liche réglé. Liste de faisabilité des boss WotLK. Rendements décroissants de raid | **Fin « Histoire » jouable :** le Roi-liche est vaincu seul en rang 0, avec haut fait, titre et générique. L'aura « Raid épuisé » apparaît au 4e passage du jour |
| V7 (commencée le 28/10/2026, périmètre revu en 10.2) | 3-4 sem. | Patch unique dans `Data\frFR` (fusion de mod-arac), hauts faits natifs, auras nommées, addon unifié au design choisi, connexion sans mot de passe en option | Critère 7.8 avec l'interface native. Les jetons existants sont convertis |
| V8+ | des mois | Section 9.1 : mise à l'échelle du monde avec retard, ligues Remix et Chaos, raids boss par boss, vol en récompense de Renom | Critères définis au moment de chaque chantier |
| Calibrage final | à définir | **Équipe d'évaluation montée par Claude** (demande de l'utilisateur du 29/10/2026), voir 10.3 | L'expérience reste exigeante d'un bout à l'autre, sans passage infaisable |

### 10.4 Publication sur GitHub (demande de l'utilisateur du 28/10/2026)

- **But** : un dépôt public, présenté sur Reddit (r/wowservers). Chacun peut reprendre, modifier et jouer.
- **Licence** : GPL v2, comme AzerothCore.
- **Préparation** : `py outils\exporter_depot.py` reconstruit la copie publique dans `Documents\Claude\Sol'Azeroth\github` puis l'analyse. L'analyse cherche les secrets, les chemins personnels et les fichiers de Blizzard (MPQ, DBC, BLP).
- **Contenu du dépôt** : le module, les scripts Lua, les migrations, les addons, les scripts PowerShell, les outils Python, le correctif de mod-challenge-modes, ce document et le guide des raids, un README en anglais et un LISEZMOI en français.
- **Exclus** : le client, les DBC, `config\mysql-acore.cnf` (remplacé par un exemple) et `config\client.txt`. Le chemin du client est lu dans `config\client.txt`, propre à chaque machine.
- **Réglages du serveur** : `scripts\configurer.ps1` applique les réglages Sol'Azeroth aux fichiers `.conf`. Il ne touche pas aux accès à la base.
- **Calendrier conseillé** : publier après la V7, pour que les captures montrent l'interface unifiée. Relancer l'export juste avant de publier. C'est l'utilisateur qui crée le dépôt et publie.

### 10.3 Calibrage final par une équipe d'évaluation (demande de l'utilisateur du 29/10/2026)

- **Pourquoi** : l'utilisateur, paladin 45 en équipement bleu de niveau 40, a « transpiré » sur une prime de zone au rang 4, et a aimé ça. Le personnage est très personnalisable (sorts et talents d'autres classes, spécialisations, maîtrises). Le jeu doit donc rester **exigeant** : investissement, risque, difficulté pour tuer, coût des achats.
- **Quoi** : à la fin de la feuille de route, Claude monte une **équipe d'évaluation** (plusieurs agents, chacun avec un angle : combat et difficulté, économie de l'or, Marques, progression et temps de jeu, builds abusifs). L'équipe s'appuie sur :
  - les journaux de donjon et la mesure du temps par activité (6.4) ;
  - le tableur d'équilibrage de l'or ;
  - les réglages de `mod_solazeroth.conf` et d'autobalance.
- **Règle** : viser **dur**, puis adoucir seulement ce qui se révèle vraiment infaisable. Cela couvre la difficulté des monstres, des boss et des rangs de menace, les gains et les prix en or et en Marques, le coût des sorts, des spés et des réinitialisations.
- **Résultat attendu** : une liste de réglages argumentée, validée par l'utilisateur, appliquée par config et SQL.

### 10.2 Chantier d'interface à prévoir (demande de l'utilisateur du 27/10/2026)

- Les fenêtres du projet sont réparties entre une dizaine d'addons, avec cinq boutons autour de la minicarte (apprentissage, rang de menace et défi extérieur, défis de création, spécialisations, contrats) et des commandes (`/arbre`, `/grimoire`, `/sacs`…). L'utilisateur se trompe souvent de bouton.
- À faire « au moment opportun » : **unifier l'interface en un seul addon**, avec un seul point d'entrée et des onglets (apprentissage, grimoire, talents, spécialisations, contrats, rang de menace, défis…), et un style commun.
- Le moment reste à choisir avec l'utilisateur (avant V4, ou avec le patch client de V7 qui permettrait une interface native).
- **Solution d'attente (validée en jeu le 27/10/2026)** : addon `SolAzerothMenu`, **un seul bouton Sol'Azeroth** autour de la minicarte. Un clic ouvre un menu vers toutes les fenêtres : apprentissage, grimoire des autres classes, talents d'une autre classe, spécialisations, contrats, rang de menace, défi en extérieur, défis du personnage, sacs, choix de butin en attente. Les cinq anciens boutons sont cachés ; les fenêtres et leurs commandes (`/apprendre`, `/rang`…) ne changent pas.
- **À garder pour la refonte (demande de l'utilisateur du 29/10/2026)** :
  - journal de collection : pour chaque donjon ou raid, un **filtre par type d'équipement** (ne voir qu'un type d'objet par boss) ;
  - journal de collection : le **modèle 3D de chaque boss**, pour que ce soit visuel.
- **Décision du 28/10/2026 (V7 lancée)** : intégrer au jeu de base tout ce qui peut l'être, et centraliser le reste dans **un seul addon** (sections, sous-onglets), avec un vrai design (« en l'état c'est vraiment austère »).
  - **Périmètre V7 validé :**
    1. outils Python pour lire et écrire les DBC et les MPQ ;
    2. un patch unique dans `Data\frFR`, qui absorbe celui de mod-arac ;
    3. hauts faits Sol'Azeroth natifs (DBC client + tables `achievement_dbc` du serveur) ;
    4. auras avec de vrais noms (`Spell.dbc`) ;
    5. addon unifié ;
    6. en option, connexion sans mot de passe (GlueXML).
    - Abandonnés : les coûts étendus des intendants (`ItemExtendedCost`) et l'onglet Codex natif. La monnaie existe déjà (objet 37711).
  - **Structure de l'addon unifié** :
    - Personnage : Apprentissage, Grimoire, Talents d'une autre classe, Spécialisations, Défis.
    - Aventure : Rang de menace, Défi extérieur, Contrats, Raids, Butin.
    - Collection : Codex et Renom, Journal, Hauts faits du compte.
    - Réglages : Plaques, Barres, Sacs, Sauvegarde.
  - **Design choisi** (sur trois maquettes, natif, carnet et épuré), un mélange :
    - la base **natif Blizzard** : cadre doré, portrait rond, onglets de section en bas, sous-onglets en haut, boutons rouges, textures du client ;
    - de l'épuré : les **pastilles rouges** de notification (butins en attente…) et la mise en **cartes** des spécialisations ;
    - du carnet : les pages de la section **Collection** sur **parchemin** avec lettrine (Codex, Renom, les trois fins).
- **V7 construite le 28/10/2026 (étapes 1 à 5, à tester en jeu)** :
  1. **Outils** (`C:\SolAzeroth\outils`) :
     - `mpq.py` lit et écrit les MPQ ; `dbc.py` lit et écrit les DBC ;
     - `verifier_outils.py` les vérifie : le patch de mod-arac est relu à l'identique, et les DBC du serveur font l'aller-retour octet pour octet.
  2. **Patch unique** `patch-frFR-4.MPQ` :
     - construit par `outils\construire_patch.py` avec tous les fichiers de `C:\SolAzeroth\patch-client\fichiers` ;
     - le lanceur le copie dans `Data\frFR` et range `Data\Patch-A.MPQ` dans `C:\SolAzeroth\archives`, car son contenu est repris dans le patch ;
     - **retour arrière** : remettre `archives\Patch-A.MPQ` dans `Data`, supprimer `Data\frFR\patch-frFR-4.MPQ`, et retirer les deux lignes du lanceur.
  3. **Hauts faits natifs** (`outils\hauts_faits_natifs.py`, migration 049) :
     - les 53 hauts faits du compte sont aussi des hauts faits du jeu (identifiant 9000 + id), dans une catégorie « Sol'Azeroth » de la fenêtre Hauts faits, avec 7 sous-catégories (Donjons, Défis de boss, Défi extérieur, Contrats, Métiers, Monde, Exploits), à 10 points chacun ;
     - un haut fait qui donne un point de talent l'affiche comme récompense ;
     - **progression** : chaque haut fait a un seul critère, de type « plus haute cote personnelle », avec une fausse équipe d'arène (1000 + id) qu'aucune vraie équipe (2c2, 3c3, 5c5) ne peut toucher. `hauts_faits.cpp` y écrit l'avancement du compte toutes les 30 s. Une barre s'affiche si le seuil dépasse 1 ;
     - à la connexion, chaque personnage reçoit les hauts faits déjà obtenus par le compte ;
     - l'addon SolAzerothHautsFaits reste, pour les bonus et le détail ;
     - le serveur charge bien les 53 critères (7 494 avant, 7 547 après).
  4. **Auras nommées** (`outils\auras_nommees.py`, migration 050, table `spell_dbc` et `Spell.dbc` du patch). Ce sont des sorts d'affichage sans effet : le module fait les calculs.
     - 100001 « Raid épuisé » remplace « Épuisement spectral » (44867) dans `raids.cpp` ;
     - 100002 « Sous-équipé » et 100003 « Bien équipé » : `ecart.cpp` les pose face au monstre de référence, avec **un cumul par point de %**. Le cadre `SolAzerothEcart` reste.
  5. **Addon unifié `SolAzeroth`** (`/sol`, clic gauche sur le bouton de la minicarte ; le clic droit garde l'ancien menu) :
     - **Personnage** : Apprentissage, Grimoire, Talents d'une autre classe, Spécialisations, Défis ;
     - **Aventure** : Rang de menace, Défi extérieur, Contrats, Butin (avec pastille rouge) ;
     - **Collection**, sur parchemin avec lettrine : Codex et Renom, Journal de collection, Hauts faits du compte (et un bouton vers la fenêtre Hauts faits du jeu) ;
     - **Réglages** : Plaques de nom, Barres et sacs, Sauvegarde (maintenant, ou intervalle de 5 à 60 min) ;
     - chaque sous-onglet accueille la fenêtre de l'addon d'origine, sans son cadre ni son titre, et réduite si elle est trop grande. Les commandes (`/codex`, `/contrats`…) et les fenêtres qui s'ouvrent seules (choix du butin) ouvrent la fenêtre Sol'Azeroth sur le bon sous-onglet ;
     - **Spécialisations** en cartes : la spé active en grande carte, avec l'icône et les points de ses trois arbres ; les autres en petites cartes, deux par deux.
  - **V7 validée en jeu par l'utilisateur le 28/10/2026** : patch unique (races et classes libres toujours présentes), hauts faits natifs, `/sol`, `/codex`, aura « Sous-équipé », spécialisations en cartes.
  - **Retours du test du 28/10/2026** :
    - les plaques de nom montraient deux noms superposés, un grand rouge et un petit blanc. Le nom d'origine est maintenant recaché à chaque mise à jour. **À revoir en jeu.** Si le rouge reste, c'est le nom affiché au-dessus de la tête des PNJ (réglage `UnitNameNPC`) ;
    - « en l'état, seul le cadre est refait » : l'utilisateur demande de refaire tout le contenu des pages.
  - **Refonte du contenu des pages (construite le 28/10/2026, à voir en jeu)** :
    - un **habillage commun** s'applique à toutes les pages accueillies, sans changer leur logique :
      - fond sombre : les lignes deviennent brunes, bordées d'or, avec un dégradé et un reflet. Les couleurs d'état sont gardées (vert = obtenu, or = actif) ;
      - les barres de progression ont un fond, un liseré et une texture plus douce ;
      - les icônes de sort et d'objet sont rognées, avec un liseré doré ;
      - sur parchemin (Collection), les lignes sont claires et translucides, et les textes passent à l'encre brune ;
    - les pages **Barres et sacs** et **Sauvegarde** sont refaites en cartes, avec icône, titre et boutons ;
    - **ensuite** : retouches page par page, à partir des captures d'écran de l'utilisateur.
    - **Retouches d'après la vidéo de l'utilisateur (28/10/2026, à revoir en jeu)** :
      - les petites pages sont agrandies jusqu'à ×1,3 pour remplir la fenêtre ;
      - sur parchemin, l'en-tête est replacé : le titre sortait du cadre et la lettrine ne se voyait pas. Les textes clairs, y compris les couleurs dans le texte, y sont assombris en gardant leur teinte ;
      - Apprentissage : la case « Déjà appris » ne chevauche plus l'or, et les boutons du bas (« Compétences » débordait) ont une largeur adaptée à leur texte ;
      - Contrats : la fenêtre est élargie (560 × 440), avec des lignes plus hautes et plus larges. Les descriptions sur deux lignes ne se chevauchent plus ;
      - Plaques de nom : le bouton « Réglages d'origine » passe sous la dernière case ;
      - **noms d'objets** : Apprentissage (Intendant, Éclats) et le suivi des contrats affichaient « Objet 862 » (« pas très sexy de mettre les ID d'objet dans le jeu », 28/10/2026). Le client ne connaît un nom qu'après l'avoir demandé au serveur, un par un et lentement. Correction :
        - nouvelle commande serveur `.solnoms id,id,…` (`addon.cpp`) : elle renvoie les noms dans la langue du joueur (préfixe d'addon `SolAzerothNoms`) ;
        - l'addon `SolAzeroth` fournit `SolAzerothNomObjet(id)` : il demande les noms manquants par paquets de 30 et les garde d'une session à l'autre (`SolAzerothDB.noms`) ;
        - Apprentissage, Contrats et Butin l'utilisent. En attendant la réponse, ils affichent « Chargement... », jamais un numéro.
    - **Retouches d'après la 3e vidéo (28/10/2026, à revoir en jeu)** : Contrats, Butin et Sorts sont propres, et le suivi affiche bien « Commande : Bottes en lin écru ». Restait :
      - Intendant : « Chargement... » ne disparaissait pas. La liste n'était redessinée que s'il manquait encore des noms : quand tous arrivaient d'un coup, le dernier dessin n'avait jamais lieu. Corrigé dans Apprentissage et Contrats ;
      - Codex : la lettrine était cachée par le fond de la page. L'en-tête est maintenant sur un cadre au-dessus des pages. La note sous les barres tient sur une ligne, et les détails des lignes ne passent plus sur la ligne suivante.
    - **4e vidéo (28/10/2026)** : les noms d'objets s'affichent à l'Intendant. Le Codex montrait encore l'ancienne version : le jeu n'avait pas été relancé par le lanceur, qui recopie les addons. Corrigé : à l'Intendant, « À une main (Haches à une main) - rang 3 » passait sous le prix. Pour une arme, seul le sous-type reste (« Haches à une main »). « rang 3 » est retiré, car tous les objets de l'Intendant le sont. La ligne est coupée à la largeur disponible.
    - **5e vidéo (29/10/2026)** : note du Codex et « Raids anciens » sur une ligne, comme prévu. Restait :
      - Intendant : il ne restait que « Niveau 45 ». Le nom venait du cache Sol'Azeroth, donc l'objet n'était plus chargé par le client, et son emplacement et son type restaient inconnus. L'objet est maintenant chargé tant que `GetItemInfo` ne répond pas ;
      - la lettrine ne s'affichait toujours pas. Sa police passe de 34 à 30 (hypothèse : taille trop grande pour le client), à confirmer en jeu.
  - **Pas faits** :
    - sous-onglet « Raids » : aucune fenêtre n'existe encore, les passages du jour restent annoncés à l'entrée ;
    - étape 6, connexion sans mot de passe : elle demanderait d'écrire le mot de passe dans un fichier du client ou de changer le serveur de connexion. **Décision à prendre par l'utilisateur.**

### 10.1 Construit, à tester plus tard en jeu

- **Demandes de l'utilisateur du 28/10/2026 (construites, à tester en jeu)** :
  - **plus de déconnexion pour inactivité** : `PreventAFKLogout = 2` dans `worldserver.conf` (le serveur refuse la déconnexion demandée par le client après 30 minutes d'absence) et `SocketTimeOutTime = 86400000` (24 h à l'écran de sélection des personnages au lieu de 15 min). Le client passe toujours seul en « Absent » après 5 minutes : c'est ce qui permet au serveur de reconnaître la déconnexion automatique, donc la marque reste. L'addon `SolAzerothAbsence` cache les messages « Vous êtes maintenant absent » et « Vous n'êtes plus absent » ;
  - **plaques de nom** : addon `SolAzerothPlaques` (`/plaques`, et entrée « Plaques de nom » du menu Sol'Azeroth), dans l'esprit de Plater. Barre de vie réglable (largeur, hauteur, texture, texte de vie, taille du texte, niveau), bordure blanche sur la cible, barre d'incantation en dessous, affaiblissements au-dessus avec temps restant et cumul (taille, nombre, seulement les miens). Le jeu 3.3.5 ne donne les affaiblissements d'un monstre que s'il est cible, focalisation ou sous la souris : ils sont gardés par monstre, et le journal de combat tient à jour ceux qu'on pose soi-même ;
  - **retours du test ICC du 28/10/2026 (Testhistoire, farouche, ilvl 252, Fortifié)** — citadelle complète en 48 min, en tuant surtout avec `.damage 100 pct` :
    - **Valithria** : les soins à la mort des monstres n'étaient pas lisibles (12 gros monstres à 6 %, 24 vers à 1 % : des bonds à quelques moments seulement). Chaque soin est maintenant annoncé : « Archimage ressuscité tué : Valithria reprend 6 % (74 %) ». Construit, à revoir en jeu ;
    - **antichambre de Sindragosa** (salle fermée, nérubiens par vagues) : 3 vagues de 30 nouveau-nés, plus 8 nérubiens deux fois et 6 gardiens. Seul, deux nouveau-nés sur trois meurent dès leur arrivée (10 par vague). Construit, à revoir en jeu ;
    - **Roi-liche** : 1,17 million de PV (17,4 millions d'origine), coups de mêlée d'environ 3 000 sur 21 900 PV en forme de félin. À juger en vrai jeu, sans raccourci, avant de toucher à l'autobalance des raids (réglage prévu en V6).
  - **raccourci de test** : `.damage 100 pct` sur la cible inflige ses PV max au nom du joueur (butin, réputation et progression comptent). `.die` ne convient pas : avec `Die.Command.Mode = 1`, le monstre meurt sans butin. Les boss scriptés gardent leurs règles (phases, PV plancher du Roi-liche).
- **Retours de test du 29/10/2026** :
  - **validés** : journal de collection, Codex, intendant, recharge de la réserve de contrats, donjon, défi extérieur, or des hauts faits ;
  - **or** : 45 po pour Ombrecroc au rang 4, à revoir avec le tableur plus tard ;
  - **corrigé, à revérifier** :
    - les sorts des autres classes disparaissaient à chaque connexion. Le serveur les supprimait parce que leur compétence n'existe pas pour la classe du personnage : option `ValidateSkillLearnedBySpells = 0` dans `worldserver.conf`. Les sorts déjà perdus avant ce jour ne sont pas récupérables : ils manquent dans les sauvegardes ;
    - plus de messages dans la discussion pour les défis de boss, le choix de butin et les nouveaux objets du journal ;
    - Marques des boss de donjon une seule fois par personnage, par boss et par rang, avec rattrapage des rangs inférieurs (7.5) ;
    - commandes d'artisan limitées aux recettes de maître de métier à son niveau (6.1) ;
    - Fortifié et Tyrannique affichent leur effet (fenêtre de menace, menu d'affixe du Renom) ;
  - **probablement pas un bug** : boissons de mana « perdues » à la reconnexion. Aucune erreur d'enregistrement ; l'utilisateur vend régulièrement tout le contenu de ses sacs ;
  - **validé le 29/10/2026** : Marques des boss une seule fois par rang, rangs inférieurs rattrapés ; prime de zone complète (crâne sur la carte et la minicarte, cible, fin du contrat, au rang 4) ;
  - **crâne de la prime absent (corrigé le 29/10/2026, à revérifier)** : `contrats.cpp` convertissait la position de la cible dans le mauvais sens (`Zone2MapCoordinates`, qui va de la carte vers le monde, au lieu de `Map2ZoneCoordinates`). Les positions envoyées à l'addon étaient donc fausses : pas de crâne et pas de coordonnées lisibles. Le crâne est sur la carte du monde, ouverte sur la zone de la cible, et **sur la minicarte** (ajout demandé par l'utilisateur le 29/10/2026). Le serveur envoie la taille de la zone en mètres. Hors de portée, le crâne reste au bord de la minicarte, à demi transparent, dans la direction de la cible ;
  - **message d'autobalance à l'entrée des donjons retiré** (`AutoBalance.PlayerChangeNotify = 0`).
- **Protection contre la malchance et Éclats (6.3, V3)** : compteur d'un objet rare (ex. la monture de Rivendare à Stratholme), Éclats d'un boss de raid et échange à 30. Pas encore accessible au personnage.

## 11. Questions ouvertes et décisions provisoires

Six décisions ont été prises par défaut pour combler des trous ; huit questions restent à trancher avec l'utilisateur.

### 11.1 Décisions provisoires (à confirmer)

| Décision | Pourquoi | Section |
| --- | --- | --- |
| Le patch client de mod-arac est accepté dès V1 | mod-arac en a besoin pour afficher les nouvelles combinaisons | 3.1 |
| Les métiers partagés sur le compte arrivent en V2 | Ils avaient disparu de la feuille de route alors que le Codex demande tous les métiers à 450 | 3.2 |
| Toute quête rapporte des jetons calculés sur le niveau du joueur | Sans mise à l'échelle du monde, les quêtes grises n'auraient plus d'intérêt | 7.6 |
| Sorts des autres classes au prix d'entraîneur × 10 | « Cher mais atteignable » ; réglable en config, à recaler avec le tableur (V4) | 3.9 |
| Spés supplémentaires à 50 / 250 / 1 000 / 2 500 po | Double spé accessible, 5e spé comme objectif de fin de jeu | 3.8 |
| Maîtrises d'armes et d'armures à prix modéré | Confort plutôt qu'investissement principal | 3.7 |

### 11.2 Questions à trancher

- [ ] Courbe d'ilvl attendu par niveau (5.1) : à calibrer sur l'équipement d'origine, puis à ajuster en jeu.
- [ ] Valeurs de l'écart d'équipement (5.2) : zone neutre ±3, −2 % / +1 % par point, plafonds −20 % et +10 %. À valider en jeu.
- [x] Plafond de butin des raids : **tranché**, rang de menace 0 à 5 et butin plafonné à +5 ilvl (4.7).
- [ ] mod-autobalance ou mod-dungeon-scale (4.1) : à décider après un test sur Ragefeu.
- [x] Courbe d'XP : **tranché**, le joueur choisit sa vitesse avec mod-individual-xp (`.xp set`, section 3.4).
- [ ] Nom des affixes. Rangs de Renom : **tranché le 28/10/2026** (7.2). (Monnaie : **Marque du voyageur**, tranché en V2.)
- [ ] Seuil de « quête grise » et barème de jetons par niveau (7.6).
- [ ] Extensions de contenu façon « Curator » : l'utilisateur fournira la référence.
- [x] Ligne « Classes » du Codex (500 h) : **tranché le 28/10/2026**, elle compte les 9 autres classes montées vers le niveau 80, sans ligues pour l'instant (7.1).
- [ ] Ligues : l'achat de sorts, de maîtrises et de spés est-il autorisé en Hardcore ? (Destin : **tranché le 30/10/2026**, ni sorts ni talents d'autres classes ; spés et maîtrises permises.)
- [ ] Connexion sans mot de passe, avec un choix parmi les comptes (demande de l'utilisateur, non urgente) : l'écran de connexion est dans l'interface du client (GlueXML), qu'un addon ne peut pas modifier. Piste : l'intégrer au patch client unique de V7.
