# Guide d'essai — voleur Assassinat (lots V1 à V5)

À suivre en jeu après la livraison du 02/11/2026. Chaque ligne dit quoi faire et ce qu'on doit voir. Si quelque chose
ne va pas : touche « ! » (signalement), en décrivant la ligne du guide.

Commandes utiles :
- `.kit spe assassinat` : choisit la spécialisation (`v3_kit.cpp`) ;
- `.kit` : redonne l'état du kit ;
- `.additem <objet> <nombre>` : commande MJ d'AzerothCore.

## 1. Création et choix de spécialisation

- [ ] Créer un orc voleur : la page des spécialisations s'ouvre seule. La carte « Voleur — Assassinat » parle des Toxines (50 %, 5 cumuls, 8 % par cumul), d'Envenimer et des deux dagues.
- [ ] Après le choix : message « Les Toxines et tes premières techniques sont prêts ». Une dague dans chaque main.
- [ ] Losange du passif à gauche des techniques : une goutte, en rouge clair ; au survol, l'infobulle des Toxines.

## 2. Techniques et règles

- [ ] Estropier et Envenimer au départ. Sans deux dagues, les techniques sont refusées.
- [ ] Toxines : environ un coup sur deux pose un cumul de Poison mortel sur la cible ; le cadre de la cible affiche « ×2 », « ×3 »… jusqu'à 5.
- [ ] Le journal de combat montre les dégâts du monstre baisser avec les cumuls (−8 % par cumul).
- [ ] Envenimer refusé sans cumul ; il frappe d'autant plus fort qu'il y a de cumuls, et les retire. Son bouton s'éclaire à 5 cumuls.
- [ ] Coup de pied (Rwag) : interrompt et réduit au silence 3 s ; son bouton s'éclaire quand la cible incante.
- [ ] Évasion : dégâts subis réduits de moitié pendant 6 s.
- [ ] Camouflage (Kaplak) : hors combat seulement. Le premier coup qui révèle est un Garrot (saignement et silence). L'annuler soi-même ne donne rien.
- [ ] Coup bas : 4 s d'étourdissement.
- [ ] Éventail de couteaux (Kaplak, après Le crâne de Minshina) : frappe tous les ennemis à 8 m et pose 2 cumuls de Poison mortel sur chacun (« ×2 » sur leurs cadres). La Rupture n'est plus en Durotar (zone 4).

## 3. Équipement

- [ ] Récompense de quête en maille : la fenêtre de quête montre la version en cuir, et on reçoit celle-là.
- [ ] Bouclier ou arme de quête : on reçoit une dague (même puissance, même rang).
- [ ] Récompenses d'annexes (or de la vallée, armes) : directement la version du voleur.
- [ ] Seules les dagues se portent : épées, masses, haches, bâtons, boucliers et orbes sont refusés (« compétence requise »).

## 4. Combats de référence

Les comparer aux simulations (`outils\simulation_voleur.py`, document de conception, lot V4) :
- [ ] Fin de vallée : un monstre de sa puissance, gagné ; plus puissant de 3, souvent perdu (le guerrier le gagne).
- [ ] Fin de Durotar : un monstre de sa puissance, 7 à 9 s, 60 à 70 % de vie restante.
- [ ] Deux monstres à la fois en fin de Durotar : difficile, à peu près une chance sur deux (simulation : 49 %, guerrier 100 %). Ouvrir par l'Éventail.
- [ ] Gouffre de Ragefeu, difficultés 1 à 5 : gagné en bleu.
- [ ] Rares secrets tout en bleu : nettement plus faciles qu'au guerrier (simulation : 62 à 70 % sans bonus, contre 0 %).
