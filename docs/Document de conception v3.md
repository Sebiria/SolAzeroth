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
- **Zones de départ** (règle du 01/11/2026, demande de l'utilisateur) : chaque zone de départ a ses propres plantes et filons, de quoi débuter les métiers de récolte et d'artisanat sans en sortir. À reprendre pour toute nouvelle zone de départ. Vallée des Épreuves : 5 filons de cuivre et 5 plantes (Pacifique, Feuillargent, Terrestrine), migrations 086 et 094 réduites de moitié par la 098, repousse de 30 minutes (095).

### 2.5 Donjons
- **Façon Genshin Impact** : le premier passage a un accès gradué.
- **Le rang d'aventurier** est un rang de compte qui monte avec tout ce qu'on accomplit : quêtes, primes, contrats, zones nettoyées, donjons réussis. Ses paliers débloquent des difficultés supplémentaires, avec des récompenses à la hauteur. Il ne donne pas de puissance.
- **Une réputation globale des donjons et raids**, commune à toutes les instances, qui monte :
  - surtout en terminant un donjon ou un raid ;
  - un tout petit peu à chaque monstre tué, pour inciter à nettoyer le donjon entier.
- **Ce qu'apporte cette réputation** (série 4) : des techniques actives et passives à choisir à l'entrée de chaque donjon. Plus le rang de réputation est haut, plus il y a de choix et d'emplacements d'amélioration.

**Construit le 01/11/2026** (`v3_donjons.cpp`, `v3_passifs.cpp`, `outils\passifs_v3.py`, `outils\simulation_donjons.py`, migration 093 ; proposition validée : « Réputation des donjons — proposition.md »), pas encore vérifié en jeu. Pas d'actif bonus : que des passifs, tous ouverts, dans des emplacements qui s'ouvrent peu à peu (choix de l'utilisateur).
- **Difficultés 1 à 5** de chaque donjon (pas des raids), choisies à l'entrée (fenêtre « Difficulté du donjon » ou `.donjon <1-5>`), modifiables jusqu'au premier combat puis verrouillées jusqu'à la remise à zéro. Les difficultés 2 à 5 s'ouvrent aux paliers 12, 20, 30 et 38 du rang d'aventurier ; un nouveau donjon reprend la dernière difficulté choisie par le compte.
  - Monstres (boss compris) à la puissance de base du joueur + écart, vie et dégâts × facteur, éclats × facteur : 2 (+0, × 1,1, 1 technique, éclats × 1,5), 3 (+0, × 1,25, 2, × 2), 4 (+1, × 1,3, 2, × 2,5), 5 (+1, × 1,4, 3, × 3). Les chiffres de la proposition (+1 à +4, × 1,2 à × 1,8) laissaient la difficulté 2 à 0 % de victoires en simulation ; ceux-ci demandent environ 1, 3, 4 puis 5 rangs d'objet de plus (et des passifs) que la difficulté 1.
  - Techniques tirées pour le donjon parmi Enragé, Renforçant, Volcanique et **Explosif** (toutes les 12 s, une sphère à 6 m du joueur, 5 % de sa vie ; non détruite en 6 s, 15 % de la vie à 30 m). Fortifié et Tyrannique sont fondus dans le facteur.
  - Dernier boss : + 2 Marques par difficulté au-dessus de 1, 25 % de chances par difficulté au-dessus de 2 d'une pierre taillée ; + 100 points d'aventurier pour chaque nouvelle difficulté réussie.
- **Réputation des donjons**, au compte : 1 par monstre, 10 par boss, 100 au dernier boss, × la difficulté. 10 rangs (0, 100, 300, 600, 1 000, 1 600, 2 400, 3 400, 4 600, 6 000 points).
- **Passifs de donjon** (21, valent dans les instances) : 6 emplacements ouverts aux rangs 1, 2, 4, 6, 8 et 10 ; se changent hors combat, hors d'une instance ou dans un donjon avant le premier combat. Chaque passif de combat vaut à peu près « + 5 % de puissance » en simulation (Peau de braise − 8 % de dégâts subis, Soif de sang 6 % de vol de vie, Bourreau + 30 % sous 35 %, Cuirasse + 6 % d'armure, etc. : liste dans `outils\passifs_v3.py`).
- **Passifs du monde extérieur** (21, valent hors des instances), en arbre à trois branches sans prérequis (combat, survie, récolte et voyage) : 6 emplacements ouverts aux paliers 2, 5, 9, 15, 23 et 31 du rang d'aventurier, puis achetés en Marques (25, 50, 100, 175, 275, 400) ; se changent dans une zone de repos. Main experte devient « 20 % de chances d'un éclat cadavérique en récoltant » (le temps de récolte ne peut pas être changé par le serveur).
- **Interface** : icône de la barre « Passifs et réputation des donjons » (pages Donjon et Extérieur), commandes `.passif`, `.passif donjon|exterieur <emplacement> <passif|0>`, `.passif acheter`.
- **Corrigé en passant** : la liste des derniers boss n'était chargée que par la v2 (`menace.cpp`) ; en v3 elle était vide, si bien que les donjons terminés ne rapportaient rien au rang d'aventurier. `v3_donjons.cpp` la charge maintenant.
- **Récompense propre aux donjons** (01/11/2026, demande de l'utilisateur ; `v3_donjons.cpp`, `outils\equipement_gouffre_v3.py`, migration 101), construite, pas encore vérifiée en jeu :
  - **Braise du Gouffre** (910190), composant de donjon rangé dans la Collection : chaque boss en donne une avec 15 % de chances par difficulté (15 % en difficulté 1, 75 % en 5), et le dernier des boss tués d'une instance en donne une de plus. Les boss se lisent dans les rencontres d'instance : ceux du Gouffre n'avaient pas le drapeau de boss et ne rapportaient que 1 point de réputation au lieu de 10 (corrigé).
  - **31 pièces bleues de puissance 14** (fenêtre Équipement, catégories « Gouffre : maille, cuir, tissu, armes ») : chaque emplacement sauf bagues, cou et bijoux (plus tard, avec la joaillerie d'une autre zone), même barème et mêmes rangs 1 à 5 que les vertes. Recette : 1 Braise par pièce d'armure et par bouclier, 3 par arme (choix de l'utilisateur), plus le matériau de base, 40 éclats et 1 Malachite taillée (armure) ou 80 éclats et 1 Œil de tigre taillé (arme), et 50 pa ou 1 po. Chiffres provisoires, à calibrer.
- **Calibrage du Gouffre de Ragefeu** (01/11/2026, choix de l'utilisateur : puissance abaissée ; `outils\gouffre_v3.py`, migration 102), pas encore vérifié en jeu. À la puissance d'origine (13 à 16), même des monstres ordinaires restaient imbattables en packs pour une fiche de fin de Durotar (puissance 9,7 à 11,6), et les boss à 0 %. Désormais : monstres ordinaires de puissance 10 et 11 (vie et dégâts × 0,85), Massacreurs de la Lame brûlante en élites allégés de puissance 11 qui mènent les packs (× 0,70), boss de puissance 12 (× 0,94, Jergosh × 1,26), packs de 2 au plus (22 apparitions retirées sur 127). En simulation, la fiche de référence (puissance 9,7, vue comme celle de 60 % de Durotar) gagne 66 à 73 % des paires et 66 à 70 % contre chaque boss ; avec un rang d'objet de plus (fin de zone), 99 à 100 %.
- **Calibrage des primes A13, A16 et A17** (01/11/2026, demande de l'utilisateur ; `outils\primes_v3.py`, migration 105), pas encore vérifié en jeu. Elles restaient à 0 %, même avec deux rangs d'objet de plus : le Gangretisseur Arrogg et le Capitaine Plate-défense sont des rares élites de Blizzard (vie × 3, dégâts × 1,7), et Dent-de-l'Écho avait des dégâts × 7,5 et une puissance de 12 à 13 pour une prime annoncée à 11. Désormais, puissance 11 pour les trois, vie et dégâts × 1,10 (Dent-de-l'Écho), × 1,16 (Arrogg) et × 0,95 (Plate-défense). En simulation, la fiche de référence sous Repos gagne 77 à 85 % ; avec un rang de plus, 99 à 100 %. Les techniques (pluie de feu, traqueur, charge, entraîner au fond, frénésie) ne sont pas simulées.
- **Auras des monstres ramenées à leur puissance** (01/11/2026, mort de l'utilisateur contre Zalazane ; `v3_combat.cpp`). Rapetissement retire 1 + 0,3 Endurance et Force par niveau du lanceur : calculé au niveau affiché (80), il retirait 24 d'Endurance au lieu de 3, et la vie passait de 152 à 32 en plein combat. Toute aura d'un monstre à points par niveau (baisse de caractéristique, d'armure…) est désormais ramenée au niveau d'origine du lanceur, comme l'étaient déjà ses dégâts et ses soins.

### 2.6 Mort
- **Retour à la pierre de foyer, sans aucune perte.**
- Depuis F10 (01/11/2026), chaque mort coûte aussi de l'âme : voir « L'âme, à la manière de Dofus » et **F10 construite** dans la partie F5.

### 2.7 Rang d'aventurier : le confort de jeu (série 4)
En plus des difficultés de donjon, ses paliers débloquent du confort :
- la compétence de monte à un certain palier ;
- des montures, que l'on peut aussi obtenir autrement ;
- une pierre de foyer qui se recharge plus vite.

**Construit le 01/11/2026** (`v3_aventurier.cpp`, `outils\montures_v3.py`, migration 092 ; proposition validée : « Rang d'aventurier et montures — proposition.md »), pas encore vérifié en jeu :
- **Rang de compte**, alimenté par tous les personnages ; chaque objectif ne rapporte qu'une fois par compte. Il remplace le Renom de la v2, qui n'est plus chargé en v3.
- **Points de base** : quête d'histoire 10, sous-zone 2, lieu nettoyé 20, annexe 25 (+10 pour une médaille d'or), relique 10, zone à 60 % 50 et à 100 % 300, donjon terminé 150. Ils croissent avec la zone, × (1 + puissance haute conseillée / 100) ; pour un donjon, avec la puissance de son dernier boss. Durotar à 100 % et le Gouffre de Ragefeu donnent environ 2 000 points : la première monture arrive juste après (choix de l'utilisateur).
- **40 paliers jusqu'à 20 000 points**, plafond à relever avec les zones suivantes. Récompenses :
  - titres du jeu (« Éclaireur », « le pèlerin », « Traqueur », « l'explorateur », « l'assidu », « Ancien », et « le suprême » au dernier palier : le jeu n'a ni « l'Aventurier » ni « le Légendaire ») ;
  - pierre de foyer (30 min de base, vérifié) : 25, 20, 15 puis 10 min ;
  - six mascottes ;
  - modes de zone : difficile au palier 5, cauchemar au palier 9 ;
  - **palier 10** : compétence de monte, une monture à 60 % offerte (Loup des bois ou Cheval bai selon la faction), boutique ouverte de 60 à 70 % ; puis une vitesse tous les deux paliers, jusqu'à 150 % au palier 40 ;
  - difficultés de donjon 2 à 5 (paliers 12, 20, 30, 38), notées pour le chantier de réputation des donjons.
- **Montures** : plus aucune vente ni formation à la monte (249 ventes et 29 formations gardées dans des tables de retour). Avant le palier 10, on ne peut pas monter ; les montures volantes ne se lancent jamais (on en reparlera pour l'Outreterre et le Norfendre). C'est la monture qui donne sa vitesse : les 186 montures terrestres du jeu sont réparties de 60 % à 150 % par pas de 5 %, des plus simples aux plus belles (177 dans la boutique, une par nom).
- **Boutique** : icône de la barre (fenêtre « Rang d'aventurier », pages Paliers et Montures), ou `.monture acheter <sort>`. Prix en Marques du voyageur, de 20 (60 %) à 1 400 (150 %). Les montures achetées sont au compte. `.aventurier` donne les points et le palier.
- **Une seule monnaie (01/11/2026, demande de l'utilisateur)** : l'Insigne de Durotar disparaît ; annexes, épreuve du jour et reliques donnent des Marques du voyageur (1 Insigne = 1 Marque), et la carte des reliques et les nœuds du camp se paient en Marques (`outils\marques_v3.py`, migration 104). Les Insignes déjà gagnés sont versés en Marques à la connexion. Raison : faire évoluer le camp, valable partout, ne doit pas dépendre de la monnaie d'une zone.

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
  - **Chefs renforcés** (A01, A02, A05, A06, A10 ; migration 075, à la demande de l'utilisateur) :
    - **Copies** : chaque chef est une copie de l'original, avec les mêmes statistiques, le même butin et les mêmes scripts. Sa mort compte pour l'original : la quête d'histoire est validée.
    - **Apparition** : quand la troupe est tombée et que le joueur approche (120 m), le chef d'origine s'efface et la copie apparaît à sa place. Sa mort clôt le lieu, puis la troupe repart à zéro pour le prochain nettoyage.
    - **Techniques** (lignes SmartAI) :
      - T1 : Yarrog appelle 2 Vils quasits toutes les 20 s ;
      - T2 : Benedict appelle 4 Soldats de marine à 50 % ;
      - T3 : Kolkanis lance Piétinement (2 s) et Choc martial toutes les 15 s, puis appelle 2 Estafettes à 50 % ;
      - T4 : Zalazane lance Maléfice (5 s, faute d'une version à 3 s) toutes les 25 s, et pose une Garde guérisseuse toutes les 30 s ;
      - T5 : Gazz'uz lance Pluie de feu toutes les 15 s, puis appelle 2 Fanatiques à 30 %.
    - Les renforts apparaissent à côté du joueur. Mouchette (A07) reste un monstre ordinaire du lieu, en attendant sa prime A15.
  - **Reste à faire** : les primes, contrats, défis et reliques (25 %). Les annexes du document de Durotar restent à valider par l'utilisateur.
- **F5f** : accès au Gouffre de Ragefeu à 60 %.
  - **Construit le 31/10/2026, pas encore vérifié en jeu** (`v3_gouffre.cpp`, migration 076) :
    - **Ruga Brise-cendre** : en plus de ses quêtes, elle propose « Descendre dans la faille ». Avec D26 rendue et 60 % de Durotar, elle envoie le joueur à l'entrée du Gouffre. Sinon, elle lui chuchote ce qui manque, avec son pourcentage.
    - **Autres entrées** : l'entrée d'origine, à Orgrimmar, est refusée sous ces conditions, avec un message qui renvoie à Ruga.
    - **Sortie** : elle ramène devant Ruga, et non plus dans Orgrimmar.
    - Les maîtres du jeu passent toujours.
  - **Calibrage à noter (retour de l'utilisateur, 31/10/2026)** : Yarrog est déjà difficile sans renforts. Yarrog renforcé (2 Vils quasits toutes les 20 s) est à revoir au calibrage final.

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

**F10 construite (01/11/2026)**, chiffres validés par l'utilisateur, pas encore compilée ni vérifiée en jeu :
- **Les chiffres** :
  - âme maximale : **100** ; un personnage neuf commence plein ;
  - perte par mort : **1 + puissance / 15** (arrondi vers le bas), **au plus 10** ; 1 par mort dans tout Durotar ;
  - régénération : **4 éclats cadavériques par point**, multipliés comme le prix des rangs (1 + (puissance − 12) / 12 au-delà de 12), pris dans la Collection.
- **Les règles** :
  - toute mort compte, sauf en champ de bataille et pour un personnage Hardcore ;
  - la régénération se fait en zone de repos (auberge ou ville) : `.ame regenerer` rend autant de points que les éclats le permettent, jusqu'au maximum ;
  - à zéro : « Âme éteinte » au milieu de l'écran, personnage immobilisé, déconnecté au bout de 5 s ; chaque connexion suivante fait de même. Le joueur le supprime lui-même ;
  - `.ame` affiche l'état ; `.ame fixer <nom> <valeur>` (MJ, même hors ligne) fixe l'âme et déverrouille le personnage au-dessus de 0.
- **L'interface** : jauge d'âme sous la puissance, dans le cadre du personnage (`SolUI_Perso.lua`). Violette, rouge sous 25 %. Au survol : perte à la prochaine mort, prix d'un point, éclats en Collection. En auberge ou en ville, un clic propose la régénération.
- **Le code** : `v3_ame.cpp` ; table `acore_characters.solazeroth_v3_ame` (migration 088, appliquée) ; message d'addon `SOLAME`.
- **Simulation** (`outils\simulation_ame.py`) : le joueur régénère en auberge tous les 5 % quand son âme passe sous 70, avec au plus la moitié de ses éclats. Les zones après Durotar sont hypothétiques (puissance 14 à 200).
  - **Prudent** (une mort tous les 10 %) : jamais d'extinction. Âme quasi intacte à Durotar ; 3 à 12 % du revenu d'éclats en milieu de jeu, ~22 % en fin de jeu.
  - **Moyen** (une mort tous les 4 %) : 0,2 % d'extinction. 1 % du revenu à Durotar, 12 à 30 % en milieu de jeu, ~55 % en fin de jeu.
  - **Téméraire** (plus d'une mort tous les 2 %) : 58 % d'extinction, surtout après la puissance 100. En fin de jeu, l'âme coûte plus que le revenu.
  - Sans jamais régénérer : 100 morts à Durotar ; 10 morts suffisent au-delà de la puissance 135.
  - À revoir au calibrage final : le coût de fin de jeu pour un joueur moyen (la moitié du revenu) est lourd ; les taux de mort réels restent à mesurer en jeu.

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
  - **Onzième série, F6 butin (31/10/2026)**, choix de l'utilisateur ; pas encore vérifiée en jeu :
    - **Butin des monstres** : le corps ne garde que les composants (objets de la Collection), les objets de quête, les objets qui lancent une quête et les clés. Plus d'équipement, de recettes ni de consommables. L'or d'origine est gardé. Le tri porte sur toute table de butin de créature, chefs de donjon et de raid compris (`v3_collection.cpp`). Le vol à la tire et le butin des objets du monde ne changent pas.
    - **Choix du butin des boss (v2, `butin.cpp`)** : plus chargé en v3.
    - **Éclat cadavérique** (910120, migration 077 ; client : `quetes_durotar.item_dbc()`) : composant de qualité inhabituelle, en tête de la Collection (743 objets, 11 catégories). À la mort, un monstre en donne 0 (25 %), 1 (40 %), 2 (25 %) ou 3 (10 %), soit 1,2 en moyenne. Élite ×3 ; rare, chef de donjon ou chef renforcé ×5. Au-delà du niveau d'origine 12 (Durotar), le nombre croît de 1/12 par niveau. Ni les bestioles ni les renforts invoqués en combat n'en donnent.
    - **À calibrer avec F8** : le nombre d'éclats, d'après le prix des rangs d'objet.
  - **Douzième série, E1 équipement (31/10/2026)**, avancée avant F7 à la demande de l'utilisateur (« je ne peux rien faire en test tant que je ne peux pas acheter, fabriquer, améliorer l'équipement ») ; pas encore vérifiée en jeu :
    - **Barème commun** (`outils/equipement_v3.py`, migration 078). Retour de l'utilisateur : les récompenses de la vallée avaient tantôt des caractéristiques, tantôt rien, car elles reprenaient les chiffres de leur objet d'origine. Désormais, toutes nos pièces (récompenses de quête et pièces fabriquées) suivent le même barème :
      - armure et dégâts d'arme d'un objet vert d'origine de même type, au niveau d'objet égal à la puissance de la pièce ;
      - au moins 1 de Puissance d'attaque, et un peu d'Endurance selon la puissance et l'emplacement. Le personnage n'a qu'environ 84 points de vie au niveau 80 caché, et 1 Endurance en vaut 10 : le barème est volontairement prudent.
      - Conséquences : la Lame de Sen'jin, anomalie à 10 dégâts par seconde, revient à environ 5 ; le Rempart de Margoz passe de 411 à 237 d'armure. **À calibrer.**
    - **Fabrication** (fenêtre Équipement, onglet Fabrication ; `v3_equipement.cpp`) : 26 recettes de Durotar, de puissance 7 à 10, en quatre catégories (Maille avec le bouclier, Armes, Cuir, Tissu). Elles sont payées en composants bruts (minerai de cuivre, pierre brute, cuir léger, lanières, étoffe de lin), pris dans la Collection puis dans le sac, et en un peu d'or (5 c par point de puissance). **La maille, le bouclier et les armes demandent une enclume ou une forge** (Razor Hill) ; le cuir et le tissu se fabriquent partout (choix de l'utilisateur). Une recette s'ouvre à la puissance de la pièce moins 4.
    - **Achat** : Uhgar (armes), Cutac (cuir et tissu) et Wuark (maille et bouclier), à Razor Hill, vendent nos pièces fabriquées à la place de leur équipement d'origine (gardé dans `solazeroth_v3_marchands_origine`). Prix : 1 pa par point de puissance pour un plastron, moins pour les petites pièces ; nettement plus cher que la fabrication.
    - **Rangs 1 à 5** (onglet Amélioration) : chaque pièce existe en 6 versions, de +10 % de caractéristiques par rang. Le nom porte le rang (« … +2 »). Améliorer remplace l'objet à la même place, hors combat. Coût à Durotar : 15, 30, 60, 105 puis 180 éclats, et 60 c, 1 pa 20, 2 pa 40, 4 pa 80, 9 pa 60 ; davantage au-delà de la puissance 12. Les rangs 4 et 5 demandent aussi des pierres taillées (joaillerie, ci-dessous).
      - **Coûts triplés le 01/11/2026.** Retour de l'utilisateur à 27,7 % de Durotar : chaque pièce neuve passait aussitôt au rang 3 (35 éclats, 94 en réserve), d'où une puissance de 9,7 (niveau d'objet moyen 7,5 × 1,3), celle du nord, dès le sud. La simulation `outils\simulation_rangs.py` (revenu mesuré : ~18 éclats par % de zone, équipement changé à chaque secteur) retrouve 9,5 au milieu du sud avec les anciens coûts. Avec ×3, la puissance reste dans la fourchette des monstres de chaque secteur (sud 7,6 → 9,0 ; nord 9,1 → 10,8), avec des rangs moyens de 2 au lieu de 3. À revérifier en fin de zone et au Gouffre.
    - **Vallée des Épreuves** (01/11/2026, demande de l'utilisateur) : 6 filons de cuivre, du lin sur les Vils quasits (40 %), une forge et une enclume près du contremaître Thazz'ril (migrations 086 et 087), et 8 recettes rudimentaires de puissance 3 et 4, sans forge, ouvertes dès le départ (`equipement_v3.py`). Le 01/11/2026, 10 plantes (4 Pacifiques, 4 Feuillargents, 2 Terrestrines) et 4 filons de plus (migration 094 ; règle en 2.4 bis). Le même jour, moitié moins (5 filons, 5 plantes ; migration 098). Simulation (Samassan, vallée) : avec la hache rudimentaire, le Vil quasit tombe en 17 à 20 s au lieu de 30 à 38 s, sans danger ; le Scorpide cliquetant (puissance 6) reste hors de portée sans le reste de la panoplie.
    - **Joaillerie** (01/11/2026, onglet Joaillerie, `outils\joaillerie_v3.py`, migration 085) : `.equipement prospecter` prend 5 Minerais de cuivre et donne une gemme brute (Malachite 55 %, Œil de tigre 35 %, Œil ténébreux 10 %) ; `.equipement tailler <pierre>` prend 2 gemmes brutes. Rang 4 : 2 Malachites taillées et 1 Œil de tigre taillé ; rang 5 : 2 Yeux de tigre taillés et 1 Œil ténébreux taillé. Au survol d'une pièce, l'onglet Amélioration montre la liste de courses jusqu'aux rangs 4 et 5 (éclats, or, pierres, gemmes à tailler, minerai à prospecter).
      - **Finitions F8** (01/11/2026) : les pierres taillées ont des icônes retail (gemmes taillées vertes, ambre et violettes, `icones_retail.py`, ItemDisplayInfo.dbc du patch). La joaillerie d'origine est retirée (migration 090) : les 16 maîtres joailliers n'enseignent plus rien, et les dessins de joaillier ne sont plus ni vendus ni lâchés en butin. Tout est sauvegardé dans les tables `solazeroth_v3_joaillier_*` pour le retour arrière. Les maîtres proposent encore de s'entraîner, sur une liste vide.
    - **Puissance du personnage** : le rang compte pour +10 % par rang (`SolAzeroth.V3.PuissanceParRang` = 0,1), au lieu des rangs de menace de la v2.
    - **Ouverture** : la fenêtre se règle dans « Techniques et raccourcis », section Fenêtres, comme la Collection.
  - **Treizième série (31/10/2026)** :
    - **Simulation de combats** (demande de l'utilisateur : tout équilibrage passe par des combats simulés entre un bot du joueur et un bot du monstre) :
      - `outils/simulation_combat.py` reprend les règles du serveur (armure fixe, ×4 et ×1,5 des monstres, malus de puissance, kit du guerrier tank, Rempart, temps de réaction du joueur). Il rejoue les combats du journal, ou bâtit un monstre depuis la base avec la formule du moteur.
      - `outils/tests_equilibrage.py` : la fidélité du modèle est bloquante (un monstre bâti depuis la base doit avoir la fiche du journal ; le combat de référence contre le Scorpide claquant doit être reproduit à 30 % près). Le rapport d'équilibrage est non bloquant : le personnage Test, avec quatre panoplies, contre dix monstres de Durotar.
      - Fidélité actuelle : dégâts du joueur +16 %, du monstre -21 %, sur un seul combat réel. Le journal écrit désormais l'arme à une décimale, pour réduire l'écart.
    - **Analyse du combat perdu contre le Scorpide claquant** (puissance 6 contre 3,2, malus de 6 % seulement) : son armure de 165 retire 8 points à chaque coup. La mêlée tombe à son plancher de 3 dégâts, et le joueur inflige 3,3 dégâts par seconde contre ses 240 points de vie. L'armure fixe des monstres écrase les armes faibles.
    - **Premier rapport de simulation** : à puissance égale, les monstres de la vallée meurent en 7 à 15 s sans danger. Au-delà de la puissance 7, même la fin des quêtes de Durotar (puissance 9,3) perd contre un monstre de puissance 10 ou 11. **À calibrer** avec ces outils.
    - **Cadre de cible** : la puissance s'affiche dès qu'on change de cible (elle attendait jusqu'à 2 s le prochain envoi du serveur). Un contour de 2 px prend la couleur de la difficulté : rouge à 5 points de puissance de plus, orange à 3, jaune de -2 à +2, vert jusqu'à -5, gris en dessous.
    - **Discussion** : les liens des objets à collectionner prennent leur teinte, comme dans les infobulles et la Collection.
  - **Quatorzième série (31/10/2026)** :
    - **Puissance de la cible, vraie cause du délai** : le serveur ne renvoyait pas un message identique au précédent. En passant d'un sanglier à un autre de même puissance, rien ne partait, alors que l'interface efface la puissance à chaque changement de cible, d'où jusqu'à 10 s d'attente. Le message part maintenant à chaque changement de cible.
    - **Puissance des monstres à moins de 60 m** (demande de l'utilisateur) : chaque seconde, le serveur envoie celle des monstres arrivés à portée (« PROCHES »), et l'interface l'affiche dès qu'on cible. Coût : une recherche dans la grille par seconde, quelques octets par monstre nouveau, et un renvoi complet toutes les 10 s.
    - **Contour de la cible** : 4 px au lieu de 2.
    - **Fabrication en 10 s** : animation du métier (marteler pour la maille et les armes, travailler debout sinon) et barre de progression. Bouger annule, sans rien coûter : composants et or ne sont pris qu'à la fin, après une nouvelle vérification.
    - **Annonces retirées** : celles de mod-transmog (« … ajouté(e) à votre collection d'apparences »), filtrées par la discussion. Le module tiers reste intact.
    - **Addon de butin v2** (SolAzerothButin) : il demandait « .solbutin liste » à la connexion, une commande absente en v3. Il est rangé avec les addons v2, et le lanceur le retire du jeu.
    - **Durotar d'essai** : les 240 po de test sont retirés, et 210 éclats cadavériques sont donnés, soit la moyenne des 175 monstres hostiles de la vallée des Épreuves (à 1,2 éclat chacun).
  - **Quinzième série (31/10/2026)** :
    - **Cri de défi** (choix de l'utilisateur) : la provocation ne servait à rien en solo. Il attire toujours les ennemis à moins de 15 m, et chacun verse 3 % de la vie maximale dans le Rempart (`SolAzeroth.V3.Rempart.CriDefi`). Simulation contre 3 monstres de la vallée : vie restante de 33 à 60 % contre des Familiers vils, de 64 à 85 % contre des Scorpides ouvriers. Les packs trop forts restent perdus.
    - **Simulateur** : combat contre un groupe (mêlée et Frappe du bouclier sur un monstre, Coup de tonnerre sur tous, Cri de défi), et effet d'un repas.
    - **Cuisine par zone** (`outils/cuisine_v3.py`, migration 079, `v3_cuisine.cpp`) :
      - les plats d'une zone sont les recettes de Blizzard dont un ingrédient au moins tombe sur ses monstres, et dont les autres s'y trouvent (butin ou marchand), sans les plats de fête ;
      - Durotar en a 5 : viande de sanglier rôtie, Surprise du scorpide, maquereau, steak de crocilisque et thon arc-en-ciel ;
      - un plat donne, pendant 30 minutes, la caractéristique de la spécialisation (Force pour le guerrier tank, sinon celle de la classe), d'autant de points que la puissance moyenne de la zone : 6 à Durotar (moyenne des niveaux de ses monstres ordinaires, entre le 5e et le 90e centile). Un seul repas à la fois ;
      - fabrication dans la fenêtre Équipement, catégorie Cuisine, près d'un feu (le Feu de camp v3 compte, et l'on cuisine assis sans l'éteindre), en 5 s ;
      - simulation (fin de vallée, +6 Force) : combats 15 à 25 % plus courts. Contre le Sanglier tacheté redoutable (puissance 7), vie restante de 27 à 42 %.
    - **Après l'essai au fort de Tiragarde** :
      - **recettes de cuisine à 3 composants** : l'ingrédient de Blizzard, plus une herbe de la zone (Pacifique, Feuillargent ou Terrestrine à Durotar) et un assaisonnement vendu dans la zone (épices douces, eau de source, lait, farine ou sel), attribués à tour de rôle ;
      - **Cri de défi** posait les monstres sur la tête du guerrier (attraction du moteur) : ils atterrissent maintenant au contact, de leur côté ;
      - **blocage à 45/46** : la troupe était tombée, et le 46e est le chef renforcé (Lieutenant Benedict), qui apparaît à la place du chef d'origine, en haut du fort, sans rien dire. Son apparition est maintenant annoncée dans la discussion, avec sa distance et « plus haut » ou « plus bas » ;
      - **silhouettes d'ambiance de l'Alliance dans le fort** (migration 080) : elles suivaient le trajet d'un Fusilier de Kul Tiras. Les monstres des lieux à nettoyer ne servent plus de routes d'ambiance. La faction ne suffisait pas à trier : d'autres PNJ de faction 123 sont de vrais gardes.
    - **Puissance du personnage, décision de l'utilisateur** : elle reste la moyenne des seules pièces portées, sans compter les emplacements vides pour 0. Une pièce proche de la moyenne ne la change donc presque pas : un pantalon de niveau 5 sur une moyenne de 4,86 la porte à 4,88.
    - **Enchantement** (demande de l'utilisateur, choix des enchantements laissé à Claude ; `outils/enchantement_v3.py`, migration 081, `v3_equipement.cpp`) : deux onglets de plus dans la fenêtre Équipement.
      - **Désenchantement** : une armure ou une arme du sac, verte ou mieux, est détruite ; son butin de Blizzard (poussières, essences, éclats) va dans la Collection. Un second clic confirme. Nos pièces (quêtes, fabrication, rangs) reçoivent la table d'une pièce verte de même genre et de même niveau d'objet. À Durotar : Poussière étrange ×1-2 (80 %) ou Essence de magie inférieure ×1-2 (20 %) pour une armure, l'inverse pour une arme.
      - **Enchantement** : les enchantements mineurs de Blizzard, un par pièce, portée ou dans le sac. Le nouveau remplace l'ancien, et il reste quand la pièce change de rang. Coût : les composants, plus 10 c par composant.

        | Pièce | Enchantement | Composants |
        |---|---|---|
        | Plastron, robe | Santé mineure, +5 points de vie | 2 Poussières |
        | Brassards | Force ou Agilité mineure, +1 | 3 Poussières, 1 Essence |
        | Cape, bouclier | Protection mineure, +10 armure | 2 Poussières, 1 Essence |
        | Arme à une main | Frappe mineure, +1 aux dégâts | 3 Poussières, 2 Essences |
        | Arme à deux mains | Impact mineur, +2 aux dégâts | 4 Poussières, 2 Essences |

      - **Équilibre** (simulation, personnage de fin de vallée) : le jeu complet vaut à peu près un rang d'amélioration sur toutes les pièces. Contre le Tigre de Durotar (puissance 8), victoire de 59 à 98 % ; contre le Fouette-queue Griffesang, de 8 à 54 %. L'Endurance mineure des bottes (+10 points de vie) le doublait presque (85 %) : pas de bottes à Durotar. La panoplie enchantée est dans `tests_equilibrage.py`.
    - **Retouches demandées ensuite** :
      - **barre de fabrication** : elle est dans la fiche de la recette, au-dessus du bouton Fabriquer, et non plus au-dessus des barres d'action ;
      - **bouton de repas** : à droite de la potion, sous la pierre de foyer. On y glisse un plat de la cuisine ; vide, ou quand le plat est épuisé, il prend le premier plat des sacs. Il a sa touche dans la fenêtre Techniques et raccourcis (« R »). Le plat glissé est gardé par le serveur (`.camp repas`, migration 082) et revient d'une session à l'autre ;
      - **apparition d'un chef renforcé** : annoncée comme une alerte de raid, au milieu de l'écran et avec son bruit, et non plus dans la discussion.
  - **Apparence et logique** : l'apparence de ces fenêtres ne vit que dans le client. Elle se retouche sans toucher au serveur : il suffit de reconstruire le patch et de relancer le jeu. Dans les fichiers Lua, apparence et comportement sont encore mêlés.

**Suite proposée par Claude** (après F5c à F5f) :
- **F6, butin** : construit (onzième série).
- **F7, potion et camp** : construit le 01/11/2026 avec les chiffres de l'utilisateur, pas encore vérifié en jeu. Aucune contrainte de contenu ; chaque rang s'achète dans la page 3 de la fenêtre Techniques et raccourcis, avec sa liste de courses (le manquant en rouge) :
  - **potion rang 1** (`.camp potion`) : 2 charges, 35 % de la vie ; **rang 2** : en plus 1 % de la vie par seconde pendant 10 s (sort 100034) ;
  - **camp nœud 2** (`.camp acheter`) : Repos de 30 min, vie maximale +5 %, 2 % de vie par seconde hors combat, +5 à la caractéristique principale de la spécialisation, et les +10 % de dégâts du nœud 1 (sorts 100033 Force, 100035 Agilité, 100036 Intelligence ; Force pour le guerrier tank, seul kit ; les autres classes ont pour l'instant celle de leur classe) ; **nœud 3** : le même Repos pour 40 min ;
  - listes de courses doublées, sans Mage royal ; elles sont dans `outils\bivouac_v3.py`, qui écrit la migration 089 et `SolUI_Camp.lua` ;
  - **simulation** (`outils\simulation_camp.py`) : potion et Repos ne changent rien contre les monstres faciles. Au mur de difficulté, ils le repoussent d'un niveau environ : à puissance 10 contre un monstre de niveau 11, victoire de 3 % sans rien, 40 % avec la potion de départ, 80 % au rang 2, 98 à 100 % avec en plus le Repos des nœuds 2-3 ; à niveau 12, au plus 7 %.
- **F8, rangs d'objet et joaillerie** : construit avec E1, finitions le 01/11/2026 (icônes, joaillerie d'origine retirée).
- **F9, modes de zone** : construit le 01/11/2026 (`v3_modes.cpp`, migration 091), pas encore vérifié en jeu. À 60 % d'une zone, le mode se choisit dans une auberge ou une ville (fenêtre des objectifs de zone, ou `.mode normal|difficile|cauchemar|aucun`) ; il est rappelé dans le suivi de zone.
  - **Puissance des monstres** : quand un monstre engage le joueur, il passe à la **puissance de base** du joueur (moyenne des niveaux d'objet, **sans les rangs**) plus l'écart du mode ; un monstre plus fort garde la sienne. Raison (simulation `outils\simulation_modes.py`) : avec la puissance rangs compris, chaque rang rendait les monstres plus forts aussi vite que le joueur, et deux rangs de plus faisaient perdre davantage. Sans les rangs, ceux-ci restent un vrai gain.
  - **Chiffres** (proposés puis ajustés par simulation, l'écart +1/+2 du départ rendait le difficile et le cauchemar injouables) : normal, écart 0 ; difficile, écart 2, vie et dégâts × 1,25, une technique, éclats × 2 ; cauchemar (hors zones de repos), écart 2, × 1,5, deux techniques plus fortes (× 1,5), éclats × 3, rares + 50 % de vie.
  - **Simulation** (fiche à puissance 9,7, niveau d'objet 7,5) : difficile, 49 % de victoires au rang 3 avec la potion de départ, 100 % avec potion rang 2 et Repos ; cauchemar, 2 % au rang 3, 63 % au rang 4 et 98 % au rang 5 avec F7. Les techniques ne sont pas simulées (comptées comme +10 % de dégâts subis).
  - **Techniques** (affixes de donjon de la v2) : Enragé (sous 30 % de vie, +50 % de dégâts), Renforçant (à sa mort, +20 % de dégâts et de vie aux monstres à 30 m, 5 fois au plus), Volcanique (pluie de feu sous le joueur toutes les 10 s, 15 % de la vie si on y reste 2 s).
  - **Cauchemar** : toutes les 4 à 6 minutes, une pluie de feu (trois éruptions) ou un rare de la zone qui apparaît à 20 m (5 minutes, il donne ses éclats) ; écran légèrement rougeâtre.
- **F10, âme** : construite le 01/11/2026 (voir **F10 construite**), pas encore compilée.
- **Rang d'aventurier et montures** : construit le 01/11/2026 (voir 2.7), pas encore vérifié en jeu.
- **Réputation des donjons, difficultés et passifs** : construits le 01/11/2026 (voir 2.5), pas encore vérifiés en jeu.
- **Accès aux fonctionnalités : les carnets** (01/11/2026, proposition et maquette validées : « Accès aux fonctionnalités — proposition.md ») : construits, essayés à blanc, pas encore vérifiés en jeu (`SolUI_Carnets.lua`).
  - Six carnets à onglets rangent toutes les fenêtres : **Personnage** (C : Fiche, Âme, Spécialisation), **Techniques** (K : Raccourcis, Techniques équipées), **Camp** (N : Feu, potion et arbre ; Cuisine), **Artisanat** (P : Fabrication, Amélioration, Désenchantement, Enchantement, Joaillerie), **Collection** (B : Inventaire, Composants), **Aventure** (L : Quêtes, Zone, Rang d'aventurier, Montures, Passifs extérieurs, Donjons). Une colonne à gauche de la fenêtre donne le carnet et ses onglets ; un seul carnet ouvert à la fois, chacun retient son dernier onglet.
  - Une seule liste pour la barre (8 icônes : les six carnets, la carte, le menu), le menu de la mini-carte et les touches. Les touches sont posées à la première connexion à la place de celles du jeu, sauf si le joueur les a changées. Le menu donne Hauts faits, Réglages Sol'Azeroth et le Menu du jeu.
  - Accès là où l'on agit : bouton « Camp » à côté du compte à rebours du feu ; annonce cliquable quand les modes d'une zone s'ouvrent (vers Aventure › Zone) et en entrant dans une zone de repos (vers Passifs extérieurs, au plus toutes les 10 minutes) ; la fenêtre d'entrée de donjon mène à Aventure › Donjons.
  - **Social retiré** (demande de l'utilisateur, « le social ne sert à rien ») : plus dans la barre ni le menu, et sa fenêtre est refermée aussitôt si elle s'ouvre (touche O).
  - **/sol ne garde que les réglages** ; les pages v2 (Contrats, Amélioration, Butin, Codex et Renom, Journal de collection, Hauts faits du compte) et la page Techniques en sont retirées.
- **Retours du 01/11/2026 après la purge du compte** (demandes de l'utilisateur) : construits, essayés à blanc, pas encore vérifiés en jeu.
  - **Inventaire de 50 places** (Collection › Inventaire, `SolUI_Inventaire.lua` ; serveur `v3_inventaire.cpp` ; migration 095) : le sac à dos (16) et la Besace d'aventurier (910235, 34 places), posée d'office à la connexion et impossible à enlever. Aucun autre sac, carquois ou giberne ne s'équipe. La grille montre ce qu'il y a vraiment dans les sacs (utiliser, vendre, glisser comme dans le jeu), les places libres et l'or. Les fenêtres de sacs du jeu ne s'ouvrent plus : leurs touches mènent à cet onglet, et un marchand l'ouvre puis le referme. L'ancien onglet « Inventaire » de la Collection s'appelle désormais « Composants ».
  - **Retirés** : l'addon des sacs (SolAzerothSacs ; la banque était déjà fermée depuis la migration 065), le grimoire du jeu (rangé, refermé s'il s'ouvre ; plus dans le menu), les macros (fenêtre du jeu qui ne se charge plus, bouton du menu du jeu caché, addon SolAzerothMacros), les barres de postures et de totems (barre de totems rangée comme celle des postures, addon SolAzerothBarres). Les trois addons sont rangés dans `addons-v2` et retirés du client par le lanceur ; /sol perd ses pages Macros et Barres et sacs.
  - **Marques, éclats et or dans le HUD** (`SolUI_Soldes.lua`) : un petit bloc au-dessus de la barre d'icônes donne les Marques du voyageur (sacs), les Éclats cadavériques (Collection et sacs) et l'or, avec le détail au survol. C'est un bloc comme les autres (mode édition : déplacer, molette pour la taille).
  - **Vallée des Épreuves** : moitié moins de récolte (5 filons de cuivre et 5 plantes, migration 098) ; repousse des plantes et filons portée de 3 à 30 minutes ; épice douce en vente chez Duokna (fournitures générales) ; migration 095.
  - **Épingles de la mini-carte et de la carte du monde** (maquette « Épingle » choisie ; `SolUI_Quetes.lua`, serveur `v3_carte.cpp`) : les marques du jeu disparaissent de la mini-carte (« ! » et « ? » effacés de `Interface\Minimap\ObjectIcons.blp` par `outils\minicarte_v3.py` ; zones et flèche d'objectif coupées par l'option questPOI, remise le temps que la carte du monde est ouverte). À leur place, une épingle par PNJ, pointe sur lui : « ! » ambre à prendre, « ! » gris facile (puissance de la quête 6 sous la tienne ou plus), « ? » pleine ambre à rendre, « ? » grise en cours. Hors de la mini-carte, elle se colle au bord, plus petite, avec une flèche (quêtes à rendre toujours, quêtes à prendre jusqu'à 500 m). Survol : les quêtes à cet endroit et des épingles voisines. Le serveur envoie désormais aussi qui reprend chaque quête du journal. Les zones d'objectif des quêtes suivies restent. Sur la carte du monde, les mêmes épingles (un peu plus grandes) remplacent les anciens points d'exclamation, avec en plus les quêtes à rendre et en cours. Les zones d'objectif y sont aussi, comme sur la mini-carte : un rond ambre à l'échelle du terrain et son point pour chaque quête du journal pas encore remplie, avec la quête et ses objectifs au survol ; les marques de quête du jeu (zones, numéros) y sont coupées aussi.
  - **Journal trié par puissance** (`SolUI_Quetes.lua`) : la liste du journal est toujours rangée par puissance croissante (à égalité, par titre) dans chaque zone, et les zones dans l'ordre de leur quête la plus faible.
  - **Chefs renforcés et quêtes** (`v3_zone.cpp`, remarque sur « Le Convent en cinq minutes ») : la troupe d'un lieu tombe aussi avec les monstres tués pour les quêtes, et le chef renforcé prenait alors la place du chef d'origine, même pour une quête ou un défi qui le vise (puissance annoncée faussée). Désormais, tant qu'une quête du journal pas encore remplie vise le chef d'origine (le tuer ou prendre un objet de quête sur lui), le chef renforcé n'apparaît pas ; s'il est déjà là hors combat, il s'efface et le chef d'origine revient. Un message l'annonce une fois. Quêtes concernées dans Durotar : le médaillon (Yarrog), le Convent en cinq minutes, les traîtres et l'assaut des remparts (Benedict), le seigneur de guerre (Kolkanis), Zalazane, Ombres ardentes (Gazz'uz).
  - **Signaler un bug** (`SolUI_Signalement.lua`, serveur `v3_signalement.cpp`, migration 097) : la touche « ! » (ou /bug ; réglable dans Techniques et raccourcis) fait noter au serveur la position exacte du personnage et sa cible, puis ouvre une fenêtre pour décrire le problème. Les signalements vont dans `acore_characters.solazeroth_v3_signalements` (colonne `traite` à 0 tant qu'ils ne sont pas traités), pour être repris tous ensemble.
  - **Premiers signalements traités** (01/11/2026, onze bugs notés avec « ! ») :
    - les reliques se posent au sol quand un personnage passe à moins de 150 m ; la hauteur corrigée est gardée en base (`v3_annexes.cpp`) ;
    - deux épingles qui se chevauchent n'en font plus qu'une, la plus importante, dont l'infobulle reprend les quêtes de l'autre (mini-carte et carte du monde) ;
    - comparaison avec la pièce portée en tenant Maj dans la fenêtre Équipement, comme dans les sacs ;
    - A11, la matriarche des scorpides, passe de puissance 4 à 5 : avec ses trois ouvriers, la simulation donne 38 % de victoires à la puissance 3,2 et 100 % (65 % de vie restante) à 4,9 ;
    - plaques de nom des monstres : la puissance à la place du niveau, colorée comme le cadre de la cible ; le serveur envoie le nom des monstres proches avec leur puissance, car une plaque ne dit pas de quel monstre elle est (`SolUI_Plaques.lua`, `v3_combat.cpp`) ;
    - enchantements en liste : une ligne par enchantement possible de chaque pièce, avec son coût et un seul bouton ;
    - plus de maîtres de classe, de profession ni de familiers dans le monde (703 apparitions retirées) ; les 293 qui donnent ou reprennent une quête restent sans leur fonction de maître ; les maîtres de monte restent (migration 099) ;
    - passif placé : la réponse donne son nom, plus son numéro (filtre de discussion dans `SolUI_Passifs.lua`) ;
    - les pièces rudimentaires restent non désenchantables (deux signalements contraires, le second l'emporte : déjà le cas).
    - enchantements : une ligne par pièce, et au bout une liste déroulante de ses enchantements avec leur coût ; en choisir un l'applique (grisés : celui en place, ceux qu'on ne peut pas payer) ;
    - les défis contre la montre à prendre ont une épingle « ? » bleue, comme les quêtes à refaire du jeu ;
    - la mini-carte montre aussi la zone d'objectif des quêtes non suivies pas encore remplies, quand elle est à portée (jamais en point au bord) ;
    - un objet qui lance une quête retirée disparaît du butin et des marchands : 44 objets, dont à Durotar l'Enveloppe vieillie du coffre de Benedict et l'Œil d'ombre ardente (migration 100) ;
    - la matriarche (A11, puissance 5) est tombée vite à la puissance 8 : conforme.
    - **reliques** : avec la carte des reliques achetée, un coffre marque chaque relique pas encore trouvée sur la mini-carte (à portée) et la carte du monde, avec son indice au survol ; une relique se ramasse aussi en se tenant à moins de 3 m (le Fétiche de jade ne se cliquait pas).
- **Annexes de Durotar** (44 %) : écrites par l'équipe d'agents, à valider, puis construites avec F5e.
- **Sorts des monstres** (01/11/2026, audit « Sorts des monstres — audit.md », accord de l'utilisateur) : construits, simulés, pas encore vérifiés en jeu.
  - Le simulateur joue désormais les sorts des scripts des monstres (`simulation_sorts.py`) : délais, incantation, valeur à la puissance du monstre, dégâts directs et sur la durée, coups d'arme, étourdissements, soins, boucliers, affaiblissements. Validé sur le journal : Corruption 15/15, Immolation 8,4/8,3, Coup de tonnerre 50/50, Bouclier de foudre 23,8/26. Sans sorts, il rend exactement les chiffres de `simulation_combat.py`.
  - Règle : chaque sort de monstre a un effet lisible en v3, sinon il est retiré ; les renforcements des monstres sont en pourcentage, jamais en points fixes (un bonus fixe s'ajoute avant le ×4 et ne suit pas les réglages : la Frénésie de Dent-de-l'Écho donnait +200 par coup, 198 relevé en jeu). 13 sorts de remplacement (102000 à 102012, migration 106, `sorts_monstres_v3.py`) : Rapetissé (−15 % de dégâts), Aveuglé (−20 % de vitesse d'attaque), Carapace (−50 % de dégâts subis), Bouclier levé (−40 %), Armure fendue (−10 % par cumul, 5 cumuls), Souillure (−25 % de soins reçus), saignement, Malédictions de faiblesse en %, Frénésie (+50 % de vitesse d'attaque, +25 % de dégâts), Assaut fulgurant et Boutoir (+50 % de dégâts quelques secondes). Retirés : Posture défensive et Coup de bouclier de Benedict, Totem de lien terrestre, Vitesse du tigre, et les invocations (marcheur du Vide, diablotin : un renfort doublait le combat d'un lanceur de sorts, contre la règle des packs de 2).
  - Recalibrage (migration 107, `sorts_calibre_v3.py`) : chaque monstre qui lance des sorts fait subir, en moyenne, autant de dégâts avec ses sorts que sans eux, et se gagne aussi souvent. D'abord sa mêlée baisse (DamageModifier, jusqu'à ×0,3), puis ses sorts (table `solazeroth_v3_sorts_facteur`, jusqu'à ×0,2, lue par `v3_combat.cpp` sur les dégâts et les soins des sorts). 56 monstres réglés sur 60. Les lanceurs de sorts sont les plus touchés (Sorcière des tempêtes ×0,37 sur ses sorts, Gazz'uz et les démonistes ×0,2).
  - Reste : les techniques ajoutées par les modes de zone et les difficultés de donjon ne sont pas encore passées par ce simulateur ; Pluie de feu est comptée en entier alors qu'on peut en sortir.
- **Lexique et explications** (01/11/2026, demande de l'utilisateur : « beaucoup d'information qu'on ne peut pas deviner ») : construits, essayés à blanc, pas encore vérifiés en jeu (`SolUI_Lexique.lua`).
  - Un septième carnet, **Lexique** (touche J si elle est libre), un onglet par thème (Monnaies, Équipement, Zone, Survie, Progression) et une page courte par concept (25 pages : comment l'obtenir, comment le dépenser, les chiffres). Les chiffres viennent du relevé du serveur du 01/11/2026 : à tenir à jour avec lui.
  - Au premier passage d'un moment clé, une petite fenêtre « À savoir » résume le concept et mène à sa page : première puissance reçue, premier éclat, premières Marques, premier or gagné, premier composant, première forge, première prime, premier contrat ou défi pris, premier lieu entamé, première relique, zone à 60 %, vie sous 50 % (vie, camp, potion), première mort, nouvelle technique, palier d'aventurier, entrée en donjon. Hors combat, une à la fois, une seule fois par compte (gardé avec la disposition de l'interface).
  - Relevé du 01/11/2026 : toute quête rendue donnait encore 3 Marques (`marques.cpp`) et le tableau de contrats v2 tournait sans interface ; coupés au lot 1 de l'audit du jeu.
- **Audit du jeu, lot 0** (02/11/2026, audit « Audit du jeu\10_consensus.md », accord de l'utilisateur) : construit, pas encore vérifié en jeu.
  - L'Œil d'ombre ardente (4903), demandé par « Ombres ardentes », n'avait plus de source depuis la migration 100 : le Gouffre restait fermé. Il revient sur Gazz'uz et ne lance plus son ancienne quête (migration 108). Nouveau test `verifier_quetes.py` : chaque objet demandé par une quête v3 active doit avoir une source (butin, contenant, marchand, script, quête active).
  - Le Journal de bord détrempé n'affiche plus la page d'Elune héritée de son objet d'origine (migration 109, `annexes_durotar.py`).
  - Quand une quête du journal retient le chef renforcé d'un lieu (A26 et Benedict), la fenêtre Zone et le suivi le disent sur la ligne du lieu.
  - Textes corrigés : infobulles du Rempart (40 % des coups, 8 % de la vie pour Frappe du bouclier), messages de déblocage et de spécialisation (carnets au lieu de /sol), Lexique au tutoiement, « quatre techniques au départ, jusqu'à huit », trois monnaies au lieu d'une (Lexique, README, LISEZMOI), « (à venir) » retiré des difficultés de donjon dans la liste des paliers.
- **Audit du jeu, lot 1 : la v2 coupée** (02/11/2026, « Audit du jeu\10_consensus.md », C3, accord de l'utilisateur) : construit, pas encore vérifié en jeu.
  - Les scripts v2 encore chargés en v3 ne tournent plus (`mod_solazeroth_loader.cpp`) : 3 Marques par quête rendue et Marques des boss selon la menace (`marques.cpp`), enchantement de bonus et `.solameliorer` (`bonus.cpp`), défis de boss tirés au sort, intendant, tableau de contrats et `.solcontrat`, protection contre la malchance et Éclats de raid, Codex, journal de collection des boss. Leurs fonctions restent dans le module : la v3 donne et retire les Marques avec celles de `marques.cpp`. L'économie des Marques de la v3 avait été réglée sans les 3 Marques par quête.
  - Gardés : `.reinitialiser` (instances rejouables sans attente, utile au Gouffre), journal de donjon, pistage des ressources, mort Hardcore, ambiance et raids seuls. Les défis de boss reviendront en v3, visibles.
  - Client : les addons Amélioration, Codex, Contrats, Hauts faits et Journal de collection sont rangés dans `addons-v2` et retirés du jeu par le lanceur ; l'entrée « Hauts faits » quitte le menu (la fenêtre du jeu n'avait que ceux de la v2). Le Lexique ne compte plus de Marques par quête.
- **Audit du jeu, lot 2 : les outils d'équilibrage réparés** (02/11/2026, « Audit du jeu\10_consensus.md », U9) : outils seulement, rien ne change en jeu.
  - `tests_equilibrage.py` passe de nouveau : il vérifie la fiche de chaque monstre des journaux (52, dont 14 écrites avant un calibrage et relues avec les réglages d'origine gardés par les migrations) et la durée de 398 combats réels en mêlée seule (simulé ÷ réel 0,99 en médiane). La vie des monstres est arrondie au-dessus comme le jeu ; les panoplies sont essayées sur le personnage de la fiche (Sebiria), plus toujours sur Test.
  - `simulation_modes.py` et `simulation_donjons.py` suivent `v3_modes.cpp` : difficile à écart 2, puissance de base arrondie en dessous sans les rangs, techniques comptées avec leur force. Le monstre des passifs est réglé par dichotomie (les passifs ne sortent plus tous négatifs : +16 à +36 victoires sur 100).
  - `simulation_rangs.py` va jusqu'au rang 5 avec l'or et les pierres taillées (comptées en filons de cuivre, 32 filons pour une pièce au rang 5) et essaie le transfert rang − 1 (C6). Résultat : les éclats bloquent avant les gemmes, les pièces finissent Durotar au rang 2,5 de moyenne (3,0 avec le transfert) ; les rangs 4 et 5 ne servent pas sur Durotar avec le revenu mesuré. À mesurer en jeu : filons minés et or gagnés par % de zone.
- **Téléportation vers les donjons terminés** (02/11/2026, demande de l'utilisateur, à la place de `.reinitialiser` dans l'interface) : construit, pas encore vérifié en jeu.
  - Carnet Aventure, onglet Téléportation : la liste des donjons dont le dernier boss est tombé au moins une fois (au compte). Un clic remet le donjon à zéro (instance neuve, difficulté à choisir à l'entrée) et y envoie le joueur, à l'arrivée de sa porte d'origine. Hors combat, hors d'une instance, vivant, pas en vol.
  - Les conditions d'entrée restent : le Gouffre de Ragefeu demande toujours D26 et 60 % de Durotar au personnage. La sortie du donjon ramène à sa sortie habituelle (Ruga pour le Gouffre).
  - `.reinitialiser` reste pour les raids. Serveur : `v3_donjons.cpp` (`.teleportdonjon`, préfixe SOLTELEPORT) ; client : `SolUI_Passifs.lua`, `SolUI_Carnets.lua` (7 onglets possibles par carnet).
- **Audit du jeu, lot 3a : armure en pourcentage, menace et mort lisibles** (02/11/2026, « Audit du jeu\10_consensus.md », C1 et C5 ; choix de l'utilisateur : les recommandations du consensus, lot 3 en trois temps) : construit, pas encore vérifié en jeu.
  - Armure : réduction = armure / (armure + 100 × (3 + puissance de l'attaquant)), sans plancher (`v3_combat.cpp`, SolAzeroth.V3.ArmureK et ArmureC). Avant : armure / 20 retirés de chaque coup, au moins 25 % passaient ; dès 600 d'armure, tous les coups tombaient au plancher.
  - Barème des pièces (`equipement_v3.py`, migration 110 par `armure_v3.py`, 468 pièces, rangs compris) : poids de la pièce × (3 + puissance). Une panoplie à jour retire, contre un monstre de sa puissance, 45 % (maille et bouclier), 40 % (maille), 25 % (cuir), 12 % (tissu), dans toutes les zones ; moins contre un plus fort. Avant : environ 850 pour une maille, de la puissance 2 à 30.
  - Dégâts des monstres en mêlée ×3 au lieu de ×4. Simulation des combats réels des journaux (`simulation_armure.py`) : monstre seul 26 % de vie perdue en médiane (cible 15 à 30), vallée 14 %, groupes 61 %. La difficulté monte maintenant au fil de Durotar (9 %, 24 %, puis 41 % contre un monstre de sa puissance) ; avant, la courbe était inversée. Le réglage fin par monstre reste au lot 3c.
  - Outils : chaque journal est relu avec la règle écrite dans son en-tête (`regles_journal`), et les anciennes fiches sont ramenées au nouveau barème (`au_present`).
  - Cible (`SolUI_Cible.lua`) : techniques du monstre (Enragé, Renforçant, Volcanique, Explosif), avec l'Enragé en rouge quand il joue ; buffs ennemis bordés d'ambre ; incantation en secondes. Le serveur envoie les techniques de la cible (SOLPUISSANCE, champs 5 et 6).
  - Joueur (`SolUI_Perso.lua`) : bords de l'écran rouges sous 35 % de vie, trait de recharge globale, récapitulatif de la mort (derniers coups, total des 10 s, plus gros coup). Erreurs rouges : liste blanche (se tourner, portée, ligne de vue, sacs pleins).
  - Mort suspecte (`v3_ame.cpp`) : un coup d'au moins 75 % de la vie, porté par un monstre qui n'est pas un boss et pas plus fort de 2 points, ne coûte pas d'âme. Un signalement part tout seul.
  - Reste de C5 pour plus tard : niveau 80 caché partout, fiche v3, puissance dans les infobulles d'objet.
  - Lot 3b proposé (« Audit du jeu\lot_3b_deblocages_proposition.md ») : techniques ouvertes par étapes du récit et emplacements ouverts peu à peu (7 techniques pour 5 emplacements en Durotar), à valider.
  - Idée de l'utilisateur, à prévoir avec le lot 4 : bonus de panoplie par paliers de pièces portées, comme sur retail, au moins pour les pièces de donjon.
- **Audit du jeu, lot 3b : techniques ouvertes par le récit** (02/11/2026, C2 du consensus ; table validée par l'utilisateur, « Audit du jeu\lot_3b_deblocages_proposition.md ») : construit, pas encore vérifié en jeu.
  - Les techniques ne s'ouvrent plus tous les 5 points de puissance mais à des étapes du récit (`v3_kit.cpp`) : Frappe du bouclier et Charge au départ ; Coup de tonnerre (Gornek, « Les crocs de la Vallée ») ; Heurt de bouclier (Zureetha Fargaze, « Les vils quasits », avant Yarrog : c'est elle qui rend la quête, pas Gornek) ; Cri de défi (Gar'Thok, « Un rapport à Orgnil ») ; Riposte du rempart (chef renforcé de Tranchecolline) ; Second souffle (Maître Gadrin, « Le crâne de Minshina »). Les 9 autres attendent les zones 2 à 7.
  - Emplacements : 3 au départ, 4 avec le Heurt de bouclier, 5 avec la Riposte ; 6, 7 et 8 plus tard. En Durotar, 7 techniques pour 5 emplacements. La table vaut pour tous les personnages, anciens compris.
  - Sorts (`techniques_v3.py`, migration 061) : bouclier exigé pour les 16 techniques, temps de recharge global de 0,75 s (choix de l'utilisateur ; le moteur ne le ramène pas à 1 s).
  - Rempart : la Frappe du bouclier y verse 5 % de la vie maximale au lieu de 8 %.
  - Interface : la fenêtre des techniques montre qui enseigne chaque technique verrouillée et le nombre d'emplacements ; le Heurt de bouclier s'illumine quand la cible incante un sort qu'on peut interrompre.
  - Dégâts d'arme normalisés : pas faits. Avec le bouclier exigé, les armes à deux mains (la Claymore en cuivre) ne portent plus les techniques.
  - Simulation (combats réels, Frappe à 5 %) : monstre seul 31 % de vie perdue en médiane (cible 15 à 30), vallée 17 %, groupes 74 % sans Cri de défi et 70 % avec. Les élites (3 combats) et les groupes restent trop durs : c'est le lot 3c.
- **Audit du jeu, lot 3c : recalibrage des monstres** (02/11/2026, C1 et C2 du consensus) : construit, pas encore vérifié en jeu.
  - Outil `calibre_3c.py`, migration 111 : 85 monstres de Durotar et du Gouffre réglés, chacun simulé contre la fiche de Sebiria la plus proche de sa puissance (à puissance égale au-delà de 9), avec la potion de départ et le Heurt de bouclier. On repart des réglages d'avant la migration 107 : les lanceurs de sorts retrouvent leurs dégâts, et leurs sorts ne baissent que si la mêlée au plus bas (×0,3) ne suffit pas (16 monstres, table solazeroth_v3_sorts_facteur). Seuls les monstres hors de leur cible bougent.
  - Cibles (vie perdue, une défaite comptant 100 %) : vallée 5 à 20 %, monstre seul 15 à 30 %, élites et chefs 30 à 60 % (et 12 à 15 s, par la vie). Les monstres du Gouffre hors boss visent la cible du monstre seul : ils vont par groupes.
  - Résultat en médiane : vallée de 2 à 10 % ; monstre seul de 42 à 26 % ; élites et chefs de 56 à 49 %, en 14 s au lieu de 18. Toutes les victoires restent à 100 % en médiane.
  - Chefs renforcés : un renfort au plus appelé en combat (Benedict en appelait 4, Kolkanis et Gazz'uz 2 : 0 % de victoires en simulation, et la mort de Test contre Benedict et ses 4 soldats, journal du 31/10/2026). Le Gazz'uz renforcé perd son marcheur du Vide, retiré partout dans la zone par la migration 106 mais pas des copies. Avec le renfort, ces combats durent 17 à 22 s.
  - Simulateur (`simulation_sorts.py`) : interruption par le Heurt de bouclier (puis silence 3 s), renforts appelés en combat, zones au sol (Pluie de feu) quittées au bout de 3 s, vie des monstres réglable.
  - Laissés tels quels ou hors cible : le Requin du sable (imbattable, danger du décor) ; la Matriarche des scorpides (élite de puissance 4), encore à 91 % de vie perdue et 73 % de victoires au plus bas des réglages.
  - `tests_equilibrage.py` relit les journaux d'avant avec la table solazeroth_v3_calibre_3c_origine : il passe.
- **Audit du jeu, lot 4a : économie du risque, première partie** (02/11/2026, C4 du consensus ; choix de l'utilisateur : défis plein tarif une fois par jour, transfert de rang à un rang de moins plus une Braise, panoplie du Gouffre seulement sur les pièces bleues à composant de donjon) : construit, pas encore vérifié en jeu. Lot 4 découpé en 4a (économie du risque), 4b (rangs et fabrication), 4c (choix, panoplie du Gouffre).
  - Défis répétables (`v3_annexes.cpp`, table solazeroth_v3_annexes_jour, migration 112) : plein tarif une fois par jour et par défi. Ensuite, le chrono et le record seulement, 1 Marque, et l'or de la quête est repris. La fenêtre des objectifs affiche la règle (famille Défis) et « payé aujourd'hui » sur le défi.
  - Éclats cadavériques selon l'écart de puissance (`v3_collection.cpp`), comme le contour de la cible : plein jusqu'à 2 points de moins, puis ×0,8, ×0,6, ×0,45, et ×0,25 pour un monstre gris (6 points de moins ou davantage). Avant, un sanglier de puissance 1 rapportait autant qu'un monstre de puissance 9.
  - Modes de zone calés sur la puissance de base la plus haute atteinte (`v3_combat.cpp`, table solazeroth_v3_puissance_max) : porter une maille de bas niveau ne garde plus les monstres faibles.
  - Fournisseur de matériaux (`v3_fournisseur.cpp`, Mogra à Razor Hill, migration 113, `outils\fournisseur_v3.py`) : minerai de cuivre, pierre brute, étoffe de lin, cuir léger et lanières, rangés dans la Collection, 20 de chaque par jour et par personnage ; jamais d'éclats, de Braises ni de pierres taillées. Choix de l'utilisateur, « hypothèse, puis mesure » : prix = 4 × l'or gagné pendant le temps de farm, à 3 po par heure de jeu (ordre revu par l'utilisateur, migration 115 : 10 pa le lin et les lanières, les plus faciles ; 20 pa le cuir léger ; 8 pa la pierre brute ; 40 pa le minerai de cuivre, le plus rare). À corriger quand les journaux donneront le vrai rythme. Les listes de courses de la fenêtre Équipement affichent le prix de Mogra pour ce qui manque.
  - Boucle de la semaine (`v3_semaine.cpp`, migration 114 ; semaine du lundi 0 h) : un affixe de la semaine, une technique de donjon à tour de rôle (Enragé, Renforçant, Volcanique, Explosif), toujours présente dans les donjons, même en difficulté 1 où elle ne change pas la puissance des monstres ; elle compte parmi les techniques des difficultés au-dessus. Un objectif de la semaine au compte, à tour de rôle : terminer un donjon, payer 3 défis plein tarif, abattre 5 élites ou rares de ta puissance. Récompense : 1 Braise du Gouffre, 1 pierre taillée et 60 points de rang d'aventurier. Fenêtre des objectifs : rubrique « Cette semaine ». La technique en difficulté 1 n'est pas encore passée en simulation : à mesurer en jeu.
- **Audit du jeu, lot 4b : rangs et fabrication** (02/11/2026, C6 du consensus ; choix de l'utilisateur : transfert à un rang de moins plus une Braise) : construit, pas encore vérifié en jeu. `v3_equipement.cpp`, migration 116, `outils\fabrication_v3.py`.
  - Fabrication limitée au secteur + 2 : une recette s'ouvre à la puissance de la pièce moins 2 (moins 4 avant ; `equipement_v3.py`, requise()). Les rudimentaires restent ouvertes dès le départ ; les pièces bleues du Gouffre restent à 10, elles demandent déjà une Braise.
  - Recettes hautes : la pièce la plus forte de chaque palier demande un composant de plus, ou son plan acheté une fois en or (au personnage, bouton « Plan » de la fiche) : bottes, gants et ceintures de puissance 8, 1 Malachite ou 2 po ; haubert, claymore et gilets de puissance 10, 1 Œil de tigre ou 5 po.
  - Transfert de rang (onglet Amélioration, bouton « Transférer » sur la pièce qui reçoit, avec aperçu avant confirmation) : la pièce de même emplacement au rang le plus haut (2 au moins) donne son rang moins un ; elle revient au rang 0. Coût : 1 Braise du Gouffre. Les pierres taillées des rangs 4 et 5 ne sont pas redemandées.
- **Audit du jeu, lot 4c : du choix** (02/11/2026, C6 du consensus ; choix de l'utilisateur, les recommandations) : construit, pas encore vérifié en jeu. Sorts : `outils\bonus_v3.py` et `cuisine_v3.py`, migration 117 ; chiffres : `outils\simulation_lot4c.py` (fiche la plus forte des journaux contre un fouette-queue réglé à 55 % de victoires ; repère « + 5 % de puissance » : + 31).
  - Variantes, choisies à la fabrication d'une pièce (fenêtre Équipement, trois boutons) et gardées à l'amélioration et au transfert : par pièce portée, Critique + 1 %, Hâte + 2 % ou Vol de vie 0,5 %. Sur 8 pièces : + 26, + 27 et + 26 (la Hâte à 1 % ne valait que + 18). Affichée sur la pièce, onglet Amélioration.
  - Panoplie du Gouffre (pièces bleues à Braise, rangs compris ; jamais les vertes de quête) : 2 pièces + 3 % de dégâts (+ 17), 4 pièces − 5 % de dégâts subis (+ 32 cumulés), 6 pièces 3 % de vol de vie (+ 40 cumulés).
  - Plats : la caractéristique, plus un bonus propre, plus fort pour l'ingrédient le plus rare à Durotar : Viande de sanglier rôtie + 3 % de vie (+ 15), Surprise du scorpide + 8 % d'armure (+ 14), Steak de crocilisque + 3 % de critique (+ 16), Maquereau ombré + 3 % de dégâts (+ 17), Thon arc-en-ciel + 12 % de vitesse d'attaque (+ 24).
  - Débouchés du surplus (catégorie Consommables de la fenêtre Équipement, plus en vente chez les marchands) : Pierre à aiguiser brute (2 Pierres brutes) + 3 % de dégâts physiques (+ 17), Renfort d'armure léger (2 Cuirs légers, 2 Lanières) + 8 % d'armure (+ 14), pendant 1 h.
  - Cumuls (simulation_lot4c.py, demande de l'utilisateur) : un seul repas à la fois, mais il s'ajoute aux consommables, à la panoplie et aux variantes. Repas et consommables valent environ + 5 % de puissance ; panoplie 6, repas et consommables, davantage que + 10 % (un monstre gagné 4 fois sur 100 l'est 82 à 91 fois, 95 à 98 avec les variantes). **Décision de l'utilisateur : gardé tel quel** — les pièces bleues aident à vivre la difficulté qui monte dans la zone ; l'équipement complet et les bonus préparent la zone suivante et les difficultés plus dures du donjon et de l'extérieur (les modes et les difficultés se calent sur la puissance de base, sans ces bonus). Conditions : le contenu plus dur doit être accessible (lot 5, C7) et la zone suivante réglée sur une référence écrite (quelques pièces bleues et un repas, sans la panoplie complète).
- **Audit du jeu, lot 5 : la progression** (02/11/2026, C7 du consensus ; D1 tranché par l'utilisateur : « en réussissant la précédente ») : construit, pas encore vérifié en jeu. `v3_aventurier.cpp`, `outils\montures_v3.py`, migration 118 ; garde-fou : `outils\test_paliers_v3.py`.
  - Difficultés des donjons : terminer un donjon (son dernier boss) en difficulté N ouvre la N + 1 de ce donjon, pour le compte ; la difficulté 2 s'ouvre au premier passage. Le rang ne les ouvre plus : ses paliers 12, 20, 30 et 38 donnent 50, 100, 150 et 200 Marques du voyageur.
  - Nouvelles sources de points, une fois par compte : maîtrise d'une zone en mode difficile (150) et en cauchemar (300), soit 150 monstres de la zone tués dans ce mode ; 14 objectifs d'artisan (15 chacun : première pièce verte de puissance 7, première bleue, rangs 3 et 5, transfert, plan, enchantement, pierre taillée, consommable, chacun des 5 plats).
  - Garde-fou : la monte (palier 10) passe de 2 000 à 1 950 points. Le test lit la base et les points du serveur : Durotar à 100 % (1 848) et le Gouffre en difficulté 1 (168) font 2 016 points, marge + 66 ; les modes de zone (paliers 5 et 9) restent atteignables. Artisan et semaine s'ajoutent.
  - Registre (Aventure › Registre) : points et objectifs faits par source, difficulté réussie par donjon, maîtrise des modes par zone. Boutique des montures : compteur (possédées / 177) et filtre Toutes, Ouvertes, Possédées, À acheter.
- **Audit du jeu, lot 6a : l'accueil** (02/11/2026, C9 du consensus ; choix de l'utilisateur : création grisée, répliques des PNJ, et la fenêtre de paroles qu'il a décrite) : construit, pas encore vérifié en jeu. Le lot 6 suit en 6b (monde, C8) et 6c (interface, C10).
  - Création : seuls l'orc et le troll guerriers. Les autres races et classes restent visibles, grisées, « pas encore prêt » au survol ; un tirage qui n'est pas prêt devient un orc guerrier. Le CharacterCreate.lua du client est repris de ses archives et modifié par `outils\interface_v3.py` ; le serveur refuse aussi (`scripts\configurer.ps1` : CharacterCreating.Disabled.RaceMask 1661, ClassMask 1534).
  - Fenêtre de paroles (`SolUI_Paroles.lua`, demande de l'utilisateur : « comme sur retail quand un PNJ parle ») : portrait du PNJ, son nom, une réplique, « Suivant » (« Terminer » à la dernière) et « Fermer » ; hors combat, une leçon à la fois, une fois par compte.
  - La vallée enseigne : 9 leçons aux moments clés, à la place des fenêtres « À savoir » qu'elles couvrent. Kaltunk à l'arrivée (puissance, carnets, zone) et aux premières Marques ; Gornek après le premier combat (règles, Rempart, boutons de potion, feu et pierre de foyer) et aux premiers éclats ; Zureetha Mireloin à la première vie basse ; le contremaître Thazz'ril à la première récolte et près d'une forge ; Galgar près d'un feu (cuisine) ; Hana'zua à la première mort.
  - Survie plus tôt : la leçon et les fenêtres de vie, feu et potion viennent dès 80 % de vie (au lieu de 50 %), et le premier combat présente la potion.
  - Lexique : thème Combat (Règles du combat, Rempart, Techniques), pages Cuisine, Pierre de foyer, Montures et « Mots du jeu » (puissance et puissance d'attaque, rang et palier, défi et épreuve, les deux éclats, le Repos au coin du feu). Faits remis à jour : puissance requise − 2, difficultés de donjon, sources du rang, Marques des paliers.
  - README et LISEZMOI : section « Premiers pas » ; Tranchecolline et « défis » à la place de Razor Hill et d'« épreuves ».
- **Audit du jeu, lot 6b : le monde** (02/11/2026, C8 du consensus ; choix de l'utilisateur : quêtes du même lieu données ensemble, répliques des chefs et trois scènes, mystère par des rares secrets, carte des reliques à 8 reliques) : construit, pas encore vérifié en jeu.
  - Allers-retours : D05 et D07 se prennent avec D04 (le Convent), D12 avec D09 (Tiragarde), D17 avec D16 (la Combe des Kolkar), D20 avec D18 et D19 (îles de l'Écho) ; les introductions de D05 et D20 suivent (migration 119).
  - Chefs : une réplique en bulle (cri) à l'engagement, une fois par apparition, jamais de fenêtre en combat (Yarrog, Benedict, Kolkanis, Zalazane, Féplouf, Gazz'uz et les quatre boss du Gouffre). Trois scènes hors combat dans la fenêtre de paroles, au rendu de D07 (Yarrog), D12 (Benedict) et D30 (Taragaman) (`v3_paroles.cpp`, `SolUI_Paroles.lua`).
  - Textes (migration 120, `outils\textes_6b.py`) : un récit par relique ; la voix du PNJ séparée de la liste grise des récompenses ; accords au genre du joueur ($G, et dans la fenêtre de paroles) ; Ruga Brise-cendre a sa propre apparence ; 59 PNJ sans quête de Durotar, d'Orgrimmar et du Gouffre perdent leur faux indicateur.
  - Carte des reliques : vendue après 8 reliques trouvées (avant : achetée vers 25-30 % de la zone).
  - Rares secrets (demande de l'utilisateur ; `outils\rares_secrets_v3.py`, migration 121, `v3_rares_secrets.cpp`) : Zal'mara la Renégate (îles de l'Écho), le Gardien cendré (nord-est) et le capitaine Hurlevague (côte est), puissance 15, ni prime ni carte. Réglés par simulation à environ 50 % de victoires pour un personnage tout en bleu du Gouffre au rang 0 avec le Repos, la panoplie 6, le thon, la pierre à aiguiser, le nécessaire d'armure et 8 pièces Critique (0 % sans ces bonus). Zal'mara donne le Raptor razzashi rapide (retiré de la boutique, 60 %, au compte), le Gardien la Braise du Gardien (bijou) et Hurlevague la Perle de Hurlevague (bague) : bleus, puissance 18, sans condition, uniques, sans rangs. Fenêtre des objectifs : « Rares secrets (n / 3) », seuls les vaincus nommés. Leur cadre de cible est à part (demande de l'utilisateur) : liseré violet, étiquette « SECRET », nom violet.
  - Hors des références : ni la simulation de Durotar ni le départ de la zone 2 ne comptent ce bijou et cette bague (`rares_secrets_v3.EXCLUS`).
- **Audit du jeu, lot 6c : l'interface** (02/11/2026, C10 du consensus ; choix de l'utilisateur : notre propre fiche, Spécialisation et /sol fondus dans les carnets, listes défilantes partout) : construit, pas encore vérifié en jeu.
  - Un seul style, le graphite : plus de fenêtre dorée de Blizzard dans les carnets.
  - Personnage › Fiche (`SolUI_Fiche.lua`) remplace la fiche de Blizzard : modèle à tourner, 19 pièces (glisser-déposer, Maj + clic pour un lien) avec leur rang (« R2 »), puissance et son détail (niveau d'objet moyen, apport des rangs), âme, et les chiffres jusque-là invisibles : réduction des coups d'un monstre de sa puissance par l'armure, critique, vol de vie des variantes. Le niveau n'y paraît plus.
  - Techniques › Spécialisation (`SolUI_Options.lua`) remplace l'addon SolAzerothKit (rangé dans `addons-v2`, retiré du jeu par le lanceur) et son doublon d'équipement des techniques. Elle s'ouvre seule pour un guerrier sans spécialisation ; « /kit » y mène.
  - Carnet Réglages (sans touche) : Interface (disposition, taille des blocs, mini-carte), Plaques de nom (l'addon SolAzerothPlaques n'a plus de fenêtre ; « Afficher le niveau » devient « Afficher la puissance du monstre ») et Sauvegarde. « /sol » et « /plaques » y mènent. L'addon SolAzeroth ne garde que les réglages du compte et les noms d'objets ; la page Monde de /sol (v2) disparaît.
  - Listes défilantes partagées (`S.Liste`, molette, « 1–8 sur 14 ») : onglets des carnets (le 8e d'Aventure était invisible), lexique, recettes, amélioration, rang d'aventurier, montures, registre, collection, téléportation.
  - Le Lexique est dans les Raccourcis ; le Lexique et l'annonce de zone de repos renvoient les modes de zone à Aventure › Zone (et non plus aux passifs extérieurs).
- **Audit du jeu, lot 7 : préparer la zone 2** (02/11/2026, « avant la zone 2 » du consensus ; choix de l'utilisateur : gabarit + vérificateur, simulation sur Durotar et deux zones extrapolées, estimation + compteur des filons ; les Tarides vont de 11 à 25) : construit ; le compteur n'est pas encore vérifié en jeu.
  - **Gabarit de zone** (`outils\gabarit_zone.py`) : une zone est un dictionnaire (plage et secteurs, parts du pourcentage, annexes par famille et barème, plantes et filons, plats, rangs du camp et de la potion, emplacements et techniques par spécialisation, donjon, économie). Le vérificateur relit Durotar dans la base et le code (parts, annexes, barème, plats, camp, récolte, techniques de `v3_kit.cpp`) : conforme. Il vérifie aussi l'emboîtement des zones (plages contiguës, secteurs de 0 à 100 %, deux rangs de camp et de potion qui suivent, emplacements croissants jusqu'à 8, aucune technique rouverte, filons et plantes) et liste à part ce qui reste à remplir. Les Tarides (11-25) et une zone 3 fictive (26-40) sont extrapolées de Durotar ; il leur manque les plats et le donjon. Les techniques et emplacements sont décrits par spécialisation : ce sont les classes qui s'adaptent au monde (demande de l'utilisateur).
  - **Simulation sur trois zones** (`outils\simulation_zones.py`) : le revenu suit. Les éclats des monstres et le coût des rangs montent avec le même facteur (1 + (P − 12) / 12), donc le rang moyen en fin de zone reste à 2,5 à 3,6 dans les trois zones (26, 39 et 39 h de jeu). Le frein n'est pas l'éclat mais les pierres des rangs 4 et 5 : sans filons, les éclats s'entassent (1 232 en réserve en fin des Tarides avec le transfert de rang). Le coût des gemmes, donc le rythme de minage, est la vraie variable des zones suivantes.
  - **Filons par heure** : estimation d'après les points d'apparition, les pools et les réapparitions (`outils\filons_heure.py`) : Durotar, 53 filons présents à la fois, environ 87 par heure à pied et 124 à monture pour qui ne fait que miner (plafond ; l'audit supposait 30 à 45) ; les Tarides, 166 présents, environ 94 et 134. Mesure réelle en jeu : chaque filon ouvert est noté avec le temps de jeu (`v3_filons.cpp`, migration 122), et `.filons` donne le total, la dernière heure de jeu et le rythme pendant le minage.
  - **Suite demandée par l'utilisateur** : dès que Durotar sera jugé vraiment bon, le démoniste, en pensant à l'artisanat et aux objets qui lui sont accessibles.
- **Démoniste : proposition validée** (02/11/2026, « Démoniste — proposition.md »), à construire en quatre lots : D1 fondations (création, spécialisations de plusieurs classes dans `v3_kit.cpp`, anciens sorts retirés), D2 kit Affliction et invocations temporaires, D3 équipement en tissu, D4 simulation, calibrage et interface.
  - **Règles de l'utilisateur** : ce sont les classes qui s'adaptent au monde, sauf exception ; aucun familier permanent, pour toutes les classes concernées, seulement des invocations temporaires à la puissance du joueur ; le guerrier ne porte que de la maille, puis de la plaque à partir de la puissance 40 (plus tard).
  - **Choix** : Affliction en premier (passif Moisson : une part des dégâts sur la durée revient en vie) ; les récompenses de maille deviennent leur version en tissu pour un démoniste (pièces et recettes de tissu à créer) ; orc et troll.
  - Les sorts du démoniste infligent un pourcentage des dégâts d'une arme normalisée, comme les techniques du guerrier : l'équipement actuel (puissance d'attaque et endurance) suffit, sans nouvelle caractéristique.
- **Démoniste, lot D1 : fondations** (02/11/2026) : construit ; pas encore vérifié en jeu.
  - **Création** : le démoniste orc et le démoniste troll sont ouverts (`ClassMask` 1278 dans `configurer.ps1` et la configuration du serveur, classe dégrisée à l'écran de création).
  - **Spécialisations de plusieurs classes** (`v3_kit.cpp`) : une table donne, pour chaque spécialisation, sa classe, sa clé (`.kit spe tank`, `.kit spe affliction`), son passif, ses techniques dans l'ordre du récit et ses armes de départ. Le démoniste Affliction y entre sans technique ni passif (lot D2) ; il reçoit la compétence Dagues et une Dague usée.
  - Ses anciens sorts (famille du démoniste : Trait de l'ombre, invocations de Blizzard…) sont retirés à la création et à chaque application du kit, comme ceux du guerrier ; tout familier est renvoyé (aucun familier permanent).
  - **Caractéristique principale par spécialisation** (choix de l'utilisateur, 02/11/2026 : le plus simple, sans dette technique, l'Agilité viendra plus tard) : Force pour le guerrier tank, Intelligence pour le démoniste Affliction. Elle choisit le repas et le repos du feu, et donne la puissance d'attaque par **une seule règle pour toutes les classes** (`v3_niveau.cpp`) : 2 par point, au lieu des formules de Blizzard par classe. Le guerrier ne change pas en mêlée ; les sorts du démoniste suivent son Intelligence.
  - Les caractéristiques gardent leurs autres effets du jeu (choix de l'utilisateur) : Force, blocage ; Agilité, critique, esquive et armure ; Intelligence, critique des sorts. Ils restent petits, car elles ne viennent que de la base et des repas ; à compter dans les simulations des classes suivantes.
  - **Interface** : la fenêtre Spécialisation montre la spécialisation de la classe (« Démoniste — Affliction ») ; la Fiche nomme la spécialisation ; la fenêtre des techniques équipées vaut pour toute spécialisation.
- **Démoniste, lot D2 : kit Affliction** (02/11/2026) : construit (`outils\demoniste_v3.py`, migration 123, `v3_demoniste.cpp`, ordre dans `v3_kit.cpp`) ; pas encore vérifié en jeu, coefficients à calibrer au lot D4.
  - **Règles de l'utilisateur, pour cette classe et les suivantes** : aucun dégât d'arme, l'arme ne compte que par ses caractéristiques. Les sorts font une part de la puissance d'attaque (table `spell_bonus_data` du moteur, base 0), avec un sort faible lançable en boucle. Toute incantation et toute canalisation se fait en mouvement (drapeaux retirés dans le Spell.dbc du serveur et du client, par `demoniste_v3.sort()`, que les classes suivantes reprendront).
  - Sorts magiques d'Ombre (critique des sorts, sans armure), hors de la famille du démoniste, temps de recharge global de 0,75 s.
  - **Passif Moisson** : 20 % des dégâts des sorts sur la durée reviennent en vie (losange du passif : une faucille).
  - **Départ** : Trait de l'ombre (25 % de la PA, 1,5 s d'incantation, sans recharge), Corruption (100 % en 15 s).
  - **Durotar**, aux mêmes étapes que le guerrier, maîtres Nartok (Vallée) puis Dhugru Gorelust (Razor Hill) :
    - Diablotin (Les crocs de la Vallée) : 15 s, recharge 45 s, un trait de feu de 15 % de la PA toutes les 2 s ;
    - Drain de vie (Les vils quasits, un emplacement) : canalisé 5 s, 25 % de la PA par seconde, rendus en vie ;
    - Peur (Un rapport à Orgnil) : 6 s, recharge 20 s ;
    - Marcheur du Vide (chef renforcé de Tranchecolline, un emplacement) : 10 s, recharge 60 s ; il provoque les ennemis à 15 m et encaisse (vie et armure du démoniste) ;
    - Malédiction d'agonie (Le crâne de Minshina) : 144 % de la PA en 24 s, par tiers à 50, 100 et 150 %.
    - L'Agonie passe en dernier, à la place que le brouillon donnait au Marcheur : les cinq étapes du guerrier sont reprises telles quelles.
  - **Panel des zones suivantes** : Malédiction de faiblesse et Siphon de vie (zone 2), Voile mortel et Graine de corruption (zone 3), Hurlement de terreur (zone 4), Drain d'âme et Pierre de soins (zone 5), Chasseur corrompu (zone 6, interrompt et réduit au silence, puis mord), Affliction instable (zone 7, +50 % sur une cible qui porte Corruption et Agonie).
  - **Invocations** (aucun familier permanent) : créatures 910050 à 910052, à vie tirée de celle du démoniste. Leurs attaques sont des sorts lancés au nom du démoniste : sa puissance d'attaque, la menace sur lui. Elles repartent à la fin de leur durée, ou si le démoniste meurt ou s'éloigne de plus de 60 m.
  - **Interface** : losange du passif par spécialisation, texte de la carte de spécialisation. Le vérificateur de zone (`gabarit_zone.py`) lit maintenant les techniques par spécialisation (conforme).
  - **Aucune attaque automatique** (choix de l'utilisateur : que des sorts) : le minuteur d'attaque du démoniste est tenu toujours chargé et sa posture d'attaque coupée (`v3_demoniste.cpp`).
- **Démoniste, lot D3 : équipement en tissu** (02/11/2026) : construit (`outils\tissu_v3.py`, migration 124, `v3_armures.cpp`) ; pas encore vérifié en jeu.
  - **Armures par classe** (règle de l'utilisateur) : le guerrier ne porte que de la maille, le démoniste que du tissu ; les capes vont à tous. La plaque du guerrier à partir de la puissance 40 viendra avec ces zones. Aucun personnage existant ne portait une pièce hors de son type.
  - **Versions en tissu** des pièces que donne le monde sans qu'on les choisisse (récompenses de quête 910101-910119, pièces d'annexes 910121-910132) : 21 pièces de maille deviennent 21 pièces en tissu (910401 et suivantes), même nom, même puissance, même puissance d'attaque et même Endurance ; seule l'armure est celle du tissu (12 % de réduction au lieu de 40 %). Les 3 boucliers deviennent des orbes tenus en main gauche (Orbe de Margoz, de la garde de Tiragarde, de cendre), sans armure. Mêmes rangs 1 à 5.
  - **Échange** : une pièce reçue dans le mauvais type (quête, butin, courrier) devient sa version au rang égal, dans les deux sens, à la mise à jour suivante du joueur, avec un message. La fenêtre de récompense de quête montre encore la pièce de maille.
  - **Fabrication** : inchangée ; chacun fabrique son type. Les recettes de tissu de Durotar et du Gouffre couvrent déjà les emplacements de la maille ; il n'y a pas d'orbe à fabriquer.
  - **Armes** : l'arme ne comptant que par ses caractéristiques, le démoniste apprend toutes les armes à une main (épées, masses, haches, dagues) et les bâtons ; ses compétences sont rendues à chaque application du kit.

## 5. Questions pour les prochaines séries

1. **Réputation des donjons** : réglée et construite le 01/11/2026 (voir 2.5). Reste à calibrer le Gouffre de Ragefeu pour la v3.
2. **Rang d'aventurier** : réglé et construit le 01/11/2026 (voir 2.7). Reste à relever le plafond de 20 000 avec les zones suivantes, et à parler des montures volantes pour l'Outreterre et le Norfendre.
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
