"""Sol'Azeroth v3 (31/10/2026) : cuisine par zone (demande de l'utilisateur).

Chaque zone a ses plats : les recettes de cuisine de Blizzard dont un ingrédient au moins tombe sur les monstres de la
zone (viande, poisson, dard…) et dont les autres s'y trouvent aussi (butin ou marchand de la zone). Les plats de fête
sont écartés. Une recette déjà prise par une zone précédente de ZONES n'est pas reprise.

Un plat donne pendant 30 minutes la caractéristique de la spécialisation (Force, Agilité ou Intelligence), d'autant de
points que la puissance moyenne de la zone : moyenne des niveaux d'origine de ses monstres ordinaires, entre le 5e et
le 90e centile (les mêmes bornes que la puissance conseillée de v3_niveau.cpp). Un seul repas à la fois.

- Sorts : un sort par plat (effet factice, v3_cuisine.cpp choisit la caractéristique), et trois auras « Bien nourri »
  par plat (Force, Agilité, Intelligence), pour que l'infobulle donne le bon chiffre.
- Fabrication : fenêtre Équipement, catégorie Cuisine, près d'un feu (le Feu de camp v3 compte), en 5 s.
- Le plat de Blizzard garde son nom et son icône ; son sort de nourriture (assis, vie rendue, banni en v3) est remplacé.

Appelé par auras_nommees.py, qui écrit le Spell.dbc du client, la migration 079 et SolUI_Cuisine.lua.
"""
import os

import dbc
from collection_v3 import requete
from hauts_faits_natifs import DBC_SERVEUR
from techniques_v3 import AURA, SOI, effet, technique

MIGRATION = r"C:\SolAzeroth\sql\migrations\079_v3_cuisine"
LUA = r"C:\SolAzeroth\interface-v3\FrameXML\SolUI_Cuisine.lua"

ZONES = [(14, "Durotar")]           # dans l'ordre du jeu
CUISINE = 185                       # SkillLine.dbc
CREER_OBJET, FACTICE, CARACTERISTIQUE = 24, 3, 29
CARACTERISTIQUES = [(0, "Force"), (1, "Agilité"), (3, "Intelligence")]   # misc de l'aura, comme UnitMods
BIEN_NOURRI = 19705                 # sort de Blizzard copié (icône du repas)
D30MIN = 30                         # SpellDuration.dbc : 1800 s
PREMIER_PLAT, PREMIER_BUFF = 101000, 101500
SCRIPT = "spell_solazeroth_v3_plat"


def puissance_moyenne(zone):
    niveaux = sorted(int(n) for (n,) in requete(
        "SELECT t.minlevel FROM creature c JOIN creature_template t ON t.entry = c.id "
        "WHERE c.zoneId = %d AND t.npcflag = 0 AND t.`rank` = 0 AND t.type <> 8" % zone))
    bas = niveaux[int(0.05 * (len(niveaux) - 1))]
    haut = niveaux[int(0.90 * (len(niveaux) - 1))]
    retenus = [n for n in niveaux if bas <= n <= haut]
    return round(sum(retenus) / len(retenus))


def recettes_de_blizzard():
    """[(sort, plat, [(ingrédient, nombre)])] des recettes de cuisine qui créent un objet."""
    sorts = {e[2] for e in dbc.Dbc.ouvrir(os.path.join(DBC_SERVEUR, "SkillLineAbility.dbc")).enregistrements
             if e[1] == CUISINE}
    sortie = []
    for e in dbc.Dbc.ouvrir(os.path.join(DBC_SERVEUR, "Spell.dbc")).enregistrements:
        if e[0] not in sorts:
            continue
        plats = [e[107 + i] for i in range(3) if e[71 + i] == CREER_OBJET and e[107 + i]]
        if plats:
            sortie.append((e[0], plats[0], [(e[52 + i], e[60 + i]) for i in range(8) if e[52 + i]]))
    return sorted(sortie)


def plats():
    """Plats de chaque zone de ZONES, dans l'ordre : dictionnaires (objet, nom, composants, zone, puissance, sort,
    buffs)."""
    recettes = recettes_de_blizzard()
    fetes = {int(e) for (e,) in requete("SELECT entry FROM item_template WHERE HolidayId <> 0")}
    noms = {int(e): n for e, n in requete(
        "SELECT i.entry, COALESCE(NULLIF(l.Name, ''), i.name) FROM item_template i "
        "LEFT JOIN item_template_locale l ON l.ID = i.entry AND l.locale = 'frFR' WHERE i.class IN (0, 7)")}
    sortie, pris = [], set()
    for zone, nom_zone in ZONES:
        butin = {int(e) for (e,) in requete(
            "SELECT DISTINCT l.Item FROM creature c JOIN creature_template t ON t.entry = c.id "
            "JOIN creature_loot_template l ON l.Entry = t.lootid WHERE c.zoneId = %d AND l.Reference = 0 "
            "AND l.QuestRequired = 0" % zone)}
        vente = {int(e) for (e,) in requete(
            "SELECT DISTINCT v.item FROM creature c JOIN npc_vendor v ON v.entry = c.id WHERE c.zoneId = %d" % zone)}
        puissance = puissance_moyenne(zone)
        for sort, plat, composants in recettes:
            objets = [o for o, _ in composants]
            if plat in pris or plat in fetes or not any(o in butin for o in objets) \
                    or not all(o in butin or o in vente for o in objets):
                continue
            pris.add(plat)
            n = len(sortie)
            sortie.append({"objet": plat, "nom": noms.get(plat, str(plat)), "composants": composants, "zone": zone,
                           "nom_zone": nom_zone, "puissance": puissance, "sort": PREMIER_PLAT + n,
                           "buffs": [PREMIER_BUFF + 3 * n + k for k in range(3)]})
    return sortie


