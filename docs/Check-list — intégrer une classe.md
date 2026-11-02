# Check-list — intégrer une classe ou une spécialisation

Écrite après le démoniste (lots D1 à D5, 02/11/2026). À parcourir dans l'ordre pour chaque nouvelle classe ou
spécialisation. Le principe de l'utilisateur sert de juge pour chaque ligne :

- aucune classe ne doit être déséquilibrée par rapport aux autres ;
- chacune progresse sans gros blocage, en farmant ses optimisations ;
- chaque classe se calibre contre le guerrier, aux mêmes pièces, à chaque étape ;
- tout mécanisme est explicite pour le joueur (infobulle, aura visible, bouton mis en avant) ;
- les classes s'adaptent au monde, pas l'inverse : on ne touche ni aux monstres ni à leur vitesse.

Les chemins sont relatifs au dépôt (`outils/`, `modules/mod-solazeroth/src/`, `interface-v3/FrameXML/`).

## 1. Identité de la spécialisation

- [ ] Une ligne dans `SPECIALISATIONS` (`v3_kit.cpp`) : identifiant, classe, nom, famille de sorts, passif, caractéristique principale (Force, Agilité, Intelligence).
- [ ] La caractéristique principale donne la puissance d'attaque par la règle unique (2 par point, `v3_niveau.cpp`). Elle choisit aussi le repas et le repos du feu. Vérifier que le repas et le repos existent pour cette caractéristique.
- [ ] Le kit : techniques dans l'ordre d'apprentissage, maîtres qui les enseignent, prix, niveau de puissance de chaque déblocage.
- [ ] Le passif de spécialisation est décrit dans son infobulle et sur la carte de choix (`SolUI_Options.lua`).
- [ ] Aucun familier permanent ; une invocation est un sort à durée et à recharge.

## 2. Sorts et dégâts

- [ ] Chaque sort passe par `sort()` (générateur de la classe, sur le modèle de `demoniste_v3.py`) :
  - copie d'un sort de Blizzard ;
  - dégâts de base à 0 ;
  - une part de la puissance d'attaque (`spell_bonus_data`, `ap_bonus` / `ap_dot_bonus`).
- [ ] Aucun dégât d'arme pour un sort ; aucune attaque automatique pour un lanceur de sorts (minuteur d'attaque tenu chargé).
- [ ] Un sort faible lançable en boucle ; les recharges sont écrites dans le générateur et dans le simulateur.
- [ ] Arme d'un lanceur de sorts : ses dégâts par seconde × 14 s'ajoutent à la puissance d'attaque, enchantements de dégâts compris (`PuissanceDeLArme`, `v3_niveau.cpp`). Le calcul doit être relancé quand l'arme ou son enchantement change.
- [ ] Les descriptions des sorts donnent les pourcentages de puissance d'attaque réellement appliqués. Elles sont à régénérer après chaque calibrage.
- [ ] Les scripts de sorts sont enregistrés (`SCRIPTS` du générateur, `AddSC_…` en C++).

## 3. Incantation, mouvement, contrôle

- [ ] Incantation à l'arrêt : les drapeaux d'interruption de Blizzard sont gardés. Les instantanés se lancent en courant. Le joueur court à 7 m/s, la plupart des monstres à 6 m/s, d'où un kite total si l'on incante en courant.
- [ ] Les coups reçus retardent une incantation (+0,5 s) et écourtent une canalisation (−25 %), deux fois au plus.
- [ ] Peur et autres contrôles :
  - seuil de rupture en pourcentage de la vie de la cible (15 % pour la Peur, `spell_solazeroth_v3_peur`) ;
  - le seuil du moteur se calcule au niveau 80 et ne casse jamais.
- [ ] Procs : une chance par tic ou par coup, avec une aura visible et le bouton mis en avant (`SolUI_Techniques.lua`). Un sort déclenché (par un passif, par exemple) ne doit pas consommer le proc.
- [ ] Interruption : la classe en a-t-elle une ? Sinon, ce qui en tient lieu est écrit dans le lexique.

## 4. Armures, objets et récompenses

- [ ] Type d'armure par classe et palier (`solazeroth-armures-par-classe` : guerrier en maille puis en plaque à 40+, démoniste en tissu).
- [ ] Conversions des pièces (`tissu_v3.py`, table `solazeroth_v3_conversions`) :
  - chaque pièce du monde a sa version dans l'armure de la classe ;
  - le bouclier devient un objet de main gauche (orbe) ;
  - l'échange se fait sans message au joueur.
- [ ] Récompenses de quête : la fenêtre et le journal montrent la version de la classe (`SolUI_Versions.lua`, `S.VersionObjet`).
- [ ] Pièces fabriquées (métiers) : une version existe pour l'armure de la classe, ou bien la règle de remplacement est écrite.
- [ ] Compétences d'armes : la classe sait manier les armes qu'elle reçoit.
- [ ] Rares secrets et leurs objets : bijou et bague portables par toutes les classes.

