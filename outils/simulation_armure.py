"""Audit du jeu, lot 3a (02/11/2026) : l'armure en pourcentage, rapportée à la puissance de l'attaquant (C1 de
« Audit du jeu\\10_consensus.md »). Lancé avec py simulation_armure.py.

Constat : la règle par soustraction (armure / 20 retirés de chaque coup, au moins 25 % du coup) met 100 % des coups de
mêlée au plancher dès environ 600 d'armure, et le barème donnait déjà environ 850 d'armure à une maille de puissance 3.

Nouvelle règle (v3_combat.cpp) : réduction = armure / (armure + K × (C + puissance de l'attaquant)), sans plancher.
Nouveau barème (equipement_v3.py) : l'armure d'une pièce vaut son poids × (C + sa puissance) ; une panoplie complète a
donc la même réduction contre un monstre de sa puissance, quelle que soit la zone, et moins contre un plus fort.

L'outil rejoue chaque combat réel des journaux (un monstre ou un groupe) avec l'ancienne règle puis avec la nouvelle :
l'armure du joueur est convertie (nouvelle panoplie de sa puissance × la part qu'il portait de l'ancienne). Il donne,
par catégorie, la vie perdue (médiane des victoires), les victoires et la durée, à comparer aux cibles du consensus :
monstre seul 15 à 30 % de vie perdue ; élites, groupes et chefs 30 à 60 %, 12 à 15 s ; la vallée plus douce.
"""
import argparse
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import simulation_combat as sim
import tests_equilibrage as te

import equipement_v3 as e3

# Nouveau barème (equipement_v3.py) : points d'armure par point de (C + puissance), panoplie de 8 pièces ou bouclier.
UNITES = {"maille": e3.ARMURE_PANOPLIE[3], "bouclier": e3.ARMURE_BOUCLIER, "cuir": e3.ARMURE_PANOPLIE[2],
          "tissu": e3.ARMURE_PANOPLIE[1]}
CIBLES = {"vallée": (0, 30), "monstre seul": (15, 30), "élite": (30, 60), "groupe": (30, 60)}


def categorie(combat, rangs):
    ms = combat["monstres"]
    if len(ms) > 1:
        return "groupe"
    if max(m.puissance for m in ms) <= 3:
        return "vallée"
    return "élite" if rangs.get(ms[0].entree, 0) >= 1 else "monstre seul"


def combats_reels():
    """Combats sans sort des journaux d'avant le lot 3a (règle par soustraction), ceux qu'on compare."""
    liste = []
    for chemin in te.journaux():
        for c in sim.lire_journal(chemin):
            if c["joueur"] and c["monstres"] and not c["sorts"] and c["regles"]["ARMURE_MODELE"] == "soustraction":
                liste.append(c)
    entrees = sorted({m.entree for c in liste for m in c["monstres"]})
    rangs = {int(e): int(r) for e, r in sim.sql("SELECT entry, `rank` FROM acore_world.creature_template WHERE entry IN (%s)"
                                                 % ",".join(map(str, entrees)))}
    return liste, rangs


def mesurer(liste, rangs, n, nouvelle):
    sim.ARMURE_MODELE = "pourcentage" if nouvelle else "soustraction"
    par = {}
    for c in liste:
        j = sim.au_present(c) if nouvelle else c["joueur"]
        if len(c["monstres"]) > 1:
            r = sim.simuler_groupe(j, c["monstres"], n)
        else:
            r = sim.simuler(j, c["monstres"][0], n)
        par.setdefault(categorie(c, rangs), []).append(r)
    lignes = []
    for cat in ("vallée", "monstre seul", "élite", "groupe"):
        rs = par.get(cat, [])
        if not rs:
            continue
        perdue = sorted(100 - r["vie_restante"] for r in rs if r["victoire"] > 0)
        duree = sorted(r["duree"] for r in rs)
        mi = perdue[len(perdue) // 2] if perdue else 100
        bas, haut = CIBLES[cat]
        lignes.append("  %-13s %3d combats | vie perdue %5.1f %% (quartiles %4.1f-%4.1f, cible %d-%d) | victoires %5.1f %% "
                      "| durée %4.1f s" % (cat, len(rs), mi, perdue[len(perdue) // 4] if perdue else 100,
                                           perdue[3 * len(perdue) // 4] if perdue else 100, bas, haut,
                                           sum(r["victoire"] for r in rs) / len(rs), duree[len(duree) // 2]))
    return lignes


def main():
    parser = argparse.ArgumentParser(description="Armure en pourcentage : combats réels rejoués")
    parser.add_argument("--n", type=int, default=200, help="combats simulés par combat réel")
    parser.add_argument("--degats", type=float, nargs="*", default=None,
                        help="multiplicateurs de dégâts des monstres à essayer avec la nouvelle règle")
    parser.add_argument("-k", type=float, default=sim.ARMURE_K)
    parser.add_argument("-c", type=float, default=sim.ARMURE_C)
    args = parser.parse_args()
    sim.ARMURE_K, sim.ARMURE_C = args.k, args.c
    liste, rangs = combats_reels()
    ancien = sim.MONSTRES_DEGATS
    sim.MONSTRES_DEGATS = 4.0
    print("Règle d'avant le lot 3a (soustraction), dégâts des monstres × 4 :")
    print("\n".join(mesurer(liste, rangs, args.n, False)))
    for d in args.degats or [ancien]:
        sim.MONSTRES_DEGATS = d
        print("Armure en pourcentage (K %g, C %g), dégâts des monstres × %g :" % (sim.ARMURE_K, sim.ARMURE_C, d))
        print("\n".join(mesurer(liste, rangs, args.n, True)))
    sim.MONSTRES_DEGATS = ancien
    print("Réduction d'une panoplie à jour contre un monstre de sa puissance : maille et bouclier %.0f %%, maille seule "
          "%.0f %%, cuir %.0f %%, tissu %.0f %%" % tuple(100 * u / (u + sim.ARMURE_K) for u in (
              UNITES["maille"] + UNITES["bouclier"], UNITES["maille"], UNITES["cuir"], UNITES["tissu"])))


if __name__ == "__main__":
    main()
