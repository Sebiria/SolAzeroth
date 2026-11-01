"""v3 (02/11/2026, audit du jeu, lot 0) : chaque objet demandé par une quête v3 active doit pouvoir s'obtenir en jeu.

La migration 100 avait retiré du butin l'Œil d'ombre ardente, que demande « Ombres ardentes » : la quête ne pouvait
plus être finie et le Gouffre restait fermé, sans que rien ne le signale. Ce test cherche une source à chaque objet
demandé : butin de monstre ou d'objet du décor (directement ou par référence), contenant, marchand, script, objet
donné par une quête.

py verifier_quetes.py  (lecture seule ; code de sortie 1 si un objet n'a aucune source)
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from quetes_durotar import sql

QUETES_V3 = "q.ID BETWEEN 910000 AND 919999"
ACTIVE = "NOT EXISTS (SELECT 1 FROM acore_world.disables d WHERE d.sourceType = 1 AND d.entry = q.ID)"
# Références de butin, sur deux niveaux (une référence peut en appeler une autre).
REFERENCES = ("SELECT Entry FROM acore_world.reference_loot_template WHERE Item IN ({0}) AND Reference = 0 UNION "
              "SELECT r2.Entry FROM acore_world.reference_loot_template r2 JOIN acore_world.reference_loot_template r1 "
              "ON r1.Entry = r2.Reference WHERE r1.Item IN ({0}) AND r1.Reference = 0")
SOURCES = [
    ("butin de monstre",
     "SELECT l.Item FROM acore_world.creature_loot_template l WHERE l.Item IN ({0}) AND l.Reference = 0 UNION "
     "SELECT i.entry FROM acore_world.item_template i JOIN acore_world.creature_loot_template l ON l.Reference IN "
     "(" + REFERENCES + ") WHERE i.entry IN ({0})"),
    ("objet du décor",
     "SELECT l.Item FROM acore_world.gameobject_loot_template l WHERE l.Item IN ({0}) AND l.Reference = 0"),
    ("contenant", "SELECT l.Item FROM acore_world.item_loot_template l WHERE l.Item IN ({0}) AND l.Reference = 0"),
    ("marchand", "SELECT v.item FROM acore_world.npc_vendor v WHERE v.item IN ({0})"),
    ("script", "SELECT s.action_param1 FROM acore_world.smart_scripts s WHERE s.action_type = 56 AND "
               "s.action_param1 IN ({0})"),
    ("donné par une quête", "SELECT q.StartItem FROM acore_world.quest_template q WHERE q.StartItem IN ({0}) AND "
                            + ACTIVE),
]


def objets_demandes():
    colonnes = ["RequiredItemId%d" % n for n in range(1, 7)]
    union = " UNION ".join(
        "SELECT q.ID, q.LogTitle, q.%s FROM acore_world.quest_template q WHERE %s AND %s AND q.%s > 0"
        % (c, QUETES_V3, ACTIVE, c) for c in colonnes)
    demandes = {}
    for quete, titre, objet in sql(union):
        demandes.setdefault(int(objet), []).append("%s %s" % (quete, titre))
    return demandes


def main():
    demandes = objets_demandes()
    liste = ", ".join(map(str, sorted(demandes)))
    trouves = set()
    for _, requete in SOURCES:
        trouves |= {int(x[0]) for x in sql(requete.format(liste))}
    manquants = sorted(set(demandes) - trouves)
    for objet in manquants:
        nom = sql("SELECT name FROM acore_world.item_template WHERE entry = %d" % objet)
        print("Sans source : objet %d (%s), demandé par %s" % (
            objet, nom[0][0] if nom else "?", ", ".join(demandes[objet])))
    print("%d objets demandés par les quêtes v3, %d sans source." % (len(demandes), len(manquants)))
    return 1 if manquants else 0


if __name__ == "__main__":
    sys.exit(main())
