"""Lot T7 des Tarides (03/11/2026) : économie des Tarides (point 11 et décisions 4, 5, 7 et 14 du brouillon des Tarides).

- Camp : potion 3-4 et feu 4-5 (bivouac_v3.COUTS_TARIDES, lignes_tarides) ; nom, zone et message d'achat de chaque
  rang, Durotar compris (solazeroth_v3_camp_rangs, lue par v3_bivouac.cpp et gabarit_zone.py).
- Cuisine : les 10 plats des Tarides (cuisine_v3.plats_tarides), comme la migration 079 pour Durotar.
- Barème des annexes par point de part, écrit en base (solazeroth_v3_annexes_bareme ; brouillon des Tarides, §4.1 :
  la Croisée part du dernier palier de Durotar). gabarit_zone.py le compare au sien.
- Composants de donjon : colonne puissance_min de solazeroth_v3_donjons_composants (le transfert de rang coûte le
  composant de la zone de la pièce) et dernier donjon terminé du compte (récompense de la semaine). Le lot T5 ajoute
  les Cavernes des Lamentations à la table.

Écrit la migration 145. auras_nommees.py --client ajoute les mêmes sorts au Spell.dbc du client ; bivouac_v3.py écrit
SolUI_Camp.lua ; ce script écrit aussi SolUI_Cuisine.lua (cuisine_v3.ecrire_lua).

py economie_tarides.py
"""
import os
import sys

ICI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ICI)
import auras_nommees
import bivouac_v3
import cuisine_v3
import dbc
import icones_retail
from hauts_faits_natifs import DBC_SERVEUR, sql_texte

MIGRATION = os.path.join(ICI, "..", "sql", "migrations", "145_v3_tarides_economie")
DUROTAR, TARIDES = 14, 17
# Barème des annexes par point de part : (puissance la plus haute de la tranche, cuivre, éclats). 20 Marques par point.
BAREMES = {
    DUROTAR: [(3, 3000, 5), (6, 6000, 8), (9, 10000, 12), (11, 12000, 15)],
    TARIDES: [(16, 12000, 15), (22, 18500, 23), (29, 28500, 36), (31, 44000, 55)],
}
MARQUES_PAR_POINT = 20
GOUFFRE = 389                       # carte du Gouffre de Ragefeu : composant pour les pièces de puissance 1 et plus


