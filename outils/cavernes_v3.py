"""Lot T5 des Tarides (03/11/2026) : les Cavernes des Lamentations (carte 43, zone 718 ; brouillon des Tarides, §3,
§4.7.4 et §5.3).

- Puissance : 30 pour les monstres ordinaires (rang 0), 31 pour les élites (rang 1) et le Dragon féerique déviant
  (rare, rang 2), 32 pour les huit boss (Mutanus le Dévoreur compris). Puissance fixe par entrée
  (solazeroth_v3_puissance_entrees, fixe = 1) : la courbe des monstres s'y applique (v3_niveau.cpp).
- Calibrage par entrée (solazeroth_v3_courbe_entrees, vie et dégâts × k) : le guerrier de fin de zone (pièces vertes des
  Tarides de puissance 30 au rang 2, Repos du feu 3) gagne CIBLE % contre une paire de l'entrée (sans potion), ou contre
  un boss ou le rare seul (potion rang 2) ; le même au rang 3 doit atteindre SEREIN %, sinon k descend jusque-là. La peur (aura 7) compte comme un
  étourdissement de même durée, ici seulement (Mutanus).
- Packs de 2 au plus (apparitions à moins de RAYON m), comme le Gouffre ; un boss reste seul. Tables de retour.
- Donjon : Graine de cauchemar (910191), taux de 10 % par boss et par difficulté (colonne taux de
  solazeroth_v3_donjons_composants), Mutanus déclaré boss (solazeroth_v3_donjons_bosses : il n'a pas d'apparition),
  pierres taillées des Tarides sur le dernier boss (solazeroth_v3_donjons_pierres).
- Pièces bleues des Lamentations (910600 à 910631, puissance 34, ouvertes à 30), recettes du §4.7.4, rangs 1 à 5 ;
  panoplie des Lamentations (solazeroth_v3_panoplies, sorts 101612 à 101614), qui ne se cumule pas avec celle du Gouffre.
- Ebru (5768) : seuil des Cavernes (60 % des Tarides et T30 rendue). Le Disciple de Naralex (3678) passe à
  npc_solazeroth_v3_disciple (escorte en solo, v3_gouffre.cpp) ; Mocassins et Ectoplasmes appelés sans SmartAI.
- Quêtes T31 à T36 (910071 à 910076) par le générateur de Durotar, récompenses 910791 à 910794 et leurs versions ;
  quêtes d'origine des Cavernes retirées (dont 6981 : l'Éclat luminescent ne la lance plus).
Tout ce qui touche à Blizzard a sa table de retour (solazeroth_v3_t5_*).

py cavernes_v3.py              écrit la migration 146, SolUI_RecettesCavernes.lua, l'Item.dbc et les listes de l'interface
py cavernes_v3.py --verifier   relit la base : calibrage, démoniste et voleur, bleues contre la fiche de sortie (34)
"""
import copy
import math
import os
import re
import sys

ICI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ICI)
import artisanat_tarides as at
import enchantement_v3 as en
import equipement_v3 as e3
import quetes_durotar as qd
import quetes_tarides as qt
from quetes_durotar import s, sql

BROUILLON = at.BROUILLON
MIGRATION = os.path.join(ICI, "..", "sql", "migrations", "146_v3_cavernes")
LUA = os.path.join(ICI, "..", "interface-v3", "FrameXML", "SolUI_RecettesCavernes.lua")
CARTE, ZONE_CAVERNES, TARIDES = 43, 718, 17
NIVEAU_MENU = "Cavernes"

# --- Monstres -------------------------------------------------------------------------------------------------------
EXCLUS = {3678, 3679, 2914, 3835}           # disciple, Naralex, bestioles
APPELES = {5762, 5763, 3654}                # appelés par l'escorte (sans apparition)
BOSS = {3653, 3669, 3670, 3671, 3673, 3674, 5775, 3654}
RARE = 5912
PUISSANCE = {0: 30, 1: 31, 2: 31}           # par rang ; les boss à 32
PUISSANCE_BOSS = 32
RAYON, PAR_PACK = 12.0, 2
CIBLE, SEREIN = 70, 95
N = 300
K_BAS, K_HAUT = 0.1, 4.0

# --- Donjon ---------------------------------------------------------------------------------------------------------
GRAINE, GRAINE_SOURCE = 910191, 17034       # Graine d'érable : apparence et type
TAUX, PUISSANCE_MIN = 10, 15
TAUX_GOUFFRE = 15
PIERRES = {389: [910180, 910181, 910182], CARTE: [910183, 910184, 910185]}
PANOPLIES = [(1, 910241, 910273, 101600, 101601, 101602, "Gouffre de Ragefeu"),
             (2, 910600, 910631, 101612, 101613, 101614, "Cavernes des Lamentations")]
SORTS_PANOPLIE = (101612, 101613, 101614)

# --- Pièces bleues --------------------------------------------------------------------------------------------------
PREMIERE, BLEUES = 910600, 34
REQUISE = 30
ECLAT, AGATE, JADE_TAILLE = 910120, 1206, 910184
MATERIAUX = {"Graine": GRAINE, "Graines": GRAINE, "Écailles de déviant": 6470, "laine": 2592, "étain": 2771,
             "argent": 2775, "éclats": ECLAT, "Agate mousse": AGATE, "Jade taillé": JADE_TAILLE,
             "Jades taillés": JADE_TAILLE}
ORDRE_ARMES = ["cape", "bouclier", "orbe", "épée", "hache", "masse", "dague", "bâton"]
RENOMMER = {("cuir", "Brassards des Lamentations"): "Brassards en cuir des Lamentations"}
CATEGORIES = [("maille", "Cavernes : maille", True), ("cuir", "Cavernes : cuir", False),
              ("tissu", "Cavernes : tissu", False), ("armes", "Cavernes : armes", True),
              ("mains", "Cavernes : cape et orbe", False)]

