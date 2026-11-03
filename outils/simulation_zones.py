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
Lot T8 des Tarides (03/11/2026) : chaque zone a sa joaillerie. Les pièces de puissance 15 ou plus paient leurs rangs 4
et 5 en pierres des Tarides (solazeroth_v3_rangs_pierres, puissance 15 : 2 Agates mousse taillées et 1 Jade taillé,
puis 2 Jades taillés et 1 Pierre de lune taillée), tirées de l'étain (3 Minerais d'étain par prospection : Agate
mousse 33 %, Jade 52 %, Pierre de lune inférieure 15 %). Aux Tarides, 138 des 200 filons sont d'étain ou d'argent
(304 Minerais d'étain sur 138 filons, soit 2,2 par filon, brouillon §4.7.5) et les autres de cuivre ; Durotar ne change pas.
Lot T7 des Tarides (03/11/2026) : les vraies bornes des secteurs (lot T0) ; le donjon ne compte pas dans le
pourcentage de zone (il vaut 0 %), ses éclats ne sont donc pas dans ce revenu. Bilan de fin (bilan()) pour chaque zone
construite : Marques gagnées et dépensées dans la zone (relues en base : annexes tous paliers, reliques, lieux ; camp,
carte des reliques), et or du modèle de zone comparé à l'or de référence, 3 po par heure × le facteur de puissance
(décision 5 du brouillon des Tarides, fournisseur_v3.OR_PAR_HEURE).
Lancé avec py simulation_zones.py [--filons 0 1 2].
"""
import argparse

import fournisseur_v3
import gabarit_zone
from simulation_rangs import (BRUTES_PAR_PIERRE, CHANCE_GEMME_FILON, MINERAI_PAR_FILON, MINERAI_PAR_PROSPECTION, PIECES,
                              PIERRES_PAR_RANG, PROSPECTION, cout)

ECLATS_PAR_HEURE = 70          # à Durotar (facteur 1)
PAR_RANG = 0.1                 # SolAzeroth.V3.PuissanceParRang

# Lot T8 des Tarides : pierres des rangs 4 et 5 par puissance minimale de la pièce (artisanat_tarides.py), et
# minerais de chaque zone : (part des filons, minerai par filon, minerai par prospection, chances des gemmes).
PIERRES_PAR_PALIER = {0: PIERRES_PAR_RANG, 15: {4: {"agate": 2, "jade": 1}, 5: {"jade": 2, "lune": 1}}}
CUIVRE = (1.0, MINERAI_PAR_FILON, MINERAI_PAR_PROSPECTION, PROSPECTION)
ETAIN = (138 / 200, 2.2, 3, {"agate": 0.33, "jade": 0.52, "lune": 0.15})
MINERAIS = {"Durotar": [CUIVRE], "Les Tarides": [(62 / 200,) + CUIVRE[1:], ETAIN]}


def gemmes_par_filon(zone):
    """Gemmes brutes de chaque sorte par filon de la zone, tout le minerai prospecté (simulation_rangs.py pour
    Durotar). Une zone sans relevé prend les minerais de la précédente (la zone 3 fictive, ceux des Tarides)."""
    minerais = MINERAIS.get(zone["nom"]) or MINERAIS["Les Tarides"]
    gemmes = {}
    for part, par_filon, par_prospection, chances in minerais:
        for g, c in chances.items():
            gemmes[g] = gemmes.get(g, 0.0) + part * (CHANCE_GEMME_FILON + par_filon / par_prospection * c)
    return gemmes


def pierres_du_rang(niveau, vers):
    palier = max(p for p in PIERRES_PAR_PALIER if niveau >= p)
    return PIERRES_PAR_PALIER[palier].get(vers, {})


def simuler(zones, filons_par_pourcent, transfert, rang_max=5):
    reserve, ors = 0.0, 0.0
    gemmes = {}
    rangs = [0] * PIECES
    resultats = []
    for zone in zones:
        eco = zone["economie"]
        par_filon = gemmes_par_filon(zone)
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
                for g in par_filon:
                    gemmes[g] = gemmes.get(g, 0.0) + filons_par_pourcent * par_filon[g] * part
                while True:
                    i = min(range(PIECES), key=lambda k: rangs[k])
                    vers = rangs[i] + 1
                    if vers > rang_max:
                        break
                    eclats, prix = cout(niveau, vers)
                    besoin = {g: n * BRUTES_PAR_PIERRE for g, n in pierres_du_rang(niveau, vers).items()}
                    if reserve < eclats or ors < prix or any(gemmes.get(g, 0.0) < n for g, n in besoin.items()):
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


MARQUES_RELIQUE, NOEUD_FEU_1 = 5, 15     # v3_annexes.cpp (par relique), v3_bivouac.cpp (feu 1, à Durotar)


def bilan():
    """Marques et or de chaque zone construite (zone_parts en base)."""
    sql = gabarit_zone.sql
    print("Bilan des Marques et de l'or (zones construites ; Marques sans le facteur de puissance)")
    for zone in gabarit_zone.ZONES:
        z = zone["zone"]
        if z is None or not sql(f"SELECT 1 FROM solazeroth_v3_zone_parts WHERE zone = {z} LIMIT 1"):
            continue
        annexes = int(sql(f"SELECT COALESCE(SUM(insignes), 0) FROM solazeroth_v3_annexes WHERE zone = {z}")[0][0])
        reliques = MARQUES_RELIQUE * int(sql(f"SELECT COUNT(*) FROM solazeroth_v3_reliques WHERE zone = {z}")[0][0])
        lieux = int(sql(f"SELECT COALESCE(SUM(r.marques), 0) FROM solazeroth_v3_lieux_recompenses r JOIN "
                        f"solazeroth_v3_zone_parts p ON p.genre = 3 AND p.cle = r.lieu WHERE p.zone = {z}")[0][0])
        camp = int(sql(f"SELECT COALESCE(SUM(c.nombre), 0) FROM solazeroth_v3_camp_couts c JOIN solazeroth_v3_camp_rangs r "
                       f"ON r.genre = c.genre AND r.rang = c.rang WHERE r.zone = {z} AND c.objet = 37711")[0][0])
        camp += NOEUD_FEU_1 if sql(f"SELECT 1 FROM solazeroth_v3_camp_rangs WHERE zone = {z} AND genre = 2 AND rang = 1") else 0
        carte = sql(f"SELECT marques FROM solazeroth_v3_reliques_cartes WHERE zone = {z}")
        carte = int(carte[0][0]) if carte else 0
        gagne = annexes + reliques + lieux
        print(f"  {zone['nom']} : {gagne} Marques gagnées (annexes {annexes}, reliques {reliques}, lieux {lieux}), "
              f"{camp + carte} dépensées dans la zone (camp {camp}, carte des reliques {carte}) ; reste {gagne - camp - carte} "
              f"pour les montures et les passifs")
        eco = zone["economie"]
        modele = reference = heures = 0.0
        for _, debut, fin, (pa, pb), _ in zone["secteurs"]:
            f = gabarit_zone.facteur((pa + pb) / 2)
            modele += eco["or_par_pourcent"] * eco["taille"] * f * (fin - debut)
            h = eco["eclats_par_pourcent"] * eco["taille"] / ECLATS_PAR_HEURE * (fin - debut)
            heures += h
            reference += fournisseur_v3.OR_PAR_HEURE * f * h
        print(f"    or : modèle de zone {modele / 10000:.0f} po en {heures:.0f} h, référence (3 po par heure × facteur) "
              f"{reference / 10000:.0f} po")


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
    bilan()


if __name__ == "__main__":
    main()
