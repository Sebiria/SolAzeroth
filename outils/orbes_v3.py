"""v3, lot D5 (02/11/2026, choix de l'utilisateur) : orbes à fabriquer, pour la main gauche du démoniste.

La forge fabrique deux boucliers (Rondache et Bouclier en cuivre) et le Gouffre le Rempart du Gouffre ; aucun métier
ne faisait d'objet de main gauche pour un lanceur de sorts. Trois orbes en joaillerie (idée de l'utilisateur : un orbe
est une pierre taillée), aux mêmes puissances, rangés avec les boucliers (« Armes et boucliers »), sans forge :
- Orbe de malachite brute (rudimentaire, puissance 3, comme la Rondache) : 1 Malachite brute, 2 Minerais de cuivre ;
- Orbe de malachite (puissance 9, comme le Bouclier en cuivre) : 1 Malachite taillée, 4 Minerais de cuivre ; vendu aussi
  par Cutac à Razor Hill ;
- Orbe ardent du Gouffre (bleu, puissance 14, comme le Rempart du Gouffre) : Braise, Œil de tigre taillé, 40 Éclats
  cadavériques, 4 Minerais de cuivre ; il compte dans la panoplie du Gouffre (v3_equipement.cpp, GOUFFRE_DERNIERE).
Coûts proches des boucliers : une pierre taillée demande environ 10 minerais (prospection, joaillerie_v3.py).
Même barème que les autres pièces (equipement_v3.caracteristiques, poids du bouclier), sans armure, comme les orbes
de tissu_v3.py ; mêmes rangs 1 à 5.

Migration à part (les migrations 078 et 101 effacent, à l'annulation, les pièces des personnages). Écrit la migration
125 et SolUI_RecettesOrbes.lua ; quetes_durotar.item_dbc() ajoute les lignes à l'Item.dbc du patch.

py orbes_v3.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from quetes_durotar import s
import equipement_v3 as e3
import equipement_gouffre_v3 as gouffre
import joaillerie_v3 as joaillerie

MIGRATION = r"C:\SolAzeroth\sql\migrations\125_v3_orbes"
LUA = r"C:\SolAzeroth\interface-v3\FrameXML\SolUI_RecettesOrbes.lua"
CUTAC = 3166                          # Razor Hill, cuir et tissu (equipement_v3.MARCHANDS)
ORBE_PERLEE, ORBE_ARCANIQUE = 15969, 7507   # apparence et type

# (entrée, nom, objet d'origine, puissance, catégorie de la fenêtre Équipement, qualité)
ORBES = [
    (910237, "Orbe de malachite brute", ORBE_PERLEE, 3, "Rudimentaire", 2),
    (910236, "Orbe de malachite", ORBE_PERLEE, 9, "Joaillerie", 2),
    (910272, "Orbe ardent du Gouffre", ORBE_ARCANIQUE, gouffre.PUISSANCE, "Gouffre : joaillerie", 3),
]
COMPOSANTS = {
    910237: [(joaillerie.MALACHITE, 1), (e3.CUIVRE, 2)],
    910236: [(gouffre.MALACHITE_TAILLEE, 1), (e3.CUIVRE, 4)],
    910272: [(gouffre.BRAISE, 1), (gouffre.OEIL_TIGRE_TAILLE, 1), (gouffre.ECLAT, 40), (e3.CUIVRE, 4)],
}
GENRE = "Armes et boucliers"


def composants(e, source):
    return COMPOSANTS[e]


def requise(e, p):
    return gouffre.PUISSANCE - 4 if e == 910272 else e3.requise(p)


def prix_recette(e, p, source):
    return gouffre.prix(source) if e == 910272 else p * 5


def lignes_dbc():
    lignes = [(e, src, None) for e, _, src, *_ in ORBES]
    for e, *_ in ORBES:
        lignes += [(e3.entree_rang(e, r), e, None) for r in range(1, e3.RANGS + 1)]
    return lignes


def main():
    armures, armes = gouffre.baremes()
    sources = e3.objets({src for _, _, src, *_ in ORBES})
    entrees = [e for e, *_ in ORBES]
    toutes = entrees + [e3.entree_rang(e, r) for e in entrees for r in range(1, e3.RANGS + 1)]
    liste = ", ".join(map(str, entrees))
    up = ["-- v3, lot D5 (02/11/2026) : orbes à fabriquer. Généré par outils\\orbes_v3.py : ne pas modifier à la main.",
          "USE acore_world;",
          "DELETE FROM item_template WHERE entry IN (%s);" % ", ".join(map(str, toutes))]
    w = up.append
    caracs = {}
    for e, nom, src, p, _, qualite in ORBES:
        source = sources[src]
        c = e3.caracteristiques(source, p, armures, armes)
        caracs[e] = c
        w("CREATE TEMPORARY TABLE sol_objet SELECT * FROM item_template WHERE entry = %d;" % src)
        w("UPDATE sol_objet SET entry = %d, name = %s, description = '', Quality = %d, bonding = 1, ItemLevel = %d, "
          "RequiredLevel = 0, RequiredSkill = 0, RequiredSkillRank = 0, AllowableClass = -1, AllowableRace = -1, "
          "BuyCount = 1, BuyPrice = %d, SellPrice = 0, RandomProperty = 0, RandomSuffix = 0, spellid_1 = 0, "
          "spelltrigger_1 = 0, spellid_2 = 0, spelltrigger_2 = 0, itemset = 0, %s;"
          % (e, s(nom), qualite, p, e3.prix(p, e3.POIDS[23]), e3.colonnes_sql(e3.au_rang(c, 0, 0))))
        w("INSERT INTO item_template SELECT * FROM sol_objet;")
        w("DROP TEMPORARY TABLE sol_objet;")
    w("")
    w("-- Rangs 1 à 5 : +10 % par rang.")
    for e, nom, *_ in ORBES:
        for r in range(1, e3.RANGS + 1):
            w("CREATE TEMPORARY TABLE sol_objet SELECT * FROM item_template WHERE entry = %d;" % e)
            w("UPDATE sol_objet SET entry = %d, name = %s, BuyPrice = 0, %s;"
              % (e3.entree_rang(e, r), s("%s +%d" % (nom, r)), e3.colonnes_sql(e3.au_rang(caracs[e], r, 0))))
            w("INSERT INTO item_template SELECT * FROM sol_objet;")
            w("DROP TEMPORARY TABLE sol_objet;")
    w("DELETE FROM solazeroth_v3_rangs WHERE base IN (%s);" % liste)
    w("INSERT INTO solazeroth_v3_rangs VALUES %s;" % ", ".join(
        "(%d, %d, %d)" % (e3.entree_rang(e, r) if r else e, e, r) for e in entrees for r in range(e3.RANGS + 1)))
    w("")
    w("-- Recettes : joaillerie, sans forge.")
    w("DELETE FROM solazeroth_v3_recettes WHERE objet IN (%s);" % liste)
    w("DELETE FROM solazeroth_v3_recettes_composants WHERE objet IN (%s);" % liste)
    w("INSERT INTO solazeroth_v3_recettes VALUES %s;" % ", ".join(
        "(%d, 0, %d, %d)" % (e, requise(e, p), prix_recette(e, p, sources[src])) for e, _, src, p, *_ in ORBES))
    w("INSERT INTO solazeroth_v3_recettes_composants VALUES %s;" % ", ".join(
        "(%d, %d, %d)" % (e, c, n) for e, _, src, *_ in ORBES for c, n in composants(e, sources[src])))
    w("INSERT IGNORE INTO npc_vendor (entry, slot, item) VALUES (%d, 0, 910236);" % CUTAC)
    w("")
    down = ["-- Retire les orbes à fabriquer. Ceux que possèdent les personnages disparaissent.",
            "USE acore_world;",
            "DELETE FROM npc_vendor WHERE entry = %d AND item = 910236;" % CUTAC,
            "DELETE FROM solazeroth_v3_recettes_composants WHERE objet IN (%s);" % liste,
            "DELETE FROM solazeroth_v3_recettes WHERE objet IN (%s);" % liste,
            "DELETE FROM solazeroth_v3_rangs WHERE base IN (%s);" % liste,
            "DELETE FROM item_template WHERE entry IN (%s);" % ", ".join(map(str, toutes)), ""]
    for suffixe, lignes in ((".up.sql", up), (".down.sql", down)):
        with open(MIGRATION + suffixe, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(lignes))

    l = ["-- Généré par outils\\orbes_v3.py : ne pas modifier à la main.",
         "-- Lot D5 : orbes de joaillerie, rangés avec les boucliers de leur niveau (même format que SolUI_Recettes.lua)."]
    for e, nom, src, p, categorie, _ in ORBES:
        drapeau = ", gouffre = true" if categorie.startswith("Gouffre") else ""
        l.append("table.insert(SolUI.RECETTES, { nom = %s, forge = false%s, recettes = {" % (e3.lua_texte(categorie), drapeau))
        l.append("    { %d, %s, %d, %d, %d, { %s }, %s }," % (e, e3.lua_texte(nom), p, requise(e, p),
                 prix_recette(e, p, sources[src]), ", ".join("{ %d, %d }" % cn for cn in composants(e, sources[src])),
                 e3.lua_texte(GENRE)))
        l.append("} })")
    with open(LUA, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(l) + "\n")

    import quetes_durotar
    quetes_durotar.item_dbc()
    for e, nom, _, p, *_ in ORBES:
        print(e, nom, "puissance", p, caracs[e])
    print("Migration 125 et SolUI_RecettesOrbes.lua écrits.")


if __name__ == "__main__":
    main()
