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

py rares_secrets_v3.py            (simulation, puis migration 121)
py rares_secrets_v3.py --simuler  (simulation seule)
"""
import math
import os
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
# Objets hors des références de simulation (Durotar, départ de la zone 2).
EXCLUS = (BIJOU, BAGUE)

# Fiche « full bleu » : 8 pièces de maille, bouclier, cape, Lame maudite (une main).
GOUFFRE = [910241, 910242, 910243, 910244, 910245, 910246, 910247, 910248, 910270, 910271, 910265]

# (entrée, origine, nom, titre, (x, y), orientation, part des dégâts / vie, techniques, récompense, objet d'origine)
# Techniques : (événement, paramètres d'événement, drapeaux, sort, cible, commentaire) ; événements 0 en combat,
# 2 vie entre min et max %, 4 entrée en combat ; cibles 1 soi, 2 sa cible.
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


def fiche():
    """Le dernier personnage des journaux, tout en bleu du Gouffre au rang 0, avec le Repos et tous les bonus."""
    sebiria = [f for f in camp.fiches() if f.nom == "Sebiria"]
    j = sim.equiper(max(sebiria, key=lambda f: f.puissance), GOUFFRE, 1)
    j = camp.repos(j, 5)
    p, c = lot4c.PANOPLIE[2][1], lot4c.CONSOMMABLES
    bonus = lot4c.cumul(p, lot4c.PLATS[4][1], c[0][1], c[1][1], {"critique": lot4c.VARIANTES["Critique"] * lot4c.PIECES})
    return j, bonus


def monstre(origine, part, techniques, k):
    m = sim.monstre_depuis_base(origine, PUISSANCE_RARE)
    return modes.renforcer(m, k, part * (1 + TECHNIQUE * len(techniques)))


def regler(j, bonus, origine, part, techniques):
    """Facteur de vie et de dégâts pour environ 50 % de victoires (dichotomie)."""
    bas, haut = 0.2, 20.0
    for _ in range(20):
        k = (bas + haut) / 2
        t = lot4c.essai(j, monstre(origine, part, techniques, k), bonus)
        if VISEE[0] <= t <= VISEE[1]:
            break
        bas, haut = (k, haut) if t > VISEE[1] else (bas, k)
    return k, t


def simuler():
    j, bonus = fiche()
    print(j, "| bonus :", bonus)
    reglages = {}
    for entree, origine, nom, _, _, _, part, techniques, *_ in RARES:
        k, t = regler(j, bonus, origine, part, techniques)
        m = monstre(origine, part, techniques, k)
        base = sim.monstre_depuis_base(origine, PUISSANCE_RARE)
        brut = sim.simuler(j, m, donjons.N, potion=donjons.POTION_F7)
        print("%-24s puissance %d, facteur %.2f : vie %d, coups %d-%d ; %.0f %% (sans bonus %.0f %%), %.0f s"
              % (nom, PUISSANCE_RARE, k, m.vie, m.bas, m.haut, t, brut["victoire"], brut["duree"]))
        orig = sim.sql("SELECT HealthModifier, DamageModifier FROM acore_world.creature_template WHERE entry = %d"
                       % origine)[0]
        reglages[entree] = (float(orig[0]) * k, float(orig[1]) * k * part * (1 + TECHNIQUE * len(techniques)))
        assert base.vie > 0
    return reglages


def bijou(source):
    """Colonnes du bijou ou de la bague : barème des pièces au poids 0,56, sans armure ni arme."""
    ap = max(1, round(POIDS_BIJOU * PUISSANCE_OBJET * e3.AP_PAR_POINT))
    endurance = round(POIDS_BIJOU * PUISSANCE_OBJET * e3.ENDURANCE_PAR_POINT)
    return e3.colonnes_sql({"armor": 0, "dmg_min1": 0, "dmg_max1": 0, "block": 0, "ap": ap, "endurance": endurance})


def lignes_dbc():
    """(entrée, entrée copiée, genre) pour l'Item.dbc du patch."""
    return [(e, source, None) for e, source, *_ in OBJETS]