# --- Ebru et l'escorte ----------------------------------------------------------------------------------------------
EBRU, DISCIPLE, TEXTE_EBRU = 5768, 3678, 910002
ARRIVEE = (-163.49, 132.9, -73.66, 5.83)    # areatrigger_teleport 228
T30 = 910070
SEUIL = (CARTE, TARIDES, 6000, T30, EBRU, TEXTE_EBRU) + ARRIVEE + (
    "Descendre dans les Cavernes.",
    "Falla Vent-de-sagesse doit d'abord t'envoyer, depuis le sommet de la colline.",
    "Les Tarides ne parlent pas encore assez de toi : {pourcent} de la zone. Reviens à {seuil}.",
    "Les Cavernes des Lamentations se passent par Ebru, dans la grotte des disciples, au-dessus de l'entrée. ")
TEXTE = ("Les Cavernes des Lamentations sont sous nos pieds. Personne ne descend sans avoir prouvé qu'il connaît la "
         "savane.")
SCRIPT_SEUIL, SCRIPT_DISCIPLE = "npc_solazeroth_v3_seuil", "npc_solazeroth_v3_disciple"

# --- Quêtes ---------------------------------------------------------------------------------------------------------
ENTREE = (-740, -2214)                      # fond de la grotte d'entrée : la carte 43 n'a pas de carte du monde
COMMENTAIRE = "Sol''Azeroth v3 : quete d''origine des Cavernes"
ECLAT_LUMINESCENT, ECLAT_CAUCHEMAR = 10441, 10649
Q = {
    31: dict(de=5767, a=5767, p=30, prev=[30], tri=ZONE_CAVERNES, objets=[(6443, 10, (-654, -2175))],
             resume="Rapporte 10 Peaux de déviant à Nalpak, prises aux déviants de la grotte d'entrée."),
    32: dict(de=EBRU, a=EBRU, p=31, prev=[30], tri=ZONE_CAVERNES, marques=10,
             tuer=[(3636, 5, ENTREE), (5755, 5, ENTREE), (5761, 5, ENTREE), (5056, 5, ENTREE)],
             resume="Dans les Cavernes, tue 5 Ravageurs, 5 Vipères, 5 Traînards et 5 Crocs-d'effroi déviants."),
    33: dict(de=3390, a=3390, p=31, prev=[30], tri=ZONE_CAVERNES, objets=[(5339, 8, ENTREE)],
             resume="Rapporte 8 Fleurs de serpent des Cavernes à l'apothicaire Helbrim."),
    34: dict(de=8418, a=8418, p=32, prev=[30], tri=ZONE_CAVERNES,
             objets=[(9738, 1, ENTREE), (9739, 1, ENTREE), (9740, 1, ENTREE), (9741, 1, ENTREE)],
             resume="Rapporte à Falla les gemmes de Cobrahn, d'Anacondra, de Pythas et de Serpentis."),
    35: dict(de=EBRU, a=8418, p=32, prev=[30], tri=ZONE_CAVERNES, marques=10,
             tuer=[(3654, 1, ENTREE)], objets=[(ECLAT_LUMINESCENT, 1, ENTREE)],
             resume="Accompagne le Disciple de Naralex jusqu'au bassin, tue Mutanus le Dévoreur et porte l'Éclat "
                    "luminescent à Falla."),
    36: dict(de=8418, a=3448, p=30, prev=[34, 35], tri=TARIDES, marques=10, depart=ECLAT_CAUCHEMAR,
             objets=[(ECLAT_CAUCHEMAR, 1, (-545, -2673))],
             resume="Porte l'Éclat de cauchemar à Tonga Totem-runique, à la Croisée."),
}
# Récompenses : (entrée, quête, nom, genre pour choisir_source)
RECOMPENSES = [
    (910791, 31, "Cape en peau saine", (4, (1,), (16,))),
    (910792, 33, "Épaulières de la fleur de serpent", (4, (3,), (3,))),
    (910793, 34, "Jambières des traîtres du Croc", (4, (3,), (7,))),
    (910794, 36, "Lame de la savane guérie", (2, (7,), (13,))),
]
GENRES = {910791: "cape", 910792: 3, 910793: 7, 910794: "arme"}
PREMIERES = (910795, 910799, 910797, 910800)   # tissu, dague, cuir, dague de main gauche

ZONE = dict(nom="Cavernes des Lamentations", prefixe="T", doc=BROUILLON, base=qt.QUETE, quetes=Q, tri=ZONE_CAVERNES,
            carte=qt.CARTE_TARIDES, recompenses={q: e for e, q, *_ in RECOMPENSES},
            origine_ou="map = %d OR (map = 1 AND zoneId = %d)" % (CARTE, ZONE_CAVERNES), origine_tri=(ZONE_CAVERNES,),
            commentaire=COMMENTAIRE)


def sources_recompenses():
    return {e: at.choisir_source(c, sc, t, Q[q]["p"]) for e, q, _, (c, sc, t) in RECOMPENSES}


def jeu(sources=None):
    """Jeu de pièces des quêtes des Cavernes (quetes_tarides : pieces_sql, lignes_dbc, versions)."""
    sources = sources or sources_recompenses()
    return dict(recompenses=[(e, Q[q]["p"], nom, sources[e]) for e, q, nom, _ in RECOMPENSES],
                premieres=PREMIERES, genres=GENRES)


# --- Monstres : liste, puissance, packs -------------------------------------------------------------------------------

def monstres():
    """{entrée: (nom, rang, minlevel, maxlevel, puissance)} des monstres de la carte 43 et des appelés."""
    sortie = {}
    for e, nom, rang, bas, haut in sql(
            "SELECT entry, name, `rank`, minlevel, maxlevel FROM acore_world.creature_template WHERE entry IN "
            "(SELECT id FROM acore_world.creature WHERE map = %d) OR entry IN (%s)"
            % (CARTE, ", ".join(map(str, sorted(APPELES))))):
        e = int(e)
        if e in EXCLUS:
            continue
        p = PUISSANCE_BOSS if e in BOSS else PUISSANCE[int(rang)]
        sortie[e] = (nom, int(rang), int(bas), int(haut), p)
    return sortie


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


