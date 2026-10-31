"""Sol'Azeroth v3 (31/10/2026) : catalogue de la Collection (document v3, § 2.8 ; maquette « 8 · Collection »).

La Collection montre tous les objets à collectionner du jeu, grisés tant qu'on n'en a pas. Le client ne connaît le nom
d'un objet qu'après l'avoir demandé au serveur : le catalogue (identifiant, nom français, qualité) est donc écrit dans
l'interface, en interface-v3\\FrameXML\\SolUI_Catalogue.lua.

Objets retenus : les matériaux (classe 7, sauf la viande, inutile sans nourriture) et les gemmes (classe 3), de qualité
commune ou mieux, qu'on peut réellement obtenir (butin, marchand, prospection, pilage, désenchantement). Les éclats
cadavériques, composants rares et reliques de zone viendront avec F6 à F10.
"""
import subprocess

from hauts_faits_natifs import IDENTIFIANTS, MYSQL

SORTIE = r"C:\SolAzeroth\interface-v3\FrameXML\SolUI_Catalogue.lua"

# nom de la catégorie, puis (classe, sous-classe) de item_template
CATEGORIES = [
    ("Tissus", [(7, 5)]),
    ("Cuirs et peaux", [(7, 6)]),
    ("Minerais, barres et pierres", [(7, 7)]),
    ("Herbes", [(7, 9)]),
    ("Éléments", [(7, 10)]),
    ("Gemmes", [(3, s) for s in range(9)] + [(7, 4)]),
    ("Enchantement", [(7, 12)]),
    ("Pièces d'ingénierie", [(7, 1), (7, 2), (7, 3)]),
    ("Divers", [(7, 11), (7, 13)]),
]

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
    obtenables = " UNION ".join("SELECT Item FROM %s_loot_template WHERE Reference = 0" % t for t in TABLES)
    lignes = requete(
        "SELECT i.entry, i.class, i.subclass, i.Quality, i.ItemLevel, COALESCE(NULLIF(l.Name, ''), i.name) "
        "FROM item_template i LEFT JOIN item_template_locale l ON l.ID = i.entry AND l.locale = 'frFR' "
        "WHERE i.class IN (3, 7) AND i.Quality >= 1 AND i.entry IN (%s UNION SELECT item FROM npc_vendor)" % obtenables)
    sortie = ["-- Catalogue de la Collection. Généré par outils\\collection_v3.py : ne pas modifier à la main.",
              "-- Par catégorie : { identifiant, nom, qualité }, du plus petit niveau d'objet au plus grand.",
              "SolUI.CATALOGUE = {"]
    total = 0
    for nom, genres in CATEGORIES:
        objets = sorted((int(niveau), nom_objet, int(entree), int(qualite))
                        for entree, classe, sous_classe, qualite, niveau, nom_objet in lignes
                        if (int(classe), int(sous_classe)) in genres)
        total += len(objets)
        sortie.append("    { nom = %s, objets = {" % lua(nom))
        sortie += ["        { %d, %s, %d }," % (entree, lua(nom_objet), qualite) for _, nom_objet, entree, qualite in objets]
        sortie.append("    } },")
    sortie.append("}")
    with open(SORTIE, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(sortie) + "\n")
    print(total, "objets dans", len(CATEGORIES), "catégories : SolUI_Catalogue.lua écrit.")


if __name__ == "__main__":
    main()
