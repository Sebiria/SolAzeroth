"""Lot T1 des Tarides (03/11/2026) : puissance des monstres par secteur (« Les Tarides — Histoire et quêtes
(brouillon).md », § Secteurs et puissance et §5.2, points 1, 6 et 7).

Décision du point 1 (03/11/2026) : la puissance d'un monstre des Tarides appartient à son secteur, pas à son entrée.
Une même entrée vit dans plusieurs secteurs (les Kolkar aux Bassins oubliés, 16, et à l'Oasis luxuriante, 19) : la
puissance se fixe donc à chaque apparition.
- Chaque secteur a une plage d'origine (niveaux de Blizzard de ses monstres) et une plage de puissance. Une sous-zone
  peut resserrer la plage de puissance (les Bassins à 16, l'Oasis luxuriante à 19). Le niveau tiré par le moteur à
  chaque apparition est ramené sur la plage, en ligne droite : puissance = bas + (niveau - origine basse) × (haut -
  bas) / (origine haute - origine basse), arrondie, bornée (v3_niveau.cpp, OnBeforeCreatureSelectLevel).
- Le moteur calcule alors la vie, les dégâts, la puissance d'attaque et l'armure à ce niveau : tout suit la puissance
  du secteur, comme une entrée de ce niveau. Les sorts suivent la puissance du monstre (v3_combat.cpp, EchelleSort).
- Les apparitions hors sous-zone nommée (la savane, sous-zone 17) prennent la sous-zone de l'apparition nommée la
  plus proche à moins de VOISIN m, sinon la plage générale du secteur de celle-ci.
- Les Tarides du sud (1156) se partagent en deux : au nord de X_SUD, le secteur du sud ; au-delà, l'extrême sud.
- Les chefs nommés et les élites hors annexes ont une puissance fixe, par entrée (FIXES).
- Une créature invoquée par un monstre des secteurs prend la puissance de celui qui l'invoque ; invoquée autrement
  (quête, objet), elle prend la plage la plus fréquente de son entrée dans la zone.
- Les PNJ amicaux à la Horde, les PNJ à fonction, les bestioles, les monstres d'événement et ceux de plus de
  ORIGINE_MAX (gros-bras de Cabestan) gardent leur niveau.

Retraits, avec tables de retour (points 6 et 7) : les 4 Serviteurs de Tranchebauge (surface du Kraal), les 89
monstres hostiles de la surface des Souilles et la patrouille de l'Alliance (5797 à 5800, avec sa formation).
Le point d'Aciérite sauvage devant le Kraal passe à la Crête de Noirépine. Les gardes posées par le lot T0 devant les
deux entrées scellées disent leur réplique quand on approche (npc_solazeroth_v3_garde_scellee, v3_gouffre.cpp).

py puissance_tarides.py           écrit la migration 136 et affiche la répartition par secteur
py puissance_tarides.py --quetes  puissance des monstres visés par les quêtes, contre celle du brouillon
"""
import math
import os
import sys
from collections import Counter, defaultdict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import dbc
from quetes_durotar import s, sql

ICI = os.path.dirname(os.path.abspath(__file__))
MIGRATION = os.path.join(ICI, "..", "sql", "migrations", "136_v3_tarides_puissance")
FACTIONS = os.path.join(ICI, "..", "data", "dbc", "FactionTemplate.dbc")
CARTE, ZONE, ABORDS = 1, 17, 718
ORIGINE_MAX = 35
VOISIN = 80.0
X_SUD = -2900.0                 # Tarides du sud (1156) : au nord, secteur 3 ; au sud, secteur 4
HORDE = 4                       # FactionTemplate : masque de groupe de la Horde

