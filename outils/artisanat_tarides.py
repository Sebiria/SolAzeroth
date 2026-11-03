"""Lot T8 des Tarides, partie verte (03/11/2026) : artisanat des Tarides (§4.7 du brouillon des Tarides).

- 96 pièces vertes en 3 paliers (pièces 15 à 18, 21 à 24, 27 à 30 ; P = 18, 24, 30, la puissance suit l'emplacement),
  recettes du §4.7.3 lues dans le brouillon (4 composants au plus, or = 10 c × puissance, ouvertes à la puissance moins
  2), rangs 1 à 5, recettes hautes (le torse de chaque palier : une gemme brute ou le plan, fabrication_v3.HAUTES).
  Apparence et type repris d'un vert de Blizzard du même emplacement, au niveau d'objet le plus proche.
- Joaillerie : prospection de l'étain (3 Minerais d'étain, Agate mousse 33 %, Jade 52 %, Pierre de lune inférieure
  15 %) ; 3 pierres taillées ; pierres des rangs 4 et 5 des pièces de puissance 15 ou plus (colonne puissance de
  solazeroth_v3_rangs_pierres : la ligne la plus haute sous la puissance de la pièce sert).
- Enchantements « inférieurs » (enchantement_v3.ENCHANTEMENTS_TARIDES) et tables de désenchantement jusqu'à 35
  (enchantement_v3.TABLES).
- Consommables du palier suivant : Pierre à aiguiser grossière, Renfort d'armure moyen, Huile de sorcier inférieure
  (sorts 101609 à 101611, groupes exclusifs avec ceux de Durotar : on n'en porte qu'un de chaque sorte).
Les pièces bleues des Cavernes (§4.7.4) viennent avec le lot T5.

Écrit la migration 141 et interface-v3\\FrameXML\\SolUI_ArtisanatTarides.lua ; quetes_durotar.item_dbc() ajoute les
pièces, les rangs et les pierres à l'Item.dbc du patch ; auras_nommees.py ajoute les sorts au Spell.dbc du client ;
icones_retail.py convertit les icônes des pierres.

py artisanat_tarides.py
"""
import os
import re
import sys

ICI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ICI)
from quetes_durotar import s, sql
import enchantement_v3 as en
import equipement_v3 as e3
import fabrication_v3

BROUILLON = os.path.join(os.path.expanduser("~"), "Documents", "Claude", "Sol'Azeroth",
                         "Les Tarides — Histoire et quêtes (brouillon).md")
MIGRATION = os.path.join(ICI, "..", "sql", "migrations", "141_v3_tarides_artisanat")
LUA = os.path.join(ICI, "..", "interface-v3", "FrameXML", "SolUI_ArtisanatTarides.lua")
ZONE_MENU = "Les Tarides"              # zone des recettes (SolUI_Zones.lua ; menu par zone puis par palier)

PREMIERE = 910500                      # 910500 à 910595, rangs 925000 à 925955
PALIERS = [18, 24, 30]
ECLAT = 910120

# Joaillerie (§4.7.5, décision 6 du comparatif).
ETAIN, PAR_PROSPECTION = 2771, 3
AGATE, JADE, PIERRE_DE_LUNE = 1206, 1529, 1705
CHANCES = [(JADE, 52), (AGATE, 33), (PIERRE_DE_LUNE, 15)]
AGATE_TAILLEE, JADE_TAILLE, LUNE_TAILLEE = 910183, 910184, 910185
TAILLES = [(AGATE_TAILLEE, "Agate mousse taillée", AGATE, 2), (JADE_TAILLE, "Jade taillé", JADE, 2),
           (LUNE_TAILLEE, "Pierre de lune taillée", PIERRE_DE_LUNE, 2)]
# Icônes : variantes des pierres taillées de Durotar (icones_retail.py, recolorées par icones_pierres_tarides).
ICONES = {AGATE_TAILLEE: "solazeroth_cutgem_agate", JADE_TAILLE: "solazeroth_cutgem_jade",
          LUNE_TAILLEE: "solazeroth_cutgem_lune"}
SEUIL_PIERRES = 15                     # pièces de puissance 15 ou plus : pierres des Tarides
RANGS = {4: [(AGATE_TAILLEE, 2), (JADE_TAILLE, 1)], 5: [(JADE_TAILLE, 2), (LUNE_TAILLEE, 1)]}

