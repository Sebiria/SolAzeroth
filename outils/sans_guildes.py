"""Sol'Azeroth v3, F5d (31/10/2026) : jeu sans guildes ni banques, Durotar sans PNJ d'ambiance, sans hauts faits natifs.

Demande de l'utilisateur : seul le niveau d'aventurier se partage entre les personnages ; plus de banque de joueur
ni de guilde. Écrit la migration 065 :
- banquiers, coffres et créateurs de guilde, dessinateurs de tabard : drapeaux retirés (creature_template et creature) ;
- coffres de guilde (gameobject de type 34) : cachés par la phase ;
- Durotar (zone 14) : PNJ d'ambiance cachés par la phase hors des villages (« pour l'instant »). Un PNJ d'ambiance est
  un humanoïde non hostile sans service ni rôle de quête ni script ; un village, les abords (RAYON mètres) d'un PNJ de
  service (marchand, maître, aubergiste, maître de vol) ;
- hauts faits natifs : tous leurs critères désactivés (table disables, type 4), progression des personnages effacée.
  Le client ne garde que les hauts faits Sol'Azeroth : outils\\hauts_faits_natifs.py (DBC du client).
Tout ce qui est caché ou retiré est gardé dans des tables solazeroth_v3_* : la migration descendante le remet.
"""
import math
import os
import subprocess

import dbc

MYSQL = r"C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe"
IDENTIFIANTS = r"C:\SolAzeroth\config\mysql-acore.cnf"
DBC_SERVEUR = r"C:\SolAzeroth\data\dbc"
MIGRATION = r"C:\SolAzeroth\sql\migrations\065_v3_sans_guildes"

PHASE_CACHEE = 1073741824          # aucune phase de joueur
DRAPEAUX_GUILDE = 131072 | 262144 | 524288 | 8388608   # banquier, créateur de guilde, tabard, coffre de guilde
SERVICES = 16 | 128 | 8192 | 65536                    # maître, marchand, maître de vol, aubergiste
HUMANOIDE = 7
JOUEURS, HORDE = 1, 4               # masques de groupe de FactionTemplate.dbc
RAYON = 90.0
BASE_HF, BASE_CRITERE = 9000, 16000
COMMENTAIRE_HF = "Sol'Azeroth v3 : haut fait natif"


def requete(sql):
    sortie = subprocess.run([MYSQL, "--defaults-extra-file=" + IDENTIFIANTS, "--default-character-set=utf8mb4", "-N", "-B",
                             "acore_world", "-e", sql], capture_output=True, check=True).stdout.decode("utf-8")
    return [ligne.split("\t") for ligne in sortie.splitlines()]


def factions_non_hostiles():
    ft = dbc.Dbc.ouvrir(os.path.join(DBC_SERVEUR, "FactionTemplate.dbc"))
    return {e[0] for e in ft.enregistrements if not e[5] & (JOUEURS | HORDE)}


def ambiance():
    amies = factions_non_hostiles()
    services = [(float(x), float(y)) for x, y in requete(
        "SELECT c.position_x, c.position_y FROM creature c JOIN creature_template t ON t.entry = c.id "
        "WHERE c.map = 1 AND c.zoneId = 14 AND ((t.npcflag | c.npcflag) & %d)" % SERVICES)]
    lignes = requete(
        "SELECT c.guid, t.faction, c.position_x, c.position_y FROM creature c JOIN creature_template t ON t.entry = c.id "
        "WHERE c.map = 1 AND c.zoneId = 14 AND t.type = %d AND t.npcflag = 0 AND c.npcflag = 0 AND c.id < 900000 "
        "AND IFNULL(t.ScriptName, '') = '' AND IFNULL(c.ScriptName, '') = '' AND c.phaseMask <> %d "
        "AND c.guid NOT IN (SELECT guid FROM game_event_creature) "
        "AND c.id NOT IN (SELECT id FROM creature_queststarter) AND c.id NOT IN (SELECT id FROM creature_questender) "
        "AND c.id NOT IN (SELECT KillCredit1 FROM creature_template) AND c.id NOT IN (SELECT KillCredit2 FROM creature_template) "
        "AND c.id NOT IN (SELECT RequiredNpcOrGo1 FROM quest_template) AND c.id NOT IN (SELECT RequiredNpcOrGo2 FROM quest_template) "
        "AND c.id NOT IN (SELECT RequiredNpcOrGo3 FROM quest_template) AND c.id NOT IN (SELECT RequiredNpcOrGo4 FROM quest_template)"
        % (HUMANOIDE, PHASE_CACHEE))
    caches = []
    for guid, faction, x, y in lignes:
        if int(faction) not in amies:
            continue
        x, y = float(x), float(y)
        if any(math.hypot(x - sx, y - sy) <= RAYON for sx, sy in services):
            continue
        caches.append(int(guid))
    return caches


def criteres_natifs():
    crit = dbc.Dbc.ouvrir(os.path.join(DBC_SERVEUR, "Achievement_Criteria.dbc"))
    return sorted(e[0] for e in crit.enregistrements if e[0] < BASE_CRITERE)


