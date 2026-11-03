"""Audit du jeu, lot 7 (02/11/2026) : gabarit de zone, à remplir avant chaque nouvelle zone (P8 du game designer
systèmes ; choix de l'utilisateur : « gabarit + vérificateur », sans regénérer les migrations de Durotar).

Une zone se décrit par un dictionnaire (voir DUROTAR) :
- plage de puissance et secteurs (début et fin en % de zone, puissance des monstres, niveau d'objet du nouvel
  équipement) ;
- parts du pourcentage par source, et nombre d'annexes par famille ;
- barème des récompenses d'annexe (éclats et Marques par famille, à la puissance 12 ou moins) ; barème par point de
  part, par tranche de puissance (lot T0 des Tarides : la zone suivante part de la dernière tranche, décision 4 du
  comparatif) ;
- plantes et filons (règle des zones de départ : de quoi débuter les métiers sans sortir) et plats ;
- rangs du camp et de la potion achetables dans la zone (règle « deux fois par zone », doc F5) ;
- emplacements et techniques ouverts, par spécialisation : ce sont les classes qui s'adaptent au monde (demande de
  l'utilisateur du 02/11/2026, en vue du démoniste) ;
- donjon (puissance des monstres et niveau d'objet de ses pièces bleues) ;
- économie (revenu par % de zone, filons) pour simulation_zones.py.
Une valeur None est « à remplir » : le vérificateur la liste à part, sans la compter comme une erreur.

Lancé seul (py gabarit_zone.py) :
1. relit Durotar dans la base et le code (zone_parts, annexes, camp, plats, filons et plantes, techniques de
   v3_kit.cpp) et la compare à sa description : le gabarit dit vrai sur la zone qui existe. Lot T0 des Tarides
   (03/11/2026) : les Tarides aussi, pour ce qui est déjà en base (récolte dans les deux sens, techniques, donjon) ;
   le reste se compare dès que la zone a des parts ;
2. vérifie l'emboîtement de Durotar, des Tarides (14-30, choix de l'utilisateur du 03/11/2026) et d'une zone 3
   extrapolée (34-50) : chaque zone commence au niveau d'objet des pièces bleues du donjon précédent ;
3. relit les fiches d'arrivée et de sortie (fiches_zones.py) : pièces en base, puissance, rang 0, sans les objets des
   rares secrets.
Code de sortie 1 s'il y a une erreur.
"""
import os
import re
import subprocess
import sys

ICI = os.path.dirname(os.path.abspath(__file__))
MYSQL = r"C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe"
CNF = os.path.join(ICI, "..", "config", "mysql-acore.cnf")
KIT = os.path.join(ICI, "..", "modules", "mod-solazeroth", "src", "v3_kit.cpp")
BIVOUAC = os.path.join(ICI, "..", "modules", "mod-solazeroth", "src", "v3_bivouac.cpp")
LOCK = os.path.join(ICI, "..", "data", "dbc", "Lock.dbc")

FAMILLES = ("lieux", "primes", "contrats", "defis", "reliques")
SOURCES = ("histoire", "exploration") + FAMILLES
EMPLACEMENTS_MAX = 8                    # EQUIPEES_MAX (v3_kit.cpp)
# Dernier rang achetable aujourd'hui (RANG_FEU_MAX et RANG_POTION_MAX de v3_bivouac.cpp ; lot T0 : le gabarit
# inversait le feu et la potion).
RANGS_CAMP = {"feu": 3, "potion": 2}

