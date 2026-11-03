"""Lot T1 des Tarides (03/11/2026) : courbe des monstres selon la puissance (choix de l'utilisateur du 03/11/2026, point
19 du §5.2 du brouillon des Tarides).

Au-delà de la puissance 14, la pente des monstres de Blizzard (vie et dégâts par niveau) dépasse celle des pièces (barème
de equipement_v3) : le guerrier d'arrivée perdait 45 % de vie contre un monstre de puissance 14, et 100 % dès 25. La
courbe multiplie la vie (et les soins) et les dégâts (mêlée, sorts, dégâts sur la durée) des monstres dont la puissance
vient d'un secteur (v3_niveau.cpp, v3_combat.cpp). Elle vaut 1 jusqu'à 14 : Durotar et le Gouffre ne bougent pas, ni les
classes, ni les pièces. Générique : une ligne par puissance, qui resservira aux donjons et aux zones suivantes
(au-delà de la dernière ligne, la dernière).

Réglage par simulation (simulation_sorts.py, sorts au contact) contre le guerrier de la fiche de ce point
(fiches_zones.joueurs : pièces d'arrivée refaites au barème, Repos du feu 3, potion rang 2, Heurt) :
- cible au même point de la zone qu'à Durotar (d = 1 + (P − 14) × 9 / 16, la fiche de Sebiria et le monstre de Durotar
  les plus proches de d, comme au lot 3c) : vie perdue de Durotar, bornée à 15-30 % ; durée de Durotar, bornée à
  DUREE (12-18 s) ;
- monstres : les REFERENCES entrées ordinaires les plus nombreuses de cette puissance (puissance_tarides.monstres) ;
- la vie règle la durée, puis les dégâts règlent la vie perdue (deux passes) ; les puissances sans monstre prennent
  l'interpolation de leurs voisines ; vie et dégâts absolus ne baissent jamais d'une puissance à la suivante.
Cas isolés, ensuite, comme au lot 3c (calibre_3c.py), dans solazeroth_v3_courbe_entrees : chaque entrée des secteurs,
simulée à sa puissance la plus fréquente avec la courbe ; seules celles hors de leur cible bougent (MARGE points en
deçà du bord) : monstre seul 15-30 %, élites et rares 30-60 % (durée 12-15 s quand gagnés au moins VICTOIRES fois sur
100). Dégâts entre F_MIN et F_MAX, puis vie entre V_MIN et V_MAX. Ce qu'aucun réglage ne rend battable (moins de 50 % de
victoires) garde la courbe seule.

py courbe_monstres.py            (réglage, puis migration 138)
py courbe_monstres.py --verifier (rapport des trois classes, courbe en base)
"""
import copy
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fiches_zones as fz
import puissance_tarides as pt
import simulation_camp as camp
import simulation_combat as sim
import simulation_sorts as ss
import tests_equilibrage as te

MIGRATION = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "sql", "migrations",
                         "138_v3_courbe_monstres")
PUISSANCES = range(15, 31)
REFERENCES = 4
DUREE = (12.0, 18.0)
CIBLES = {"seul": (15.0, 30.0), "élite": (30.0, 60.0)}
DUREE_ELITE = (12.0, 15.0)
MARGE = 3.0
F_MIN, F_MAX, V_MIN, V_MAX = 0.3, 2.0, 0.5, 2.0
VICTOIRES = 80
N, N_FINAL = 150, 400
POTION_DUROTAR = (1, 30, 0, 0)       # calibre_3c.POTION


def perdue(r):
    return te.perdue(r)


def regler(mesure, cible, bas, haut, croissant=True, pas=7):
    """Le facteur entre bas et haut pour lequel mesure(k) vaut cible (mesure croissante en k si croissant)."""
    for _ in range(pas):
        k = (bas + haut) / 2
        if (mesure(k) > cible) == croissant:
            haut = k
        else:
            bas = k
    return round((bas + haut) / 2, 3)


def reference_durotar(p):
    """(vie perdue, durée) à Durotar au même point de la zone que la puissance p des Tarides."""
    d = 1 + (p - 14) * 9 / 16
    puissances = {n: e for e, n in te.MONSTRES}
    dp = min(puissances, key=lambda k: abs(k - d))
    fiche = min((f for f in camp.fiches() if f.nom == "Sebiria"), key=lambda f: abs(f.puissance - d))
    m = ss.monstre_avec_sorts(puissances[dp], dp)
    r = ss.simuler(fiche, m, N_FINAL, potion=POTION_DUROTAR, heurt=te.HEURT if dp >= 3 else None)
    return perdue(r), r["duree"]


def mesurer(g, monstres, v, d, n=N):
    """Moyennes pondérées (vie perdue, durée, victoires) du guerrier contre ces monstres, courbe (v, d)."""
    total = poids = duree = victoires = 0.0
    for m, nombre in monstres:
        c = ss.courber(copy.deepcopy(m), (v, d))
        r = ss.simuler(g, c, n, potion=te.POTION_TARIDES, heurt=te.HEURT)
        total += perdue(r) * nombre
        duree += r["duree"] * nombre
        victoires += r["victoire"] * nombre
        poids += nombre
    return total / poids, duree / poids, victoires / poids