# Secteurs : (numéro, nom, zone, plage d'origine, plage de puissance). Brouillon, § Secteurs et puissance.
SECTEURS = [
    (1, "La Croisée", ZONE, (10, 15), (14, 16)),
    (2, "Les oasis et la côte", ZONE, (12, 20), (18, 22)),
    (3, "Le sud", ZONE, (16, 22), (25, 27)),
    (4, "L'extrême sud", ZONE, (19, 27), (27, 30)),
    (5, "Abords des Cavernes", ABORDS, (11, 17), (30, 30)),
]
# Sous-zones : secteur, et plage de puissance quand elle est plus étroite que celle du secteur (quêtes et lieux du
# brouillon : T04 et T09 aux Bassins à 16, A03 et T10 à T12 aux oasis à 19, T14 sur la côte à 18…).
SOUS_ZONES = {
    379: (1, (14, 14)), 380: (1, (14, 14)), 815: (1, (14, 14)), 458: (1, (14, 15)), 1704: (1, (14, 15)),
    2757: (1, (14, 15)), 1699: (1, (15, 16)), 384: (1, (15, 16)), 2138: (1, (16, 16)), 386: (1, (16, 16)),
    387: (2, (19, 19)), 388: (2, (19, 19)), 392: (2, (18, 18)), 391: (2, (18, 18)), 401: (2, (18, 18)),
    385: (2, (21, 22)), 1697: (2, (20, 21)), 383: (2, (19, 21)), 382: (2, (18, 19)), 381: (2, (20, 22)),
    1702: (2, (18, 20)), 1703: (2, (22, 22)), 1599: (2, (22, 22)),
    378: (3, (25, 25)), 1700: (3, (25, 25)), 1698: (3, (25, 25)),
    1157: (4, (27, 28)), 390: (4, (29, 29)), 1701: (4, (29, 29)), 359: (4, (27, 27)), 2157: (4, (30, 30)),
    1557: (4, (30, 30)), 1717: (4, (30, 30)), 1316: (4, (30, 30)),
}
SUD_NORD, SUD_SUD = (3, (25, 27)), (4, (27, 28))     # Tarides du sud (1156), de part et d'autre de X_SUD
DECOR = {720}                   # Île de la Dispute : spectateurs, décor
# Puissance fixe par entrée : chefs nommés ramenés au haut de leur secteur, rares et élites hors annexes, troupe de
# Bael'dun (T25, A09).
FIXES = {
    3986: 16,   # Sarilus Souillemporte (25 d'origine), T08 ; faction 118, amie de la Horde (lot T2)
    3396: 22,   # Hezrul Marque-de-sang, T13
    3398: 22,   # Gesharahan, élite rare, relique A34
    3393: 22,   # Capitaine Beaumont, T15
    5863: 27,   # Géoprêtresse Gukk'rok, T23
    3414: 30,   # Général Doublenattes (30), T27
    5831: 28,   # Vif-crins, élite, à côté d'Humar (A17)
    5848: 30,   # Malgin Brasselorge, rare, Donjon de Bael'dun
    7233: 22,   # Sous-chef Fizzule, élite, décor près de la Videfange (point 7)
    7288: 22,   # Grand contremaître Puzik Bisbiwix, élite, décor (point 7)
    3376: 30, 3377: 30, 3378: 30,   # Soldats, Fusiliers et Officiers de Bael'dun
}

# Retraits (points 6 et 7) : (nom, condition sur creature).
RETRAITS = [
    ("Serviteurs de Tranchebauge (surface du Kraal)", "areaId = 1717 AND id = 6132"),
    ("surface des Souilles de Tranchebauge", "areaId = 1316 AND id IN (7872, 7873, 7874, 7895, 12865)"),
    ("patrouille de l'Alliance", "id IN (5797, 5798, 5799, 5800)"),
]
# Aciérite sauvage devant le Kraal (guid 212956, entre le Kraal et les Souilles) : à la Crête de Noirépine, près des
# huttes de Lok (position d'un Prophète Tranchecrin, à plus de 60 m des autres points de récolte). Hauteur à vérifier.
ACIERITE = (212956, (-4471.07, -1945.0, 118.288), (-3715.3, -1690.9, 93.6))
# Répliques des gardes des entrées scellées (lot T0, guids 9100100 et 9100101).
GARDES = [
    (244, 9100100, "Ordre de Kirge Corne-sévère : personne n'entre dans le Kraal. Les huréceros ont creusé trop "
                   "profond, et ce qui vit en dessous ne nous regarde pas encore."),
    (442, 9100101, "Les Souilles sont mortes, et elles ne le savent pas. Personne n'y descend."),
]
SCRIPT_GARDE = "npc_solazeroth_v3_garde_scellee"


