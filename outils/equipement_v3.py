"""v3, E1 (31/10/2026) : équipement à fabriquer, à acheter et à améliorer (document v3, § 2.4 et F8 ; choix de
l'utilisateur du 31/10/2026).

- Barème commun à toutes nos pièces (récompenses de quête 910101-910119 et pièces fabriquées 910201-910226). Les
  récompenses reprenaient les chiffres de leur objet d'origine : tantôt des caractéristiques, tantôt rien. Désormais :
  - armure et dégâts d'arme : ceux d'un objet d'origine vert de même type et de même niveau d'objet que la puissance
    de la pièce (droite ajustée sur les objets verts de niveau 5 à 30) ;
  - Puissance d'attaque (au moins 1) et Endurance, selon la puissance et l'emplacement. Prudence : au niveau 80 caché,
    le personnage n'a qu'environ 84 points de vie et 1 Endurance en donne 10. À calibrer.
- Recettes (fenêtre Équipement, v3_equipement.cpp) : composants bruts de la Collection et un peu d'or. Maille, bouclier
  et armes se fabriquent près d'une enclume ou d'une forge ; cuir et tissu partout. Une recette s'ouvre à la puissance
  de la pièce moins 4.
- Marchands de Razor Hill (Uhgar, Cutac, Wuark) : leurs pièces d'équipement d'origine sont remplacées par nos pièces
  fabriquées, plus chères en or que la fabrication.
- Rangs 1 à 5 : chaque pièce existe en 6 versions, caractéristiques +10 % par rang (entrée 920000 + (pièce - 910000)
  × 10 + rang, nom « … +rang »). Le coût est calculé par le serveur.

Écrit la migration 078, SolUI_Recettes.lua (interface) et, par quetes_durotar.item_dbc(), l'Item.dbc du patch client.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from quetes_durotar import EQUIPEMENT, s, sql

MIGRATION = r"C:\SolAzeroth\sql\migrations\078_v3_equipement"
RECETTES_LUA = r"C:\SolAzeroth\interface-v3\FrameXML\SolUI_Recettes.lua"

CUIVRE, PIERRE, CUIR, LANIERES, LIN = 2770, 2835, 2318, 2934, 2589
RANGS = 5
MARCHANDS = {3163: "Armes", 3166: "Cuir et tissu", 3167: "Maille"}   # Uhgar, Cutac, Wuark (Razor Hill)

# (entrée, nom, objet d'origine pour l'apparence et le type, puissance, composants, catégorie)
RECETTES = [
    (910201, "Haubert en anneaux de cuivre", 3471, 10, {CUIVRE: 16, PIERRE: 4}, "Maille"),
    (910202, "Jambières en anneaux de cuivre", 2852, 9, {CUIVRE: 10, PIERRE: 2}, "Maille"),
    (910203, "Bottes en anneaux de cuivre", 3469, 8, {CUIVRE: 8, PIERRE: 2}, "Maille"),
    (910204, "Gantelets en cuivre", 3472, 8, {CUIVRE: 8, PIERRE: 2}, "Maille"),
    (910205, "Brassards en cuivre", 2853, 7, {CUIVRE: 4, PIERRE: 2}, "Maille"),
    (910206, "Ceinture en anneaux de cuivre", 2851, 8, {CUIVRE: 6, PIERRE: 2}, "Maille"),
    (910207, "Bouclier en cuivre", 2376, 9, {CUIVRE: 10, PIERRE: 4}, "Maille"),
    (910208, "Épée courte en cuivre", 2847, 9, {CUIVRE: 8, PIERRE: 2, CUIR: 2}, "Armes"),
    (910209, "Hache en cuivre", 2845, 9, {CUIVRE: 8, PIERRE: 2, CUIR: 2}, "Armes"),
    (910210, "Masse en cuivre", 2844, 9, {CUIVRE: 8, PIERRE: 2, CUIR: 2}, "Armes"),
    (910211, "Dague en cuivre", 7166, 9, {CUIVRE: 6, PIERRE: 2, CUIR: 2}, "Armes"),
    (910212, "Claymore en cuivre", 7955, 10, {CUIVRE: 14, PIERRE: 4, CUIR: 2}, "Armes"),
    (910213, "Gilet en cuir estampé", 2300, 10, {CUIR: 10, LANIERES: 4}, "Cuir"),
    (910214, "Pantalon en cuir cousu", 2303, 9, {CUIR: 8, LANIERES: 4}, "Cuir"),
    (910215, "Bottes en cuir cousu", 2302, 8, {CUIR: 6, LANIERES: 2}, "Cuir"),
    (910216, "Gants en cuir estampé", 4239, 8, {CUIR: 6, LANIERES: 2}, "Cuir"),
    (910217, "Brassards en cuir cousu", 7277, 7, {CUIR: 4, LANIERES: 2}, "Cuir"),
    (910218, "Ceinture en cuir cousu", 4237, 8, {CUIR: 6, LANIERES: 2}, "Cuir"),
    (910219, "Cape en cuir estampé", 2310, 9, {CUIR: 6, LANIERES: 2}, "Cuir"),
    (910220, "Gilet rouge en lin", 6239, 10, {LIN: 12}, "Tissu"),
    (910221, "Pantalon en lin", 4343, 9, {LIN: 10}, "Tissu"),
    (910222, "Bottes en lin", 2569, 8, {LIN: 8, CUIR: 2}, "Tissu"),
    (910223, "Gants en lin épais", 4307, 8, {LIN: 8}, "Tissu"),
    (910224, "Brassards en lin", 4308, 7, {LIN: 6}, "Tissu"),
    (910225, "Ceinture en lin", 7026, 8, {LIN: 6}, "Tissu"),
    (910226, "Cape en lin renforcé", 2580, 9, {LIN: 8}, "Tissu"),
]
FORGE = {"Maille", "Armes"}
CATEGORIES = ["Maille", "Armes", "Cuir", "Tissu"]

# Poids de l'emplacement (InventoryType) dans le barème.
POIDS = {5: 1.0, 20: 1.0, 7: 1.0, 17: 1.0, 8: 0.75, 10: 0.75, 6: 0.75, 1: 0.75, 3: 0.75,
         9: 0.56, 16: 0.56, 14: 0.56, 13: 0.56, 21: 0.56, 22: 0.56}
AP_PAR_POINT, ENDURANCE_PAR_POINT = 0.6, 0.12
PUISSANCE_ATTAQUE, ENDURANCE = 38, 7
COLONNES = ["entry", "name", "class", "subclass", "InventoryType", "armor", "dmg_min1", "dmg_max1", "delay", "block"]


def droite(points):
    """Moindres carrés : y = a + b x."""
    n = len(points)
    mx = sum(x for x, _ in points) / n
    my = sum(y for _, y in points) / n
    vx = sum((x - mx) ** 2 for x, _ in points)
    b = sum((x - mx) * (y - my) for x, y in points) / vx if vx else 0.0
    return my - b * mx, b


def baremes():
    armures = {}
    for sous_classe, emplacement, niveau, armure in sql(
            "SELECT subclass, InventoryType, ItemLevel, armor FROM acore_world.item_template WHERE class = 4 "
            "AND Quality = 2 AND ItemLevel BETWEEN 5 AND 30 AND armor > 0 AND subclass IN (1, 2, 3, 6)"):
        emplacement = 5 if emplacement == "20" else int(emplacement)
        armures.setdefault((int(sous_classe), emplacement), []).append((int(niveau), int(armure)))
    armures = {k: droite(v) for k, v in armures.items() if len(v) >= 3}
    armes = {}
    for emplacement, niveau, bas, haut, cadence in sql(
            "SELECT InventoryType, ItemLevel, dmg_min1, dmg_max1, delay FROM acore_world.item_template WHERE class = 2 "
            "AND Quality = 2 AND ItemLevel BETWEEN 5 AND 30 AND delay > 0 AND dmg_max1 > 0 "
            "AND InventoryType IN (13, 17, 21, 22)"):
        deux_mains = emplacement == "17"
        armes.setdefault(deux_mains, []).append((int(niveau), (float(bas) + float(haut)) / 2 / (int(cadence) / 1000)))
    return armures, {k: droite(v) for k, v in armes.items()}


def objets(entrees):
    lignes = sql("SELECT %s FROM acore_world.item_template WHERE entry IN (%s)"
                 % (", ".join(COLONNES), ",".join(map(str, entrees))))
    return {int(l[0]): dict(zip(COLONNES, l)) for l in lignes}


def caracteristiques(modele, puissance, armures, armes):
    """Colonnes d'item_template du barème, pour une pièce de cette puissance (rang 0)."""
    classe, sous_classe = int(modele["class"]), int(modele["subclass"])
    emplacement = int(modele["InventoryType"])
    poids = POIDS[emplacement]
    c = {"armor": 0, "dmg_min1": 0, "dmg_max1": 0}
    if classe == 4:
        a, b = armures[(sous_classe, 5 if emplacement == 20 else emplacement)]
        c["armor"] = max(1, round(a + b * puissance))
    else:
        a, b = armes[emplacement == 17]
        cadence = int(modele["delay"]) / 1000
        moyenne = max(1.0, a + b * puissance) * cadence
        bas, haut = float(modele["dmg_min1"]), float(modele["dmg_max1"])
        part = bas / (bas + haut) if bas + haut else 0.4
        c["dmg_min1"] = max(1, round(moyenne * 2 * part))
        c["dmg_max1"] = max(c["dmg_min1"] + 1, round(moyenne * 2 * (1 - part)))
    c["ap"] = max(1, round(poids * puissance * AP_PAR_POINT))
    c["endurance"] = round(poids * puissance * ENDURANCE_PAR_POINT)
    return c


