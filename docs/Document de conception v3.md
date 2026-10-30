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
- **Malus hors de sa puissance** : dans une zone trop forte pour lui, le joueur subit un malus de dégâts proportionnel à son manque de puissance.
  - Il réduit seulement les dégâts que le joueur inflige ; les monstres restent normaux (série 5).
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
