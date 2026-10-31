# Sol'Azeroth v3 — Document de conception

Refonte en profondeur décidée par l'utilisateur le 30/10/2026. Le jeu actuel (v2, voir « WoW Solo — Document de conception v2.md ») est jugé trop facile : on saute du contenu. Ses contraintes d'interface et de ressources sont aussi trop lourdes. La v3 garde les fondations techniques et réécrit le jeu lui-même.

## 1. Principe

On se réapproprie la maison : on garde les murs porteurs et on refait le reste.

- **Ce qu'on garde** : le serveur AzerothCore et le module, le lanceur, les sauvegardes, les migrations de la base, la fabrication du patch client et le dépôt GitHub.
- **Ce qu'on réécrit librement**, même en profondeur et quitte à beaucoup déboguer :
  - le serveur, dont on a tout le code source ;
  - l'interface du jeu.
- **Les murs porteurs** : le programme du client (`Wow.exe`), avec l'affichage 3D, la caméra et les déplacements. On ne le modifierait qu'en dernier recours, avec l'accord de l'utilisateur.

**La v3 remplace la v2 tout de suite** (série 4) : l'utilisateur ne veut pas maintenir la v2, il repart sur une dynamique propre. Un repère dans le dépôt GitHub garde la v2 en mémoire.

**Interface épurée et moderne** (série 4) : peu d'éléments à l'écran. Restent bien visibles le cadre de la cible et les buffs et débuffs.

**Écran de combat validé le 31/10/2026** : maquette « 6 · Synthèse », sur la toile de maquettes https://claude.ai/artifact/5nV5Cc2JHM94pFnHtGe4Py (privée).
- **Personnage**, repris de la maquette Immersif :
  - vie et Rempart en deux arcs fins autour du guerrier ;
  - losange du passif ;
  - buffs en petites pastilles ;
  - puissance « 142 / 140 » sous le Rempart ;
  - deux petites barres de 4 techniques translucides en bas au centre, chaque recharge sous un voile avec les secondes ;
  - un halo sur une technique mise en avant.
- **Cible**, reprise de la maquette Tactique : grand cadre en haut au centre, avec élite, vie en chiffres et en %, incantation très visible, et débuffs grands et chronométrés.
- **Zone**, reprise de la maquette Arène, en haut à droite : suivi de zone (pourcentage, reliques), mini-carte et menu.
- **Allure** : fond graphite, police Inter seule, un seul ambre pour le Rempart.

**Vérifié le 30/10/2026 : l'interface peut être entièrement remplacée.** Le client charge des fichiers d'interface Blizzard (FrameXML, GlueXML) modifiés dans notre patch, et ce code garde les droits de Blizzard en combat. Un test a pu cacher le cadre protégé du portrait en plein combat. L'interface v3 se fait donc directement dans ces fichiers, et non en addons.

## 2. Décisions de fond (séries de questions du 30/10/2026)

### 2.1 Niveau et puissance
- **Le niveau est caché et fixe en coulisses**, par exemple tout le monde au niveau 80, monstres compris. Le joueur ne voit jamais de niveau.
- **La progression passe par la puissance**, qui vient surtout de l'équipement (niveau d'objet et rang d'amélioration), avec une petite part tirée des autres systèmes de progression.
- **Calcul de la puissance** (série 5) : chaque objet porte un chiffre de puissance, qui dépend de sa qualité, de son origine et de son rang d'amélioration. La puissance du personnage est la moyenne de ses objets, plus un petit bonus des autres systèmes. Un seul chiffre, comme un niveau d'objet moyen.