DUROTAR = {
    "nom": "Durotar", "zone": 14, "plage": (1, 10),
    "secteurs": [  # nom, début %, fin %, puissance des monstres, niveau d'objet (simulation_rangs.py)
        ("Vallée", 0, 8, (1, 3), 3.0),
        ("Tranchecolline", 8, 25, (4, 6), 6.0),
        ("Sud", 25, 45, (8, 9), 7.5),
        ("Nord", 45, 65, (9, 10), 9.0),
        ("Gouffre et fin", 65, 100, (10, 12), 10.0),
    ],
    # Parts en % (« Durotar — Histoire et quêtes », §4.3).
    "parts": {"histoire": 50, "exploration": 6, "lieux": 19, "primes": 10, "contrats": 6, "defis": 5, "reliques": 4},
    "annexes": {"lieux": 10, "primes": 9, "contrats": 5, "defis": 6, "reliques": 16},
    # Par annexe à donneur, tous paliers compris (solazeroth_v3_annexes) : (éclats, Marques), arrondis.
    "bareme": {"primes": (15, 22), "contrats": (16, 29), "defis": (11, 17)},
    # Par point de part (« Durotar — Histoire et quêtes », §4.1) : (puissance la plus haute de la tranche, cuivres,
    # éclats) ; Marques : 20 par point.
    "bareme_par_point": {"marques": 20, "tranches": [(3, 3000, 5), (6, 6000, 8), (9, 10000, 12), (11, 12000, 15)]},
    "recolte": {"filons": [1731], "plantes": [1617, 1618, 1619, 1620]},
    "plats": 5,
    # Rangs ouverts dans la zone (v3_bivouac.cpp : feu 1 contre des Marques, 2 et 3 par solazeroth_v3_camp_couts genre
    # 2 ; potion 1 et 2 par le genre 1). Lot T0 : le gabarit inversait les deux.
    "camp": {"feu": (1, 3), "potion": (1, 2)},
    "specialisations": {
        "guerrier_tank": {"emplacements": (3, 5), "techniques": [100011, 100013, 100012, 100019, 100015, 100014, 100016]},
        # Lot D2 : mêmes étapes du récit (Diablotin, Drain de vie, Peur, Marcheur du Vide, Malédiction d'agonie).
        "demoniste_affliction": {"emplacements": (3, 5),
                                 "techniques": [100201, 100202, 100203, 100205, 100206, 100207, 100204]},
        # Lots V2 et V6 : mêmes étapes (Coup de pied, Évasion, Camouflage, Coup bas, Éventail de couteaux).
        "voleur_assassinat": {"emplacements": (3, 5),
                              "techniques": [100302, 100304, 100305, 100307, 100308, 100311, 100316]},
    },
    # Bleues du Gouffre : niveau d'objet 14 (equipement_gouffre_v3.PUISSANCE), la puissance d'arrivée aux Tarides.
    "donjon": {"nom": "Gouffre de Ragefeu", "carte": 389, "puissance": (10, 12), "bleues": 14, "seuil": 60},
    # Revenu mesuré (simulation_rangs.py) ; filons présents à la fois (pools et filons seuls, filons_heure.py).
    "economie": {"eclats_par_pourcent": 18, "or_par_pourcent": 2700, "taille": 1.0, "filons_actifs": 53},
}


def extrapoler(base, nom, zone, plage, specialisations, recolte=None, donjon=None, taille=None, secteurs=None):
    """Zone de même forme que base, ses puissances ramenées sur la nouvelle plage. Le camp prend les deux rangs
    suivants ; ce qui dépend de la zone réelle (récolte, plats, donjon, barème moyen des annexes) reste à remplir si
    on ne le donne pas. Le barème par point repart de la dernière tranche de base, puis × 1,54 par tranche (décision 4
    du comparatif des Tarides)."""
    a0, a1 = base["plage"]
    b0, b1 = plage

    def ramener(p):
        return round(b0 + (p - a0) * (b1 - b0) / (a1 - a0), 1)

    if secteurs is None:
        dernier = len(base["secteurs"])
        secteurs = [("Donjon et fin" if i == dernier else f"Secteur {i}", d, f, (ramener(p[0]), ramener(p[1])),
                     ramener(niveau)) for i, (_, d, f, p, niveau) in enumerate(base["secteurs"], 1)]
    _, cuivres, eclats = base["bareme_par_point"]["tranches"][-1]
    tranches = []
    for haut, *_ in base["bareme_par_point"]["tranches"]:
        tranches.append((round(ramener(haut)), round(cuivres, -2), round(eclats)))
        cuivres, eclats = cuivres * 1.54, eclats * 1.54
    bareme_par_point = {"marques": base["bareme_par_point"]["marques"], "tranches": tranches}
    economie = dict(base["economie"])
    # Une zone plus large (15 points au lieu de 10) a proportionnellement plus de monstres par % de zone.
    economie["taille"] = taille if taille is not None else base["economie"]["taille"] * (b1 - b0 + 1) / (a1 - a0 + 1)
    economie["filons_actifs"] = None
    camp = {g: (r[1] + 1, r[1] + 2) for g, r in base["camp"].items()}
    # Donjon et bleues : mêmes écarts à la fin de zone que la zone de base, en points (Durotar finit à 10, Gouffre
    # 10-12, bleues 14 : + 0, + 2, + 4). Décision 3 du brouillon des Tarides : bleues à fin + 4, pas ramenées en
    # proportion de la plage.
    d0, d1 = base["donjon"]["puissance"]
    donjon = dict(donjon or {"nom": None, "carte": None})
    donjon.setdefault("puissance", (b1 + d0 - a1, b1 + d1 - a1))
    donjon.setdefault("bleues", b1 + base["donjon"]["bleues"] - a1)
    donjon.setdefault("seuil", base["donjon"]["seuil"])   # % de la zone pour entrer (60 %, décision 3)
    return {
        "nom": nom, "zone": zone, "plage": plage, "secteurs": secteurs,
        "parts": dict(base["parts"]), "annexes": dict(base["annexes"]), "bareme": None,
        "bareme_par_point": bareme_par_point,
        "recolte": recolte, "plats": None, "camp": camp, "specialisations": specialisations,
        "donjon": donjon, "economie": economie,
    }


