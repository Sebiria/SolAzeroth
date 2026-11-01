"""v3 (01/11/2026, choix de l'utilisateur : « puissance abaissée ») : calibrage du Gouffre de Ragefeu.

À la puissance d'origine (13 à 16), même des monstres ordinaires restaient imbattables en packs pour une fiche de fin de
Durotar (puissance 9,7 à 11,6), et les boss à 0 %. Désormais :
- les monstres du Gouffre passent à la puissance 10 et 11, ordinaires (rang 0), sauf les Massacreurs de la Lame
  brûlante, élites allégés qui mènent les packs ; les boss passent à la puissance 12 ;
- leur vie et leurs dégâts (HealthModifier, DamageModifier) sont réglés par simulation : la fiche de référence (la plus
  forte des journaux, puissance 9,7, Repos et potion rang 2), vue comme celle de 60 % de Durotar, gagne environ CIBLE %
  de ses combats ; la même avec un rang d'objet de plus (fin de Durotar) doit dépasser SEREIN % ;
- les packs (apparitions à moins de RAYON m les unes des autres) gardent 2 monstres au plus : les autres sont retirés
  (gardés pour la migration inverse).

py gouffre_v3.py  (écrit la migration 102 et affiche les réglages)
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import simulation_camp as camp
import simulation_combat as sim
import simulation_modes as modes
from quetes_durotar import sql

MIGRATION = r"C:\SolAzeroth\sql\migrations\102_v3_gouffre_calibre"
GOUFFRE = 389
ORDINAIRES = {11318: (10, 11), 11319: (10, 11), 11320: (10, 10), 11321: (10, 10), 11322: (10, 11), 11324: (10, 11)}
CHEF = 11323                     # Massacreur de la Lame brûlante : élite allégé, chef de pack
CHEF_NIVEAU = (11, 11)
BOSS = {11517: 12, 11518: 12, 11519: 12, 11520: 12}
RAYON, PAR_PACK = 12.0, 2
CIBLE, SEREIN = 70, 95
POTION = (2, 35, 1, 10)
N = 300


def monstre(entree, niveau, vie, degats):
    """Le monstre à ce niveau, avec ces modificateurs à la place des siens."""
    m = sim.monstre_depuis_base(entree, niveau)
    origine = sql("SELECT HealthModifier, DamageModifier FROM acore_world.creature_template WHERE entry = %d" % entree)[0]
    h0, d0 = float(origine[0]), float(origine[1])
    m.vie = max(1, round(m.vie * vie / h0))
    m.bas, m.haut = max(1, round(m.bas * degats / d0)), max(1, round(m.haut * degats / d0))
    return m


def regler(taux, bas=0.1, haut=4.0):
    """Le facteur (vie et dégâts) qui donne CIBLE % de victoires ; taux(k) décroît avec k."""
    for _ in range(14):
        k = (bas + haut) / 2
        if taux(k) > CIBLE:
            bas = k
        else:
            haut = k
    return round((bas + haut) / 2, 2)


def packs(apparitions):
    parent = list(range(len(apparitions)))

    def racine(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a
    for a in range(len(apparitions)):
        for b in range(a + 1, len(apparitions)):
            if math.dist(apparitions[a][2:], apparitions[b][2:]) <= RAYON:
                parent[racine(a)] = racine(b)
    groupes = {}
    for a, ap in enumerate(apparitions):
        groupes.setdefault(racine(a), []).append(ap)
    return list(groupes.values())


def main():
    reference = max(camp.fiches(), key=lambda f: f.puissance)
    j60 = camp.repos(reference, 5)
    j100 = camp.repos(modes.rangs(reference, 1), 5)
    print("Fiche de référence : %s" % reference)

    # Ordinaires : réglés en pack de 2, au niveau le plus haut de chacun, avec le suivant de la liste.
    liste = list(ORDINAIRES)

    def paires(j, k):
        return sum(sim.simuler_groupe(j, [monstre(e, ORDINAIRES[e][1], k, k),
                                          monstre(liste[(i + 1) % len(liste)], ORDINAIRES[liste[(i + 1) % len(liste)]][1],
                                                  k, k)], N)["victoire"] for i, e in enumerate(liste)) / len(liste)
    k_ord = regler(lambda k: paires(j60, k))
    print("Ordinaires : vie et dégâts x %.2f ; paires : %.0f %% (60 %%), %.0f %% (fin de zone)"
          % (k_ord, paires(j60, k_ord), paires(j100, k_ord)))

    # Chef de pack : seul, puis avec un ordinaire.
    def chef(j, k, avec=False):
        groupe = [monstre(CHEF, CHEF_NIVEAU[1], k, k)] + ([monstre(11318, 11, k_ord, k_ord)] if avec else [])
        if avec:
            return sim.simuler_groupe(j, groupe, N)["victoire"]
        return sim.simuler(j, groupe[0], N, potion=POTION)["victoire"]
    k_chef = regler(lambda k: chef(j60, k, True))
    print("Chef (Massacreur) : x %.2f ; avec un ordinaire : %.0f %% / %.0f %% ; seul : %.0f %% / %.0f %%"
          % (k_chef, chef(j60, k_chef, True), chef(j100, k_chef, True), chef(j60, k_chef), chef(j100, k_chef)))

    # Boss : seuls.
    k_boss = {}
    for e, niveau in BOSS.items():
        k_boss[e] = regler(lambda k: sim.simuler(j60, monstre(e, niveau, k, k), N, potion=POTION)["victoire"])
        t60 = sim.simuler(j60, monstre(e, niveau, k_boss[e], k_boss[e]), N, potion=POTION)["victoire"]
        t100 = sim.simuler(j100, monstre(e, niveau, k_boss[e], k_boss[e]), N, potion=POTION)["victoire"]
        print("Boss %d : x %.2f ; %.0f %% / %.0f %%%s" % (e, k_boss[e], t60, t100, "" if t100 >= SEREIN else "  (< %d %%)" % SEREIN))

    # Packs de 2 au plus : on garde le chef s'il y en a un, puis les plus proches du centre.
    apparitions = [(int(g), int(i), float(x), float(y), float(z)) for g, i, x, y, z in sql(
        "SELECT guid, id, position_x, position_y, position_z FROM acore_world.creature WHERE map = %d AND id IN (%s)"
        % (GOUFFRE, ", ".join(map(str, list(ORDINAIRES) + [CHEF]))))]
    retirees = []
    for groupe in packs(apparitions):
        cx = sum(a[2] for a in groupe) / len(groupe)
        cy = sum(a[3] for a in groupe) / len(groupe)
        groupe.sort(key=lambda a: (a[1] != CHEF, math.hypot(a[2] - cx, a[3] - cy)))
        retirees += [a[0] for a in groupe[PAR_PACK:]]
    print("Apparitions : %d, dont %d retirées (packs de %d au plus, rayon %.0f m)"
          % (len(apparitions), len(retirees), PAR_PACK, RAYON))

    entrees = list(ORDINAIRES) + [CHEF] + list(BOSS)
    liste_sql = ", ".join(map(str, entrees))
    guids = ", ".join(map(str, retirees))
    up = ["-- v3 (01/11/2026) : calibrage du Gouffre de Ragefeu (puissance abaissée, packs de 2). Généré par",
          "-- outils\\gouffre_v3.py : ne pas modifier à la main.",
          "USE acore_world;",
          "CREATE TABLE IF NOT EXISTS solazeroth_v3_gouffre_origine SELECT entry, minlevel, maxlevel, `rank`, "
          "HealthModifier, DamageModifier FROM creature_template WHERE entry IN (%s);" % liste_sql]
    for e, (bas, haut) in ORDINAIRES.items():
        up.append("UPDATE creature_template SET minlevel = %d, maxlevel = %d, `rank` = 0, HealthModifier = %.2f, "
                  "DamageModifier = %.2f WHERE entry = %d;" % (bas, haut, k_ord, k_ord, e))
    up.append("UPDATE creature_template SET minlevel = %d, maxlevel = %d, `rank` = 1, HealthModifier = %.2f, "
              "DamageModifier = %.2f WHERE entry = %d;" % (CHEF_NIVEAU[0], CHEF_NIVEAU[1], k_chef, k_chef, CHEF))
    for e, niveau in BOSS.items():
        up.append("UPDATE creature_template SET minlevel = %d, maxlevel = %d, HealthModifier = %.2f, "
                  "DamageModifier = %.2f WHERE entry = %d;" % (niveau, niveau, k_boss[e], k_boss[e], e))
    if retirees:
        up += ["CREATE TABLE IF NOT EXISTS solazeroth_v3_gouffre_apparitions SELECT * FROM creature WHERE guid IN (%s);"
               % guids,
               "CREATE TABLE IF NOT EXISTS solazeroth_v3_gouffre_apparitions_addon SELECT * FROM creature_addon "
               "WHERE guid IN (%s);" % guids,
               "DELETE FROM creature_addon WHERE guid IN (%s);" % guids,
               "DELETE FROM creature WHERE guid IN (%s);" % guids]
    up.append("")
    down = ["-- Rend au Gouffre de Ragefeu ses monstres d'origine.",
            "USE acore_world;",
            "UPDATE creature_template t JOIN solazeroth_v3_gouffre_origine o ON o.entry = t.entry SET t.minlevel = "
            "o.minlevel, t.maxlevel = o.maxlevel, t.`rank` = o.`rank`, t.HealthModifier = o.HealthModifier, "
            "t.DamageModifier = o.DamageModifier;",
            "DROP TABLE solazeroth_v3_gouffre_origine;"]
    if retirees:
        down += ["INSERT IGNORE INTO creature SELECT * FROM solazeroth_v3_gouffre_apparitions;",
                 "INSERT IGNORE INTO creature_addon SELECT * FROM solazeroth_v3_gouffre_apparitions_addon;",
                 "DROP TABLE solazeroth_v3_gouffre_apparitions, solazeroth_v3_gouffre_apparitions_addon;"]
    down.append("")
    for suffixe, lignes in ((".up.sql", up), (".down.sql", down)):
        with open(MIGRATION + suffixe, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(lignes))
    print("Migration 102 écrite.")


if __name__ == "__main__":
    main()
