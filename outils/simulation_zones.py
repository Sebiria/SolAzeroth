"""Audit du jeu, lot 7 (02/11/2026) : économie des éclats sur trois zones (P8 du game designer systèmes ; choix de
l'utilisateur : Durotar avec ses vrais chiffres, puis les Tarides 11-25 et une zone 26-40 extrapolées par le gabarit).

Question : quand les coûts des rangs sont multipliés par (1 + (P − 12) / 12) au-delà de la puissance 12, le revenu
suit-il ? Le joueur traverse les zones du gabarit (gabarit_zone.ZONES) secteur par secteur, comme simulation_rangs.py :
8 pièces neuves à chaque secteur (ou gardant leur rang moins un, « transfert », lot 4b), la pièce la moins améliorée
d'abord, tant qu'éclats, or et pierres taillées le permettent.

Revenu d'un % de zone : éclats_par_pourcent (18, mesuré à Durotar) × taille de la zone (plus de monstres par % dans une
zone plus large) × facteur de la puissance des monstres du secteur, car les éclats des monstres suivent le même facteur
que les coûts (v3_collection.cpp Eclats). L'or suit la même règle (hypothèse : les primes en or des quêtes et annexes
montent avec la zone). Les pierres taillées viennent des filons (--filons par % de zone, sans facteur : leur nombre par
rang est fixe). Les heures : 70 éclats par heure à Durotar (rapport de l'artisan de l'audit, ~60 monstres par heure).
Lancé avec py simulation_zones.py [--filons 0 1 2].
"""
import argparse

import gabarit_zone
from simulation_rangs import BRUTES_PAR_PIERRE, PIECES, PIERRES_PAR_RANG, PROSPECTION, cout, gemmes_par_filon

ECLATS_PAR_HEURE = 70          # à Durotar (facteur 1)
PAR_RANG = 0.1                 # SolAzeroth.V3.PuissanceParRang


def simuler(zones, filons_par_pourcent, transfert, rang_max=5):
    reserve, ors = 0.0, 0.0
    gemmes = {g: 0.0 for g in PROSPECTION}
    par_filon = gemmes_par_filon()
    rangs = [0] * PIECES
    resultats = []
    for zone in zones:
        eco = zone["economie"]
        gagne = depense = heures = 0.0
        lignes = []
        for nom, debut, fin, (pa, pb), niveau in zone["secteurs"]:
            rangs = [max(0, r - 1) for r in rangs] if transfert else [0] * PIECES
            f_monstres = gabarit_zone.facteur((pa + pb) / 2)
            revenu = eco["eclats_par_pourcent"] * eco["taille"] * f_monstres
            # Lot T0 des Tarides : bornes non entières (19,3 %…). Un pas par % de zone, le dernier au prorata ; aux
            # bornes entières (Durotar), rien ne change.
            largeur = fin - debut
            pas = [1.0] * int(largeur + 1e-9)
            if largeur - len(pas) > 1e-9:
                pas.append(largeur - len(pas))
            for part in pas:
                reserve += revenu * part
                gagne += revenu * part
                ors += eco["or_par_pourcent"] * eco["taille"] * f_monstres * part
                heures += eco["eclats_par_pourcent"] * eco["taille"] / ECLATS_PAR_HEURE * part
                for g in gemmes:
                    gemmes[g] += filons_par_pourcent * par_filon[g] * part
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
                    depense += eclats
                    ors -= prix
                    for g, n in besoin.items():
                        gemmes[g] -= n
                    rangs[i] = vers
            moyen = sum(rangs) / PIECES
            lignes.append(f"    {nom:15} monstres {pa:4.1f}-{pb:4.1f}, objets {niveau:4.1f} (coût × "
                          f"{gabarit_zone.facteur(niveau):.2f}) : rangs moyens {moyen:.1f}, puissance "
                          f"{niveau * (1 + PAR_RANG * moyen):4.1f}, réserve {reserve:.0f} éclats")
        resultats.append((zone, lignes, sum(rangs) / PIECES, gagne, depense, reserve, heures))
    return resultats


def main():
    parser = argparse.ArgumentParser(description="Économie des éclats sur trois zones")
    parser.add_argument("--filons", type=float, nargs="*", default=[0.0, 1.0, 2.0],
                        help="filons minés par %% de zone pour les pierres des rangs 4 et 5")
    args = parser.parse_args()
    for filons in args.filons:
        for transfert in (False, True):
            print(f"{filons:g} filon(s) par % de zone" + (", rang transféré (rang − 1)" if transfert else ""))
            for zone, lignes, moyen, gagne, depense, reserve, heures in simuler(gabarit_zone.ZONES, filons, transfert):
                p0, p1 = zone["plage"]
                print(f"  {zone['nom']} ({p0}-{p1}), {heures:.0f} h : {gagne:.0f} éclats gagnés, {depense:.0f} dépensés "
                      f"({100 * depense / gagne:.0f} %), rangs moyens en fin de zone {moyen:.1f}")
                print("\n".join(lignes))
            print()


if __name__ == "__main__":
    main()