# Lot 3b (« Audit du jeu\lot_3b_deblocages_proposition.md ») : techniques et emplacements des zones suivantes.
# Plage 14-30 (décision de l'utilisateur du 03/11/2026 : la Croisée à 14-16, fin de zone hors instance à 30).
TARIDES = extrapoler(DUROTAR, "Les Tarides", 17, (14, 30), {
    "guerrier_tank": {"emplacements": (5, 6), "techniques": [100020, 100018]},    # Fracasser armure, Mur protecteur
    "demoniste_affliction": {"emplacements": (5, 6), "techniques": [100208, 100209]},   # Faiblesse, Siphon de vie
    "voleur_assassinat": {"emplacements": (5, 6), "techniques": [100312, 100313]},   # Poison affaiblissant, Lancer
},
    # Lot T0 (brouillon des Tarides, §4.6) : les entrées réelles de la zone 17, relevées en base. Cuivre 1731, 3763,
    # 103713 ; étain 1732, 3764, 103711 ; argent 1733, 105569.
    recolte={"filons": [1731, 1732, 1733, 3763, 3764, 103711, 103713, 105569],
             "plantes": [1620, 1622, 1623, 1624, 1628, 2045, 3724, 3725, 3726, 3727, 3729, 3730]},
    donjon={"nom": "Cavernes des Lamentations", "carte": 43},   # 30-32, bleues 34 (décision 16 du comparatif)
    # Lot T0 : les vraies bornes des secteurs (point 10 du §5.2 : 0, 19,3, 48,55, 71,65, 100). Le donjon ne compte pas
    # dans le pourcentage. Niveau d'objet du nouvel équipement : le haut du secteur (une quête donne la puissance de
    # son secteur).
    secteurs=[("La Croisée", 0, 19.3, (14, 16), 16.0), ("Oasis et côte", 19.3, 48.55, (18, 22), 22.0),
              ("Le sud", 48.55, 71.65, (25, 27), 27.0), ("L'extrême sud", 71.65, 100, (27, 30), 30.0)])
# Barème des annexes par point (décision 4 du comparatif, brouillon §4.1) : la Croisée part de la dernière tranche
# de Durotar, puis × 1,54 environ par tranche.
TARIDES["bareme_par_point"]["tranches"] = [(16, 12000, 15), (22, 18500, 23), (29, 28500, 36), (31, 44000, 55)]
TARIDES["economie"]["filons_actifs"] = 166   # filons_heure.py (cuivre, étain, argent de la zone 17)
TARIDES["plats"] = 10                         # plafond des Tarides (décision de l'utilisateur du 03/11/2026)
# Zone 3 : commence aux bleues des Cavernes (34) ; même largeur que les Tarides (16 points), fin à 50. Fin choisie
# pour le gabarit, à valider par l'utilisateur.
ZONE_3 = extrapoler(TARIDES, "Zone 3 (fictive)", None, (34, 50), {
    "guerrier_tank": {"emplacements": (6, 6), "techniques": [100021, 100017]},    # Désarmement, Ravage
    "demoniste_affliction": {"emplacements": (6, 6), "techniques": [100213, 100211]},   # Voile mortel, Graine
    "voleur_assassinat": {"emplacements": (6, 6), "techniques": [100314, 100318]},   # Sprint, Feinte
})
ZONES = [DUROTAR, TARIDES, ZONE_3]


