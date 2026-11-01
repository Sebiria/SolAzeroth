"""v3, F8 (01/11/2026, demande de l'utilisateur : « la liste de courses pour améliorer les objets en rang 4 et 5, en
implémentant la joaillerie ») : joaillerie de la fenêtre Équipement (v3_equipement.cpp, SolUI_Equipement.lua).

- Prospection : 5 Minerais de cuivre de la Collection donnent une gemme brute de Durotar (Malachite, Œil de tigre ou
  Œil ténébreux, selon les chances ci-dessous), rangée dans la Collection.
- Taille : 2 gemmes brutes donnent une pierre taillée (nouvel objet, rangé dans la Collection, catégorie Gemmes).
- Rangs 4 et 5 : en plus des éclats cadavériques et de l'or, des pierres taillées (RANGS ci-dessous).
Valeurs provisoires, à calibrer avec l'économie (calibrage final).

Écrit la migration 085 et interface-v3\\FrameXML\\SolUI_Joaillerie.lua ; quetes_durotar.item_dbc() ajoute les pierres
taillées à l'Item.dbc du patch.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from quetes_durotar import s, sql

MIGRATION = r"C:\SolAzeroth\sql\migrations\085_v3_joaillerie"
LUA = r"C:\SolAzeroth\interface-v3\FrameXML\SolUI_Joaillerie.lua"

MINERAI, PAR_PROSPECTION = 2770, 5
MALACHITE, OEIL_TIGRE, OEIL_TENEBREUX = 774, 818, 1210
CHANCES = [(MALACHITE, 55), (OEIL_TIGRE, 35), (OEIL_TENEBREUX, 10)]   # en %, total 100
# (pierre taillée, nom, gemme brute, nombre de gemmes brutes)
TAILLES = [
    (910180, "Malachite taillée", MALACHITE, 2),
    (910181, "Œil de tigre taillé", OEIL_TIGRE, 2),
    (910182, "Œil ténébreux taillé", OEIL_TENEBREUX, 2),
]
# Icône retail de chaque pierre (icones_retail.py) : apparence numérotée comme la pierre, copiée de sa gemme brute.
ICONES = {910180: "inv_jewelcrafting_80_cutgem01_green", 910181: "inv_jewelcrafting_80_cutgem01_orange",
          910182: "inv_jewelcrafting_80_cutgem01_purple"}
# Pierres taillées demandées pour passer au rang 4 et au rang 5.
RANGS = {4: [(910180, 2), (910181, 1)], 5: [(910181, 2), (910182, 1)]}


def lignes_dbc():
    return [(e, brute, None) for e, _, brute, _ in TAILLES]


def affichages():
    """{pierre: apparence} pour l'Item.dbc du patch (quetes_durotar.item_dbc)."""
    return {e: e for e in ICONES}


def lua(t):
    return '"' + t.replace("\\", "\\\\").replace('"', '\\"') + '"'


