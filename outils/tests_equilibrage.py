"""v3 (31/10/2026) : tests d'équilibrage, par simulation de combats (simulation_combat.py). À lancer après chaque
changement de chiffres (monstres, armure, équipement, kit), comme le demande l'utilisateur.

1. Fidélité du modèle (bloquant) :
   - chaque monstre des journaux, bâti depuis la base, a la fiche que le serveur a écrite (avec ses réglages du moment :
     un journal écrit avant un calibrage est relu avec les réglages d'origine que la migration a gardés) ;
   - le combat du journal (Scorpide claquant, donnees_tests) rejoué donne à peu près les mêmes dégâts par seconde ;
   - tous les combats réels contre un seul monstre sans sort (audit du jeu, lot 2, 02/11/2026) : la durée simulée
     rapportée à la durée réelle reste proche de 1 en médiane.
2. Rapport d'équilibrage (non bloquant) : le personnage de la dernière fiche du journal, avec son équipement puis avec
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
TOLERANCE_DUREE = 0.15   # médiane de la durée simulée ÷ durée réelle, sur tous les combats en mêlée seule
MIN_COMBATS = 30
# Réglages d'origine gardés par les migrations de calibrage (primes 105, Gouffre 102, sorts 107, lot 3c 111).
ORIGINES = ["solazeroth_v3_calibre_3c_origine", "solazeroth_v3_sorts_calibre_origine", "solazeroth_v3_primes_origine", "solazeroth_v3_gouffre_origine"]
REPAS_DUROTAR = 6
# Enchantements de Durotar (enchantement_v3.py) : plastron +5 vie, cape +10 armure, brassards +1 Force, arme +1 dégât.
ENCHANTEMENTS_DUROTAR = dict(vie=5, armure=10, force=1, degats=1)

# (entrée, niveau d'origine) : de la vallée des Épreuves au sud de Durotar.
MONSTRES = [(3098, 2), (3124, 3), (3101, 4), (3125, 6), (3099, 7), (3122, 8), (3121, 8), (3100, 9), (3123, 10),
            (3110, 11)]
# Panoplies essayées sur le personnage de la fiche, en plus de son équipement actuel.
PANOPLIES = {
    "fin de vallée (quêtes)": [910105, 910106, 910101, 910102, 910103, 910104, 910108],
    "fabriquée (maille)": [910201, 910202, 910203, 910204, 910205, 910206, 910207, 910208],
    "fin de Durotar (quêtes)": [910109, 910118, 910111, 910110, 910117, 910114, 910107, 910116, 910119],
}


CHAMPS = ("vie", "armure", "bas", "haut", "vitesse")
# Coups : le journal écrit des entiers, le jeu calcule en virgule flottante (Zalaphil, 11-15 au lieu de 12-16).
ECART = {"bas": 1, "haut": 1}


def reglages_connus(entree):
    """Réglages du monstre : ceux de la base, puis ceux d'avant chaque calibrage."""
    liste = [None]
    for table in ORIGINES:
        colonnes = [c for (c,) in sim.sql("SELECT COLUMN_NAME FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = "
                                           "'acore_world' AND TABLE_NAME = '%s' AND COLUMN_NAME IN ('HealthModifier', "
                                           "'DamageModifier')" % table)]
        if not colonnes:
            continue
        for ligne in sim.sql("SELECT %s FROM acore_world.%s WHERE entry = %d" % (", ".join(colonnes), table, entree)):
            liste.append({c: float(v) for c, v in zip(colonnes, ligne)})
    return liste


def journaux():
    return sorted(glob.glob(os.path.join(sim.JOURNAUX, "*.log")), key=os.path.getmtime)