def retraits(liste):
    """Apparitions retirées : packs de PAR_PACK au plus, les plus proches du centre ; un boss reste seul."""
    apparitions = [(int(g), int(i), float(x), float(y), float(z)) for g, i, x, y, z in sql(
        "SELECT guid, id, position_x, position_y, position_z FROM acore_world.creature WHERE map = %d AND id IN (%s)"
        % (CARTE, ", ".join(map(str, sorted(liste)))))]
    retirees = []
    for groupe in packs(apparitions):
        cx = sum(a[2] for a in groupe) / len(groupe)
        cy = sum(a[3] for a in groupe) / len(groupe)
        groupe.sort(key=lambda a: (a[1] not in BOSS and a[1] != RARE, math.hypot(a[2] - cx, a[3] - cy)))
        garde = len([a for a in groupe if a[1] in BOSS]) or PAR_PACK
        retirees += [a[0] for a in groupe[garde:]]
    restent = {}
    for g, i, *_ in apparitions:
        if g not in retirees:
            restent[i] = restent.get(i, 0) + 1
    return apparitions, sorted(retirees), restent


# --- Calibrage ------------------------------------------------------------------------------------------------------

def peur_comme_etourdi(ss):
    """La peur (aura 7) compte comme un étourdissement de même durée (10 s au plus), pour ce calibrage seulement."""
    if getattr(ss.effets, "peur", False):
        return
    origine = ss.effets

    def effets(sid, niveau, classe, cible_script):
        sortie = origine(sid, niveau, classe, cible_script)
        e = ss.enregistrement(sid)
        if e:
            for i in range(3):
                if e[71 + i] in (6, 27, 35) and e[95 + i] == 7:
                    sortie.append(("etourdi", ss.ENNEMI, 0, min(ss.duree(e), 10.0), None))
        return sortie
    effets.peur = True
    ss.effets = effets


def joueurs_fin(rang):
    """(guerrier, démoniste, voleur) de fin de zone : vertes des Tarides de puissance 30, à ce rang."""
    import fiches_zones as fz
    import simulation_vertes_tarides as svt
    vertes = list(range(svt.PREMIERE, svt.DERNIERE + 1))
    infos = svt.objets(vertes + [e for l in fz.GOUFFRE.values() for e in l])
    req = svt.requises()
    pieces = {spe: svt.panoplie(spe, 30, vertes, infos, req)[0] for spe in fz.SPECIALISATIONS}
    return svt.joueurs_reels(svt.au_rang(pieces, rang))


def seul(e):
    return e in BOSS or e == RARE


def regler(taux, cible=CIBLE, haut=K_HAUT):
    """Le facteur k qui donne cible % de victoires ; taux(k) décroît avec k."""
    bas = K_BAS
    if taux(haut) > cible:
        return haut
    for _ in range(14):
        k = (bas + haut) / 2
        if taux(k) > cible:
            bas = k
        else:
            haut = k
    return round((bas + haut) / 2, 2)


def guerrier_contre(ss, te, g, m, e, k=None):
    """Victoires du guerrier : paire de l'entrée sans potion, ou boss / rare seul avec la potion. k : facteur de vie et
    de dégâts sur la courbe (None : le monstre tel quel, courbe déjà appliquée)."""
    import simulation_combat as sim
    if k is not None:
        cv, cd = sim.courbe(m.puissance)
        m = ss.courber(copy.deepcopy(m), (cv * k, cd * k))
    if seul(e):
        return ss.simuler(g, m, N, potion=te.POTION_TARIDES, heurt=te.HEURT)["victoire"]
    return ss.simuler(g, [m, copy.deepcopy(m)], N, heurt=te.HEURT)["victoire"]


def calibrer(liste):
    import simulation_sorts as ss
    import tests_equilibrage as te
    peur_comme_etourdi(ss)
    g60, _, _ = joueurs_fin(2)
    g100, _, _ = joueurs_fin(3)
    print("Guerrier de fin de zone : vie %d, puissance %.1f (rang 2) ; vie %d (rang 3)" % (g60.vie, g60.puissance,
                                                                                         g100.vie))
    k = {}
    for e, (nom, rang, _, _, p) in sorted(liste.items(), key=lambda kv: (kv[1][4], kv[0])):
        m = ss.monstre_avec_sorts(e, p, contact=True)
        k[e] = regler(lambda x: guerrier_contre(ss, te, g60, m, e, x))
        serein = ""
        if guerrier_contre(ss, te, g100, m, e, k[e]) < SEREIN:
            # Un rang de plus doit suffire : le facteur descend jusqu'à SEREIN % au rang 3.
            k[e] = regler(lambda x: guerrier_contre(ss, te, g100, m, e, x), SEREIN, k[e])
            while k[e] > K_BAS and guerrier_contre(ss, te, g100, m, e, k[e]) < SEREIN:
                k[e] = round(k[e] - 0.01, 2)      # l'arrondi de la dichotomie peut tomber du mauvais côté
            serein ="  (abaissé pour %d %% au rang 3)" % SEREIN
        t60 = guerrier_contre(ss, te, g60, m, e, k[e])
        t100 = guerrier_contre(ss, te, g100, m, e, k[e])
        print("  %-24s P%d %-6s x %.2f : %3.0f %% (rang 2), %3.0f %% (rang 3)%s" % (
            nom[:24], p, "seul" if seul(e) else "paire", k[e], t60, t100, serein))
    return k


# --- Pièces bleues --------------------------------------------------------------------------------------------------

def composants(texte):
    """« 3 Graines, 20 étain, 160 éclats, 1 Jade taillé » -> [(objet, n)]."""
    liste = []
    for morceau in texte.split(","):
        n, nom = re.fullmatch(r"\s*(\d+) (.+?)\s*", morceau).groups()
        liste.append((MATERIAUX[nom], int(n)))
    assert len(liste) <= 4, texte
    return liste


