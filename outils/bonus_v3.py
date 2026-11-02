"""Audit du jeu, lot 4c (02/11/2026, C6 du consensus ; choix de l'utilisateur) : panoplie du Gouffre, variantes par
emplacement et débouchés du surplus. Chiffres : outils\\simulation_lot4c.py.
- Panoplie du Gouffre (pièces bleues à Braise, rangs compris ; jamais les vertes de quête) : 2 pièces + 3 % de dégâts,
  4 pièces − 5 % de dégâts subis, 6 pièces 3 % de vol de vie (v3_equipement.cpp).
- Variantes, choisies à la fabrication des pièces : Critique + 1 %, Hâte + 2 %, Vol de vie 0,5 %, par pièce portée
  (une aura à cumuls par variante, un cumul par pièce).
- Surplus : Pierre à aiguiser brute (2 Pierres brutes) + 3 % de dégâts physiques, Renfort d'armure léger (2 Cuirs
  légers, 2 Lanières) + 8 % d'armure, pendant 1 h ; fabriqués dans la fenêtre Équipement (catégorie Consommables). On
  ne les achète plus chez les marchands.

Appelé par auras_nommees.py (Spell.dbc du client) ; écrit la migration 117 et SolUI_RecettesSurplus.lua. Les effets
propres des plats sont dans cuisine_v3.py (BONUS) ; la migration 117 réécrit leurs auras.
"""
from techniques_v3 import AURA, AURA_FACTICE, ARMURE_POURCENT, DEGATS_INFLIGES, DEGATS_SUBIS, INFINIE, SOI, effet, technique

MIGRATION = r"C:\SolAzeroth\sql\migrations\117_v3_bonus"
LUA = r"C:\SolAzeroth\interface-v3\FrameXML\SolUI_RecettesSurplus.lua"
PANOPLIE_2, PANOPLIE_4, PANOPLIE_6, CRITIQUE, HATE, VOL, PIERRE, RENFORT = range(101600, 101608)
CRIT_POURCENT, HATE_MELEE_DISTANCE, VITESSE_INCANTATION = 290, 192, 65
D1H = 42
TOUTES, PHYSIQUE, ARMURE = 127, 1, 1
SANS_ANNULATION, PASSIF, APRES_LA_MORT = 0x80000000, 0x40, 0x00100000
BIEN_NOURRI, SORT_PIERRE, SORT_RENFORT = 19705, 2828, 2831
PIECES_MAX = 8
# Consommables : (objet, nom, sort, prix en cuivre, composants)
CONSOMMABLES = [(2862, "Pierre à aiguiser brute", PIERRE, 5, [(2835, 2)]),
                (2304, "Renfort d'armure léger", RENFORT, 10, [(2318, 2), (2934, 2)])]


def permanente(d, ident, nom, texte, icone, cumuls=0):
    e = technique(d, BIEN_NOURRI, ident, nom, "", icone, 0, texte, duree=INFINIE)
    e[4], e[5:12] = PASSIF | SANS_ANNULATION, [0] * 7
    e[7] = APRES_LA_MORT
    e[49] = cumuls
    e[213] = 0
    return e


def lignes(d):
    icone = d.chercher(BIEN_NOURRI)[133]
    t = []
    e = permanente(d, PANOPLIE_2, "Panoplie du Gouffre (2)", "Dégâts infligés augmentés de 3 %.", icone)
    effet(e, 0, AURA, 3, SOI, aura=DEGATS_INFLIGES, misc=TOUTES)
    t.append(e)
    e = permanente(d, PANOPLIE_4, "Panoplie du Gouffre (4)", "Dégâts subis réduits de 5 %.", icone)
    effet(e, 0, AURA, -5, SOI, aura=DEGATS_SUBIS, misc=TOUTES)
    t.append(e)
    e = permanente(d, PANOPLIE_6, "Panoplie du Gouffre (6)", "3 % des dégâts infligés rendus en vie.", icone)
    effet(e, 0, AURA, 0, SOI, aura=AURA_FACTICE)
    t.append(e)
    e = permanente(d, CRITIQUE, "Variante : Critique", "Chances de coup critique augmentées de 1 % par pièce.", icone,
                   PIECES_MAX)
    effet(e, 0, AURA, 1, SOI, aura=CRIT_POURCENT)
    t.append(e)
    e = permanente(d, HATE, "Variante : Hâte", "Vitesse d'attaque et d'incantation augmentée de 2 % par pièce.", icone,
                   PIECES_MAX)
    effet(e, 0, AURA, 2, SOI, aura=HATE_MELEE_DISTANCE)
    effet(e, 1, AURA, 2, SOI, aura=VITESSE_INCANTATION)
    t.append(e)
    e = permanente(d, VOL, "Variante : Vol de vie", "0,5 % des dégâts infligés rendus en vie par pièce.", icone, PIECES_MAX)
    effet(e, 0, AURA, 0, SOI, aura=AURA_FACTICE)
    t.append(e)
    for ident, nom, texte, modele, aura, misc, valeur in (
            (PIERRE, "Pierre à aiguiser", "Dégâts physiques infligés augmentés de 3 %.", SORT_PIERRE, DEGATS_INFLIGES,
             PHYSIQUE, 3),
            (RENFORT, "Renfort d'armure", "Armure augmentée de 8 %.", SORT_RENFORT, ARMURE_POURCENT, ARMURE, 8)):
        e = technique(d, BIEN_NOURRI, ident, nom, texte + " Pendant 1 h.", d.chercher(modele)[133], 0, texte, duree=D1H)
        e[213] = 0
        effet(e, 0, AURA, valeur, SOI, aura=aura, misc=misc)
        t.append(e)
    return t


