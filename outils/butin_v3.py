"""Sol'Azeroth v3 (31/10/2026, demande de l'utilisateur) : butin inutile retiré du jeu (migration 068).

Le joueur n'a pas de sac de départ : les objets gris ne servent à rien. Et la vie ne remonte que par le feu de camp,
la potion du module et les sorts : nourriture, boissons, potions de soins ou de mana, bandages, pierres de soins… sont
bannis. Sont retirés :
- les objets de qualité médiocre (gris) ;
- les consommables (classe 0) dont un sort rend de la vie ou du mana, d'un coup ou dans la durée (lu dans Spell.dbc).
On garde tout objet lié à une quête : objet de quête, objet qui lance une quête, objet demandé ou fourni par une quête.
Mais le sort de tout consommable de régénération, même lié à une quête, est désactivé pour les joueurs (table
disables) : l'objet se livre encore, il ne se mange, ne se boit ni ne s'utilise plus. Les sorts de classe sont épargnés.

Retirés des tables de butin (monstres, objets du décor, réserves, contenants, vol à la tire, pêche, dépeçage) et des
marchands. Les lignes retirées sont gardées dans des tables solazeroth_v3_butin_* pour la migration de retour.
Les récompenses de quête ne sont pas touchées.
"""
import os
import subprocess

import dbc
from hauts_faits_natifs import DBC_SERVEUR, IDENTIFIANTS, MYSQL

MIGRATION = r"C:\SolAzeroth\sql\migrations\068_v3_butin_inutile"

# Spell.dbc : types d'effet (71 à 73) et d'aura (95 à 97) qui rendent de la vie ou de la ressource.
EFFETS = {10, 30, 67, 136, 137}          # soin, gain de ressource, soin à la vie maximale, soin et gain en %
AURAS = {8, 20, 21, 24, 84, 85, 161}     # soins et gains périodiques, régénération de vie et de ressource

FAMILLES_DE_CLASSE = {3, 4, 5, 6, 7, 8, 9, 10, 11, 15}   # mage à chevalier de la mort
COMMENTAIRE = "Sol''Azeroth v3 : consommable de regeneration"

TABLES = ["creature_loot_template", "gameobject_loot_template", "reference_loot_template", "item_loot_template",
          "pickpocketing_loot_template", "fishing_loot_template", "skinning_loot_template"]


def requete(sql):
    sortie = subprocess.run([MYSQL, "--defaults-extra-file=" + IDENTIFIANTS, "-N", "-B", "acore_world", "-e", sql],
                            capture_output=True, check=True).stdout.decode()
    return [ligne.split("\t") for ligne in sortie.splitlines()]


def sorts_de_regeneration():
    # Sorts hors des familles de classe (208 : SpellFamilyName) : ceux des objets (sans famille, ou potions : 13).
    d = dbc.Dbc.ouvrir(os.path.join(DBC_SERVEUR, "Spell.dbc"))
    return {e[0] for e in d.enregistrements if e[208] not in FAMILLES_DE_CLASSE
            and (EFFETS & set(e[71:74]) or any(e[71 + i] == 6 and e[95 + i] in AURAS for i in range(3)))}


def main():
    regeneration = sorts_de_regeneration()
    de_quete = {int(l[0]) for l in requete(
        "SELECT RequiredItemId1 FROM quest_template UNION SELECT RequiredItemId2 FROM quest_template "
        "UNION SELECT RequiredItemId3 FROM quest_template UNION SELECT RequiredItemId4 FROM quest_template "
        "UNION SELECT RequiredItemId5 FROM quest_template UNION SELECT RequiredItemId6 FROM quest_template "
        "UNION SELECT ItemDrop1 FROM quest_template UNION SELECT ItemDrop2 FROM quest_template "
        "UNION SELECT ItemDrop3 FROM quest_template UNION SELECT ItemDrop4 FROM quest_template "
        "UNION SELECT StartItem FROM quest_template")}
    gris, consommables, bannis = [], [], set()
    for entree, classe, qualite, lien, depart, *sorts in requete(
            "SELECT entry, class, Quality, bonding, startquest, spellid_1, spellid_2, spellid_3, spellid_4, spellid_5 "
            "FROM item_template"):
        entree = int(entree)
        if classe == "0":
            bannis |= regeneration & {int(s) for s in sorts}
        if classe == "12" or lien == "4" or depart != "0" or entree in de_quete:
            continue
        if qualite == "0":
            gris.append(entree)
        elif classe == "0" and regeneration & {int(s) for s in sorts}:
            consommables.append(entree)

    objets = sorted(gris + consommables)
    up = ["-- v3 : butin inutile retiré (objets gris, consommables qui rendent vie ou mana).",
          "-- Généré par outils\\butin_v3.py : ne pas modifier à la main.",
          "USE acore_world;",
          "DROP TABLE IF EXISTS solazeroth_v3_butin_objets;",
          "CREATE TABLE solazeroth_v3_butin_objets (entry INT UNSIGNED NOT NULL PRIMARY KEY);"]
    for i in range(0, len(objets), 500):
        up.append("INSERT INTO solazeroth_v3_butin_objets VALUES %s;" % ", ".join("(%d)" % o for o in objets[i:i + 500]))
    up += ["INSERT IGNORE INTO disables (sourceType, entry, flags, params_0, params_1, comment) VALUES %s;"
           % ", ".join("(0, %d, 1, '', '', '%s')" % (sort, COMMENTAIRE) for sort in sorted(bannis))]
    down = ["-- Rend le butin retiré par la migration 068.", "USE acore_world;",
            "DELETE FROM disables WHERE sourceType = 0 AND comment = '%s';" % COMMENTAIRE]
    for table in TABLES:
        copie = "solazeroth_v3_butin_" + table.replace("_loot_template", "")
        up += ["DROP TABLE IF EXISTS %s;" % copie,
               "CREATE TABLE %s SELECT t.* FROM %s t JOIN solazeroth_v3_butin_objets o ON o.entry = t.Item "
               "WHERE t.Reference = 0;" % (copie, table),
               "DELETE t FROM %s t JOIN solazeroth_v3_butin_objets o ON o.entry = t.Item WHERE t.Reference = 0;" % table]
        down += ["INSERT IGNORE INTO %s SELECT * FROM %s;" % (table, copie), "DROP TABLE %s;" % copie]
    up += ["DROP TABLE IF EXISTS solazeroth_v3_butin_marchands;",
           "CREATE TABLE solazeroth_v3_butin_marchands SELECT v.* FROM npc_vendor v "
           "JOIN solazeroth_v3_butin_objets o ON o.entry = v.item;",
           "DELETE v FROM npc_vendor v JOIN solazeroth_v3_butin_objets o ON o.entry = v.item;"]
    down += ["INSERT IGNORE INTO npc_vendor SELECT * FROM solazeroth_v3_butin_marchands;",
             "DROP TABLE solazeroth_v3_butin_marchands;", "DROP TABLE solazeroth_v3_butin_objets;"]
    for suffixe, contenu in ((".up.sql", up), (".down.sql", down)):
        with open(MIGRATION + suffixe, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(contenu) + "\n")
    print(len(gris), "objets gris et", len(consommables), "consommables de régénération retirés,", len(bannis),
          "sorts désactivés : migration 068 écrite.")


if __name__ == "__main__":
    main()
