"""Audit du jeu, lot 5 (02/11/2026) : garde-fou du rang d'aventurier. Points maximum, lus dans la base et dans
v3_aventurier.cpp comme le serveur les compte, de Durotar à 100 % et du Gouffre de Ragefeu en difficulté 1 ; on vérifie
que les paliers des modes de zone (5 et 9) et de la monte (10) restent atteignables sans farmer les difficultés.
Les objectifs d'artisan et de la semaine ne comptent pas : ils s'ajoutent.

py test_paliers_v3.py        (code de sortie 1 si un palier n'est plus atteignable)
"""
import os
import re
import subprocess
import sys

ICI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ICI)
import montures_v3

MYSQL = r"C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe"
CNF = r"C:\SolAzeroth\config\mysql-acore.cnf"
SOURCE = os.path.join(ICI, "..", "modules", "mod-solazeroth", "src", "v3_aventurier.cpp")
DUROTAR, GOUFFRE = 14, 4                      # zone ; donjon LFG (instance_encounters.lastEncounterDungeon)
QUETE, EXPLORATION, LIEU, ANNEXE, RELIQUE, MEDAILLE_OR, DONJON, ZONE_60, ZONE_100 = range(1, 10)
VERIFIES = {5: "mode difficile", 9: "mode cauchemar", 10: "monte"}


def sql(requete):
    r = subprocess.run([MYSQL, "--defaults-extra-file=" + CNF, "-N", "-B", "acore_world", "-e", requete],
                       capture_output=True, check=True)
    return [l.split("\t") for l in r.stdout.decode("utf-8").splitlines()]


def points_de_base():
    texte = open(SOURCE, encoding="utf-8").read()
    return [int(x) for x in re.search(r"uint32 const POINTS\[\] = \{([^}]*)\}", texte).group(1).split(",")]


def puissance_haute(zone):
    """Comme v3_niveau.cpp : 90e centile des niveaux des monstres ordinaires de la zone."""
    niveaux = sorted(int(n) for (n,) in sql("SELECT t.minlevel FROM creature c JOIN creature_template t ON t.entry = c.id "
                     "WHERE c.zoneId = %d AND t.npcflag = 0 AND t.`rank` = 0 AND t.type <> 8" % zone))
    return niveaux[int(0.90 * (len(niveaux) - 1))]


def gain(points, genre, puissance, nombre=1):
    return nombre * round(points[genre] * (1 + puissance / 100))


def main():
    points = points_de_base()
    haute = puissance_haute(DUROTAR)
    parts = {int(g): int(n) for g, n in sql("SELECT genre, COUNT(*) FROM solazeroth_v3_zone_parts WHERE zone = %d "
                                             "GROUP BY genre" % DUROTAR)}
    ors = int(sql("SELECT COUNT(*) FROM solazeroth_v3_annexes a JOIN solazeroth_v3_zone_parts p ON p.genre = 4 AND "
                  "p.cle = a.quete AND p.zone = %d WHERE a.`or` > 0" % DUROTAR)[0][0])
    boss = int(sql("SELECT MIN(t.minlevel) FROM instance_encounters i JOIN creature_template t ON t.entry = i.creditEntry "
                   "WHERE i.lastEncounterDungeon = %d" % GOUFFRE)[0][0])
    zone = sum(gain(points, g, haute, n) for g, n in parts.items())
    zone += gain(points, MEDAILLE_OR, haute, ors) + gain(points, ZONE_60, haute) + gain(points, ZONE_100, haute)
    donjon = gain(points, DONJON, boss)
    total = zone + donjon
    print("Durotar (puissance haute %d) : %d points ; Gouffre en difficulté 1 (boss %d) : %d ; total %d"
          % (haute, zone, boss, donjon, total))
    erreurs = 0
    for palier, nom in VERIFIES.items():
        seuil = montures_v3.PALIERS[palier - 1][0]
        ok = total >= seuil
        erreurs += not ok
        print("   palier %2d (%s) à %5d points : %s (marge %+d)" % (palier, nom, seuil, "ok" if ok else "HORS D'ATTEINTE",
                                                                    total - seuil))
    return 1 if erreurs else 0


if __name__ == "__main__":
    sys.exit(main())
