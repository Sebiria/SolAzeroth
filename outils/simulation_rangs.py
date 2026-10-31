# Outil de calibrage (01/11/2026), lancé avec py simulation_rangs.py.
# Simulation d'économie des rangs : le joueur gagne des éclats au fil du pourcentage de zone, change d'équipement à
# chaque secteur (8 pièces, rang 0) et améliore au plus tôt la pièce la moins chère. On regarde la puissance obtenue.
# Revenu mesuré sur la partie de Test : ~500 éclats pour 27,7 % (monstres, élites, défis), soit ~18 éclats par %.
REVENU = 18
SECTEURS = [  # (début %, fin %, niveau d'objet moyen du nouvel équipement, puissance des monstres)
    ("Vallée", 0, 8, 3.0, "2-4"),
    ("Tranchecolline", 8, 25, 6.0, "5-6"),
    ("Sud", 25, 45, 7.5, "8-9"),
    ("Nord", 45, 65, 9.0, "9-10"),
    ("Gouffre et fin", 65, 100, 10.0, "11-12"),
]


def simuler(couts, rang_max=3):
    reserve, lignes = 0.0, []
    for nom, debut, fin, niveau, cible in SECTEURS:
        rangs = [0] * 8
        pmin = None
        for pct in range(debut, fin):
            reserve += REVENU
            while True:
                i = min(range(8), key=lambda k: rangs[k])
                if rangs[i] >= rang_max or reserve < couts[rangs[i]]:
                    break
                reserve -= couts[rangs[i]]
                rangs[i] += 1
            puissance = niveau * (1 + 0.1 * sum(rangs) / 8)
            if pmin is None:
                pmin = puissance
            if pct == (debut + fin) // 2:
                pmil = puissance
        lignes.append(f"  {nom:15} monstres {cible:5} | entrée {pmin:4.1f}  milieu {pmil:4.1f}  fin {puissance:4.1f}"
                      f"  (rangs moyens {sum(rangs) / 8:.1f}, réserve {reserve:.0f})")
    return lignes


for titre, couts in [("Actuel 5/10/20", [5, 10, 20]), ("x2 10/20/40", [10, 20, 40]),
                     ("x3 15/30/60", [15, 30, 60]), ("x4 20/40/80", [20, 40, 80])]:
    print(titre)
    print("\n".join(simuler(couts)))