# Consommables (§4.7.6) : (objet, nom, sort, prix en cuivre, composants, sort modèle, texte, groupe de Durotar)
SORT_PIERRE, SORT_RENFORT, SORT_HUILE = 101609, 101610, 101611
CONSOMMABLES = [
    (2863, "Pierre à aiguiser grossière", SORT_PIERRE, 10, [(2836, 2)], 2829,
     "Dégâts physiques infligés augmentés de 5 %.", 101606, "physique", 5),
    (2313, "Renfort d'armure moyen", SORT_RENFORT, 20, [(2319, 2), (2318, 1)], 2832,
     "Armure augmentée de 12 %.", 101607, "armure", 12),
    (20746, "Huile de sorcier inférieure", SORT_HUILE, 10, [(2450, 2), (10940, 1)], 25119,
     "Dégâts magiques infligés augmentés de 5 %.", 101608, "magique", 5),
]
GROUPES = {SORT_PIERRE: 1127, SORT_RENFORT: 1128, SORT_HUILE: 1129}   # spell_group (le plus haut était 1126)
EXCLUSIF = 1                                                           # SPELL_GROUP_STACK_RULE_EXCLUSIVE

MATERIAUX = {"cuivre": 2770, "étain": 2771, "argent": 2775, "pierre brute": 2835, "pierre grossière": 2836,
             "cuir léger": 2318, "lanières": 2934, "peau légère": 783, "cuir moyen": 2319, "peau moyenne": 4232,
             "cuir fin de kodo": 5082, "lin": 2589, "laine": 2592, "soie": 4306,
             "Agate mousse taillée": AGATE_TAILLEE, "Jade taillé": JADE_TAILLE, "Pierre de lune taillée": LUNE_TAILLEE}
GEMMES_HAUTES = {"Agate mousse": AGATE, "Jade": JADE, "Pierre de lune inférieure": PIERRE_DE_LUNE}

# Emplacements des armures, dans l'ordre des tableaux : (nom de ligne, InventoryType possibles, écart de puissance).
EMPLACEMENTS = [("Tête", (1,), -1), ("Épaules", (3,), -1), ("Torse", (5, 20), 0), ("Poignets", (9,), -3),
                ("Mains", (10,), -2), ("Taille", (6,), -2), ("Jambes", (7,), -1), ("Pieds", (8,), -2)]
FAMILLES = [("maille", 3, True), ("cuir", 2, False), ("tissu", 1, False)]
# Armes et main gauche : (genre du tableau, classe, sous-classes, InventoryType, forge)
ARMES = {"cape": (4, (1,), (16,), False), "bouclier": (4, (6,), (14,), True), "orbe": (4, (0,), (23,), False),
         "épée": (2, (7,), (13,), True), "hache": (2, (0,), (13,), True), "masse": (2, (4,), (13,), True),
         "dague": (2, (15,), (13,), True), "bâton": (2, (10,), (17,), True)}
# Les deux brassards du palier ont le même nom dans le brouillon : le cuir prend « en cuir » (point du §5.2).
RENOMMER = {("cuir", "Brassards"): "Brassards en cuir"}
CATEGORIES = [("maille", "Les Tarides : maille", True), ("cuir", "Les Tarides : cuir", False),
              ("tissu", "Les Tarides : tissu", False), ("armes", "Les Tarides : armes", True),
              ("mains", "Les Tarides : cape et orbe", False)]


def cuivre(texte):
    m = re.fullmatch(r"(\d+) pa(?: (\d+))?", texte.strip())
    return int(m.group(1)) * 100 + int(m.group(2) or 0)


def composants(texte):
    """« 4 cuivre, 6 étain, 2 pierre brute ; + 1 Agate mousse ou le plan » -> ([(objet, n)], gemme haute ou None)."""
    base, _, haute = texte.partition(";")
    liste = []
    for morceau in base.split(","):
        n, nom = re.fullmatch(r"\s*(\d+) (.+?)\s*", morceau).groups()
        liste.append((MATERIAUX[nom], int(n)))
    gemme = None
    if haute:
        nom = re.fullmatch(r"\s*\+ 1 (.+) ou le plan\s*", haute).group(1)
        gemme = GEMMES_HAUTES[nom]
    assert len(liste) <= 4, texte
    return liste, gemme


