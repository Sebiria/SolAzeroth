"""v3 (01/11/2026, demande de l'utilisateur) : récompense du Gouffre de Ragefeu.

- Composant de donjon : Braise du Gouffre (910190), rangée dans la Collection. Chaque boss en donne une avec 15 % de
  chances par difficulté, et le dernier des boss tués d'une instance en donne une de plus (v3_donjons.cpp, table
  solazeroth_v3_donjons_composants).
- Pièces bleues de puissance 14, une par emplacement (ni bagues, ni cou, ni bijoux : plus tard, avec la joaillerie
  d'une autre zone), en maille, cuir et tissu, plus la cape, le bouclier et les armes. Même barème que les pièces
  vertes (equipement_v3.py), mêmes rangs 1 à 5.
- Recettes : 1 Braise par pièce d'armure et par bouclier, 3 par arme (choix de l'utilisateur), et une liste de courses
  non négligeable : matériau de base, éclats cadavériques, une pierre taillée et de l'or. La fenêtre Équipement montre
  4 composants au plus et 8 recettes par catégorie. Chiffres provisoires, à calibrer avec l'économie.
- Apparence et type repris d'un objet d'origine : ceux du Gouffre quand il y en a (Lame maudite, Cape souterraine,
  Robe d'évocation, Lame psalmodiante, Manchettes cristallines, Brassards troglodytes), sinon un objet proche.

Écrit la migration 101 et interface-v3\\FrameXML\\SolUI_RecettesGouffre.lua ; quetes_durotar.item_dbc() ajoute les
nouvelles lignes à l'Item.dbc du patch.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from quetes_durotar import s, sql
import equipement_v3 as e3

MIGRATION = r"C:\SolAzeroth\sql\migrations\101_v3_gouffre_bleu"
LUA = r"C:\SolAzeroth\interface-v3\FrameXML\SolUI_RecettesGouffre.lua"

GOUFFRE = 389
BRAISE, BRAISE_SOURCE = 910190, 7077   # Cœur de feu : apparence et type de composant
ECLAT, MALACHITE_TAILLEE, OEIL_TIGRE_TAILLE = 910120, 910180, 910181
PUISSANCE = 14

# (entrée, nom, objet d'origine, catégorie, matériau, nombre)
PIECES = [
    (910241, "Heaume du Gouffre", 3836, "maille", e3.CUIVRE, 20),
    (910242, "Spallières du Gouffre", 3841, "maille", e3.CUIVRE, 18),
    (910243, "Haubert du Gouffre", 6642, "maille", e3.CUIVRE, 32),
    (910244, "Brassards troglodytes du Gouffre", 14147, "maille", e3.CUIVRE, 10),
    (910245, "Gantelets du Gouffre", 12994, "maille", e3.CUIVRE, 16),
    (910246, "Ceinturon du Gouffre", 5425, "maille", e3.CUIVRE, 14),
    (910247, "Cuissards du Gouffre", 6087, "maille", e3.CUIVRE, 22),
    (910248, "Solerets du Gouffre", 12982, "maille", e3.CUIVRE, 16),
    (910249, "Capuche du Gouffre", 3020, "cuir", e3.CUIR, 16),
    (910250, "Épaulettes du Gouffre", 5254, "cuir", e3.CUIR, 14),
    (910251, "Tunique du Gouffre", 12988, "cuir", e3.CUIR, 22),
    (910252, "Brassards du Gouffre", 12999, "cuir", e3.CUIR, 10),
    (910253, "Gants du Gouffre", 10413, "cuir", e3.CUIR, 12),
    (910254, "Ceinture du Gouffre", 10412, "cuir", e3.CUIR, 12),
    (910255, "Jambières du Gouffre", 10410, "cuir", e3.CUIR, 18),
    (910256, "Bottes du Gouffre", 10411, "cuir", e3.CUIR, 12),
    (910257, "Capuchon du Gouffre", 3889, "tissu", e3.LIN, 18),
    (910258, "Mantelet du Gouffre", 12998, "tissu", e3.LIN, 16),
    (910259, "Robe d'évocation du Gouffre", 14150, "tissu", e3.LIN, 26),
    (910260, "Manchettes cristallines du Gouffre", 14148, "tissu", e3.LIN, 12),
    (910261, "Mitaines du Gouffre", 12977, "tissu", e3.LIN, 14),
    (910262, "Cordelière du Gouffre", 2911, "tissu", e3.LIN, 14),
    (910263, "Pantalon du Gouffre", 12987, "tissu", e3.LIN, 20),
    (910264, "Sandales du Gouffre", 4320, "tissu", e3.LIN, 14),
    (910265, "Lame maudite du Gouffre", 14145, "armes", e3.CUIVRE, 20),
    (910266, "Hache du Gouffre", 5426, "armes", e3.CUIVRE, 20),
    (910267, "Masse du Gouffre", 5197, "armes", e3.CUIVRE, 20),
    (910268, "Lame psalmodiante du Gouffre", 14151, "armes", e3.CUIVRE, 16),
    (910269, "Lame ardente du Gouffre", 12992, "armes", e3.CUIVRE, 32),
    (910270, "Rempart du Gouffre", 6447, "armes", e3.CUIVRE, 22),
    (910271, "Cape souterraine du Gouffre", 14149, "armes", e3.LIN, 14),
]
CATEGORIES = [("maille", "Gouffre : maille", True), ("cuir", "Gouffre : cuir", False),
              ("tissu", "Gouffre : tissu", False), ("armes", "Gouffre : armes", True)]


def baremes():
    """Barème des pièces vertes ; les emplacements sans objet vert de niveau 5 à 30 (casque et épaules en maille) se
    lisent jusqu'au niveau 45."""
    armures, armes = e3.baremes()
    larges = {}
    for sous_classe, emplacement, niveau, armure in sql(
            "SELECT subclass, InventoryType, ItemLevel, armor FROM acore_world.item_template WHERE class = 4 "
            "AND Quality = 2 AND ItemLevel BETWEEN 5 AND 45 AND armor > 0 AND subclass IN (1, 2, 3, 6)"):
        emplacement = 5 if emplacement == "20" else int(emplacement)
        larges.setdefault((int(sous_classe), emplacement), []).append((int(niveau), int(armure)))
    for cle, points in larges.items():
        if cle not in armures and len(points) >= 3:
            armures[cle] = e3.droite(points)
    return armures, armes


