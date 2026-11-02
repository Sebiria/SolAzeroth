"""Audit du jeu, lot 3c (02/11/2026, « Audit du jeu\\10_consensus.md », C1 et C2) : recalibrage des monstres de Durotar
et du Gouffre avec la nouvelle armure (lot 3a), le kit du lot 3b et l'interruption.

Les lanceurs de sorts retrouvent leurs dégâts : la migration 107 avait baissé leur mêlée (jusqu'à ×0,3) et leurs sorts
(jusqu'à ×0,2) faute d'interruption. Ici on repart des réglages d'avant elle, les sorts entiers, et chaque monstre est
simulé contre la fiche de Sebiria la plus proche de sa puissance (simulation_sorts.py), avec la potion de départ et le
Heurt de bouclier dès la puissance 3. Seuls les monstres hors de leur cible bougent, et seulement jusqu'à rentrer dans
la cible (MARGE points en deçà du bord) : les écarts entre monstres restent.
- Vie perdue attendue (une défaite compte 100 %), cibles du consensus : vallée (puissance 3 au plus) 5 à 20 %, monstre
  seul 15 à 30 %, élites et chefs (chefs renforcés, élites de Durotar, boss du Gouffre) 30 à 60 %. Les monstres du
  Gouffre hors boss vont par groupes : ils visent la cible du monstre seul, le groupe fait le reste.
- Réglage : DamageModifier (entre F_MIN et F_MAX fois celui d'avant la migration 107) ; si la mêlée au plus bas ne
  suffit pas, les sorts baissent aussi (facteur entre G_MIN et 1, table solazeroth_v3_sorts_facteur) ; pour les élites
  et les chefs gagnés au moins VICTOIRES fois sur 100, ensuite HealthModifier (entre V_MIN et V_MAX), pour une durée
  de 12 à 15 s.
- Chefs renforcés : un renfort au plus appelé en combat (APPELS_MAX ; Benedict en appelait 4, Kolkanis et Gazz'uz 2 :
  0 % de victoires en simulation, et la mort de Test contre Benedict et ses 4 soldats au journal du 31/10/2026), et plus
  de marcheur du Vide (retiré partout dans la zone par la migration 106, pas des copies renforcées).

py calibre_3c.py            écrit la migration 111 et affiche les réglages
py calibre_3c.py 3204 ...   affiche seulement ces monstres
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import simulation_camp as camp
import simulation_sorts as ss
import sorts_monstres_v3 as smv
from quetes_durotar import sql

MIGRATION = r"C:\SolAzeroth\sql\migrations\111_v3_calibre_3c"
CHEFS_RENFORCES = [910010, 910011, 910012, 910013, 910014]
BOSS_GOUFFRE = [11517, 11518, 11519, 11520]
APPELS_MAX = {910011: 1, 910012: 1, 910014: 1}   # Yarrog garde ses 2 quasits toutes les 20 s
CIBLES = {"vallée": (5, 20), "seul": (15, 30), "élite": (30, 60)}
DUREE = (12.0, 15.0)
MARGE = 3.0
F_MIN, F_MAX, V_MIN, V_MAX, G_MIN = 0.3, 2.0, 0.5, 2.0, 0.2
VICTOIRES = 80
POTION = (1, 30, 0, 0)
HEURT = 12.0
N, N_FINAL = 200, 600


def perdue(r):
    """Vie perdue attendue, en %, une défaite comptant pour 100 %."""
    v = r["victoire"] / 100.0
    return v * (100.0 - r["vie_restante"]) + (1 - v) * 100.0


def regler(mesure, cible, bas, haut, croissant=True):
    """Le facteur entre bas et haut pour lequel mesure(k) vaut cible."""
    for _ in range(8):
        k = (bas + haut) / 2
        if (mesure(k) > cible) == croissant:
            haut = k
        else:
            bas = k
    return round((bas + haut) / 2, 2)


def categorie(entree, puissance, rang):
    if entree in CHEFS_RENFORCES or entree in BOSS_GOUFFRE or (rang >= 1 and entree not in gouffre):
        return "élite"
    return "vallée" if puissance <= 3 else "seul"


def garder(entree, sorts):
    """Sorts d'un chef renforcé après la migration 111 : sans invocation, APPELS_MAX renforts au plus."""
    sorts = [s for s in sorts if s["id"] not in smv.INVOCATIONS]
    appels = [s for s in sorts if s["id"] < 0][:APPELS_MAX.get(entree, 99)]
    return [s for s in sorts if s["id"] >= 0] + appels