def toutes_les_entrees():
    """(entrée, nom, puissance, rang, nombre) des monstres des secteurs, sans doublon (la puissance la plus courante)."""
    vues = {}
    for s in range(1, len(pt.SECTEURS) + 1):
        for e, nom, p, rang, nombre in pt.monstres(s):
            if e not in vues or nombre > vues[e][4]:
                vues[e] = (e, nom, p, rang, nombre)
    return sorted(vues.values(), key=lambda x: (x[2], x[0]))


def regler_courbe(entrees):
    courbe, lignes = {}, []
    for p in PUISSANCES:
        ici = sorted((x for x in entrees if x[2] == p and x[3] == 0), key=lambda x: -x[4])[:REFERENCES]
        if not ici:
            continue
        ref_perdue, ref_duree = reference_durotar(p)
        cible = min(max(ref_perdue, CIBLES["seul"][0]), CIBLES["seul"][1])
        duree = min(max(ref_duree, DUREE[0]), DUREE[1])
        g = fz.joueurs(p)[0]
        monstres = [(ss.monstre_avec_sorts(e, p, contact=True), nombre) for e, _, _, _, nombre in ici]
        v, d = 1.0, 1.0
        avant = mesurer(g, monstres, 1.0, 1.0)
        for _ in range(2):
            v = regler(lambda k: mesurer(g, monstres, k, d)[1], duree, 0.2, 1.0)
            d = regler(lambda k: mesurer(g, monstres, v, k)[0], cible, 0.2, 1.0)
        apres = mesurer(g, monstres, v, d, N_FINAL)
        courbe[p] = (v, d)
        lignes.append("P%d (Durotar %.1f : %.1f %%, %.1f s) cible %.1f %% %.1f s | avant %.1f %% %.1f s | vie x%.3f "
                      "dégâts x%.3f | après %.1f %% %.1f s %.0f %% de victoires | %s" % (
                          p, 1 + (p - 14) * 9 / 16, ref_perdue, ref_duree, cible, duree, avant[0], avant[1], v, d,
                          apres[0], apres[1], apres[2], ", ".join(x[1][:18] for x in ici)))
        print(lignes[-1], flush=True)
    # Puissances sans monstre : interpolées ; puis jamais de remontée en montant.
    faites = sorted(courbe)
    for p in PUISSANCES:
        if p not in courbe:
            bas = max((k for k in faites if k < p), default=None)
            haut = min((k for k in faites if k > p), default=None)
            if bas is None or haut is None:
                courbe[p] = courbe[bas if haut is None else haut]
            else:
                f = (p - bas) / (haut - bas)
                courbe[p] = tuple(round(courbe[bas][i] + f * (courbe[haut][i] - courbe[bas][i]), 3) for i in (0, 1))
    # Jamais moins de vie ni de dégâts en montant : la vie et les dégâts de base d'un guerrier (classe 1) de Blizzard
    # multipliés par la courbe ne baissent pas d'une puissance à la suivante.
    base = {int(n): (float(v), float(d)) for n, v, d in sim.sql(
        "SELECT level, basehp0, damage_base FROM acore_world.creature_classlevelstats WHERE class = 1")}
    for p in PUISSANCES:
        if p - 1 not in courbe:       # la première ligne (15) : la courbe commence là
            continue
        avant = courbe[p - 1]
        courbe[p] = tuple(round(max(courbe[p][i], avant[i] * base[p - 1][i] / base[p][i]), 3) for i in (0, 1))
    return courbe, lignes


def categorie(rang):
    return "élite" if rang >= 1 else "seul"


def regler_entrees(entrees):
    """Cas isolés : (entrée, vie, dégâts) relatifs à la courbe, et les lignes du rapport."""
    corrections, lignes = {}, []
    for e, nom, p, rang, nombre in entrees:
        try:
            m0 = ss.monstre_avec_sorts(e, p, contact=True)
        except IndexError:
            continue
        if m0.vie <= 10:
            continue
        g = fz.joueurs(p)[0]
        base = sim.courbe(p) if p > 14 else (1.0, 1.0)
        cat = categorie(rang)
        bas, haut = CIBLES[cat]

        def essai(v, d, n=N):
            c = ss.courber(copy.deepcopy(m0), (base[0] * v, base[1] * d))
            return ss.simuler(g, c, n, potion=te.POTION_TARIDES, heurt=te.HEURT)

        depart = essai(1.0, 1.0, N_FINAL)
        v, d = 1.0, 1.0
        for _ in range(2):
            q = perdue(essai(v, d))
            if q > haut:
                if perdue(essai(v, F_MIN)) > haut - MARGE:
                    d = F_MIN
                    v = regler(lambda k: perdue(essai(k, d)), haut - MARGE, V_MIN, v)
                else:
                    d = regler(lambda k: perdue(essai(v, k)), haut - MARGE, F_MIN, d)
            elif q < bas:
                d = regler(lambda k: perdue(essai(v, k)), bas + MARGE, d, F_MAX)
            r = essai(v, d)
            if cat == "élite" and r["victoire"] >= VICTOIRES and not DUREE_ELITE[0] <= r["duree"] <= DUREE_ELITE[1]:
                but = DUREE_ELITE[0] + 1 if r["duree"] < DUREE_ELITE[0] else DUREE_ELITE[1] - 1
                v = regler(lambda k: essai(k, d)["duree"], but, V_MIN, V_MAX)
        fin = essai(v, d, N_FINAL)
        if fin["victoire"] < 50:
            lignes.append("%6d %-26s P%-2d %-5s laissé à la courbe : %3.0f %% de victoires au mieux" % (
                e, nom[:26], p, cat, fin["victoire"]))
            print(lignes[-1], flush=True)
            continue
        if abs(v - 1) > 1e-3 or abs(d - 1) > 1e-3:
            corrections[e] = (round(v, 3), round(d, 3))
            lignes.append("%6d %-26s P%-2d %-5s | courbe %5.1f %% %4.1f s %3.0f %% | vie x%.2f dégâts x%.2f | après "
                          "%5.1f %% %4.1f s %3.0f %%" % (e, nom[:26], p, cat, perdue(depart), depart["duree"],
                                                          depart["victoire"], v, d, perdue(fin), fin["duree"],
                                                          fin["victoire"]))
            print(lignes[-1], flush=True)
    return corrections, lignes


