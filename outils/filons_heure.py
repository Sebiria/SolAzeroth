"""Audit du jeu, lot 7 (02/11/2026) : estimation des filons minés par heure à pied (choix de l'utilisateur : « estimer
+ compteur » ; la mesure réelle vient de « .filons » en jeu, v3_filons.cpp).

C'est ce rythme qui fixe le coût des pierres taillées des rangs 4 et 5 (simulation_rangs.py, simulation_zones.py).

Modèle, d'après la base du monde :
- les filons de la zone (gameobject), regroupés en pools (pool_gameobject) : seuls max_limit d'un pool sont là à la
  fois ; un filon miné disparaît, et au bout de son délai (spawntimesecs) le pool en fait apparaître un au hasard parmi
  ses emplacements libres. Un filon hors pool réapparaît à sa place ;
- le joueur part de son point de départ, va toujours au filon présent le plus proche (à vol d'oiseau × DETOUR pour le
  relief et les monstres), à VITESSE mètres par seconde, et passe RECOLTE secondes par filon.
On joue une heure, TIRAGES fois, et on donne la moyenne. C'est un plafond : un joueur qui fait aussi ses quêtes en mine
bien moins (voir --filons de simulation_rangs.py, par % de zone).
Lancé avec py filons_heure.py.
"""
import math
import random
import subprocess

import gabarit_zone

VITESSE = 7.0           # course à pied (pas de monture avant le palier 10 du rang d'aventurier)
MONTURE = 1.6           # monture à 60 %
DETOUR = 1.4
RECOLTE = 5.0           # sort de minage et butin
DUREE = 3600.0
TIRAGES = 40
CAS = [  # zone, filons (entrées de gameobject_template), départ (x, y)
    (gabarit_zone.DUROTAR, [1731], (300.0, -4730.0)),                              # Razor Hill
    (gabarit_zone.TARIDES, [1731, 1732, 1733, 3763, 3764, 103711, 103713, 105569], (-450.0, -2650.0)),  # la Croisée
]


def sql(requete):
    r = subprocess.run([gabarit_zone.MYSQL, "--defaults-extra-file=" + gabarit_zone.CNF, "-N", "-B", "acore_world",
                        "-e", requete], capture_output=True, check=True)
    return [l.split("\t") for l in r.stdout.decode("utf-8").splitlines()]


def lire(zone, entrees):
    lignes = sql(f"SELECT g.guid, g.position_x, g.position_y, g.spawntimesecs, IFNULL(pg.pool_entry, 0), "
                 f"IFNULL(pt.max_limit, 1) FROM gameobject g LEFT JOIN pool_gameobject pg ON pg.guid = g.guid "
                 f"LEFT JOIN pool_template pt ON pt.entry = pg.pool_entry "
                 f"WHERE g.zoneId = {zone} AND g.id IN ({','.join(map(str, entrees))})")
    filons = [{"x": float(x), "y": float(y), "delai": int(d), "pool": int(p) or -int(g), "max": int(m)}
              for g, x, y, d, p, m in lignes]
    return filons


def heure(filons, depart, vitesse, rng):
    pools = {}
    for i, f in enumerate(filons):
        pools.setdefault(f["pool"], {"max": f["max"], "lieux": []})["lieux"].append(i)
    presents = set()
    for p in pools.values():
        presents.update(rng.sample(p["lieux"], min(p["max"], len(p["lieux"]))))
    attente = []   # (instant, pool) : un filon du pool réapparaît
    t, (x, y), mines = 0.0, depart, 0
    while True:
        for instant, pool in [a for a in attente if a[0] <= t]:
            attente.remove((instant, pool))
            libres = [i for i in pools[pool]["lieux"] if i not in presents]
            presents.add(rng.choice(libres))
        if not presents:
            t = min(a[0] for a in attente)
            continue
        i = min(presents, key=lambda k: (filons[k]["x"] - x) ** 2 + (filons[k]["y"] - y) ** 2)
        f = filons[i]
        t += math.hypot(f["x"] - x, f["y"] - y) * DETOUR / vitesse + RECOLTE
        if t > DUREE:
            return mines
        x, y = f["x"], f["y"]
        mines += 1
        presents.discard(i)
        attente.append((t + f["delai"], f["pool"]))


def main():
    rng = random.Random(7)
    for zone, entrees, depart in CAS:
        filons = lire(zone["zone"], entrees)
        actifs = sum(p["max"] for p in {f["pool"]: f for f in filons}.values())
        print(f"{zone['nom']} : {len(filons)} emplacements de filon, {actifs} présents à la fois, réapparition "
              f"{min(f['delai'] for f in filons) // 60} à {max(f['delai'] for f in filons) // 60} min")
        for nom, vitesse in (("à pied", VITESSE), ("monture à 60 %", VITESSE * MONTURE)):
            n = [heure(filons, depart, vitesse, rng) for _ in range(TIRAGES)]
            print(f"  {nom:15} : {sum(n) / len(n):5.1f} filons par heure (de {min(n)} à {max(n)})")


if __name__ == "__main__":
    main()