def arrondi(x):
    return int(math.floor(x + 0.5))      # comme std::lround pour des valeurs positives


def puissance(niveau, plage):
    """Puissance d'une apparition au niveau tiré : même calcul que v3_niveau.cpp."""
    (o_bas, o_haut), (p_bas, p_haut) = plage
    if p_bas == p_haut or o_haut <= o_bas:
        return p_bas if p_bas == p_haut else arrondi((p_bas + p_haut) / 2)
    return max(p_bas, min(p_haut, arrondi(p_bas + (niveau - o_bas) * (p_haut - p_bas) / (o_haut - o_bas))))


def factions_amies():
    amies = set()
    for e in dbc.Dbc.ouvrir(FACTIONS).enregistrements:
        if (e[3] & HORDE or e[4] & HORDE) and not e[5] & HORDE:
            amies.add(e[0])
    return amies


def retirees():
    guids = set()
    for _, condition in RETRAITS:
        guids |= {int(g) for (g,) in sql("SELECT guid FROM acore_world.creature WHERE map = %d AND (%s)"
                                         % (CARTE, condition))}
    return guids


def apparitions(avec_retirees=False):
    """Apparitions concernées : [dict(guid, entree, zone, sous_zone, x, y, bas, haut, rang, nom)]."""
    amies = factions_amies()
    exclues = set() if avec_retirees else retirees()
    sortie = []
    for g, e, z, a, x, y, bas, haut, rang, faction, nom in sql(
            "SELECT c.guid, c.id, c.zoneId, c.areaId, c.position_x, c.position_y, t.minlevel, t.maxlevel, t.`rank`, "
            "t.faction, COALESCE(NULLIF(l.Name, ''), t.name) FROM acore_world.creature c JOIN acore_world.creature_template t "
            "ON t.entry = c.id LEFT JOIN acore_world.creature_template_locale l ON l.entry = t.entry AND l.locale = 'frFR' "
            "WHERE c.map = %d AND c.zoneId IN (%d, %d) AND t.npcflag = 0 AND t.type <> 8 AND t.maxlevel <= %d AND NOT "
            "EXISTS (SELECT 1 FROM acore_world.game_event_creature ev WHERE ev.guid = c.guid)"
            % (CARTE, ZONE, ABORDS, ORIGINE_MAX)):
        if (int(faction) in amies and int(e) not in FIXES) or int(g) in exclues or int(a) in DECOR:
            continue
        sortie.append(dict(guid=int(g), entree=int(e), zone=int(z), sous_zone=int(a), x=float(x), y=float(y),
                           bas=int(bas), haut=int(haut), rang=int(rang), nom=nom))
    return sortie


def plage_secteur(numero):
    return next((o, p) for n, _, _, o, p in SECTEURS if n == numero)


def classer(liste):
    """Ajoute à chaque apparition son secteur et sa plage (origine, puissance)."""
    def nommee(ap):
        if ap["zone"] == ABORDS:
            return 5, plage_secteur(5)[1]
        if ap["sous_zone"] == 1156:
            return SUD_NORD if ap["x"] > X_SUD else SUD_SUD
        return SOUS_ZONES.get(ap["sous_zone"])
    # Repères : les apparitions des sous-zones nommées de la zone 17 (la grotte des Cavernes, zone 718, n'en sert pas :
    # ses abords à 30 ne débordent pas sur la savane).
    reperes = [(ap, nommee(ap)) for ap in liste if ap["zone"] == ZONE and nommee(ap)]
    for ap in liste:
        sz = nommee(ap)
        if sz is None:
            proche, d = min(((r, math.hypot(r[0]["x"] - ap["x"], r[0]["y"] - ap["y"])) for r in reperes),
                            key=lambda t: t[1])
            sz = proche[1] if d <= VOISIN else (proche[1][0], plage_secteur(proche[1][0])[1])
        numero, p = sz
        ap["secteur"] = numero
        ap["plage"] = (plage_secteur(numero)[0], p)
        if ap["entree"] in FIXES:
            ap["plage"] = ((ap["bas"], ap["haut"]), (FIXES[ap["entree"]], FIXES[ap["entree"]]))
        ap["puissance"] = (puissance(ap["bas"], ap["plage"]), puissance(ap["haut"], ap["plage"]))
    return liste


