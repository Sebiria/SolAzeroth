"""Audit du jeu, lot 6b (02/11/2026, C8 ; demande de l'utilisateur) : trois rares secrets de Durotar.

« Il faut que ces rares soient de challenge full bleu full buff de ragefeu. Ils donnent pour l'un une monture, pour un
autre un bijou équipable sans condition, de qualité bleue, puissance +4 que l'équipement Ragefeu rang 0, et le dernier
une bague pareil. Ces objets ne doivent pas compter dans la simulation de Durotar, ni dans le commencement de la
prochaine zone. »

- Cachés : ni prime, ni point sur la carte, ni part de zone ; la fenêtre des objectifs compte « ? / 3 » et ne nomme
  que ceux qu'on a vaincus (v3_rares_secrets.cpp, « SECRETS;n;total;noms » avant FINZONE).
- Réglés par simulation contre la fiche la plus forte possible au sortir du Gouffre : le dernier personnage des
  journaux, tout en bleu du Gouffre au rang 0 (maille, bouclier, cape, arme à une main), Repos au coin du feu,
  panoplie 6, thon, pierre à aiguiser, nécessaire d'armure et 8 pièces de variante Critique ; potion rang 2. Visée :
  environ 50 % de victoires. Leurs deux techniques comptent chacune + TECHNIQUE de dégâts, comme les modes.
- Récompenses : la monture (Raptor razzashi rapide, retiré de la boutique, vitesse 60 % : prestige, pas progression ;
  montures_v3.SECRETES) ajoutée aux montures du compte ; le bijou et la bague tombent du corps (uniques, liés quand
  ramassés), puissance 18 (14 + 4), sans rangs, barème à 0,56 (comme cou et cape).
- Exclus des références : ni la simulation de Durotar (tests_equilibrage, paliers), ni le départ de la zone 2 ne
  supposent ces objets ; EXCLUS les liste pour les outils qui lisent l'équipement porté.

Lot T6 des Tarides (03/11/2026, §4.5 du brouillon des Tarides) : l'outil est par zone (ZONES). Les Tarides ont cinq
rares secrets (910043 à 910047, puissance 35 = bleues des Cavernes + 1), réglés de la même façon contre la fiche la
plus forte au sortir des Cavernes : bleues des Lamentations au rang 0 (fiches_zones.CAVERNES), camp des Tarides (feu 5,
potion 4), panoplie des Lamentations 6, plat de hâte des Tarides, pierre à aiguiser grossière, renfort d'armure moyen,
8 variantes Critique. Récompenses à 38 (bleues + 4) : collier, bague, deux bijoux, et le Zhévra rapide (retiré de la
boutique, 60 %). Bras-de-pierre et le Requin du sable sont de vrais rares de la zone : leur apparition d'origine est
retirée (table de retour solazeroth_v3_t6_apparitions). La table solazeroth_v3_rares_secrets (migration 121) reçoit
leurs lignes ; le cadre violet (SolUI_Cible.lua, RARES_SECRETS) est réécrit pour toutes les zones. --controle relit
les rares en base : guerrier, démoniste et voleur, sans et avec les bonus (cible 30 à 70 % pour chaque classe).

py rares_secrets_v3.py [durotar|tarides]            (simulation, puis migration 121 ou 147)
py rares_secrets_v3.py [durotar|tarides] --simuler  (simulation seule)
py rares_secrets_v3.py tarides --controle           (après la migration : les trois classes contre les rares en base)
"""
import math
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from quetes_durotar import s
import annexes_durotar as annexes
import equipement_v3 as e3
import simulation_camp as camp
import simulation_combat as sim
import simulation_donjons as donjons
import simulation_lot4c as lot4c
import simulation_modes as modes

MIGRATION = r"C:\SolAzeroth\sql\migrations\121_v3_rares_secrets"
DUROTAR = 14
GUID = 9100040
MONTURE = 24242                       # Raptor razzashi rapide (montures_v3.SECRETES)
BIJOU, BAGUE = 910300, 910301
PUISSANCE_OBJET = 18                  # pièces bleues du Gouffre (14) + 4
POIDS_BIJOU = 0.56
PUISSANCE_RARE = 15
TECHNIQUE = 0.05
VISEE = (45, 55)

