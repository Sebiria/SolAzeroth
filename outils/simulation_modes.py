"""F9 (01/11/2026) : simulation des modes de zone (chiffres validés par l'utilisateur, à ajuster ici).

Pour chaque fiche des journaux (puissance 5 et plus), contre trois monstres de Durotar remis à la puissance du mode,
comme v3_modes.cpp : la puissance de base du joueur (sans les rangs) arrondie en dessous, plus l'écart du mode ; un
monstre plus fort garde la sienne.
- normal rehaussé : écart 0 ;
- difficile : écart 2, vie et dégâts × 1,25, une technique ;
- cauchemar : écart 2, vie et dégâts × 1,5, deux techniques de force 1,5.
Le joueur est pris tel quel (potion de départ), avec la potion rang 2 et le Repos des nœuds 2-3 (F7), puis avec en plus
deux rangs d'objet de mieux (+20 % de vie, d'armure et de dégâts ; les monstres ne montent pas avec les rangs). La
puissance de la fiche du journal est prise comme puissance de base.
Les techniques (Enragé, Renforçant, Volcanique) ne sont pas simulées une à une : chacune compte pour + TECHNIQUE de
dégâts subis, multipliée par sa force.
Audit du jeu, lot 2 (02/11/2026) : écart du difficile (1 au lieu de 2), monstres calés sur la puissance avec les rangs
et arrondi au plus proche corrigés pour suivre le serveur.

Lot T7 des Tarides (03/11/2026, point 13.5 du comparatif) : --tarides simule les modes sur la fiche des Tarides à 60 %
de la zone (secteur du sud, monstres 25 à 27 : puissance 26, fiches_zones.joueurs), le guerrier contre les monstres des
Tarides de cette tranche (tests_equilibrage.MONSTRES_TARIDES, sorts et courbe compris), avec le camp de fin de Durotar
(potion 2, feu 3), puis celui des Tarides (potion 4 : 3 charges à 40 % ; feu 5 : vie +8 %, +10 Force), puis avec deux
rangs d'objet de mieux.

py simulation_modes.py [--tarides]
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import simulation_camp as camp
import simulation_combat as sim

MONSTRES = (3125, 3099, 3122)          # scorpide, sanglier, fouette-queue
# (écart, vie et dégâts, techniques, force des techniques), comme REGLES dans v3_modes.cpp
MODES = {"normal": (0, 1.0, 0, 1.0), "difficile": (2, 1.25, 1, 1.0), "cauchemar": (2, 1.5, 2, 1.5)}
TECHNIQUE = 0.05                        # dégâts subis en plus par technique, à part


def renforcer(m, facteur, techniques):
    m.vie = round(m.vie * facteur)
    m.bas, m.haut = round(m.bas * facteur * techniques), round(m.haut * facteur * techniques)
    return m


def puissance_visee(joueur, ecart, entree):
    """Puissance d'un monstre remis au mode : puissance de base du joueur arrondie en dessous + écart, ou la sienne si
    elle est plus forte (v3_modes.cpp)."""
    return max(sim.monstre_depuis_base(entree).puissance, math.floor(joueur.puissance) + ecart)


def rangs(joueur, n):
    """Le joueur avec n rangs d'objet de plus (+10 % par rang sur l'équipement, approché sur toute la fiche)."""
    f = 1 + 0.1 * n
    j = sim.Fiche(joueur.nom, round(joueur.vie * f), round(joueur.armure * f), joueur.bas * f, joueur.haut * f,
                  joueur.vitesse, joueur.critique, joueur.puissance * f)
    return j


def main():
    print("Victoires (%%) sur %d monstres ; colonnes : %s" % (len(MONSTRES), " / ".join(MODES)))
    for joueur in camp.fiches():
        if joueur.puissance < 5:
            continue
        variantes = (("tel quel", joueur, (1, 30, 0, 0)),
                     ("F7", camp.repos(joueur, 5), (2, 35, 1, 10)),
                     ("F7 + 2 rangs", camp.repos(rangs(joueur, 2), 5), (2, 35, 1, 10)))
        for nom, j, potion in variantes:
            cases = []
            for mode, (ecart, facteur, techniques, force) in MODES.items():
                tech = 1 + TECHNIQUE * techniques * force
                ms = [renforcer(sim.monstre_depuis_base(e, puissance_visee(joueur, ecart, e)), facteur, tech)
                      for e in MONSTRES]
                taux = sum(sim.simuler(j, m, 400, potion=potion)["victoire"] for m in ms) / len(ms)
                cases.append("%3.0f" % taux)
            print("%-6s P%-4.1f %-13s %s" % (joueur.nom, joueur.puissance, nom, " / ".join(cases)))


P_TARIDES = 26                          # 60 % des Tarides : secteur du sud (48,55 à 71,65 %), monstres 25 à 27
POTION_TARIDES_4 = (3, 40, 1, 10)       # potion 4 des Tarides (bivouac_v3.py)


def tarides():
    import fiches_zones as fz
    import simulation_sorts as ss
    import tests_equilibrage as te
    g = fz.joueurs(P_TARIDES)[0]
    camp_tarides = lambda j: sim.enchanter(j, vie=round(j.vie * 0.03), force=5)   # feu 5 au lieu du feu 3
    monstres = [(e, p) for e, p in te.MONSTRES_TARIDES if 25 <= p <= 27]
    print("Tarides, guerrier P%d (fiche à 60 %%), victoires (%%) sur %d monstres ; colonnes : %s"
          % (P_TARIDES, len(monstres), " / ".join(MODES)))
    variantes = (("camp de Durotar", g, te.POTION_TARIDES), ("camp des Tarides", camp_tarides(g), POTION_TARIDES_4),
                 ("Tarides + 2 rangs", camp_tarides(rangs(g, 2)), POTION_TARIDES_4))
    for nom, j, potion in variantes:
        cases = []
        for mode, (ecart, facteur, techniques, force) in MODES.items():
            tech = 1 + TECHNIQUE * techniques * force
            ms = [renforcer(ss.monstre_avec_sorts(e, max(p, math.floor(P_TARIDES) + ecart), contact=True, courbe=True),
                            facteur, tech) for e, p in monstres]
            taux = sum(ss.simuler(j, m, 400, potion=potion, heurt=te.HEURT)["victoire"] for m in ms) / len(ms)
            cases.append("%3.0f" % taux)
        print("  %-18s %s" % (nom, " / ".join(cases)))


if __name__ == "__main__":
    if "--tarides" in sys.argv:
        tarides()
    else:
        main()
