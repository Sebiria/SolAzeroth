"""Sol'Azeroth v3 (31/10/2026) : désenchanter et enchanter depuis la fenêtre Équipement (demande de l'utilisateur ;
choix des enchantements laissé à Claude, en pensant à l'équilibre).

- Désenchanter : une pièce d'armure ou une arme du sac, verte ou mieux, donne le butin de Blizzard de sa table
  (disenchant_loot_template), rangé dans la Collection. Nos pièces (quêtes, fabrication, rangs) reçoivent la table
  d'une pièce verte de même genre et de même niveau d'objet. À Durotar (niveau d'objet 15 au plus) : Poussière étrange
  ou Essence de magie inférieure.
- Enchanter : les enchantements de Blizzard (SpellItemEnchantment.dbc, que le client affiche déjà), payés avec ces
  composants et un peu d'or (OR_PAR_COMPOSANT). Un par pièce ; le nouveau remplace l'ancien.
- Équilibre (simulation_combat.py, personnage de fin de vallée contre Durotar) : le jeu complet vaut à peu près un rang
  d'amélioration sur toutes les pièces. L'Endurance des bottes (+10 points de vie) le doublait : pas de bottes à
  Durotar.

Écrit la migration 081 et SolUI_Enchantements.lua.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from collection_v3 import requete

MIGRATION = r"C:\SolAzeroth\sql\migrations\081_v3_enchantement"
LUA = r"C:\SolAzeroth\interface-v3\FrameXML\SolUI_Enchantements.lua"

POUSSIERE, ESSENCE = 10940, 10938
OR_PAR_COMPOSANT = 10   # cuivre
PLASTRON, BRASSARDS, CAPE, BOUCLIER, ARME_1M, ARME_2M, MAIN_GAUCHE = [5, 20], [9], [16], [14], [13, 21, 22], [17], [23]
MAINS = [10]
# Lot T8 des Tarides : composants du désenchantement des pièces 16 à 25 (tables 2, 3, 22 et 23).
ESSENCE_SUPERIEURE, ESSENCE_ASTRALE, PETIT_ECLAT = 10939, 10998, 10978

# (identifiant, nom, effet, enchantement de SpellItemEnchantment.dbc, InventoryType, composants)
ENCHANTEMENTS = [
    (1, "Santé mineure", "+5 points de vie", 41, PLASTRON, {POUSSIERE: 2}),
    (2, "Force mineure", "+1 Force", 248, BRASSARDS, {POUSSIERE: 3, ESSENCE: 1}),
    (3, "Agilité mineure", "+1 Agilité", 247, BRASSARDS, {POUSSIERE: 3, ESSENCE: 1}),
    (4, "Protection mineure", "+10 armure", 783, CAPE, {POUSSIERE: 2, ESSENCE: 1}),
    (5, "Protection mineure", "+10 armure", 783, BOUCLIER, {POUSSIERE: 2, ESSENCE: 1}),
    (6, "Frappe mineure", "+1 aux dégâts de l'arme", 250, ARME_1M, {POUSSIERE: 3, ESSENCE: 2}),
    (7, "Impact mineur", "+2 aux dégâts de l'arme", 241, ARME_2M, {POUSSIERE: 4, ESSENCE: 2}),
    # Lot D5 (02/11/2026) : la caractéristique des lanceurs de sorts, sur les brassards et l'orbe (qui remplace le
    # bouclier du guerrier et son enchantement de Protection).
    (8, "Intelligence mineure", "+1 Intelligence", 79, BRASSARDS, {POUSSIERE: 3, ESSENCE: 1}),
    (9, "Intelligence mineure", "+1 Intelligence", 79, MAIN_GAUCHE, {POUSSIERE: 2, ESSENCE: 1}),
]

# Lot T8 des Tarides (03/11/2026, §4.7.5) : palier « inférieur », écrit par artisanat_tarides.py (migration 141).
# Il s'ajoute à celui de Durotar : sur une même pièce, le nouveau remplace l'ancien. Caractéristique principale sur les
# brassards et les gants (et l'orbe) ; pas de bottes, comme à Durotar.
ENCHANTEMENTS_TARIDES = [
    (10, "Force inférieure", "+3 Force", 823, BRASSARDS + MAINS, {POUSSIERE: 4, ESSENCE_ASTRALE: 1}),
    (11, "Agilité inférieure", "+3 Agilité", 849, BRASSARDS + MAINS, {POUSSIERE: 4, ESSENCE_ASTRALE: 1}),
    (12, "Intelligence inférieure", "+3 Intelligence", 723, BRASSARDS + MAINS + MAIN_GAUCHE,
     {POUSSIERE: 4, ESSENCE_ASTRALE: 1}),
    (13, "Santé inférieure", "+15 points de vie", 242, PLASTRON, {POUSSIERE: 4, ESSENCE_SUPERIEURE: 1}),
    (14, "Protection inférieure", "+20 armure", 744, CAPE, {POUSSIERE: 3, ESSENCE_SUPERIEURE: 1}),
    (15, "Bouclier renforcé", "+30 armure", 848, BOUCLIER, {POUSSIERE: 4, ESSENCE_ASTRALE: 1}),
    (16, "Frappe inférieure", "+2 aux dégâts de l'arme", 241, ARME_1M, {POUSSIERE: 4, ESSENCE_ASTRALE: 1, PETIT_ECLAT: 1}),
    (17, "Impact inférieur", "+3 aux dégâts de l'arme", 943, ARME_2M, {POUSSIERE: 6, ESSENCE_ASTRALE: 2, PETIT_ECLAT: 1}),
]

# Table de désenchantement d'une pièce verte : (armure, arme) par tranche de niveau d'objet. Lot T8 des Tarides :
# tranches 26 à 30 et 31 à 35 (tables de Blizzard relues en base, 4 et 24, 5 et 25).
TABLES = [(15, 1, 21), (20, 2, 22), (25, 3, 23), (30, 4, 24), (35, 5, 25)]


def lua(texte):
    return '"' + texte.replace("\\", "\\\\").replace('"', '\\"') + '"'


def nos_pieces():
    """(entrée, classe, niveau d'objet) de nos pièces, rangs compris, vertes ou mieux."""
    return [(int(e), int(c), int(n)) for e, c, n in requete(
        "SELECT entry, class, ItemLevel FROM item_template WHERE class IN (2, 4) AND Quality >= 2 AND "
        "(entry BETWEEN 910101 AND 910299 OR entry IN (SELECT entree FROM solazeroth_v3_rangs))")]


def table_de(classe, niveau):
    for plafond, armure, arme in TABLES:
        if niveau <= plafond:
            return arme if classe == 2 else armure
    return None


def descriptions(tables):
    """Texte du butin de chaque table : « Poussière étrange ×1-2 (80 %) ou … »."""
    sortie = {}
    for t in sorted(tables):
        lignes = [(int(o), float(c), int(a), int(b), nom) for o, c, a, b, nom in requete(
            "SELECT d.Item, d.Chance, d.MinCount, d.MaxCount, COALESCE(NULLIF(l.Name, ''), i.name) "
            "FROM disenchant_loot_template d JOIN item_template i ON i.entry = d.Item "
            "LEFT JOIN item_template_locale l ON l.ID = i.entry AND l.locale = 'frFR' WHERE d.Entry = %d" % t)]
        # Chance 0 : part égale de ce que les autres laissent (règle des groupes de butin du moteur).
        reste = max(0.0, 100.0 - sum(c for _, c, _, _, _ in lignes))
        zeros = sum(1 for _, c, _, _, _ in lignes if c == 0) or 1
        morceaux = []
        for _, c, a, b, nom in sorted(lignes, key=lambda l: -(l[1] or reste / zeros)):
            part = c or reste / zeros
            if part > 0:
                morceaux.append("%s ×%s (%d %%)" % (nom, a if a == b else "%d-%d" % (a, b), round(part)))
        sortie[t] = " ou ".join(morceaux)
    return sortie


def main():
    pieces = nos_pieces()
    affectees = [(e, table_de(c, n)) for e, c, n in pieces if table_de(c, n)]
    up = ["-- v3 : désenchantement et enchantement. Généré par outils\\enchantement_v3.py : ne pas modifier à la main.",
          "USE acore_world;",
          "DROP TABLE IF EXISTS solazeroth_v3_enchantements, solazeroth_v3_enchantements_types,"
          " solazeroth_v3_enchantements_composants;",
          "CREATE TABLE solazeroth_v3_enchantements (id INT UNSIGNED NOT NULL PRIMARY KEY,"
          " enchantement INT UNSIGNED NOT NULL, prix INT UNSIGNED NOT NULL);",
          "CREATE TABLE solazeroth_v3_enchantements_types (id INT UNSIGNED NOT NULL, type TINYINT UNSIGNED NOT NULL,"
          " PRIMARY KEY (id, type));",
          "CREATE TABLE solazeroth_v3_enchantements_composants (id INT UNSIGNED NOT NULL, composant INT UNSIGNED NOT NULL,"
          " nombre INT UNSIGNED NOT NULL, PRIMARY KEY (id, composant));",
          "INSERT INTO solazeroth_v3_enchantements VALUES %s;" % ", ".join(
              "(%d, %d, %d)" % (i, e, OR_PAR_COMPOSANT * sum(c.values())) for i, _, _, e, _, c in ENCHANTEMENTS),
          "INSERT INTO solazeroth_v3_enchantements_types VALUES %s;" % ", ".join(
              "(%d, %d)" % (i, t) for i, _, _, _, types, _ in ENCHANTEMENTS for t in types),
          "INSERT INTO solazeroth_v3_enchantements_composants VALUES %s;" % ", ".join(
              "(%d, %d, %d)" % (i, o, n) for i, _, _, _, _, c in ENCHANTEMENTS for o, n in c.items()),
          # Table de désenchantement d'origine de nos pièces, pour la migration de retour (premier passage seulement).
          "CREATE TABLE IF NOT EXISTS solazeroth_v3_desenchantement_origine (entry INT UNSIGNED NOT NULL PRIMARY KEY,"
          " DisenchantID INT UNSIGNED NOT NULL, RequiredDisenchantSkill SMALLINT NOT NULL);",
          "INSERT IGNORE INTO solazeroth_v3_desenchantement_origine SELECT entry, DisenchantID, RequiredDisenchantSkill"
          " FROM item_template WHERE entry IN (%s);" % ", ".join(str(e) for e, _ in affectees)]
    for t in sorted({t for _, t in affectees}):
        up.append("UPDATE item_template SET DisenchantID = %d, RequiredDisenchantSkill = 1 WHERE entry IN (%s);"
                  % (t, ", ".join(str(e) for e, u in affectees if u == t)))
    down = ["-- Retire le désenchantement et l'enchantement v3.",
            "USE acore_world;",
            "UPDATE item_template i JOIN solazeroth_v3_desenchantement_origine o ON o.entry = i.entry"
            " SET i.DisenchantID = o.DisenchantID, i.RequiredDisenchantSkill = o.RequiredDisenchantSkill;",
            "DROP TABLE IF EXISTS solazeroth_v3_enchantements, solazeroth_v3_enchantements_types,"
            " solazeroth_v3_enchantements_composants, solazeroth_v3_desenchantement_origine;"]
    for suffixe, contenu in ((".up.sql", up), (".down.sql", down)):
        with open(MIGRATION + suffixe, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(contenu) + "\n")

    tables = {int(t) for (t,) in requete(
        "SELECT DISTINCT DisenchantID FROM item_template WHERE DisenchantID > 0 AND ItemLevel <= 25")} | \
        {t for _, t in affectees}
    sortie = ["-- Généré par outils\\enchantement_v3.py : ne pas modifier à la main.",
              "-- Enchantements de la fenêtre Équipement : { id, nom, effet, enchantement, { InventoryType… },",
              "-- { { composant, nombre }, … }, prix en cuivre } ; butin de chaque table de désenchantement.",
              "SolUI.ENCHANTEMENTS = {"]
    for i, nom, effet, e, types, c in ENCHANTEMENTS:
        sortie.append("    { %d, %s, %s, %d, { %s }, { %s }, %d }," % (
            i, lua(nom), lua(effet), e, ", ".join(map(str, types)),
            ", ".join("{ %d, %d }" % (o, n) for o, n in c.items()), OR_PAR_COMPOSANT * sum(c.values())))
    sortie += ["}", "SolUI.DESENCHANTEMENT = {"]
    sortie += ["    [%d] = %s," % (t, lua(texte)) for t, texte in descriptions(tables).items()]
    sortie.append("}")
    with open(LUA, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(sortie) + "\n")
    print(len(ENCHANTEMENTS), "enchantements,", len(affectees), "pièces désenchantables : migration 081 et",
          "SolUI_Enchantements.lua écrits.")


if __name__ == "__main__":
    main()
