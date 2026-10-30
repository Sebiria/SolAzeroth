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

**Vérifié le 30/10/2026 : l'interface peut être entièrement remplacée.** Le client charge des fichiers d'interface Blizzard (FrameXML, GlueXML) modifiés dans notre patch, et ce code garde les droits de Blizzard en combat. Un test a pu cacher le cadre protégé du portrait en plein combat. L'interface v3 se fait donc directement dans ces fichiers, et non en addons.

## 2. Décisions de fond (séries de questions du 30/10/2026)

### 2.1 Niveau et puissance
- **Le niveau est caché et fixe en coulisses**, par exemple tout le monde au niveau 80, monstres compris. Le joueur ne voit jamais de niveau.
- **La progression passe par la puissance**, qui vient surtout de l'équipement (niveau d'objet et rang d'amélioration), avec une petite part tirée des autres systèmes de progression.

### 2.2 Monde et zones
- **Monde ouvert**, chaque zone ayant une puissance conseillée.
- **Malus hors de sa puissance** : dans une zone trop forte pour lui, le joueur subit un malus de dégâts proportionnel à son manque de puissance.
- **Une zone se suffit à elle-même** : ses quêtes, ses primes et ses contrats sont en accès libre, avec des défis difficiles et de belles récompenses. Les quêtes qui envoient dans une autre zone sont écartées pour l'instant.
- **Nettoyer la zone prépare son donjon** :
  - à 60 % (quêtes, primes, contrats…), on l'aborde correctement, « pas comme un touriste » ;
  - à 100 %, on l'aborde sereinement.

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

## 3. Première zone : Durotar

- **But de la première zone** : nettoyer tout Durotar, Vallée des épreuves comprise. Le Gouffre de Ragefeu en est l'aboutissement.
- **Personnage de test** : guerrier, spécialisation tank.
- **Rôle du test** : vérifier que le jeu est amusant et exigeant avant d'étendre la refonte au reste d'Azeroth. Il construit une première tranche de jeu, mais le contenu de Durotar visé reste toute la zone.

## 4. Questions pour les prochaines séries

1. **Réputation des donjons** : la liste des techniques actives et passives d'entrée, et les paliers d'emplacements.
2. **Rang d'aventurier** :
   - combien de paliers ;
   - ce qu'apporte chaque action ;
   - les difficultés ouvertes par palier.
3. **Puissance** :
   - la formule exacte ;
   - la façon de l'afficher ;
   - la courbe du malus de dégâts hors zone.
4. **Kit du guerrier tank** :
   - le passif d'identité ;
   - le panel de techniques ;
   - les 8 de départ ;
   - la façon de tenir les monstres (menace) sans rage.
5. **Durotar** :
   - ce qui compte dans le pourcentage de nettoyage ;
   - les primes et contrats propres à la zone ;
   - les défis difficiles ;
   - les récompenses.
6. **Interface v3** : quels cadres de Blizzard on garde, on refait ou on supprime, avec une maquette.
7. **Monstres** :
   - leurs dégâts et leur vie à niveau fixe ;
   - les techniques des monstres et des boss face à un joueur sans ressource.
8. **Remarques de l'utilisateur à revoir** une fois la v3 posée :
   - la mascotte ramasseuse avec son arbre (n°6) ;
   - l'objet de buffs groupés (n°7) ;
   - le bouton de téléportation en fin de donjon (n°9).

   Les bugs de la v2 (n°1 à 4, 8 et 12) ne valent la peine d'être corrigés que si l'on continue de jouer à la v2 en attendant.
