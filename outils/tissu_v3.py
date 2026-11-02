"""Sol'Azeroth v3, lot D3 (02/11/2026) : versions en tissu des pièces que donne le monde, pour le démoniste.

Choix de l'utilisateur (« Démoniste — proposition.md », question 3, b) : chaque pièce de maille gagnée devient, pour un
démoniste, sa version en tissu de même puissance ; chaque bouclier, un orbe tenu en main gauche. Règle des armures par
classe : le guerrier ne porte que de la maille (plus tard, de la plaque à partir de la puissance 40), le démoniste que
du tissu ; les capes, en tissu, vont à tous (v3_armures.cpp).

- Pièces converties : celles que donne le monde sans qu'on les choisisse, c'est-à-dire les récompenses de quête
  (910101-910119) et des annexes (910121-910132). Les pièces fabriquées ne le sont pas : chacun fabrique celles de son
  type (les recettes de tissu de Durotar et du Gouffre couvrent déjà les emplacements de la maille).
- Même nom, même puissance, même barème (equipement_v3.caracteristiques) : la puissance d'attaque et l'Endurance sont
  celles de la maille, seule l'armure est celle du tissu (12 % de réduction au lieu de 40 %). Les orbes n'ont pas
  d'armure et prennent le poids du bouclier. Apparence : un objet vert d'origine en tissu du même emplacement.
- Mêmes rangs 1 à 5 (solazeroth_v3_rangs) ; la table solazeroth_v3_conversions apparie chaque pièce (et chaque rang)
  à sa version, dans les deux sens. Le serveur échange la pièce reçue (v3_armures.cpp).

Écrit la migration 124 et SolUI_Versions.lua (la fenêtre de quête montre au démoniste la version qu'il recevra) ;
quetes_durotar.item_dbc() ajoute les nouvelles lignes à l'Item.dbc du patch.

Armes (02/11/2026, règles de l'utilisateur) : le démoniste ne manie que dagues et bâtons, le voleur Assassinat que des
dagues. Les épées et la masse que donnent les quêtes ont donc leur version en dague, de même puissance et de mêmes
rangs (migration 127, qui ajoute ses paires à la table de la 124 : rejouer la 127 après toute reprise de la 124). Les
armes du Gouffre se fabriquent : chacun fabrique la sienne (Lame psalmodiante, une dague).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from quetes_durotar import s, sql
import equipement_v3 as e3

MIGRATION = r"C:\SolAzeroth\sql\migrations\124_v3_tissu"
VERSIONS_LUA = r"C:\SolAzeroth\interface-v3\FrameXML\SolUI_Versions.lua"

MAILLE, BOUCLIER = 3, 6
MAIN_GAUCHE = 23
POIDS_MAIN_GAUCHE = e3.POIDS[14]          # celui du bouclier
# Apparence et type : objet vert d'origine en tissu, par emplacement (InventoryType).
MODELES = {5: 6241, 6: 2283, 7: 2958, 8: 3307, 9: 6543, 10: 3308, MAIN_GAUCHE: 15969}
PREMIERE = 910401
# Noms des orbes (un bouclier tenu en main gauche n'a pas de sens en orbe).
ORBES = {910116: "Orbe de Margoz", 910122: "Orbe de la garde de Tiragarde", 910131: "Orbe de cendre"}
MIGRATION_ARMES = r"C:\SolAzeroth\sql\migrations\127_v3_dagues"
DAGUE = 4947                              # Dague dentelée : verte, à une main, 1,5 s
DAGUES = [(910108, 910451, "Dague d'officier de Kul Tiras"), (910113, 910452, "Dague de Sen'jin"),
          (910119, 910453, "Dague de l'Affameur"), (910125, 910454, "Dague du capitaine Plate-défense")]


def a_convertir():
    """Pièces de maille et boucliers que donne le monde : (entrée, nom, sous-classe, emplacement, puissance)."""
    lignes = sql("SELECT entry, name, subclass, InventoryType, ItemLevel FROM acore_world.item_template WHERE class = 4 "
                 "AND subclass IN (%d, %d) AND (entry BETWEEN 910101 AND 910119 OR entry BETWEEN 910121 AND 910139) "
                 "ORDER BY entry" % (MAILLE, BOUCLIER))
    return [(int(e), nom, int(sc), int(t), int(p)) for e, nom, sc, t, p in lignes]


def paires():
    """(pièce d'origine, version en tissu, nom, modèle, puissance), dans l'ordre des entrées."""
    return [(e, PREMIERE + i, ORBES.get(e, nom), MODELES[MAIN_GAUCHE if sc == BOUCLIER else t], p)
            for i, (e, nom, sc, t, p) in enumerate(a_convertir())]


def lignes_dbc():
    """Item.dbc : (entrée, entrée dont on copie la ligne, genre), la base avant ses rangs."""
    lignes = []
    for _, n, _, modele, _ in paires():
        lignes.append((n, modele, None))
        lignes += [(e3.entree_rang(n, r), n, None) for r in range(1, e3.RANGS + 1)]
    for _, n, _ in DAGUES:
        lignes.append((n, DAGUE, None))
        lignes += [(e3.entree_rang(n, r), n, None) for r in range(1, e3.RANGS + 1)]
    return lignes


def puissances_armes():
    return {int(e): int(p) for e, p in sql("SELECT entry, ItemLevel FROM acore_world.item_template WHERE entry IN (%s)"
                                           % ", ".join(str(o) for o, _, _ in DAGUES))}


def ecrire_armes(armures, armes):
    """Migration 127 : versions en dague des armes de quête, et leurs paires dans solazeroth_v3_conversions."""
    modele = e3.objets({DAGUE})[DAGUE]
    puissances = puissances_armes()
    nouvelles = [n for _, n, _ in DAGUES]
    toutes = [e3.entree_rang(n, r) if r else n for n in nouvelles for r in range(e3.RANGS + 1)]
    up = ["-- v3 : versions en dague des armes de quête, pour le démoniste et le voleur. Généré par outils\\tissu_v3.py :",
          "-- ne pas modifier à la main.",
          "USE acore_world;"]
    w = up.append
    w("DELETE FROM item_template WHERE entry IN (%s);" % ", ".join(map(str, toutes)))
    for origine, n, nom in DAGUES:
        c = e3.caracteristiques(modele, puissances[origine], armures, armes)
        for r in range(e3.RANGS + 1):
            entree = e3.entree_rang(n, r) if r else n
            w("CREATE TEMPORARY TABLE sol_objet SELECT * FROM item_template WHERE entry = %d;" % DAGUE)
            w("UPDATE sol_objet SET entry = %d, name = %s, description = '', Quality = 2, bonding = 1, ItemLevel = %d, "
              "RequiredLevel = 0, RequiredSkill = 0, RequiredSkillRank = 0, AllowableClass = -1, AllowableRace = -1, "
              "BuyPrice = 0, SellPrice = 0, RandomProperty = 0, RandomSuffix = 0, spellid_1 = 0, spelltrigger_1 = 0, "
              "%s;" % (entree, s("%s +%d" % (nom, r) if r else nom), puissances[origine],
                       e3.colonnes_sql(e3.au_rang(c, r, 0))))
            w("INSERT INTO item_template SELECT * FROM sol_objet;")
            w("DROP TEMPORARY TABLE sol_objet;")
    w("DELETE FROM solazeroth_v3_rangs WHERE base IN (%s);" % ", ".join(map(str, nouvelles)))
    w("INSERT INTO solazeroth_v3_rangs VALUES %s;" % ", ".join(
        "(%d, %d, %d)" % (e3.entree_rang(n, r) if r else n, n, r) for n in nouvelles for r in range(e3.RANGS + 1)))
    paires_armes = []
    for origine, n, _ in DAGUES:
        for r in range(e3.RANGS + 1):
            a, b = (e3.entree_rang(origine, r), e3.entree_rang(n, r)) if r else (origine, n)
            paires_armes += [(a, b), (b, a)]
    w("REPLACE INTO solazeroth_v3_conversions VALUES %s;" % ", ".join("(%d, %d)" % p for p in paires_armes))
    down = ["-- Retire les versions en dague des armes de quête.",
            "USE acore_world;",
            "DELETE FROM solazeroth_v3_conversions WHERE origine IN (%s);" % ", ".join(str(a) for a, _ in paires_armes),
            "DELETE FROM solazeroth_v3_rangs WHERE base IN (%s);" % ", ".join(map(str, nouvelles)),
            "DELETE FROM item_template WHERE entry IN (%s);" % ", ".join(map(str, toutes))]
    for suffixe, lignes in ((".up.sql", up), (".down.sql", down)):
        with open(MIGRATION_ARMES + suffixe, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(lignes) + "\n")
    for origine, n, nom in DAGUES:
        print(origine, "->", n, nom, "puissance", puissances[origine],
              e3.caracteristiques(modele, puissances[origine], armures, armes))


def caracteristiques(modele, puissance, armures, armes):
    if int(modele["InventoryType"]) == MAIN_GAUCHE:
        return {"armor": 0, "dmg_min1": 0, "dmg_max1": 0,
                "ap": max(1, round(POIDS_MAIN_GAUCHE * puissance * e3.AP_PAR_POINT)),
                "endurance": round(POIDS_MAIN_GAUCHE * puissance * e3.ENDURANCE_PAR_POINT)}
    return e3.caracteristiques(modele, puissance, armures, armes)


def main():
    armures, armes = e3.baremes()
    liste = paires()
    modeles = e3.objets({m for _, _, _, m, _ in liste})
    up = ["-- v3, lot D3 : versions en tissu des pièces du monde, pour le démoniste. Généré par outils\\tissu_v3.py : ne pas",
          "-- modifier à la main.",
          "USE acore_world;"]
    w = up.append
    nouvelles = [n for _, n, *_ in liste]
    toutes = [e3.entree_rang(n, r) if r else n for n in nouvelles for r in range(e3.RANGS + 1)]
    w("DELETE FROM item_template WHERE entry IN (%s);" % ", ".join(map(str, toutes)))
    for origine, n, nom, modele, p in liste:
        c = caracteristiques(modeles[modele], p, armures, armes)
        for r in range(e3.RANGS + 1):
            entree = e3.entree_rang(n, r) if r else n
            w("CREATE TEMPORARY TABLE sol_objet SELECT * FROM item_template WHERE entry = %d;" % modele)
            w("UPDATE sol_objet SET entry = %d, name = %s, description = '', Quality = 2, bonding = 1, ItemLevel = %d, "
              "RequiredLevel = 0, RequiredSkill = 0, RequiredSkillRank = 0, AllowableClass = -1, AllowableRace = -1, "
              "BuyPrice = 0, SellPrice = 0, RandomProperty = 0, RandomSuffix = 0, spellid_1 = 0, spelltrigger_1 = 0, "
              "%s;" % (entree, s("%s +%d" % (nom, r) if r else nom), p, e3.colonnes_sql(e3.au_rang(c, r, 0))))
            w("INSERT INTO item_template SELECT * FROM sol_objet;")
            w("DROP TEMPORARY TABLE sol_objet;")
    w("DELETE FROM solazeroth_v3_rangs WHERE base IN (%s);" % ", ".join(map(str, nouvelles)))
    w("INSERT INTO solazeroth_v3_rangs VALUES %s;" % ", ".join(
        "(%d, %d, %d)" % (e3.entree_rang(n, r) if r else n, n, r) for n in nouvelles for r in range(e3.RANGS + 1)))
    w("CREATE TABLE IF NOT EXISTS solazeroth_v3_conversions (origine INT UNSIGNED NOT NULL PRIMARY KEY, "
      "version INT UNSIGNED NOT NULL);")
    w("DELETE FROM solazeroth_v3_conversions;")
    valeurs = []
    for origine, n, *_ in liste:
        for r in range(e3.RANGS + 1):
            a, b = (e3.entree_rang(origine, r), e3.entree_rang(n, r)) if r else (origine, n)
            valeurs += ["(%d, %d)" % (a, b), "(%d, %d)" % (b, a)]
    w("INSERT INTO solazeroth_v3_conversions VALUES %s;" % ", ".join(valeurs))
    down = ["-- Retire les versions en tissu des pièces du monde (celles que possèdent les personnages disparaissent).",
            "USE acore_world;",
            "DROP TABLE solazeroth_v3_conversions;",
            "DELETE FROM solazeroth_v3_rangs WHERE base IN (%s);" % ", ".join(map(str, nouvelles)),
            "DELETE FROM item_template WHERE entry IN (%s);" % ", ".join(map(str, toutes))]
    for suffixe, lignes in ((".up.sql", up), (".down.sql", down)):
        with open(MIGRATION + suffixe, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(lignes) + "\n")
    lua = ["-- Généré par outils\\tissu_v3.py : ne pas modifier à la main.",
           "-- Classe -> pièce du monde -> { sa version que la classe reçoit, son nom } (v3_armures.cpp).",
           "SolUI.VERSIONS = {", "    WARLOCK = {"]
    lua += ['        [%d] = { %d, "%s" },' % (origine, n, nom) for origine, n, nom, _, _ in liste]
    lua += ['        [%d] = { %d, "%s" },' % (origine, n, nom) for origine, n, nom in DAGUES]
    lua += ["    },", "    ROGUE = {"]
    lua += ['        [%d] = { %d, "%s" },' % (origine, n, nom) for origine, n, nom in DAGUES]
    lua += ["    },", "}"]
    with open(VERSIONS_LUA, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lua) + "\n")
    ecrire_armes(armures, armes)
    import quetes_durotar
    quetes_durotar.item_dbc()
    for origine, n, nom, modele, p in liste:
        print(origine, "->", n, nom, "puissance", p, caracteristiques(modeles[modele], p, armures, armes))
    print("%d versions en tissu, %d rangs : migration 124 et Item.dbc écrits." % (len(liste), len(liste) * e3.RANGS))


if __name__ == "__main__":
    main()
