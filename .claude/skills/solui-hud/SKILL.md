---
name: solui-hud
description: Conventions de l'interface v3 de Sol'Azeroth (HUD, cadres et fenêtres SolUI en Lua pour le client WoW 3.3.5a). À charger avant de maquetter, créer ou modifier un élément d'interface du jeu (interface-v3/FrameXML/SolUI_*.lua, textures de outils/interface_v3.py), et avec frontend-design pour toute maquette de HUD.
---

# Interface SolUI (HUD de Sol'Azeroth)

L'interface v3 remplace celle de Blizzard dans les fichiers du jeu. Son identité est **déjà choisie et validée**
(écran de combat « 6 · Synthèse », 31/10/2026, document v3 § 1 et F4). Ce skill dit comment la prolonger sans la
casser. Avec `frontend-design`, il l'emporte : le brief, ici, est cette identité.

## 1. Identité visuelle (ne pas la refaire sans demande de l'utilisateur)

- **Épurée** : peu d'éléments à l'écran. Restent bien visibles le cadre de la cible et les buffs et débuffs.
- **Fond graphite translucide**, filet d'un pixel, **police Inter seule**, **un seul ambre** comme accent (Rempart,
  état choisi, mise en avant). Le vert, le rouge et le bleu portent un sens (réussite, danger ou malus, information),
  jamais de la décoration.
- `frontend-design` range « fond sombre et un seul accent vif » parmi les choix par défaut à éviter : ici c'est un
  choix validé, on le garde. Sa liberté sert à l'intérieur de ce cadre (hiérarchie, mise en page, mouvement, textes).
- **Style propre à Sol'Azeroth** : on ne reproduit pas l'apparence de l'interface de Blizzard ni d'un autre jeu
  (textures, mise en page, ornements). Les icônes d'objets et de sorts du client restent utilisées.
- **Pas de niveau visible** : on montre la puissance. Au plus 8 techniques à l'écran (deux barres de 4) et le camp.

## 2. Où est le code

- `interface-v3/FrameXML/SolUI_*.lua` : copiés dans `Interface\FrameXML` et ajoutés au `FrameXML.toc` du client par
  `outils/interface_v3.py`, puis mis dans le patch par `construire_patch.py`. Ce code garde les droits de Blizzard en
  combat (pas d'addon).
- **Nouveau fichier** : l'ajouter à la liste `CODE` de `outils/interface_v3.py`, à sa place dans l'ordre de
  chargement (après `SolUI_Base.lua` et ce dont il dépend).
- `SolUI_Cartes.lua` est **généré** par `interface_v3.py` (liste `GENERES`) : ne pas l'écrire à la main.
- Textures : TGA 32 bits tracées par `outils/interface_v3.py` (Pillow), servies sous
  `Interface\SolAzeroth\Textures\`. Dimensions en puissances de 2. Pas de fichier Blizzard (`.blp`, `.mpq`) dans le
  dépôt.

## 3. Briques de `SolUI_Base.lua` (toujours les réutiliser)

| Besoin | Brique |
|---|---|
| Couleur | `S.Couleur(nom, alpha)` sur la palette `S.C` : `texte`, `clair`, `gris`, `ambre`, `ambreClair`, `vert`, `vertClair`, `rouge`, `rougeClair`, `bleu`, `fond`, `bord`, `creux`, `bordCreux`. Pas de couleur en dur ailleurs. |
| Texte | `S.Texte(parent, graisse, taille, couleur)` : Inter `Light`, `Regular`, `SemiBold` ou `Bold`, avec ombre. |
| Texture | `S.Texture(parent, couche, nom, r, g, b, a)` : `nil` donne une texture unie. |
| Panneau | `S.Panneau(cadre, alpha, bord)` : fond graphite et filet d'un pixel. |
| Fenêtre | `S.Fenetre(nom, largeur, hauteur, titre)` : déplaçable par sa barre, fermée par Échap. |
| Bouton | `S.BoutonPlat(parent, texte, largeur, hauteur, taille)`, puis `b:Choisir(vrai)`. |
| Liste longue | `S.Liste(parent, widgets, surChange)` : molette, rail et « 1–8 sur 14 ». |
| Objet | `S.ContourRarete` et `S.Rarete` : toute icône d'objet est encadrée à la couleur de sa rareté. |
| Nombres | `S.Nombre` (« 1 840 », « 1,3 »), `S.Duree` (« 7 s », « 28 min »), `S.Argent`, `S.ToucheCourte`. |
| Afficher | `S.Montrer(objet, visible)`. |

**Échelle** : tout est placé sur `S.racine`, où **1 unité = 1 pixel d'une maquette de 900 de haut**, quelle que soit
la résolution. Les maquettes HTML se dessinent donc sur une toile de 1440 × 900 (ou 1600 × 900), et leurs cotes
passent telles quelles en Lua. Les blocs du HUD se placent par `S.DISPOSITION` et `S.Placer(cadre, nom)`, jamais par
des points codés en dur (l'interface sera paramétrable).

## 4. Contraintes de l'API 3.3.5a (build 12340, Lua 5.1)

- Pas d'espace `C_*`, pas de `C_Timer` : minuterie par `OnUpdate` (cumuler `ecoule`, ne rien recalculer à chaque
  image sans besoin).
- Pas de `SetShown`, `SetColorTexture`, `CreateFromMixins`, ni d'atlas : utiliser `S.Montrer`, `S.Texture`.
- `SetBackdrop` existe directement sur les cadres (pas de `BackdropTemplate`).
- Boutons de techniques : ils cliquent les `ActionButton1` à `8` de Blizzard, cachés mais chargés (action « click »
  des boutons sécurisés). Ne pas remplacer ce mécanisme ; en combat, ne pas déplacer, montrer ou cacher un cadre
  sécurisé.
- Le client est **frFR** : tous les textes en français, phrase normale (pas de capitales, sauf ÉLITE, RARE, BOSS sur
  la cible, déjà validé).

## 5. Démarche

1. **Maquette d'abord** : une page HTML (artifact) sur la toile de maquettes, avec `frontend-design` pour la direction,
   aux cotes de la racine 900 et avec les vraies couleurs de `S.C` et la police Inter. Plusieurs variantes si la
   forme est ouverte.
2. **Validation par l'utilisateur** avant tout code Lua.
3. **Code** avec les briques ci-dessus, dans le fichier du bloc concerné ou un nouveau `SolUI_*.lua`.
4. **Vérification** : syntaxe avec `luac -p` si disponible. Le jeu ne tourne pas dans une session cloud : dire
   clairement que l'élément est « construit, pas encore vérifié en jeu ».
5. **Trace** : noter la décision, datée, dans `docs/Document de conception v3.md` (comme les autres lots F4).

## 6. Lisibilité en combat (critères de relecture)

- La cible, son incantation et ses débuffs se lisent d'un coup d'œil ; rien ne les couvre.
- Une information n'apparaît qu'une fois à l'écran.
- Le mouvement sert à signaler (halo qui respire sur la technique mise en avant), pas à décorer ; une seule chose
  bouge à la fois.
- Les chiffres restent lisibles sur tout décor (ombre du texte, fond `creux` sous les barres).
