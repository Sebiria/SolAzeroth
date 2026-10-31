"""v3, F5e (31/10/2026) : pourcentage de Durotar, lieux à nettoyer et exploration.

Source : « Durotar — Histoire et quêtes (brouillon).md » :
- la part de chaque quête d'histoire (D01 à D26, « **Part** : x % ») ;
- les lieux à nettoyer (§4.1.1, A01 à A10) : monstres à éliminer, chef, part ;
- l'exploration (§4.2) : 24 sous-zones et leur part.
Les autres annexes (primes, contrats, défis, reliques : 25 % de la zone) viendront ensuite.

Écrit la migration 074 :
- acore_world.solazeroth_v3_zone_parts (zone, genre, clé, part en centièmes de %, nom) ;
  genre 1 = quête rendue, 2 = sous-zone explorée, 3 = lieu nettoyé ;
- acore_world.solazeroth_v3_lieux_monstres (lieu, créature, nombre) : le chef compte pour 1 ;
- acore_characters.solazeroth_v3_lieux (guid, lieu, créature, nombre) : les monstres tués par chaque personnage.
Le serveur lit ces tables au démarrage (v3_zone.cpp).
"""
import os
import re

HISTOIRE = os.path.join(os.path.expanduser("~"), "Documents", "Claude", "Sol'Azeroth",
                        "Durotar — Histoire et quêtes (brouillon).md")
MIGRATION = r"C:\SolAzeroth\sql\migrations\074_v3_zone_durotar"

DUROTAR = 14
QUETE = 910000          # D01 = 910001 (quetes_durotar.py)
LIEU = 1                # A01 = lieu 1
QUETE_GENRE, EXPLORATION, LIEU_GENRE = 1, 2, 3


def centiemes(texte):
    return round(float(texte.replace(",", ".")) * 100)


def s(texte):
    return "'" + texte.replace("\\", "\\\\").replace("'", "''") + "'"


def lire():
    quetes, lieux, sous_zones = [], [], []
    courant, section = None, None
    for ligne in open(HISTOIRE, encoding="utf-8"):
        m = re.match(r"#### D(\d\d) — (.+)", ligne)
        if m:
            courant = (int(m.group(1)), m.group(2).strip())
            continue
        if ligne.startswith("#### ") or ligne.startswith("### ") or ligne.startswith("## "):
            courant = None
            section = ligne.strip()
        m = re.match(r"- \*\*Part\*\* : ([\d,]+) %\.$", ligne.strip())
        if m and courant and courant[0] <= 26:
            quetes.append((courant[0], courant[1], centiemes(m.group(1))))
        cellules = [c.strip() for c in ligne.strip().strip("|").split("|")]
        if section and section.startswith("#### 4.1.1") and re.match(r"A\d\d \(L\d\d\)", cellules[0]):
            numero = int(cellules[0][1:3])
            monstres = [(int(e), int(n)) for n, e in re.findall(r"(\d+) [^,(]+\((\d+)\)", cellules[4])]
            chef = re.search(r"\((?:copie de )?(\d+)", cellules[5])
            if chef:
                monstres.append((int(chef.group(1)), 1))
            lieux.append((numero, cellules[1], monstres, centiemes(cellules[8].rstrip(" %"))))
        if section and section.startswith("### 4.2") and cellules[0].isdigit():
            sous_zones.append((int(cellules[0]), cellules[1], centiemes(cellules[4].rstrip(" %"))))
    return quetes, lieux, sous_zones


def main():
    quetes, lieux, sous_zones = lire()
    totaux = [sum(q[2] for q in quetes), sum(z[2] for z in sous_zones), sum(l[3] for l in lieux)]
    if len(quetes) != 26 or len(sous_zones) != 24 or len(lieux) != 10 or totaux != [5000, 600, 1900]:
        raise SystemExit("Document inattendu : %d quêtes, %d sous-zones, %d lieux, totaux %s"
                         % (len(quetes), len(sous_zones), len(lieux), totaux))
    up = ["-- v3, F5e : pourcentage de Durotar. Généré par outils\\zone_durotar.py : ne pas modifier à la main.",
          "-- Parts en centièmes de % : quêtes d'histoire (50 %), exploration (6 %), lieux à nettoyer (19 %).",
          "DROP TABLE IF EXISTS acore_world.solazeroth_v3_zone_parts;",
          "CREATE TABLE acore_world.solazeroth_v3_zone_parts (zone INT UNSIGNED NOT NULL, genre TINYINT UNSIGNED NOT NULL,"
          " cle INT UNSIGNED NOT NULL, part INT UNSIGNED NOT NULL, nom VARCHAR(100) NOT NULL,"
          " PRIMARY KEY (zone, genre, cle));",
          "DROP TABLE IF EXISTS acore_world.solazeroth_v3_lieux_monstres;",
          "CREATE TABLE acore_world.solazeroth_v3_lieux_monstres (lieu INT UNSIGNED NOT NULL, creature INT UNSIGNED NOT NULL,"
          " nombre INT UNSIGNED NOT NULL, PRIMARY KEY (lieu, creature));",
          "CREATE TABLE IF NOT EXISTS acore_characters.solazeroth_v3_lieux (guid INT UNSIGNED NOT NULL,"
          " lieu INT UNSIGNED NOT NULL, creature INT UNSIGNED NOT NULL, nombre INT UNSIGNED NOT NULL,"
          " PRIMARY KEY (guid, lieu, creature));"]
    parts = ([(QUETE_GENRE, QUETE + n, p, titre) for n, titre, p in quetes]
             + [(EXPLORATION, zone, p, nom) for zone, nom, p in sous_zones]
             + [(LIEU_GENRE, LIEU + numero - 1, p, nom) for numero, nom, _, p in lieux])
    up.append("INSERT INTO acore_world.solazeroth_v3_zone_parts VALUES\n" + ",\n".join(
        "(%d, %d, %d, %d, %s)" % (DUROTAR, genre, cle, p, s(nom)) for genre, cle, p, nom in parts) + ";")
    up.append("INSERT INTO acore_world.solazeroth_v3_lieux_monstres VALUES\n" + ",\n".join(
        "(%d, %d, %d)" % (LIEU + numero - 1, e, n) for numero, _, monstres, _ in lieux for e, n in monstres) + ";")
    down = ["-- Retire le pourcentage de Durotar. Les monstres tués pour les lieux sont perdus.",
            "DROP TABLE acore_world.solazeroth_v3_zone_parts;",
            "DROP TABLE acore_world.solazeroth_v3_lieux_monstres;",
            "DROP TABLE acore_characters.solazeroth_v3_lieux;"]
    for suffixe, contenu in ((".up.sql", up), (".down.sql", down)):
        with open(MIGRATION + suffixe, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(contenu) + "\n")
    print(len(parts), "parts (%d quêtes, %d sous-zones, %d lieux) : migration 074 écrite."
          % (len(quetes), len(sous_zones), len(lieux)))


if __name__ == "__main__":
    main()