def lire():
    """Recettes du §4.7.3 : [(palier, famille, nom, puissance, requise, prix, composants, gemme, (classe, sous-classes,
    InventoryType), forge)], dans l'ordre des entrées."""
    texte = open(BROUILLON, encoding="utf-8").read()
    section = texte[texte.index("#### 4.7.3"):texte.index("#### 4.7.4")]
    recettes = []
    for n, morceau in enumerate(re.split(r"\*\*Palier I+, ", section)[1:]):
        suffixe = re.match(r"« … (.+?) »", morceau).group(1)
        armures, armes = [], []
        for ligne in morceau.splitlines():
            cellules = [c.strip() for c in ligne.strip().strip("|").split("|")]
            if len(cellules) == 6 and cellules[0] in [e[0] for e in EMPLACEMENTS]:
                emplacement = next(e for e in EMPLACEMENTS if e[0] == cellules[0])
                p, requise = map(int, re.fullmatch(r"(\d+) \((\d+)\)", cellules[1]).groups())
                assert p == PALIERS[n] + emplacement[2], ligne
                for (famille, sous, forge), cellule in zip(FAMILLES, cellules[2:5]):
                    nom, _, liste = cellule.partition(" : ")
                    nom = RENOMMER.get((famille, nom), nom)
                    c, gemme = composants(liste)
                    # Torse : une robe pour le tissu si possible, une tunique sinon.
                    types = (20, 5) if emplacement[1] == (5, 20) and sous == 1 else emplacement[1][:1]
                    armures.append((famille, "%s %s" % (nom, suffixe), p, requise, cuivre(cellules[5]), c, gemme,
                                    (4, (sous,), types), forge))
            elif len(cellules) == 5 and re.match(r".+ \((\w+)\)$", cellules[0]):
                nom, genre = re.fullmatch(r"(.+) \((.+)\)", cellules[0]).groups()
                p, requise = map(int, re.fullmatch(r"(\d+) \((\d+)\)", cellules[1]).groups())
                classe, sous, types, forge = ARMES[genre]
                assert forge == (cellules[2] == "oui"), ligne
                c, gemme = composants(cellules[3])
                armes.append(("armes" if forge else "mains", nom, p, requise, cuivre(cellules[4]), c, gemme,
                              (classe, sous, types), forge))
        ordre = {f: i for i, (f, _, _) in enumerate(FAMILLES)}
        armures.sort(key=lambda r: ordre[r[0]])          # maille, cuir, tissu, chacune dans l'ordre des emplacements
        recettes += [(n + 1,) + r for r in armures + armes]
    assert len(recettes) == 96, len(recettes)
    return recettes


def choisir_source(classe, sous_classes, types, niveau):
    """Un vert de Blizzard de ce type, au niveau d'objet le plus proche (le plus petit numéro à égalité)."""
    ligne = sql("SELECT entry FROM acore_world.item_template WHERE entry < 900000 AND Quality = 2 AND class = %d "
                "AND subclass IN (%s) AND InventoryType IN (%s) AND displayid > 0 AND RandomProperty = 0 "
                "AND name NOT LIKE '%%Monster%%' AND name NOT LIKE '%%Test%%' AND name NOT LIKE '%%Deprecated%%' "
                "AND name NOT LIKE '%%OLD%%' AND ItemLevel BETWEEN 5 AND 45 "
                "ORDER BY ABS(CAST(ItemLevel AS SIGNED) - %d), (InventoryType = %d) DESC, entry LIMIT 1"
                % (classe, ",".join(map(str, sous_classes)), ",".join(map(str, types)), niveau, types[0]))
    assert ligne, (classe, sous_classes, types, niveau)
    return int(ligne[0][0])


def pieces():
    """[(entrée, palier, famille, nom, puissance, requise, prix, composants, gemme, source, forge)]."""
    sortie = []
    for i, (palier, famille, nom, p, requise, prix, c, gemme, genre, forge) in enumerate(lire()):
        sortie.append((PREMIERE + i, palier, famille, nom, p, requise, prix, c, gemme, choisir_source(*genre, p), forge))
    return sortie


def caracteristiques_baton(source, p, armes):
    """Comme batons_v3 : dégâts d'une arme à une main, PA et Endurance d'une dague et d'un orbe de même puissance."""
    a, b = armes[False]
    cadence = int(source["delay"]) / 1000
    moyenne = max(1.0, a + b * p) * cadence
    bas, haut = float(source["dmg_min1"]), float(source["dmg_max1"])
    part = bas / (bas + haut) if bas + haut else 0.4
    c = {"armor": 0, "dmg_min1": max(1, round(moyenne * 2 * part))}
    c["dmg_max1"] = max(c["dmg_min1"] + 1, round(moyenne * 2 * (1 - part)))
    c["ap"] = 2 * max(1, round(e3.POIDS[13] * p * e3.AP_PAR_POINT))
    c["endurance"] = 2 * round(e3.POIDS[13] * p * e3.ENDURANCE_PAR_POINT)
    return c


def genre_menu(source):
    return "Armes et boucliers" if int(source["class"]) == 4 and int(source["subclass"]) == 0 else e3.genre(source)


