# Outil de calibrage (01/11/2026), lancé avec py simulation_ame.py.
# Simulation du rythme de perte de l'âme (F10, v3_ame.cpp) : le joueur avance de % en % à travers les zones, meurt au
# hasard selon son profil, et régénère son âme en auberge dès qu'elle passe sous un seuil, avec ses éclats.
# On regarde l'âme la plus basse atteinte, la part du revenu d'éclats partie dans l'âme, et le risque d'extinction.
# Revenu : ~18 éclats par % à Durotar (simulation_rangs.py), multiplié comme le butin des monstres au-delà de la
# puissance 12 (v3_collection.cpp : 1 + (niveau - 12) / 12).
import math
import random

AME_MAX = 100
PERTE_MAX = 10
PUISSANCE_PAR_PERTE = 15
ECLATS_PAR_POINT = 4
REVENU = 18

# (nom, puissance à l'entrée, puissance à la sortie) : Durotar d'après simulation_rangs.py, puis des zones
# hypothétiques jusqu'à la fin du jeu (niveau d'objet ~200).
ZONES = [("Durotar", 3, 14), ("Zone 2", 14, 22), ("Zone 3", 22, 32), ("Zone 4", 32, 45), ("Zone 5", 45, 60),
         ("Zone 6", 60, 80), ("Zone 7", 80, 105), ("Zone 8", 105, 135), ("Zone 9", 135, 165), ("Zone 10", 165, 200)]

# Morts par % de zone. Prudent : une mort tous les 10 %. Moyen : tous les 4 %. Téméraire : plus d'une tous les 2 %.
PROFILS = [("Prudent", 0.10), ("Moyen", 0.25), ("Téméraire", 0.6)]
SEUIL = 70           # le joueur régénère en auberge sous ce seuil
AUBERGE_TOUS = 5     # il passe en auberge tous les 5 %
PART_MAX = 0.5       # et n'y consacre au plus que la moitié de sa réserve d'éclats (le reste va aux rangs)
ESSAIS = 2000


def facteur(p):
    return 1 + max(0, p - 12) / 12


def perte(p):
    return min(PERTE_MAX, 1 + int(p // PUISSANCE_PAR_PERTE))


def prix(p):
    return int(ECLATS_PAR_POINT * facteur(p) + 0.5)


def poisson(lam):
    seuil, k, prod = math.exp(-lam), 0, random.random()
    while prod > seuil:
        k += 1
        prod *= random.random()
    return k


def partie(taux):
    ame, reserve, eteinte = AME_MAX, 0.0, None
    par_zone = []
    for nom, debut, fin in ZONES:
        revenu = depense = morts = 0
        ame_min = ame
        for pct in range(100):
            p = debut + (fin - debut) * pct / 100
            gain = REVENU * facteur(p)
            revenu += gain
            reserve += gain
            for _ in range(poisson(taux)):
                morts += 1
                ame = max(0, ame - perte(p))
                ame_min = min(ame_min, ame)
                if ame == 0 and eteinte is None:
                    eteinte = f"{nom} {pct} %"
            if ame == 0:
                break
            if pct % AUBERGE_TOUS == AUBERGE_TOUS - 1 and ame < SEUIL:
                points = min(AME_MAX - ame, int(reserve * PART_MAX // prix(p)))
                ame += points
                reserve -= points * prix(p)
                depense += points * prix(p)
        par_zone.append((nom, morts, ame_min, depense / revenu if revenu else 0))
        if ame == 0:
            break
    return par_zone, eteinte


def tableau_chiffres():
    print("Puissance | perte par mort | éclats par point | coût d'une mort | revenu par % | morts de 100 à 0")
    for p in [3, 8, 12, 14, 20, 30, 45, 60, 80, 105, 135, 165, 200]:
        c = perte(p) * prix(p)
        print(f"  {p:4}    | {perte(p):6}         | {prix(p):6}           | {c:6}          | {REVENU * facteur(p):6.0f}"
              f"       | {math.ceil(AME_MAX / perte(p)):4}")


def profils():
    random.seed(10)
    for nom_profil, taux in PROFILS:
        resultats = [partie(taux) for _ in range(ESSAIS)]
        eteintes = [e for _, e in resultats if e]
        print(f"\n{nom_profil} ({taux} mort par %) : âme éteinte dans {100 * len(eteintes) / ESSAIS:.1f} % des parties")
        print("  Zone      | morts (moy.) | âme la plus basse (médiane, 5e centile) | part du revenu en âme (moy.)")
        for i, (nom, _, _) in enumerate(ZONES):
            lignes = [r[0][i] for r in resultats if len(r[0]) > i]
            if not lignes:
                break
            minima = sorted(l[2] for l in lignes)
            print(f"  {nom:9} | {sum(l[1] for l in lignes) / len(lignes):6.1f}       | "
                  f"{minima[len(minima) // 2]:4} / {minima[len(minima) // 20]:4}"
                  f"                          | {100 * sum(l[3] for l in lignes) / len(lignes):5.1f} %")


def sans_regeneration():
    print("\nSans jamais régénérer (profil Moyen) : % de zone parcourus avant l'extinction, en partant de 100")
    for nom, debut, fin in ZONES:
        p = (debut + fin) / 2
        morts = math.ceil(AME_MAX / perte(p))
        print(f"  {nom:9} (puissance {p:5.1f}) : {morts:3} morts, soit ~{morts / 0.25:5.0f} % de zone")


tableau_chiffres()
profils()
sans_regeneration()