def au_rang(c, rang, bloc):
    f = 1 + 0.1 * rang
    r = {k: round(v * f) for k, v in c.items()}
    r["block"] = round(bloc * f)
    return r


def colonnes_sql(c):
    stats = [(PUISSANCE_ATTAQUE, c["ap"])] + ([(ENDURANCE, c["endurance"])] if c["endurance"] else [])
    morceaux = ["armor = %d" % c["armor"], "dmg_min1 = %d" % c["dmg_min1"], "dmg_max1 = %d" % c["dmg_max1"],
                "block = %d" % c["block"]]
    for i in range(1, 11):
        t, v = stats[i - 1] if i <= len(stats) else (0, 0)
        morceaux += ["stat_type%d = %d" % (i, t), "stat_value%d = %d" % (i, v)]
    return ", ".join(morceaux)


def entree_rang(base, rang):
    return 920000 + (base - 910000) * 10 + rang


def pieces():
    """(entrée, nom, objet d'origine, puissance) de toutes nos pièces améliorables."""
    return [(e, nom, source, p) for e, _, nom, source, p in EQUIPEMENT] + \
           [(e, nom, source, p) for e, nom, source, p, _, _ in RECETTES]


def lignes_dbc():
    """Lignes à ajouter à Item.dbc : (entrée, entrée dont on copie la ligne), dans l'ordre (la base avant ses rangs)."""
    lignes = [(e, source) for e, _, source, _, _, _ in RECETTES]
    for e, _, _, _ in pieces():
        lignes += [(entree_rang(e, r), e) for r in range(1, RANGS + 1)]
    return lignes