def main():
    assert sum(c for _, c in CHANCES) == 100
    pierres = ", ".join(str(e) for e, *_ in TAILLES)
    up = ["-- v3, F8 (01/11/2026) : joaillerie (prospection, taille) et pierres des rangs 4 et 5. Généré par",
          "-- outils\\joaillerie_v3.py : ne pas modifier à la main.",
          "USE acore_world;",
          "DELETE FROM item_template WHERE entry IN (%s);" % pierres,
          "DELETE FROM item_template_locale WHERE ID IN (%s);" % pierres]
    for e, nom, brute, _ in TAILLES:
        up += ["CREATE TEMPORARY TABLE sol_objet SELECT * FROM item_template WHERE entry = %d;" % brute,
               "UPDATE sol_objet SET entry = %d, name = %s, displayid = %d, Quality = 3, BuyPrice = 0, "
               "SellPrice = 0, description = 'Pierre taillée : améliore les rangs 4 et 5.';" % (e, s(nom), e),
               "INSERT INTO item_template SELECT * FROM sol_objet;",
               "DROP TEMPORARY TABLE sol_objet;",
               "INSERT INTO item_template_locale (ID, locale, Name, Description, VerifiedBuild) VALUES "
               "(%d, 'frFR', %s, 'Pierre taillée : améliore les rangs 4 et 5.', 0);" % (e, s(nom))]
    up += ["INSERT IGNORE INTO solazeroth_v3_collectionnables VALUES %s;" % ", ".join("(%d)" % e for e, *_ in TAILLES),
           "DROP TABLE IF EXISTS solazeroth_v3_prospection;",
           "CREATE TABLE solazeroth_v3_prospection (minerai INT UNSIGNED NOT NULL, nombre INT UNSIGNED NOT NULL, "
           "gemme INT UNSIGNED NOT NULL, chance TINYINT UNSIGNED NOT NULL, PRIMARY KEY (minerai, gemme));",
           "INSERT INTO solazeroth_v3_prospection VALUES %s;" % ", ".join(
               "(%d, %d, %d, %d)" % (MINERAI, PAR_PROSPECTION, g, c) for g, c in CHANCES),
           "DROP TABLE IF EXISTS solazeroth_v3_tailles;",
           "CREATE TABLE solazeroth_v3_tailles (pierre INT UNSIGNED NOT NULL PRIMARY KEY, brute INT UNSIGNED NOT NULL, "
           "nombre INT UNSIGNED NOT NULL);",
           "INSERT INTO solazeroth_v3_tailles VALUES %s;" % ", ".join(
               "(%d, %d, %d)" % (e, b, n) for e, _, b, n in TAILLES),
           "DROP TABLE IF EXISTS solazeroth_v3_rangs_pierres;",
           "CREATE TABLE solazeroth_v3_rangs_pierres (rang TINYINT UNSIGNED NOT NULL, pierre INT UNSIGNED NOT NULL, "
           "nombre INT UNSIGNED NOT NULL, PRIMARY KEY (rang, pierre));",
           "INSERT INTO solazeroth_v3_rangs_pierres VALUES %s;" % ", ".join(
               "(%d, %d, %d)" % (r, p, n) for r, liste in RANGS.items() for p, n in liste),
           ""]
    down = ["-- Retire la joaillerie. Les pierres taillées rangées restent en Collection, sans emploi.",
            "USE acore_world;",
            "DROP TABLE solazeroth_v3_prospection, solazeroth_v3_tailles, solazeroth_v3_rangs_pierres;",
            "DELETE FROM solazeroth_v3_collectionnables WHERE entry IN (%s);" % pierres,
            "DELETE FROM item_template WHERE entry IN (%s);" % pierres,
            "DELETE FROM item_template_locale WHERE ID IN (%s);" % pierres,
            ""]
    for suffixe, lignes in ((".up.sql", up), (".down.sql", down)):
        with open(MIGRATION + suffixe, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(lignes))

    l = ["-- Généré par outils\\joaillerie_v3.py : ne pas modifier à la main.",
         "-- Joaillerie (fenêtre Équipement) : prospection, tailles { pierre, nom, brute, nombre } et pierres des rangs.",
         "SolUI.JOAILLERIE = {",
         "    minerai = %d, parProspection = %d," % (MINERAI, PAR_PROSPECTION),
         "    chances = { %s }," % ", ".join("{ %d, %d }" % gc for gc in CHANCES),
         "    tailles = {"]
    l += ["        { %d, %s, %d, %d }," % (e, lua(nom), b, n) for e, nom, b, n in TAILLES]
    l.append("    },")
    l.append("    rangs = { %s }," % ", ".join(
        "[%d] = { %s }" % (r, ", ".join("{ %d, %d }" % pn for pn in liste)) for r, liste in RANGS.items()))
    l.append("}")
    l.append("-- Les pierres taillées dans la catégorie Gemmes de la Collection.")
    l.append("for _, c in ipairs(SolUI.CATALOGUE or {}) do")
    l.append("    if c.nom == \"Gemmes\" then")
    l += ["        table.insert(c.objets, { %d, %s, 3 })" % (e, lua(nom)) for e, nom, _, _ in TAILLES]
    l.append("    end")
    l.append("end")
    with open(LUA, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(l) + "\n")
    import icones_retail
    import quetes_durotar
    affichage_brut = {int(e): int(affichage) for e, affichage in sql(
        "SELECT entry, displayid FROM acore_world.item_template WHERE entry IN (%s)"
        % ", ".join(str(b) for _, _, b, _ in TAILLES))}
    icones_retail.affichages_objets({e: (affichage_brut[b], ICONES[e]) for e, _, b, _ in TAILLES})
    quetes_durotar.item_dbc()
    print("%d pierres taillées, prospection et pierres des rangs 4 et 5 : migration 085 et SolUI_Joaillerie.lua écrits."
          % len(TAILLES))


if __name__ == "__main__":
    main()
