"""F9 (01/11/2026) : simulation des modes de zone (chiffres validés par l'utilisateur, à ajuster ici).

Pour chaque fiche des journaux (puissance 5 et plus), contre trois monstres de Durotar remis à la puissance du mode :
- normal rehaussé : à la puissance du joueur ;
- difficile : puissance + 1, vie et dégâts × DIFFICILE ;
- cauchemar : puissance + 2, vie et dégâts × CAUCHEMAR.
Le joueur est pris tel quel (potion de départ), avec la potion rang 2 et le Repos des nœuds 2-3 (F7), puis avec en plus
deux rangs d'objet de mieux (+20 % de vie, d'armure et de dégâts, et de puissance : les monstres montent avec lui).
Les techniques (Enragé, Renforçant, Volcanique) ne sont pas simulées : comptées à part, environ +10 % de dégâts subis.

py simulation_modes.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import simulation_camp as camp
import simulation_combat as sim

MONSTRES = (3125, 3099, 3122)          # scorpide, sanglier, fouette-queue
MODES = {"normal": (0, 1.0), "difficile": (1, 1.25), "cauchemar": (2, 1.5)}   # (puissance en plus, vie et dégâts)
TECHNIQUES = 1.10                       # dégâts subis en plus, à part


def renforcer(m, facteur, techniques):
    m.vie = round(m.vie * facteur)
    m.bas, m.haut = round(m.bas * facteur * techniques), round(m.haut * facteur * techniques)
    return m


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
            p = round(j.puissance)
            cases = []
            for mode, (ecart, facteur) in MODES.items():
                tech = 1.0 if mode == "normal" else TECHNIQUES
                ms = [renforcer(sim.monstre_depuis_base(e, p + ecart), facteur, tech) for e in MONSTRES]
                taux = sum(sim.simuler(j, m, 400, potion=potion)["victoire"] for m in ms) / len(ms)
                cases.append("%3.0f" % taux)
            print("%-6s P%-4.1f %-13s %s" % (joueur.nom, joueur.puissance, nom, " / ".join(cases)))


if __name__ == "__main__":
    main()