def lire():
    """Recettes du §4.7.4 : [(catégorie, nom, prix, composants, (classe, sous-classes, InventoryType), forge)], maille,
    cuir, tissu (dans l'ordre des emplacements), puis les armes et mains gauches dans l'ordre ORDRE_ARMES."""
    texte = open(BROUILLON, encoding="utf-8").read()
    section = texte[texte.index("#### 4.7.4"):texte.index("#### 4.7.5")]
    armures = {f: [] for f, _, _ in at.FAMILLES}
    armes = {}
    commun = None
    for ligne in section.splitlines():
        m = re.match(r"Armures \(chacune : (.+) ; (\d+ po(?: \d+ pa)?)\) :", ligne)
        if m:
            commun = (m.group(1), m.group(2))
        cellules = [c.strip() for c in ligne.strip().strip("|").split("|")]
        if len(cellules) == 4 and cellules[0] in [e[0] for e in at.EMPLACEMENTS]:
            emplacement = next(e for e in at.EMPLACEMENTS if e[0] == cellules[0])
            for (famille, sous, forge), cellule in zip(at.FAMILLES, cellules[1:4]):
                nom, _, materiau = cellule.partition(" : ")
                nom = RENOMMER.get((famille, nom), nom)
                n, mat = re.fullmatch(r"(\d+) (.+)", materiau).groups()
                base = commun[0].replace("le matériau", "%s %s" % (n, mat))
                types = (20, 5) if emplacement[1] == (5, 20) and sous == 1 else emplacement[1][:1]
                armures[famille].append((famille, nom, prix_or(commun[1]), composants(base), (4, (sous,), types),
                                         forge))
        elif len(cellules) == 4 and re.match(r".+ \((\w+)\)$", cellules[0]) and cellules[1] in ("oui", "non"):
            nom, genre = re.fullmatch(r"(.+) \((.+)\)", cellules[0]).groups()
            classe, sous, types, forge = at.ARMES[genre]
            assert forge == (cellules[1] == "oui"), ligne
            armes[genre] = ("armes" if forge else "mains", nom, prix_or(cellules[3]), composants(cellules[2]),
                            (classe, sous, types), forge)
    recettes = [r for f, _, _ in at.FAMILLES for r in armures[f]] + [armes[g] for g in ORDRE_ARMES]
    assert len(recettes) == 32, len(recettes)
    return recettes


def prix_or(texte):
    m = re.fullmatch(r"(\d+) po(?: (\d+) pa)?", texte.strip())
    return int(m.group(1)) * 10000 + int(m.group(2) or 0) * 100


def pieces():
    """[(entrée, catégorie, nom, prix, composants, source, forge)]."""
    return [(PREMIERE + i, cat, nom, prix, c, at.choisir_source(*genre, BLEUES), forge)
            for i, (cat, nom, prix, c, genre, forge) in enumerate(lire())]


def lignes_dbc():
    """(entrée, entrée copiée, genre) pour l'Item.dbc du patch : la Graine, les pièces bleues et leurs rangs, puis les
    récompenses des quêtes et leurs versions. Les sources sont lues dans SolUI_RecettesCavernes.lua (commentaire
    « sources »), écrit par main(), pour se passer de la base."""
    sources = _sources_lues()
    if not sources:
        return []
    lignes = [(GRAINE, GRAINE_SOURCE, None)]
    for e in range(PREMIERE, PREMIERE + 32):
        lignes.append((e, sources[e], None))
    for e in range(PREMIERE, PREMIERE + 32):
        lignes += [(e3.entree_rang(e, r), e, None) for r in range(1, e3.RANGS + 1)]
    j = dict(recompenses=[(e, Q[q]["p"], nom, sources[e]) for e, q, nom, _ in RECOMPENSES],
             premieres=PREMIERES, genres=GENRES)
    return lignes + qt.lignes_dbc(j)


def _sources_lues():
    if not os.path.exists(LUA):
        return {}
    m = re.search(r"^-- sources : (.+)$", open(LUA, encoding="utf-8").read(), re.M)
    return {int(a): int(b) for a, b in (x.split("=") for x in m.group(1).split())} if m else {}


def jeu_lu():
    """Le jeu des récompenses avec les sources écrites (versions de SolUI_Versions.lua, sans base)."""
    sources = _sources_lues()
    return jeu(sources) if sources else None


def sorts(d):
    """Sorts de la panoplie des Lamentations (Spell.dbc), comme bonus_v3.lignes."""
    import bonus_v3 as b
    from techniques_v3 import AURA, AURA_FACTICE, DEGATS_INFLIGES, DEGATS_SUBIS, SOI, effet
    icone = d.chercher(b.BIEN_NOURRI)[133]
    t = []
    s2, s4, s6 = SORTS_PANOPLIE
    e = b.permanente(d, s2, "Panoplie des Lamentations (2)", "Dégâts infligés augmentés de 3 %.", icone)
    effet(e, 0, AURA, 3, SOI, aura=DEGATS_INFLIGES, misc=b.TOUTES)
    t.append(e)
    e = b.permanente(d, s4, "Panoplie des Lamentations (4)", "Dégâts subis réduits de 5 %.", icone)
    effet(e, 0, AURA, -5, SOI, aura=DEGATS_SUBIS, misc=b.TOUTES)
    t.append(e)
    e = b.permanente(d, s6, "Panoplie des Lamentations (6)", "3 % des dégâts infligés rendus en vie.", icone)
    effet(e, 0, AURA, 0, SOI, aura=AURA_FACTICE)
    t.append(e)
    return t


def lua(t):
    return '"' + t.replace("\\", "\\\\").replace('"', '\\"') + '"'


# --- La migration ---------------------------------------------------------------------------------------------------