def verifier_fiches(erreurs):
    """Fiche de chaque monstre (dernière rencontre de chaque entrée et puissance) contre celle bâtie depuis la base."""
    vus = {}
    for chemin in journaux():
        for c in sim.lire_journal(chemin):
            for m in c["monstres"]:
                vus[(m.entree, m.puissance)] = m
    anciens = 0
    for (entree, puissance), m in sorted(vus.items()):
        fiches = [sim.monstre_depuis_base(entree, puissance, r) for r in reglages_connus(entree)]
        justes = [i for i, f in enumerate(fiches) if all(abs(getattr(f, c) - getattr(m, c)) <= ECART.get(c, 0)
                                                          for c in CHAMPS)]
        if not justes:
            f = fiches[0]
            erreurs.append("monstre %d (puissance %d) : %s" % (entree, puissance, ", ".join(
                "%s %s dans la base, %s dans le journal" % (c, getattr(f, c), getattr(m, c))
                for c in CHAMPS if abs(getattr(f, c) - getattr(m, c)) > ECART.get(c, 0))))
        elif 0 not in justes:
            anciens += 1
    print("  fiches des monstres : %d vérifiées, dont %d écrites avant un calibrage" % (len(vus), anciens))


def verifier_durees(erreurs):
    """Combats réels contre un seul monstre, sans sort, gagnés : durée simulée ÷ durée réelle."""
    rapports = []
    for chemin in journaux():
        for c in sim.lire_journal(chemin):
            b = c["bilan"]
            if (not c["joueur"] or len(c["monstres"]) != 1 or c["sorts"] or not b or b["tues"] != 1
                    or b["duree"] < 3):
                continue
            avant = sim.appliquer(c["regles"])     # chaque journal avec sa règle d'armure (lot 3a)
            r = sim.simuler(c["joueur"], c["monstres"][0], 200)
            sim.appliquer(avant)
            if r["victoire"] > 50:
                rapports.append(r["duree"] / b["duree"])
    if len(rapports) < MIN_COMBATS:
        print("  durées : %d combats seulement, pas de verdict" % len(rapports))
        return
    rapports.sort()
    mediane = rapports[len(rapports) // 2]
    print("  durées de %d combats réels en mêlée seule : simulé ÷ réel %.2f en médiane (quartiles %.2f et %.2f)" % (
        len(rapports), mediane, rapports[len(rapports) // 4], rapports[3 * len(rapports) // 4]))
    if abs(mediane - 1) > TOLERANCE_DUREE:
        erreurs.append("durée simulée ÷ réelle %.2f en médiane, hors de 1 ± %.2f" % (mediane, TOLERANCE_DUREE))


def verifier_modele():
    erreurs = []
    verifier_fiches(erreurs)
    combats = sim.lire_journal(REFERENCE)
    reel = combats[0]
    m = reel["monstres"][0]
    avant = sim.appliquer(reel["regles"])
    r = sim.simuler(reel["joueur"], m, 3000)
    sim.appliquer(avant)
    for nom, simule, mesure in (("joueur", r["dps_joueur"], REEL_JOUEUR), ("monstre", r["dps_monstre"], REEL_MONSTRE)):
        ecart = simule / mesure - 1
        print("  dégâts par seconde du %s : simulé %.2f, réel %.2f (%+.0f %%)" % (nom, simule, mesure, 100 * ecart))
        if abs(ecart) > TOLERANCE:
            erreurs.append("dégâts du %s : %+.0f %% d'écart avec le journal" % (nom, 100 * ecart))
    if r["victoire"] > 10:
        erreurs.append("le combat perdu du journal est gagné %.0f fois sur 100 en simulation" % r["victoire"])
    verifier_durees(erreurs)
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
    fiches = (sim.au_present(c) for chemin in list(reversed(journaux())) + [REFERENCE]
              for c in reversed(sim.lire_journal(chemin)) if c["joueur"])
    joueur = next(fiches)
    # Les pièces remplacées sont lues sur le même personnage que la fiche (avant le 02/11/2026 : toujours Test).
    guid = int(sim.sql("SELECT guid FROM acore_characters.characters WHERE name = '%s'" % joueur.nom)[0][0])
    print("Fiche : %s (personnage %d)" % (joueur.nom, guid))
    panoplies = {"équipement actuel": joueur}
    for nom, objets in PANOPLIES.items():
        panoplies[nom] = sim.equiper(joueur, objets, guid)
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