def est_arme(source):
    return int(source["class"]) == 2


def composants(source, materiau, nombre):
    """4 lignes au plus (fenêtre Équipement) : Braise, matériau, éclats, pierre taillée."""
    if est_arme(source):
        return [(BRAISE, 3), (materiau, nombre), (ECLAT, 80), (OEIL_TIGRE_TAILLE, 1)]
    return [(BRAISE, 1), (materiau, nombre), (ECLAT, 40), (MALACHITE_TAILLEE, 1)]


def prix(source):
    return 10000 if est_arme(source) else 5000   # 1 po par arme, 50 pa par pièce d'armure


def lignes_dbc():
    """(entrée, entrée copiée, genre) pour l'Item.dbc du patch : la Braise, les pièces, puis leurs rangs."""
    lignes = [(BRAISE, BRAISE_SOURCE, None)] + [(e, src, None) for e, _, src, *_ in PIECES]
    for e, *_ in PIECES:
        lignes += [(e3.entree_rang(e, r), e, None) for r in range(1, e3.RANGS + 1)]
    return lignes


def lua(t):
    return '"' + t.replace("\\", "\\\\").replace('"', '\\"') + '"'


def main():
    armures, armes = baremes()
    sources = e3.objets({src for _, _, src, *_ in PIECES})
    manquants = [src for _, _, src, *_ in PIECES if src not in sources]
    assert not manquants, manquants
    entrees = [e for e, *_ in PIECES]
    tout = ", ".join(map(str, entrees + [BRAISE]))
    rangs = ", ".join(str(e3.entree_rang(e, r)) for e in entrees for r in range(1, e3.RANGS + 1))
    up, down = [], []
    w = up.append
    w("-- v3 (01/11/2026) : Braise du Gouffre (composant de donjon) et pièces bleues du Gouffre de Ragefeu. Généré par")
    w("-- outils\\equipement_gouffre_v3.py : ne pas modifier à la main.")
    w("USE acore_world;")
    w("DELETE FROM item_template WHERE entry IN (%s) OR entry IN (%s);" % (tout, rangs))
    w("DELETE FROM item_template_locale WHERE ID = %d;" % BRAISE)
    w("CREATE TEMPORARY TABLE sol_objet SELECT * FROM item_template WHERE entry = %d;" % BRAISE_SOURCE)
    w("UPDATE sol_objet SET entry = %d, name = 'Braise du Gouffre', Quality = 3, bonding = 1, BuyPrice = 0, "
      "SellPrice = 0, stackable = 1000, description = 'Composant de donjon (Gouffre de Ragefeu) : sert aux pièces "
      "bleues du Gouffre.';" % BRAISE)
    w("INSERT INTO item_template SELECT * FROM sol_objet;")
    w("DROP TEMPORARY TABLE sol_objet;")
    w("INSERT INTO item_template_locale (ID, locale, Name, Description, VerifiedBuild) VALUES (%d, 'frFR', "
      "'Braise du Gouffre', 'Composant de donjon (Gouffre de Ragefeu) : sert aux pièces bleues du Gouffre.', 0);"
      % BRAISE)
    w("INSERT IGNORE INTO solazeroth_v3_collectionnables VALUES (%d);" % BRAISE)
    w("CREATE TABLE IF NOT EXISTS solazeroth_v3_donjons_composants (carte INT UNSIGNED NOT NULL PRIMARY KEY, "
      "composant INT UNSIGNED NOT NULL);")
    w("REPLACE INTO solazeroth_v3_donjons_composants VALUES (%d, %d);" % (GOUFFRE, BRAISE))
    w("CREATE TABLE IF NOT EXISTS acore_characters.solazeroth_v3_donjons_boss (instance INT UNSIGNED NOT NULL, "
      "boss INT UNSIGNED NOT NULL, PRIMARY KEY (instance, boss));")
    w("")
    w("-- Pièces bleues : apparence et type repris d'un objet d'origine, barème des pièces vertes à la puissance %d."
      % PUISSANCE)
    caracs = {}
    for e, nom, src, *_ in PIECES:
        source = sources[src]
        poids = e3.POIDS[int(source["InventoryType"])]
        c = e3.caracteristiques(source, PUISSANCE, armures, armes)
        bloc = int(source["block"])
        caracs[e] = (c, bloc)
        w("CREATE TEMPORARY TABLE sol_objet SELECT * FROM item_template WHERE entry = %d;" % src)
        w("UPDATE sol_objet SET entry = %d, name = %s, description = '', Quality = 3, bonding = 1, ItemLevel = %d, "
          "RequiredLevel = 0, RequiredSkill = 0, RequiredSkillRank = 0, AllowableClass = -1, AllowableRace = -1, "
          "BuyCount = 1, BuyPrice = %d, SellPrice = 0, RandomProperty = 0, RandomSuffix = 0, spellid_1 = 0, "
          "spelltrigger_1 = 0, spellid_2 = 0, spelltrigger_2 = 0, itemset = 0, %s;"
          % (e, s(nom), PUISSANCE, e3.prix(PUISSANCE, poids), e3.colonnes_sql(e3.au_rang(c, 0, bloc))))
        w("INSERT INTO item_template SELECT * FROM sol_objet;")
        w("DROP TEMPORARY TABLE sol_objet;")
    w("")
    w("-- Rangs 1 à 5 : +10 % par rang.")
    for e, nom, *_ in PIECES:
        c, bloc = caracs[e]
        for r in range(1, e3.RANGS + 1):
            w("CREATE TEMPORARY TABLE sol_objet SELECT * FROM item_template WHERE entry = %d;" % e)
            w("UPDATE sol_objet SET entry = %d, name = %s, BuyPrice = 0, %s;"
              % (e3.entree_rang(e, r), s("%s +%d" % (nom, r)), e3.colonnes_sql(e3.au_rang(c, r, bloc))))
            w("INSERT INTO item_template SELECT * FROM sol_objet;")
            w("DROP TEMPORARY TABLE sol_objet;")
    w("DELETE FROM solazeroth_v3_rangs WHERE base IN (%s);" % ", ".join(map(str, entrees)))
    w("INSERT INTO solazeroth_v3_rangs VALUES %s;" % ", ".join(
        "(%d, %d, %d)" % (e3.entree_rang(e, r) if r else e, e, r) for e in entrees for r in range(e3.RANGS + 1)))
    w("")
    w("-- Recettes (puissance requise : celle de la pièce moins 4, comme les vertes).")
    forge = {cle: f for cle, _, f in CATEGORIES}
    w("DELETE FROM solazeroth_v3_recettes WHERE objet IN (%s);" % ", ".join(map(str, entrees)))
    w("DELETE FROM solazeroth_v3_recettes_composants WHERE objet IN (%s);" % ", ".join(map(str, entrees)))
    w("INSERT INTO solazeroth_v3_recettes VALUES %s;" % ", ".join(
        "(%d, %d, %d, %d)" % (e, forge[cat], PUISSANCE - 4, prix(sources[src])) for e, _, src, cat, *_ in PIECES))
    w("INSERT INTO solazeroth_v3_recettes_composants VALUES %s;" % ", ".join(
        "(%d, %d, %d)" % (e, c, n) for e, _, src, _, m, nb in PIECES for c, n in composants(sources[src], m, nb)))
    w("")
    d = down.append
    d("-- Retire la Braise du Gouffre et les pièces bleues. Celles que possèdent les personnages disparaissent.")
    d("USE acore_world;")
    d("DELETE FROM solazeroth_v3_recettes_composants WHERE objet IN (%s);" % ", ".join(map(str, entrees)))
    d("DELETE FROM solazeroth_v3_recettes WHERE objet IN (%s);" % ", ".join(map(str, entrees)))
    d("DELETE FROM solazeroth_v3_rangs WHERE base IN (%s);" % ", ".join(map(str, entrees)))
    d("DELETE FROM item_template WHERE entry IN (%s) OR entry IN (%s);" % (tout, rangs))
    d("DELETE FROM item_template_locale WHERE ID = %d;" % BRAISE)
    d("DELETE FROM solazeroth_v3_collectionnables WHERE entry = %d;" % BRAISE)
    d("DROP TABLE IF EXISTS solazeroth_v3_donjons_composants, acore_characters.solazeroth_v3_donjons_boss;")
    d("")
    for suffixe, lignes in ((".up.sql", up), (".down.sql", down)):
        with open(MIGRATION + suffixe, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(lignes))

    l = ["-- Généré par outils\\equipement_gouffre_v3.py : ne pas modifier à la main.",
         "-- Pièces bleues du Gouffre de Ragefeu, après les recettes vertes (même format que SolUI_Recettes.lua) ;",
         "-- la Braise du Gouffre dans la catégorie Divers de la Collection."]
    for cle, nom, f in CATEGORIES:
        l.append("table.insert(SolUI.RECETTES, { nom = %s, forge = %s, gouffre = true, recettes = {"
                 % (lua(nom), "true" if f else "false"))
        for e, n, src, cat, m, nb in PIECES:
            if cat == cle:
                l.append("    { %d, %s, %d, %d, %d, { %s } }," % (e, lua(n), PUISSANCE, PUISSANCE - 4,
                         prix(sources[src]), ", ".join("{ %d, %d }" % cn for cn in composants(sources[src], m, nb))))
        l.append("} })")
    l += ["for _, c in ipairs(SolUI.CATALOGUE or {}) do",
          "    if c.nom == \"Divers\" then table.insert(c.objets, 1, { %d, \"Braise du Gouffre\", 3 }) end" % BRAISE,
          "end"]
    with open(LUA, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(l) + "\n")
    import quetes_durotar
    quetes_durotar.item_dbc()
    for e, nom, src, *_ in PIECES[:1] + PIECES[24:25] + PIECES[29:30]:
        print(e, nom, caracs[e][0])
    print("%d pièces bleues et la Braise du Gouffre : migration 101 et SolUI_RecettesGouffre.lua écrits." % len(PIECES))


if __name__ == "__main__":
    main()