def ecrire(sorts_sql, plats_sql, plats_ids):
    ids = ", ".join(str(i) for i in range(PANOPLIE_2, RENFORT + 1))
    up = ["-- Audit du jeu, lot 4c (02/11/2026) : panoplie du Gouffre, variantes, consommables du surplus et effets propres",
          "-- des plats. Généré par outils\\auras_nommees.py (bonus_v3.py, cuisine_v3.py) : ne pas modifier à la main.",
          "USE acore_world;",
          "DELETE FROM spell_dbc WHERE ID IN (%s);" % ids,
          "DELETE FROM spell_dbc WHERE ID IN (%s);" % ", ".join(str(i) for i in plats_ids)]
    up += sorts_sql + plats_sql
    down = ["USE acore_world;", up[3]]
    for objet, nom, sort, prix, composants in CONSOMMABLES:
        up += ["UPDATE item_template SET spellid_1 = %d, spelltrigger_1 = 0, spellcharges_1 = -1, spellcooldown_1 = -1, "
               "spellcategory_1 = 0, spellcategorycooldown_1 = -1, RequiredLevel = 0, RequiredSkill = 0, "
               "RequiredSkillRank = 0 WHERE entry = %d;" % (sort, objet),
               "DELETE FROM npc_vendor WHERE item = %d;" % objet,
               "DELETE FROM solazeroth_v3_recettes WHERE objet = %d;" % objet,
               "DELETE FROM solazeroth_v3_recettes_composants WHERE objet = %d;" % objet,
               "INSERT INTO solazeroth_v3_recettes (objet, forge, puissance, prix) VALUES (%d, 0, 0, %d);" % (objet, prix)]
        up += ["INSERT INTO solazeroth_v3_recettes_composants (objet, composant, nombre) VALUES (%d, %d, %d);"
               % (objet, c, n) for c, n in composants]
        down += ["DELETE FROM solazeroth_v3_recettes WHERE objet = %d;" % objet,
                 "DELETE FROM solazeroth_v3_recettes_composants WHERE objet = %d;" % objet]
    up += ["USE acore_characters;",
           "CREATE TABLE IF NOT EXISTS solazeroth_v3_variantes (item INT UNSIGNED NOT NULL PRIMARY KEY, variante TINYINT "
           "UNSIGNED NOT NULL) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;", ""]
    down += ["-- Sorts et objets d'origine : rejouer les migrations 050 et 079.", "USE acore_characters;",
             "DROP TABLE IF EXISTS solazeroth_v3_variantes;", ""]
    for suffixe, contenu in ((".up.sql", up), (".down.sql", down)):
        with open(MIGRATION + suffixe, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(contenu))
    lua = ["-- Généré par outils\\bonus_v3.py : ne pas modifier à la main.",
           "-- Audit du jeu, lot 4c : consommables du surplus, après les recettes du Gouffre (même format que SolUI_Recettes.lua).",
           'table.insert(SolUI.RECETTES, { nom = "Consommables", surplus = true, recettes = {']
    for objet, nom, sort, prix, composants in CONSOMMABLES:
        lua.append('    { %d, "%s", 0, 0, %d, { %s }, "Consommables" },'
                   % (objet, nom, prix, ", ".join("{ %d, %d }" % c for c in composants)))
    lua += ["} })", ""]
    with open(LUA, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lua))