def facteur(puissance):
    """Coûts des rangs et éclats des monstres (v3_equipement.cpp Cout, v3_collection.cpp Eclats)."""
    return 1.0 + max(0, int(puissance) - 12) / 12.0


# ----------------------------------------------------------------------------------------------------------------
# Vérification
# ----------------------------------------------------------------------------------------------------------------
def a_remplir(zone):
    manque = []
    for cle in ("zone", "plats", "recolte"):
        if zone.get(cle) is None:
            manque.append(cle)
    if zone["donjon"].get("nom") is None:
        manque.append("donjon")
    if zone.get("bareme") is None:
        manque.append("barème moyen des annexes (une fois écrites)")
    if zone["economie"].get("filons_actifs") is None:
        manque.append("filons actifs (filons_heure.py)")
    return manque


def verifier(zone, precedente=None):
    erreurs = []
    nom = zone["nom"]
    total = sum(zone["parts"].get(s, 0) for s in SOURCES)
    if abs(total - 100) > 1e-6:
        erreurs.append(f"{nom} : les parts font {total:g} %, pas 100 %")
    for f in FAMILLES:
        if zone["parts"].get(f, 0) > 0 and not zone["annexes"].get(f):
            erreurs.append(f"{nom} : {zone['parts'][f]:g} % de {f} sans aucune annexe")
    # Secteurs : de 0 à 100 % sans trou, puissances croissantes dans la plage (le donjon peut la dépasser).
    fin = 0
    bas_precedent = None
    p0, p1 = zone["plage"]
    for n, d, f, (a, b), _ in zone["secteurs"]:
        if d != fin:
            erreurs.append(f"{nom} : le secteur {n} commence à {d} %, le précédent finit à {fin} %")
        fin = f
        if bas_precedent is not None and a < bas_precedent:
            erreurs.append(f"{nom} : le secteur {n} ({a:g}) est plus faible que le précédent ({bas_precedent:g})")
        bas_precedent = a
        if a < p0 or a > p1:
            erreurs.append(f"{nom} : le secteur {n} ({a:g}) sort de la plage {p0}-{p1}")
    if fin != 100:
        erreurs.append(f"{nom} : les secteurs s'arrêtent à {fin} %")
    if zone["donjon"]["puissance"][1] < p1:
        erreurs.append(f"{nom} : le donjon ({zone['donjon']['puissance'][1]}) est plus faible que la zone ({p1})")
    if zone["recolte"] is not None and not (zone["recolte"].get("filons") and zone["recolte"].get("plantes")):
        erreurs.append(f"{nom} : il faut des filons et des plantes (règle des zones de départ)")
    # Barème par point : tranches croissantes, qui couvrent la plage.
    tranches = zone["bareme_par_point"]["tranches"]
    for (h0, c0, e0), (h1, c1, e1) in zip(tranches, tranches[1:]):
        if not (h1 > h0 and c1 > c0 and e1 > e0):
            erreurs.append(f"{nom} : barème par point non croissant ({h0} puis {h1})")
    if tranches[-1][0] < p1:
        erreurs.append(f"{nom} : le barème par point s'arrête à {tranches[-1][0]}, la zone va jusqu'à {p1}")
    if precedente:
        # Le camp ouvre deux rangs de chaque par zone. Durotar, qui ouvre le camp, a le feu 1 à 3.
        for g, (r0, r1) in zone["camp"].items():
            if r1 - r0 != 1:
                erreurs.append(f"{nom} : {g} ouvre {r1 - r0 + 1} rangs, deux attendus")
        # Décision 4 du comparatif des Tarides : rien ne baisse au changement de zone.
        if tranches[0][1:] != precedente["bareme_par_point"]["tranches"][-1][1:]:
            erreurs.append(f"{nom} : le barème par point commence à {tranches[0][1:]}, la zone précédente finit à "
                           f"{precedente['bareme_par_point']['tranches'][-1][1:]}")
        # La zone commence au niveau d'objet des bleues du donjon précédent : c'est la puissance d'un joueur qui
        # arrive tout en bleu, au rang 0 (Durotar : bleues du Gouffre 14, les Tarides commencent à 14). Le saut
        # entre la fin d'une zone et le début de la suivante est donc voulu.
        bleues = precedente["donjon"].get("bleues")
        if p0 != bleues:
            erreurs.append(f"{nom} : la plage commence à {p0}, les bleues du donjon précédent valent {bleues}")
        for g, (r0, _) in zone["camp"].items():
            if r0 != precedente["camp"][g][1] + 1:
                erreurs.append(f"{nom} : {g} reprend au rang {r0}, la zone précédente finit au rang "
                               f"{precedente['camp'][g][1]}")
    deja = set()
    z = precedente
    while z:   # techniques déjà ouvertes par les zones précédentes
        for s in z["specialisations"].values():
            deja.update(s["techniques"])
        z = z.get("_precedente")
    for spe, s in zone["specialisations"].items():
        e0, e1 = s["emplacements"]
        if not (e0 <= e1 <= EMPLACEMENTS_MAX):
            erreurs.append(f"{nom} : {spe} a des emplacements {e0}-{e1} (8 au plus, croissants)")
        if precedente and spe in precedente["specialisations"] and e0 != precedente["specialisations"][spe]["emplacements"][1]:
            erreurs.append(f"{nom} : {spe} reprend à {e0} emplacements, la zone précédente finit à "
                           f"{precedente['specialisations'][spe]['emplacements'][1]}")
        for t in s["techniques"]:
            if t in deja:
                erreurs.append(f"{nom} : {spe} rouvre la technique {t}")
        deja.update(s["techniques"])
    return erreurs


