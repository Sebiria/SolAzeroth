"""Lot T8 des Tarides (03/11/2026) : les pièces vertes des Tarides tiennent-elles la fiche du joueur ?

Les monstres des Tarides sont réglés (courbe_monstres.py) contre la fiche de chaque point de la zone
(fiches_zones.joueurs(P) : les pièces d'arrivée refaites au barème de la puissance P). Ici, le même guerrier, le même
démoniste et le même voleur portent de vraies pièces : à chaque emplacement des bleues du Gouffre, la meilleure pièce
qu'il peut fabriquer, c'est-à-dire la verte des Tarides (artisanat_tarides.py, migration 141) de plus haut niveau
d'objet dont la puissance requise ne dépasse pas la sienne, sinon la bleue du Gouffre. Le bâton (deux mains) n'est pas
essayé : il vaut la dague et l'orbe de sa puissance.

Chaque point est (puissance du joueur quand il fabrique, puissance des monstres). Les sauts du récit sont compris :
16 -> 18 (de la Croisée aux oasis) et 22 -> 25 (des oasis au sud) : le joueur fabrique encore à 16 (ou 22) et affronte
déjà les monstres de 18 (ou 25). Monstres : ceux de tests_equilibrage.MONSTRES_TARIDES de cette puissance, au contact,
avec la courbe en base.

Deux lectures : les pièces au rang 0, comme la fiche (écart de niveau d'objet seul), puis au rang RANG (toutes les
pièces portées, vertes et bleues), en deçà de ce que simulation_zones.py donne à la fin de chaque secteur (rangs moyens
3 et plus avec 1 ou 2 filons par % de zone). Tenu : au rang RANG, vie perdue au plus ECART points au-dessus de la fiche
(rang 0), pour les trois classes ; le rang 0 est affiché pour mesurer l'écart.

py simulation_vertes_tarides.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import courbe_monstres as cm
import equipement_v3 as e3
import fiches_zones as fz
import gabarit_zone as gz
import simulation_combat as sim
import simulation_sorts as ss
import tests_equilibrage as te

POINTS = [(14, 14), (16, 16), (16, 18), (18, 18), (22, 22), (22, 25), (25, 25), (27, 27), (30, 30)]
ECART = 5.0          # points de vie perdue au-dessus de la fiche, tolérés
RANG = 2             # rang des pièces portées pour la lecture qui décide
N = 400
PREMIERE, DERNIERE = 910500, 910595
UNE_MAIN = {13, 21, 22}
TORSE = {5, 20}


def objets(entrees):
    liste = ", ".join(str(e) for e in entrees)
    return {int(e): (int(c), int(s), int(t), int(n), int(r)) for e, c, s, t, n, r in gz.sql(
        "SELECT entry, class, subclass, InventoryType, ItemLevel, RequiredLevel FROM item_template "
        "WHERE entry IN (%s)" % liste)}


def requises():
    """{pièce verte : puissance requise}, lue dans le générateur (la base garde le niveau requis de Blizzard)."""
    import artisanat_tarides
    return {p[0]: p[5] for p in artisanat_tarides.pieces()}


def meme_place(a, b):
    """Deux pièces vont au même emplacement et sont de la même sorte (armure de même type, ou arme de même famille)."""
    (ca, sa, ta, *_), (cb, sb, tb, *_) = a, b
    if ca != cb:
        return False
    if ca == 4:
        return sa == sb and (ta == tb or {ta, tb} <= TORSE)
    return sa == sb and (ta == tb or {ta, tb} <= UNE_MAIN)


def panoplie(spe, puissance, vertes, infos, requise):
    """Pièces portées par spe à cette puissance de fabrication, et leur niveau moyen."""
    sortie = []
    for bleue in fz.GOUFFRE[spe]:
        choix = [v for v in vertes if requise[v] <= puissance and meme_place(infos[v], infos[bleue])
                 and infos[v][3] > infos[bleue][3]]
        sortie.append(max(choix, key=lambda v: (infos[v][3], -v)) if choix else bleue)
    return sortie, sum(infos[e][3] for e in sortie) / len(sortie)


def au_rang(pieces, rang):
    return {spe: [e3.entree_rang(e, rang) if rang else e for e in liste] for spe, liste in pieces.items()}


def joueurs_reels(pieces):
    import simulation_camp as camp
    import simulation_demoniste as sd
    import simulation_voleur as sv
    sebiria = max((f for f in camp.fiches() if f.nom == "Sebiria"), key=lambda f: f.puissance)
    g = camp.repos(sim.equiper(sebiria, pieces["guerrier_tank"], fz.SEBIRIA), fz.REPOS)
    d = sd.renforce(sd.demoniste(pieces["demoniste_affliction"], fz.SEBIRIA, repas=fz.REPOS))
    v = sv.renforce(sv.voleur(pieces["voleur_assassinat"], fz.SEBIRIA, g.critique, repas=fz.REPOS))
    return g, d, v


def resultats(joueurs, entree, p):
    import simulation_demoniste as sd
    import simulation_voleur as sv
    g, d, v = joueurs
    m = ss.monstre_avec_sorts(entree, p, contact=True, courbe=True)
    mm = sim.courber(sd.monstre(entree, p))
    return (cm.perdue(ss.simuler(g, m, N, potion=te.POTION_TARIDES, heurt=te.HEURT)),
            cm.perdue(sd.simuler(d, [mm], N, potion=te.POTION_TARIDES)),
            cm.perdue(sv.simuler(v, [mm], N, potion=te.POTION_TARIDES))), m.nom


def main():
    vertes = list(range(PREMIERE, DERNIERE + 1))
    infos = objets(vertes + [e for liste in fz.GOUFFRE.values() for e in liste])
    requise = requises()
    classes = ("guerrier", "démoniste", "voleur")
    problemes = []
    for fabrique, p in POINTS:
        pieces, moyennes = {}, {}
        for spe in fz.SPECIALISATIONS:
            pieces[spe], moyennes[spe] = panoplie(spe, fabrique, vertes, infos, requise)
        reels = joueurs_reels(pieces)
        montes = joueurs_reels(au_rang(pieces, RANG))
        fiche = fz.joueurs(p)
        print("\nFabrique à %d, monstres de %d : niveau moyen des pièces %s" % (fabrique, p, ", ".join(
            "%s %.1f" % (c, moyennes[s]) for c, s in zip(classes, fz.SPECIALISATIONS)))
              + " ; vie perdue au rang 0 / au rang %d" % RANG)
        for entree, pm in te.MONSTRES_TARIDES:
            if pm != p:
                continue
            reel, nom = resultats(reels, entree, pm)
            monte, _ = resultats(montes, entree, pm)
            ref, _ = resultats(fiche, entree, pm)
            print("  %-26s | " % nom[:26] + " | ".join(
                "%s %4.1f / %4.1f %% (fiche %4.1f)" % (c, a, m, b) for c, a, m, b in zip(classes, reel, monte, ref)))
            for c, m, b in zip(classes, monte, ref):
                if m > b + ECART:
                    problemes.append("%s, fabrique à %d contre %s (%d) : %.1f %% de vie perdue au rang %d, fiche %.1f %%"
                                     % (c, fabrique, nom, pm, m, RANG, b))
    print()
    if problemes:
        print("Ne tient pas la fiche :")
        for p in problemes:
            print("  " + p)
    else:
        print("Au rang %d, les pièces vertes tiennent la fiche à chaque point, pour les trois classes (écart toléré %g "
              "points)." % (RANG, ECART))


if __name__ == "__main__":
    main()
