"""v3, F5e (31/10/2026) : pourcentage d'une zone, lieux à nettoyer et exploration.

Usage : py zone_durotar.py [durotar|tarides]   (durotar par défaut ; lot T3 des Tarides, 03/11/2026)

Source : le brouillon de la zone (« <Zone> — Histoire et quêtes (brouillon).md ») :
- la part de chaque quête d'histoire (D01 à D26, T01 à T30 : « **Part** : x % ») ;
- les lieux à nettoyer (§4.1.1, A01 à A10) : monstres à éliminer, chef, part (et, aux Tarides, récompense) ;
- l'exploration (§4.2) : les sous-zones et leur part.
Les autres annexes (primes, contrats, défis, reliques : 25 % de la zone) sont écrites par annexes_durotar.py.

Durotar écrit la migration 074 :
- acore_world.solazeroth_v3_zone_parts (zone, genre, clé, part en centièmes de %, nom) ;
  genre 1 = quête rendue, 2 = sous-zone explorée, 3 = lieu nettoyé ;
- acore_world.solazeroth_v3_lieux_monstres (lieu, créature, nombre, sous_zones, invocations) : la troupe ; un chef
  ordinaire (Mouchette) compte pour 1. Les deux dernières colonnes viennent du lot T0 des Tarides (migration 135) :
  Durotar garde « toute la zone » et les invocations comptées ;
- acore_world.solazeroth_v3_lieux_chefs (lieu, origine, renforcé) : les chefs renforcés (copies de la migration 075),
  qui apparaissent quand la troupe est tombée et dont la mort clôt le lieu ;
- acore_characters.solazeroth_v3_lieux (guid, lieu, créature, nombre) : les monstres tués par chaque personnage.

Les Tarides écrivent la migration 140 (lot T3) : seulement les lignes de la zone 17 et les lieux 11 à 20, sans
toucher à Durotar. En plus :
- le plafond de 60 morts par lieu (point 15 du brouillon), réparti au prorata des entrées (« 60 parmi 85 ») ;
- les sous-zones de chaque lieu et les invocations ignorées (lot T0) ;
- les 7 copies renforcées des chefs (comme la migration 075, sans technique : les techniques M1 à M8 viennent avec le
  lot T4), à la puissance du chef d'histoire (décision 5) ;
- le paiement des lieux (décision 2) : acore_world.solazeroth_v3_lieux_recompenses (lieu, Marques, cuivre, éclats,
  composants), versé à la première fermeture ; acore_characters.solazeroth_v3_lieux_payes (guid, lieu).
Le serveur lit ces tables au démarrage (v3_zone.cpp). Rejouer la 074 efface les lignes de la 140 : la rejouer aussi.
"""
import os
import re
import sys

DOCUMENTS = os.path.join(os.path.expanduser("~"), "Documents", "Claude", "Sol'Azeroth")
MIGRATIONS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "sql", "migrations")

QUETE_GENRE, EXPLORATION, LIEU_GENRE = 1, 2, 3

ZONES = {
    "durotar": dict(
        histoire="Durotar — Histoire et quêtes (brouillon).md", migration="074_v3_zone_durotar", zone=14,
        prefixe="D", quete=910000, lieu=1, quetes=26, sous_zones=24,
        # Chef d'origine -> copie renforcée (migration 075_v3_chefs_renforces).
        renforces={3183: 910010, 3192: 910011, 5808: 910012, 3205: 910013, 3204: 910014}),
    "tarides": dict(
        histoire="Les Tarides — Histoire et quêtes (brouillon).md", migration="140_v3_tarides_pourcentage", zone=17,
        prefixe="T", quete=910040, lieu=11, quetes=30, sous_zones=32, plafond=60,
        # Copies créées par cette migration : Kreenig, Sarilus, Hezrul, Beaumont, Gukk'rok, Doublenattes, Lok.
        renforces={3438: 910060, 3986: 910061, 3396: 910062, 3393: 910063, 5863: 910064, 3414: 910065,
                   3435: 910066},
        # A02 : 9 des 45 Cogneurs et Acolytes du Pic ont la sous-zone 17 (la zone elle-même) en base ; ces entrées ne
        # vivent qu'au Pic, on l'ajoute pour que le compte de 45 soit atteignable sans attendre les réapparitions.
        aires_en_plus={2: "17"}),
}


def centiemes(texte):
    return round(float(texte.replace(",", ".")) * 100)