# ----------------------------------------------------------------------------------------------------------------
# Relecture des zones dans la base et le code
# ----------------------------------------------------------------------------------------------------------------
def sql(requete):
    r = subprocess.run([MYSQL, "--defaults-extra-file=" + CNF, "-N", "-B", "acore_world", "-e", requete],
                       capture_output=True, check=True)
    return [l.split("\t") for l in r.stdout.decode("utf-8").splitlines()]


# Listes de v3_kit.cpp (ORDRE_<nom>) et spécialisations du gabarit (lot D2 : une liste par spécialisation).
ORDRES = {"TANK": "guerrier_tank", "AFFLICTION": "demoniste_affliction", "ASSASSINAT": "voleur_assassinat"}


def techniques_du_kit():
    """Techniques de chaque liste de v3_kit.cpp, dans l'ordre : (sort, ouverte dès aujourd'hui, pas « PLUS_TARD »)."""
    texte = open(KIT, encoding="utf-8").read()
    lu = {}
    for nom, bloc in re.findall(r"std::vector<Technique> const ORDRE_(\w+) =\s*\{(.*?)\n    \};", texte, re.S):
        lu[ORDRES.get(nom, nom)] = [(int(s), quete != "PLUS_TARD")
                                    for s, quete in re.findall(r'\{ (\d+), "[^"]+", (\w+), \d+,', bloc)]
    return lu


def serrures_de_recolte():
    """Serrures (Lock.dbc) des plantes et des filons : première clé de type « compétence » (2), herboristerie (2) ou
    minage (3). Les coffres et objets de quête qui demandent l'herboristerie en deuxième clé n'en sont pas."""
    sys.path.insert(0, ICI)
    import dbc
    return {r[0] for r in dbc.Dbc.ouvrir(LOCK).enregistrements if r[1] == 2 and r[9] in (2, 3)}


