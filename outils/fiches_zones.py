"""Lot T0 des Tarides (03/11/2026) : fiches d'arrivée et de sortie des zones, lues par les simulations.

Décision 8 du comparatif avec Durotar (03/11/2026) : une zone se calibre sur le joueur qui arrive « full stuff bleu
rang 0, sans compter les récompenses des rares » du donjon précédent. Chaque fiche dit :
- les pièces portées, par spécialisation (entrées d'item_template, toutes au rang 0) : à donner telles quelles à
  simulation_combat.equiper (le personnage du journal, ses pièces remplacées par celles-ci) ;
- la puissance attendue : la moyenne des niveaux d'objet portés (CalculerPuissance, v3_combat.cpp) ;
- les techniques et emplacements de techniques acquis, le camp (feu, potion) : ceux de la fin de la zone précédente,
  lus dans le gabarit (gabarit_zone.py).
Les objets des rares secrets (rares_secrets_v3.EXCLUS) n'y sont jamais.

- ARRIVEE_TARIDES : les bleues du Gouffre de Ragefeu (equipement_gouffre_v3, puissance 14), 11 pièces : puissance 14,0.
- SORTIE_TARIDES : l'arrivée en zone 3, aux bleues des Cavernes des Lamentations (34). Les pièces s'écrivent au lot
  T8 (§4.7.4 du brouillon des Tarides) ; d'ici là, seule la puissance attendue est fixée.

py fiches_zones.py  (relit les pièces en base et affiche les fiches)
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gabarit_zone as gz

SPECIALISATIONS = ("guerrier_tank", "demoniste_affliction", "voleur_assassinat")

# Bleues du Gouffre (migration 101, equipement_gouffre_v3.PIECES ; orbe : orbes_v3, migration 125).
CAPE = 910271
GOUFFRE = {
    # Maille (tête, épaules, torse, poignets, mains, taille, jambes, pieds), cape, Lame maudite, Rempart.
    "guerrier_tank": [910241, 910242, 910243, 910244, 910245, 910246, 910247, 910248, CAPE, 910265, 910270],
    # Tissu, cape, Lame psalmodiante (dague), Orbe ardent du Gouffre.
    "demoniste_affliction": [910257, 910258, 910259, 910260, 910261, 910262, 910263, 910264, CAPE, 910268, 910272],
    # Cuir, cape, deux Lames psalmodiantes (dagues).
    "voleur_assassinat": [910249, 910250, 910251, 910252, 910253, 910254, 910255, 910256, CAPE, 910268, 910268],
}


def fiche(nom, zone, precedente, pieces, puissance):
    """Fiche d'un joueur qui entre dans zone en sortant de precedente (dictionnaires du gabarit)."""
    faites = gz.ZONES[:gz.ZONES.index(precedente) + 1]
    techniques = {spe: [t for z in faites for t in z["specialisations"][spe]["techniques"]] for spe in SPECIALISATIONS}
    emplacements = {spe: precedente["specialisations"][spe]["emplacements"][1] for spe in SPECIALISATIONS}
    return {"nom": nom, "zone": zone["nom"], "puissance": puissance, "rang": 0, "pieces": pieces,
            "techniques": techniques, "emplacements": emplacements,
            "camp": {g: r[1] for g, r in precedente["camp"].items()}}


ARRIVEE_TARIDES = fiche("Arrivée aux Tarides", gz.TARIDES, gz.DUROTAR, GOUFFRE, gz.DUROTAR["donjon"]["bleues"])
SORTIE_TARIDES = fiche("Sortie des Tarides (arrivée en zone 3)", gz.ZONE_3, gz.TARIDES, None,
                       gz.TARIDES["donjon"]["bleues"])
FICHES = [ARRIVEE_TARIDES, SORTIE_TARIDES]


def verifier():
    """(erreurs, lignes à afficher) : pièces en base, de qualité bleue, puissance relue égale à l'attendue, aucun objet
    des rares secrets, et l'attendue égale au début de la plage de la zone d'arrivée."""
    from rares_secrets_v3 import EXCLUS
    erreurs, lignes = [], []
    for f in FICHES:
        arrivee = next(z for z in gz.ZONES if z["nom"] == f["zone"])
        if f["puissance"] != arrivee["plage"][0]:
            erreurs.append(f"{f['nom']} : puissance {f['puissance']}, la zone commence à {arrivee['plage'][0]}")
        if f["pieces"] is None:
            lignes.append(f"{f['nom']} : puissance {f['puissance']:g} attendue ; pièces à écrire (lot T8) ; "
                          f"camp {f['camp']}")
            continue
        for spe, pieces in f["pieces"].items():
            entrees = ", ".join(str(e) for e in sorted(set(pieces)))
            niveaux = {int(e): (int(n), int(q)) for e, n, q in
                       gz.sql(f"SELECT entry, ItemLevel, Quality FROM item_template WHERE entry IN ({entrees})")}
            manque = [e for e in pieces if e not in niveaux]
            if manque:
                erreurs.append(f"{f['nom']} ({spe}) : {manque} absents d'item_template")
                continue
            exclus = [e for e in pieces if e in EXCLUS]
            if exclus:
                erreurs.append(f"{f['nom']} ({spe}) : {exclus} sont des objets de rares secrets")
            pas_bleues = [e for e in pieces if niveaux[e][1] != 3]
            if pas_bleues:
                erreurs.append(f"{f['nom']} ({spe}) : {pas_bleues} ne sont pas bleues")
            puissance = round(sum(niveaux[e][0] for e in pieces) / len(pieces), 1)
            if puissance != f["puissance"]:
                erreurs.append(f"{f['nom']} ({spe}) : puissance relue {puissance}, attendue {f['puissance']}")
            lignes.append(f"{f['nom']} ({spe}) : {len(pieces)} pièces au rang 0, puissance {puissance:g}, "
                          f"{len(f['techniques'][spe])} techniques, {f['emplacements'][spe]} emplacements, "
                          f"camp {f['camp']}")
    return erreurs, lignes


if __name__ == "__main__":
    e, l = verifier()
    print("\n".join(l + ["erreur : " + x for x in e]))
    sys.exit(1 if e else 0)
