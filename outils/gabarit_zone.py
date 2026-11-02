"""Audit du jeu, lot 7 (02/11/2026) : gabarit de zone, à remplir avant chaque nouvelle zone (P8 du game designer
systèmes ; choix de l'utilisateur : « gabarit + vérificateur », sans regénérer les migrations de Durotar).

Une zone se décrit par un dictionnaire (voir DUROTAR) :
- plage de puissance et secteurs (début et fin en % de zone, puissance des monstres, niveau d'objet du nouvel
  équipement) ;
- parts du pourcentage par source, et nombre d'annexes par famille ;
- barème des récompenses d'annexe (éclats et Marques par famille, à la puissance 12 ou moins) ;
- plantes et filons (règle des zones de départ : de quoi débuter les métiers sans sortir) et plats ;
- rangs du camp et de la potion achetables dans la zone (règle « deux fois par zone », doc F5) ;
- emplacements et techniques ouverts, par spécialisation : ce sont les classes qui s'adaptent au monde (demande de
  l'utilisateur du 02/11/2026, en vue du démoniste) ;
- donjon ;
- économie (revenu par % de zone, filons) pour simulation_zones.py.
Une valeur None est « à remplir » : le vérificateur la liste à part, sans la compter comme une erreur.

Lancé seul (py gabarit_zone.py) :
1. relit Durotar dans la base et le code (zone_parts, annexes, camp, plats, filons et plantes, techniques de
   v3_kit.cpp) et la compare à sa description : le gabarit dit vrai sur la zone qui existe ;
2. vérifie l'emboîtement de Durotar, des Tarides (11-25, choix de l'utilisateur) et d'une zone 3 extrapolée (26-40).
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

FAMILLES = ("lieux", "primes", "contrats", "defis", "reliques")
SOURCES = ("histoire", "exploration") + FAMILLES
EMPLACEMENTS_MAX = 8                    # EQUIPEES_MAX (v3_kit.cpp)
RANGS_CAMP = {"feu": 2, "potion": 3}    # dernier rang achetable aujourd'hui (solazeroth_v3_camp_couts)

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
    "recolte": {"filons": [1731], "plantes": [1617, 1618, 1619, 1620]},
    "plats": 5,
    "camp": {"feu": (1, 2), "potion": (2, 3)},
    "specialisations": {
        "guerrier_tank": {"emplacements": (3, 5), "techniques": [100011, 100013, 100012, 100019, 100015, 100014, 100016]},
    },
    "donjon": {"nom": "Gouffre de Ragefeu", "carte": 389, "puissance": (10, 12)},
    # Revenu mesuré (simulation_rangs.py) ; filons présents à la fois (pools et filons seuls, filons_heure.py).
    "economie": {"eclats_par_pourcent": 18, "or_par_pourcent": 2700, "taille": 1.0, "filons_actifs": 53},
}


def extrapoler(base, nom, zone, plage, specialisations, recolte=None, donjon=None, taille=None):
    """Zone de même forme que base, ses puissances ramenées sur la nouvelle plage. Le camp prend les deux rangs
    suivants ; ce qui dépend de la zone réelle (récolte, plats, donjon) reste à remplir si on ne le donne pas."""
    a0, a1 = base["plage"]
    b0, b1 = plage

    def ramener(p):
        return round(b0 + (p - a0) * (b1 - b0) / (a1 - a0), 1)

    dernier = len(base["secteurs"])
    secteurs = [("Donjon et fin" if i == dernier else f"Secteur {i}", d, f, (ramener(p[0]), ramener(p[1])), ramener(niveau))
                for i, (_, d, f, p, niveau) in enumerate(base["secteurs"], 1)]
    economie = dict(base["economie"])
    # Une zone plus large (15 points au lieu de 10) a proportionnellement plus de monstres par % de zone.
    economie["taille"] = taille if taille is not None else base["economie"]["taille"] * (b1 - b0 + 1) / (a1 - a0 + 1)
    economie["filons_actifs"] = None
    camp = {g: (r[1] + 1, r[1] + 2) for g, r in base["camp"].items()}
    return {
        "nom": nom, "zone": zone, "plage": plage, "secteurs": secteurs,
        "parts": dict(base["parts"]), "annexes": dict(base["annexes"]), "bareme": dict(base["bareme"]),
        "recolte": recolte, "plats": None, "camp": camp, "specialisations": specialisations,
        "donjon": donjon or {"nom": None, "carte": None, "puissance": (b1, b1 + 2)}, "economie": economie,
    }


# Lot 3b (« Audit du jeu\lot_3b_deblocages_proposition.md ») : techniques et emplacements des zones suivantes.
TARIDES = extrapoler(DUROTAR, "Les Tarides", 17, (11, 25), {
    "guerrier_tank": {"emplacements": (5, 6), "techniques": [100020, 100018]},    # Fracasser armure, Mur protecteur
}, recolte={"filons": [1731, 1732, 1733], "plantes": [1617, 1618, 1619, 1620, 2041, 2045, 3729]})
TARIDES["economie"]["filons_actifs"] = 166   # filons_heure.py (cuivre, étain, argent de la zone 17)
ZONE_3 = extrapoler(TARIDES, "Zone 3 (fictive)", None, (26, 40), {
    "guerrier_tank": {"emplacements": (6, 6), "techniques": [100021, 100017]},    # Désarmement, Ravage
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
    for g, (r0, r1) in zone["camp"].items():
        if r1 - r0 != 1:
            erreurs.append(f"{nom} : {g} ouvre {r1 - r0 + 1} rangs, deux attendus")
    if precedente:
        if p0 != precedente["plage"][1] + 1:
            erreurs.append(f"{nom} : la plage commence à {p0}, la zone précédente finit à {precedente['plage'][1]}")
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
# Relecture de Durotar dans la base et le code
# ----------------------------------------------------------------------------------------------------------------
def sql(requete):
    r = subprocess.run([MYSQL, "--defaults-extra-file=" + CNF, "-N", "-B", "acore_world", "-e", requete],
                       capture_output=True, check=True)
    return [l.split("\t") for l in r.stdout.decode("utf-8").splitlines()]


def techniques_du_kit():
    """Techniques de v3_kit.cpp (ORDRE) ouvertes dès aujourd'hui, c'est-à-dire pas « PLUS_TARD »."""
    texte = open(KIT, encoding="utf-8").read()
    return [int(s) for s, quete in re.findall(r'\{ (\d+), "[^"]+", (\w+), \d+,', texte) if quete != "PLUS_TARD"]


def relire_durotar():
    """Durotar tel que le jeu le contient, sous la forme du gabarit (seulement ce qui se relit)."""
    z = DUROTAR["zone"]
    parts = {int(g): int(p) / 100 for g, p in sql(f"SELECT genre, SUM(part) FROM solazeroth_v3_zone_parts "
                                                  f"WHERE zone = {z} GROUP BY genre")}
    # Genres de solazeroth_v3_zone_parts : 1 quête, 2 sous-zone, 3 lieu, 4 annexe à donneur, 5 relique.
    lignes = sql("SELECT cle, eclats, insignes FROM solazeroth_v3_annexes")
    numeros = sorted({int(c[1:]) for c, _, _ in lignes})
    bareme = {}
    for famille, (n0, n1) in {"primes": (11, 19), "contrats": (20, 24), "defis": (25, 30)}.items():
        dans = [l for l in lignes if n0 <= int(l[0][1:]) <= n1]
        nombre = len({l[0] for l in dans})
        bareme[famille] = (round(sum(int(l[1]) for l in dans) / nombre), round(sum(int(l[2]) for l in dans) / nombre))
    lu = {
        "parts": {"histoire": parts.get(1, 0), "exploration": parts.get(2, 0), "lieux": parts.get(3, 0),
                  "annexes": parts.get(4, 0), "reliques": parts.get(5, 0)},
        "annexes": {
            "lieux": int(sql("SELECT COUNT(DISTINCT lieu) FROM solazeroth_v3_lieux_monstres")[0][0]),
            "primes": sum(11 <= n <= 19 for n in numeros), "contrats": sum(20 <= n <= 24 for n in numeros),
            "defis": sum(25 <= n <= 30 for n in numeros),
            "reliques": int(sql("SELECT COUNT(*) FROM solazeroth_v3_reliques")[0][0]),
        },
        "plats": int(sql(f"SELECT COUNT(*) FROM solazeroth_v3_plats WHERE zone = {z}")[0][0]),
        "camp": {g: (int(a), int(b)) for g, a, b in (
            (["feu", "potion"][int(genre) - 1], a, b) for genre, a, b in
            sql("SELECT genre, MIN(rang), MAX(rang) FROM solazeroth_v3_camp_couts GROUP BY genre"))},
        "recolte": {o for (o,) in sql(f"SELECT DISTINCT id FROM gameobject WHERE zoneId = {z}")},
        "techniques": techniques_du_kit(),
        "bareme": bareme,
    }
    return lu


def comparer_durotar(lu):
    d = DUROTAR
    ecarts = []
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
        ecarts.append(f"camp : gabarit {d['camp']}, jeu {lu['camp']}")
    for o in d["recolte"]["filons"] + d["recolte"]["plantes"]:
        if str(o) not in lu["recolte"]:
            ecarts.append(f"récolte : {o} n'apparaît pas dans la zone {d['zone']}")
    if lu["techniques"] != d["specialisations"]["guerrier_tank"]["techniques"]:
        ecarts.append(f"techniques : gabarit {d['specialisations']['guerrier_tank']['techniques']}, "
                      f"v3_kit.cpp {lu['techniques']}")
    return ecarts


def main():
    erreurs = []
    print("1. Durotar relu dans le jeu, comparé au gabarit")
    ecarts = comparer_durotar(relire_durotar())
    print("\n".join("  écart : " + e for e in ecarts) or "  conforme")
    erreurs += ecarts
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
    print("\nAucun problème trouvé." if not erreurs else f"\n{len(erreurs)} problème(s).")
    return 1 if erreurs else 0


if __name__ == "__main__":
    sys.exit(main())
