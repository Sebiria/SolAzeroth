"""Sol'Azeroth v3 (31/10/2026) : catalogue de la Collection (document v3, § 2.8 ; maquette « 8 · Collection »).

La Collection montre tous les objets à collectionner du jeu, grisés tant qu'on n'en a pas. Le client ne connaît le nom
d'un objet qu'après l'avoir demandé au serveur : le catalogue (identifiant, nom français, qualité) est donc écrit dans
l'interface, en interface-v3\\FrameXML\\SolUI_Catalogue.lua. La même liste va en base (migration 069,
acore_world.solazeroth_v3_collectionnables) : le serveur range ces objets dans la Collection (v3_collection.cpp).

Objets retenus : les matériaux (classe 7) et les gemmes (classe 3), de qualité commune ou mieux, qu'on peut réellement
obtenir (butin, marchand, prospection, pilage, désenchantement). Cuisine (31/10/2026, l'Eau de source fraîche ramassée
allait dans le sac) : la viande, et les consommables qui servent de composant à une recette de cuisine (lait, eau,
fruits…), lus dans Spell.dbc et SkillLineAbility.dbc. Les éclats
cadavériques, composants rares et reliques de zone viendront avec F6 à F10.
"""
import os
import subprocess

import dbc
from hauts_faits_natifs import DBC_SERVEUR, IDENTIFIANTS, MYSQL

SORTIE = r"C:\SolAzeroth\interface-v3\FrameXML\SolUI_Catalogue.lua"
MIGRATION = r"C:\SolAzeroth\sql\migrations\069_v3_collection"

# nom de la catégorie, puis (classe, sous-classe) de item_template
CATEGORIES = [
    ("Tissus", [(7, 5)]),
    ("Cuirs et peaux", [(7, 6)]),
    ("Métaux et pierres", [(7, 7)]),
    ("Herbes", [(7, 9)]),
    ("Éléments", [(7, 10)]),
    ("Gemmes", [(3, s) for s in range(9)] + [(7, 4)]),
    ("Enchantement", [(7, 12)]),
    ("Pièces d'ingénierie", [(7, 1), (7, 2), (7, 3)]),
    ("Cuisine", [(7, 8)]),
    ("Divers", [(7, 11), (7, 13)]),
]
CUISINE = 185   # SkillLine.dbc


def composants_de_cuisine():
    """Objets demandés par une recette de cuisine (Spell.dbc, Reagent : colonnes 52 à 59)."""
    recettes = {e[2] for e in dbc.Dbc.ouvrir(os.path.join(DBC_SERVEUR, "SkillLineAbility.dbc")).enregistrements
                if e[1] == CUISINE}
    composants = set()
    for e in dbc.Dbc.ouvrir(os.path.join(DBC_SERVEUR, "Spell.dbc")).enregistrements:
        if e[0] in recettes:
            composants |= {objet for objet in e[52:60] if objet}
    return composants

TABLES = ["creature", "gameobject", "reference", "item", "skinning", "fishing", "pickpocketing", "prospecting",
          "milling", "disenchant"]


def requete(sql):
    sortie = subprocess.run([MYSQL, "--defaults-extra-file=" + IDENTIFIANTS, "--default-character-set=utf8mb4", "-N", "-B",
                             "acore_world", "-e", sql],
                            capture_output=True, check=True).stdout.decode("utf-8")
    return [ligne.split("\t") for ligne in sortie.splitlines()]


def lua(texte):
    return '"' + texte.replace("\\", "\\\\").replace('"', '\\"') + '"'


def main():
    cuisine = composants_de_cuisine()
    obtenables = " UNION ".join("SELECT Item FROM %s_loot_template WHERE Reference = 0" % t for t in TABLES)
    lignes = requete(
        "SELECT i.entry, i.class, i.subclass, i.Quality, i.ItemLevel, COALESCE(NULLIF(l.Name, ''), i.name) "
        "FROM item_template i LEFT JOIN item_template_locale l ON l.ID = i.entry AND l.locale = 'frFR' "
        "WHERE (i.class IN (3, 7) OR (i.class = 0 AND i.entry IN (%s))) AND i.Quality >= 1 "
        "AND i.entry IN (%s UNION SELECT item FROM npc_vendor)" % (",".join(map(str, sorted(cuisine))), obtenables))
    sortie = ["-- Catalogue de la Collection. Généré par outils\\collection_v3.py : ne pas modifier à la main.",
              "-- Par catégorie : { identifiant, nom, qualité }, du plus petit niveau d'objet au plus grand.",
              "SolUI.CATALOGUE = {"]
    total, tous = 0, set()
    for nom, genres in CATEGORIES:
        objets = sorted((int(niveau), nom_objet, int(entree), int(qualite))
                        for entree, classe, sous_classe, qualite, niveau, nom_objet in lignes
                        if (int(classe), int(sous_classe)) in genres
                        or (nom == "Cuisine" and classe == "0"))
        total += len(objets)
        tous |= {entree for _, _, entree, _ in objets}
        sortie.append("    { nom = %s, objets = {" % lua(nom))
        sortie += ["        { %d, %s, %d }," % (entree, lua(nom_objet), qualite) for _, nom_objet, entree, qualite in objets]
        sortie.append("    } },")
    sortie.append("}")
    with open(SORTIE, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(sortie) + "\n")
    up = ["-- v3 : inventaire sans limite (document v3, § 2.8). Généré par outils\\collection_v3.py : ne pas modifier à la main.",
          "-- Les objets à collectionner (les mêmes que SolUI_Catalogue.lua) et ce que chaque personnage en possède.",
          "DROP TABLE IF EXISTS acore_world.solazeroth_v3_collectionnables;",
          "CREATE TABLE acore_world.solazeroth_v3_collectionnables (entry INT UNSIGNED NOT NULL PRIMARY KEY);"]
    tous = sorted(tous)
    for i in range(0, len(tous), 500):
        up.append("INSERT INTO acore_world.solazeroth_v3_collectionnables VALUES %s;"
                  % ", ".join("(%d)" % e for e in tous[i:i + 500]))
    up.append("CREATE TABLE IF NOT EXISTS acore_characters.solazeroth_v3_collection (guid INT UNSIGNED NOT NULL, "
              "objet INT UNSIGNED NOT NULL, nombre INT UNSIGNED NOT NULL, PRIMARY KEY (guid, objet));")
    down = ["-- Retire l'inventaire sans limite. Les objets rangés sont perdus : faire une sauvegarde avant.",
            "DROP TABLE acore_world.solazeroth_v3_collectionnables;",
            "DROP TABLE acore_characters.solazeroth_v3_collection;"]
    for suffixe, contenu in ((".up.sql", up), (".down.sql", down)):
        with open(MIGRATION + suffixe, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(contenu) + "\n")
    print(total, "objets dans", len(CATEGORIES), "catégories : SolUI_Catalogue.lua et migration 069 écrits.")


if __name__ == "__main__":
    main()
