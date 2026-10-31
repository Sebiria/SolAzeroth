"""Hauts faits Sol'Azeroth dans la fenêtre native (V7).

Lit acore_world.solazeroth_hauts_faits et produit :
- côté client, Achievement.dbc, Achievement_Criteria.dbc et Achievement_Category.dbc dans patch-client\\fichiers\\DBFilesClient ;
- côté serveur, la migration SQL (tables achievement_dbc, achievement_criteria_dbc, achievement_category_dbc).
Numérotation : catégorie 15100 (« Sol'Azeroth ») et 15101 à 15107 ; haut fait 9000 + id ; critère 16000 + id.
Progression : critère de type 75 (plus haute cote personnelle), avec une fausse équipe d'arène 1000 + id :
le module y écrit l'avancement, aucune vraie équipe (2, 3 ou 5) ne peut le toucher.
"""
import os
import subprocess

import dbc

MYSQL = r"C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe"
IDENTIFIANTS = r"C:\SolAzeroth\config\mysql-acore.cnf"
DBC_SERVEUR = r"C:\SolAzeroth\data\dbc"
DBC_CLIENT = r"C:\SolAzeroth\patch-client\fichiers\DBFilesClient"
MIGRATION = r"C:\SolAzeroth\sql\migrations\049_hauts_faits_natifs"

CATEGORIE = 15100
CATEGORIES = {1: "Donjons", 2: "Défis de boss", 3: "Défi extérieur", 4: "Contrats", 5: "Métiers", 6: "Monde", 7: "Exploits"}
ICONES = {1: 3226, 2: 3225, 3: 3421, 4: 3419, 5: 2846, 6: 3490, 7: 3275}
BASE_HF, BASE_CRITERE = 9000, 16000
TYPE_COTE = 75          # ACHIEVEMENT_CRITERIA_TYPE_HIGHEST_PERSONAL_RATING
EQUIPE = 1000           # fausse équipe d'arène : 1000 + id
POINTS = 10
MASQUE = 0xFF01FE
FRFR = 2                # position du français dans les colonnes de texte


def lire_hauts_faits():
    sortie = subprocess.run([MYSQL, "--defaults-extra-file=" + IDENTIFIANTS, "--default-character-set=utf8mb4", "-N", "-B", "-e",
                             "SELECT id, categorie, nom, description, quantite, talent FROM acore_world.solazeroth_hauts_faits ORDER BY id"],
                            capture_output=True, check=True).stdout.decode("utf-8")
    lignes = []
    for ligne in sortie.splitlines():
        i, c, nom, desc, q, t = ligne.split("\t")
        lignes.append((int(i), int(c), nom, desc, int(q), t == "1"))
    return lignes


def textes(d, chaine):
    """17 champs : 16 langues (français et anglais remplis) puis le masque."""
    champs = [0] * 16
    champs[0] = champs[FRFR] = d.ajouter_texte(chaine)
    return champs + [MASQUE if chaine else 0]


def sql_texte(chaine):
    return "'" + chaine.replace("\\", "\\\\").replace("'", "''") + "'"


def sql_langues(chaine):
    """16 colonnes de langue en SQL : positions 0 et 2 remplies, puis le masque."""
    valeurs = ["NULL"] * 16
    if chaine:
        valeurs[0] = valeurs[FRFR] = sql_texte(chaine)
    return valeurs + [str(MASQUE if chaine else 0)]


def recompense(talent):
    return "1 point de talent pour le compte" if talent else ""


