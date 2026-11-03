"""Sol'Azeroth v3 : versions par classe des pièces que donne le monde (lots D3 du démoniste et V3 du voleur).

Le monde (récompenses de quête 910101-910119, annexes 910121-910139) donne de la maille, des boucliers et des épées,
faits pour le guerrier. Chaque classe reçoit à la place la version de son type, de même puissance et de mêmes rangs :
- démoniste (« Démoniste — proposition.md », question 3, b) : maille en tissu, bouclier en orbe, arme en dague ;
- voleur Assassinat (« Voleur — proposition.md », §7) : maille en cuir, bouclier en dague de main gauche, arme en dague.
Règles de l'utilisateur : le guerrier ne porte que de la maille (plus tard, de la plaque à partir de la puissance 40), le
démoniste que du tissu, le voleur que du cuir ; les capes, en tissu, vont à tous (v3_armures.cpp). Le démoniste ne
manie que dagues et bâtons, le voleur que des dagues (v3_kit.cpp).

- Même nom (sauf orbes et dagues), même puissance, même barème (equipement_v3.caracteristiques) : puissance
  d'attaque et Endurance de la pièce d'origine, armure du type (tissu 12 %, cuir 25 %, maille 40 % de réduction). Les
  orbes n'ont pas d'armure et prennent le poids du bouclier. Apparence : un objet vert d'origine du même emplacement.
- Les pièces fabriquées ne sont pas converties : chacun fabrique celles de son type.
- Table solazeroth_v3_versions (origine, classe, version), rangs compris. Le serveur donne la version au moment de la
  récompense (v3_armures.cpp ; annexes : v3_annexes.cpp), et la fenêtre de quête la montre déjà (SolUI_Versions.lua).
  Elle remplace la table solazeroth_v3_conversions (une seule version par pièce), retirée par la migration 130.

Migrations : 124 (tissu et orbes), 127 (dagues des armes de quête), 130 (cuir, dagues de main gauche, table des
versions). quetes_durotar.item_dbc() ajoute les nouvelles lignes à l'Item.dbc du patch.
Lot T2 des Tarides : SolUI_Versions.lua reçoit aussi les versions des récompenses des Tarides (quetes_tarides.py,
migration 139).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from quetes_durotar import s, sql
import equipement_v3 as e3

MIGRATION = r"C:\SolAzeroth\sql\migrations\124_v3_tissu"
MIGRATION_ARMES = r"C:\SolAzeroth\sql\migrations\127_v3_dagues"
MIGRATION_VERSIONS = r"C:\SolAzeroth\sql\migrations\130_v3_versions"
VERSIONS_LUA = r"C:\SolAzeroth\interface-v3\FrameXML\SolUI_Versions.lua"

DEMONISTE, VOLEUR = 9, 4                  # CLASS_WARLOCK, CLASS_ROGUE
MAILLE, BOUCLIER = 3, 6
MAIN_GAUCHE = 23
POIDS_MAIN_GAUCHE = e3.POIDS[14]          # celui du bouclier
# Apparence et type : objet vert d'origine, par emplacement (InventoryType).
MODELES = {5: 6241, 6: 2283, 7: 2958, 8: 3307, 9: 6543, 10: 3308, MAIN_GAUCHE: 15969}       # tissu, orbe
MODELES_CUIR = {5: 4861, 6: 15399, 7: 2962, 8: 23404, 9: 28147, 10: 4239}
DAGUE = 4947                              # Dague dentelée : verte, à une main, 1,5 s
PREMIERE, PREMIERE_CUIR, PREMIERE_DAGUE_MG = 910401, 910461, 910491
# Noms : un bouclier n'a pas de sens en orbe ni en dague.
ORBES = {910116: "Orbe de Margoz", 910122: "Orbe de la garde de Tiragarde", 910131: "Orbe de cendre"}
DAGUES_MG = {910116: "Dague de Margoz", 910122: "Dague de la garde de Tiragarde", 910131: "Dague de cendre"}
DAGUES = [(910108, 910451, "Dague d'officier de Kul Tiras"), (910113, 910452, "Dague de Sen'jin"),
          (910119, 910453, "Dague de l'Affameur"), (910125, 910454, "Dague du capitaine Plate-défense")]


def a_convertir():
    """Pièces de maille et boucliers que donne le monde : (entrée, nom, sous-classe, emplacement, puissance)."""
    lignes = sql("SELECT entry, name, subclass, InventoryType, ItemLevel FROM acore_world.item_template WHERE class = 4 "
                 "AND subclass IN (%d, %d) AND (entry BETWEEN 910101 AND 910119 OR entry BETWEEN 910121 AND 910139) "
                 "ORDER BY entry" % (MAILLE, BOUCLIER))
    return [(int(e), nom, int(sc), int(t), int(p)) for e, nom, sc, t, p in lignes]


def puissances_armes():
    return {int(e): int(p) for e, p in sql("SELECT entry, ItemLevel FROM acore_world.item_template WHERE entry IN (%s)"
                                           % ", ".join(str(o) for o, _, _ in DAGUES))}


def paires():
    """(pièce d'origine, version en tissu, nom, modèle, puissance), dans l'ordre des entrées (migration 124)."""
    return [(e, PREMIERE + i, ORBES.get(e, nom), MODELES[MAIN_GAUCHE if sc == BOUCLIER else t], p)
            for i, (e, nom, sc, t, p) in enumerate(a_convertir())]


def paires_armes():
    """Dagues des armes de quête (migration 127)."""
    puissances = puissances_armes()
    return [(o, n, nom, DAGUE, puissances[o]) for o, n, nom in DAGUES]


def paires_voleur():
    """Cuir des pièces de maille, dagues de main gauche des boucliers (migration 130)."""
    pieces = a_convertir()
    cuir = [(e, nom, t, p) for e, nom, sc, t, p in pieces if sc == MAILLE]
    boucliers = [(e, p) for e, nom, sc, t, p in pieces if sc == BOUCLIER]
    return ([(e, PREMIERE_CUIR + i, nom, MODELES_CUIR[t], p) for i, (e, nom, t, p) in enumerate(cuir)]
            + [(e, PREMIERE_DAGUE_MG + i, DAGUES_MG[e], DAGUE, p) for i, (e, p) in enumerate(boucliers)])


def lignes_dbc():
    """Item.dbc : (entrée, entrée dont on copie la ligne, genre), la base avant ses rangs."""
    lignes = []
    for _, n, _, modele, _ in paires() + paires_armes() + paires_voleur():
        lignes.append((n, modele, None))
        lignes += [(e3.entree_rang(n, r), n, None) for r in range(1, e3.RANGS + 1)]
    return lignes


def caracteristiques(modele, puissance, armures, armes):
    if int(modele["InventoryType"]) == MAIN_GAUCHE:
        return {"armor": 0, "dmg_min1": 0, "dmg_max1": 0,
                "ap": max(1, round(POIDS_MAIN_GAUCHE * puissance * e3.AP_PAR_POINT)),
                "endurance": round(POIDS_MAIN_GAUCHE * puissance * e3.ENDURANCE_PAR_POINT)}
    return e3.caracteristiques(modele, puissance, armures, armes)


def objets_sql(liste, armures, armes):
    """Pièces et leurs rangs 1 à 5 : (requêtes, entrées de base, toutes les entrées)."""
    modeles = e3.objets({m for _, _, _, m, _ in liste})
    nouvelles = [n for _, n, *_ in liste]
    toutes = [e3.entree_rang(n, r) if r else n for n in nouvelles for r in range(e3.RANGS + 1)]
    l = ["DELETE FROM item_template WHERE entry IN (%s);" % ", ".join(map(str, toutes))]
    for origine, n, nom, modele, p in liste:
        c = caracteristiques(modeles[modele], p, armures, armes)
        for r in range(e3.RANGS + 1):
            entree = e3.entree_rang(n, r) if r else n
            l.append("CREATE TEMPORARY TABLE sol_objet SELECT * FROM item_template WHERE entry = %d;" % modele)
            l.append("UPDATE sol_objet SET entry = %d, name = %s, description = '', Quality = 2, bonding = 1, "
                     "ItemLevel = %d, RequiredLevel = 0, RequiredSkill = 0, RequiredSkillRank = 0, AllowableClass = -1, "
                     "AllowableRace = -1, BuyPrice = 0, SellPrice = 0, RandomProperty = 0, RandomSuffix = 0, "
                     "spellid_1 = 0, spelltrigger_1 = 0, %s;"
                     % (entree, s("%s +%d" % (nom, r) if r else nom), p, e3.colonnes_sql(e3.au_rang(c, r, 0))))
            l.append("INSERT INTO item_template SELECT * FROM sol_objet;")
            l.append("DROP TEMPORARY TABLE sol_objet;")
    l.append("DELETE FROM solazeroth_v3_rangs WHERE base IN (%s);" % ", ".join(map(str, nouvelles)))
    l.append("INSERT INTO solazeroth_v3_rangs VALUES %s;" % ", ".join(
        "(%d, %d, %d)" % (e3.entree_rang(n, r) if r else n, n, r) for n in nouvelles for r in range(e3.RANGS + 1)))
    retrait = ["DELETE FROM solazeroth_v3_rangs WHERE base IN (%s);" % ", ".join(map(str, nouvelles)),
               "DELETE FROM item_template WHERE entry IN (%s);" % ", ".join(map(str, toutes))]
    return l, retrait


def ecrire(chemin, entete, up, down):
    for suffixe, lignes in ((".up.sql", entete + ["USE acore_world;"] + up), (".down.sql", down)):
        with open(chemin + suffixe, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(lignes) + "\n")


def versions():
    """(classe, origine, version, nom) pour chaque classe qui reçoit une autre version que la pièce du monde."""
    v = [(DEMONISTE, o, n, nom) for o, n, nom, _, _ in paires() + paires_armes()]
    v += [(VOLEUR, o, n, nom) for o, n, nom, _, _ in paires_voleur() + paires_armes()]
    return v


def ecrire_versions_lua():
    """SolUI_Versions.lua : versions de Durotar (ce fichier) et des zones suivantes (quetes_tarides.versions,
    lot T2 des Tarides ; pièces des annexes des Tarides, lot T4)."""
    import annexes_tarides
    import quetes_tarides
    toutes = versions() + quetes_tarides.versions() + quetes_tarides.versions(annexes_tarides.JEU)
    lua = ["-- Généré par outils\\tissu_v3.py : ne pas modifier à la main.",
           "-- Classe -> pièce du monde -> { sa version que la classe reçoit, son nom } (v3_armures.cpp).",
           "SolUI.VERSIONS = {"]
    for classe, cle in ((DEMONISTE, "WARLOCK"), (VOLEUR, "ROGUE")):
        lua.append("    %s = {" % cle)
        lua += ['        [%d] = { %d, "%s" },' % (o, n, nom) for c, o, n, nom in toutes if c == classe]
        lua.append("    },")
    lua.append("}")
    with open(VERSIONS_LUA, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lua) + "\n")


def main():
    armures, armes = e3.baremes()
    up, down = objets_sql(paires(), armures, armes)
    ecrire(MIGRATION, ["-- v3, lot D3 : versions en tissu des pièces du monde, pour le démoniste. Généré par "
                       "outils\\tissu_v3.py : ne pas", "-- modifier à la main."], up,
           ["-- Retire les versions en tissu des pièces du monde (celles que possèdent les personnages disparaissent).",
            "USE acore_world;"] + down)
    up, down = objets_sql(paires_armes(), armures, armes)
    ecrire(MIGRATION_ARMES, ["-- v3 : versions en dague des armes de quête, pour le démoniste et le voleur. Généré par "
                             "outils\\tissu_v3.py :", "-- ne pas modifier à la main."], up,
           ["-- Retire les versions en dague des armes de quête.", "USE acore_world;"] + down)
    up, down = objets_sql(paires_voleur(), armures, armes)
    lignes = []
    for classe, o, n, _ in versions():
        for r in range(e3.RANGS + 1):
            lignes.append("(%d, %d, %d)" % ((e3.entree_rang(o, r), classe, e3.entree_rang(n, r)) if r else (o, classe, n)))
    up += ["DROP TABLE IF EXISTS solazeroth_v3_conversions;",
           "CREATE TABLE IF NOT EXISTS solazeroth_v3_versions (origine INT UNSIGNED NOT NULL, classe TINYINT UNSIGNED "
           "NOT NULL, version INT UNSIGNED NOT NULL, PRIMARY KEY (origine, classe));",
           "DELETE FROM solazeroth_v3_versions;",
           "INSERT INTO solazeroth_v3_versions VALUES %s;" % ", ".join(lignes)]
    ecrire(MIGRATION_VERSIONS, ["-- v3, lot V3 : versions en cuir et dagues de main gauche pour le voleur, et table des "
                                "versions par classe.", "-- Généré par outils\\tissu_v3.py : ne pas modifier à la main."],
           up, ["-- Retire le cuir et les dagues de main gauche du voleur, et la table des versions.", "USE acore_world;",
                "DROP TABLE IF EXISTS solazeroth_v3_versions;"] + down)
    ecrire_versions_lua()
    import quetes_durotar
    quetes_durotar.item_dbc()
    modeles = e3.objets({m for _, _, _, m, _ in paires() + paires_armes() + paires_voleur()})
    for o, n, nom, modele, p in paires() + paires_armes() + paires_voleur():
        print(o, "->", n, nom, "puissance", p, caracteristiques(modeles[modele], p, armures, armes))
    print("%d versions par classe : migrations 124, 127 et 130, SolUI_Versions.lua et Item.dbc écrits." % len(versions()))


if __name__ == "__main__":
    main()