def s(texte):
    return "'" + texte.replace("\\", "\\\\").replace("'", "''") + "'"


def repartir(total, effectifs):
    """Répartit total entre les entrées au prorata de leurs effectifs (plus forts restes)."""
    somme = sum(effectifs)
    parts = [total * n / somme for n in effectifs]
    entiers = [int(p) for p in parts]
    for i in sorted(range(len(parts)), key=lambda i: entiers[i] - parts[i])[:total - sum(entiers)]:
        entiers[i] += 1
    return entiers


def monstres_du_lieu(cellule, z):
    """Troupe d'un lieu : « 26 Cogneurs (3379), ... » ou « 60 parmi 85 Tranchecrins : Sourciers (3267, 18), ... »."""
    m = re.match(r"(\d+) parmi (\d+)", cellule)
    if not m:
        return [(int(e), int(n)) for n, e in re.findall(r"(\d+) [^,(]+\((\d+)\)", cellule)]
    plafond, total = int(m.group(1)), int(m.group(2))
    entrees = [(int(e), int(n)) for e, n in re.findall(r"\((\d+), (\d+)\)", cellule)]
    if plafond != z.get("plafond") or sum(n for _, n in entrees) != total:
        raise SystemExit("Troupe inattendue : " + cellule[:60])
    return list(zip([e for e, _ in entrees], repartir(plafond, [n for _, n in entrees])))


def recompense_du_lieu(cellule, composants):
    """« 20 Marques, 1 po 20 pa, 15 éclats, 3 Cuir léger, 1 Malachite » -> (Marques, cuivre, éclats, [(objet, n)])."""
    marques = cuivre = eclats = 0
    objets = []
    for morceau in [m.strip() for m in cellule.split(",")]:
        if m := re.fullmatch(r"(\d+) Marques", morceau):
            marques = int(m.group(1))
        elif m := re.fullmatch(r"(?:(\d+) po)? ?(?:(\d+) pa)?", morceau):
            cuivre = int(m.group(1) or 0) * 10000 + int(m.group(2) or 0) * 100
        elif m := re.fullmatch(r"(\d+) éclats", morceau):
            eclats = int(m.group(1))
        elif m := re.fullmatch(r"(\d+) (.+)", morceau):
            nom = m.group(2)
            objet = composants.get(nom) or next((e for n, e in composants.items() if n.startswith(nom)), None)
            if not objet:
                raise SystemExit("Composant inconnu : " + nom)
            objets.append((objet, int(m.group(1))))
        else:
            raise SystemExit("Récompense illisible : " + morceau)
    return marques, cuivre, eclats, objets


def lire(z):
    quetes, lieux, sous_zones, aires = [], [], [], {}
    courant, section, composants = None, None, {}
    texte = open(os.path.join(DOCUMENTS, z["histoire"]), encoding="utf-8").read()
    if "plafond" in z:
        # Sous-zones de chaque lieu (§4.1.1, « Compter par sous-zone ») et identifiants des composants (§4.1).
        paragraphe = re.search(r"une colonne `sous_zones` par lieu \(([^)]+)\)", texte).group(1)
        for numero, liste in re.findall(r"A(\d\d) : ([\d et]+)", paragraphe):
            en_plus = z.get("aires_en_plus", {}).get(int(numero))
            aires[int(numero)] = ",".join(re.findall(r"\d+", liste) + ([en_plus] if en_plus else []))
        ligne = re.search(r"des composants des Tarides : (.+)", texte).group(1)
        composants = {nom.strip(): int(e) for nom, e in re.findall(r"([^,(]+) \((\d+)\)", ligne)}
    for ligne in texte.splitlines(True):
        m = re.match(r"#### %s(\d\d) — (.+)" % z["prefixe"], ligne)
        if m:
            courant = (int(m.group(1)), m.group(2).strip())
            continue
        if ligne.startswith("#### ") or ligne.startswith("### ") or ligne.startswith("## "):
            courant = None
            section = ligne.strip()
        m = re.match(r"- \*\*Part\*\* : ([\d,]+) %\.$", ligne.strip())
        if m and courant and courant[0] <= z["quetes"]:
            quetes.append((courant[0], courant[1], centiemes(m.group(1))))
        cellules = [c.strip() for c in ligne.strip().strip("|").split("|")]
        if section and section.startswith("#### 4.1.1") and re.match(r"A\d\d( \(L\d\d\))?$", cellules[0]):
            numero = int(cellules[0][1:3])
            monstres = monstres_du_lieu(cellules[4], z)
            renforce = re.search(r"\(copie de (\d+)\)", cellules[5])
            chef = re.search(r"\((\d+)", cellules[5])
            if renforce:
                renforce = (int(renforce.group(1)), z["renforces"][int(renforce.group(1))])
            elif chef:
                monstres.append((int(chef.group(1)), 1))
            recompense = recompense_du_lieu(cellules[9], composants) if composants else None
            lieux.append((numero, cellules[1], monstres, centiemes(cellules[8].rstrip(" %")), renforce,
                          aires.get(numero, ""), recompense))
        if section and section.startswith("### 4.2") and cellules[0].isdigit():
            sous_zones.append((int(cellules[0]), cellules[1], centiemes(cellules[4].rstrip(" %"))))
    return quetes, lieux, sous_zones