# Fiche « full bleu » : 8 pièces de maille, bouclier, cape, Lame maudite (une main).
GOUFFRE = [910241, 910242, 910243, 910244, 910245, 910246, 910247, 910248, 910270, 910271, 910265]

# (entrée, origine, nom, titre, (x, y) ou (x, y, z), orientation, part des dégâts / vie, techniques, récompense,
#  objet d'origine[, retouches du modèle]) ; techniques : (événement, paramètres d'événement, drapeaux, sort, cible,
# commentaire) ; événements 0 en combat, 2 vie entre min et max %, 4 entrée en combat, 9 cible entre min et max m ;
# cibles 1 soi, 2 sa cible.
RARES = [
    (910040, 3206, "Zal'mara la Renégate", "", (-1626, -5350), 2.0, 1.0, [
        (0, (4000, 6000, 12000, 15000), 0, 744, 2, "Zal'mara - Venin"),
        (2, (0, 30, 0, 0), 1, 8269, 1, "Zal'mara - Frénésie sous 30 %"),
    ], ("monture", MONTURE), None),
    (910041, 3197, "Gardien cendré", "La Lame ardente", (1470, -4930), 5.2, 1.1, [
        (0, (6000, 8000, 16000, 18000), 0, 11990, 2, "Gardien cendré - Pluie de feu"),
        (0, (2000, 3000, 30000, 30000), 0, 702, 2, "Gardien cendré - Malédiction de faiblesse"),
    ], ("objet", BIJOU), 21568),
    (910042, 3128, "Capitaine Hurlevague", "Noyé de Kul Tiras", (300, -5165), 1.4, 0.9, [
        (4, (0, 0, 0, 0), 0, 51756, 2, "Hurlevague - Charge"),
        (0, (5000, 7000, 10000, 12000), 0, 11971, 2, "Hurlevague - Fracasser armure"),
    ], ("objet", BAGUE), 6332),
]
OBJETS = [(BIJOU, 21568, "Braise du Gardien", "Elle ne s'éteint jamais tout à fait ; la Lame la croyait perdue."),
          (BAGUE, 6332, "Perle de Hurlevague", "Le capitaine la serrait encore quand la mer l'a rendu à la côte.")]