def main():
    import auras_nommees
    import dbc
    from hauts_faits_natifs import DBC_SERVEUR
    import tissu_v3
    liste = monstres()
    apparitions, retirees, restent = retraits([e for e in liste if e not in APPELES])
    print("Apparitions : %d, dont %d retirées (packs de %d au plus, rayon %.0f m, boss seuls)"
          % (len(apparitions), len(retirees), PAR_PACK, RAYON))
    for e, n, *_ in Q[32]["tuer"]:
        assert restent.get(e, 0) >= n, (e, restent.get(e, 0))
    print("T32 : il reste %s" % ", ".join("%d × %d" % (restent[e], e) for e, *_ in Q[32]["tuer"]))
    k = calibrer(liste)

    armures, armes = __import__("equipement_gouffre_v3").baremes()
    bleues = pieces()
    sources = e3.objets({p[5] for p in bleues})
    entrees = [p[0] for p in bleues]
    tout = ", ".join(map(str, entrees))
    rangs = [e3.entree_rang(e, r) for e in entrees for r in range(1, e3.RANGS + 1)]
    src_rec = sources_recompenses()
    j = jeu(src_rec)
    textes = qd.lire_textes(ZONE)
    interdit = re.compile(r"\b(épées?|boucliers?|heaumes?|gantelets?|guerrier|guerrière|démoniste|voleur|voleuse)\b")
    for n, t in textes.items():
        for champ, texte in t.items():
            assert not interdit.search(texte.lower()), (n, champ)
    origine = qd.quetes_d_origine(ZONE)
    assert 6981 in origine, origine
    pos = qd.positions(ZONE)
    ids = sorted(qd.ident(ZONE, n) for n in Q)
    quetes = ", ".join(map(str, ids))
    garde = ", ".join(map(str, retirees))
    pnj = ", ".join(map(str, (EBRU, DISCIPLE, 5762, 5763)))
    entrees_monstres = ", ".join(map(str, sorted(liste)))

    up, down = [], []
    w = up.append
    w("-- Lot T5 des Tarides (03/11/2026) : les Cavernes des Lamentations. Généré par outils\\cavernes_v3.py : ne pas")
    w("-- modifier à la main. Durotar et le Gouffre ne changent pas.")
    w("SET SESSION sql_mode = '';")
    w("USE acore_world;")
    w("")
    w("-- Puissance fixe par entrée (30 ordinaires, 31 élites et rare, 32 boss) ; la courbe s'y applique.")
    w("DELETE FROM solazeroth_v3_puissance_entrees WHERE entree IN (%s);" % entrees_monstres)
    w("INSERT INTO solazeroth_v3_puissance_entrees VALUES %s;" % ", ".join(
        "(%d, %d, 1, 0, %d, %d, %d, %d)" % (e, ZONE_CAVERNES, b, h, p, p) for e, (_, _, b, h, p) in sorted(liste.items())))
    w("-- Calibrage par entrée (vie et dégâts × k sur la courbe) : guerrier de fin de zone à %d %% (paires, ou boss et" % CIBLE)
    w("-- rare seuls avec la potion).")
    w("DELETE FROM solazeroth_v3_courbe_entrees WHERE entree IN (%s);" % entrees_monstres)
    w("INSERT INTO solazeroth_v3_courbe_entrees VALUES %s;" % ", ".join(
        "(%d, %.2f, %.2f)" % (e, k[e], k[e]) for e in sorted(k)))
    w("-- Packs de %d au plus (rayon %.0f m), boss seuls : %d apparitions retirées." % (PAR_PACK, RAYON, len(retirees)))
    w("CREATE TABLE solazeroth_v3_t5_apparitions SELECT * FROM creature WHERE guid IN (%s);" % garde)
    w("CREATE TABLE solazeroth_v3_t5_apparitions_addon SELECT * FROM creature_addon WHERE guid IN (%s);" % garde)
    w("DELETE FROM creature_addon WHERE guid IN (%s);" % garde)
    w("DELETE FROM creature WHERE guid IN (%s);" % garde)
    w("")
    w("-- Donjon : taux du composant par carte, boss sans apparition, pierres du dernier boss, panoplies.")
    w("SET @manque = (SELECT COUNT(*) = 0 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = 'acore_world' "
      "AND TABLE_NAME = 'solazeroth_v3_donjons_composants' AND COLUMN_NAME = 'taux');")
    w("SET @requete = IF(@manque, 'ALTER TABLE solazeroth_v3_donjons_composants ADD COLUMN taux TINYINT UNSIGNED NOT "
      "NULL DEFAULT %d', 'DO 0');" % TAUX_GOUFFRE)
    w("PREPARE requete FROM @requete;")
    w("EXECUTE requete;")
    w("DEALLOCATE PREPARE requete;")
    w("REPLACE INTO solazeroth_v3_donjons_composants (carte, composant, puissance_min, taux) VALUES (%d, %d, %d, %d);"
      % (CARTE, GRAINE, PUISSANCE_MIN, TAUX))
    w("CREATE TABLE solazeroth_v3_donjons_bosses (boss INT UNSIGNED NOT NULL PRIMARY KEY, carte INT UNSIGNED NOT NULL);")
    w("INSERT INTO solazeroth_v3_donjons_bosses VALUES (3654, %d);" % CARTE)
    w("CREATE TABLE solazeroth_v3_donjons_pierres (carte INT UNSIGNED NOT NULL, pierre INT UNSIGNED NOT NULL, "
      "PRIMARY KEY (carte, pierre));")
    w("INSERT INTO solazeroth_v3_donjons_pierres VALUES %s;" % ", ".join(
        "(%d, %d)" % (c, p) for c, l in PIERRES.items() for p in l))
    w("CREATE TABLE solazeroth_v3_panoplies (ordre TINYINT UNSIGNED NOT NULL PRIMARY KEY, premiere INT UNSIGNED NOT "
      "NULL, derniere INT UNSIGNED NOT NULL, sort_2 INT UNSIGNED NOT NULL, sort_4 INT UNSIGNED NOT NULL, sort_6 INT "
      "UNSIGNED NOT NULL, nom VARCHAR(64) NOT NULL) DEFAULT CHARSET=utf8mb4;")
    w("INSERT INTO solazeroth_v3_panoplies VALUES %s;" % ", ".join(
        "(%d, %d, %d, %d, %d, %d, %s)" % (o, a, b, s2, s4, s6, s(nom)) for o, a, b, s2, s4, s6, nom in PANOPLIES))
    d = dbc.Dbc.ouvrir(os.path.join(DBC_SERVEUR, "Spell.dbc"))
    types = auras_nommees.types_colonnes()
    ids_sorts = ", ".join(map(str, SORTS_PANOPLIE))
    w("DELETE FROM spell_dbc WHERE ID IN (%s);" % ids_sorts)
    for e in sorts(d):
        w("INSERT INTO spell_dbc VALUES (%s);" % ", ".join(auras_nommees.valeur_sql(d, t, v) for t, v in zip(types, e)))
    w("")
    w("-- Graine de cauchemar (Collection, Divers).")
    desc = "Composant de donjon (Cavernes des Lamentations) : sert aux pièces bleues des Cavernes."
    w("DELETE FROM item_template WHERE entry IN (%s) OR entry IN (%s) OR entry = %d;"
      % (tout, ", ".join(map(str, rangs)), GRAINE))
    w("DELETE FROM item_template_locale WHERE ID = %d;" % GRAINE)
    w("CREATE TEMPORARY TABLE sol_objet SELECT * FROM item_template WHERE entry = %d;" % GRAINE_SOURCE)
    w("UPDATE sol_objet SET entry = %d, name = 'Graine de cauchemar', Quality = 3, bonding = 1, BuyPrice = 0, "
      "SellPrice = 0, stackable = 1000, spellid_1 = 0, spelltrigger_1 = 0, description = %s;" % (GRAINE, s(desc)))
    w("INSERT INTO item_template SELECT * FROM sol_objet;")
    w("DROP TEMPORARY TABLE sol_objet;")
    w("INSERT INTO item_template_locale (ID, locale, Name, Description, VerifiedBuild) VALUES (%d, 'frFR', "
      "'Graine de cauchemar', %s, 0);" % (GRAINE, s(desc)))
    w("INSERT IGNORE INTO solazeroth_v3_collectionnables VALUES (%d);" % GRAINE)
    w("")
    w("-- Pièces bleues des Lamentations : apparence et type d'un vert de Blizzard, barème commun à la puissance %d."
      % BLEUES)
    caracs = {}
    for e, cat, nom, prix, c, src, forge in bleues:
        source = sources[src]
        poids = e3.POIDS[int(source["InventoryType"])]
        ca = at.caracteristiques_baton(source, BLEUES, armes) if int(source["InventoryType"]) == 17 else \
            e3.caracteristiques(source, BLEUES, armures, armes)
        bloc = int(source["block"])
        caracs[e] = (ca, bloc)
        w("CREATE TEMPORARY TABLE sol_objet SELECT * FROM item_template WHERE entry = %d;" % src)
        w("UPDATE sol_objet SET entry = %d, name = %s, description = '', Quality = 3, bonding = 1, ItemLevel = %d, "
          "RequiredLevel = 0, RequiredSkill = 0, RequiredSkillRank = 0, AllowableClass = -1, AllowableRace = -1, "
          "BuyCount = 1, BuyPrice = %d, SellPrice = 0, RandomProperty = 0, RandomSuffix = 0, spellid_1 = 0, "
          "spelltrigger_1 = 0, spellid_2 = 0, spelltrigger_2 = 0, itemset = 0, DisenchantID = %d, "
          "RequiredDisenchantSkill = 1, %s;"
          % (e, s(nom), BLEUES, e3.prix(BLEUES, poids), en.table_de(int(source["class"]), BLEUES),
             e3.colonnes_sql(e3.au_rang(ca, 0, bloc))))
        w("INSERT INTO item_template SELECT * FROM sol_objet;")
        w("DROP TEMPORARY TABLE sol_objet;")
    for e, cat, nom, *_ in bleues:
        ca, bloc = caracs[e]
        for r in range(1, e3.RANGS + 1):
            w("CREATE TEMPORARY TABLE sol_objet SELECT * FROM item_template WHERE entry = %d;" % e)
            w("UPDATE sol_objet SET entry = %d, name = %s, BuyPrice = 0, %s;"
              % (e3.entree_rang(e, r), s("%s +%d" % (nom, r)), e3.colonnes_sql(e3.au_rang(ca, r, bloc))))
            w("INSERT INTO item_template SELECT * FROM sol_objet;")
            w("DROP TEMPORARY TABLE sol_objet;")
    w("DELETE FROM solazeroth_v3_rangs WHERE base IN (%s);" % tout)
    w("INSERT INTO solazeroth_v3_rangs VALUES %s;" % ", ".join(
        "(%d, %d, %d)" % (e3.entree_rang(e, r) if r else e, e, r) for e in entrees for r in range(e3.RANGS + 1)))
    w("-- Recettes (puissance %d), composants du §4.7.4." % REQUISE)
    w("DELETE FROM solazeroth_v3_recettes WHERE objet IN (%s);" % tout)
    w("DELETE FROM solazeroth_v3_recettes_composants WHERE objet IN (%s);" % tout)
    w("INSERT INTO solazeroth_v3_recettes VALUES %s;" % ", ".join(
        "(%d, %d, %d, %d)" % (e, forge, REQUISE, prix) for e, _, _, prix, _, _, forge in bleues))
    w("INSERT INTO solazeroth_v3_recettes_composants VALUES %s;" % ", ".join(
        "(%d, %d, %d)" % (e, o, n) for e, _, _, _, c, _, _ in bleues for o, n in c))
    w("")
    w("-- Ebru : seuil des Cavernes ; le Disciple de Naralex : escorte en solo (v3_gouffre.cpp) ; Mocassins et")
    w("-- Ectoplasmes appelés sans SmartAI (leur script visait le disciple).")
    w("CREATE TABLE solazeroth_v3_t5_pnj_origine SELECT entry, npcflag, AIName, ScriptName FROM creature_template "
      "WHERE entry IN (%s);" % pnj)
    w("DELETE FROM npc_text WHERE ID = %d;" % TEXTE_EBRU)
    w("INSERT INTO npc_text (ID, text0_0, text0_1, Probability0) VALUES (%d, %s, %s, 1);" % (TEXTE_EBRU, s(TEXTE), s(TEXTE)))
    w("DELETE FROM solazeroth_v3_donjons_seuils WHERE carte = %d;" % CARTE)
    w("INSERT INTO solazeroth_v3_donjons_seuils VALUES (%d, %d, %d, %d, %d, %d, %g, %g, %g, %g, %s, %s, %s, %s);"
      % (SEUIL[:10] + tuple(s(x) for x in SEUIL[10:])))
    w("UPDATE creature_template SET npcflag = npcflag | 1, ScriptName = %s WHERE entry = %d;" % (s(SCRIPT_SEUIL), EBRU))
    w("UPDATE creature_template SET AIName = '', ScriptName = %s WHERE entry = %d;" % (s(SCRIPT_DISCIPLE), DISCIPLE))
    w("UPDATE creature_template SET AIName = '' WHERE entry IN (5762, 5763);")
    w("")
    w("-- Quêtes d'origine des Cavernes et de leurs abords (zone 718) : retirées (%d), dont 6981." % len(origine))
    up += qd.disables_sql(ZONE, origine)
    w("-- Objets qui lançaient une de ces quêtes : ils ne la lancent plus (l'Éclat luminescent sert à T35).")
    w("CREATE TABLE solazeroth_v3_t5_sans_quete SELECT i.entry, i.startquest FROM item_template i JOIN disables d ON "
      "d.sourceType = 1 AND d.entry = i.startquest AND d.comment = '%s' WHERE i.startquest > 0;" % COMMENTAIRE)
    w("UPDATE item_template i JOIN solazeroth_v3_t5_sans_quete o ON o.entry = i.entry SET i.startquest = 0;")
    p_up, p_down, _ = qt.pieces_sql(j)
    w("-- Récompenses au barème, rangs 1 à 5, versions par classe.")
    up += p_up
    w("-- Les quêtes T31 à T36.")
    up += qd.quetes_sql(ZONE, textes, pos)
    w("-- Faux indicateurs de quête des abords et des Cavernes (passe de la migration 120).")
    active = "NOT EXISTS (SELECT 1 FROM disables d WHERE d.sourceType = 1 AND d.entry = q.quest)"
    w("CREATE TABLE solazeroth_v3_t5_faux_indicateurs (entry INT UNSIGNED NOT NULL PRIMARY KEY) SELECT DISTINCT "
      "t.entry FROM creature c JOIN creature_template t ON t.entry = c.id WHERE ((c.map = 1 AND c.zoneId = %d) OR "
      "c.map = %d) AND (t.npcflag & 2) AND NOT EXISTS (SELECT 1 FROM creature_queststarter q WHERE q.id = t.entry AND "
      "%s) AND NOT EXISTS (SELECT 1 FROM creature_questender q WHERE q.id = t.entry AND %s);"
      % (ZONE_CAVERNES, CARTE, active, active))
    w("UPDATE creature_template t JOIN solazeroth_v3_t5_faux_indicateurs f ON f.entry = t.entry "
      "SET t.npcflag = t.npcflag & ~2;")
    w("")

    x = down.append
    x("-- Annule le lot T5 des Tarides (migration 146). Les pièces et Graines des personnages disparaissent.")
    x("SET SESSION sql_mode = '';")
    x("USE acore_world;")
    x("UPDATE creature_template t JOIN solazeroth_v3_t5_faux_indicateurs f ON f.entry = t.entry "
      "SET t.npcflag = t.npcflag | 2;")
    x("DROP TABLE solazeroth_v3_t5_faux_indicateurs;")
    for table, colonne in (("quest_template", "ID"), ("quest_template_addon", "ID"), ("quest_request_items", "ID"),
                           ("quest_offer_reward", "ID"), ("quest_poi", "QuestID"), ("quest_poi_points", "QuestID"),
                           ("creature_queststarter", "quest"), ("creature_questender", "quest")):
        x("DELETE FROM %s WHERE %s IN (%s);" % (table, colonne, quetes))
    x("DELETE FROM conditions WHERE SourceTypeOrReferenceId = 19 AND SourceEntry IN (%s);" % quetes)
    down.extend(p_down)
    x("UPDATE item_template i JOIN solazeroth_v3_t5_sans_quete o ON o.entry = i.entry SET i.startquest = o.startquest;")
    x("DROP TABLE solazeroth_v3_t5_sans_quete;")
    x("DELETE FROM disables WHERE sourceType = 1 AND comment = '%s';" % COMMENTAIRE)
    x("UPDATE creature_template t JOIN solazeroth_v3_t5_pnj_origine o ON o.entry = t.entry SET t.npcflag = o.npcflag, "
      "t.AIName = o.AIName, t.ScriptName = o.ScriptName;")
    x("DROP TABLE solazeroth_v3_t5_pnj_origine;")
    x("DELETE FROM solazeroth_v3_donjons_seuils WHERE carte = %d;" % CARTE)
    x("DELETE FROM npc_text WHERE ID = %d;" % TEXTE_EBRU)
    x("DELETE FROM solazeroth_v3_recettes WHERE objet IN (%s);" % tout)
    x("DELETE FROM solazeroth_v3_recettes_composants WHERE objet IN (%s);" % tout)
    x("DELETE FROM solazeroth_v3_rangs WHERE base IN (%s);" % tout)
    x("DELETE FROM item_template WHERE entry IN (%s) OR entry IN (%s) OR entry = %d;"
      % (tout, ", ".join(map(str, rangs)), GRAINE))
    x("DELETE FROM item_template_locale WHERE ID = %d;" % GRAINE)
    x("DELETE FROM solazeroth_v3_collectionnables WHERE entry = %d;" % GRAINE)
    x("DELETE FROM spell_dbc WHERE ID IN (%s);" % ids_sorts)
    x("DROP TABLE solazeroth_v3_panoplies, solazeroth_v3_donjons_pierres, solazeroth_v3_donjons_bosses;")
    x("DELETE FROM solazeroth_v3_donjons_composants WHERE carte = %d;" % CARTE)
    x("ALTER TABLE solazeroth_v3_donjons_composants DROP COLUMN taux;")
    x("INSERT IGNORE INTO creature SELECT * FROM solazeroth_v3_t5_apparitions;")
    x("INSERT IGNORE INTO creature_addon SELECT * FROM solazeroth_v3_t5_apparitions_addon;")
    x("DROP TABLE solazeroth_v3_t5_apparitions, solazeroth_v3_t5_apparitions_addon;")
    x("DELETE FROM solazeroth_v3_courbe_entrees WHERE entree IN (%s);" % entrees_monstres)
    x("DELETE FROM solazeroth_v3_puissance_entrees WHERE entree IN (%s);" % entrees_monstres)
    x("")
    for suffixe, lignes in ((".up.sql", up), (".down.sql", down)):
        with open(MIGRATION + suffixe, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(lignes))

    l = ["-- Généré par outils\\cavernes_v3.py : ne pas modifier à la main.",
         "-- Lot T5 des Tarides : pièces bleues des Lamentations (niveau « %s » du menu de fabrication), après les" % NIVEAU_MENU,
         "-- recettes des Tarides ; la Graine de cauchemar dans la catégorie Divers de la Collection.",
         "-- sources : " + " ".join("%d=%d" % (e, src) for e, _, _, _, _, src, _ in bleues) + " "
         + " ".join("%d=%d" % kv for kv in sorted(src_rec.items()))]
    for cle, nom, forge in CATEGORIES:
        l.append("table.insert(SolUI.RECETTES, { nom = %s, zone = %s, forge = %s, donjon = true, recettes = {"
                 % (lua(nom), lua(at.ZONE_MENU), "true" if forge else "false"))
        for e, cat, n, prix, c, src, _ in bleues:
            if cat == cle:
                l.append("    { %d, %s, %d, %d, %d, { %s }, %s }," % (e, lua(n), BLEUES, REQUISE, prix,
                         ", ".join("{ %d, %d }" % oc for oc in c), lua(at.genre_menu(sources[src]))))
        l.append("} })")
    l += ["for _, c in ipairs(SolUI.CATALOGUE or {}) do",
          "    if c.nom == \"Divers\" then table.insert(c.objets, 1, { %d, \"Graine de cauchemar\", 3 }) end" % GRAINE,
          "end"]
    with open(LUA, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(l) + "\n")
    assert {e: s_ for e, s_ in _sources_lues().items() if e in src_rec} == src_rec
    tissu_v3.ecrire_versions_lua()
    qd.item_dbc()
    qd.puissances()
    for e, cat, nom, *_ in bleues[:1] + bleues[24:25] + bleues[31:32]:
        print(e, nom, caracs[e][0])
    print("%d monstres réglés, %d pièces bleues, %d quêtes, %d quêtes d'origine retirées : migration 146 et "
          "SolUI_RecettesCavernes.lua écrits." % (len(k), len(bleues), len(Q), len(origine)))