def parts_de(z, quetes, lieux, sous_zones):
    return ([(QUETE_GENRE, z["quete"] + n, p, titre) for n, titre, p in quetes]
            + [(EXPLORATION, zone, p, nom) for zone, nom, p in sous_zones]
            + [(LIEU_GENRE, z["lieu"] + l[0] - 1, l[3], l[1]) for l in lieux])


def verifier(z, quetes, lieux, sous_zones):
    totaux = [sum(q[2] for q in quetes), sum(x[2] for x in sous_zones), sum(l[3] for l in lieux)]
    if len([l for l in lieux if l[4]]) != len(z["renforces"]):
        raise SystemExit("Chefs renforcés inattendus")
    if (len(quetes) != z["quetes"] or len(sous_zones) != z["sous_zones"] or len(lieux) != 10
            or totaux != [5000, 600, 1900]):
        raise SystemExit("Document inattendu : %d quêtes, %d sous-zones, %d lieux, totaux %s"
                         % (len(quetes), len(sous_zones), len(lieux), totaux))


def durotar(z):
    quetes, lieux, sous_zones = lire(z)
    verifier(z, quetes, lieux, sous_zones)
    up = ["-- v3, F5e : pourcentage de Durotar. Généré par outils\\zone_durotar.py : ne pas modifier à la main.",
          "-- Parts en centièmes de % : quêtes d'histoire (50 %), exploration (6 %), lieux à nettoyer (19 %).",
          "DROP TABLE IF EXISTS acore_world.solazeroth_v3_zone_parts;",
          "CREATE TABLE acore_world.solazeroth_v3_zone_parts (zone INT UNSIGNED NOT NULL, genre TINYINT UNSIGNED NOT NULL,"
          " cle INT UNSIGNED NOT NULL, part INT UNSIGNED NOT NULL, nom VARCHAR(100) NOT NULL,"
          " PRIMARY KEY (zone, genre, cle));",
          "DROP TABLE IF EXISTS acore_world.solazeroth_v3_lieux_monstres;",
          # Lot T3 des Tarides : les colonnes du lot T0 (migration 135) sont créées ici, pour qu'un nouveau passage de la
          # 074 ne les perde pas. Durotar : toute la zone, invocations comptées.
          "CREATE TABLE acore_world.solazeroth_v3_lieux_monstres (lieu INT UNSIGNED NOT NULL, creature INT UNSIGNED NOT NULL,"
          " nombre INT UNSIGNED NOT NULL, sous_zones VARCHAR(64) NOT NULL DEFAULT '',"
          " invocations TINYINT UNSIGNED NOT NULL DEFAULT 1, PRIMARY KEY (lieu, creature));",
          "DROP TABLE IF EXISTS acore_world.solazeroth_v3_lieux_chefs;",
          "CREATE TABLE acore_world.solazeroth_v3_lieux_chefs (lieu INT UNSIGNED NOT NULL PRIMARY KEY,"
          " origine INT UNSIGNED NOT NULL, renforce INT UNSIGNED NOT NULL);",
          "CREATE TABLE IF NOT EXISTS acore_characters.solazeroth_v3_lieux (guid INT UNSIGNED NOT NULL,"
          " lieu INT UNSIGNED NOT NULL, creature INT UNSIGNED NOT NULL, nombre INT UNSIGNED NOT NULL,"
          " PRIMARY KEY (guid, lieu, creature));"]
    parts = parts_de(z, quetes, lieux, sous_zones)
    up.append("INSERT INTO acore_world.solazeroth_v3_zone_parts VALUES\n" + ",\n".join(
        "(%d, %d, %d, %d, %s)" % (z["zone"], genre, cle, p, s(nom)) for genre, cle, p, nom in parts) + ";")
    up.append("INSERT INTO acore_world.solazeroth_v3_lieux_monstres (lieu, creature, nombre) VALUES\n" + ",\n".join(
        "(%d, %d, %d)" % (z["lieu"] + l[0] - 1, e, n) for l in lieux for e, n in l[2]) + ";")
    up.append("INSERT INTO acore_world.solazeroth_v3_lieux_chefs VALUES\n" + ",\n".join(
        "(%d, %d, %d)" % (z["lieu"] + l[0] - 1, l[4][0], l[4][1]) for l in lieux if l[4]) + ";")
    down = ["-- Retire le pourcentage de Durotar. Les monstres tués pour les lieux sont perdus.",
            "DROP TABLE acore_world.solazeroth_v3_zone_parts;",
            "DROP TABLE acore_world.solazeroth_v3_lieux_monstres;",
            "DROP TABLE IF EXISTS acore_world.solazeroth_v3_lieux_chefs;",
            "DROP TABLE acore_characters.solazeroth_v3_lieux;"]
    return up, down, "%d parts (%d quêtes, %d sous-zones, %d lieux)" % (len(parts), len(quetes), len(sous_zones),
                                                                        len(lieux))


