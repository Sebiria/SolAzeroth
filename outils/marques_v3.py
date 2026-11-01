"""v3 (01/11/2026, demande de l'utilisateur : « plutôt qu'une seule monnaie… convertis gains actuels et à venir en
Marques du voyageur ») : l'Insigne de Durotar disparaît au profit de la Marque du voyageur (objet 37711, sacs).

- Gains : annexes, épreuve du jour et reliques donnent des Marques (v3_annexes.cpp ; la colonne insignes de
  solazeroth_v3_annexes garde son nom et ses nombres, 1 Insigne = 1 Marque).
- Prix : carte des reliques (v3_annexes.cpp) et nœuds du camp (solazeroth_v3_camp_couts) en Marques.
- Textes de récompense des 30 annexes : refaits par annexes_durotar.recompense_texte.
- Soldes : les Insignes des Collections passent dans solazeroth_jetons_dus (Marques versées à la connexion, par
  compte ; marques.cpp). À appliquer serveur arrêté (la Collection est gardée en mémoire).

py marques_v3.py  (écrit la migration 104)
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import annexes_durotar as annexes
from quetes_durotar import s

MIGRATION = r"C:\SolAzeroth\sql\migrations\104_v3_marques"
INSIGNE, MARQUE = 910140, 37711


def main():
    ids = ", ".join(str(a["q"]) for a in annexes.A)
    up = ["-- v3 (01/11/2026) : Insignes de Durotar convertis en Marques du voyageur. Généré par outils\\marques_v3.py :",
          "-- ne pas modifier à la main. À appliquer serveur arrêté.",
          "USE acore_world;",
          "CREATE TABLE IF NOT EXISTS solazeroth_v3_marques_textes SELECT ID, RewardText FROM quest_offer_reward "
          "WHERE ID IN (%s);" % ids]
    for a in annexes.A:
        up.append("UPDATE quest_offer_reward SET RewardText = %s WHERE ID = %d;"
                  % (s((a["fin"] + " " + annexes.recompense_texte(a)).strip()), a["q"]))
    up += ["UPDATE solazeroth_v3_camp_couts SET objet = %d WHERE objet = %d;" % (MARQUE, INSIGNE),
           "USE acore_characters;",
           "CREATE TABLE IF NOT EXISTS solazeroth_v3_marques_insignes SELECT guid, nombre FROM solazeroth_v3_collection "
           "WHERE objet = %d;" % INSIGNE,
           "INSERT INTO solazeroth_jetons_dus (account, jetons) SELECT c.account, SUM(i.nombre) FROM "
           "solazeroth_v3_marques_insignes i JOIN characters c ON c.guid = i.guid GROUP BY c.account "
           "ON DUPLICATE KEY UPDATE jetons = jetons + VALUES(jetons);",
           "DELETE FROM solazeroth_v3_collection WHERE objet = %d;" % INSIGNE,
           ""]
    down = ["-- Rend les Insignes (les Marques déjà versées restent dans les sacs).",
            "USE acore_world;",
            "UPDATE quest_offer_reward q JOIN solazeroth_v3_marques_textes t ON t.ID = q.ID SET q.RewardText = t.RewardText;",
            "DROP TABLE solazeroth_v3_marques_textes;",
            "UPDATE solazeroth_v3_camp_couts SET objet = %d WHERE objet = %d;" % (INSIGNE, MARQUE),
            "USE acore_characters;",
            "REPLACE INTO solazeroth_v3_collection (guid, objet, nombre) SELECT guid, %d, nombre FROM "
            "solazeroth_v3_marques_insignes;" % INSIGNE,
            "DROP TABLE solazeroth_v3_marques_insignes;",
            ""]
    for suffixe, lignes in ((".up.sql", up), (".down.sql", down)):
        with open(MIGRATION + suffixe, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(lignes))
    print("Migration 104 écrite (%d textes)." % len(annexes.A))


if __name__ == "__main__":
    main()
