# Guide d'essai — démoniste (lots D1 à D5)

À suivre en jeu après la livraison du 02/11/2026. Chaque ligne dit quoi faire et ce qu'on doit voir. Si quelque chose
ne va pas : touche « ! » (signalement), en décrivant la ligne du guide.

Commandes utiles :
- `.kit spe affliction` : choisit la spécialisation (`v3_kit.cpp`) ;
- `.kit` : redonne l'état du kit ;
- `.additem <objet> <nombre>` : commande MJ d'AzerothCore ; les composants vont dans la Collection.

Objets utiles :

| Objet | Entrée |
|---|---|
| Orbes de joaillerie | 910237 (brute), 910236, 910272 (Gouffre) |
| Malachite brute, Malachite taillée, Œil de tigre taillé | 774, 910180, 910181 |
| Braise du Gouffre, Éclat cadavérique | 910190, 910120 |
| Minerai de cuivre, Feuillargent | 2770, 765 |
| Poussière étrange, Essence de magie inférieure | 10940, 10938 |
| Huile de sorcier mineure | 20744 |

## 1. Création et choix de spécialisation

- [ ] Créer un orc démoniste : la page des spécialisations s'ouvre seule. La carte « Démoniste — Affliction » parle de la Moisson, de la Transe, de l'incantation à l'arrêt et de l'arme.
- [ ] Après le choix : message « La Moisson et tes premières techniques sont prêts ». Une dague de départ est en main, et aucune attaque automatique ne part.
- [ ] Pas d'arc de Rempart autour du personnage ; la puissance prend sa place.

## 2. Sorts et règles

- [ ] Trait de l'ombre : interrompu si l'on bouge. Corruption et les sorts instantanés se lancent en courant.
- [ ] Un coup reçu pendant une incantation la retarde, deux fois au plus. Une canalisation (Drain de vie) est écourtée.
- [ ] Transe de l'ombre : pendant Corruption ou Agonie, une aura apparaît de temps en temps. Le bouton du Trait s'allume alors, le Trait part sans incantation et l'aura disparaît.
- [ ] Peur : le monstre fuit, puis la peur se brise quand il a perdu environ 15 % de sa vie.
- [ ] Diablotin (lance des Traits de feu) et Marcheur du Vide (à Tranchecolline : il attire les coups 10 s).
- [ ] Moisson : la vie remonte pendant que les maléfices font des dégâts.
- [ ] Infobulles des sorts : les pourcentages correspondent aux dégâts vus dans le journal de combat.

## 3. Équipement

- [ ] Récompense de quête en maille ou bouclier : la fenêtre de quête montre déjà la version tissu ou l'orbe, et on reçoit bien celle-là, sans message.
- [ ] Une meilleure arme augmente la puissance d'attaque (fiche du personnage), même si elle ne frappe pas.
- [ ] Toutes les armes à une main se portent : dagues, épées, masses, haches, bâtons. Les armes à deux mains ne se portent pas.
- [ ] Artisanat (P), Fabrication, « Armes et boucliers » : les trois orbes sont rangés avec les boucliers. Ils se fabriquent sans forge, avec les gemmes de la Collection.
- [ ] L'Orbe ardent du Gouffre compte dans la panoplie du Gouffre : avec 2 pièces bleues, l'aura « Panoplie du Gouffre (2) ».
- [ ] Les orbes s'améliorent en rang (+1 à +5) comme les autres pièces.

## 4. Enchantements et consommables

- [ ] Enchanter des brassards et un orbe avec « Intelligence mineure » (+1 Intelligence) : la puissance d'attaque monte de 2.
- [ ] Enchanter l'arme avec « Frappe mineure » : la puissance d'attaque monte aussi.
- [ ] Fabriquer l'Huile de sorcier mineure (2 Feuillargents, catégorie Consommables) : aura « Huile de sorcier », dégâts magiques +3 % pendant 1 h.
- [ ] Thon arc-en-ciel : l'aura « Bien nourri » donne Intelligence et vitesse d'incantation +12 %. Le Trait doit s'incanter un peu plus vite.
- [ ] Repos au coin du feu : l'Intelligence monte, pas la Force.

## 5. Passifs

- [ ] Contre-attaque (passif de donjon) : quand on est frappé, un Trait de l'ombre part parfois tout seul, sans consommer la Transe.
- [ ] Les passifs de dégâts (Bourreau, Premier sang, Brise-chef) s'appliquent aux sorts.
- [ ] Pour info : en simulation, les passifs de survie et Main vive rapportent peu au démoniste. Préférer les passifs de dégâts.

## 6. Textes adaptés à la classe

- [ ] Gornek, après le premier combat : il parle des sorts, de l'incantation à l'arrêt et de la Moisson, ni du bouclier ni du Rempart.
- [ ] Zureetha : « Tu saignes, jeune démoniste. »
- [ ] Prime de Zalaphil : « L'équipement de la garde est à toi », et l'orbe en récompense.
- [ ] Reliques de la Lame ardente : la récompense annoncée est « un bouclier ou un orbe ».

## 7. Combats de référence

Les comparer aux simulations (document de conception, lots D4 et D5) :
- [ ] Fin de vallée : un monstre de sa puissance ; deux Vils quasits (simulation : 69 % de victoires).
- [ ] Fin de Durotar : un monstre de sa puissance, 12 à 15 s, 75 à 88 % de vie restante.
- [ ] Gouffre de Ragefeu, difficultés 1 à 5.
- [ ] Rares secrets tout en bleu : Zal'mara et le Gardien cendré plus faciles qu'au guerrier, Hurlevague (qui charge) plus dur.
- [ ] Le journal de combat (`journaux\combat`) donne l'Intelligence du joueur.