def prix(p, poids):
    return round(p * poids * 100)


def main():
    armures, armes = baremes()
    toutes = pieces()
    sources = objets({src for _, _, src, _ in toutes})
    recompenses = objets({e for e, *_ in EQUIPEMENT})
    up, down = [], []
    w = up.append
    w("-- v3, E1 (31/10/2026) : équipement à fabriquer, à acheter et à améliorer. Généré par outils\\equipement_v3.py :")
    w("-- ne pas modifier à la main.")
    w("USE acore_world;")
    w("")
    w("-- Pièces fabriquées : apparence et type repris d'un objet d'origine.")
    for e, nom, source, p, _, categorie in RECETTES:
        poids = POIDS[int(sources[source]["InventoryType"])]
        w("DELETE FROM item_template WHERE entry = %d;" % e)
        w("CREATE TEMPORARY TABLE sol_objet SELECT * FROM item_template WHERE entry = %d;" % source)
        w("UPDATE sol_objet SET entry = %d, name = %s, description = '', Quality = 2, bonding = 1, ItemLevel = %d, "
          "RequiredLevel = 0, RequiredSkill = 0, RequiredSkillRank = 0, AllowableClass = -1, AllowableRace = -1, "
          "BuyCount = 1, BuyPrice = %d, SellPrice = 0, RandomProperty = 0, RandomSuffix = 0, spellid_1 = 0, "
          "spelltrigger_1 = 0;" % (e, s(nom), p, prix(p, poids)))
        w("INSERT INTO item_template SELECT * FROM sol_objet;")
        w("DROP TEMPORARY TABLE sol_objet;")
    w("")
    w("-- Barème commun (rang 0) : récompenses de quête et pièces fabriquées.")
    caracs = {}
    for e, nom, source, p in toutes:
        modele = recompenses.get(e) or sources[source]
        c = caracteristiques(modele, p, armures, armes)
        bloc = int(sources[source]["block"])
        caracs[e] = (c, bloc)
        w("UPDATE item_template SET %s WHERE entry = %d;" % (colonnes_sql(au_rang(c, 0, bloc)), e))
    w("")
    w("-- Rangs 1 à 5 : +10 % par rang.")
    for e, nom, source, p in toutes:
        c, bloc = caracs[e]
        for r in range(1, RANGS + 1):
            n = entree_rang(e, r)
            w("DELETE FROM item_template WHERE entry = %d;" % n)
            w("CREATE TEMPORARY TABLE sol_objet SELECT * FROM item_template WHERE entry = %d;" % e)
            w("UPDATE sol_objet SET entry = %d, name = %s, BuyPrice = 0, %s;"
              % (n, s("%s +%d" % (nom, r)), colonnes_sql(au_rang(c, r, bloc))))
            w("INSERT INTO item_template SELECT * FROM sol_objet;")
            w("DROP TEMPORARY TABLE sol_objet;")
    w("")
    w("DROP TABLE IF EXISTS solazeroth_v3_rangs;")
    w("CREATE TABLE solazeroth_v3_rangs (entree INT UNSIGNED NOT NULL PRIMARY KEY, base INT UNSIGNED NOT NULL, "
      "rang TINYINT UNSIGNED NOT NULL);")
    valeurs = ["(%d, %d, %d)" % (entree_rang(e, r) if r else e, e, r) for e, *_ in toutes for r in range(RANGS + 1)]
    w("INSERT INTO solazeroth_v3_rangs VALUES %s;" % ", ".join(valeurs))
    w("DROP TABLE IF EXISTS solazeroth_v3_recettes;")
    w("CREATE TABLE solazeroth_v3_recettes (objet INT UNSIGNED NOT NULL PRIMARY KEY, forge TINYINT UNSIGNED NOT NULL, "
      "puissance TINYINT UNSIGNED NOT NULL, prix INT UNSIGNED NOT NULL);")
    w("INSERT INTO solazeroth_v3_recettes VALUES %s;" % ", ".join(
        "(%d, %d, %d, %d)" % (e, categorie in FORGE, max(0, p - 4), p * 5) for e, _, _, p, _, categorie in RECETTES))
    w("DROP TABLE IF EXISTS solazeroth_v3_recettes_composants;")
    w("CREATE TABLE solazeroth_v3_recettes_composants (objet INT UNSIGNED NOT NULL, composant INT UNSIGNED NOT NULL, "
      "nombre INT UNSIGNED NOT NULL, PRIMARY KEY (objet, composant));")
    w("INSERT INTO solazeroth_v3_recettes_composants VALUES %s;" % ", ".join(
        "(%d, %d, %d)" % (e, c, n) for e, _, _, _, composants, _ in RECETTES for c, n in composants.items()))
    w("")
    w("-- Marchands de Razor Hill : leurs pièces d'équipement d'origine (gardées dans solazeroth_v3_marchands_origine)")
    w("-- sont remplacées par nos pièces fabriquées.")
    liste = ",".join(map(str, MARCHANDS))
    w("CREATE TABLE IF NOT EXISTS solazeroth_v3_marchands_origine SELECT v.* FROM npc_vendor v JOIN item_template i "
      "ON i.entry = v.item WHERE v.entry IN (%s) AND i.class IN (2, 4);" % liste)
    w("DELETE v FROM npc_vendor v JOIN item_template i ON i.entry = v.item WHERE v.entry IN (%s) AND i.class IN (2, 4);"
      % liste)
    vente = []
    for marchand, categorie in MARCHANDS.items():
        cats = {"Cuir et tissu": {"Cuir", "Tissu"}}.get(categorie, {categorie})
        vente += ["(%d, %d, %d)" % (marchand, n, e) for n, (e, _, _, _, _, c) in enumerate(RECETTES) if c in cats]
    w("INSERT INTO npc_vendor (entry, slot, item) VALUES %s;" % ", ".join(vente))
    w("")

    d = down.append
    d("-- Retire l'équipement à fabriquer et les rangs, rend aux récompenses leurs chiffres d'origine et aux marchands")
    d("-- de Razor Hill leur liste. Les pièces fabriquées ou améliorées que possèdent les personnages disparaissent.")
    d("USE acore_world;")
    d("DELETE FROM npc_vendor WHERE entry IN (%s) AND item BETWEEN 910201 AND 910299;" % liste)
    d("INSERT IGNORE INTO npc_vendor SELECT * FROM solazeroth_v3_marchands_origine;")
    d("DROP TABLE solazeroth_v3_marchands_origine;")
    d("DROP TABLE solazeroth_v3_recettes_composants;")
    d("DROP TABLE solazeroth_v3_recettes;")
    d("DROP TABLE solazeroth_v3_rangs;")
    d("DELETE FROM item_template WHERE entry BETWEEN 910201 AND 910299 OR entry BETWEEN 921000 AND 922999;")
    for e, _, _, source, _ in EQUIPEMENT:
        d("UPDATE item_template d JOIN item_template o ON o.entry = %d SET %s WHERE d.entry = %d;" % (source, ", ".join(
            "d.%s = o.%s" % (k, k) for k in ["armor", "dmg_min1", "dmg_max1", "block"]
            + ["stat_type%d" % i for i in range(1, 11)] + ["stat_value%d" % i for i in range(1, 11)]), e))
    d("")
    for suffixe, lignes in ((".up.sql", up), (".down.sql", down)):
        with open(MIGRATION + suffixe, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(lignes))

    lua = ["-- Généré par outils\\equipement_v3.py : ne pas modifier à la main.",
           "-- Recettes de la fenêtre Équipement, par catégorie : { objet, nom, puissance de la pièce,",
           "-- puissance requise, prix en cuivre, { { composant, nombre }, … } }.",
           "SolUI.RECETTES = {"]
    for categorie in CATEGORIES:
        lua.append("    { nom = %s, forge = %s, recettes = {" % (lua_texte(categorie), "true" if categorie in FORGE else "false"))
        for e, nom, _, p, composants, c in RECETTES:
            if c == categorie:
                lua.append("        { %d, %s, %d, %d, %d, { %s } }," % (e, lua_texte(nom), p, max(0, p - 4), p * 5,
                           ", ".join("{ %d, %d }" % kv for kv in composants.items())))
        lua.append("    } },")
    lua.append("}")
    with open(RECETTES_LUA, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lua) + "\n")

    import quetes_durotar
    quetes_durotar.item_dbc()
    for e, nom, source, p in toutes[:3] + toutes[19:22]:
        c, _ = caracs[e]
        print(e, nom, "puissance", p, c)
    print("%d recettes, %d pièces améliorables, %d rangs : migration 078 et SolUI_Recettes.lua écrits."
          % (len(RECETTES), len(toutes), len(toutes) * RANGS))


def lua_texte(t):
    return '"' + t.replace("\\", "\\\\").replace('"', '\\"') + '"'


if __name__ == "__main__":
    main()