def ecrire(reglages):
    up, down = [], []
    w = up.append
    w("-- Audit du jeu, lot 6b (02/11/2026, C8) : trois rares secrets de Durotar. Généré par outils\\rares_secrets_v3.py :")
    w("-- ne pas modifier à la main. Scripts : v3_rares_secrets.cpp.")
    w("USE acore_world;")
    w("")
    w("-- Bijou et bague : bleus, puissance %d, sans condition ni rangs, uniques." % PUISSANCE_OBJET)
    for e, source, nom, texte in OBJETS:
        annexes.copie_objet(w, source, e, nom, "description = %s, Quality = 3, bonding = 1, ItemLevel = %d, "
                            "RequiredLevel = 0, RequiredSkill = 0, RequiredSkillRank = 0, AllowableClass = -1, "
                            "AllowableRace = -1, maxcount = 1, BuyPrice = 0, SellPrice = 0, RandomProperty = 0, "
                            "RandomSuffix = 0, itemset = 0, spellid_1 = 0, spelltrigger_1 = 0, spellid_2 = 0, "
                            "spelltrigger_2 = 0, %s" % (s(texte), PUISSANCE_OBJET, bijou(source)))
        w("UPDATE item_template_locale SET Description = %s WHERE ID = %d AND locale = 'frFR';" % (s(texte), e))
    w("")
    w("-- Les rares : puissance %d, rang 4 (rare), vie et dégâts réglés par simulation ; sans le script d'origine."
      % PUISSANCE_RARE)
    lignes = []
    for guid, (entree, origine, nom, titre, (x, y), o, _, techniques, (genre, valeur), _) in enumerate(RARES, GUID):
        vie, degats = reglages[entree]
        annexes.copie_creature(w, origine, entree, nom, titre,
                               ", `rank` = 4, minlevel = %d, maxlevel = %d, HealthModifier = %.3f, DamageModifier = %.3f, "
                               "AIName = 'SmartAI', ScriptName = '', lootid = %d, mingold = 0, maxgold = 0"
                               % (PUISSANCE_RARE, PUISSANCE_RARE, vie, degats, entree if genre == "objet" else 0))
        w("UPDATE creature_template_model SET DisplayScale = DisplayScale * 1.3 WHERE CreatureID = %d;" % entree)
        w("INSERT INTO creature_equip_template (CreatureID, ID, ItemID1, ItemID2, ItemID3, VerifiedBuild) SELECT %d, ID, "
          "ItemID1, ItemID2, ItemID3, 0 FROM creature_equip_template WHERE CreatureID = %d;" % (entree, origine))
        w("INSERT INTO creature (guid, id, map, zoneId, areaId, spawnMask, phaseMask, equipment_id, position_x, "
          "position_y, position_z, orientation, spawntimesecs, wander_distance, MovementType) VALUES "
          "(%d, %d, 1, %d, 0, 1, 1, 1, %d, %d, %.1f, %.1f, 1800, 0, 0);"
          % (guid, entree, DUROTAR, x, y, annexes.hauteur(x, y), o))
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
    w("-- Liste lue par v3_rares_secrets.cpp ; vaincus par personnage.")
    w("CREATE TABLE IF NOT EXISTS solazeroth_v3_rares_secrets (creature INT UNSIGNED NOT NULL PRIMARY KEY, "
      "zone INT UNSIGNED NOT NULL, monture INT UNSIGNED NOT NULL);")
    w("REPLACE INTO solazeroth_v3_rares_secrets VALUES %s;" % ", ".join(
        "(%d, %d, %d)" % (r[0], DUROTAR, r[8][1] if r[8][0] == "monture" else 0) for r in RARES))
    w("CREATE TABLE IF NOT EXISTS acore_characters.solazeroth_v3_rares_vaincus (guid INT UNSIGNED NOT NULL, "
      "creature INT UNSIGNED NOT NULL, PRIMARY KEY (guid, creature));")
    w("")
    w("-- La monture devient secrète : hors de la boutique, vitesse 60 % (montures_v3.SECRETES, Spell.dbc du patch).")
    w("DELETE FROM solazeroth_v3_montures WHERE sort = %d;" % MONTURE)
    w("UPDATE spell_dbc SET EffectBasePoints_2 = 59 WHERE ID = %d;" % MONTURE)
    w("")
    entrees = ", ".join(str(r[0]) for r in RARES)
    objets = ", ".join(str(e) for e, *_ in OBJETS)
    down += ["-- Retire les rares secrets ; la monture revient en boutique à 135 %. Bijou, bague et montures déjà gagnés",
             "-- disparaissent (objets) ou restent au compte (monture).",
             "USE acore_world;",
             "DELETE FROM creature WHERE guid BETWEEN %d AND %d;" % (GUID, GUID + len(RARES) - 1),
             "DELETE FROM smart_scripts WHERE source_type = 0 AND entryorguid IN (%s);" % entrees,
             "DELETE FROM creature_loot_template WHERE Entry IN (%s);" % entrees,
             "DELETE FROM creature_template WHERE entry IN (%s);" % entrees,
             "DELETE FROM creature_template_model WHERE CreatureID IN (%s);" % entrees,
             "DELETE FROM creature_equip_template WHERE CreatureID IN (%s);" % entrees,
             "DELETE FROM creature_template_locale WHERE entry IN (%s);" % entrees,
             "DELETE FROM item_template WHERE entry IN (%s);" % objets,
             "DELETE FROM item_template_locale WHERE ID IN (%s);" % objets,
             "DROP TABLE IF EXISTS solazeroth_v3_rares_secrets, acore_characters.solazeroth_v3_rares_vaincus;",
             "INSERT IGNORE INTO solazeroth_v3_montures VALUES (%d, 135, 900);" % MONTURE,
             "UPDATE spell_dbc SET EffectBasePoints_2 = 134 WHERE ID = %d;" % MONTURE,
             ""]
    for suffixe, contenu in ((".up.sql", up), (".down.sql", down)):
        with open(MIGRATION + suffixe, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(contenu))
    import quetes_durotar
    quetes_durotar.item_dbc()
    print("Migration 121 écrite : %d rares, %d objets." % (len(RARES), len(OBJETS)))


if __name__ == "__main__":
    r = simuler()
    if "--simuler" not in sys.argv:
        ecrire(r)
