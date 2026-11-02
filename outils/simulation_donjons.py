"""Réputation des donjons (01/11/2026, proposition validée) : simulation des difficultés de donjon et des passifs.

1. Difficultés : la fiche la plus forte des journaux (puissance 9,7), avec F7 (potion rang 2, Repos) et 0, 2 ou 4 rangs
   d'objet, contre un Massacreur de la Lame brûlante (11323, élite) et Taragaman l'Affameur (11520, dernier boss) :
   - difficulté 1 : puissance de la base (celle du calibrage du Gouffre, migration 102) ;
   - difficultés 2 à 5 : puissance de base du joueur (sans les rangs) arrondie en dessous + écart, ou celle du monstre
     si elle est plus forte (v3_modes.cpp), vie et dégâts × facteur ; les techniques
     (Enragé, Renforçant, Volcanique, Explosif, Fortifié, Tyrannique) ne sont pas simulées une à une : chacune compte
     pour + TECHNIQUE de dégâts subis, et Fortifié/Tyrannique sont dans le facteur moyen.
2. Passifs : contre un monstre réglé pour que la fiche gagne environ une fois sur deux, victoires avec chaque passif
   simulable, à comparer avec « + 5 % de puissance » (+ 5 % de dégâts infligés et − 5 % de dégâts subis).
Audit du jeu, lot 2 (02/11/2026) : le monstre des passifs est réglé par dichotomie et sa référence mesurée sur le
monstre retenu (avant : pas de ± 5 % qui oscillaient, puis une référence prise avant le dernier pas, d'où des passifs
tous négatifs) ; puissance visée arrondie en dessous, comme le serveur.

py simulation_donjons.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import simulation_camp as camp
import simulation_combat as sim
import simulation_modes as modes

ELITE, BOSS = 11323, 11520
# difficulté : (écart, vie et dégâts, techniques)
DIFFICULTES = {2: (0, 1.1, 1), 3: (0, 1.25, 2), 4: (1, 1.3, 2), 5: (1, 1.4, 3)}
# Chiffres de la proposition, (1, 1.2, 1) à (4, 1.8, 3) : la difficulté 2 restait à 0 % de victoires même avec deux rangs
# d'objet de plus ; ceux-ci demandent environ 1, 3, 4 puis 5 rangs (et des passifs) de plus que la difficulté 1.
TECHNIQUE = 0.05
POTION_F7 = (2, 35, 1, 10)
N = 400

PASSIFS = {
    "+ 5 % de puissance (repère)": {"inflige": 1.05, "subis": 0.95},
    "Peau de braise (− 8 % subis)": {"subis": 0.92},
    "Soif de sang (6 % de vol de vie)": {"vol": 0.06},
    "Second souffle (15 % sous 30 %)": {"souffle": (0.30, 0.15)},
    "Épines (7 % de la mêlée)": {"epines": 0.07},
    "Bourreau (+ 30 % sous 35 %)": {"bourreau": (0.35, 0.30)},
    "Brise-chef (+ 10 % contre les boss)": {"inflige": 1.10},
    "Premier sang (+ 50 % au-dessus de 80 %)": {"premier": (0.80, 0.50)},
    "Main vive (recharges − 10 %)": {"recharge": 0.90},
    "Contre-attaque (20 %)": {"contre": 0.20},
    "Embuscade (+ 80 % au-dessus de 90 %)": {"premier": (0.90, 0.80)},
    "Chasseur de rares (+ 10 %)": {"inflige": 1.10},
    "Solitaire (− 8 % subis)": {"subis": 0.92},
    "Nettoyeur (+ 10 %)": {"inflige": 1.10},
}


def taux(j, m, **options):
    return sim.simuler(j, m, N, potion=POTION_F7, **options)["victoire"]


def difficultes(joueur):
    print("1. Victoires (%%) par difficulté, contre le Massacreur (élite) / Taragaman (boss)")
    print("   %-18s %s" % ("", "   ".join("diff. %d     " % d for d in range(1, 6))))
    for n in (0, 2, 4):
        j = camp.repos(modes.rangs(joueur, n), 5)
        cases = []
        for d in range(1, 6):
            paire = []
            for entree in (ELITE, BOSS):
                if d == 1:
                    m = sim.monstre_depuis_base(entree)
                else:
                    ecart, facteur, techniques = DIFFICULTES[d]
                    m = modes.renforcer(sim.monstre_depuis_base(entree, modes.puissance_visee(joueur, ecart, entree)),
                                        facteur, 1 + TECHNIQUE * techniques)
                paire.append("%3.0f" % taux(j, m))
            cases.append(" / ".join(paire))
        print("   %-18s %s" % ("+ %d rangs d'objet" % n, "   ".join("%-12s" % c for c in cases)))


def etalonnees(joueur):
    """Les difficultés l'une par rapport à l'autre : l'élite à la puissance de base du joueur, ramené à environ 95 %
    de victoires sans rang d'objet (le Gouffre n'est pas encore calibré pour la v3), puis chaque difficulté appliquée
    à cet élite étalonné."""
    j0 = camp.repos(joueur, 5)
    base = math.floor(joueur.puissance)
    reglage = 1.0
    for _ in range(60):
        m = modes.renforcer(sim.monstre_depuis_base(ELITE, base), reglage, 1.0)
        t = taux(j0, m)
        if 93 <= t <= 97:
            break
        reglage *= 1.04 if t > 97 else 0.96
    print("\n1 bis. Élite étalonné (× %.2f de vie et dégâts, %.0f %% en difficulté 1) :" % (reglage, t))
    for n in (0, 2, 4):
        j = camp.repos(modes.rangs(joueur, n), 5)
        cases = ["%3.0f" % taux(j, m)]
        for d, (ecart, facteur, techniques) in DIFFICULTES.items():
            md = modes.renforcer(sim.monstre_depuis_base(ELITE, base + ecart), reglage * facteur, 1 + TECHNIQUE * techniques)
            cases.append("%3.0f" % taux(j, md))
        print("   %-18s %s" % ("+ %d rangs d'objet" % n, " / ".join(cases)))


def passifs(joueur):
    j = camp.repos(joueur, 5)
    niveau = math.floor(joueur.puissance)
    bas, haut = 0.2, 5.0                    # facteur de vie et de dégâts du monstre
    for _ in range(14):
        k = (bas + haut) / 2
        t = taux(j, modes.renforcer(sim.monstre_depuis_base(3122, niveau), k, 1.0))
        if 45 <= t <= 55:
            break
        if t > 55:
            bas = k
        else:
            haut = k
    m = modes.renforcer(sim.monstre_depuis_base(3122, niveau), k, 1.0)
    t = taux(j, m)
    print("\n2. Passifs, contre un fouette-queue réglé à %.0f %% de victoires (vie %d, coups %d-%d)" % (t, m.vie, m.bas, m.haut))
    for nom, p in PASSIFS.items():
        print("   %-46s %3.0f %%  (%+.0f)" % (nom, taux(j, m, passifs=p), taux(j, m, passifs=p) - t))
    for nom, vie, armure in (("Carrure (+ 8 % de vie)", 1.08, 1.0), ("Cuirasse (+ 6 % d'armure)", 1.0, 1.06)):
        f = sim.Fiche(j.nom, round(j.vie * vie), round(j.armure * armure), j.bas, j.haut, j.vitesse, j.critique,
                      j.puissance)
        print("   %-46s %3.0f %%  (%+.0f)" % (nom, taux(f, m), taux(f, m) - t))


def main():
    joueur = max(camp.fiches(), key=lambda f: f.puissance)
    print(joueur)
    difficultes(joueur)
    etalonnees(joueur)
    passifs(joueur)


if __name__ == "__main__":
    main()
