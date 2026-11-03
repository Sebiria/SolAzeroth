"""Audit du jeu, lot 4b (02/11/2026, C6 du consensus) : rangs et fabrication (v3_equipement.cpp).
- Fabrication limitée au secteur + 2 : une recette s'ouvre à la puissance de la pièce moins 2 (moins 4 avant), les
  rudimentaires restant ouvertes dès le départ (outils\\equipement_v3.py, requise()). Les pièces bleues du Gouffre
  restent à 10 : elles demandent déjà une Braise du Gouffre, le composant de leur secteur.
- Recettes hautes de chaque secteur : la pièce la plus forte de chaque palier demande un composant de plus, rare dans
  son secteur, ou un plan acheté une fois pour toutes en or (au personnage). On peut sauter un secteur en farmant,
  mais ce saut a un prix.
- Transfert de rang (choix de l'utilisateur : rang - 1 et une Braise) : dans le serveur seulement, rien ici.

py fabrication_v3.py   (écrit la migration 116)
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from equipement_v3 import requise
from quetes_durotar import sql

MIGRATION = r"C:\SolAzeroth\sql\migrations\116_v3_fabrication"
MALACHITE, OEIL_TIGRE = 774, 818
# puissance de la pièce : (composant, nombre, prix du plan en cuivre)
HAUTES = {
    8: (MALACHITE, 1, 20000),     # haut de Tranchecolline : bottes, gants et ceintures
    10: (OEIL_TIGRE, 1, 50000),   # haut du sud et du nord : haubert, claymore, gilets
    # Lot T8 des Tarides (03/11/2026, §4.7.2) : le torse de chaque palier, écrit par artisanat_tarides.py (migration
    # 141) ; ce script-ci ne prend que les recettes sous la puissance du Gouffre.
    18: (1206, 1, 70000),         # Agate mousse, palier I « de la Croisée »
    24: (1529, 1, 110000),        # Jade, palier II « des oasis »
    30: (1705, 1, 180000),        # Pierre de lune inférieure, palier III « de Taurajo »
}
GOUFFRE = 14


def main():
    recettes = sql("SELECT r.objet, i.ItemLevel, r.puissance FROM acore_world.solazeroth_v3_recettes r JOIN "
                   "acore_world.item_template i ON i.entry = r.objet WHERE i.ItemLevel < %d ORDER BY r.objet" % GOUFFRE)
    up = ["-- Audit du jeu, lot 4b (02/11/2026) : fabrication limitée au secteur + 2, recettes hautes et plans. Généré par",
          "-- outils\\fabrication_v3.py : ne pas modifier à la main.",
          "USE acore_world;"]
    down = ["USE acore_world;"]
    recettes = [tuple(int(v) for v in ligne) for ligne in recettes]
    for objet, niveau, _ in recettes:
        avant, apres = max(0, niveau - 4), requise(niveau)   # avant : règle de la migration 078
        if apres != int(avant):
            up.append("UPDATE solazeroth_v3_recettes SET puissance = %d WHERE objet = %d;" % (apres, objet))
            down.append("UPDATE solazeroth_v3_recettes SET puissance = %d WHERE objet = %d;" % (int(avant), objet))
    up += ["CREATE TABLE IF NOT EXISTS solazeroth_v3_recettes_hautes (objet INT UNSIGNED NOT NULL PRIMARY KEY, composant "
           "INT UNSIGNED NOT NULL, nombre INT UNSIGNED NOT NULL, plan INT UNSIGNED NOT NULL) ENGINE=InnoDB DEFAULT "
           "CHARSET=utf8mb4;",
           # Lot T8 des Tarides : seulement les recettes de ce script (les Tarides ont les leurs, migration 141).
           "DELETE FROM solazeroth_v3_recettes_hautes WHERE objet IN (%s);"
           % ", ".join(str(o) for o, n, _ in recettes if int(n) in HAUTES)]
    for objet, niveau, _ in recettes:
        if int(niveau) in HAUTES:
            composant, nombre, plan = HAUTES[int(niveau)]
            up.append("INSERT INTO solazeroth_v3_recettes_hautes VALUES (%d, %d, %d, %d);" % (objet, composant, nombre, plan))
            print("%d puissance %d : %d × %d ou plan %d c" % (objet, niveau, nombre, composant, plan))
    up += ["USE acore_characters;",
           "CREATE TABLE IF NOT EXISTS solazeroth_v3_plans (guid INT UNSIGNED NOT NULL, objet INT UNSIGNED NOT NULL, "
           "PRIMARY KEY (guid, objet)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;", ""]
    down += ["DROP TABLE IF EXISTS solazeroth_v3_recettes_hautes;", "USE acore_characters;",
             "DROP TABLE IF EXISTS solazeroth_v3_plans;", ""]
    for suffixe, contenu in ((".up.sql", up), (".down.sql", down)):
        with open(MIGRATION + suffixe, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(contenu))
    print("Migration 116 écrite.")


if __name__ == "__main__":
    main()