# --- Lot T6 des Tarides : les cinq rares secrets (§4.5 du brouillon des Tarides) ---------------------------------------
TARIDES = 17
GUID_TARIDES = 9100043
PUISSANCE_RARE_TARIDES = 35           # bleues des Cavernes (34) + 1
PUISSANCE_OBJET_TARIDES = 38          # bleues des Cavernes (34) + 4
ZHEVRA = 48954                        # Zhévra rapide de la boutique (49322 : le même, appris par l'objet 37719)
ZHEVRA_SORTS = (48954, 49322)
COLLIER, ANNEAU, REGULATEUR, DENT = 910302, 910303, 910304, 910305
CHARGE = 51756                        # ouverture : met le rare au contact (simulation_demoniste.CHARGE)
RARES_TARIDES = [
    (910043, 3840, "Vylas Crocsonge", "Druide du Croc égaré", (-1055, -2285, 91.9), 0.6, 3.5, [
        (0, (8000, 10000, 25000, 25000), 0, 31541, 2, "Vylas - Sommeil (5 s)"),
        (2, (0, 50, 0, 0), 1, 8599, 1, "Vylas - Enrager sous 50 %"),
        (2, (0, 50, 6000, 8000), 0, 14795, 2, "Vylas - Poison de Peau-de-venin sous 50 %"),
    ], ("objet", COLLIER), 7731),
    (910044, 4514, "Échine-de-ronce", "Rejeton d'Agammagan", (-3250, -1860, 93.0), 1.0, 2.0, [
        (9, (8, 30, 12000, 15000), 0, CHARGE, 2, "Échine-de-ronce - Charge des ronces à plus de 8 m"),
        (0, (6000, 8000, 20000, 20000), 0, 51439, 1, "Échine-de-ronce - Contrecoup (renvoi, 6 s)"),
    ], ("objet", ANNEAU), 5007),
    (910045, 3439, "Prototype XT-0", "", (1241, -3596, 90.3), 2.4, 2.5, [
        (0, (5000, 7000, 15000, 15000), 0, 17207, 1, "XT-0 - Tourbillon"),
        (2, (0, 30, 0, 0), 1, 8269, 1, "XT-0 - Surchauffe (Frénésie) sous 30 %"),
    ], ("objet", REGULATEUR), 4381, {"faction": 16}),
    (910046, 5837, "Bras-de-pierre", "Khan déchu des Kolkar", (395, -1360, 92.3), 3.1, 1.0, [
        (4, (0, 0, 0, 0), 0, CHARGE, 2, "Bras-de-pierre - Charge kolkar"),
        (0, (6000, 8000, 18000, 18000), 0, 8078, 1, "Bras-de-pierre - Coup de tonnerre"),
    ], ("monture", ZHEVRA), None),
    (910047, 5435, "Mâchoire-des-sables", "Requin du sable", (-1222, -3888, 12.1), 0.8, 0.4, [
        (4, (0, 0, 0, 0), 0, CHARGE, 2, "Mâchoire-des-sables - Surgir du sable"),
        (0, (5000, 7000, 20000, 20000), 0, 9493, 2, "Mâchoire-des-sables - Déchirure"),
    ], ("objet", DENT), 19992, {"au_sol": True}),
]
OBJETS_TARIDES = [
    (COLLIER, 7731, "Collier du rêve brisé", "Vylas le portait quand le cauchemar l'a pris ; il en garde le froid."),
    (ANNEAU, 5007, "Anneau d'épine de sang", "Taillé dans une épine du Rejeton : il pique encore la main qui le serre."),
    (REGULATEUR, 4381, "Régulateur surchauffé", "Il chauffe toujours un peu ; le prototype n'a jamais su s'arrêter."),
    (DENT, 19992, "Dent de Mâchoire-des-sables", "Arrachée au requin qui nageait dans le sable ; elle grince encore."),
]
# Vrais rares de la zone copiés : leur apparition d'origine est retirée (Bras-de-pierre, Requin du sable de la côte).
RETRAITS_TARIDES = (20635, 43494)

# Objets hors des références de simulation (Durotar, départ de la zone 2 ; Tarides, départ de la zone 3).
EXCLUS = (BIJOU, BAGUE) + tuple(e for e, *_ in OBJETS_TARIDES)


def fiche():
    """Le dernier personnage des journaux, tout en bleu du Gouffre au rang 0, avec le Repos et tous les bonus."""
    sebiria = [f for f in camp.fiches() if f.nom == "Sebiria"]
    j = sim.equiper(max(sebiria, key=lambda f: f.puissance), GOUFFRE, 1)
    j = camp.repos(j, 5)
    p, c = lot4c.PANOPLIE[2][1], lot4c.CONSOMMABLES
    bonus = lot4c.cumul(p, lot4c.PLATS[4][1], c[0][1], c[1][1], {"critique": lot4c.VARIANTES["Critique"] * lot4c.PIECES})
    return j, bonus


# --- Fiche des Tarides : la plus forte au sortir des Cavernes ---------------------------------------------------------

def camp_tarides(j):
    """Feu 5 des Tarides : Repos à +10 et vie maximale +8 % (au lieu de +5 et +5 %) ; j a déjà le Repos du feu 3."""
    return sim.enchanter(j, vie=round(j.vie * 0.03), force=5)


def bonus_tarides():
    """Panoplie des Lamentations 6 (mêmes paliers que le Gouffre, décision 13), plat de hâte des Tarides, pierre à
    aiguiser grossière, renfort d'armure moyen (artisanat_tarides.CONSOMMABLES), 8 variantes Critique."""
    import artisanat_tarides as at
    import cuisine_v3 as c
    hate = max(c.BONUS[p["objet"]][2] for p in c.plats_tarides() if c.BONUS[p["objet"]][0] == c.HATE_MELEE_DISTANCE)
    pierre, renfort = at.CONSOMMABLES[0][-1], at.CONSOMMABLES[1][-1]
    return lot4c.cumul(lot4c.PANOPLIE[2][1], {"hate": hate / 100}, {"inflige": 1 + pierre / 100},
                       {"armure": 1 + renfort / 100}, {"critique": lot4c.VARIANTES["Critique"] * lot4c.PIECES})