def lignes_dbc():
    """(entrée, entrée copiée, genre) pour l'Item.dbc du patch : pierres taillées, pièces, puis leurs rangs."""
    liste = pieces()
    lignes = [(e, brute, None) for e, _, brute, _ in TAILLES] + [(p[0], p[9], None) for p in liste]
    for p in liste:
        lignes += [(e3.entree_rang(p[0], r), p[0], None) for r in range(1, e3.RANGS + 1)]
    return lignes


def affichages():
    """{pierre: apparence} pour l'Item.dbc du patch (quetes_durotar.item_dbc)."""
    return {e: e for e in ICONES}


def affichages_sources():
    """{apparence: (apparence copiée, icône)} pour l'ItemDisplayInfo.dbc du patch (icones_retail.affichages_objets)."""
    brutes = {int(e): int(a) for e, a in sql("SELECT entry, displayid FROM acore_world.item_template WHERE entry IN (%s)"
                                             % ", ".join(str(b) for _, _, b, _ in TAILLES))}
    return {e: (brutes[b], ICONES[e]) for e, _, b, _ in TAILLES}


def sorts(d):
    """Sorts des consommables (Spell.dbc), comme bonus_v3.lignes."""
    from techniques_v3 import AURA, ARMURE_POURCENT, DEGATS_INFLIGES, SOI, effet, technique
    import bonus_v3 as b
    misc = {"physique": (DEGATS_INFLIGES, b.PHYSIQUE), "armure": (ARMURE_POURCENT, b.ARMURE),
            "magique": (DEGATS_INFLIGES, b.MAGIQUES)}
    noms = {SORT_PIERRE: "Pierre à aiguiser grossière", SORT_RENFORT: "Renfort d'armure moyen",
            SORT_HUILE: "Huile de sorcier inférieure"}
    t = []
    for objet, nom, sort, prix, c, modele, texte, _, genre, valeur in CONSOMMABLES:
        e = technique(d, b.BIEN_NOURRI, sort, noms[sort], texte + " Pendant 1 h.", d.chercher(modele)[133], 0, texte,
                      duree=b.D1H)
        e[213] = 0
        aura, m = misc[genre]
        effet(e, 0, AURA, valeur, SOI, aura=aura, misc=m)
        t.append(e)
    return t


def lua(t):
    return '"' + t.replace("\\", "\\\\").replace('"', '\\"') + '"'


