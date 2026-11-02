"""F7 (01/11/2026) : simulation des rangs de la potion et du Repos au coin du feu (chiffres de l'utilisateur).

Le personnage du dernier combat journalisé, contre des monstres de Durotar de sa puissance et au-dessus, avec :
- la potion du départ (1 charge, 30 %), du rang 1 (2 charges, 35 %) et du rang 2 (2 charges, 35 %, puis 1 % par
  seconde pendant 10 s), bue sous 35 % de vie ;
- le Repos du nœud 1 (vie +5 %, dégâts +10 %) et des nœuds 2 et 3 (en plus Force +5).

py simulation_camp.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import simulation_combat as sim

POTIONS = {"sans": None, "départ": (1, 30, 0, 0), "rang 1": (2, 35, 0, 0), "rang 2": (2, 35, 1, 10)}
MONSTRES = (3125, 3099, 3122)  # scorpide, sanglier, fouette-queue
ECARTS = (1, 2, 3)  # niveau du monstre - puissance du joueur


def repos(joueur, force):
    """Repos : vie maximale +5 %, dégâts +10 %, Force en plus (2 PA par point pour le guerrier)."""
    j = sim.enchanter(joueur, vie=round(joueur.vie * 0.05), force=force)
    j.bas, j.haut = j.bas * 1.10, j.haut * 1.10
    return j


def fiches():
    """La fiche la plus récente de chaque (personnage, puissance arrondie) des journaux."""
    vues = {}
    for f in sorted(sim.glob.glob(sim.os.path.join(sim.JOURNAUX, "*.log")), key=sim.os.path.getmtime):
        for c in sim.lire_journal(f):
            # Lot 3a (02/11/2026) : fiches ramenées aux règles d'aujourd'hui (armure en pourcentage).
            if c["joueur"] and round(c["joueur"].puissance) >= 3:
                vues[(c["joueur"].nom, round(c["joueur"].puissance))] = sim.au_present(c)
    return [vues[k] for k in sorted(vues)]


def main():
    print("Victoires (%%) sur %d monstres x écarts %s ; colonnes : potion %s" % (len(MONSTRES), ECARTS, " / ".join(POTIONS)))
    for joueur in fiches():
        p = round(joueur.puissance)
        monstres = {e: [sim.monstre_depuis_base(m, p + e) for m in MONSTRES] for e in ECARTS}
        for nom_j, j in (("sans Repos", joueur), ("Repos 1", repos(joueur, 0)), ("Repos 2-3", repos(joueur, 5))):
            cases = []
            for e in ECARTS:
                taux = [sum(sim.simuler(j, m, 400, potion=po)["victoire"] for m in monstres[e]) / len(MONSTRES)
                        for po in POTIONS.values()]
                cases.append("+%d : %s" % (e, " / ".join("%3.0f" % t for t in taux)))
            print("%-9s P%-2d %-10s %s" % (joueur.nom, p, nom_j, "   ".join(cases)))


if __name__ == "__main__":
    main()