def joueurs_tarides():
    """(guerrier, démoniste, voleur) aux bleues des Cavernes au rang 0, camp des Tarides (feu 5)."""
    import fiches_zones as fz
    import simulation_demoniste as sd
    import simulation_voleur as sv
    import simulation_vertes_tarides as svt
    g, d, v = svt.joueurs_reels(fz.SORTIE_TARIDES["pieces"])
    pieces = fz.SORTIE_TARIDES["pieces"]
    d = sd.renforce(sd.demoniste(pieces["demoniste_affliction"], fz.SEBIRIA, repas=fz.REPOS + 5))
    v = sv.renforce(sv.voleur(pieces["voleur_assassinat"], fz.SEBIRIA, g.critique, repas=fz.REPOS + 5))
    d.vie, v.vie = round(d.vie * 1.03), round(v.vie * 1.03)
    return camp_tarides(g), d, v


def fiche_tarides():
    return joueurs_tarides()[0], bonus_tarides()


def essai_tarides(j, m, bonus):
    """Comme lot4c.essai, avec la potion 4 des Tarides."""
    f = lot4c.fiche(j, bonus.get("vie", 1.0), bonus.get("armure", 1.0), bonus.get("critique", 0.0), bonus.get("hate", 0.0))
    passifs = {k: v for k, v in bonus.items() if k in ("inflige", "subis", "vol")}
    return sim.simuler(f, m, donjons.N, potion=modes.POTION_TARIDES_4, passifs=passifs or None)["victoire"]


ZONES = {
    "durotar": dict(nom="Durotar", migration=MIGRATION, zone=DUROTAR, guid=GUID, puissance=PUISSANCE_RARE,
                    objet=PUISSANCE_OBJET, rares=RARES, objets=OBJETS, fiche=fiche, essai=lot4c.essai,
                    potion=donjons.POTION_F7, bornes=(0.2, 20.0), monture=(MONTURE,), boutique=(135, 900), retraits=()),
    "tarides": dict(nom="Les Tarides", migration=r"C:\SolAzeroth\sql\migrations\147_v3_rares_secrets_tarides",
                    zone=TARIDES, guid=GUID_TARIDES, puissance=PUISSANCE_RARE_TARIDES, objet=PUISSANCE_OBJET_TARIDES,
                    rares=RARES_TARIDES, objets=OBJETS_TARIDES, fiche=fiche_tarides, essai=essai_tarides,
                    potion=modes.POTION_TARIDES_4, bornes=(0.02, 20.0), monture=ZHEVRA_SORTS, boutique=(125, 670),
                    retraits=RETRAITS_TARIDES),
}


def monstre(origine, part, techniques, k, puissance=PUISSANCE_RARE):
    m = sim.monstre_depuis_base(origine, puissance)
    return modes.renforcer(m, k, part * (1 + TECHNIQUE * len(techniques)))


def regler(j, bonus, origine, part, techniques, z=None):
    """Facteur de vie et de dégâts pour environ 50 % de victoires (dichotomie)."""
    z = z or ZONES["durotar"]
    bas, haut = z["bornes"]
    for _ in range(20):
        k = (bas + haut) / 2
        t = z["essai"](j, monstre(origine, part, techniques, k, z["puissance"]), bonus)
        if VISEE[0] <= t <= VISEE[1]:
            break
        bas, haut = (k, haut) if t > VISEE[1] else (bas, k)
    return k, t


