"""Audit du jeu, lot 4c (02/11/2026) : simulation des bonus du lot, d'après le cadre des passifs de
simulation_donjons.py (la fiche la plus forte des journaux, contre un fouette-queue réglé à environ 50 % de victoires).
- Variantes par emplacement (choix à la fabrication) : Critique, Hâte et Vol de vie doivent se valoir ; on les compare
  sur 8 pièces de la même variante.
- Panoplie du Gouffre : paliers 2, 4 et 6 pièces, cumulés.
- Plats : chacun garde la caractéristique ; son bonus propre est plus fort pour l'ingrédient le plus rare.
- Consommables du surplus : pierre à aiguiser et nécessaire d'armure, 1 h.
Repère : « + 5 % de puissance » (+ 5 % de dégâts infligés et − 5 % de dégâts subis).

py simulation_lot4c.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import simulation_camp as camp
import simulation_combat as sim
import simulation_donjons as donjons
import simulation_modes as modes

PIECES = 8
# Par pièce (v3_equipement.cpp) : Critique en points de %, Hâte en %, Vol de vie en part des dégâts.
VARIANTES = {"Critique": 1.0, "Hâte": 2.0, "Vol de vie": 0.005}   # Hâte à 1 % : + 18 contre + 26, d'où 2 %
# Panoplie du Gouffre, cumulée : 2 pièces + 3 % de dégâts, 4 pièces − 5 % de dégâts subis, 6 pièces 3 % de vol de vie.
PANOPLIE = [(2, {"inflige": 1.03}), (4, {"inflige": 1.03, "subis": 0.95}),
            (6, {"inflige": 1.03, "subis": 0.95, "vol": 0.03})]
# Plats de Durotar (cuisine_v3.py), du plus commun au plus rare : bonus propre.
# Rareté de l'ingrédient de Blizzard à Durotar (chance × monstres) : sanglier 24 300, dard 13 300, crocilisque 1 080,
# maquereau 590, thon 185.
PLATS = [("Viande de sanglier rôtie : + 3 % de vie", {"vie": 1.03}),
         ("Surprise du scorpide : + 8 % d'armure", {"armure": 1.08}),
         ("Steak de crocilisque : + 3 % de critique", {"critique": 3.0}),
         ("Maquereau ombré : + 3 % de dégâts", {"inflige": 1.03}),
         ("Thon arc-en-ciel : + 12 % de hâte", {"hate": 0.12})]
# + 5 % de dégâts et + 10 % d'armure valaient + 23 et + 16, plus qu'un plat : ramenés au niveau des plats communs.
CONSOMMABLES = [("Pierre à aiguiser : + 3 % de dégâts physiques", {"inflige": 1.03}),
                ("Nécessaire d'armure : + 8 % d'armure", {"armure": 1.08})]


def fiche(j, vie=1.0, armure=1.0, critique=0.0, hate=0.0):
    return sim.Fiche(j.nom, round(j.vie * vie), round(j.armure * armure), j.bas, j.haut, j.vitesse / (1 + hate),
                     j.critique + critique, j.puissance)


def essai(j, m, bonus):
    """Victoires (%) avec un bonus : vie, armure, critique, hâte sur la fiche ; inflige, subis, vol en passifs."""
    f = fiche(j, bonus.get("vie", 1.0), bonus.get("armure", 1.0), bonus.get("critique", 0.0), bonus.get("hate", 0.0))
    passifs = {k: v for k, v in bonus.items() if k in ("inflige", "subis", "vol")}
    return donjons.taux(f, m, passifs=passifs or None)


def main():
    joueur = max(camp.fiches(), key=lambda f: f.puissance)
    j = camp.repos(joueur, 5)
    niveau = math.floor(joueur.puissance)
    bas, haut = 0.2, 5.0
    for _ in range(14):
        k = (bas + haut) / 2
        t = donjons.taux(j, modes.renforcer(sim.monstre_depuis_base(3122, niveau), k, 1.0))
        if 45 <= t <= 55:
            break
        if t > 55:
            bas = k
        else:
            haut = k
    m = modes.renforcer(sim.monstre_depuis_base(3122, niveau), k, 1.0)
    t = donjons.taux(j, m)
    print(joueur)
    print("Fouette-queue réglé à %.0f %% de victoires (vie %d, coups %d-%d)\n" % (t, m.vie, m.bas, m.haut))

    def ligne(nom, bonus):
        v = essai(j, m, bonus)
        print("   %-52s %3.0f %%  (%+.0f)" % (nom, v, v - t))

    print("Repère")
    ligne("+ 5 % de puissance", {"inflige": 1.05, "subis": 0.95})
    print("Variantes, %d pièces de la même" % PIECES)
    ligne("Critique (+ %.1f %% par pièce)" % VARIANTES["Critique"], {"critique": VARIANTES["Critique"] * PIECES})
    ligne("Hâte (+ %.1f %% par pièce)" % VARIANTES["Hâte"], {"hate": VARIANTES["Hâte"] * PIECES / 100})
    ligne("Vol de vie (%.1f %% par pièce)" % (VARIANTES["Vol de vie"] * 100), {"vol": VARIANTES["Vol de vie"] * PIECES})
    print("Panoplie du Gouffre")
    for n, bonus in PANOPLIE:
        ligne("%d pièces" % n, bonus)
    print("Plats (bonus propre, en plus de la caractéristique)")
    for nom, bonus in PLATS:
        ligne(nom, bonus)
    print("Consommables du surplus")
    for nom, bonus in CONSOMMABLES:
        ligne(nom, bonus)


if __name__ == "__main__":
    main()