def par_entree(liste):
    """Plage la plus fréquente de chaque entrée (créatures invoquées hors des monstres des secteurs)."""
    plages = defaultdict(Counter)
    for ap in liste:
        plages[ap["entree"]][(ap["zone"], ap["plage"])] += 1
    return {e: c.most_common(1)[0][0] for e, c in plages.items()}


def monstres(secteur=None, sous_zones=None):
    """(entrée, nom, puissance, rang, nombre d'apparitions) des monstres d'un secteur ou de sous-zones, pour les
    simulations : la puissance la plus fréquente de chaque entrée."""
    compte = defaultdict(Counter)
    noms, rangs = {}, {}
    for ap in classer(apparitions()):
        if (secteur and ap["secteur"] != secteur) or (sous_zones and ap["sous_zone"] not in sous_zones):
            continue
        compte[ap["entree"]][ap["puissance"][1]] += 1
        noms[ap["entree"]], rangs[ap["entree"]] = ap["nom"], ap["rang"]
    return sorted(((e, noms[e], c.most_common(1)[0][0], rangs[e], sum(c.values())) for e, c in compte.items()),
                  key=lambda t: (t[2], t[0]))


def conseillee(liste):
    """Puissance conseillée de la zone 17 : plage des secteurs (v3_niveau.cpp, à défaut des centiles)."""
    zones = [p for _, _, z, _, p in SECTEURS if z == ZONE]
    return min(p[0] for p in zones), max(p[1] for p in zones)