def simuler(z=None):
    z = z or ZONES["durotar"]
    j, bonus = z["fiche"]()
    print(j, "| bonus :", bonus)
    reglages = {}
    for entree, origine, nom, _, _, _, part, techniques, *_ in z["rares"]:
        k, t = regler(j, bonus, origine, part, techniques, z)
        m = monstre(origine, part, techniques, k, z["puissance"])
        base = sim.monstre_depuis_base(origine, z["puissance"])
        brut = sim.simuler(j, m, donjons.N, potion=z["potion"])
        print("%-24s puissance %d, facteur %.2f : vie %d, coups %d-%d ; %.0f %% (sans bonus %.0f %%), %.0f s"
              % (nom, z["puissance"], k, m.vie, m.bas, m.haut, t, brut["victoire"], brut["duree"]))
        orig = sim.sql("SELECT HealthModifier, DamageModifier FROM acore_world.creature_template WHERE entry = %d"
                       % origine)[0]
        reglages[entree] = (float(orig[0]) * k, float(orig[1]) * k * part * (1 + TECHNIQUE * len(techniques)))
        assert base.vie > 0
    return reglages


def bijou(source, puissance=PUISSANCE_OBJET):
    """Colonnes du bijou ou de la bague : barème des pièces au poids 0,56, sans armure ni arme."""
    ap = max(1, round(POIDS_BIJOU * puissance * e3.AP_PAR_POINT))
    endurance = round(POIDS_BIJOU * puissance * e3.ENDURANCE_PAR_POINT)
    return e3.colonnes_sql({"armor": 0, "dmg_min1": 0, "dmg_max1": 0, "block": 0, "ap": ap, "endurance": endurance})


def lignes_dbc():
    """(entrée, entrée copiée, genre) pour l'Item.dbc du patch."""
    return [(e, source, None) for e, source, *_ in OBJETS + OBJETS_TARIDES]


def ecrire_client():
    """Lot T6 des Tarides : le cadre violet reconnaît les rares secrets de toutes les zones (SolUI_Cible.lua)."""
    chemin = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "interface-v3", "FrameXML", "SolUI_Cible.lua")
    with open(chemin, encoding="utf-8", newline="") as f:
        texte = f.read()
    liste = "local RARES_SECRETS = { %s }" % ", ".join("[%d] = true" % r[0] for z in ZONES.values() for r in z["rares"])
    nouveau, n = re.subn(r"local RARES_SECRETS = \{[^}]*\}", liste, texte)
    assert n == 1, "RARES_SECRETS introuvable dans SolUI_Cible.lua"
    with open(chemin, "w", encoding="utf-8", newline="") as f:
        f.write(nouveau)