def main():
    hauts_faits = lire_hauts_faits()

    cat = dbc.Dbc.ouvrir(os.path.join(DBC_SERVEUR, "Achievement_Category.dbc"))
    hf = dbc.Dbc.ouvrir(os.path.join(DBC_SERVEUR, "Achievement.dbc"))
    crit = dbc.Dbc.ouvrir(os.path.join(DBC_SERVEUR, "Achievement_Criteria.dbc"))
    # v3, F5d (31/10/2026) : les hauts faits natifs sont purgés (migration 065) ; le client ne garde que les nôtres.
    cat.enregistrements, hf.enregistrements, crit.enregistrements = [], [], []

    categories = [(CATEGORIE, 0xFFFFFFFF, "Sol'Azeroth", 11)]
    categories += [(CATEGORIE + n, CATEGORIE, nom, n) for n, nom in CATEGORIES.items()]
    for i, parent, nom, ordre in categories:
        cat.enregistrements.append([i, parent] + textes(cat, nom) + [ordre])

    ordre = {}
    for i, c, nom, desc, q, talent in hauts_faits:
        ordre[c] = ordre.get(c, 0) + 1
        hf.enregistrements.append([BASE_HF + i, 0xFFFFFFFF, 0xFFFFFFFF, 0] + textes(hf, nom) + textes(hf, desc)
                                  + [CATEGORIE + c, POINTS, ordre[c], 0, ICONES[c]] + textes(hf, recompense(talent)) + [0, 0])
        crit.enregistrements.append([BASE_CRITERE + i, BASE_HF + i, TYPE_COTE, EQUIPE + i, q, 0, 0, 0, 0]
                                    + textes(crit, desc) + [1 if q > 1 else 0, 0, 0, 0, 1])

    os.makedirs(DBC_CLIENT, exist_ok=True)
    cat.enregistrer(os.path.join(DBC_CLIENT, "Achievement_Category.dbc"))
    hf.enregistrer(os.path.join(DBC_CLIENT, "Achievement.dbc"))
    crit.enregistrer(os.path.join(DBC_CLIENT, "Achievement_Criteria.dbc"))

    up = ["-- Hauts faits Sol'Azeroth dans la fenêtre native (V7). Généré par outils\\hauts_faits_natifs.py : ne pas modifier à la main.",
          "-- Le client lit les mêmes données dans patch-frFR-4.MPQ.",
          "USE acore_world;",
          "DELETE FROM achievement_category_dbc WHERE ID BETWEEN %d AND %d;" % (CATEGORIE, CATEGORIE + 99),
          "DELETE FROM achievement_dbc WHERE ID BETWEEN %d AND %d;" % (BASE_HF, BASE_HF + 999),
          "DELETE FROM achievement_criteria_dbc WHERE ID BETWEEN %d AND %d;" % (BASE_CRITERE, BASE_CRITERE + 999)]
    for i, parent, nom, o in categories:
        up.append("INSERT INTO achievement_category_dbc VALUES (%s);" % ", ".join(
            [str(i), str(parent if parent != 0xFFFFFFFF else -1)] + sql_langues(nom) + [str(o)]))
    ordre = {}
    for i, c, nom, desc, q, talent in hauts_faits:
        ordre[c] = ordre.get(c, 0) + 1
        up.append("INSERT INTO achievement_dbc VALUES (%s);" % ", ".join(
            [str(BASE_HF + i), "-1", "-1", "0"] + sql_langues(nom) + sql_langues(desc)
            + [str(CATEGORIE + c), str(POINTS), str(ordre[c]), "0", str(ICONES[c])] + sql_langues(recompense(talent)) + ["0", "0"]))
        up.append("INSERT INTO achievement_criteria_dbc VALUES (%s);" % ", ".join(
            [str(BASE_CRITERE + i), str(BASE_HF + i), str(TYPE_COTE), str(EQUIPE + i), str(q), "0", "0", "0", "0"]
            + sql_langues(desc) + [str(1 if q > 1 else 0), "0", "0", "0", "1"]))
    down = ["-- Retire les hauts faits Sol'Azeroth natifs (les hauts faits du compte restent dans solazeroth_hf_obtenus).",
            "USE acore_world;",
            up[3], up[4], up[5],
            "DELETE FROM acore_characters.character_achievement WHERE achievement BETWEEN %d AND %d;" % (BASE_HF, BASE_HF + 999),
            "DELETE FROM acore_characters.character_achievement_progress WHERE criteria BETWEEN %d AND %d;" % (BASE_CRITERE, BASE_CRITERE + 999)]
    for suffixe, lignes in ((".up.sql", up), (".down.sql", down)):
        with open(MIGRATION + suffixe, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(lignes) + "\n")
    print(len(hauts_faits), "hauts faits,", len(categories), "catégories : DBC client et migration 049 écrits.")


if __name__ == "__main__":
    main()