# Puissance d'un chef d'histoire à son apparition (Ramener de v3_niveau.cpp, sur la table du lot T1).
PUISSANCE_CHEF = ("LEAST(a.puissance_max, GREATEST(a.puissance_min, IF(a.origine_max <= a.origine_min,"
                  " ROUND((a.puissance_min + a.puissance_max) / 2), ROUND(a.puissance_min + (t.minlevel - a.origine_min)"
                  " * (a.puissance_max - a.puissance_min) / (a.origine_max - a.origine_min)))))")


def tarides(z):
    quetes, lieux, sous_zones = lire(z)
    verifier(z, quetes, lieux, sous_zones)
    zone, premier, dernier = z["zone"], z["lieu"], z["lieu"] + 9
    copies = sorted(z["renforces"].items(), key=lambda c: c[1])
    liste = ", ".join(str(c) for _, c in copies)
    paires = ", ".join("(%d, %d)" % c for c in copies)
    up = ["-- Lot T3 des Tarides (03/11/2026) : pourcentage des Tarides, lieux à nettoyer et leur paiement.",
          "-- Généré par outils\\zone_durotar.py tarides : ne pas modifier à la main. Ne touche pas à Durotar.",
          "-- Parts en centièmes de % : quêtes d'histoire T01 à T30 (50 %), exploration (6 %), lieux A01 à A10 (19 %).",
          "USE acore_world;", "",
          "DELETE FROM solazeroth_v3_zone_parts WHERE zone = %d;" % zone,
          "DELETE FROM solazeroth_v3_lieux_monstres WHERE lieu BETWEEN %d AND %d;" % (premier, dernier),
          "DELETE FROM solazeroth_v3_lieux_chefs WHERE lieu BETWEEN %d AND %d;" % (premier, dernier)]
    parts = parts_de(z, quetes, lieux, sous_zones)
    up.append("INSERT INTO solazeroth_v3_zone_parts VALUES\n" + ",\n".join(
        "(%d, %d, %d, %d, %s)" % (zone, genre, cle, p, s(nom)) for genre, cle, p, nom in parts) + ";")
    up.append("-- Troupes : plafond de %d morts réparti au prorata des entrées ; comptées dans les sous-zones du lieu ;"
              " invocations ignorées." % z["plafond"])
    up.append("INSERT INTO solazeroth_v3_lieux_monstres (lieu, creature, nombre, sous_zones, invocations) VALUES\n"
              + ",\n".join("(%d, %d, %d, %s, 0)" % (premier + l[0] - 1, e, n, s(l[5])) for l in lieux for e, n in l[2])
              + ";")
    up.append("INSERT INTO solazeroth_v3_lieux_chefs VALUES\n" + ",\n".join(
        "(%d, %d, %d)" % (premier + l[0] - 1, l[4][0], l[4][1]) for l in lieux if l[4]) + ";")
    up += ["",
           "-- Chefs renforcés : copies des chefs d'histoire, comme la migration 075 (mêmes statistiques, butin, SmartAI,",
           "-- textes et sorts ; leur mort compte pour l'original). Pas de technique en plus : M1 à M8 viennent au lot T4.",
           "DELETE FROM creature_template WHERE entry IN (%s);" % liste,
           "DELETE FROM creature_template_model WHERE CreatureID IN (%s);" % liste,
           "DELETE FROM creature_template_locale WHERE entry IN (%s);" % liste,
           "DELETE FROM creature_template_spell WHERE CreatureID IN (%s);" % liste,
           "DELETE FROM creature_text WHERE CreatureID IN (%s);" % liste,
           "DELETE FROM smart_scripts WHERE entryorguid IN (%s) AND source_type = 0;" % liste,
           "DROP TEMPORARY TABLE IF EXISTS solazeroth_copie;",
           "CREATE TEMPORARY TABLE solazeroth_copie (origine INT UNSIGNED NOT NULL, copie INT UNSIGNED NOT NULL);",
           "INSERT INTO solazeroth_copie VALUES %s;" % paires,
           "DROP TEMPORARY TABLE IF EXISTS solazeroth_t;",
           "CREATE TEMPORARY TABLE solazeroth_t SELECT t.* FROM creature_template t JOIN solazeroth_copie c ON c.origine = t.entry;",
           "UPDATE solazeroth_t t JOIN solazeroth_copie c ON c.origine = t.entry",
           "    SET t.KillCredit1 = t.entry, t.subname = 'Chef renforcé', t.pickpocketloot = 0, t.entry = c.copie;",
           "INSERT INTO creature_template SELECT * FROM solazeroth_t;",
           "DROP TEMPORARY TABLE solazeroth_t;"]
    for table, colonne in (("creature_template_model", "CreatureID"), ("creature_template_spell", "CreatureID"),
                           ("creature_text", "CreatureID")):
        up += ["CREATE TEMPORARY TABLE solazeroth_t SELECT x.* FROM %s x JOIN solazeroth_copie c ON c.origine = x.%s;"
               % (table, colonne),
               "UPDATE solazeroth_t x JOIN solazeroth_copie c ON c.origine = x.%s SET x.%s = c.copie;" % (colonne, colonne),
               "INSERT INTO %s SELECT * FROM solazeroth_t;" % table,
               "DROP TEMPORARY TABLE solazeroth_t;"]
    up += ["INSERT INTO creature_template_locale (entry, locale, Name, Title, VerifiedBuild)",
           "    SELECT c.copie, 'frFR', COALESCE(NULLIF(l.Name, ''), t.name), 'Chef renforcé', 0",
           "    FROM solazeroth_copie c JOIN creature_template t ON t.entry = c.origine",
           "    LEFT JOIN creature_template_locale l ON l.entry = c.origine AND l.locale = 'frFR';",
           "CREATE TEMPORARY TABLE solazeroth_t SELECT s.* FROM smart_scripts s JOIN solazeroth_copie c ON c.origine = s.entryorguid",
           "    WHERE s.source_type = 0;",
           "UPDATE solazeroth_t s JOIN solazeroth_copie c ON c.origine = s.entryorguid SET s.entryorguid = c.copie;",
           "INSERT INTO smart_scripts SELECT * FROM solazeroth_t;",
           "DROP TEMPORARY TABLE solazeroth_t;",
           "",
           "-- Puissance (décision 5) : celle du chef d'histoire à son apparition (table du lot T1), fixée par entrée ;",
           "-- la correction de la courbe du chef d'histoire le suit.",
           "DELETE FROM solazeroth_v3_puissance_entrees WHERE entree IN (%s);" % liste,
           "DELETE FROM solazeroth_v3_courbe_entrees WHERE entree IN (%s);" % liste,
           "INSERT INTO solazeroth_v3_puissance_entrees (entree, zone, fixe, secteur, origine_min, origine_max,"
           " puissance_min, puissance_max)",
           "    SELECT c.copie, %d, 1, COALESCE(e.secteur, 0), t.minlevel, t.minlevel, %s, %s"
           % (zone, PUISSANCE_CHEF, PUISSANCE_CHEF),
           "    FROM solazeroth_copie c JOIN creature_template t ON t.entry = c.origine",
           "    JOIN creature o ON o.id = c.origine JOIN solazeroth_v3_puissance_apparitions a ON a.guid = o.guid",
           "    LEFT JOIN solazeroth_v3_puissance_entrees e ON e.entree = c.origine;",
           "INSERT INTO solazeroth_v3_courbe_entrees (entree, vie, degats)",
           "    SELECT c.copie, x.vie, x.degats FROM solazeroth_copie c JOIN solazeroth_v3_courbe_entrees x ON x.entree = c.origine;",
           "DROP TEMPORARY TABLE solazeroth_copie;",
           "",
           "-- Paiement des lieux (décision 2), à la première fermeture : Marques, cuivre, éclats et composants (objet:nombre).",
           "-- Barème provisoire du brouillon, à régler au calibrage final. Durotar n'a pas de ligne : rien ne change pour lui.",
           "CREATE TABLE IF NOT EXISTS solazeroth_v3_lieux_recompenses (lieu INT UNSIGNED NOT NULL PRIMARY KEY,"
           " marques INT UNSIGNED NOT NULL, cuivre INT UNSIGNED NOT NULL, eclats INT UNSIGNED NOT NULL,"
           " composants VARCHAR(128) NOT NULL DEFAULT '');",
           "DELETE FROM solazeroth_v3_lieux_recompenses WHERE lieu BETWEEN %d AND %d;" % (premier, dernier)]
    up.append("INSERT INTO solazeroth_v3_lieux_recompenses VALUES\n" + ",\n".join(
        "(%d, %d, %d, %d, %s)" % (premier + l[0] - 1, l[6][0], l[6][1], l[6][2],
                                  s(",".join("%d:%d" % o for o in l[6][3]))) for l in lieux) + ";")
    up.append("CREATE TABLE IF NOT EXISTS acore_characters.solazeroth_v3_lieux_payes (guid INT UNSIGNED NOT NULL,"
              " lieu INT UNSIGNED NOT NULL, PRIMARY KEY (guid, lieu));")
    down = ["-- Retire le pourcentage des Tarides, leurs chefs renforcés et le paiement des lieux. Durotar ne bouge pas.",
            "USE acore_world;",
            "DELETE FROM solazeroth_v3_zone_parts WHERE zone = %d;" % zone,
            "DELETE FROM solazeroth_v3_lieux_monstres WHERE lieu BETWEEN %d AND %d;" % (premier, dernier),
            "DELETE FROM solazeroth_v3_lieux_chefs WHERE lieu BETWEEN %d AND %d;" % (premier, dernier),
            "DELETE FROM acore_characters.solazeroth_v3_lieux WHERE lieu BETWEEN %d AND %d;" % (premier, dernier),
            "DELETE FROM creature_template WHERE entry IN (%s);" % liste,
            "DELETE FROM creature_template_model WHERE CreatureID IN (%s);" % liste,
            "DELETE FROM creature_template_locale WHERE entry IN (%s);" % liste,
            "DELETE FROM creature_template_spell WHERE CreatureID IN (%s);" % liste,
            "DELETE FROM creature_text WHERE CreatureID IN (%s);" % liste,
            "DELETE FROM smart_scripts WHERE entryorguid IN (%s) AND source_type = 0;" % liste,
            "DELETE FROM solazeroth_v3_puissance_entrees WHERE entree IN (%s);" % liste,
            "DELETE FROM solazeroth_v3_courbe_entrees WHERE entree IN (%s);" % liste,
            "DROP TABLE IF EXISTS solazeroth_v3_lieux_recompenses;",
            "DROP TABLE IF EXISTS acore_characters.solazeroth_v3_lieux_payes;"]
    troupes = ", ".join("A%02d %d" % (l[0], sum(n for _, n in l[2]) + (1 if l[4] else 0)) for l in lieux)
    return up, down, "%d parts (%d quêtes, %d sous-zones, %d lieux : %s)" % (
        len(parts), len(quetes), len(sous_zones), len(lieux), troupes)


def main():
    nom = sys.argv[1] if len(sys.argv) > 1 else "durotar"
    if nom not in ZONES:
        raise SystemExit("Usage : py zone_durotar.py [durotar|tarides]")
    z = ZONES[nom]
    up, down, bilan = (durotar if nom == "durotar" else tarides)(z)
    chemin = os.path.join(MIGRATIONS, z["migration"])
    for suffixe, contenu in ((".up.sql", up), (".down.sql", down)):
        with open(chemin + suffixe, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(contenu) + "\n")
    print(bilan, ": migration", z["migration"][:3], "écrite.")


if __name__ == "__main__":
    main()