def liste(valeurs):
    return ", ".join(str(v) for v in valeurs)


def main():
    caches = ambiance()
    criteres = criteres_natifs()
    up = ["-- Sol'Azeroth v3, F5d : sans guildes ni banques, Durotar sans PNJ d'ambiance, sans hauts faits natifs.",
          "-- Généré par outils\\sans_guildes.py : ne pas modifier à la main.",
          "USE acore_world;",
          "",
          "-- Banquiers, guildes, tabards : drapeaux retirés (sauvegarde pour la migration descendante).",
          "CREATE TABLE IF NOT EXISTS solazeroth_v3_drapeaux_origine (genre VARCHAR(8) NOT NULL, cle INT UNSIGNED NOT NULL,"
          " npcflag INT UNSIGNED NOT NULL, PRIMARY KEY (genre, cle));",
          "INSERT IGNORE INTO solazeroth_v3_drapeaux_origine SELECT 'modele', entry, npcflag FROM creature_template"
          " WHERE npcflag & %d;" % DRAPEAUX_GUILDE,
          "INSERT IGNORE INTO solazeroth_v3_drapeaux_origine SELECT 'apparition', guid, npcflag FROM creature"
          " WHERE npcflag & %d;" % DRAPEAUX_GUILDE,
          "UPDATE creature_template SET npcflag = npcflag & ~%d WHERE npcflag & %d;" % (DRAPEAUX_GUILDE, DRAPEAUX_GUILDE),
          "UPDATE creature SET npcflag = npcflag & ~%d WHERE npcflag & %d;" % (DRAPEAUX_GUILDE, DRAPEAUX_GUILDE),
          "",
          "-- Coffres de guilde et PNJ d'ambiance de Durotar : cachés par la phase.",
          "CREATE TABLE IF NOT EXISTS solazeroth_v3_phases_origine (genre VARCHAR(8) NOT NULL, guid INT UNSIGNED NOT NULL,"
          " phaseMask INT UNSIGNED NOT NULL, PRIMARY KEY (genre, guid));",
          "INSERT IGNORE INTO solazeroth_v3_phases_origine SELECT 'objet', g.guid, g.phaseMask FROM gameobject g"
          " JOIN gameobject_template t ON t.entry = g.id WHERE t.type = 34;",
          "UPDATE gameobject g JOIN gameobject_template t ON t.entry = g.id SET g.phaseMask = %d WHERE t.type = 34;" % PHASE_CACHEE]
    if caches:
        up += ["INSERT IGNORE INTO solazeroth_v3_phases_origine SELECT 'pnj', guid, phaseMask FROM creature"
               " WHERE guid IN (%s);" % liste(caches),
               "UPDATE creature SET phaseMask = %d WHERE guid IN (%s);" % (PHASE_CACHEE, liste(caches))]
    up += ["",
           "-- Hauts faits natifs : critères désactivés, progression effacée.",
           "INSERT IGNORE INTO disables (sourceType, entry, flags, params_0, params_1, comment) VALUES"]
    up.append(",\n".join("(4, %d, 0, '', '', '%s')" % (c, COMMENTAIRE_HF.replace("'", "''")) for c in criteres) + ";")
    up += ["DELETE FROM acore_characters.character_achievement WHERE achievement < %d;" % BASE_HF,
           "DELETE FROM acore_characters.character_achievement_progress WHERE criteria < %d;" % BASE_CRITERE]

    down = ["-- Remet banquiers, guildes, coffres, PNJ d'ambiance et hauts faits natifs (la progression effacée ne revient pas).",
            "USE acore_world;",
            "UPDATE creature_template t JOIN solazeroth_v3_drapeaux_origine o ON o.genre = 'modele' AND o.cle = t.entry"
            " SET t.npcflag = o.npcflag;",
            "UPDATE creature c JOIN solazeroth_v3_drapeaux_origine o ON o.genre = 'apparition' AND o.cle = c.guid"
            " SET c.npcflag = o.npcflag;",
            "UPDATE gameobject g JOIN solazeroth_v3_phases_origine o ON o.genre = 'objet' AND o.guid = g.guid"
            " SET g.phaseMask = o.phaseMask;",
            "UPDATE creature c JOIN solazeroth_v3_phases_origine o ON o.genre = 'pnj' AND o.guid = c.guid"
            " SET c.phaseMask = o.phaseMask;",
            "DROP TABLE solazeroth_v3_drapeaux_origine;",
            "DROP TABLE solazeroth_v3_phases_origine;",
            "DELETE FROM disables WHERE sourceType = 4 AND comment = '%s';" % COMMENTAIRE_HF.replace("'", "''")]
    for suffixe, lignes in ((".up.sql", up), (".down.sql", down)):
        with open(MIGRATION + suffixe, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(lignes) + "\n")
    print(len(caches), "PNJ d'ambiance cachés,", len(criteres), "critères de hauts faits natifs désactivés : migration 065 écrite.")


if __name__ == "__main__":
    main()