def ecrire(courbe, corrections):
    up = ["-- Lot T1 des Tarides (03/11/2026) : courbe des monstres selon la puissance (point 19 du brouillon), et",
          "-- corrections des cas isolés. Généré par outils\\courbe_monstres.py : ne pas modifier à la main.",
          "USE acore_world;",
          "DROP TABLE IF EXISTS solazeroth_v3_courbe_puissance, solazeroth_v3_courbe_entrees;",
          "CREATE TABLE solazeroth_v3_courbe_puissance (puissance TINYINT UNSIGNED NOT NULL PRIMARY KEY, vie FLOAT NOT "
          "NULL, degats FLOAT NOT NULL);",
          "INSERT INTO solazeroth_v3_courbe_puissance VALUES %s;" % ", ".join(
              "(%d, %.3f, %.3f)" % (p, v, d) for p, (v, d) in sorted(courbe.items())),
          "CREATE TABLE solazeroth_v3_courbe_entrees (entree INT UNSIGNED NOT NULL PRIMARY KEY, vie FLOAT NOT NULL, "
          "degats FLOAT NOT NULL);"]
    if corrections:
        up.append("INSERT INTO solazeroth_v3_courbe_entrees VALUES %s;" % ", ".join(
            "(%d, %.3f, %.3f)" % (e, v, d) for e, (v, d) in sorted(corrections.items())))
    up.append("")
    down = ["-- Retire la courbe des monstres (migration 138).", "USE acore_world;",
            "DROP TABLE IF EXISTS solazeroth_v3_courbe_puissance, solazeroth_v3_courbe_entrees;", ""]
    for suffixe, lignes in ((".up.sql", up), (".down.sql", down)):
        with open(MIGRATION + suffixe, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(lignes))
    print("Migration 138 écrite : %d puissances, %d entrées corrigées." % (len(courbe), len(corrections)))


def verifier():
    """Les trois classes avec la courbe en base, contre les monstres de chaque palier (tests_equilibrage)."""
    import simulation_demoniste as sd
    import simulation_voleur as sv
    for nom, puissance in te.PANOPLIES_TARIDES.items():
        g, dm, v = fz.joueurs(puissance)
        print("\nTarides, %s (puissance %d)" % (nom, puissance))
        for e, p in te.MONSTRES_TARIDES:
            if not puissance - 1 <= p <= puissance + 2:
                continue
            m = ss.monstre_avec_sorts(e, p, contact=True, courbe=True)
            mm = sim.courber(sd.monstre(e, p))
            rg = ss.simuler(g, m, N_FINAL, potion=te.POTION_TARIDES, heurt=te.HEURT)
            rd = sd.simuler(dm, [mm], N_FINAL, potion=te.POTION_TARIDES)
            rv = sv.simuler(v, [mm], N_FINAL, potion=te.POTION_TARIDES)
            print("  %-26s P%-2d | guerrier %5.1f %% %4.1f s | démoniste %5.1f %% %4.1f s | voleur %5.1f %% %4.1f s" % (
                m.nom[:26], p, perdue(rg), rg["duree"], perdue(rd), rd["duree"], perdue(rv), rv["duree"]))


def main():
    if "--verifier" in sys.argv:
        verifier()
        return
    entrees = toutes_les_entrees()
    sim.COURBE, sim.COURBE_ENTREES = {}, {}
    courbe, _ = regler_courbe(entrees)
    print("Courbe :", ", ".join("%d : %.2f / %.2f" % (p, v, d) for p, (v, d) in sorted(courbe.items())), flush=True)
    sim.COURBE = dict(courbe)
    corrections, _ = regler_entrees(entrees)
    ecrire(courbe, corrections)


if __name__ == "__main__":
    main()