def main():
    global gouffre
    choisis = [int(x) for x in sys.argv[1:]]
    gouffre = {int(x[0]) for x in sql("SELECT DISTINCT id FROM acore_world.creature WHERE map = 389")}
    avant_107 = {int(e): float(d) for e, d in sql(
        "SELECT entry, DamageModifier FROM acore_world.solazeroth_v3_sorts_calibre_origine")}
    actuels = {int(e): (float(d), float(h), int(r)) for e, d, h, r in sql(
        "SELECT entry, DamageModifier, HealthModifier, `rank` FROM acore_world.creature_template")}
    fiches = [f for f in camp.fiches() if f.nom == "Sebiria"]
    reglages = []
    for entree in choisis or sorted(set(smv.monstres_zone()) | set(CHEFS_RENFORCES)):
        try:
            m = ss.monstre_avec_sorts(entree)
        except IndexError:
            continue
        if m.puissance > 15 or m.vie <= 10:      # bestioles (Aspic : 2 points de vie) écartées
            continue
        if entree in CHEFS_RENFORCES:
            # Les copies renforcées (migration 075) gardaient le marcheur du Vide que la migration 106 a retiré partout
            # dans la zone : la migration 111 le leur retire aussi.
            m.sorts = garder(entree, m.sorts)
            m.renforts = []
        dm, hm, rang = actuels[entree]
        base = avant_107.get(entree, dm) / dm if dm else 1.0     # mêlée d'avant la migration 107, relative à l'actuelle
        j = min(fiches, key=lambda f: abs(f.puissance - m.puissance))
        if m.puissance > j.puissance + 1:
            # Pas de fiche aussi forte (Gouffre, puissance 10 à 12) : le combat est joué à puissance égale, le monstre
            # ramené à la puissance de la fiche ; ses facteurs valent ensuite à son niveau.
            sorts_chef = m.sorts if entree in CHEFS_RENFORCES else None
            m = ss.monstre_avec_sorts(entree, round(j.puissance), renforts=entree not in CHEFS_RENFORCES)
            if sorts_chef is not None:
                m.sorts = garder(entree, m.sorts)
        cat = categorie(entree, m.puissance, rang)
        bas, haut = CIBLES[cat]
        options = dict(potion=POTION, heurt=HEURT if m.puissance >= 3 else None)

        def sim(f, v, g=1.0, n=N):
            return ss.simuler(j, m, n, melee=base * f, vie=v, facteur_sorts=g, **options)

        try:
            depart = sim(1.0, 1.0, n=N_FINAL)
        except ZeroDivisionError:      # tué au premier coup (bestiole)
            continue
        f, v, g = 1.0, 1.0, 1.0
        for _ in range(2):
            p = perdue(sim(f, v, g))
            if p > haut:
                if perdue(sim(F_MIN, v, g)) > haut - MARGE:
                    f = F_MIN
                    g = regler(lambda k: perdue(sim(f, v, k)), haut - MARGE, G_MIN, g)
                else:
                    f = regler(lambda k: perdue(sim(k, v, g)), haut - MARGE, F_MIN, f)
            elif p < bas:
                if g < 1.0:
                    g = regler(lambda k: perdue(sim(f, v, k)), bas + MARGE, g, 1.0)
                else:
                    f = regler(lambda k: perdue(sim(k, v, g)), bas + MARGE, f, F_MAX)
            r = sim(f, v, g)
            if cat == "élite" and r["victoire"] >= VICTOIRES and not DUREE[0] <= r["duree"] <= DUREE[1]:
                but = DUREE[0] + 1 if r["duree"] < DUREE[0] else DUREE[1] - 1
                v = regler(lambda k: sim(f, k, g)["duree"], but, V_MIN, V_MAX)
        fin = sim(f, v, g, N_FINAL)
        if fin["victoire"] < 50:
            # Rien ne le rend battable (Requin du sable : danger du décor) : il garde ses réglages.
            print("%6d %-28s P%-2d %-6s laissé tel quel : %3.0f %% de victoires au mieux" % (
                entree, m.nom[:28], m.puissance, cat, fin["victoire"]), flush=True)
            continue
        nouveau_dm = round(avant_107.get(entree, dm) * f, 3)
        nouveau_hm = round(hm * v, 3)
        reglages.append((entree, nouveau_dm, nouveau_hm, dm, hm, g))
        print("%6d %-28s P%-2d %-6s (fiche %4.1f) | avant %5.1f %% perdue %4.1f s %3.0f %% vict. | mêlée x%.2f vie x%.2f "
              "sorts x%.2f | après %5.1f %% %4.1f s %3.0f %%" % (
                  entree, m.nom[:28], m.puissance, cat, j.puissance, perdue(depart), depart["duree"],
                  depart["victoire"], f, v, g, perdue(fin), fin["duree"], fin["victoire"]), flush=True)

    if choisis:
        return
    changes = [r for r in reglages if abs(r[1] - r[3]) > 1e-3 or abs(r[2] - r[4]) > 1e-3 or r[5] < 1.0]
    liste = ", ".join(str(r[0]) for r in changes) or "0"
    up = ["-- Audit du jeu, lot 3c (02/11/2026) : monstres de Durotar et du Gouffre recalibrés (armure du lot 3a, kit du",
          "-- lot 3b, interruption) ; les sorts retrouvent leurs dégâts. Généré par outils\\calibre_3c.py : ne pas",
          "-- modifier à la main.",
          "USE acore_world;",
          "CREATE TABLE solazeroth_v3_calibre_3c_origine SELECT entry, DamageModifier, HealthModifier FROM "
          "creature_template WHERE entry IN (%s);" % liste,
          "CREATE TABLE solazeroth_v3_sorts_facteur_3c SELECT * FROM solazeroth_v3_sorts_facteur;",
          "DELETE FROM solazeroth_v3_sorts_facteur;",
          "CREATE TABLE solazeroth_v3_chefs_3c_origine SELECT * FROM smart_scripts WHERE source_type = 0 AND "
          "entryorguid IN (%s);" % ", ".join(map(str, CHEFS_RENFORCES)),
          "DELETE FROM smart_scripts WHERE source_type = 0 AND entryorguid IN (%s) AND action_type = 11 AND "
          "action_param1 IN (%s);" % (", ".join(map(str, CHEFS_RENFORCES)), ", ".join(map(str, smv.INVOCATIONS)))]
    for entree, nombre in APPELS_MAX.items():
        up.append("DELETE FROM smart_scripts WHERE source_type = 0 AND entryorguid = %d AND action_type = 12 AND id > "
                  "(SELECT premier FROM (SELECT MIN(id) + %d AS premier FROM smart_scripts WHERE source_type = 0 AND "
                  "entryorguid = %d AND action_type = 12) p);" % (entree, nombre - 1, entree))
    for entree, d, h, _, _, g in changes:
        up.append("UPDATE creature_template SET DamageModifier = %.3f, HealthModifier = %.3f WHERE entry = %d;"
                  % (d, h, entree))
        if g < 1.0:
            up.append("INSERT INTO solazeroth_v3_sorts_facteur VALUES (%d, %.2f);" % (entree, g))
    up.append("")
    down = ["-- Rend aux monstres leurs réglages d'avant le lot 3c.",
            "USE acore_world;",
            "UPDATE creature_template t JOIN solazeroth_v3_calibre_3c_origine o ON o.entry = t.entry SET "
            "t.DamageModifier = o.DamageModifier, t.HealthModifier = o.HealthModifier;",
            "DELETE FROM solazeroth_v3_sorts_facteur;",
            "INSERT INTO solazeroth_v3_sorts_facteur SELECT * FROM solazeroth_v3_sorts_facteur_3c;",
            "DELETE FROM smart_scripts WHERE source_type = 0 AND entryorguid IN (%s);" % ", ".join(map(str, CHEFS_RENFORCES)),
            "INSERT INTO smart_scripts SELECT * FROM solazeroth_v3_chefs_3c_origine;",
            "DROP TABLE solazeroth_v3_chefs_3c_origine;",
            "DROP TABLE solazeroth_v3_calibre_3c_origine;",
            "DROP TABLE solazeroth_v3_sorts_facteur_3c;", ""]
    for suffixe, lignes in ((".up.sql", up), (".down.sql", down)):
        with open(MIGRATION + suffixe, "w", encoding="utf-8", newline="\n") as fichier:
            fichier.write("\n".join(lignes))
    print("Migration 111 écrite : %d monstres réglés sur %d." % (len(changes), len(reglages)))


if __name__ == "__main__":
    main()