def ecrire(liste):
    up, down = [], []
    w = up.append
    w("-- Lot T1 des Tarides (03/11/2026) : puissance des monstres par secteur, retraits du Kraal, des Souilles et de")
    w("-- la patrouille, Aciérite déplacée, répliques des gardes. Généré par outils\\puissance_tarides.py : ne pas")
    w("-- modifier à la main.")
    w("USE acore_world;")
    w("")
    w("-- Secteurs (puissance conseillée de la zone : v3_niveau.cpp).")
    w("CREATE TABLE solazeroth_v3_puissance_secteurs (zone INT UNSIGNED NOT NULL, secteur TINYINT UNSIGNED NOT NULL, "
      "nom VARCHAR(64) NOT NULL, origine_min TINYINT UNSIGNED NOT NULL, origine_max TINYINT UNSIGNED NOT NULL, "
      "puissance_min TINYINT UNSIGNED NOT NULL, puissance_max TINYINT UNSIGNED NOT NULL, PRIMARY KEY (zone, secteur)) "
      "DEFAULT CHARSET=utf8mb4;")
    w("INSERT INTO solazeroth_v3_puissance_secteurs VALUES %s;" % ", ".join(
        "(%d, %d, %s, %d, %d, %d, %d)" % (z, n, s(nom), o[0], o[1], p[0], p[1]) for n, nom, z, o, p in SECTEURS))
    colonnes = ("secteur TINYINT UNSIGNED NOT NULL, origine_min TINYINT UNSIGNED NOT NULL, origine_max TINYINT UNSIGNED "
                "NOT NULL, puissance_min TINYINT UNSIGNED NOT NULL, puissance_max TINYINT UNSIGNED NOT NULL")
    w("-- Plage de chaque apparition (lue à chaque apparition et réapparition).")
    w("CREATE TABLE solazeroth_v3_puissance_apparitions (guid INT UNSIGNED NOT NULL PRIMARY KEY, %s);" % colonnes)
    lignes = ["(%d, %d, %d, %d, %d, %d)" % ((ap["guid"], ap["secteur"]) + ap["plage"][0] + ap["plage"][1])
              for ap in sorted(liste, key=lambda a: a["guid"])]
    for i in range(0, len(lignes), 400):
        w("INSERT INTO solazeroth_v3_puissance_apparitions VALUES %s;" % ", ".join(lignes[i:i + 400]))
    w("-- Plage par entrée : puissances fixes (fixe = 1), et créatures invoquées hors des monstres des secteurs.")
    w("CREATE TABLE solazeroth_v3_puissance_entrees (entree INT UNSIGNED NOT NULL PRIMARY KEY, zone INT UNSIGNED NOT "
      "NULL, fixe TINYINT UNSIGNED NOT NULL, %s);" % colonnes)
    entrees = par_entree(liste)

    def secteur(e, o, p):
        return next(a["secteur"] for a in liste if a["entree"] == e and a["plage"] == (o, p))
    w("INSERT INTO solazeroth_v3_puissance_entrees VALUES %s;" % ", ".join(
        "(%d, %d, %d, %d, %d, %d, %d, %d)" % ((e, z, int(e in FIXES), secteur(e, o, p)) + o + p)
        for e, (z, (o, p)) in sorted(entrees.items())))
    w("")
    gardes = ", ".join(str(g) for _, g, _ in GARDES)
    for nom, condition in RETRAITS:
        w("-- Retrait : %s." % nom)
    condition = " OR ".join("(%s)" % c for _, c in RETRAITS)
    cible = "SELECT guid FROM creature WHERE map = %d AND (%s)" % (CARTE, condition)
    w("CREATE TABLE solazeroth_v3_tarides_retraits SELECT * FROM creature WHERE map = %d AND (%s);" % (CARTE, condition))
    w("CREATE TABLE solazeroth_v3_tarides_retraits_addon SELECT * FROM creature_addon WHERE guid IN "
      "(SELECT guid FROM solazeroth_v3_tarides_retraits);")
    w("CREATE TABLE solazeroth_v3_tarides_retraits_formations SELECT * FROM creature_formations WHERE leaderGUID IN "
      "(SELECT guid FROM solazeroth_v3_tarides_retraits) OR memberGUID IN (SELECT guid FROM solazeroth_v3_tarides_retraits);")
    w("DELETE FROM creature_formations WHERE leaderGUID IN (SELECT guid FROM solazeroth_v3_tarides_retraits) OR "
      "memberGUID IN (SELECT guid FROM solazeroth_v3_tarides_retraits);")
    w("DELETE FROM creature_addon WHERE guid IN (SELECT guid FROM solazeroth_v3_tarides_retraits);")
    w("DELETE c FROM creature c JOIN solazeroth_v3_tarides_retraits r ON r.guid = c.guid;")
    w("")
    g, avant, apres = ACIERITE
    w("-- Aciérite sauvage devant le Kraal : à la Crête de Noirépine.")
    w("UPDATE gameobject SET position_x = %g, position_y = %g, position_z = %g, areaId = 1701 WHERE guid = %d;"
      % (apres + (g,)))
    w("")
    w("-- Répliques des gardes des entrées scellées (v3_gouffre.cpp).")
    w("ALTER TABLE solazeroth_v3_entrees_scellees ADD COLUMN garde INT UNSIGNED NOT NULL DEFAULT 0, "
      "ADD COLUMN replique VARCHAR(255) NOT NULL DEFAULT '';")
    for declencheur, guid, texte in GARDES:
        w("UPDATE solazeroth_v3_entrees_scellees SET garde = %d, replique = %s WHERE declencheur = %d;"
          % (guid, s(texte), declencheur))
    w("UPDATE creature SET ScriptName = %s WHERE guid IN (%s);" % (s(SCRIPT_GARDE), gardes))

    d = down.append
    d("-- Annule le lot T1 des Tarides (migration 136). Généré par outils\\puissance_tarides.py.")
    d("USE acore_world;")
    d("UPDATE creature SET ScriptName = '' WHERE guid IN (%s);" % gardes)
    d("ALTER TABLE solazeroth_v3_entrees_scellees DROP COLUMN garde, DROP COLUMN replique;")
    d("UPDATE gameobject SET position_x = %g, position_y = %g, position_z = %g, areaId = 0 WHERE guid = %d;"
      % (avant + (g,)))
    d("INSERT IGNORE INTO creature SELECT * FROM solazeroth_v3_tarides_retraits;")
    d("INSERT IGNORE INTO creature_addon SELECT * FROM solazeroth_v3_tarides_retraits_addon;")
    d("INSERT IGNORE INTO creature_formations SELECT * FROM solazeroth_v3_tarides_retraits_formations;")
    d("DROP TABLE solazeroth_v3_tarides_retraits, solazeroth_v3_tarides_retraits_addon, "
      "solazeroth_v3_tarides_retraits_formations;")
    d("DROP TABLE solazeroth_v3_puissance_entrees, solazeroth_v3_puissance_apparitions, solazeroth_v3_puissance_secteurs;")
    for suffixe, contenu in ((".up.sql", up), (".down.sql", down)):
        with open(MIGRATION + suffixe, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(contenu) + "\n")
    print("Migration écrite :", os.path.normpath(MIGRATION) + ".up.sql")


