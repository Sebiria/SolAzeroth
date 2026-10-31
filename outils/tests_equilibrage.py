"""v3 (31/10/2026) : tests d'équilibrage, par simulation de combats (simulation_combat.py). À lancer après chaque
changement de chiffres (monstres, armure, équipement, kit), comme le demande l'utilisateur.

1. Fidélité du modèle (bloquant) :
   - un monstre bâti depuis la base a la fiche que le serveur a écrite dans le journal ;
   - le combat du journal (Scorpide claquant, donnees_tests) rejoué donne à peu près les mêmes dégâts par seconde.
2. Rapport d'équilibrage (non bloquant) : le personnage Test (dernière fiche du journal), avec son équipement puis avec
   des pièces de Durotar, contre des monstres de Durotar. Cibles provisoires du document : combat de 8 à 20 s contre un
   monstre de sa puissance, gagné au moins 95 fois sur 100, avec 30 à 85 % de vie restante.

py tests_equilibrage.py        (code de sortie 1 si la fidélité du modèle n'est plus tenue)
"""
import glob
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import simulation_combat as sim

ICI = os.path.dirname(os.path.abspath(__file__))
REFERENCE = os.path.join(ICI, "donnees_tests", "combat_scorpide_2026-10-31.txt")
# Mesuré dans ce journal : joueur 86 dégâts en 25,8 s, monstre 74 subis (après le Rempart) en 25,8 s.
REEL_JOUEUR, REEL_MONSTRE = 86 / 25.8, 74 / 25.8
TOLERANCE = 0.30   # un seul combat réel : ses dés comptent
REPAS_DUROTAR = 6
# Enchantements de Durotar (enchantement_v3.py) : plastron +5 vie, cape +10 armure, brassards +1 Force, arme +1 dégât.
ENCHANTEMENTS_DUROTAR = dict(vie=5, armure=10, force=1, degats=1)

# (entrée, niveau d'origine) : de la vallée des Épreuves au sud de Durotar.
MONSTRES = [(3098, 2), (3124, 3), (3101, 4), (3125, 6), (3099, 7), (3122, 8), (3121, 8), (3100, 9), (3123, 10),
            (3110, 11)]
# Panoplies essayées sur le personnage Test, en plus de son équipement actuel.
PANOPLIES = {
    "fin de vallée (quêtes)": [910105, 910106, 910101, 910102, 910103, 910104, 910108],
    "fabriquée (maille)": [910201, 910202, 910203, 910204, 910205, 910206, 910207, 910208],
    "fin de Durotar (quêtes)": [910109, 910118, 910111, 910110, 910117, 910114, 910107, 910116, 910119],
}


def verifier_modele():
    erreurs = []
    combats = sim.lire_journal(REFERENCE)
    reel = combats[0]
    m = reel["monstres"][0]
    base = sim.monstre_depuis_base(m.entree, m.puissance)
    for champ in ("vie", "armure", "bas", "haut", "vitesse"):
        if getattr(base, champ) != getattr(m, champ):
            erreurs.append("monstre %d : %s %s dans la base, %s dans le journal" % (m.entree, champ,
                                                                                  getattr(base, champ), getattr(m, champ)))
    r = sim.simuler(reel["joueur"], m, 3000)
    for nom, simule, mesure in (("joueur", r["dps_joueur"], REEL_JOUEUR), ("monstre", r["dps_monstre"], REEL_MONSTRE)):
        ecart = simule / mesure - 1
        print("  dégâts par seconde du %s : simulé %.2f, réel %.2f (%+.0f %%)" % (nom, simule, mesure, 100 * ecart))
        if abs(ecart) > TOLERANCE:
            erreurs.append("dégâts du %s : %+.0f %% d'écart avec le journal" % (nom, 100 * ecart))
    if r["victoire"] > 10:
        erreurs.append("le combat perdu du journal est gagné %.0f fois sur 100 en simulation" % r["victoire"])
    return erreurs


def verdict(joueur, monstre, r):
    if abs(monstre.puissance - joueur.puissance) > 2:
        return ""
    if r["victoire"] < 95 or r["vie_restante"] < 30:
        return "  <- trop dur"
    if r["duree"] > 20:
        return "  <- trop long"
    if r["duree"] < 8 or r["vie_restante"] > 85:
        return "  <- trop facile"
    return "  ok"


def rapport():
    # Fiche du personnage : le journal le plus récent qui en a une, sinon le combat de référence.
    journaux = sorted(glob.glob(os.path.join(sim.JOURNAUX, "*.log")), key=os.path.getmtime, reverse=True)
    fiches = (c["joueur"] for chemin in journaux + [REFERENCE] for c in reversed(sim.lire_journal(chemin)) if c["joueur"])
    joueur = next(fiches)
    panoplies = {"équipement actuel": joueur}
    for nom, objets in PANOPLIES.items():
        panoplies[nom] = sim.equiper(joueur, objets, 20)
    # Repas de Durotar (cuisine_v3.py : puissance moyenne de la zone, 6) sur la panoplie de fin de vallée.
    panoplies["fin de vallée + repas de Durotar"] = sim.repas(panoplies["fin de vallée (quêtes)"], REPAS_DUROTAR)
    panoplies["fin de vallée + enchantements de Durotar"] = sim.enchanter(panoplies["fin de vallée (quêtes)"],
                                                                         **ENCHANTEMENTS_DUROTAR)
    monstres = [sim.monstre_depuis_base(e, n) for e, n in MONSTRES]
    for nom, j in panoplies.items():
        print("\n%s : puissance %.1f, vie %d, armure %d, arme %.1f-%.1f / %.2f s" % (nom, j.puissance, j.vie, j.armure,
                                                                                   j.bas, j.haut, j.vitesse))
        for m in monstres:
            r = sim.simuler(j, m, 1000)
            print("  %-34s P%-2d %s%s" % (m.nom[:34], m.puissance, sim.rapport(j, m, r), verdict(j, m, r)))


def main():
    print("Fidélité du modèle (journal de référence : %s)" % os.path.basename(REFERENCE))
    erreurs = verifier_modele()
    for e in erreurs:
        print("  ÉCHEC :", e)
    print("  ok" if not erreurs else "  %d échec(s)" % len(erreurs))
    print("\nRapport d'équilibrage (non bloquant ; verdict contre les monstres à 2 points de puissance au plus)")
    rapport()
    return 1 if erreurs else 0


if __name__ == "__main__":
    sys.exit(main())
