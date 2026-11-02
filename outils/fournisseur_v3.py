"""Audit du jeu, lot 4a (02/11/2026, C4 du consensus : « l'or achète du temps, jamais de la puissance ») : fournisseur de
matériaux de Razor Hill (v3_fournisseur.cpp). Choix de l'utilisateur : prix posés sur une hypothèse écrite, corrigés
quand les journaux donneront le vrai rythme de farm.

Prix d'un matériau = FACTEUR × (or gagné en jouant pendant le temps qu'il faut pour le récolter). Hypothèses :
- OR_PAR_HEURE : 3 po par heure de jeu (Durotar rapporte environ 27 po, simulation_rangs.py, en 8 à 10 h) ;
- RYTHMES : unités récoltées par minute de farm (un filon par minute, 2,5 minerais par filon…).
Le fournisseur ne vend que les matériaux communs : ni éclats, ni Braises, ni pierres taillées, qui récompensent le
risque. PLAFOND unités de chaque matériau par jour et par personnage.

py fournisseur_v3.py   (écrit la migration 113 et affiche les prix)
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from quetes_durotar import sql

MIGRATION = r"C:\SolAzeroth\sql\migrations\113_v3_fournisseur"
OR_PAR_HEURE = 30000        # cuivre
FACTEUR = 4                 # le consensus : 3 à 5 fois la valeur du farm
PLAFOND = 20
RYTHMES = {                 # entrée : unités par minute de farm (hypothèses à mesurer en jeu ; ordre revu par
                            # l'utilisateur le 02/11/2026 : lin et lanières les plus faciles, puis le cuir léger, la
                            # pierre brute ; le minerai de cuivre le plus rare)
    2589: 2.0,              # Étoffe de lin : humanoïdes, nombreux
    2934: 2.0,              # Lanières de cuir déchirées
    2318: 1.0,              # Cuir léger : plus rare que les lanières
    2835: 2.5,              # Pierre brute
    2770: 0.5,              # Minerai de cuivre : le plus rare
}
PNJ, MODELE, GUID = 910030, 3168, 9100030       # copie de Flakk (Fournitures, Razor Hill)
PLACE = (325.9, -4767.6, 12.6, 1.6)


def nom(entree):
    l = sql("SELECT COALESCE(NULLIF(l.Name, ''), i.name) FROM acore_world.item_template i LEFT JOIN "
            "acore_world.item_template_locale l ON l.ID = i.entry AND l.locale = 'frFR' WHERE i.entry = %d" % entree)
    return l[0][0]


def main():
    lignes = []
    for entree, rythme in RYTHMES.items():
        prix = int(round(OR_PAR_HEURE / 60.0 / rythme * FACTEUR))
        lignes.append((entree, nom(entree), prix))
        print("%5d %-32s %5d c l'unité, %d par jour" % (entree, nom(entree), prix, PLAFOND))
    echappe = lambda s: s.replace("'", "''")
    up = ["-- Audit du jeu, lot 4a (02/11/2026) : fournisseur de matériaux de Razor Hill. Généré par",
          "-- outils\\fournisseur_v3.py : ne pas modifier à la main (prix et hypothèses y sont écrits).",
          "USE acore_world;",
          "CREATE TABLE IF NOT EXISTS solazeroth_v3_fournisseur (objet INT UNSIGNED NOT NULL PRIMARY KEY, nom VARCHAR(64) "
          "NOT NULL, prix INT UNSIGNED NOT NULL, plafond INT UNSIGNED NOT NULL) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;",
          "DELETE FROM solazeroth_v3_fournisseur;"]
    up += ["INSERT INTO solazeroth_v3_fournisseur VALUES (%d, '%s', %d, %d);" % (e, echappe(n), p, PLAFOND)
           for e, n, p in lignes]
    up += ["DELETE FROM creature_template WHERE entry = %d;" % PNJ,
           "DELETE FROM creature_template_model WHERE CreatureID = %d;" % PNJ,
           "DELETE FROM creature WHERE guid = %d;" % GUID,
           "CREATE TEMPORARY TABLE sol_pnj SELECT * FROM creature_template WHERE entry = %d;" % MODELE,
           "UPDATE sol_pnj SET entry = %d, name = 'Mogra', subname = 'Matériaux', npcflag = 1, gossip_menu_id = 0, "
           "AIName = '', ScriptName = 'npc_solazeroth_v3_fournisseur';" % PNJ,
           "INSERT INTO creature_template SELECT * FROM sol_pnj;",
           "DROP TEMPORARY TABLE sol_pnj;",
           "INSERT INTO creature_template_model (CreatureID, Idx, CreatureDisplayID, DisplayScale, Probability, "
           "VerifiedBuild) SELECT %d, Idx, CreatureDisplayID, DisplayScale, Probability, VerifiedBuild FROM "
           "creature_template_model WHERE CreatureID = %d;" % (PNJ, MODELE),
           "INSERT INTO creature (guid, id, map, zoneId, areaId, spawnMask, phaseMask, equipment_id, position_x, "
           "position_y, position_z, orientation, spawntimesecs, wander_distance, MovementType) VALUES (%d, %d, 1, 14, "
           "362, 1, 1, 0, %.1f, %.1f, %.1f, %.2f, 300, 0, 0);" % ((GUID, PNJ) + PLACE),
           "USE acore_characters;",
           "CREATE TABLE IF NOT EXISTS solazeroth_v3_fournisseur_achats (guid INT UNSIGNED NOT NULL, objet INT UNSIGNED "
           "NOT NULL, jour INT UNSIGNED NOT NULL, nombre INT UNSIGNED NOT NULL, PRIMARY KEY (guid, objet)) ENGINE=InnoDB "
           "DEFAULT CHARSET=utf8mb4;", ""]
    down = ["USE acore_world;",
            "DELETE FROM creature WHERE guid = %d;" % GUID,
            "DELETE FROM creature_template_model WHERE CreatureID = %d;" % PNJ,
            "DELETE FROM creature_template WHERE entry = %d;" % PNJ,
            "DROP TABLE IF EXISTS solazeroth_v3_fournisseur;",
            "USE acore_characters;",
            "DROP TABLE IF EXISTS solazeroth_v3_fournisseur_achats;", ""]
    for suffixe, contenu in ((".up.sql", up), (".down.sql", down)):
        with open(MIGRATION + suffixe, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(contenu))
    print("Migration 113 écrite.")


if __name__ == "__main__":
    main()