### 2.2 Monde et zones
- **Monde ouvert**, chaque zone ayant une puissance conseillée.
- **Une zone couvre une plage de puissance, découpée en secteurs** (précision de l'utilisateur, 31/10/2026). Par exemple, Durotar va de 1 à 10 :
  - la Vallée des épreuves vers 1 à 3 ;
  - les alentours de Razor Hill vers 4 à 6 ;
  - les camps du sud vers 8 à 10.

  On avance dans la zone à mesure qu'on gagne en puissance.
- **Puissance d'un monstre** : par défaut, son niveau d'origine chez Blizzard, qui gradue déjà les monstres de chaque zone ; en coulisses, il passe au niveau fixe.
- **Puissance d'un secteur** : celle de ses monstres, corrigeable secteur par secteur dans une table.
- **Malus hors de sa puissance** : dans une zone trop forte pour lui, le joueur subit un malus de dégâts proportionnel à son manque de puissance.
  - Il réduit seulement les dégâts que le joueur inflige ; les monstres restent normaux (série 5).
  - Il se calcule face à la puissance du monstre combattu, et non face à celle de toute la zone.
  - Exemple de courbe, à calibrer : −2 % par point de puissance manquant, avec un plafond.
- **Une zone se suffit à elle-même** : ses quêtes, ses primes et ses contrats sont en accès libre, avec des défis difficiles et de belles récompenses. Les quêtes qui envoient dans une autre zone sont écartées pour l'instant.
- **Nettoyer la zone prépare son donjon** :
  - à 60 % (quêtes, primes, contrats…), on l'aborde correctement, « pas comme un touriste » ;
  - à 100 %, on l'aborde sereinement.
- **Ce qui compte dans le pourcentage** (série 6) : tout. Quêtes de la zone, primes et contrats, lieux nettoyés (camps, grottes, repaires, chef compris), exploration et secrets.
- **Les paliers** (série 6) :
  - **60 % ouvre l'accès au donjon de la zone**, et rien d'autre ;
  - **100 %** n'apporte pas de bonus en soi : c'est le meilleur équipement gagné en chemin qui rend le donjon bien plus serein qu'à 60 %.
- **Les défis difficiles de zone** (série 6) :
  - **les reliques cachées** un peu partout, à toutes récolter ; une carte qui dévoile leur position s'achète ;
  - **des élites renforcés**, rares et bien plus forts que la zone, avec leurs propres techniques ;
  - **des vagues** de monstres de plus en plus dures, avec un classement de la vague atteinte ;
  - **du contre-la-montre** : nettoyer un lieu ou tuer une cible en temps limité, avec médaille bronze, argent ou or.

### 2.3 Combat
- **Plus aucune ressource** (rage, énergie, mana, runes, points de combo) : seulement des temps de recharge, à la manière de Riven dans League of Legends.
- **8 techniques actives**, sur deux barres de 4 l'une au-dessus de l'autre, plus **un passif** qui fait l'identité de la spécialisation.
- **Les 8 techniques se choisissent dans un panel** propre à la spécialisation (une quinzaine), qui s'agrandit en progressant.
- **Au moins 3 spécialisations par classe**, en DPS, tank ou hybride DPS/tank selon la classe.
- **Soins** :
  - aucune spécialisation de soin pur, ni de kit de soin ;
  - les spécialisations hybrides se soignent en infligeant des dégâts ;
  - les classes qui avaient une spécialisation de soin gardent un sort de soin à fort temps de recharge.
- **Pas de chance de toucher** : tout coup porte.
- **Plus de menace** (série 5) : en solo, les monstres n'ont que le joueur à frapper. Le tank se définit par sa résistance, sa capacité à regrouper les monstres et à en tenir beaucoup à la fois. Les provocations deviennent des techniques qui attirent les monstres à soi.

### 2.4 Caractéristiques de l'équipement
- **Jeu simplifié et lisible**. Premières pistes : Puissance (dégâts), Vie, Armure, Critique, Hâte (réduit les temps de recharge) et Vol de vie.
- **L'armure devient une réduction fixe des dégâts subis**, retirée de chaque coup.
- **Tous les objets sont réécrits** selon ce modèle.
- **Les conditions pour porter un objet** sont les nôtres, plus de niveau requis.
- **Arsenal façon Genshin Impact (idée de l'utilisateur, 31/10/2026, pour plus tard)** :
  - **Les armes suivent la spécialisation.** En passant tank, le personnage est équipé tout seul d'une épée et d'un bouclier ; en berserker, de deux armes à une main ; en armes, d'une arme à deux mains.
  - **On ne change plus d'arme par le sac.** Une fenêtre présente les armes possédées pour la spécialisation, et le joueur choisit celle à porter. Il peut garder une vieille arme bien améliorée plutôt qu'une nouvelle, si ses statistiques sont meilleures.
  - **De même pour tout l'équipement**, emplacement par emplacement.
  - Se marie avec l'amélioration des objets (page Amélioration de la v2, à recycler) et avec la puissance tirée de l'équipement (§2.1).
  - **Questions à trancher** :
    - chaque spécialisation garde-t-elle son propre équipement choisi ?
    - un objet gagné va-t-il directement dans l'arsenal, sans passer par le sac ?
    - que deviennent les objets en double ou dépassés : recyclés en matériaux d'amélioration ?

### 2.4 bis Métiers (idée de l'utilisateur, 31/10/2026, pour plus tard)
- **Métiers de récolte** (minerais, plantes…) :
  - **connus dès le départ**, sans apprentissage ni niveau de compétence ;
  - on garde les modèles du jeu pour les filons et les plantes, mais leurs **icônes sont remplacées par celles du jeu actuel** (retail).
- **Nos propres recettes**, avec des icônes retail elles aussi.
  - Cela supposera d'extraire beaucoup d'icônes depuis Wowhead, avec le même outil que pour les techniques (`outils\icones_retail.py`). Le téléchargement en masse se fera avec l'accord de l'utilisateur.
- **Les autres métiers** viendront au compte-gouttes, plus tard.

### 2.5 Donjons
- **Façon Genshin Impact** : le premier passage a un accès gradué.
- **Le rang d'aventurier** est un rang de compte qui monte avec tout ce qu'on accomplit : quêtes, primes, contrats, zones nettoyées, donjons réussis. Ses paliers débloquent des difficultés supplémentaires, avec des récompenses à la hauteur. Il ne donne pas de puissance.
- **Une réputation globale des donjons et raids**, commune à toutes les instances, qui monte :
  - surtout en terminant un donjon ou un raid ;
  - un tout petit peu à chaque monstre tué, pour inciter à nettoyer le donjon entier.
- **Ce qu'apporte cette réputation** (série 4) : des techniques actives et passives à choisir à l'entrée de chaque donjon. Plus le rang de réputation est haut, plus il y a de choix et d'emplacements d'amélioration.

### 2.6 Mort
- **Retour à la pierre de foyer, sans aucune perte.**

### 2.7 Rang d'aventurier : le confort de jeu (série 4)
En plus des difficultés de donjon, ses paliers débloquent du confort :
- la compétence de monte à un certain palier ;
- des montures, que l'on peut aussi obtenir autrement ;
- une pierre de foyer qui se recharge plus vite.

### 2.8 Inventaire sans limite (série 4)
- **Plus de banque.**
- **Un inventaire complet des objets à collectionner** (composants, matériaux…), sans limite de quantité.
  - Il est **exhaustif** (précision de l'utilisateur, 31/10/2026) : trié par catégorie, il montre tous les objets à collectionner du jeu.
  - Un objet qu'on n'a pas est grisé ; un objet qu'on a est en couleur, avec le nombre possédé.
- **Pas de sac de départ** : les objets gris ne servent à rien et sont retirés du butin (migration 068).
- **La vie ne remonte que par le feu de camp, la potion du module et les sorts.** Nourriture, boissons, potions de Blizzard, bandages et pierres de soins sont bannis.

### 2.9 Ce qu'on recycle de la v2
- **Contrats et primes**, pour accumuler une monnaie.
- **Améliorations d'objets** avec les Marques.
- **Rangs de menace**, qui deviennent les difficultés des donjons.

## 3. Guerrier tank : brouillon de kit (proposition de Claude, à valider)

Ce brouillon sert de base de discussion : chiffres, noms et choix sont à reprendre ensemble. La ressource est remplacée par les temps de recharge. Un temps de recharge global de 1 seconde sépare deux techniques. L'attaque automatique reste.

### 3.1 Passif d'identité : Rempart
- Chaque coup encaissé, après l'armure, verse **25 % de ses dégâts dans le Rempart**.
- **Le Rempart est un bouclier** qui absorbe les coups suivants. Il est plafonné à 30 % de la vie maximale et se vide doucement hors combat.
- **Certaines techniques consomment le Rempart** pour frapper ou se soigner.
- **Le choix permanent** : garder le Rempart pour se protéger, ou le dépenser pour rendre les coups.

### 3.2 Les 8 techniques de départ
| Technique | Recharge | Effet |
| --- | --- | --- |
| Frappe du bouclier | 6 s | Gros dégâts à la cible, remplit le Rempart d'un montant fixe |
| Coup de tonnerre | 8 s | Dégâts autour de soi ; les ennemis touchés frappent 20 % moins vite pendant 10 s |
| Charge | 15 s | Bond sur la cible, étourdit 1 s |
| Cri de défi | 12 s | Attire vers soi tous les ennemis à moins de 15 m (regroupement) |
| Riposte du rempart | 10 s | Consomme le Rempart : 150 % du montant consommé en dégâts à la cible et autour |
| Second souffle | 45 s | Consomme le Rempart : soigne de 100 % du montant consommé |
| Ravage | 10 s | Dégâts autour de soi, +10 % par ennemi touché (jusqu'à +50 %) |
| Mur protecteur | 90 s | −50 % de dégâts subis pendant 8 s |

### 3.3 Techniques du panel, débloquées en progressant
| Technique | Recharge | Effet |
| --- | --- | --- |
| Heurt de bouclier | 12 s | Interrompt une incantation et réduit au silence 3 s |
| Fracasser armure | 8 s | Réduit l'armure de la cible (cumulable 3 fois) |
| Onde de choc | 20 s | Cône devant soi, étourdit 2 s |
| Bond héroïque | 20 s | Saut vers un point, dégâts à l'arrivée |
| Dernier rempart | 120 s | +30 % de vie maximale pendant 15 s, et le Rempart est rempli |
| Renvoi de sort | 20 s | Renvoie le prochain sort reçu |
| Désarmement | 30 s | La cible inflige 50 % de dégâts en moins pendant 6 s |
| Vengeance | 8 s | Utilisable seulement si le Rempart est plein : gros dégâts, ne consomme pas le Rempart |

## 4. Première zone : Durotar

- **But de la première zone** : nettoyer tout Durotar, Vallée des épreuves comprise. Le Gouffre de Ragefeu en est l'aboutissement.
- **Personnage de test** : guerrier, spécialisation tank.
- **Rôle du test** : vérifier que le jeu est amusant et exigeant avant d'étendre la refonte au reste d'Azeroth. Il construit une première tranche de jeu, mais le contenu de Durotar visé reste toute la zone.

## 6. Plan technique des fondations (proposé le 31/10/2026, à valider)

Le principe : chaque étape se termine par une compilation, un démarrage propre du serveur et un essai en jeu par l'utilisateur. Le moteur d'AzerothCore reste intact tant qu'un point d'accroche existe. Quand il faut le modifier, la modification est gardée sous forme de patch, comme `patches\mod-challenge-modes.patch`. Le nouveau code va dans des fichiers `v3_*.cpp`, ce qui demande une seule reconfiguration de la compilation.

### F0. Bascule en v3
- Sauvegarde complète, puis réglage `SolAzeroth.Version = 3`.
- On coupe les systèmes v2 qui contredisent la v3 :

  | Coupés | Repris plus tard, adaptés |
  | --- | --- |
  | échelle du monde, écart de niveau, défi extérieur | contrats et primes |
  | rangs de menace actuels | Marques et amélioration d'objets |
  | spécialisations et talents v2 | butin, intendant |
  | formation (achat des sorts), mod-autobalance, mod-individual-xp | hauts faits, codex, ambiance |

- Les personnages v2 ne sont plus jouables en v3 : on repart de nouveaux personnages, après sauvegarde.
- **Construit le 31/10/2026** :
  - sauvegarde complète permanente dans `backups2-final` (bases et réglages) ;
  - `SolAzeroth.Version = 3` : le chargeur du module ne charge plus les 15 systèmes v2 (`mod_solazeroth_loader.cpp`) ;
  - `AutoBalance.Enable.Global = 0` (mod-individual-xp était déjà coupé) ;
  - 8 addons v2 rangés dans `addons-v2` et retirés du jeu par le lanceur : Écart, Formation, Grimoire, Menace, Spécialisations, Talents, Ressources, Défis ;
  - leurs pages sont retirées de `/sol` et du menu de la minicarte ;
  - le cache des rangs d'objets, utilisé par les améliorations, se charge maintenant de lui-même, sans le système d'écart.

  Au démarrage, la base signale encore des commandes et des scripts v2 sans code : c'est attendu, on fera le ménage plus tard.

### F1. Niveau caché et fixe
- **Joueur** : tout nouveau personnage commence directement au niveau 80, sans expérience à gagner. Les conditions de niveau des objets sont alors toujours remplies.
- **Monstres** : ils sont tous au niveau 80. Leur vie et leurs dégâts viennent de **leur puissance**, c'est-à-dire leur niveau d'origine, corrigeable par secteur dans une nouvelle table `solazeroth_v3_secteurs`. Le moteur offre l'accroche pour fixer le niveau (`OnBeforeCreatureSelectLevel`).
- **Interface** : le niveau n'est plus affiché nulle part.
- **Vérification** : un nouveau guerrier niveau 80 et un sanglier de Durotar au niveau 80 se battent à armes égales. Ni l'un ni l'autre n'écrase l'autre.

  **Construite le 31/10/2026**, pas encore vérifiée en jeu :
  - `configurer.ps1` : `StartPlayerLevel` et `StartHeroicPlayerLevel` = 80, `Rate.Talent = 0` (plus aucun point de talent) ;
  - migration 060 : les statistiques de base du niveau 80 (`player_class_stats`) deviennent celles du niveau 1. Le chevalier de la mort, qui n'a pas de niveau 1, prend celles du guerrier. Les anciennes valeurs sont gardées dans `solazeroth_v3_stats_80` pour l'annulation ;
  - `v3_niveau.cpp` : chaque créature garde les statistiques de son niveau d'origine, retenu comme sa puissance (`SolAzeroth::PuissanceCreature`), puis passe au niveau 80. Les familiers sont exclus. La puissance d'attaque des joueurs est calculée comme au niveau 1.

  Premier test en jeu (31/10/2026) : un sanglier tué en 6 coups blancs, sans critique, pour moins de 10 % de vie perdue. La vie revenait aussitôt, car la régénération selon l'Esprit remplit en quelques secondes une réserve de 70 PV. Correction :
  - cette régénération est coupée (`Rate.Health = 0.001`, le jeu refuse 0) ;
  - hors combat, le joueur récupère `SolAzeroth.V3.RegenVie` = 3 % de sa vie maximum toutes les 2 secondes, soit la vie pleine en un peu plus d'une minute ;
  - les familiers des joueurs ne régénèrent presque plus ; à revoir avec les classes à familier.

  Pas encore fait : la table des secteurs, et le masquage du niveau à l'écran (prévu en F4).

  À surveiller :
  - les quêtes basses s'affichent en gris ;
  - l'or des quêtes suit le niveau 80 ;
  - les sorts des monstres qui grandissent avec le niveau du lanceur peuvent frapper un peu plus fort.

  On calibrera tout cela plus tard.

### F2. Règles de combat
- **Plus de raté, d'esquive, de parade ni de blocage** : tout coup porte, et seul le critique reste. Pour la mêlée, le moteur offre l'accroche `OnBeforeRollMeleeOutcomeAgainst`. Pour les sorts, c'est à vérifier ; à défaut, petit patch du moteur.
- **Armure = réduction fixe** : le pourcentage d'armure du moteur est neutralisé et remplacé par une réduction fixe, retirée de chaque coup.
- **Plus de ressource** : rage, énergie, mana, runes et combos ne sont plus ni utilisés ni affichés.
- **Puissance du personnage** : moyenne des objets, chiffre envoyé à l'interface. Elle sert aussi à calculer le malus hors zone.

  **Construite et vérifiée en jeu le 31/10/2026** : un sanglier tombe en une quinzaine de coups blancs, contre 6 avant F2, car l'armure retire maintenant des points fixes à de petits coups. Tous les coups portent, dans les deux sens. La régénération est faible mais acceptable.
  - **patch du moteur** `patches\azerothcore-v3-combat.patch` : trois accroches ajoutées au moteur (ratés des sorts, armure, coût des sorts), sur 6 fichiers ;
  - `v3_combat.cpp` :
    - **tout coup porte**, en mêlée, à distance et pour les sorts. Les effets comme l'étourdissement ne sont plus résistés. Plus de coup érafle ni de coup écrasant, même face à un boss. Le critique reste. L'immunité, le renvoi de sort et la fuite d'un monstre (évasion) restent aussi ;
    - **armure** : chaque coup physique perd armure ÷ 20 points de dégâts (`SolAzeroth.V3.ArmureParPoint`), mais garde au moins 25 % de sa valeur (`SolAzeroth.V3.ArmureMinimum`). Les sorts magiques ne passent pas par l'armure ;
    - **ressources** : plus aucun sort ne coûte de mana, de rage, d'énergie ou de puissance runique, pour les joueurs comme pour les monstres. Les sorts payés en vie gardent leur coût. Les barres restent affichées jusqu'à l'interface v3 (F4) ;
    - **puissance** : moyenne des niveaux d'objet équipés (chemise et tabard exclus), +3 % par rang d'amélioration. C'est provisoire, en attendant les chiffres par qualité et origine (question 3). Elle part toutes les 2 secondes vers l'interface (message `SOLPUISSANCE`), et la commande `.puissance` l'affiche avec celle de la cible ;
    - **malus** : face à un monstre plus fort, les dégâts du joueur et de ses familiers baissent de 2 % par point de puissance manquant, au plus 75 % (`SolAzeroth.V3.MalusParPoint`, `SolAzeroth.V3.MalusMax`).

  À surveiller :
  - les attaques qui consomment toute la rage restante (Exécution…) gardent ce comportement jusqu'au kit v3 (F3) ;
  - les points de combo et les runes ne sont pas encore traités : on les verra avec les classes concernées.

### F3. Kit du guerrier tank
- **Les 16 techniques** sont créées comme sorts propres (outil existant `auras_nommees.py` : Spell.dbc du client et table `spell_dbc` du serveur). Chacune a un coût nul, un temps de recharge, des valeurs fixes et aucune posture requise.
- **Le passif Rempart** est écrit dans le module : bouclier rempli par les coups reçus, et consommé par Riposte et Second souffle.
- **Le panel** : 8 techniques équipées sur les deux barres, et le choix des autres au repos.

  **Décisions de l'utilisateur (31/10/2026)** :
  - le brouillon de la partie 3 est construit tel quel, et les chiffres se calibreront en jouant ;
  - la spécialisation se choisit dès l'entrée en jeu ;
  - on démarre avec le passif et 4 techniques, puis une technique se débloque tous les 5 points de puissance ;
  - les icônes viennent de la version retail (Wowhead), pour un aspect plus moderne.

  **Construite le 31/10/2026**, pas encore vérifiée en jeu :
  - **sorts** 100009 à 100028 (`outils\techniques_v3.py`, appelé par `auras_nommees.py`, migration 061). Chaque technique copie un sort de Blizzard pour son visuel et son ciblage. Elle n'a ni coût, ni posture, ni arme ou bouclier requis. Elle a sa propre recharge et un temps de recharge global de 1 s. Elle sort de la famille du guerrier, si bien qu'aucun talent ni script de Blizzard ne s'y accroche ;
  - **dégâts** : ce sont des pourcentages des dégâts de l'arme, pour suivre l'équipement. Frappe du bouclier 200 %, Coup de tonnerre 100 % à 8 m, Ravage 100 % (+10 % par ennemi), Onde de choc 150 %, Bond héroïque 100 %, Vengeance 300 %. Ces chiffres sont des propositions de Claude ;
  - **icônes** : 17 icônes retail (`outils\icones_retail.py`, à lancer avec `py -3.11`), converties en BLP et ajoutées à `SpellIcon.dbc` sous `Interface\Icons\SolAzeroth_*` ;
  - **`v3_kit.cpp`** :
    - le Rempart est une aura d'absorption (100010). Les dégâts encaissés la remplissent, qu'ils soient absorbés ou non ;
    - les réglages : `SolAzeroth.V3.Rempart.Part` = 25 %, `Plafond` = 30 % de la vie, `Fuite` = 1 % toutes les 2 s hors combat, `FrappeBouclier` = 5 % ;
    - six SpellScripts : Frappe du bouclier, Riposte, Second souffle, Ravage, Vengeance, Dernier rempart ;
    - les anciens sorts du guerrier (postures, Frappe héroïque…) sont retirés ;
    - la table `solazeroth_v3_kit` garde la spécialisation et les techniques équipées (migration 062) ;
    - commandes `.kit`, `.kit spe tank` et `.kit equiper <sorts>` (hors combat) ;
  - **ordre de déblocage proposé**, à corriger :
    - au départ : Frappe du bouclier, Coup de tonnerre, Charge, Riposte du rempart ;
    - puis, à 5 points de puissance : Cri de défi ; à 10 : Second souffle ; à 15 : Ravage ; à 20 : Mur protecteur ; à 25 : Heurt de bouclier ; à 30 : Fracasser armure ; à 35 : Désarmement ; à 40 : Onde de choc ; à 45 : Bond héroïque ; à 50 : Renvoi de sort ; à 55 : Vengeance ; à 60 : Dernier rempart ;
  - **addon `SolAzerothKit`**, provisoire jusqu'à F4 :
    - une page Techniques (`/kit`, ou `/sol` section Personnage) pour choisir la spécialisation, puis cocher 8 techniques ;
    - une jauge du Rempart sous le cadre du joueur.

  Choix et limites :
  - Charge devient utilisable en combat ;
  - Désarmement ne désarme pas vraiment : il réduit les dégâts de 50 %, pour toucher aussi les monstres insensibles au désarmement ;
  - Cri de défi tire les monstres jusque sur le guerrier, puis les provoque 6 s ;
  - les dégâts du Bond héroïque partent dès le saut et arrivent avec un léger délai.

  **Premier essai en jeu (31/10/2026)** : les icônes s'affichaient en carrés verts, sauf pendant le glisser-déposer. Le BLP produit par Pillow n'avait qu'un seul niveau d'image, alors que les icônes de Blizzard en ont 7 (de 64 à 1 pixel) et que les barres lisent un niveau réduit. `icones_retail.py` écrit désormais lui-même le fichier, avec ses 7 niveaux.

  **Journal de combat** (demande du 31/10/2026), `v3_journal.cpp`, pour vérifier que les chiffres sont cohérents :
  - un fichier par personnage et par connexion : `journaux\combat\<nom>_<date>.log` ;
  - à chaque combat, la fiche du joueur : puissance, vie, armure, force, endurance, puissance d'attaque, dégâts et vitesse de l'arme, critique, Rempart ;
  - puis la fiche de chaque monstre : puissance d'origine, vie, armure, dégâts et vitesse, et le malus du joueur contre lui ;
  - chaque coup, dans les deux sens : technique, dégâts, part retirée par l'armure, part absorbée, résistée ou bloquée, critique, vie restante de la cible et Rempart du joueur. S'y ajoutent les soins et les morts ;
  - un bilan à la sortie du combat : durée, dégâts infligés et subis par seconde, détail par technique ;
  - une nouvelle accroche du moteur, `OnDamageLog`, appelée pour la mêlée, les sorts et les dégâts périodiques, a été ajoutée à `patches\azerothcore-v3-combat.patch` ;
  - réglage `SolAzeroth.V3.JournalCombat` (1 par défaut).

  **Deuxième essai (31/10/2026, journal d'Ezafz contre deux sangliers tachetés)** :
  - **icônes toujours vertes** : aucune icône de Blizzard n'est à palette ; toutes sont en DXT. `icones_retail.py` écrit maintenant du DXT1 sans transparence, avec 7 niveaux, exactement comme `Ability_Warrior_ShieldBash` ;
  - **armure des monstres au niveau 80** : le sanglier avait 9729 d'armure. Le moteur génère l'armure de base après le choix du niveau, donc au niveau 80. Tous les coups physiques du joueur tombaient au plancher de 25 % (3 dégâts pour un coup blanc de 10 à 12). Le « sanglier en une quinzaine de coups » de F2 venait de cette erreur, pas de l'armure ÷ 20. Correction : nouvelle accroche du moteur `OnCreatureBaseArmor`, et `v3_niveau.cpp` reprend l'armure du niveau d'origine (8 à 20 pour ce sanglier) ;
  - **blocage des techniques** : le sanglier bloquait encore des techniques (« bloqué 6 »). `Unit::isSpellBlocked` passe maintenant par l'accroche « tout coup porte » de F2 ;
  - **journal** : le bilan comptait 0 monstre tué, car la sortie de combat arrive avant l'accroche de mort. La mort est maintenant comptée au coup qui tue ;
  - **chiffres justes par ailleurs** : arme 10-12 → coup blanc d'environ 10 avant armure ; Frappe du bouclier (200 %) environ 21 ; Coup de tonnerre (100 %) environ 10 ; le Rempart se remplit et absorbe comme prévu ;
  - **à calibrer en F5** : le sanglier (coups de 2 toutes les 2 s) n'inflige presque rien, 2 à 3 points par combat sur 70 de vie. Les dégâts des monstres à niveau fixe restent la question 7.

  **Troisième essai (31/10/2026, 9 combats contre des sangliers)** :
  - les chiffres sont cohérents : armure 8 à 20, coups blancs de 8 à 12, Frappe du bouclier de 18 à 22, Coup de tonnerre de 8 à 12, critique à environ ×2, plus aucun blocage ;
  - en revanche, le joueur ne risque rien. Un sanglier meurt en 1 à 6 s et coûte 0 à 2 points de vie sur 70. Le Rempart ne dépasse pas 3 points ;
  - cela ne vient pas d'un bug : c'est le rapport de forces d'origine de Blizzard, qu'un niveau caché ne change pas.

  **Premier calibrage (accepté par l'utilisateur le 31/10/2026)**, à ajuster avec le journal :
  - `SolAzeroth.V3.MonstresVie` = 2 : la vie des monstres est multipliée à leur apparition (`v3_niveau.cpp`) ;
  - `SolAzeroth.V3.MonstresDegats` = 2,5 : les dégâts des monstres contre le joueur et ses familiers sont multipliés avant l'armure, pour la mêlée, les sorts et les dégâts périodiques (`v3_combat.cpp`) ;
  - cible : un monstre de sa puissance tient de 10 à 12 s et coûte environ un quart de la vie sans se défendre ;
  - l'en-tête du journal rappelle les deux multiplicateurs ;
  - les fiches des monstres donnent la vie multipliée, mais les coups avant multiplication.

  **Deuxième réglage (journal Ezafz du 31/10/2026 à 02h29, accepté par l'utilisateur)** :
  - le multiplicateur s'applique bien. Mais un coup brut de 1 × 2,5 était tronqué à 2, puis l'armure et le Rempart l'effaçaient : les sangliers de puissance 1 restaient inoffensifs ;
  - un sanglier de puissance 2 tient 21,8 s et coûte la moitié de la vie, mais sans technique pendant les 15 premières secondes. Avec le kit, on estime 12 à 14 s, proche de la cible ;
  - les dégâts des monstres et les apports du Rempart sont désormais arrondis au plus proche ;
  - Rempart renforcé : `Rempart.Part` passe de 25 à 40 %, et `Rempart.FrappeBouclier` de 5 à 8 % de la vie maximale.

  **Troisième réglage (journal Ezafz de 02h37, accepté par l'utilisateur)** :
  - les durées sont dans la cible quand le kit sert dès le début : 11,3 s contre la puissance 2 ;
  - mais le joueur ne perd que 0 à 10 points de vie sur 70 : le Rempart efface environ 60 % des dégâts, car les dégâts absorbés le rechargent aussi ;
  - `MonstresDegats` passe de 2,5 à 4. Attendu : environ 15 points de vie perdus contre un monstre de sa puissance.

### F4. Interface v3 dans les fichiers du jeu
- **Nos propres fichiers sont ajoutés à FrameXML.** Le test du 30/10 a montré que ce code garde les droits de Blizzard en combat.
- **Les cadres de Blizzard inutiles sont cachés** : barres d'action, cadres du joueur et de la cible, mana, expérience…
- **L'écran de combat de la maquette Synthèse est construit** : arcs de vie et de Rempart, deux barres de 4, grand cadre de cible, suivi de zone.

**Décisions de l'utilisateur (31/10/2026)** :
- **Touches** : aucune n'est imposée. Les deux barres reprennent les emplacements 1 à 8 de la barre d'action 1 de Blizzard. Chaque joueur les attribue dans le menu Raccourcis, et chaque bouton affiche la touche choisie.
- **Suivi de zone réduit** en attendant F5 : nom de la zone, puissance conseillée et sous-zone. Le pourcentage et les reliques arriveront avec F5.
- **Police Inter**, téléchargée depuis le dépôt officiel `rsms/inter` (v4.1, licence OFL). Le dépôt ne fournit plus de TTF statiques en dehors d'une archive de 33 Mo. On prend donc la police variable (880 Ko), dont l'outil tire quatre graisses statiques : Light, Regular, SemiBold et Bold.

**Construction (31/10/2026)** :
- **Code** : `interface-v3\FrameXML\SolUI_*.lua`, ajouté au `FrameXML.toc` du client par `outils\interface_v3.py`, puis mis dans le patch par `construire_patch.py`. Ce code garde donc les droits de Blizzard en combat.
  - `Base` : polices, couleurs, racine à l'échelle de la maquette (900 unités de haut) et messages du serveur.
  - `Cacher` : cadres de Blizzard remplacés, rangés sous un cadre caché.
  - `Perso` : arcs, libellés, puissance et pastilles.
  - `Techniques` : deux barres et losange du passif.
  - `Cible` : cadre de la cible.
  - `Zone` : suivi de zone, mini-carte et bouton Menu.
- **Textures** (TGA 32 bits) tracées par l'outil : arcs, anneau, rond, bouton arrondi, halo, losange et bouclier.
- **Barres** : chaque bouton clique le bouton de Blizzard correspondant (`ActionButton1` à `8`, caché mais chargé), avec l'action « click » des boutons sécurisés.
  - On voit : la recharge sous un voile avec les secondes (le temps global ne voile pas), un point quand l'effet est actif, l'icône rougie hors de portée et la touche.
  - On peut glisser-déposer les techniques comme sur les barres de Blizzard.
  - La Riposte du rempart est mise en avant (halo ambre qui respire) quand le Rempart dépasse la moitié de son plafond.
- **Cible** : étiquette ÉLITE, RARE ou BOSS, nom, puissance du monstre et malus du joueur contre lui (en rouge), vie en chiffres et en %, barre graduée aux quarts.
  - L'incantation s'affiche en grand, avec une bordure grise si elle ne peut pas être interrompue.
  - Jusqu'à 3 débuffs, avec cumuls, durée et temps restant.
- **Menu** : il remplace le micro-menu. Il ouvre le personnage, les sacs, les techniques, les sorts, les quêtes, la carte, les hauts faits, le social, /sol et le menu du jeu.
- **Serveur** :
  - puissance envoyée avec une décimale ;
  - message `SOLZONE` « ZONE;basse;haute » au changement de zone et toutes les 10 s ;
  - Rempart renvoyé au moins toutes les 2 s, et puissance toutes les 10 s, pour qu'un /reload retrouve tout.
- **Puissance conseillée d'une zone** : du 5e au 90e centile des niveaux d'origine de ses monstres ordinaires (sans PNJ de service, élites ni bestioles), calculée au démarrage.
  - Exemples : Durotar 1–10, les Tarides 11–22.
  - Une zone trop disparate (plus de 25 d'écart, comme une capitale) n'en a pas.
- L'ancienne jauge du Rempart de l'addon SolAzerothKit est retirée.
- **Pour revenir à l'interface de Blizzard** : supprimer `patch-client\fichiers\Interface\FrameXML`, puis relancer `construire_patch.py`.

**Premier essai en jeu (31/10/2026)** :
- Le client accepte le `FrameXML.toc` modifié, et l'interface s'affiche.
- **Corrigé** :
  - le nom de la cible manquait : il était ancré sur l'étiquette ÉLITE, cachée et sans largeur ;
  - les boutons des addons restaient autour de la mini-carte : ils sont maintenant rangés.
- **Demande de l'utilisateur** : couper tous les messages d'erreur rouges (« pas encore disponible », « hors de portée »…). Les messages jaunes restent.
- **Demande de l'utilisateur : une interface paramétrable**, dont le contenu doit donc s'adapter.
  - La position, l'échelle et la largeur de chaque bloc sont réunies dans `S.DISPOSITION` (`SolUI_Base.lua`) et appliquées par `S.Placer`. La future page de réglages n'aura qu'à les changer.
  - Le cadre de la cible suit sa largeur : barre, graduations et incantation s'étirent, et le nombre de débuffs affichés (6 au plus) est celui qui tient.
- Les barres verte et rouge vues sous le personnage sont des WeakAuras de la v2 propres au joueur, et non l'interface v3.

**Réglages de l'interface (31/10/2026)** :
- **Mode édition** (`SolUI_Reglages.lua`) : chaque bloc se couvre d'un calque ambre.
  - On le déplace à la souris : il garde son point d'ancrage, et seul son décalage change.
  - La molette change son échelle, de 60 à 160 %. Maj + molette change la largeur de la cible, de 420 à 1100.
  - Un bandeau rappelle les gestes. Le mode se ferme avec Terminer, Échap ou l'entrée en combat.
  - Sans cible, le cadre de la cible montre un aperçu vide pour qu'on puisse le placer.
- **Page /sol > Réglages > Interface** :
  - bouton du mode édition et bouton « Tout réinitialiser » ;
  - un curseur d'échelle et un bouton « Réinitialiser » par bloc ;
  - un curseur pour la largeur de la cible.
- **Sauvegarde** : la disposition est gardée dans `SolAzerothDB.interface` (addon SolAzeroth, commune au compte) et reprise au chargement. Les valeurs sont bornées et les champs inconnus ignorés.

### F5. Premier essai jouable à Durotar
- Les monstres de la Vallée des épreuves et de Durotar sont remis à l'échelle, et le Gouffre de Ragefeu s'ouvre à 60 %, même si le contenu de la zone est encore incomplet.
- **Vérification** : l'utilisateur joue son guerrier tank et dit si c'est exigeant et amusant. Les chiffres se calibrent à partir de là.

**Décisions de l'utilisateur (31/10/2026)** :
- **Les quêtes de Durotar sont réécrites.**
  - L'histoire est cohérente et ne demande que des choses à faire dans Durotar, sans voyager ailleurs. Les quêtes d'origine sont retirées.
  - Le fil de l'histoire mène à nettoyer le Gouffre de Ragefeu.
  - Une équipe d'agents écrit puis relit l'histoire, et l'utilisateur la valide avant qu'on la construise.
- **Pourcentage de la zone** :
  - **les quêtes de l'histoire rapportent 50 %** ;
  - **les activités secondaires, l'autre moitié** : tout aussi conséquentes, et faisables en parallèle selon l'envie du joueur.
  - Pour ce premier essai, les activités secondaires comptées sont les lieux à nettoyer (une dizaine, proposés par Claude) et l'exploration des sous-zones. Primes, reliques et défis viendront ensuite.
- **Le Gouffre de Ragefeu est bloqué sous 60 %** : le joueur est renvoyé dehors, avec un message qui donne son pourcentage.
- **Les quêtes passent elles aussi par notre interface** : un journal et un suivi à nous, à la place de ceux de Blizzard. Les quêtes sont visibles sur la carte et la mini-carte, ainsi que la zone où remplir chaque objectif.
- **Mort** : quand le joueur libère son esprit, il revient à sa pierre de foyer, vivant, sans fantôme, sans usure et sans course au cadavre.

**Découpage de F5 (proposé par Claude)** :
- **F5a** : mort v3.
- **F5b** : histoire de Durotar, écrite et relue par l'équipe d'agents, puis validée par l'utilisateur.
- **F5c** : construction des quêtes dans la base, et retrait des quêtes d'origine.
- **F5d** : interface des quêtes (journal, suivi, carte et mini-carte).
- **F5e** : pourcentage de zone, lieux à nettoyer et exploration.
  - **Construit le 31/10/2026, pas encore vérifié en jeu** : `outils\zone_durotar.py` lit les parts dans le document de Durotar et écrit la migration 074 : 26 quêtes (50 %), 24 sous-zones (6 %) et 10 lieux (19 %). Le serveur (`v3_zone.cpp`) compte les quêtes rendues, les sous-zones découvertes et les monstres de chaque lieu tués dans la zone, y compris pour les quêtes.
  - **Interface** : le suivi de zone affiche le pourcentage et une jauge. Au survol, il détaille histoire, exploration et annexes, et donne l'avancée de chaque lieu.
  - **Reste à faire** : les chefs renforcés (en attendant, le chef d'origine compte pour 1 monstre du lieu), puis les primes, contrats, défis et reliques (25 %). Les annexes du document de Durotar restent à valider par l'utilisateur.
- **F5f** : accès au Gouffre de Ragefeu à 60 %.

**Validation de l'histoire de Durotar (31/10/2026)** : l'utilisateur valide le brouillon relu (`Durotar — Histoire et quêtes (brouillon).md`) et toutes les recommandations du relecteur, sauf la répartition des activités secondaires :
- **exploration 6 %**, comme recommandé ;
- **les 44 % restants vont à tout ce qui est annexe** : primes, contrats, défis, objets à collectionner cachés, lieux à nettoyer… Ces activités sont **plus difficiles que les quêtes de la zone**.

**Nouvelles décisions de l'utilisateur (31/10/2026)** :
- **Butin des monstres et des chefs** : on retire leurs tables de butin. On ne garde que les **composants** : tissu, gemmes, matériaux en général.
- **Plus de dépeçage** : le cuir tombe directement sur les monstres qui se dépeçaient.
- **Éclats cadavériques** : chaque monstre de la zone de départ en donne **de 0 à 3**. Ils servent à **monter le rang d'un objet, jusqu'au rang 5**. À équilibrer ensemble :
  - la rareté de l'éclat ;
  - la quantité qui grandit avec la puissance des zones ;
  - la quantité nécessaire pour monter un objet, qui suit la puissance de l'objet ;
  - et le fait qu'en avançant, il y a de plus en plus d'objets à monter.
- **Bouton de potion** dans le cadre du personnage : une **potion unique**, améliorable sur trois axes (soin rendu, temps de recharge, nombre de charges).
- **Bouton de camp** dans le cadre du personnage : il pose un feu de camp. Assis près du feu, on régénère sa vie. Au bout de **60 secondes assis**, on reçoit un bonus. Le camp s'améliore comme la potion, sur la régénération rendue, ainsi que sur le nombre et la qualité des bonus, indépendamment des consommables.
- **Exigence** : un peu exigeant dans la zone de départ, puis **de plus en plus, de façon exponentielle**, dans les zones suivantes. On peut ajouter des sorts et des bonus aux monstres, aux rares et aux chefs.
  - Hors de Durotar, on doit aborder les combats prudemment, avoir des potions de soin et prendre en compte les consommables qui augmentent les caractéristiques pendant un temps. Il faut aussi monter le rang de ses objets.
- **Le but** : on ne doit pas pouvoir rouler sur le jeu.

**Précisions de l'utilisateur (31/10/2026, suite)** :
- **L'équipement vient des quêtes et des annexes**, un peu comme dans le jeu d'origine. Les emplacements s'ouvrent progressivement : pas d'épaules, de tête, de bijou ni de bague dans la zone de départ ; ils viennent un peu plus tard.
- **L'or, comme dans Genshin Impact** :
  - il sert à acheter des consommables et des objets à collectionner, mais cher, en contrepartie de ne pas avoir à les récolter soi-même ;
  - il contribue à l'amélioration de l'équipement et à l'achat d'équipement ;
  - il sert aussi à acheter les recettes des métiers.
- **Améliorer la potion et le camp : une liste de courses.**
  - Le joueur doit pouvoir les améliorer **deux fois par zone**. La première amélioration les rend indispensables pour les quêtes et les annexes de la zone ; la deuxième apporte du confort.
  - Le coût reste proportionnel à la zone, toujours dans l'idée de difficulté. La liste demande de la monnaie, de l'or, des éclats cadavériques, des plantes, des minerais, des étoffes… **Être créatif** : l'investissement doit être réel et la récompense appréciable.
- **Rangs d'objet** :
  - les rangs coûtent des éclats, et chaque rang ajoute environ **10 % aux caractéristiques**, soit +50 % au rang 5 ;
  - **les rangs 4 et 5 demandent en plus des composants rares**, de l'or et des éclats. Il faut que ce soit dur.
- **Joaillerie réinventée** : on efface les recettes d'origine, l'interface et les icônes, et on crée nos propres composants rares, avec des icônes retail. Par exemple, avec 5 malachites ramassées sur les monstres, ou obtenues en prospectant du minerai comme le joaillier d'origine, on fabrique un composant rare.
- **Un jeu dur, mais permissif pour qui veut récolter** : une fois **60 % d'une zone** atteints, le joueur choisit dans une zone de repos un mode pour cette zone :
  - **Mode normal (rehaussé)** : un monstre plus faible que le joueur monte à sa puissance, et donne des éclats en proportion ;
  - **Mode difficile** : encore plus d'éclats ; les monstres de la zone sont plus dangereux, avec des techniques en plus ;
  - **Mode cauchemar**, actif seulement hors des zones de repos :
    - des techniques encore améliorées, et des bonus pour les monstres et les rares ;
    - des **événements aléatoires**, par exemple une pluie de feu ou un rare qui apparaît ;
    - un **écran légèrement rougeâtre**.
- **L'âme, à la manière de Dofus** (remet en cause la mort sans perte de F5a) :
  - à chaque mort, le personnage perd une partie de son âme ;
  - plus il est puissant, plus la mort coûte d'âme ; à bas niveau, la perte doit rester presque négligeable ;
  - pour régénérer l'âme, il faut une quantité non négligeable d'éclats, de plus en plus grande avec la puissance du personnage ;
  - **si l'âme tombe à zéro, le personnage devient inutilisable, donc à supprimer.**
  - Réponses de l'utilisateur aux questions de Claude :
    - **chaque mort coûte de l'âme**, très peu au début ; le retour à la pierre de foyer reste, sans autre perte ;
    - **à zéro, le personnage est verrouillé** : le serveur refuse de le connecter (« Âme éteinte ») et le joueur le supprime lui-même. Une commande MJ peut le déverrouiller en cas de mort due à un bogue ;
    - **zones de repos = auberges et villes**, celles où le jeu donne déjà le repos. Le mode s'y choisit.

**F5c construite (31/10/2026)**, pas encore vérifiée en jeu :
- `outils\quetes_durotar.py` lit les textes du document de l'histoire et écrit la migration 063 : quêtes 910001 à 910030, 19 récompenses d'équipement 910101 à 910119 (avec l'Item.dbc du patch client), Ruga Brise-cendre au Rocher du crâne, et la Sacoche du Totem-sinistre près de Maur ;
- 102 quêtes d'origine de Durotar, de la Vallée et du Gouffre sont retirées par la table `disables` ; les quêtes de fête restent ;
- le niveau des quêtes suit celui du joueur (QuestLevel -1), pour qu'elles ne s'affichent pas en gris ;
- les zones d'objectif sont dans `quest_poi`. Celles du Gouffre s'affichent à la faille, car le Gouffre n'a pas de carte ;
- les récompenses du point 24 ont été corrigées comme recommandé.

**Fêtes retirées (31/10/2026, décision de l'utilisateur)** : migration 064. 42 événements de fête ou de saison ne démarrent plus : fêtes du calendrier, foire de Sombrelune, Nouvel an, bière du mois, concours de pêche et poissons de saison. 743 quêtes de fête sont désactivées. Restent les événements qui ne sont pas des fêtes, comme les appels aux armes des champs de bataille ou les cycles de jour et de nuit.

**F5d construite (31/10/2026)**, pas encore vérifiée en jeu : `SolUI_Quetes.lua` (et `SolUI_Cartes.lua`, généré depuis WorldMapArea.dbc).
- **Suivi** sous la zone, déplaçable et réglable comme les autres blocs : les quêtes suivies et leurs objectifs. Clic : ouvre le journal ; clic droit : ne plus suivre. Une quête acceptée est suivie d'office.
- **Journal** (touche du journal, menu Quêtes) : la liste à gauche, la quête à droite (objectifs, récit, récompenses), avec Suivre, Carte et Abandonner. Il remplace celui de Blizzard, qui reste chargé mais ouvre le nôtre.
- **Mini-carte** : la zone d'objectif de chaque quête suivie, ou un point vert sur le PNJ à qui la rendre. Au bord de la mini-carte si c'est trop loin.
- **Carte du monde** : celle de Blizzard, avec les objectifs de quête toujours affichés.
- Les fenêtres d'acceptation et de rendu des quêtes restent celles de Blizzard pour l'instant.

**Correctifs après le premier essai (31/10/2026)**, pas encore vérifiés en jeu :
- **Dialogue** (`SolUI_Dialogue.lua`) : notre fenêtre remplace celles de Blizzard pour parler aux PNJ et pour accepter, suivre et rendre les quêtes (choix de la récompense compris).
- **Raccourcis** : les touches de la barre d'action 1 visent nos boutons. Avant, en posture, elles passaient à la barre de posture du guerrier : Alt+A lançait le sort racial de l'orc.
- **Mini-carte** : sa taille et celle des repères de quête se règlent dans /sol, page Réglages > Interface. Les repères sont relus toutes les 3 s ; `/solpoi` affiche ce que le jeu donne pour chaque quête suivie. Le suivi des quêtes se range sous la zone et ne recouvre plus le bouton Menu.
- **Nouveau personnage** : il commence sans arme. Le choix de la spécialisation revient après la cinématique d'introduction, et ce choix vide la première barre pour la remplir des techniques.
- **Plus de guildes ni de banques** (migrations 065 et 066) : banquiers, coffres de guilde, créateurs de guilde et dessinateurs de tabards sont retirés. Les deux « Coffres » de la V2 sont effacés. Seul le niveau d'aventurier se partage entre les personnages.
- **Hauts faits natifs purgés** : leurs 7 655 critères sont désactivés et leur progression est effacée. Le client ne garde que les hauts faits Sol'Azeroth.
- **Durotar** : 17 PNJ d'ambiance sont cachés hors des villages, pour l'instant (`outils/sans_guildes.py`). La migration descendante les remet.
- **Reste à faire** : identifier le motif « Cabestan » sous la mini-carte. Les icônes propres à chaque collectible attendent notre système de collectibles.

**Deuxième série de correctifs (31/10/2026)**, pas encore vérifiés en jeu :
- **Discussion** (`SolUI_Discussion.lua`) : notre fenêtre remplace celles de Blizzard, sans onglets.
  - Le fond n'apparaît que sous la souris ou pendant la saisie.
  - Le bouton en haut à droite choisit ce qui s'affiche : discussion, paroles des PNJ, butin et argent, progression, sorts appris ou oubliés, système.
  - Le bloc se déplace en mode édition, comme les autres.
- **Objets de quête** (matraque…) : un bouton à gauche de la quête dans le suivi, comme dans le suivi de Blizzard.
- **Argent** : les sommes s'affichent avec les icônes des pièces.
- **Dialogue** : Accepter est à gauche et Refuser à droite.
- **Nouveau guerrier** : il naît sans ses anciens sorts ni barre d'action, donc sans messages « Vous avez oublié… ». Les hauts faits du compte lui sont inscrits sans annonce.
- **Choix de la spécialisation tank** : il équipe l'Épée courte usée et le Vieux bouclier en bois si les mains sont vides.
- `/soltexte <mot>` dit quel cadre affiche un texte (pour trouver « Cabestan »).
- **À venir** : une refonte graphique du dialogue et du journal, sur maquette à valider.

**Troisième série (31/10/2026)**, pas encore vérifiée en jeu :
- **Discussion** : notre fenêtre ne se chargeait pas (une fonction absente de ce client). C'est corrigé. Pendant 15 s après la connexion, les messages de sorts, recettes et métiers appris ou oubliés sont tus.
- **Potion et feu de camp, rang de départ** (avance sur F7). Deux boutons à droite des techniques, avec des icônes de retail. Côté serveur : `v3_bivouac.cpp`, migration 067.
  - **Potion de soins** : rend 30 % de la vie. 3 charges, 30 s de recharge, hors du temps global. Les charges reviennent toutes en zone de repos, et une toutes les 15 s assis près de son feu.
  - **Feu de camp** : 2 minutes, 2 minutes de recharge, hors combat. Assis à moins de 5 m de son propre feu : 6 % de la vie toutes les 2 s. Au bout de 60 s : Repos au coin du feu, vie maximale +5 % pendant 10 minutes.
- **Mini-carte** : le bouton d'enregistrement vidéo est rangé. L'élément de bordure qui affiche le village le plus proche reste à identifier (`/solminicarte`, `/soltexte`).

**Quatrième série (31/10/2026)**, après l'essai du feu de camp ; pas encore vérifiée en jeu :
- **Techniques** : aucun temps de recharge global, chacune n'a plus que sa propre recharge.
- **Potion de soins** : 1 charge au départ. La recharge de 30 s reste, pour quand il y aura plusieurs charges.
- **Feu de camp** :
  - le personnage s'assoit dès que le feu est posé ;
  - se lever, entrer en combat ou mourir éteint le feu ; la recharge de 2 minutes reste ;
  - le Feu douillet de Blizzard (+4 esprit) est retiré.
- **Repos au coin du feu** : 30 minutes, à améliorer plus tard. Il vient au bout de 60 s assis, et rend alors toutes les potions (avant, une charge revenait toutes les 15 s).
- **Butin** (`outils/butin_v3.py`, migration 068). Retirés des tables de butin (monstres, décor, réserves, contenants, vol à la tire, pêche, dépeçage) et des marchands :
  - les objets gris ;
  - les consommables qui rendent vie ou mana.
  
  Les objets liés à une quête restent, mais le sort de tout consommable de régénération est désactivé pour les joueurs. Les récompenses de quête ne sont pas touchées.
- **Maquettes à valider** (toile de maquettes, rangée « Fenêtres v3 ») :
  - **7 · Techniques et raccourcis** : l'onglet Raccourcis passe en premier (demande de l'utilisateur).
    - Les 10 boutons sont disposés comme à l'écran. On clique un bouton, puis on appuie sur la touche voulue.
    - Maj, Ctrl et Alt se combinent avec la touche. Échap annule, Suppr retire le raccourci.
    - Une touche déjà prise est retirée de son ancien bouton, et la fenêtre le signale.
    - À droite, la liste de tous les raccourcis, avec ceux des fenêtres.
    - Onglets suivants : techniques équipées, puis feu de camp et potion.
  - **8 · Collection** : l'inventaire exhaustif du § 2.8.
    - Catégories à gauche, avec une recherche et un filtre Tout, Possédés ou Manquants.
    - Un objet possédé est en couleur, avec son nombre ; les autres sont grisés.
    - Le détail de l'objet choisi est à droite.
- **Construites le 31/10/2026** (pas encore vérifiées en jeu) ; elles s'ouvrent depuis le bouton Menu, ou par une touche réglée dans la fenêtre :
  - `SolUI_Raccourcis.lua` : les touches sont celles du jeu, enregistrées à la fermeture. L'onglet Techniques équipées envoie `.kit equiper`. L'onglet Feu de camp et potion décrit le rang de départ.
  - `SolUI_Collection.lua` et le catalogue `SolUI_Catalogue.lua` (`outils/collection_v3.py`) : 609 matériaux et gemmes qu'on peut obtenir, en 9 catégories. En attendant l'inventaire sans limite côté serveur, le nombre possédé est celui des sacs et de la banque.
  - **Inventaire sans limite** (`v3_collection.cpp`, migration 069) : les 609 objets à collectionner ne passent plus par le sac.
    - **Au butin** : juste avant l'ouverture de la fenêtre de butin, ils en sont retirés et rangés en base, sans limite. Un sac plein ne bloque plus la collecte.
    - **Autres arrivées** (quête, marchand, courrier) : l'objet est rangé juste après être entré dans le sac.
    - **Quête en cours** : un objet qu'elle demande reste dans le sac.
    - **Retrait** : la fenêtre Collection remet 1 ou 20 objets dans le sac (`.collection retirer`).
    - Collection par personnage, pour l'instant.
  - **Corrections du même jour** :
    - **Sorts des monstres** : ils se calculaient sur le niveau affiché, 80 (Boule de feu du Familier vil à 1 100). Ils sont ramenés à la puissance du monstre ; c'est le cas aussi des dégâts sur la durée et des soins.
    - **Feu de camp** : compte à rebours au-dessus des techniques avant le Repos et les potions.
    - **Raccourcis** : boutons de la souris (milieu, 4, 5) et molette.
    - **Quêtes suivies** : gardées par personnage et remises à la connexion.
  - **Cinquième série (31/10/2026)**, après l'essai dans la vallée des Épreuves ; pas encore vérifiée en jeu :
    - **Journal de combat** : la Boule de feu du Familier vil frappe pour environ 24 avant le Rempart (6 × 4). Elle passe outre l'armure. Elle partait toutes les 5 à 7 s, alors qu'un combat dure deux fois plus longtemps qu'à l'origine, puisque la vie des monstres est doublée. Un diablotin tient 44 s contre le personnage Test, de puissance 1,7 contre 4, et deux diablotins le tuent.
    - **Sorts des monstres normaux** (migration 070, annulée et retirée le jour même) : leurs sorts répétés en combat partaient deux fois moins souvent. Le réglage `MonstresDegatsSorts` (septième série) la remplace.
    - **PNJ d'ambiance dans la grotte de la Lame ardente** (migration 071) : ils suivaient les trajets de patrouille des Familiers vils, dont la faction 7 avait été prise pour une faction non hostile. 32 trajets de monstres hostiles ont été retirés des routes d'ambiance ; il en reste 462.
    - **Pierre de foyer** : troisième bouton, à droite du feu de camp. Sa touche se règle dans la fenêtre des raccourcis, sous le nom « PF ».
    - **Repos au coin du feu** : hors combat, il rend 1 % de la vie maximale par seconde. Ce taux s'améliorera par rang avec F7, comme le bonus de vie.
    - **Touches de souris abrégées** sur les boutons : S4 pour le bouton 4, MH et MB pour la molette.
    - **Collection** : la grille passe à 4 colonnes plus larges. Les tuiles affichent « Manquant ». La catégorie s'appelle désormais « Métaux et pierres », et la croix de fermeture ne recouvre plus le filtre « Manquants ».
    - **Discussion** : la zone de saisie s'appelle `ChatFrame1EditBox` en 3.3.5. Le nom `ChatFrameEditBox` provoquait une erreur au chargement (FrameXML.log).
  - **Sixième série (31/10/2026)**, d'après 14 combats dans le Convent de la Lame ardente ; pas encore vérifiée en jeu :
    - **Journal** :
      - aucune mort ;
      - la Boule de feu part bien toutes les 10 s environ ;
      - le Familier vil coûte 7 à 51 points de vie, le Traqueur gangrené 0 à 8 ;
      - le joueur a 240 d'armure, soit -12 par coup : la mêlée des monstres tombe au plancher de 25 %, puis le Rempart l'absorbe ;
      - les combats durent 17 à 48 s, contre 10 à 12 s visés, car le personnage n'inflige que 4 à 8 dégâts par seconde avec une arme de 7-9 ;
      - ces deux points relèvent du calibrage final.
    - **Régénération passive** (demande de l'utilisateur) : 2 % de la vie maximale par seconde hors combat (`SolAzeroth.V3.RegenVie` = 2, désormais en % par seconde ; c'était 3 % toutes les 2 s). Le Repos au coin du feu ajoute 1 % par seconde.
    - **Objet de départ d'une quête** (Matraque du contremaître) : retiré du sac quand la quête est rendue, s'il est lié à la quête et ne sert à aucune autre quête en cours (`v3_collection.cpp`). Le moteur le laissait.
    - **Collection, catégorie Cuisine** : la viande, et les consommables qui servent de composant à une recette de cuisine (Eau de source fraîche, lait, fruits…). Ils sont lus dans Spell.dbc et SkillLineAbility.dbc. La Collection passe à 742 objets en 10 catégories.
    - **Yarrog Plaie-d'ombre** (migration 072) : la migration 065 l'avait caché comme PNJ d'ambiance de Durotar, car sa faction 7 était prise pour non hostile. `sans_guildes.py` écarte désormais la faction 7 et les monstres qui portent un objet de quête.
    - **Sarkoth** : la quête « Sarkoth » (910006) est donnée par Hana'zua, couchée sur la colline au nord-ouest de la vallée, après « Les crocs de la Vallée ».
  - **Septième série (31/10/2026, accord de l'utilisateur)** :
    - **Journal contre Yarrog Plaie-d'ombre** (puissance 5) : mort du joueur en 12,4 s, pour 35 dégâts infligés sur 196.
      - Sa mêlée ne passait pas l'armure.
      - Corruption touchait pour 40 bruts par tick et Immolation pour 40. Ces sorts passent outre l'armure et prenaient le même ×4 que la mêlée.
      - Côté joueur : son armure de 109 retirait 4 à 5 points à chaque coup d'une arme 7-9.
    - **Nouveau réglage `SolAzeroth.V3.MonstresDegatsSorts` = 2** (`v3_combat.cpp`) : il s'applique aux sorts magiques et aux dégâts sur la durée des monstres, saignements compris. La mêlée et les techniques physiques gardent `MonstresDegats` = 4, car l'armure les réduit.
    - **Migration 070 annulée et retirée.** Le ×2 à la cadence d'origine donne aux Familiers vils la même pression que le ×4 à demi-cadence de l'essai précédent, que l'utilisateur jugeait correct.
    - L'en-tête du journal de combat indique les deux multiplicateurs.
    - **Reste au calibrage final** : l'armure fixe des monstres contre les armes faibles du début de jeu.
  - **Huitième série (31/10/2026)**, après plusieurs essais contre Yarrog :
    - **Retour de l'utilisateur** :
      - Yarrog a été battu au 2e ou 3e essai, mais seulement en jouant autour d'un pilier pour éviter Immolation, et la dernière fois à un coup blanc de la mort ;
      - les ticks de Corruption ne sont pas négligeables ;
      - jouer avec les murs n'est pas instinctif ;
      - Sarkoth, qui ne fait que de la mêlée, a été facile ;
      - réduire l'armure n'est pas la solution.
    - **Dégâts sur la durée des monstres** : nouveau réglage `SolAzeroth.V3.MonstresDegatsDuree` = 1,5 ; les sorts directs restent à ×2.
    - **Arbre du camp** (proposition de l'utilisateur) : les améliorations du feu de camp prennent la forme d'un arbre de talents. **Premier nœud, obligatoire** : « Flamme du guerrier », 15 Marques (environ 20 gagnées dans la vallée). Le Repos au coin du feu donne alors aussi +10 % de dégâts infligés.
      - Le bonus vient avec le Repos, pas en permanent : on a une raison de faire un feu avant un chef. C'est le choix de l'utilisateur.
      - Mise en œuvre : sort 100032 (copie du Repos avec l'aura 79, +10 % toutes écoles), lancé à la place de 100031 quand `solazeroth_v3_bivouac.rang_feu` ≥ 1 ; achat par `.camp acheter` ; affichage dans l'onglet « Feu de camp et potion » de la fenêtre Techniques et raccourcis.
      - **La suite de l'arbre est à débattre**, ainsi que son lien avec la « liste de courses » de F7 (or, éclats, composants).
  - **Neuvième série (31/10/2026)**, après la fin des quêtes de la vallée ; pas encore vérifiée en jeu :
    - **Retour de l'utilisateur** : le message « Vous exécutez Cueillette sur Feuillargent » est inutile ; le cuivre n'a pas pu être miné ; la quête de Hana'zua (Sarkoth) serait passée inaperçue ; le dépeçage doit disparaître ; sur le cadre de cible, « -8 % de dégâts » chevauchait la vie.
    - **Tout se récolte, sans niveau** : à la connexion, herboristerie et minage passent à 450/450, avec les sorts de grand maître (50300, 50310). Le minage n'a plus besoin de pioche (migration 073, et le même Spell.dbc côté client). Les messages « Vous exécutez… » et de progression de métier ne s'affichent plus.
    - **Plus de dépeçage** (avance sur F6) : au démarrage, le serveur retire le butin de dépeçage des modèles de créature et le garde en mémoire. À la mort, le cuir et les peaux s'ajoutent au butin du corps, donc à la Collection.
    - **Quêtes à prendre sur la carte du monde** : le serveur (v3_carte.cpp) relit toutes les 3 s les quêtes que le personnage peut accepter sur son continent (niveau, quête précédente, classe, réputation…). Un « ! » marque chaque donneur ; le survol donne les titres et leur niveau.
    - **Cadre de cible** : la vie s'affiche dans la barre ; le pourcentage de dégâts garde sa place à droite.
  - **Dixième série (31/10/2026)**, pas encore vérifiée en jeu :
    - **Systèmes de la v2 retirés en v3** : les hauts faits du compte (avec leurs points de talent et leurs Marques) et les métiers partagés sur le compte ne sont plus chargés. Les métiers à 450 avaient débloqué quatre hauts faits de métier. Ils sont retirés du personnage Test, avec les 30 Marques qu'ils avaient données.
    - **Bonus des métiers retirés** : Robustesse du minage (+60 Endurance, d'où 713 points de vie) et Sang-de-vie de l'herboristerie. Le dépeçage est retiré, et Maître en anatomie avec lui.
    - **Puissance des quêtes** : un chiffre devant chaque quête, dans le suivi, le journal et sur la carte. Nos quêtes restent au niveau du joueur, car à leur niveau d'origine le client cacherait leur « ! ». Leur puissance vient donc de `SolUI_Puissances.lua`, généré par `quetes_durotar.py`.
    - **Infobulles** : celle d'un objet n'affiche plus les autres personnages qui le possèdent (addon des sacs). Un objet à collectionner n'affiche que son nom, coloré selon son type : vert pour les herbes, bleu pour les métaux et les pierres, orange pour les cuirs. Ces couleurs servent aussi dans la Collection.
  - **Apparence et logique** : l'apparence de ces fenêtres ne vit que dans le client. Elle se retouche sans toucher au serveur : il suffit de reconstruire le patch et de relancer le jeu. Dans les fichiers Lua, apparence et comportement sont encore mêlés.

**Suite proposée par Claude** (après F5c à F5f) :
- **F6, butin** : tables de butin réduites aux composants, éclats cadavériques, or (le cuir sans dépeçage est fait, neuvième série).
- **F7, potion et camp** : les deux boutons du cadre du personnage, et leurs listes de courses.
- **F8, rangs d'objet et joaillerie** : rangs 1 à 5, composants rares, et nos recettes de joaillerie.
- **F9, modes de zone** : normal rehaussé, difficile et cauchemar.
- **F10, âme** : perte à la mort, régénération avec les éclats, verrouillage à zéro.
- **Annexes de Durotar** (44 %) : écrites par l'équipe d'agents, à valider, puis construites avec F5e.

## 5. Questions pour les prochaines séries

1. **Réputation des donjons** : la liste des techniques actives et passives d'entrée, et les paliers d'emplacements.
2. **Rang d'aventurier** :
   - combien de paliers ;
   - ce qu'apporte chaque action ;
   - les difficultés ouvertes par palier.
3. **Puissance** : les chiffres par qualité et origine d'objet, et la courbe exacte du malus.
4. **Kit du guerrier tank** : relire et corriger le brouillon de la partie 3. Il reste aussi à fixer :
   - l'ordre de déblocage du panel ;
   - les deux autres spécialisations du guerrier.
5. **Durotar** : la liste concrète des quêtes gardées, des lieux à nettoyer, des primes et contrats, des reliques, des élites, du lieu de vagues et des épreuves contre la montre, avec leurs récompenses.
6. **Interface v3** : l'écran de combat est choisi. Il reste à concevoir les fenêtres (sac et inventaire de collection, panel de techniques, équipement et puissance, carte, réputation et rang d'aventurier), puis à dresser la liste des cadres de Blizzard à garder, refaire ou supprimer.
7. **Monstres** :
   - leurs dégâts et leur vie à niveau fixe ;
   - les techniques des monstres et des boss face à un joueur sans ressource.
8. **Remarques de l'utilisateur à revoir** une fois la v3 posée :
   - la mascotte ramasseuse avec son arbre (n°6) ;
   - l'objet de buffs groupés (n°7) ;
   - le bouton de téléportation en fin de donjon (n°9).

   Les bugs de la v2 (n°1 à 4, 8 et 12) ne valent la peine d'être corrigés que si l'on continue de jouer à la v2 en attendant.