## 5. Améliorations à farmer

- [ ] Enchantements (`enchantement_v3.py`, migration 081) :
  - un enchantement pour la caractéristique principale ;
  - un enchantement pour chaque emplacement que la classe porte (orbe, bâton, arme à deux mains…) ;
  - les enchantements d'arme comptent pour un lanceur de sorts.
- [ ] Gemmes et autres améliorations : une version pour chaque caractéristique principale.
- [ ] Rangs d'objet, panoplies et bonus de panoplie : valables pour les versions de la classe.
- [ ] Repas et repos du feu pour la caractéristique principale (`SolUI_Camp`, cuisine).
- [ ] Potions : rien de propre à la classe.

## 6. Passifs et mécanismes partagés

Relire chaque passif extérieur et de donjon (`passifs_v3.py`, `v3_passifs.cpp`) en se demandant s'il suppose la mêlée, l'arme ou le Rempart :

- [ ] Contre-attaque : un lanceur de sorts rend un sort instantané, pas un coup d'arme.
- [ ] Épines, Bourreau, Premier sang, Embuscade, Main vive : valables pour des sorts et des dégâts sur la durée ?
- [ ] Rempart et Second souffle : le Rempart n'existe que pour le guerrier tank. L'interface le cache aux autres (`SolUI_Perso.lua`), et le serveur ne l'envoie qu'au tank.
- [ ] Vol de vie et soins : se cumulent-ils sans excès avec un soin propre à la classe (Moisson) ?
- [ ] Difficultés de donjon et leurs techniques (Explosif, Volcanique…) : une classe à distance les vit différemment. Le vérifier en jeu.

## 7. Simulations (toutes contre le guerrier, mêmes pièces)

Simulateur de la classe sur le modèle de `simulation_demoniste.py`. Il reprend :
- combats enchaînés, recharges qui courent entre deux combats ;
- ouverture à distance, vitesse de course réelle des monstres ;
- retards d'incantation, Peur, invocations, procs, potion.

- [ ] Fin de vallée, contre sa puissance et au-dessus : seul, puis en groupe de 2 et de 3.
- [ ] Fin de Durotar, mêmes essais.
- [ ] Gouffre de Ragefeu : élite et dernier boss, difficultés 1 à 5, avec 0, 2 et 4 rangs d'objet (`--gouffre`).
- [ ] Rares secrets : tout en bleu, avec tous les bonus du défi, et leurs techniques d'ouverture (une Charge annule la distance).
- [ ] Passifs : leur gain doit rester du même ordre que pour le guerrier.
- [ ] Verdict de `tests_equilibrage.py` (« ok » contre sa puissance) et fidélité du modèle : `ok`.
- [ ] Les résultats sont écrits dans le document de conception : chiffres, écarts acceptés et pourquoi.

## 8. Interface et explications

- [ ] Carte de spécialisation (`SolUI_Options.lua`) : rôle, passif, règles de la classe (incantation, arme).
- [ ] Lexique (`SolUI_Lexique.lua`) : une page pour les mécanismes propres à la classe. Mettre à jour aussi les pages générales qui ne parlaient que du guerrier.
- [ ] Barre des techniques : procs mis en avant, recharges visibles.
- [ ] HUD : rien de vide ni d'inutile pour la classe (Rempart, ressources).
- [ ] Infobulles des sorts : chiffres exacts après calibrage.
- [ ] Textes des passifs : ils disent ce que fait le passif pour la classe.

## 9. Journal de combat et outils

- [ ] La fiche du joueur dans le journal donne sa caractéristique principale (`v3_journal.cpp`). Les expressions de `simulation_combat.py` restent compatibles (`JOUEUR`).
- [ ] Les sorts de la classe apparaissent nommés dans le journal.
- [ ] Commandes MJ utiles (`.kit`, `.passif`…) : vérifiées dans le code source avant de les donner.

## 10. Vérifications et livraison

- [ ] Construction du serveur seulement si ni le worldserver ni WoW ne tournent.
- [ ] Migrations régénérées et rejouées : `migrer.ps1 -Annuler N`, puis `migrer.ps1`.
- [ ] `interface_v3.py`, `verifier_lua.py`, puis `construire_patch.py`. Le patch ne se reconstruit jamais pendant que WoW tourne.
- [ ] Banc d'essai de l'interface : tous les essais `ok`, plus un essai pour chaque nouveauté de la classe.
- [ ] Document de conception (CRLF) et mémoire mis à jour.
- [ ] Export du dépôt (« Aucun problème trouvé »), commit, push.
- [ ] Essai en jeu par l'utilisateur. Les signalements arrivent par la touche « ! ».