def main():
    import auras_nommees
    import dbc
    from hauts_faits_natifs import DBC_SERVEUR
    gabarits = __import__("equipement_gouffre_v3").baremes()
    armures, armes = gabarits
    liste = pieces()
    sources = e3.objets({p[9] for p in liste})
    entrees = [p[0] for p in liste]
    rangs = [e3.entree_rang(e, r) for e in entrees for r in range(1, e3.RANGS + 1)]
    tout = ", ".join(map(str, entrees))
    pierres = ", ".join(str(e) for e, *_ in TAILLES)
    up, down = [], []
    w = up.append
    w("-- Lot T8 des Tarides, partie verte (03/11/2026) : artisanat des Tarides. Généré par outils\\artisanat_tarides.py :")
    w("-- ne pas modifier à la main. Ne touche à rien de Durotar (les consommables de Durotar restent, à côté).")
    w("USE acore_world;")
    w("DELETE FROM item_template WHERE entry IN (%s) OR entry BETWEEN %d AND %d OR entry IN (%s);"
      % (tout, rangs[0], rangs[-1], pierres))
    w("DELETE FROM item_template_locale WHERE ID IN (%s);" % pierres)
    w("")
    w("-- Pierres taillées des Tarides (Collection, catégorie Gemmes).")
    for e, nom, brute, _ in TAILLES:
        w("CREATE TEMPORARY TABLE sol_objet SELECT * FROM item_template WHERE entry = %d;" % brute)
        w("UPDATE sol_objet SET entry = %d, name = %s, displayid = %d, Quality = 3, BuyPrice = 0, SellPrice = 0, "
          "description = 'Pierre taillée : améliore les rangs 4 et 5 des pièces de puissance 15 ou plus.';"
          % (e, s(nom), e))
        w("INSERT INTO item_template SELECT * FROM sol_objet;")
        w("DROP TEMPORARY TABLE sol_objet;")
        w("INSERT INTO item_template_locale (ID, locale, Name, Description, VerifiedBuild) VALUES (%d, 'frFR', %s, "
          "'Pierre taillée : améliore les rangs 4 et 5 des pièces de puissance 15 ou plus.', 0);" % (e, s(nom)))
    w("INSERT IGNORE INTO solazeroth_v3_collectionnables VALUES %s;" % ", ".join("(%d)" % e for e, *_ in TAILLES))
    w("")
    w("-- Pièces vertes : apparence et type d'un vert de Blizzard, barème commun (equipement_v3), rangs 1 à 5.")
    caracs = {}
    for e, palier, famille, nom, p, requise, prix, c, gemme, src, forge in liste:
        source = sources[src]
        poids = e3.POIDS[int(source["InventoryType"])]
        if int(source["InventoryType"]) == 17:
            ca = caracteristiques_baton(source, p, armes)
        else:
            ca = e3.caracteristiques(source, p, armures, armes)
        bloc = int(source["block"])
        caracs[e] = (ca, bloc)
        table = en.table_de(int(source["class"]), p)
        w("CREATE TEMPORARY TABLE sol_objet SELECT * FROM item_template WHERE entry = %d;" % src)
        w("UPDATE sol_objet SET entry = %d, name = %s, description = '', Quality = 2, bonding = 1, ItemLevel = %d, "
          "RequiredLevel = 0, RequiredSkill = 0, RequiredSkillRank = 0, AllowableClass = -1, AllowableRace = -1, "
          "BuyCount = 1, BuyPrice = %d, SellPrice = 0, RandomProperty = 0, RandomSuffix = 0, spellid_1 = 0, "
          "spelltrigger_1 = 0, spellid_2 = 0, spelltrigger_2 = 0, itemset = 0, DisenchantID = %d, "
          "RequiredDisenchantSkill = 1, %s;"
          % (e, s(nom), p, e3.prix(p, poids), table, e3.colonnes_sql(e3.au_rang(ca, 0, bloc))))
        w("INSERT INTO item_template SELECT * FROM sol_objet;")
        w("DROP TEMPORARY TABLE sol_objet;")
    for e, palier, famille, nom, *_ in liste:
        ca, bloc = caracs[e]
        for r in range(1, e3.RANGS + 1):
            w("CREATE TEMPORARY TABLE sol_objet SELECT * FROM item_template WHERE entry = %d;" % e)
            w("UPDATE sol_objet SET entry = %d, name = %s, BuyPrice = 0, %s;"
              % (e3.entree_rang(e, r), s("%s +%d" % (nom, r)), e3.colonnes_sql(e3.au_rang(ca, r, bloc))))
            w("INSERT INTO item_template SELECT * FROM sol_objet;")
            w("DROP TEMPORARY TABLE sol_objet;")
    w("DELETE FROM solazeroth_v3_rangs WHERE base IN (%s);" % tout)
    w("INSERT INTO solazeroth_v3_rangs VALUES %s;" % ", ".join(
        "(%d, %d, %d)" % (e3.entree_rang(e, r) if r else e, e, r) for e in entrees for r in range(e3.RANGS + 1)))
    w("")
    w("-- Recettes (puissance de la pièce moins 2), composants, et recettes hautes (le torse de chaque palier).")
    w("DELETE FROM solazeroth_v3_recettes WHERE objet IN (%s);" % tout)
    w("DELETE FROM solazeroth_v3_recettes_composants WHERE objet IN (%s);" % tout)
    w("DELETE FROM solazeroth_v3_recettes_hautes WHERE objet IN (%s);" % tout)
    w("INSERT INTO solazeroth_v3_recettes VALUES %s;" % ", ".join(
        "(%d, %d, %d, %d)" % (e, forge, requise, prix) for e, _, _, _, _, requise, prix, _, _, _, forge in liste))
    w("INSERT INTO solazeroth_v3_recettes_composants VALUES %s;" % ", ".join(
        "(%d, %d, %d)" % (e, o, n) for e, *_, c, gemme, src, forge in liste for o, n in c))
    hautes = []
    for e, palier, famille, nom, p, requise, prix, c, gemme, src, forge in liste:
        if gemme:
            composant, nombre, plan = fabrication_v3.HAUTES[p]
            assert composant == gemme, (nom, composant, gemme)
            hautes.append("(%d, %d, %d, %d)" % (e, composant, nombre, plan))
    assert len(hautes) == 9, hautes
    w("INSERT INTO solazeroth_v3_recettes_hautes VALUES %s;" % ", ".join(hautes))
    w("")
    w("-- Joaillerie : prospection de l'étain, tailles, pierres des rangs 4 et 5 selon la puissance de la pièce.")
    w("DELETE FROM solazeroth_v3_prospection WHERE minerai = %d;" % ETAIN)
    w("INSERT INTO solazeroth_v3_prospection VALUES %s;" % ", ".join(
        "(%d, %d, %d, %d)" % (ETAIN, PAR_PROSPECTION, g, c) for g, c in CHANCES))
    w("DELETE FROM solazeroth_v3_tailles WHERE pierre IN (%s);" % pierres)
    w("INSERT INTO solazeroth_v3_tailles VALUES %s;" % ", ".join("(%d, %d, %d)" % (e, b, n) for e, _, b, n in TAILLES))
    # La migration 085 (joaillerie_v3.py) crée maintenant la colonne ; on ne l'ajoute que si elle manque.
    w("SET @manque = (SELECT COUNT(*) = 0 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = 'acore_world' "
      "AND TABLE_NAME = 'solazeroth_v3_rangs_pierres' AND COLUMN_NAME = 'puissance');")
    w("SET @requete = IF(@manque, 'ALTER TABLE solazeroth_v3_rangs_pierres ADD COLUMN puissance TINYINT UNSIGNED NOT "
      "NULL DEFAULT 0 FIRST, DROP PRIMARY KEY, ADD PRIMARY KEY (puissance, rang, pierre)', 'DO 0');")
    w("PREPARE requete FROM @requete;")
    w("EXECUTE requete;")
    w("DEALLOCATE PREPARE requete;")
    w("DELETE FROM solazeroth_v3_rangs_pierres WHERE puissance = %d;" % SEUIL_PIERRES)
    w("INSERT INTO solazeroth_v3_rangs_pierres (puissance, rang, pierre, nombre) VALUES %s;" % ", ".join(
        "(%d, %d, %d, %d)" % (SEUIL_PIERRES, r, p, n) for r, l in RANGS.items() for p, n in l))
    w("")
    w("-- Enchantements « inférieurs » (10 c par composant).")
    ids = ", ".join(str(i) for i, *_ in en.ENCHANTEMENTS_TARIDES)
    w("DELETE FROM solazeroth_v3_enchantements WHERE id IN (%s);" % ids)
    w("DELETE FROM solazeroth_v3_enchantements_types WHERE id IN (%s);" % ids)
    w("DELETE FROM solazeroth_v3_enchantements_composants WHERE id IN (%s);" % ids)
    w("INSERT INTO solazeroth_v3_enchantements VALUES %s;" % ", ".join(
        "(%d, %d, %d)" % (i, e, en.OR_PAR_COMPOSANT * sum(c.values())) for i, _, _, e, _, c in en.ENCHANTEMENTS_TARIDES))
    w("INSERT INTO solazeroth_v3_enchantements_types VALUES %s;" % ", ".join(
        "(%d, %d)" % (i, t) for i, _, _, _, types, _ in en.ENCHANTEMENTS_TARIDES for t in types))
    w("INSERT INTO solazeroth_v3_enchantements_composants VALUES %s;" % ", ".join(
        "(%d, %d, %d)" % (i, o, n) for i, _, _, _, _, c in en.ENCHANTEMENTS_TARIDES for o, n in c.items()))
    w("")
    w("-- Consommables du palier suivant : notre sort (1 h), recette ; un seul de chaque sorte (groupe exclusif avec")
    w("-- celui de Durotar). Les objets et les ventes d'origine sont gardés dans des tables de retour.")
    objets = ", ".join(str(o[0]) for o in CONSOMMABLES)
    sorts_ids = ", ".join(str(o[2]) for o in CONSOMMABLES)
    w("CREATE TABLE IF NOT EXISTS solazeroth_v3_t8_objets_origine SELECT entry, spellid_1, spelltrigger_1, "
      "spellcharges_1, spellcooldown_1, spellcategory_1, spellcategorycooldown_1, RequiredLevel, RequiredSkill, "
      "RequiredSkillRank FROM item_template WHERE entry IN (%s);" % objets)
    w("CREATE TABLE IF NOT EXISTS solazeroth_v3_t8_ventes_origine SELECT * FROM npc_vendor WHERE item IN (%s);" % objets)
    w("DELETE FROM npc_vendor WHERE item IN (%s);" % objets)
    w("DELETE FROM spell_dbc WHERE ID IN (%s);" % sorts_ids)
    d = dbc.Dbc.ouvrir(os.path.join(DBC_SERVEUR, "Spell.dbc"))
    types = auras_nommees.types_colonnes()
    for e in sorts(d):
        w("INSERT INTO spell_dbc VALUES (%s);" % ", ".join(auras_nommees.valeur_sql(d, t, v) for t, v in zip(types, e)))
    for objet, nom, sort, prix, c, *_ in CONSOMMABLES:
        w("UPDATE item_template SET spellid_1 = %d, spelltrigger_1 = 0, spellcharges_1 = -1, spellcooldown_1 = -1, "
          "spellcategory_1 = 0, spellcategorycooldown_1 = -1, RequiredLevel = 0, RequiredSkill = 0, "
          "RequiredSkillRank = 0 WHERE entry = %d;" % (sort, objet))
        w("DELETE FROM solazeroth_v3_recettes WHERE objet = %d;" % objet)
        w("DELETE FROM solazeroth_v3_recettes_composants WHERE objet = %d;" % objet)
        w("INSERT INTO solazeroth_v3_recettes (objet, forge, puissance, prix) VALUES (%d, 0, 0, %d);" % (objet, prix))
        w("INSERT INTO solazeroth_v3_recettes_composants (objet, composant, nombre) VALUES %s;"
          % ", ".join("(%d, %d, %d)" % (objet, o, n) for o, n in c))
    groupes = ", ".join(str(g) for g in GROUPES.values())
    w("DELETE FROM spell_group WHERE id IN (%s);" % groupes)
    w("DELETE FROM spell_group_stack_rules WHERE group_id IN (%s);" % groupes)
    w("INSERT INTO spell_group (id, spell_id) VALUES %s;" % ", ".join(
        "(%d, %d), (%d, %d)" % (GROUPES[sort], durotar, GROUPES[sort], sort) for _, _, sort, _, _, _, _, durotar, *_
        in CONSOMMABLES))
    w("INSERT INTO spell_group_stack_rules (group_id, stack_rule, description) VALUES %s;" % ", ".join(
        "(%d, %d, %s)" % (GROUPES[sort], EXCLUSIF, s("Sol'Azeroth : " + nom)) for _, nom, sort, *_ in CONSOMMABLES))
    w("")

    x = down.append
    x("-- Retire l'artisanat des Tarides. Les pièces et pierres que possèdent les personnages disparaissent ; les")
    x("-- consommables reprennent leur sort et leurs ventes d'origine.")
    x("USE acore_world;")
    x("DELETE FROM spell_group WHERE id IN (%s);" % groupes)
    x("DELETE FROM spell_group_stack_rules WHERE group_id IN (%s);" % groupes)
    x("DELETE FROM spell_dbc WHERE ID IN (%s);" % sorts_ids)
    x("UPDATE item_template i JOIN solazeroth_v3_t8_objets_origine o ON o.entry = i.entry SET i.spellid_1 = o.spellid_1, "
      "i.spelltrigger_1 = o.spelltrigger_1, i.spellcharges_1 = o.spellcharges_1, i.spellcooldown_1 = o.spellcooldown_1, "
      "i.spellcategory_1 = o.spellcategory_1, i.spellcategorycooldown_1 = o.spellcategorycooldown_1, "
      "i.RequiredLevel = o.RequiredLevel, i.RequiredSkill = o.RequiredSkill, i.RequiredSkillRank = o.RequiredSkillRank;")
    x("INSERT IGNORE INTO npc_vendor SELECT * FROM solazeroth_v3_t8_ventes_origine;")
    x("DROP TABLE IF EXISTS solazeroth_v3_t8_objets_origine, solazeroth_v3_t8_ventes_origine;")
    x("DELETE FROM solazeroth_v3_recettes WHERE objet IN (%s) OR objet IN (%s);" % (tout, objets))
    x("DELETE FROM solazeroth_v3_recettes_composants WHERE objet IN (%s) OR objet IN (%s);" % (tout, objets))
    x("DELETE FROM solazeroth_v3_recettes_hautes WHERE objet IN (%s);" % tout)
    x("DELETE FROM solazeroth_v3_rangs WHERE base IN (%s);" % tout)
    x("DELETE FROM solazeroth_v3_enchantements WHERE id IN (%s);" % ids)
    x("DELETE FROM solazeroth_v3_enchantements_types WHERE id IN (%s);" % ids)
    x("DELETE FROM solazeroth_v3_enchantements_composants WHERE id IN (%s);" % ids)
    x("DELETE FROM solazeroth_v3_prospection WHERE minerai = %d;" % ETAIN)
    x("DELETE FROM solazeroth_v3_tailles WHERE pierre IN (%s);" % pierres)
    x("DELETE FROM solazeroth_v3_rangs_pierres WHERE puissance = %d;" % SEUIL_PIERRES)
    x("DELETE FROM solazeroth_v3_collectionnables WHERE entry IN (%s);" % pierres)
    x("DELETE FROM item_template WHERE entry IN (%s) OR entry BETWEEN %d AND %d OR entry IN (%s);"
      % (tout, rangs[0], rangs[-1], pierres))
    x("DELETE FROM item_template_locale WHERE ID IN (%s);" % pierres)
    x("")
    for suffixe, lignes in ((".up.sql", up), (".down.sql", down)):
        with open(MIGRATION + suffixe, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(lignes))

    l = ["-- Généré par outils\\artisanat_tarides.py : ne pas modifier à la main.",
         "-- Lot T8 des Tarides : recettes vertes (zone « %s » du menu de fabrication), joaillerie, pierres des" % ZONE_MENU,
         "-- rangs 4 et 5 selon la puissance de la pièce, enchantements inférieurs et consommables du palier suivant."]
    for cle, nom, forge in CATEGORIES:
        l.append("table.insert(SolUI.RECETTES, { nom = %s, zone = %s, forge = %s, recettes = {"
                 % (lua(nom), lua(ZONE_MENU), "true" if forge else "false"))
        for e, palier, famille, n, p, requise, prix, c, gemme, src, _ in liste:
            if famille == cle:
                l.append("    { %d, %s, %d, %d, %d, { %s }, %s }," % (e, lua(n), p, requise, prix,
                         ", ".join("{ %d, %d }" % oc for oc in c), lua(genre_menu(sources[src]))))
        l.append("} })")
    l.append('table.insert(SolUI.RECETTES, { nom = "Consommables", zone = %s, surplus = true, recettes = {'
             % lua(ZONE_MENU))
    for objet, nom, sort, prix, c, *_ in CONSOMMABLES:
        l.append('    { %d, %s, 0, 0, %d, { %s }, "Consommables" },'
                 % (objet, lua(nom), prix, ", ".join("{ %d, %d }" % oc for oc in c)))
    l.append("} })")
    l.append("-- Joaillerie : une prospection de plus, les tailles, et les pierres des rangs à partir de la puissance %d."
             % SEUIL_PIERRES)
    l.append("local J = SolUI.JOAILLERIE")
    l.append("J.prospections = J.prospections or { { minerai = J.minerai, parProspection = J.parProspection, "
             "chances = J.chances } }")
    l.append("table.insert(J.prospections, { zone = %s, minerai = %d, parProspection = %d, chances = { %s } })"
             % (lua(ZONE_MENU), ETAIN, PAR_PROSPECTION, ", ".join("{ %d, %d }" % gc for gc in CHANCES)))
    for e, nom, b, n in TAILLES:
        l.append("table.insert(J.tailles, { %d, %s, %d, %d })" % (e, lua(nom), b, n))
    l.append("J.paliers = J.paliers or {}")
    l.append("table.insert(J.paliers, { puissance = %d, rangs = { %s } })" % (SEUIL_PIERRES, ", ".join(
        "[%d] = { %s }" % (r, ", ".join("{ %d, %d }" % pn for pn in liste_)) for r, liste_ in RANGS.items())))
    l.append("for _, c in ipairs(SolUI.CATALOGUE or {}) do")
    l.append('    if c.nom == "Gemmes" then')
    l += ["        table.insert(c.objets, { %d, %s, 3 })" % (e, lua(nom)) for e, nom, _, _ in TAILLES]
    l.append("    end")
    l.append("end")
    l.append("-- Enchantements inférieurs (même format que SolUI_Enchantements.lua) et butin des tables de désenchantement.")
    for i, nom, effet, e, types, c in en.ENCHANTEMENTS_TARIDES:
        l.append("table.insert(SolUI.ENCHANTEMENTS, { %d, %s, %s, %d, { %s }, { %s }, %d, %s })" % (
            i, lua(nom), lua(effet), e, ", ".join(map(str, types)),
            ", ".join("{ %d, %d }" % (o, n) for o, n in c.items()), en.OR_PAR_COMPOSANT * sum(c.values()),
            lua(ZONE_MENU)))
    tables = sorted({t for _, a, b in en.TABLES for t in (a, b)})
    for t, texte in en.descriptions(tables).items():
        l.append("SolUI.DESENCHANTEMENT[%d] = SolUI.DESENCHANTEMENT[%d] or %s" % (t, t, lua(texte)))
    with open(LUA, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(l) + "\n")

    import icones_retail
    import quetes_durotar
    icones_retail.ecrire_affichages()
    quetes_durotar.item_dbc()
    for e, palier, famille, nom, p, *_, src, _ in liste[:1] + liste[24:32]:
        print(e, nom, "P%d" % p, "source", src, sources[src]["name"], caracs[e][0])
    print("%d pièces vertes, %d pierres taillées, %d enchantements, %d consommables : migration 141 et "
          "SolUI_ArtisanatTarides.lua écrits." % (len(liste), len(TAILLES), len(en.ENCHANTEMENTS_TARIDES),
                                                  len(CONSOMMABLES)))


if __name__ == "__main__":
    main()