def lignes(d, liste):
    """Sorts du Spell.dbc : celui de chaque plat, puis ses trois auras."""
    icone = d.chercher(BIEN_NOURRI)[133]
    t = []
    for p in liste:
        e = technique(d, BIEN_NOURRI, p["sort"], p["nom"],
                      "Augmente de %d la Force, l'Agilité ou l'Intelligence, selon ta spécialisation, pendant 30 min "
                      "(repas de %s). Un seul repas à la fois." % (p["puissance"], p["nom_zone"]), icone, 0)
        e[213] = 0
        effet(e, 0, FACTICE, 0, SOI)
        t.append(e)
        for buff, (misc, carac) in zip(p["buffs"], CARACTERISTIQUES):
            e = technique(d, BIEN_NOURRI, buff, "Bien nourri", "", icone, 0,
                          "%s augmentée de %d." % (carac, p["puissance"]), duree=D30MIN)
            e[213] = 0
            effet(e, 0, AURA, p["puissance"], SOI, aura=CARACTERISTIQUE, misc=misc)
            t.append(e)
    return t


def lua(texte):
    return '"' + texte.replace("\\", "\\\\").replace('"', '\\"') + '"'


def ecrire(liste, sorts_sql):
    """Migration 079 (sorts déjà convertis en SQL par auras_nommees.py) et SolUI_Cuisine.lua."""
    ids = ", ".join(str(i) for p in liste for i in [p["sort"]] + p["buffs"])
    objets = ", ".join(str(p["objet"]) for p in liste)
    up = ["-- v3 : cuisine par zone. Généré par outils\\auras_nommees.py (cuisine_v3.py) : ne pas modifier à la main.",
          "-- Le client lit les mêmes sorts dans patch-frFR-4.MPQ ; v3_cuisine.cpp donne l'aura de la spécialisation.",
          "USE acore_world;",
          "DELETE FROM spell_dbc WHERE ID IN (%s);" % ids,
          "DELETE FROM spell_script_names WHERE ScriptName = '%s';" % SCRIPT]
    up += sorts_sql
    up += ["INSERT INTO spell_script_names (spell_id, ScriptName) VALUES %s;"
           % ", ".join("(%d, '%s')" % (p["sort"], SCRIPT) for p in liste)]
    up += ["DROP TABLE IF EXISTS solazeroth_v3_plats, solazeroth_v3_plats_composants;",
           "CREATE TABLE solazeroth_v3_plats (objet INT UNSIGNED NOT NULL PRIMARY KEY, zone INT UNSIGNED NOT NULL,"
           " puissance TINYINT UNSIGNED NOT NULL, sort INT UNSIGNED NOT NULL, force_ INT UNSIGNED NOT NULL,"
           " agilite INT UNSIGNED NOT NULL, intelligence INT UNSIGNED NOT NULL);",
           "CREATE TABLE solazeroth_v3_plats_composants (objet INT UNSIGNED NOT NULL, composant INT UNSIGNED NOT NULL,"
           " nombre INT UNSIGNED NOT NULL, PRIMARY KEY (objet, composant));",
           "INSERT INTO solazeroth_v3_plats VALUES %s;" % ", ".join(
               "(%d, %d, %d, %d, %d, %d, %d)" % (p["objet"], p["zone"], p["puissance"], p["sort"], *p["buffs"])
               for p in liste),
           "INSERT INTO solazeroth_v3_plats_composants VALUES %s;" % ", ".join(
               "(%d, %d, %d)" % (p["objet"], c, n) for p in liste for c, n in p["composants"]),
           # Sort d'origine des plats, pour la migration de retour (gardé au premier passage seulement).
           "CREATE TABLE IF NOT EXISTS solazeroth_v3_plats_origine (entry INT UNSIGNED NOT NULL PRIMARY KEY,"
           " spellid_1 INT NOT NULL, description VARCHAR(255) NOT NULL);",
           "INSERT IGNORE INTO solazeroth_v3_plats_origine SELECT entry, spellid_1, description FROM item_template"
           " WHERE entry IN (%s);" % objets]
    up += ["UPDATE item_template SET spellid_1 = %d, description = '' WHERE entry = %d;" % (p["sort"], p["objet"])
           for p in liste]
    down = ["-- Retire la cuisine v3 et rend aux plats leur sort de nourriture.",
            "USE acore_world;",
            "UPDATE item_template i JOIN solazeroth_v3_plats_origine o ON o.entry = i.entry"
            " SET i.spellid_1 = o.spellid_1, i.description = o.description;",
            "DROP TABLE IF EXISTS solazeroth_v3_plats, solazeroth_v3_plats_composants, solazeroth_v3_plats_origine;",
            up[3], up[4]]
    for suffixe, contenu in ((".up.sql", up), (".down.sql", down)):
        with open(MIGRATION + suffixe, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(contenu) + "\n")

    sortie = ["-- Généré par outils\\cuisine_v3.py (auras_nommees.py) : ne pas modifier à la main.",
              "-- Catégorie Cuisine de la fenêtre Équipement : { plat, nom, puissance du repas, puissance requise,",
              "-- prix en cuivre, { { composant, nombre }, … }, zone }. Se fabrique près d'un feu.",
              "table.insert(SolUI.RECETTES, { nom = \"Cuisine\", feu = true, recettes = {"]
    for p in sorted(liste, key=lambda p: (p["puissance"], p["nom"])):
        sortie.append("    { %d, %s, %d, 0, 0, { %s }, %s }," % (
            p["objet"], lua(p["nom"]), p["puissance"],
            ", ".join("{ %d, %d }" % (c, n) for c, n in p["composants"]), lua(p["nom_zone"])))
    sortie.append("} })")
    with open(LUA, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(sortie) + "\n")
