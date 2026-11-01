"""v3 (01/11/2026, proposition validée par l'utilisateur : « Réputation des donjons — proposition.md ») : difficultés de
donjon, réputation des donjons et passifs.

- Difficultés 1 à 5, choisies à l'entrée du donjon (v3_donjons.cpp), ouvertes par le rang d'aventurier.
- Réputation des donjons, au compte : 10 rangs, qui ouvrent les emplacements des passifs de donjon.
- Passifs de donjon et du monde extérieur, tous ouverts : le joueur choisit lesquels mettre dans ses emplacements
  (v3_passifs.cpp). Emplacements extérieurs : ouverts par le rang d'aventurier, puis achetés en Marques.
- Valeurs ajustées par simulation (outils\\simulation_donjons.py) : chaque passif de combat vaut à peu près « + 5 % de
  puissance ».

Appelé par auras_nommees.py (lignes() puis ecrire()) : écrit les auras des passifs, la migration 093 et
interface-v3\\FrameXML\\SolUI_PassifsDonnees.lua.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from cuisine_v3 import lua
from techniques_v3 import AURA, INFINIE, SOI, D6, VIE_POURCENT, effet, technique

MIGRATION = r"C:\SolAzeroth\sql\migrations\093_v3_donjons"
LUA = r"C:\SolAzeroth\interface-v3\FrameXML\SolUI_PassifsDonnees.lua"

# Difficultés : (écart de puissance, vie et dégâts, techniques des monstres, éclats, palier du rang d'aventurier).
# Simulation : la proposition, écart +1 à +4 et × 1,2 à × 1,8, laissait la difficulté 2 à 0 % de victoires même avec
# deux rangs d'objet de plus ; celles-ci demandent environ 1, 3, 4 puis 5 rangs d'objet (et des passifs) de plus.
DIFFICULTES = {1: (0, 1.0, 0, 1.0, 0), 2: (0, 1.1, 1, 1.5, 12), 3: (0, 1.25, 2, 2.0, 20), 4: (1, 1.3, 2, 2.5, 30),
               5: (1, 1.4, 3, 3.0, 38)}
TECHNIQUES = ["Enragé : sous 30 % de vie, + 50 % de dégâts",
              "Renforçant : à sa mort, + 20 % de dégâts et de vie aux monstres à 30 m",
              "Volcanique : une pluie de feu sous vos pieds toutes les 10 s",
              "Explosif : une sphère instable à détruire en 6 s toutes les 12 s"]

# Réputation des donjons : seuils des rangs 1 à 10, et rang qui ouvre chaque emplacement.
RANGS = [0, 100, 300, 600, 1000, 1600, 2400, 3400, 4600, 6000]
EMPLACEMENTS_DONJON = [1, 2, 4, 6, 8, 10]
# Emplacements extérieurs : (palier du rang d'aventurier, prix en Marques du voyageur).
EMPLACEMENTS_EXTERIEUR = [(2, 25), (5, 50), (9, 100), (15, 175), (23, 275), (31, 400)]

# Auras des passifs qui changent une caractéristique (le reste est dans v3_passifs.cpp).
CARRURE, CUIRASSE, PAS_LEGER, FUITE, RODEUR = 100040, 100041, 100042, 100043, 100044
ARMURE_BASE_POURCENT, VITESSE, REPERE = 142, 31, 152

# (numéro, nom, effet) ; numéros lus par v3_passifs.cpp (SolAzeroth.h, enum Passif).
DONJON = [
    (1, "Peau de braise", "− 8 % de dégâts subis."),
    (2, "Soif de sang", "6 % des dégâts infligés rendus en vie."),
    (3, "Second souffle", "Une fois par combat, sous 30 % de vie : rend 15 % de la vie."),
    (4, "Épines", "Renvoie 7 % des dégâts de mêlée subis."),
    (5, "Récupération", "+ 2 % de vie par seconde hors combat."),
    (6, "Bourreau", "+ 30 % de dégâts contre une cible sous 35 % de vie."),
    (7, "Élan", "+ 2 % de dégâts par monstre tué, jusqu'à + 10 % ; perdu à la mort."),
    (8, "Brise-chef", "+ 10 % de dégâts contre les boss."),
    (9, "Contre la meute", "− 3 % de dégâts subis par ennemi au contact au-delà du premier, jusqu'à − 12 %."),
    (10, "Fureur du nombre", "+ 4 % de dégâts par ennemi qui vous attaque, jusqu'à + 16 %."),
    (11, "Premier sang", "+ 50 % de dégâts contre un monstre au-dessus de 80 % de vie."),
    (12, "Carrure", "+ 8 % de vie maximale."),
    (13, "Main vive", "Recharges des techniques − 10 %."),
    (14, "Cuirasse", "+ 6 % d'armure."),
    (15, "Pied sûr", "− 30 % de dégâts des pluies de feu, explosions et sorts de zone."),
    (16, "Fin de combat", "À la fin de chaque combat, rend 10 % de la vie."),
    (17, "Contre-attaque", "Quand on vous frappe, 20 % de chances de rendre une attaque."),
    (18, "Tenace", "− 25 % de durée des étourdissements, immobilisations et ralentissements."),
    (19, "Dernier rempart", "Une fois par donjon, une mort est évitée : vous restez à 30 % de vie."),
    (20, "Charognard", "+ 25 % d'éclats dans le donjon."),
    (21, "Pilleur de faille", "+ 1 Marque du voyageur par boss."),
]
# (numéro, branche, nom, effet)
EXTERIEUR = [
    (31, "Combat", "Embuscade", "+ 80 % de dégâts contre un monstre au-dessus de 90 % de vie."),
    (32, "Combat", "Chasseur de rares", "+ 10 % de dégâts contre les rares, les élites et les chefs renforcés."),
    (33, "Combat", "Solitaire", "− 8 % de dégâts subis quand un seul monstre vous attaque."),
    (34, "Combat", "Nettoyeur", "+ 10 % de dégâts contre les monstres des lieux à nettoyer."),
    (35, "Combat", "Défi tenu", "+ 5 s à chaque épreuve contre la montre."),
    (36, "Combat", "Mauvais œil", "En mode difficile ou cauchemar, les monstres ont une technique de moins (au moins une)."),
    (37, "Survie", "Fin de traque", "Chaque monstre tué rend 3 % de la vie."),
    (38, "Survie", "Second vent", "Régénération hors combat + 50 %."),
    (39, "Survie", "Instinct de fuite", "Sous 25 % de vie, + 30 % de vitesse de course pendant 6 s (une fois par minute)."),
    (40, "Survie", "Gorgée de plus", "+ 1 charge de potion."),
    (41, "Survie", "Veillée", "Le Repos du feu de camp dure + 50 %."),
    (42, "Survie", "Gourmet", "Les plats durent + 50 %."),
    (43, "Survie", "Âme tenace", "− 20 % d'âme perdue à la mort."),
    (44, "Récolte", "Cueilleur", "15 % de chances d'un composant de plus en récoltant (herbes, minerai, pêche)."),
    (45, "Récolte", "Main experte", "20 % de chances d'un éclat cadavérique en récoltant."),
    (46, "Récolte", "Éclats d'aventure", "+ 10 % d'éclats hors des instances."),
    (47, "Récolte", "Chasseur de primes", "+ 20 % de Marques du voyageur des primes, contrats et défis."),
    (48, "Voyage", "Pas léger", "+ 8 % de vitesse de course à pied."),
    (49, "Voyage", "Rôdeur", "Les monstres vous repèrent de 6 m moins loin."),
    (50, "Voyage", "Foyer proche", "Pierre de foyer − 5 min."),
    (51, "Voyage", "Marchandage", "− 10 % chez les marchands et pour les réparations."),
]


def lignes(d):
    def icone(sort):
        return d.chercher(sort)[133]
    t = []
    for ident, nom, texte, valeur, aura, misc, duree, modele in (
            (CARRURE, "Carrure", "Vie maximale augmentée de 8 %.", 8, VIE_POURCENT, 0, INFINIE, 1243),
            (CUIRASSE, "Cuirasse", "Armure augmentée de 6 %.", 6, ARMURE_BASE_POURCENT, 1, INFINIE, 71),
            (PAS_LEGER, "Pas léger", "Vitesse de course augmentée de 8 %.", 8, VITESSE, 0, INFINIE, 2983),
            (FUITE, "Instinct de fuite", "Vitesse de course augmentée de 30 %.", 30, VITESSE, 0, D6, 1850),
            (RODEUR, "Rôdeur", "Les monstres vous repèrent de 6 m moins loin.", -6, REPERE, 0, INFINIE, 1784)):
        e = technique(d, 12975, ident, nom, texte, icone(modele), 0, texte, duree=duree)
        e[131] = 0
        effet(e, 0, AURA, valeur, SOI, aura=aura, misc=misc)
        t.append(e)
    return t


def ecrire(sorts_sql):
    ids = ", ".join(str(i) for i in (CARRURE, CUIRASSE, PAS_LEGER, FUITE, RODEUR))
    up = ["-- v3 : difficultés de donjon, réputation des donjons et passifs. Généré par outils\\auras_nommees.py (passifs_v3.py) :",
          "-- ne pas modifier à la main. Le client lit les mêmes auras dans patch-frFR-4.MPQ ; le reste est dans",
          "-- v3_donjons.cpp et v3_passifs.cpp.",
          "USE acore_world;",
          "DELETE FROM spell_dbc WHERE ID IN (%s);" % ids]
    up += sorts_sql
    up += ["CREATE TABLE IF NOT EXISTS acore_characters.solazeroth_v3_reputation (compte INT UNSIGNED NOT NULL PRIMARY KEY,"
           " points INT UNSIGNED NOT NULL, emplacements TINYINT UNSIGNED NOT NULL DEFAULT 0);",
           # genre 0 : donjon, 1 : extérieur ; emplacement 0 à 5.
           "CREATE TABLE IF NOT EXISTS acore_characters.solazeroth_v3_passifs (compte INT UNSIGNED NOT NULL,"
           " genre TINYINT UNSIGNED NOT NULL, emplacement TINYINT UNSIGNED NOT NULL, passif TINYINT UNSIGNED NOT NULL,"
           " PRIMARY KEY (compte, genre, emplacement));",
           "CREATE TABLE IF NOT EXISTS acore_characters.solazeroth_v3_donjons (instance INT UNSIGNED NOT NULL PRIMARY KEY,"
           " difficulte TINYINT UNSIGNED NOT NULL, techniques TINYINT UNSIGNED NOT NULL, verrouille TINYINT UNSIGNED NOT NULL);"]
    down = ["-- Retire les difficultés de donjon, la réputation des donjons et les passifs v3.", "USE acore_world;", up[4],
            "DROP TABLE IF EXISTS acore_characters.solazeroth_v3_reputation, acore_characters.solazeroth_v3_passifs,"
            " acore_characters.solazeroth_v3_donjons;"]
    for suffixe, contenu in ((".up.sql", up), (".down.sql", down)):
        with open(MIGRATION + suffixe, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(contenu) + "\n")

    s = ["-- Généré par outils\\passifs_v3.py (auras_nommees.py) : ne pas modifier à la main.",
         "-- Difficultés { écart, vie et dégâts, techniques, éclats, palier }, techniques des monstres, rangs de réputation,",
         "-- emplacements, passifs de donjon { numéro, nom, effet } et du monde extérieur { numéro, branche, nom, effet }.",
         "SolUI.DIFFICULTES = {"]
    s += ["    { %d, %s, %d, %s, %d }," % (e, lua(("%.2f" % f).rstrip("0").rstrip(".").replace(".", ",")), t,
                                         lua(("%.1f" % x).rstrip("0").rstrip(".").replace(".", ",")), p)
          for e, f, t, x, p in DIFFICULTES.values()]
    s += ["}", "SolUI.TECHNIQUES_DONJON = { %s }" % ", ".join(lua(t) for t in TECHNIQUES),
          "SolUI.RANGS_REPUTATION = { %s }" % ", ".join(map(str, RANGS)),
          "SolUI.EMPLACEMENTS_DONJON = { %s }" % ", ".join(map(str, EMPLACEMENTS_DONJON)),
          "SolUI.EMPLACEMENTS_EXTERIEUR = { %s }" % ", ".join("{ %d, %d }" % e for e in EMPLACEMENTS_EXTERIEUR),
          "SolUI.PASSIFS_DONJON = {"]
    s += ["    { %d, %s, %s }," % (n, lua(nom), lua(texte)) for n, nom, texte in DONJON]
    s += ["}", "SolUI.PASSIFS_EXTERIEUR = {"]
    s += ["    { %d, %s, %s, %s }," % (n, lua(b), lua(nom), lua(texte)) for n, b, nom, texte in EXTERIEUR]
    s.append("}")
    with open(LUA, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(s) + "\n")