# --- Vérification, après la migration ---------------------------------------------------------------------------------

def verifier():
    import fiches_zones as fz
    import simulation_combat as sim
    import simulation_demoniste as sd
    import simulation_sorts as ss
    import simulation_voleur as sv
    import tests_equilibrage as te
    import courbe_monstres as cm
    peur_comme_etourdi(ss)
    liste = monstres()
    fin2, fin3 = joueurs_fin(2), joueurs_fin(3)
    print("Calibrage relu en base (courbe et correction de l'entrée) : guerrier rang 2 / rang 3 ; démoniste et voleur "
          "rang 2 (contrôle)")
    ecarts = []
    for e, (nom, rang, _, _, p) in sorted(liste.items(), key=lambda kv: (kv[1][4], kv[0])):
        m = ss.monstre_avec_sorts(e, p, contact=True, courbe=True)
        t2, t3 = guerrier_contre(ss, te, fin2[0], m, e), guerrier_contre(ss, te, fin3[0], m, e)
        mm = sim.courber(sd.monstre(e, p))
        groupe = [mm] if seul(e) else [mm, copy.deepcopy(mm)]
        potion = te.POTION_TARIDES if seul(e) else None
        td = sd.simuler(fin2[1], groupe, N, potion=potion)["victoire"]
        tv = sv.simuler(fin2[2], groupe, N, potion=potion)["victoire"]
        print("  %-24s P%d %-5s guerrier %3.0f / %3.0f %% | démoniste %3.0f %% | voleur %3.0f %%"
              % (nom[:24], p, "seul" if seul(e) else "paire", t2, t3, td, tv))
        if abs(t2 - CIBLE) > 8 and t2 < CIBLE or t3 < SEREIN - 5:
            ecarts.append("%s : %.0f / %.0f %%" % (nom, t2, t3))
    print("\nBleues des Lamentations au rang 0 contre la fiche de sortie (34, pièces d'arrivée refaites au barème) : "
          "vie perdue (%)")
    reels = __import__("simulation_vertes_tarides").joueurs_reels(fz.SORTIE_TARIDES["pieces"])
    fiche = fz.joueurs(34)
    for j, f, c in zip(reels, fiche, ("guerrier", "démoniste", "voleur")):
        print("  %-9s réel vie %d armure %d puissance %.1f | fiche vie %d armure %d" % (
            c, j.vie, j.armure, j.puissance, f.vie, f.armure))
    for e in (3376, 3633):
        m = ss.monstre_avec_sorts(e, 34, contact=True, courbe=True)
        mm = sim.courber(sd.monstre(e, 34))
        r = (cm.perdue(ss.simuler(reels[0], m, N, potion=te.POTION_TARIDES, heurt=te.HEURT)),
             cm.perdue(sd.simuler(reels[1], [mm], N, potion=te.POTION_TARIDES)),
             cm.perdue(sv.simuler(reels[2], [mm], N, potion=te.POTION_TARIDES)))
        b = (cm.perdue(ss.simuler(fiche[0], m, N, potion=te.POTION_TARIDES, heurt=te.HEURT)),
             cm.perdue(sd.simuler(fiche[1], [mm], N, potion=te.POTION_TARIDES)),
             cm.perdue(sv.simuler(fiche[2], [mm], N, potion=te.POTION_TARIDES)))
        print("  %-24s P34 | " % m.nom[:24] + " | ".join("%s %4.1f %% (fiche %4.1f)" % (c, a, x) for c, a, x in
                                                       zip(("guerrier", "démoniste", "voleur"), r, b)))
        for c, a, x in zip(("guerrier", "démoniste", "voleur"), r, b):
            if a > x + 5.0:
                ecarts.append("%s contre %s à 34 : %.1f %% perdue, fiche %.1f %%" % (c, m.nom, a, x))
    print("\n" + ("Écarts :\n  " + "\n  ".join(ecarts) if ecarts else "Aucun écart : calibrage tenu, bleues à la fiche."))
    return 1 if ecarts else 0


if __name__ == "__main__":
    if "--verifier" in sys.argv:
        sys.exit(verifier())
    main()