def ecrire(reglages, z=None, chemin=None):
    z = z or ZONES["durotar"]
    durotar = z["zone"] == DUROTAR
    rares, objets, puissance = z["rares"], z["objets"], z["puissance"]
    up, down = [], []
    w = up.append
    if durotar:
        w("-- Audit du jeu, lot 6b (02/11/2026, C8) : trois rares secrets de Durotar. Généré par outils\\rares_secrets_v3.py :")
        w("-- ne pas modifier à la main. Scripts : v3_rares_secrets.cpp.")
    else:
        w("-- Lot T6 des Tarides (03/11/2026) : cinq rares secrets des Tarides. Généré par outils\\rares_secrets_v3.py "
          "tarides :")
        w("-- ne pas modifier à la main. Scripts : v3_rares_secrets.cpp ; liste dans solazeroth_v3_rares_secrets "
          "(migration 121).")
    w("USE acore_world;")
    w("")
    if durotar:
        w("-- Bijou et bague : bleus, puissance %d, sans condition ni rangs, uniques." % z["objet"])
    else:
        w("-- Collier, bague et deux bijoux : bleus, puissance %d, sans condition ni rangs, uniques." % z["objet"])
    for e, source, nom, texte in objets:
        annexes.copie_objet(w, source, e, nom, "description = %s, Quality = 3, bonding = 1, ItemLevel = %d, "
                            "RequiredLevel = 0, RequiredSkill = 0, RequiredSkillRank = 0, AllowableClass = -1, "
                            "AllowableRace = -1, maxcount = 1, BuyPrice = 0, SellPrice = 0, RandomProperty = 0, "
                            "RandomSuffix = 0, itemset = 0, spellid_1 = 0, spelltrigger_1 = 0, spellid_2 = 0, "
                            "spelltrigger_2 = 0, %s" % (s(texte), z["objet"], bijou(source, z["objet"])))
        w("UPDATE item_template_locale SET Description = %s WHERE ID = %d AND locale = 'frFR';" % (s(texte), e))
    w("")
    if z["retraits"]:
        garde = ", ".join(map(str, z["retraits"]))
        w("-- Apparitions d'origine des rares copiés (Bras-de-pierre, Requin du sable) : retirées, table de retour.")
        w("CREATE TABLE solazeroth_v3_t6_apparitions SELECT * FROM creature WHERE guid IN (%s);" % garde)
        w("CREATE TABLE solazeroth_v3_t6_apparitions_addon SELECT * FROM creature_addon WHERE guid IN (%s);" % garde)
        w("DELETE FROM creature_addon WHERE guid IN (%s);" % garde)
        w("DELETE FROM creature WHERE guid IN (%s);" % garde)
        w("")
    w("-- Les rares : puissance %d, rang 4 (rare), vie et dégâts réglés par simulation ; sans le script d'origine."
      % puissance)
    lignes = []
    for guid, (entree, origine, nom, titre, position, o, _, techniques, (genre, valeur), _, *extra) in \
            enumerate(rares, z["guid"]):
        retouches = extra[0] if extra else {}
        vie, degats = reglages[entree]
        faction = ", faction = %d" % retouches["faction"] if "faction" in retouches else ""
        annexes.copie_creature(w, origine, entree, nom, titre,
                               ", `rank` = 4, minlevel = %d, maxlevel = %d, HealthModifier = %.3f, DamageModifier = %.3f, "
                               "AIName = 'SmartAI', ScriptName = '', lootid = %d, mingold = 0, maxgold = 0%s"
                               % (puissance, puissance, vie, degats, entree if genre == "objet" else 0, faction))
        w("UPDATE creature_template_model SET DisplayScale = DisplayScale * 1.3 WHERE CreatureID = %d;" % entree)
        w("INSERT INTO creature_equip_template (CreatureID, ID, ItemID1, ItemID2, ItemID3, VerifiedBuild) SELECT %d, ID, "
          "ItemID1, ItemID2, ItemID3, 0 FROM creature_equip_template WHERE CreatureID = %d;" % (entree, origine))
        if retouches.get("au_sol"):
            # Le Requin du sable ne quitte pas l'eau (Ground = 0) : sa copie marche sur le sable.
            w("INSERT INTO creature_template_movement (CreatureId, Ground, Swim, Flight, Rooted, Chase, Random) "
              "VALUES (%d, 1, 1, 0, 0, 0, 0);" % entree)
        x, y = position[:2]
        hauteur = position[2] if len(position) > 2 else annexes.hauteur(x, y)
        w("INSERT INTO creature (guid, id, map, zoneId, areaId, spawnMask, phaseMask, equipment_id, position_x, "
          "position_y, position_z, orientation, spawntimesecs, wander_distance, MovementType) VALUES "
          "(%d, %d, 1, %d, 0, 1, 1, 1, %d, %d, %.1f, %.1f, 1800, 0, 0);"
          % (guid, entree, z["zone"], x, y, hauteur, o))
        if genre == "objet":
            w("INSERT INTO creature_loot_template (Entry, Item, Reference, Chance, QuestRequired, LootMode, GroupId, "
              "MinCount, MaxCount, Comment) VALUES (%d, %d, 0, 100, 0, 1, 0, 1, 1, 'Sol''Azeroth v3 : rare secret');"
              % (entree, valeur))
        for n, (ev, ep, flags, sort, cible, comment) in enumerate(techniques):
            lignes.append("(%d, 0, %d, 0, %d, 0, 100, %d, %d, %d, %d, %d, 0, 0, 11, %d, 0, 0, 0, 0, 0, %d, 0, 0, 0, 0, "
                          "0, 0, 0, 0, %s)" % (entree, n, ev, flags, *ep, sort, cible, s(comment)))
    w("INSERT INTO smart_scripts (entryorguid, source_type, id, link, event_type, event_phase_mask, event_chance, "
      "event_flags, event_param1, event_param2, event_param3, event_param4, event_param5, event_param6, action_type, "
      "action_param1, action_param2, action_param3, action_param4, action_param5, action_param6, target_type, "
      "target_param1, target_param2, target_param3, target_param4, target_x, target_y, target_z, target_o, comment) "
      "VALUES\n" + ",\n".join(lignes) + ";")
    w("")
    if durotar:
        w("-- Liste lue par v3_rares_secrets.cpp ; vaincus par personnage.")
        w("CREATE TABLE IF NOT EXISTS solazeroth_v3_rares_secrets (creature INT UNSIGNED NOT NULL PRIMARY KEY, "
          "zone INT UNSIGNED NOT NULL, monture INT UNSIGNED NOT NULL);")
    else:
        w("-- Liste lue par v3_rares_secrets.cpp (table de la migration 121) ; vaincus par personnage.")
    w("REPLACE INTO solazeroth_v3_rares_secrets VALUES %s;" % ", ".join(
        "(%d, %d, %d)" % (r[0], z["zone"], r[8][1] if r[8][0] == "monture" else 0) for r in rares))
    if durotar:
        w("CREATE TABLE IF NOT EXISTS acore_characters.solazeroth_v3_rares_vaincus (guid INT UNSIGNED NOT NULL, "
          "creature INT UNSIGNED NOT NULL, PRIMARY KEY (guid, creature));")
    w("")
    sorts = ", ".join(map(str, z["monture"]))
    w("-- La monture devient secrète : hors de la boutique, vitesse 60 % (montures_v3.SECRETES, Spell.dbc du patch).")
    if durotar:
        w("DELETE FROM solazeroth_v3_montures WHERE sort = %d;" % MONTURE)
        w("UPDATE spell_dbc SET EffectBasePoints_2 = 59 WHERE ID = %d;" % MONTURE)
    else:
        w("DELETE FROM solazeroth_v3_montures WHERE sort IN (%s);" % sorts)
        w("UPDATE spell_dbc SET EffectBasePoints_2 = 59 WHERE ID IN (%s);" % sorts)
    w("")
    entrees = ", ".join(str(r[0]) for r in rares)
    objets_ids = ", ".join(str(e) for e, *_ in objets)
    vitesse, prix = z["boutique"]
    if durotar:
        down += ["-- Retire les rares secrets ; la monture revient en boutique à 135 %. Bijou, bague et montures déjà "
                 "gagnés",
                 "-- disparaissent (objets) ou restent au compte (monture)."]
    else:
        down += ["-- Retire les rares secrets des Tarides ; le Zhévra rapide revient en boutique à %d %%. Objets déjà "
                 "gagnés : disparaissent ;" % vitesse,
                 "-- monture : reste au compte. Les apparitions d'origine de Bras-de-pierre et du Requin du sable "
                 "reviennent."]
    down += ["USE acore_world;",
             "DELETE FROM creature WHERE guid BETWEEN %d AND %d;" % (z["guid"], z["guid"] + len(rares) - 1),
             "DELETE FROM smart_scripts WHERE source_type = 0 AND entryorguid IN (%s);" % entrees,
             "DELETE FROM creature_loot_template WHERE Entry IN (%s);" % entrees,
             "DELETE FROM creature_template WHERE entry IN (%s);" % entrees,
             "DELETE FROM creature_template_model WHERE CreatureID IN (%s);" % entrees,
             "DELETE FROM creature_equip_template WHERE CreatureID IN (%s);" % entrees]
    if not durotar:
        down.append("DELETE FROM creature_template_movement WHERE CreatureId IN (%s);" % entrees)
    down += ["DELETE FROM creature_template_locale WHERE entry IN (%s);" % entrees,
             "DELETE FROM item_template WHERE entry IN (%s);" % objets_ids,
             "DELETE FROM item_template_locale WHERE ID IN (%s);" % objets_ids]
    if durotar:
        down += ["DROP TABLE IF EXISTS solazeroth_v3_rares_secrets, acore_characters.solazeroth_v3_rares_vaincus;",
                 "INSERT IGNORE INTO solazeroth_v3_montures VALUES (%d, %d, %d);" % (MONTURE, vitesse, prix),
                 "UPDATE spell_dbc SET EffectBasePoints_2 = %d WHERE ID = %d;" % (vitesse - 1, MONTURE),
                 ""]
    else:
        down += ["DELETE FROM solazeroth_v3_rares_secrets WHERE creature IN (%s);" % entrees,
                 "DELETE FROM acore_characters.solazeroth_v3_rares_vaincus WHERE creature IN (%s);" % entrees,
                 "INSERT IGNORE INTO creature SELECT * FROM solazeroth_v3_t6_apparitions;",
                 "INSERT IGNORE INTO creature_addon SELECT * FROM solazeroth_v3_t6_apparitions_addon;",
                 "DROP TABLE solazeroth_v3_t6_apparitions, solazeroth_v3_t6_apparitions_addon;",
                 "INSERT IGNORE INTO solazeroth_v3_montures VALUES (%d, %d, %d);" % (z["monture"][0], vitesse, prix),
                 "UPDATE spell_dbc SET EffectBasePoints_2 = %d WHERE ID IN (%s);" % (vitesse - 1, sorts),
                 ""]
    base = chemin or z["migration"]
    for suffixe, contenu in ((".up.sql", up), (".down.sql", down)):
        with open(base + suffixe, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(contenu))
    if chemin:
        return
    import quetes_durotar
    quetes_durotar.item_dbc()
    ecrire_client()
    print("Migration %s écrite : %d rares, %d objets." % (os.path.basename(base)[:3], len(rares), len(objets)))


