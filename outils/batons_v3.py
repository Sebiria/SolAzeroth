"""v3 (02/11/2026, choix de l'utilisateur) : bâtons à fabriquer, pour le démoniste.

Règle de l'utilisateur : le démoniste manie dagues et bâtons. Le bâton se tient à deux mains, sans orbe : il vaut donc
une dague et un orbe de même puissance réunis (recommandation acceptée) :
- puissance d'attaque et Endurance : celles de la dague plus celles de l'orbe (poids 0,56 + 0,56) ;
- dégâts par seconde : ceux d'une arme à une main de même puissance (le démoniste en tire sa puissance d'attaque,
  v3_niveau.cpp, PuissanceDeLArme) ;
- recette : celle de la dague plus celle de l'orbe du même palier.
Trois paliers, aux puissances des dagues : Bâton grossier de malachite (rudimentaire, 4), Bâton de malachite (forge,
9), Bâton ardent du Gouffre (bleu, 14, dans la panoplie du Gouffre : il compte pour deux pièces, comme toute arme à
deux mains, v3_equipement.cpp). Mêmes rangs 1 à 5.

Migration à part (128) ; écrit aussi SolUI_RecettesBatons.lua ; quetes_durotar.item_dbc() ajoute les lignes à
l'Item.dbc du patch.

py batons_v3.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from quetes_durotar import s
import equipement_v3 as e3
import equipement_gouffre_v3 as gouffre
import joaillerie_v3 as joaillerie

MIGRATION = r"C:\SolAzeroth\sql\migrations\128_v3_batons"
LUA = r"C:\SolAzeroth\interface-v3\FrameXML\SolUI_RecettesBatons.lua"
BATON_VERT, BATON_BLEU = 1933, 890          # Bâton de conjuration, Bâton du psalmodieur tordu : apparence et type
ORBE_DE = {4: 3, 9: 9, gouffre.PUISSANCE: gouffre.PUISSANCE}   # puissance de l'orbe du même palier (orbes_v3.py)

# (entrée, nom, objet d'origine, puissance, catégorie de la fenêtre Équipement, forge, qualité)
BATONS = [
    (910455, "Bâton grossier de malachite", BATON_VERT, 4, "Rudimentaire", False, 2),
    (910456, "Bâton de malachite", BATON_VERT, 9, "Armes", True, 2),
    (910273, "Bâton ardent du Gouffre", BATON_BLEU, gouffre.PUISSANCE, "Gouffre : armes", True, 3),
]
# Dague et orbe du même palier, réunis (equipement_v3, equipement_gouffre_v3, orbes_v3).
COMPOSANTS = {
    910455: [(e3.CUIVRE, 4), (e3.LANIERES, 1), (joaillerie.MALACHITE, 1)],
    910456: [(e3.CUIVRE, 10), (e3.PIERRE, 2), (e3.CUIR, 2), (gouffre.MALACHITE_TAILLEE, 1)],
    910273: [(gouffre.BRAISE, 4), (e3.CUIVRE, 20), (gouffre.ECLAT, 120), (gouffre.OEIL_TIGRE_TAILLE, 2)],
}
REQUISE = {910455: 0, 910456: 7, 910273: gouffre.PUISSANCE - 4}
PRIX = {910455: 35, 910456: 90}
GENRE = "Armes et boucliers"


def prix_recette(e, source):
    return PRIX.get(e) or 2 * gouffre.prix(source)


def lignes_dbc():
    lignes = [(e, src, None) for e, _, src, *_ in BATONS]
    for e, *_ in BATONS:
        lignes += [(e3.entree_rang(e, r), e, None) for r in range(1, e3.RANGS + 1)]
    return lignes


def caracteristiques(source, p, armures, armes):
    """Puissance d'attaque et Endurance d'une dague et d'un orbe réunis ; dégâts par seconde d'une arme à une main."""
    a, b = armes[False]
    cadence = int(source["delay"]) / 1000
    moyenne = max(1.0, a + b * p) * cadence
    bas, haut = float(source["dmg_min1"]), float(source["dmg_max1"])
    part = bas / (bas + haut) if bas + haut else 0.4
    c = {"armor": 0, "dmg_min1": max(1, round(moyenne * 2 * part))}
    c["dmg_max1"] = max(c["dmg_min1"] + 1, round(moyenne * 2 * (1 - part)))
    for poids, puissance in ((e3.POIDS[13], p), (e3.POIDS[23], ORBE_DE[p])):
        c["ap"] = c.get("ap", 0) + max(1, round(poids * puissance * e3.AP_PAR_POINT))
        c["endurance"] = c.get("endurance", 0) + round(poids * puissance * e3.ENDURANCE_PAR_POINT)
    return c


def main():
    armures, armes = gouffre.baremes()
    sources = e3.objets({src for _, _, src, *_ in BATONS})
    entrees = [e for e, *_ in BATONS]
    toutes = entrees + [e3.entree_rang(e, r) for e in entrees for r in range(1, e3.RANGS + 1)]
    liste = ", ".join(map(str, entrees))
    up = ["-- v3 (02/11/2026) : bâtons à fabriquer, pour le démoniste. Généré par outils\\batons_v3.py : ne pas modifier à",
          "-- la main.",
          "USE acore_world;",
          "DELETE FROM item_template WHERE entry IN (%s);" % ", ".join(map(str, toutes))]
    w = up.append
    caracs = {}
    for e, nom, src, p, _, _, qualite in BATONS:
        c = caracteristiques(sources[src], p, armures, armes)
        caracs[e] = c
        w("CREATE TEMPORARY TABLE sol_objet SELECT * FROM item_template WHERE entry = %d;" % src)
        w("UPDATE sol_objet SET entry = %d, name = %s, description = '', Quality = %d, bonding = 1, ItemLevel = %d, "
          "RequiredLevel = 0, RequiredSkill = 0, RequiredSkillRank = 0, AllowableClass = -1, AllowableRace = -1, "
          "BuyCount = 1, BuyPrice = 0, SellPrice = 0, RandomProperty = 0, RandomSuffix = 0, spellid_1 = 0, "
          "spelltrigger_1 = 0, spellid_2 = 0, spelltrigger_2 = 0, itemset = 0, %s;"
          % (e, s(nom), qualite, p, e3.colonnes_sql(e3.au_rang(c, 0, 0))))
        w("INSERT INTO item_template SELECT * FROM sol_objet;")
        w("DROP TEMPORARY TABLE sol_objet;")
    w("")
    w("-- Rangs 1 à 5 : +10 % par rang.")
    for e, nom, *_ in BATONS:
        for r in range(1, e3.RANGS + 1):
            w("CREATE TEMPORARY TABLE sol_objet SELECT * FROM item_template WHERE entry = %d;" % e)
            w("UPDATE sol_objet SET entry = %d, name = %s, %s;"
              % (e3.entree_rang(e, r), s("%s +%d" % (nom, r)), e3.colonnes_sql(e3.au_rang(caracs[e], r, 0))))
            w("INSERT INTO item_template SELECT * FROM sol_objet;")
            w("DROP TEMPORARY TABLE sol_objet;")
    w("DELETE FROM solazeroth_v3_rangs WHERE base IN (%s);" % liste)
    w("INSERT INTO solazeroth_v3_rangs VALUES %s;" % ", ".join(
        "(%d, %d, %d)" % (e3.entree_rang(e, r) if r else e, e, r) for e in entrees for r in range(e3.RANGS + 1)))
    w("")
    w("DELETE FROM solazeroth_v3_recettes WHERE objet IN (%s);" % liste)
    w("DELETE FROM solazeroth_v3_recettes_composants WHERE objet IN (%s);" % liste)
    w("INSERT INTO solazeroth_v3_recettes VALUES %s;" % ", ".join(
        "(%d, %d, %d, %d)" % (e, forge, REQUISE[e], prix_recette(e, sources[src]))
        for e, _, src, _, _, forge, _ in BATONS))
    w("INSERT INTO solazeroth_v3_recettes_composants VALUES %s;" % ", ".join(
        "(%d, %d, %d)" % (e, c, n) for e, *_ in BATONS for c, n in COMPOSANTS[e]))
    w("")
    down = ["-- Retire les bâtons à fabriquer. Ceux que possèdent les personnages disparaissent.",
            "USE acore_world;",
            "DELETE FROM solazeroth_v3_recettes_composants WHERE objet IN (%s);" % liste,
            "DELETE FROM solazeroth_v3_recettes WHERE objet IN (%s);" % liste,
            "DELETE FROM solazeroth_v3_rangs WHERE base IN (%s);" % liste,
            "DELETE FROM item_template WHERE entry IN (%s);" % ", ".join(map(str, toutes)), ""]
    for suffixe, lignes in ((".up.sql", up), (".down.sql", down)):
        with open(MIGRATION + suffixe, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(lignes))

    l = ["-- Généré par outils\\batons_v3.py : ne pas modifier à la main.",
         "-- Bâtons du démoniste, rangés avec les armes de leur niveau (même format que SolUI_Recettes.lua)."]
    for e, nom, src, p, categorie, forge, _ in BATONS:
        drapeau = ", donjon = true" if categorie.startswith("Gouffre") else ""
        l.append("table.insert(SolUI.RECETTES, { nom = %s, forge = %s%s, recettes = {"
                 % (e3.lua_texte(categorie), "true" if forge else "false", drapeau))
        l.append("    { %d, %s, %d, %d, %d, { %s }, %s }," % (e, e3.lua_texte(nom), p, REQUISE[e],
                 prix_recette(e, sources[src]), ", ".join("{ %d, %d }" % cn for cn in COMPOSANTS[e]),
                 e3.lua_texte(GENRE)))
        l.append("} })")
    with open(LUA, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(l) + "\n")

    import quetes_durotar
    quetes_durotar.item_dbc()
    for e, nom, _, p, *_ in BATONS:
        print(e, nom, "puissance", p, caracs[e])
    print("Migration 128 et SolUI_RecettesBatons.lua écrits.")


if __name__ == "__main__":
    main()