# Monstres visés par les quêtes d'histoire et puissance du brouillon (§2), pour --quetes.
QUETES = [
    ("T02", (3244, 3246), None, (14, 15)), ("T03", (3242,), None, (15, 15)), ("T04", (3272, 3273), {386}, (16, 16)),
    ("T05", (3265, 3266, 3267, 3268, 3269, 3271), {1699}, (15, 15)), ("T06", (3379, 3380), {384, 2138}, (15, 16)),
    ("T08", (3986,), None, (16, 16)), ("T11", (3461,), {387, 388}, (19, 19)),
    ("T12", (3272, 3273, 3274, 3275), {387}, (19, 19)), ("T13", (3396,), None, (22, 22)),
    ("T14", (3381, 3382, 3383, 3384), {391, 392}, (18, 18)), ("T15", (3385, 3386, 3393), {385}, (21, 22)),
    ("T18", (3258, 3260, 3261, 3263), {1700, 1698}, (25, 25)), ("T19", (3258, 3260, 3261, 3263), {1700}, (25, 25)),
    ("T22", (3238, 3239, 3240), {1156}, (25, 27)), ("T23", (5863,), None, (27, 27)),
    ("T24", (3374, 3375), {359}, (27, 27)), ("T25", (3376, 3377, 3378), None, (30, 30)),
    ("T27", (3414,), None, (30, 30)), ("T28", (3434, 3435, 3436, 3456, 3457, 3458, 3459), {1701}, (29, 30)),
]


def quetes(liste):
    print("Quête  monstres                         puissance en base   brouillon")
    for nom, entrees, sous_zones, voulue in QUETES:
        secteur = 1 if nom in ("T02", "T03") else None
        p = [q for ap in liste if ap["entree"] in entrees and (ap["sous_zone"] in sous_zones if sous_zones else
                                                             secteur in (None, ap["secteur"])) for q in ap["puissance"]
             if not (sous_zones == {1156} and ap["secteur"] != 3)]
        if not p:
            print("%-6s %-32s aucune apparition" % (nom, entrees))
            continue
        ecart = "" if voulue[0] <= min(p) and max(p) <= voulue[1] else "   <- écart"
        print("%-6s %-32s %2d à %2d              %d à %d%s" % (nom, ",".join(map(str, entrees))[:32], min(p), max(p),
                                                              voulue[0], voulue[1], ecart))


def main():
    liste = classer(apparitions())
    if "--quetes" in sys.argv:
        quetes(liste)
        return
    ecrire(liste)
    par_secteur = defaultdict(Counter)
    for ap in liste:
        for p in ap["puissance"]:
            par_secteur[ap["secteur"]][p] += 1
    for n, nom, _, o, p in SECTEURS:
        c = par_secteur[n]
        print("Secteur %d, %s (origine %d-%d -> %d-%d) : %d apparitions ; puissances %s" % (
            n, nom, o[0], o[1], p[0], p[1], sum(c.values()) // 2, ", ".join("%d (%d)" % kv for kv in sorted(c.items()))))
    print("Retraits : %d apparitions ; puissance conseillée de la zone : %d-%d" % (len(retirees()), *conseillee(liste)))


if __name__ == "__main__":
    main()