# --- Contrôle, après la migration : les trois classes contre les rares en base ------------------------------------------

def ouverture(techniques):
    """Une charge à l'engagement ou à distance met le rare au contact tout de suite (le démoniste ne le tient pas loin)."""
    return any(ev in (4, 9) and sort == CHARGE for ev, _, _, sort, *_ in techniques)


def controle(z):
    import simulation_demoniste as sd
    import simulation_voleur as sv
    g, d, v = joueurs_tarides() if z["zone"] == TARIDES else (None, None, None)
    b = bonus_tarides()
    db, vb = sd.avec_bonus(d, b), sv.avec_bonus(v, b)
    n, potion = donjons.N, z["potion"]
    print("%s, rares secrets en base (puissance %d), fiche de sortie des Cavernes, camp des Tarides, potion 4 :"
          % (z["nom"], z["puissance"]))
    print("victoires (%) sans / avec les autres bonus (panoplie 6, plat, pierre, renfort, 8 variantes Critique)")
    ecarts, totaux = [], {"guerrier": [], "démoniste": [], "voleur": []}
    for entree, origine, nom, _, _, _, _, techniques, *_ in z["rares"]:
        m = sim.monstre_depuis_base(entree, z["puissance"])
        m.course = 1000.0 if ouverture(techniques) else sd.vitesse(entree)
        r = {"guerrier": (sim.simuler(g, m, n, potion=potion)["victoire"], essai_tarides(g, m, b)),
             "démoniste": (sd.simuler(d, [m], n, potion=potion)["victoire"], sd.simuler(db, [m], n, potion=potion)["victoire"]),
             "voleur": (sv.simuler(v, [m], n, potion=potion)["victoire"], sv.simuler(vb, [m], n, potion=potion)["victoire"])}
        print("   %-22s vie %5d | " % (nom, m.vie) + " | ".join(
            "%s %5.1f / %5.1f" % (c, a, x) for c, (a, x) in r.items()))
        for c, (_, x) in r.items():
            totaux[c].append(x)
            if not 30 <= x <= 70:
                ecarts.append("%s contre %s : %.0f %%" % (c, nom, x))
    print("Moyennes avec les bonus : " + ", ".join("%s %.0f %%" % (c, sum(t) / len(t)) for c, t in totaux.items()))
    print("Écarts (hors 30 à 70 %) : " + ("; ".join(ecarts) if ecarts else "aucun"))
    return 1 if ecarts else 0


if __name__ == "__main__":
    z = ZONES["tarides" if "tarides" in sys.argv else "durotar"]
    if "--controle" in sys.argv:
        sys.exit(controle(z))
    r = simuler(z)
    if "--simuler" not in sys.argv:
        ecrire(r, z)