def relire(zone):
    """La zone telle que le jeu la contient, sous la forme du gabarit (seulement ce qui se relit). Tant que la zone
    n'a pas de parts en base (« construite » faux), seuls la récolte, les techniques et le donjon se relisent."""
    z = zone["zone"]
    parts = {int(g): int(p) / 100 for g, p in sql(f"SELECT genre, SUM(part) FROM solazeroth_v3_zone_parts "
                                                  f"WHERE zone = {z} GROUP BY genre")}
    serrures = ", ".join(map(str, sorted(serrures_de_recolte())))
    carte = zone["donjon"]["carte"]
    seuil = sql(f"SELECT zone, seuil FROM solazeroth_v3_donjons_seuils WHERE carte = {carte}")
    lu = {
        "construite": bool(parts),
        "recolte": {o for (o,) in sql(f"SELECT DISTINCT id FROM gameobject WHERE zoneId = {z}")},
        "noeuds": {o for (o,) in sql(f"SELECT DISTINCT g.id FROM gameobject g JOIN gameobject_template t "
                                     f"ON t.entry = g.id WHERE g.zoneId = {z} AND t.type = 3 "
                                     f"AND t.data0 IN ({serrures})")},
        "techniques": techniques_du_kit(),
        "entree": bool(sql(f"SELECT 1 FROM areatrigger_teleport WHERE target_map = {carte} LIMIT 1")),
        "seuil": (int(seuil[0][0]), int(seuil[0][1]) / 100) if seuil else None,
    }
    if not parts:
        return lu
    # Genres de solazeroth_v3_zone_parts : 1 quête, 2 sous-zone, 3 lieu, 4 annexe à donneur, 5 relique. Annexes,
    # reliques et lieux : les tables n'ont pas encore de colonne de zone (tout est à Durotar).
    lignes = sql("SELECT cle, eclats, insignes FROM solazeroth_v3_annexes")
    numeros = sorted({int(c[1:]) for c, _, _ in lignes})
    bareme = {}
    for famille, (n0, n1) in {"primes": (11, 19), "contrats": (20, 24), "defis": (25, 30)}.items():
        dans = [l for l in lignes if n0 <= int(l[0][1:]) <= n1]
        nombre = len({l[0] for l in dans})
        bareme[famille] = (round(sum(int(l[1]) for l in dans) / nombre), round(sum(int(l[2]) for l in dans) / nombre))
    texte = open(BIVOUAC, encoding="utf-8").read()
    feu = int(re.search(r"RANG_FEU_MAX = (\d+)", texte).group(1))
    potion = int(re.search(r"RANG_POTION_MAX = (\d+)", texte).group(1))
    couts = {int(g): (int(a), int(b)) for g, a, b in
             sql("SELECT genre, MIN(rang), MAX(rang) FROM solazeroth_v3_camp_couts GROUP BY genre")}
    lu.update({
        "parts": {"histoire": parts.get(1, 0), "exploration": parts.get(2, 0), "lieux": parts.get(3, 0),
                  "annexes": parts.get(4, 0), "reliques": parts.get(5, 0)},
        "annexes": {
            "lieux": int(sql("SELECT COUNT(DISTINCT lieu) FROM solazeroth_v3_lieux_monstres")[0][0]),
            "primes": sum(11 <= n <= 19 for n in numeros), "contrats": sum(20 <= n <= 24 for n in numeros),
            "defis": sum(25 <= n <= 30 for n in numeros),
            "reliques": int(sql("SELECT COUNT(*) FROM solazeroth_v3_reliques")[0][0]),
        },
        "plats": int(sql(f"SELECT COUNT(*) FROM solazeroth_v3_plats WHERE zone = {z}")[0][0]),
        # Rangs : RANG_*_MAX de v3_bivouac.cpp. Coûts : genre 1 la potion, genre 2 le feu (rang 1 du feu contre
        # des Marques, sans ligne de coût).
        "camp": {"feu": (1, feu), "potion": (1, potion)},
        "couts": {"feu": couts.get(2), "potion": couts.get(1)},
        "bareme": bareme,
    })
    return lu