def main():
    d = dbc.Dbc.ouvrir(os.path.join(DBC_SERVEUR, "Spell.dbc"))
    types = auras_nommees.types_colonnes()
    en_sql = lambda e: "INSERT INTO spell_dbc VALUES (%s);" % ", ".join(
        auras_nommees.valeur_sql(d, t, v) for t, v in zip(types, e))
    repos = bivouac_v3.lignes_tarides(d, icones_retail.identifiants())
    plats = cuisine_v3.plats_tarides()
    cuisine = cuisine_v3.lignes(d, plats)
    sorts = [e[0] for e in repos + cuisine]
    objets = ", ".join(str(p["objet"]) for p in plats)

    up = ["-- Lot T7 des Tarides (03/11/2026) : économie des Tarides. Généré par outils\\economie_tarides.py : ne pas",
          "-- modifier à la main. Le client lit les mêmes sorts dans patch-frFR-4.MPQ (auras_nommees.py --client).",
          "SET SESSION sql_mode = '';",
          "USE acore_world;",
          "",
          "-- Camp : potion 3-4 et feu 4-5 (genre 1 potion, 2 feu ; objet 0 = or, en cuivre).",
          "DELETE FROM solazeroth_v3_camp_couts WHERE (genre = 1 AND rang IN (3, 4)) OR (genre = 2 AND rang IN (4, 5));"]
    up.append("INSERT INTO solazeroth_v3_camp_couts VALUES %s;" % ", ".join(
        "(%d, %d, %d, %d)" % (bivouac_v3.GENRES[g], r, o, n)
        for (g, r), c in sorted(bivouac_v3.COUTS_TARIDES.items()) for o, n in c.items()))
    up += ["DROP TABLE IF EXISTS solazeroth_v3_camp_rangs;",
           "CREATE TABLE solazeroth_v3_camp_rangs (genre TINYINT UNSIGNED NOT NULL, rang TINYINT UNSIGNED NOT NULL, "
           "zone INT UNSIGNED NOT NULL, nom VARCHAR(80) NOT NULL, message VARCHAR(255) NOT NULL, PRIMARY KEY (genre, rang));"]
    up.append("INSERT INTO solazeroth_v3_camp_rangs VALUES %s;" % ", ".join(
        "(%d, %d, %d, %s, %s)" % (bivouac_v3.GENRES[g], r, z, sql_texte(bivouac_v3.NOMS[(g, r)]), sql_texte(m))
        for (g, r), (z, m) in sorted(bivouac_v3.RANGS.items())))
    up += ["", "-- Sorts : Repos du feu 4-5, plats des Tarides et leurs auras « Bien nourri ».",
           "DELETE FROM spell_dbc WHERE ID IN (%s);" % ", ".join(map(str, sorts)),
           "DELETE FROM spell_script_names WHERE spell_id IN (%s);" % ", ".join(str(p["sort"]) for p in plats)]
    up += [en_sql(e) for e in repos + cuisine]
    up.append("INSERT INTO spell_script_names (spell_id, ScriptName) VALUES %s;" % ", ".join(
        "(%d, '%s')" % (p["sort"], cuisine_v3.SCRIPT) for p in plats))
    up += ["", "-- Cuisine : les 10 plats des Tarides (le sort d'origine est gardé dans solazeroth_v3_plats_origine).",
           "DELETE FROM solazeroth_v3_plats WHERE zone = %d;" % TARIDES,
           "DELETE FROM solazeroth_v3_plats_composants WHERE objet IN (%s);" % objets,
           "INSERT INTO solazeroth_v3_plats VALUES %s;" % ", ".join(
               "(%d, %d, %d, %d, %d, %d, %d)" % (p["objet"], p["zone"], p["puissance"], p["sort"], *p["buffs"])
               for p in plats),
           "INSERT INTO solazeroth_v3_plats_composants VALUES %s;" % ", ".join(
               "(%d, %d, %d)" % (p["objet"], c, n) for p in plats for c, n in p["composants"]),
           "INSERT IGNORE INTO solazeroth_v3_plats_origine SELECT entry, spellid_1, description FROM item_template"
           " WHERE entry IN (%s);" % objets]
    up += ["UPDATE item_template SET spellid_1 = %d, description = '' WHERE entry = %d;" % (p["sort"], p["objet"])
           for p in plats]
    up += ["", "-- Barème des annexes par point de part (haut : puissance la plus haute de la tranche).",
           "DROP TABLE IF EXISTS solazeroth_v3_annexes_bareme;",
           "CREATE TABLE solazeroth_v3_annexes_bareme (zone INT UNSIGNED NOT NULL, haut TINYINT UNSIGNED NOT NULL, "
           "cuivre INT UNSIGNED NOT NULL, eclats INT UNSIGNED NOT NULL, marques INT UNSIGNED NOT NULL, "
           "PRIMARY KEY (zone, haut));",
           "INSERT INTO solazeroth_v3_annexes_bareme VALUES %s;" % ", ".join(
               "(%d, %d, %d, %d, %d)" % (z, h, c, e, MARQUES_PAR_POINT)
               for z, tranches in sorted(BAREMES.items()) for h, c, e in tranches)]
    up += ["", "-- Composants de donjon : puissance minimale des pièces de la zone du donjon (transfert de rang).",
           "ALTER TABLE solazeroth_v3_donjons_composants ADD COLUMN puissance_min TINYINT UNSIGNED NOT NULL DEFAULT 1;",
           "UPDATE solazeroth_v3_donjons_composants SET puissance_min = 1 WHERE carte = %d;" % GOUFFRE,
           "",
           "-- Dernier donjon terminé (son dernier boss), au compte : composant de la récompense de la semaine.",
           "CREATE TABLE IF NOT EXISTS acore_characters.solazeroth_v3_dernier_donjon (compte INT UNSIGNED NOT NULL "
           "PRIMARY KEY, carte INT UNSIGNED NOT NULL) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;"]

    down = ["-- Retire l'économie des Tarides (lot T7).",
            "SET SESSION sql_mode = '';",
            "USE acore_world;",
            up[6],
            "DROP TABLE IF EXISTS solazeroth_v3_camp_rangs;",
            "UPDATE item_template i JOIN solazeroth_v3_plats_origine o ON o.entry = i.entry"
            " SET i.spellid_1 = o.spellid_1, i.description = o.description WHERE i.entry IN (%s);" % objets,
            "DELETE FROM solazeroth_v3_plats_origine WHERE entry IN (%s);" % objets,
            "DELETE FROM solazeroth_v3_plats WHERE zone = %d;" % TARIDES,
            "DELETE FROM solazeroth_v3_plats_composants WHERE objet IN (%s);" % objets,
            "DELETE FROM spell_dbc WHERE ID IN (%s);" % ", ".join(map(str, sorts)),
            "DELETE FROM spell_script_names WHERE spell_id IN (%s);" % ", ".join(str(p["sort"]) for p in plats),
            "DROP TABLE IF EXISTS solazeroth_v3_annexes_bareme;",
            "ALTER TABLE solazeroth_v3_donjons_composants DROP COLUMN puissance_min;",
            "DROP TABLE IF EXISTS acore_characters.solazeroth_v3_dernier_donjon;"]
    for suffixe, contenu in ((".up.sql", up), (".down.sql", down)):
        with open(MIGRATION + suffixe, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(contenu) + "\n")
    cuisine_v3.ecrire_lua(cuisine_v3.plats())   # SolUI_Cuisine.lua : Durotar et les Tarides
    print("%d sorts, %d plats, %d rangs du camp : migration 145 écrite." % (len(sorts), len(plats),
                                                                          len(bivouac_v3.COUTS_TARIDES)))


if __name__ == "__main__":
    main()
