"""Audit du jeu, lot 3a (02/11/2026) : armure de nos pièces au nouveau barème (equipement_v3.armure), pour la règle en
pourcentage de v3_combat.cpp. Lancé avec py armure_v3.py ; écrit la migration 110.

Toutes nos pièces d'armure (910000 à 929999, rangs compris) : armure = barème à la puissance de la pièce (son niveau
d'objet), × (1 + 0,1 × rang) pour les versions améliorées (au_rang d'equipement_v3.py). Seule la colonne armor change ;
l'ancienne est gardée dans solazeroth_v3_armure_origine.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import equipement_v3 as e3
from quetes_durotar import sql

MIGRATION = r"C:\SolAzeroth\sql\migrations\110_v3_armure_pourcentage"


def rang_de(entree):
    return (entree - 920000) % 10 if entree >= 920000 else 0


def main():
    lignes = sql("SELECT entry, subclass, InventoryType, ItemLevel, armor FROM acore_world.item_template "
                 "WHERE entry BETWEEN 910000 AND 929999 AND class = 4 AND armor > 0 ORDER BY entry")
    nouvelles = []
    for entree, sous_classe, emplacement, niveau, ancienne in lignes:
        entree, rang = int(entree), rang_de(int(entree))
        base = e3.armure(int(sous_classe), int(emplacement), int(niveau))
        nouvelles.append((entree, int(ancienne), round(base * (1 + 0.1 * rang))))
    with open(MIGRATION + ".up.sql", "w", encoding="utf-8", newline="\n") as f:
        f.write("-- v3 (02/11/2026, audit du jeu, lot 3a) : armure de nos pièces au barème de la règle en pourcentage\n"
                "-- (outils\\armure_v3.py, equipement_v3.armure). Généré : ne pas modifier à la main.\n"
                "USE acore_world;\n"
                "CREATE TABLE solazeroth_v3_armure_origine SELECT entry, armor FROM item_template\n"
                "WHERE entry BETWEEN 910000 AND 929999 AND class = 4 AND armor > 0;\n")
        for entree, _, armure in nouvelles:
            f.write("UPDATE item_template SET armor = %d WHERE entry = %d;\n" % (armure, entree))
    with open(MIGRATION + ".down.sql", "w", encoding="utf-8", newline="\n") as f:
        f.write("-- Rend à nos pièces leur armure d'avant le lot 3a.\n"
                "USE acore_world;\n"
                "UPDATE item_template i JOIN solazeroth_v3_armure_origine o ON o.entry = i.entry SET i.armor = o.armor;\n"
                "DROP TABLE solazeroth_v3_armure_origine;\n")
    print("%d pièces ; exemples :" % len(nouvelles))
    for entree, ancienne, armure in nouvelles:
        if entree in (910201, 910207, 910232, 910243, 910270, 922015):
            print("  %d : %d -> %d" % (entree, ancienne, armure))


if __name__ == "__main__":
    main()