def comparer(zone, lu, precedentes):
    """Écarts entre le gabarit de la zone et le jeu. precedentes : les zones d'avant (rang des techniques)."""
    d = zone
    ecarts = []
    declares = d["recolte"]["filons"] + d["recolte"]["plantes"]
    for o in declares:
        if str(o) not in lu["recolte"]:
            ecarts.append(f"récolte : {o} n'apparaît pas dans la zone {d['zone']}")
    for o in sorted(lu["noeuds"] - {str(x) for x in declares}, key=int):
        ecarts.append(f"récolte : {o} (plante ou filon de la zone {d['zone']}) manque au gabarit")
    # Les listes de v3_kit.cpp mettent les techniques de chaque zone à la suite de celles des zones précédentes.
    for spe in sorted(set(lu["techniques"]) | set(d["specialisations"])):
        gabarit = d["specialisations"].get(spe, {}).get("techniques")
        debut = sum(len(p["specialisations"].get(spe, {}).get("techniques", [])) for p in precedentes)
        tranche = lu["techniques"].get(spe, [])[debut:debut + len(gabarit or [])]
        if [s for s, _ in tranche] != gabarit:
            ecarts.append(f"techniques ({spe}) : gabarit {gabarit}, v3_kit.cpp {[s for s, _ in tranche] or None}")
        elif lu["construite"] and not all(ouverte for _, ouverte in tranche):
            ecarts.append(f"techniques ({spe}) : {[s for s, o in tranche if not o]} encore « PLUS_TARD »")
    if not lu["entree"]:
        ecarts.append(f"donjon : aucune entrée (areatrigger_teleport) vers la carte {d['donjon']['carte']}")
    if lu["seuil"] is not None and lu["seuil"] != (d["zone"], d["donjon"]["seuil"]):
        ecarts.append(f"donjon : seuil du gabarit {d['donjon']['seuil']} % de la zone {d['zone']}, table "
                      f"{lu['seuil'][1]:g} % de la zone {lu['seuil'][0]}")
    if lu["construite"] and lu["seuil"] is None:
        ecarts.append(f"donjon : pas de seuil dans solazeroth_v3_donjons_seuils pour la carte {d['donjon']['carte']}")
    if not lu["construite"]:
        return ecarts
    attendu = {"histoire": d["parts"]["histoire"], "exploration": d["parts"]["exploration"],
               "lieux": d["parts"]["lieux"], "reliques": d["parts"]["reliques"],
               "annexes": d["parts"]["primes"] + d["parts"]["contrats"] + d["parts"]["defis"]}
    for k, v in attendu.items():
        if abs(lu["parts"][k] - v) > 1e-6:
            ecarts.append(f"part {k} : gabarit {v:g} %, jeu {lu['parts'][k]:g} %")
    for k, v in d["annexes"].items():
        if lu["annexes"][k] != v:
            ecarts.append(f"annexes {k} : gabarit {v}, jeu {lu['annexes'][k]}")
    if lu["bareme"] != d["bareme"]:
        ecarts.append(f"barème : gabarit {d['bareme']}, jeu {lu['bareme']}")
    if lu["plats"] != d["plats"]:
        ecarts.append(f"plats : gabarit {d['plats']}, jeu {lu['plats']}")
    if lu["camp"] != d["camp"]:
        ecarts.append(f"camp : gabarit {d['camp']}, v3_bivouac.cpp {lu['camp']}")
    # Chaque rang de la zone a son coût en base (sauf le feu 1, en Marques).
    for g, (r0, r1) in d["camp"].items():
        bas = max(r0, 2) if g == "feu" else r0
        if lu["couts"][g] is None or lu["couts"][g][0] > bas or lu["couts"][g][1] < r1:
            ecarts.append(f"camp : {g} {bas} à {r1} sans coût complet en base ({lu['couts'][g]})")
    return ecarts


def main():
    erreurs = []
    precedentes = []
    print("1. Zones relues dans le jeu, comparées au gabarit")
    for zone in ZONES:
        if zone["zone"] is None:
            continue
        lu = relire(zone)
        ecarts = comparer(zone, lu, precedentes)
        etat = "" if lu["construite"] else " (pas encore construite : récolte, techniques et donjon seulement)"
        print(f"  {zone['nom']}{etat} : " + ("conforme" if not ecarts else f"{len(ecarts)} écart(s)"))
        for e in ecarts:
            print("    écart : " + e)
        erreurs += ecarts
        precedentes.append(zone)
    print("\n2. Emboîtement des zones")
    precedente = None
    for zone in ZONES:
        zone["_precedente"] = precedente
        e = verifier(zone, precedente)
        erreurs += e
        reste = a_remplir(zone)
        p0, p1 = zone["plage"]
        print(f"  {zone['nom']} ({p0}-{p1}) : " + ("emboîtée" if not e else f"{len(e)} erreur(s)")
              + (f" ; à remplir : {', '.join(reste)}" if reste else ""))
        for ligne in e:
            print("    " + ligne)
        precedente = zone
    print("\n3. Fiches d'arrivée et de sortie (fiches_zones.py)")
    import fiches_zones
    e, lignes = fiches_zones.verifier()
    for l in lignes:
        print("  " + l)
    for l in e:
        print("  erreur : " + l)
    erreurs += e
    print("\nAucun problème trouvé." if not erreurs else f"\n{len(erreurs)} problème(s).")
    return 1 if erreurs else 0


if __name__ == "__main__":
    sys.exit(main())
