# Outil de calibrage (01/11/2026), lancé avec py simulation_rangs.py.
# Simulation d'économie des rangs : le joueur gagne des éclats, de l'or et des gemmes au fil du pourcentage de zone,
# change d'équipement à chaque secteur (8 pièces) et améliore au plus tôt la pièce la moins chère. On regarde la
# puissance obtenue.
# Revenu mesuré sur la partie de Test : ~500 éclats pour 27,7 % (monstres, élites, défis), soit ~18 éclats par %.
#
# Audit du jeu, lot 2 (02/11/2026) : la simulation s'arrêtait au rang 3 et ne comptait que les éclats. Elle suit
# maintenant le serveur jusqu'au rang 5 :
# - éclats et or de chaque rang (ECLATS_PAR_RANG et OR_PAR_RANG de v3_equipement.cpp, plus chers au-delà de la
#   puissance 12) ;
# - pierres taillées des rangs 4 et 5 (solazeroth_v3_rangs_pierres), comptées en filons de cuivre : un filon donne en
#   moyenne 2,5 minerais (1 à 4) et 5 % de chances de chaque gemme brute ; 5 minerais se prospectent en une gemme
#   (Malachite 55 %, Œil de tigre 35 %, Œil ténébreux 10 %) ; une pierre taillée demande 2 gemmes de sa sorte ;
# - option « transfert » : à chaque changement de secteur, la nouvelle pièce garde le rang de l'ancienne moins un
#   (proposition C6 de « Audit du jeu\10_consensus.md », pas construite).
# À mesurer en jeu : le nombre de filons minés par % de zone (--filons n'est qu'une hypothèse) ; l'or (OR_PAR_POURCENT)
# est estimé d'après le rapport de l'artisan de l'audit (environ 27 po pour tout Durotar).
import argparse

REVENU = 18                 # éclats par % de zone
OR_PAR_POURCENT = 2700      # cuivre par % de zone (environ 27 po sur Durotar)
SECTEURS = [  # (début %, fin %, niveau d'objet moyen du nouvel équipement, puissance des monstres)
    ("Vallée", 0, 8, 3.0, "2-4"),
    ("Tranchecolline", 8, 25, 6.0, "5-6"),
    ("Sud", 25, 45, 7.5, "8-9"),
    ("Nord", 45, 65, 9.0, "9-10"),
    ("Gouffre et fin", 65, 100, 10.0, "11-12"),
]
PIECES = 8

# Serveur (v3_equipement.cpp, joaillerie_v3.py, migration 085).
ECLATS_PAR_RANG = [15, 30, 60, 105, 180]
OR_PAR_RANG = [60, 120, 240, 480, 960]                  # cuivre
PIERRES_PAR_RANG = {4: {"malachite": 2, "tigre": 1}, 5: {"tigre": 2, "tenebreux": 1}}
BRUTES_PAR_PIERRE = 2
MINERAI_PAR_FILON, CHANCE_GEMME_FILON = 2.5, 0.05
MINERAI_PAR_PROSPECTION = 5
PROSPECTION = {"malachite": 0.55, "tigre": 0.35, "tenebreux": 0.10}


def cout(niveau, vers):
    facteur = 1.0 + max(0, int(niveau) - 12) / 12.0
    return int(ECLATS_PAR_RANG[vers - 1] * facteur + 0.5), int(OR_PAR_RANG[vers - 1] * facteur + 0.5)


def gemmes_par_filon():
    """Gemmes brutes de chaque sorte par filon, tout le minerai prospecté."""
    return {g: CHANCE_GEMME_FILON + MINERAI_PAR_FILON / MINERAI_PAR_PROSPECTION * c for g, c in PROSPECTION.items()}


def filons_pour_rang(vers):
    """Filons qu'il faut pour les pierres du rang (la gemme la plus rare fixe le nombre)."""
    besoin = PIERRES_PAR_RANG.get(vers)
    if not besoin:
        return 0.0
    par_filon = gemmes_par_filon()
    return max(n * BRUTES_PAR_PIERRE / par_filon[g] for g, n in besoin.items())


def simuler(rang_max=5, filons_par_pourcent=0.0, transfert=False, revenu=REVENU):
    reserve, ors, gemmes = 0.0, 0.0, {g: 0.0 for g in PROSPECTION}
    par_filon = gemmes_par_filon()
    lignes, rangs = [], [0] * PIECES
    for nom, debut, fin, niveau, cible in SECTEURS:
        rangs = [max(0, r - 1) for r in rangs] if transfert else [0] * PIECES
        pmin = pmil = None
        for pct in range(debut, fin):
            reserve += revenu
            ors += OR_PAR_POURCENT
            for g in gemmes:
                gemmes[g] += filons_par_pourcent * par_filon[g]
            while True:
                i = min(range(PIECES), key=lambda k: rangs[k])
                vers = rangs[i] + 1
                if vers > rang_max:
                    break
                eclats, prix = cout(niveau, vers)
                besoin = {g: n * BRUTES_PAR_PIERRE for g, n in PIERRES_PAR_RANG.get(vers, {}).items()}
                if reserve < eclats or ors < prix or any(gemmes[g] < n for g, n in besoin.items()):
                    break
                reserve -= eclats
                ors -= prix
                for g, n in besoin.items():
                    gemmes[g] -= n
                rangs[i] = vers
            puissance = niveau * (1 + 0.1 * sum(rangs) / PIECES)
            if pmin is None:
                pmin = puissance
            if pct == (debut + fin) // 2:
                pmil = puissance
        lignes.append(f"  {nom:15} monstres {cible:5} | entrée {pmin:4.1f}  milieu {pmil:4.1f}  fin {puissance:4.1f}"
                      f"  (rangs moyens {sum(rangs) / PIECES:.1f}, réserve {reserve:.0f} éclats, {ors / 10000:.1f} po)")
    return lignes


def main():
    parser = argparse.ArgumentParser(description="Économie des rangs d'objet")
    parser.add_argument("--filons", type=float, nargs="*", default=[0.0, 1.0, 2.0],
                        help="filons minés par %% de zone pour la joaillerie (hypothèses à essayer)")
    args = parser.parse_args()

    print("Coût d'une pièce de Durotar (puissance 12 ou moins), du rang 0 au rang 5 :")
    total_e = total_o = total_f = 0
    for vers in range(1, 6):
        e, o = cout(10, vers)
        f = filons_pour_rang(vers)
        total_e, total_o, total_f = total_e + e, total_o + o, total_f + f
        print(f"  rang {vers} : {e:3d} éclats, {o / 100:5.2f} pa, {f:4.1f} filons de pierres"
              f"   (cumul {total_e} éclats, {total_o / 100:.2f} pa, {total_f:.0f} filons)")
    print(f"  Revenu : {REVENU} éclats et {OR_PAR_POURCENT / 100:.0f} pa par % de zone.\n")

    for filons in args.filons:
        for transfert in (False, True):
            titre = f"{filons:g} filon(s) par % pour la joaillerie" + (", rang transféré (rang - 1)" if transfert else "")
            print(titre)
            print("\n".join(simuler(filons_par_pourcent=filons, transfert=transfert)))


if __name__ == "__main__":
    main()
