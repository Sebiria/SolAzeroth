"""v3 (01/11/2026, demande de l'utilisateur) : rang d'aventurier et montures.

- Rang de compte, 40 paliers de 0 à 20 000 points (v3_aventurier.cpp ; proposition validée le 01/11/2026,
  « Rang d'aventurier et montures — proposition.md »). Le plafond sera relevé avec les zones suivantes.
- Plus aucune vente de monture native ni formation à la monte : sauvegardées puis retirées par la migration 092.
- C'est la monture qui donne sa vitesse, de 60 % à 150 % par pas de 5 % : le 2e effet des 186 montures terrestres
  (aura 32, vitesse montée) est réécrit dans Spell.dbc (client) et spell_dbc (serveur). Boutique en Marques du
  voyageur, ouverte au palier 10 ; chaque vitesse s'ouvre avec son palier.

Appelé par auras_nommees.py (lignes() puis ecrire()) ; écrit la migration 092 et
interface-v3\\FrameXML\\SolUI_AventurierDonnees.lua.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from cuisine_v3 import lua

MIGRATION = r"C:\SolAzeroth\sql\migrations\092_v3_aventurier"
LUA = r"C:\SolAzeroth\interface-v3\FrameXML\SolUI_AventurierDonnees.lua"

VITESSE = 81                                  # EffectBasePoints du 2e effet (valeur = points + 1)

# Récompenses : (genre, valeur, texte). Genres lus par v3_aventurier.cpp.
RIEN, TITRE, FOYER, MASCOTTE, MODE, MONTE, VITESSE_OUVERTE, MARQUES = range(8)
# Lot 5 : les difficultés des donjons s'ouvrent en réussissant la précédente ; leurs paliers donnent des Marques.
# Titres pris dans CharTitles.dbc (il n'y a ni « l'Aventurier » ni « le Légendaire » dans le jeu).
PALIERS = [
    (0, RIEN, 0, ""),
    (50, TITRE, 15, "Titre « Éclaireur »"),
    (150, FOYER, 25, "Pierre de foyer : 25 min"),
    (350, MASCOTTE, 10709, "Mascotte : Chien de prairie brun"),
    (500, MODE, 1, "Mode difficile des zones"),
    (750, TITRE, 168, "Titre « le pèlerin »"),
    (1000, FOYER, 20, "Pierre de foyer : 20 min"),
    (1300, MASCOTTE, 10683, "Mascotte : Ara aile verte"),
    (1600, MODE, 2, "Mode cauchemar des zones"),
    (1950, MONTE, 70, "Monte, une monture à 60 % offerte, boutique des montures (60 à 70 %)"),
    (2250, VITESSE_OUVERTE, 75, "Montures à 75 %"),
    (2650, MARQUES, 50, "50 Marques du voyageur"),
    (3050, VITESSE_OUVERTE, 80, "Montures à 80 %"),
    (3450, FOYER, 15, "Pierre de foyer : 15 min"),
    (3900, VITESSE_OUVERTE, 85, "Montures à 85 %"),
    (4350, TITRE, 91, "Titre « Traqueur »"),
    (4800, VITESSE_OUVERTE, 90, "Montures à 90 %"),
    (5300, MASCOTTE, 15999, "Mascotte : Jeune worg"),
    (5800, VITESSE_OUVERTE, 95, "Montures à 95 %"),
    (6350, MARQUES, 100, "100 Marques du voyageur"),
    (6850, VITESSE_OUVERTE, 100, "Montures à 100 %"),
    (7450, TITRE, 78, "Titre « l'explorateur »"),
    (8000, VITESSE_OUVERTE, 105, "Montures à 105 %"),
    (8600, FOYER, 10, "Pierre de foyer : 10 min"),
    (9200, VITESSE_OUVERTE, 110, "Montures à 110 %"),
    (9800, MASCOTTE, 10695, "Mascotte : Jeune dragonnet sombre"),
    (10450, VITESSE_OUVERTE, 115, "Montures à 115 %"),
    (11100, TITRE, 172, "Titre « l'assidu »"),
    (11750, VITESSE_OUVERTE, 120, "Montures à 120 %"),
    (12450, MARQUES, 150, "150 Marques du voyageur"),
    (13150, VITESSE_OUVERTE, 125, "Montures à 125 %"),
    (13850, MASCOTTE, 36031, "Mascotte : Jeune faucon-dragon bleu"),
    (14550, VITESSE_OUVERTE, 130, "Montures à 130 %"),
    (15300, TITRE, 74, "Titre « Ancien »"),
    (16050, VITESSE_OUVERTE, 135, "Montures à 135 %"),
    (16800, MASCOTTE, 46599, "Mascotte : Jeune phénix"),
    (17600, VITESSE_OUVERTE, 140, "Montures à 140 %"),
    (18400, MARQUES, 200, "200 Marques du voyageur"),
    (19200, VITESSE_OUVERTE, 145, "Montures à 145 %"),
    (20000, VITESSE_OUVERTE, 150, "Montures à 150 %, titre « le suprême »"),
]
TITRE_FINAL = 85                              # « %s le suprême », donné avec le dernier palier

PRIX = {60: 20, 65: 40, 70: 60, 75: 80, 80: 110, 85: 140, 90: 180, 95: 220, 100: 270, 105: 330, 110: 400,
        115: 480, 120: 570, 125: 670, 130: 780, 135: 900, 140: 1050, 145: 1200, 150: 1400}
# Première monture offerte au palier 10, selon la faction.
OFFERTE_HORDE, OFFERTE_ALLIANCE = 580, 458    # Loup des bois, Cheval bai

# Noms français du jeu (Spell.dbc), des plus simples aux plus belles. Un nom porté par plusieurs sorts (versions
# Horde et Alliance) ne paraît qu'une fois dans la boutique, mais tous ces sorts prennent la vitesse.
VITESSES = {
    60: ["Loup des bois", "Loup brun", "Loup redoutable", "Bélier gris", "Bélier brun", "Bélier blanc", "Pinto",
         "Jument alezane", "Cheval bai", "Etalon noir", "Mécanotrotteur non peint", "Mécanotrotteur rouge"],
    65: ["Raptor émeraude", "Raptor turquoise", "Raptor violet", "Kodo brun", "Kodo gris", "Sabre-de-givre rayé",
         "Sabre-de-givre tacheté", "Sabre-de-nuit rayé", "Mécanotrotteur bleu", "Mécanotrotteur vert",
         "Mécanotrotteur violet"],
    70: ["Cheval squelette bai", "Cheval squelette bleu", "Cheval squelette rouge", "Cheval squelette noir",
         "Faucon-pérégrin bleu", "Faucon-pérégrin noir", "Faucon-pérégrin rouge", "Faucon-pérégrin violet",
         "Elekk brun", "Elekk gris", "Elekk violet"],
    75: ["Kodo blanc", "Loup noir", "Mécanotrotteur vert fluorescent", "Mécanotrotteur rouge et bleu",
         "Sabre-de-l'aube rayé", "Bélier de la fête des Brasseurs", "Kodo de monte de la fête des Brasseurs",
         "Balai magique", "Léopard primal", "Tigre à dents de sabre fauve"],
    80: ["Loup brun rapide", "Loup des bois rapide", "Loup gris rapide", "Bélier brun rapide", "Bélier gris rapide",
         "Bélier blanc rapide", "Palefroi bai rapide", "Palefroi blanc rapide", "Palomino rapide",
         "Tigre à dents de sabre doré"],
    85: ["Raptor bleu rapide", "Raptor vert olive rapide", "Raptor orange rapide", "Grand kodo brun", "Grand kodo gris",
         "Grand kodo blanc", "Sabre-de-brume rapide", "Sabre-de-givre rapide", "Sabre-de-l'aube rapide"],
    90: ["Mécanotrotteur blanc rapide", "Mécanotrotteur jaune rapide", "Mécanotrotteur vert rapide",
         "Faucon-pérégrin rose rapide", "Faucon-pérégrin vert rapide", "Faucon-pérégrin violet rapide",
         "Grand elekk bleu", "Grand elekk vert", "Grand elekk violet", "Cheval de guerre squelette vert",
         "Cheval de guerre squelette violet", "Sabre-tempête rapide"],
    95: ["Loup bordeaux rapide", "Raptor violet rapide", "Bélier pourpre rapide", "Palefroi gris rapide",
         "Faucon-pérégrin rouge rapide", "Grand elekk rouge", "Grand kodo doré", "Sabre-de-lune rapide", "Turbotrotteur",
         "Cheval de guerre squelette blanc", "Bélier rapide de la fête des Brasseurs",
         "Grand kodo de la fête des Brasseurs"],
    100: ["Loup d'Orgrimmar", "Raptor sombrelance", "Kodo des Pitons du Tonnerre", "Cheval de guerre réprouvé",
          "Faucon-pérégrin de Lune-d'argent", "Bélier de Forgefer", "Palefroi de Hurlevent", "Sabre-de-nuit darnassien",
          "Elekk de l'Exodar", "Mécanotrotteur de Gnomeregan"],
    105: ["Loup blanc", "Loup rouge", "Kodo bleu", "Kodo vert", "Palomino", "Etalon blanc", "Raptor ivoire",
          "Raptor chamaré rouge"],
    110: ["Bélier de givre", "Bélier noir", "Mécanotrotteur bleu clair modèle A", "Mécanotrotteur blanc modèle B",
          "Sabre-de-nuit noir", "Ancien sabre-de-givre", "Sabre-de-givre de Berceau-de-l'Hiver", "Hurleur Loup-de-givre",
          "Destrier de bataille foudrepique"],
    115: ["Talbuk de monte argenté", "Talbuk de monte blanc", "Talbuk de monte brun", "Talbuk de monte cobalt",
          "Talbuk de monte sombre", "Talbuk de guerre argenté", "Talbuk de guerre blanc", "Talbuk de guerre brun",
          "Talbuk de guerre cobalt", "Talbuk de guerre sombre"],
    120: ["Loup de guerre noir", "Raptor de guerre noir", "Kodo de guerre noir", "Bélier de guerre noir",
          "Palefroi de guerre noir", "Tigre de guerre noir", "Trotteur de bataille noir", "Elekk de guerre noir",
          "Cheval de guerre squelette rouge", "Cheval de guerre squelette ocre", "Grand elekk d'élite",
          "Faucon de guerre rapide"],
    125: ["Ours polaire blanc", "Ours polaire brun", "Ours polaire noir", "Ours brun cuirassé",
          "Ours de guerre noir", "Loup rapide de la Horde", "Palefroi rapide de l'Alliance",
          "Faucon-pérégrin saccage-soleil", "Palefroi quel'dorei"],
    130: ["Mammouth laineux", "Mammouth des glaces", "Mammouth de guerre noir", "Grand mammouth des glaces",
          "Grand mammouth de guerre noir", "Cheval de guerre de l'Aube d'argent", "Destrier d'Argent",
          "Cheval de guerre blanc de croisé", "Cheval de guerre noir de croisé"],
    135: ["Tigre zulien rapide", "Faucon-pérégrin blanc rapide", "Seigneur corbeau",
          "Ours de guerre amani", "Destrier de la mort de Vaillefendre", "Cheval de guerre embrasé",
          "Char d'assaut qiraji bleu", "Char d'assaut qiraji jaune", "Char d'assaut qiraji rouge",
          "Char d'assaut qiraji vert"],
    140: ["Grand ours de bataille", "Ravasaure peau-de-venin", "Bécane de mekgénieur", "Mécabécane", "Tigre spectral",
          "Traqueur dimensionnel noir"],
    145: ["Tigre spectral rapide", "Mammouth de voyage de la toundra", "Rhinocéros laineux blanc"],
    150: ["Char d'assaut qiraji noir", "Destrier de la mort cramoisi"],
}
# Lot 6b (02/11/2026) : montures secrètes, hors boutique, gagnées ailleurs (rares_secrets_v3.py) : nom -> vitesse.
# Lot T6 des Tarides (03/11/2026) : le Zhévra rapide (125 % en boutique jusque-là) est la monture de Bras-de-pierre.
SECRETES = {"Raptor razzashi rapide": 60, "Zhévra rapide": 60}
MONTURE, OBJET_MONTURE = 15, 5                # classe et sous-classe des objets de monture
EFFET_MONTE, EFFET_VITESSE = 78, 32           # auras des montures terrestres
MONTE = [33388, 33391, 34090, 34091, 54197, 33389, 33392, 34092, 34093, 54198]   # formations à la monte


def montures(d):
    """Sorts de monture terrestre du jeu (objets de monture qui apprennent un sort à auras 78 et 32), par nom."""
    from quetes_durotar import sql
    par_nom = {}
    for sort in {int(v) for ligne in sql("SELECT spellid_1, spellid_2 FROM acore_world.item_template"
                                         " WHERE class = %d AND subclass = %d" % (MONTURE, OBJET_MONTURE)) for v in ligne}:
        e = d.chercher(sort) if sort > 0 else None
        if e and e[95:98] == [EFFET_MONTE, EFFET_VITESSE, 0] and e not in [x for l in par_nom.values() for x in l]:
            par_nom.setdefault(d.texte(e[138]), []).append(e)
    return par_nom


def lignes(d):
    """Réécrit la vitesse des montures dans Spell.dbc ; rend (sorts modifiés, catalogue [(sort, nom, vitesse)])."""
    par_nom = montures(d)
    noms = [n for liste in VITESSES.values() for n in liste] + list(SECRETES)
    assert len(noms) == len(set(noms)), "monture rangée à deux vitesses"
    assert set(noms) == set(par_nom), ("répartition incomplète", set(par_nom) ^ set(noms))
    modifies, catalogue = [], []
    for vitesse, liste in VITESSES.items():
        for nom in liste:
            sorts = sorted(par_nom[nom], key=lambda e: e[0])
            for e in sorts:
                e[VITESSE] = vitesse - 1
                modifies.append(e)
            catalogue.append((sorts[0][0], nom, vitesse))
    for nom, vitesse in SECRETES.items():   # vitesse réécrite, mais pas de vente
        for e in par_nom[nom]:
            e[VITESSE] = vitesse - 1
            modifies.append(e)
    return modifies, catalogue


def ecrire(modifies, catalogue, sorts_sql):
    ids = ", ".join(str(e[0]) for e in modifies)
    up = ["-- v3 : rang d'aventurier et montures. Généré par outils\\auras_nommees.py (montures_v3.py) : ne pas modifier à la main.",
          "-- Le client lit les mêmes vitesses dans patch-frFR-4.MPQ ; le rang et la boutique sont dans v3_aventurier.cpp.",
          "USE acore_world;",
          "DELETE FROM spell_dbc WHERE ID IN (%s);" % ids]
    up += sorts_sql
    up += ["DROP TABLE IF EXISTS solazeroth_v3_aventurier_paliers, solazeroth_v3_montures;",
           "CREATE TABLE solazeroth_v3_aventurier_paliers (palier TINYINT UNSIGNED NOT NULL PRIMARY KEY,"
           " points INT UNSIGNED NOT NULL, genre TINYINT UNSIGNED NOT NULL, valeur INT UNSIGNED NOT NULL);",
           "INSERT INTO solazeroth_v3_aventurier_paliers VALUES %s;" % ", ".join(
               "(%d, %d, %d, %d)" % (n, p, g, v) for n, (p, g, v, _) in enumerate(PALIERS, 1)),
           "CREATE TABLE solazeroth_v3_montures (sort INT UNSIGNED NOT NULL PRIMARY KEY,"
           " vitesse TINYINT UNSIGNED NOT NULL, prix INT UNSIGNED NOT NULL);",
           "INSERT INTO solazeroth_v3_montures VALUES %s;" % ", ".join(
               "(%d, %d, %d)" % (sort, vitesse, PRIX[vitesse]) for sort, _, vitesse in catalogue),
           # Ventes de montures et formations à la monte : gardées au premier passage, pour le retour.
           "CREATE TABLE IF NOT EXISTS solazeroth_v3_montures_ventes LIKE npc_vendor;",
           "INSERT IGNORE INTO solazeroth_v3_montures_ventes SELECT v.* FROM npc_vendor v"
           " JOIN item_template i ON i.entry = v.item WHERE i.class = %d AND i.subclass = %d;" % (MONTURE, OBJET_MONTURE),
           "DELETE v FROM npc_vendor v JOIN item_template i ON i.entry = v.item"
           " WHERE i.class = %d AND i.subclass = %d;" % (MONTURE, OBJET_MONTURE),
           "CREATE TABLE IF NOT EXISTS solazeroth_v3_montures_formation LIKE trainer_spell;",
           "INSERT IGNORE INTO solazeroth_v3_montures_formation SELECT * FROM trainer_spell WHERE SpellId IN (%s);"
           % ", ".join(map(str, MONTE)),
           "DELETE FROM trainer_spell WHERE SpellId IN (%s);" % ", ".join(map(str, MONTE)),
           # Rang de compte : objectifs déjà comptés (une fois par compte) et montures achetées.
           "CREATE TABLE IF NOT EXISTS acore_characters.solazeroth_v3_aventurier (compte INT UNSIGNED NOT NULL,"
           " genre TINYINT UNSIGNED NOT NULL, cle INT UNSIGNED NOT NULL, points INT UNSIGNED NOT NULL,"
           " PRIMARY KEY (compte, genre, cle));",
           "CREATE TABLE IF NOT EXISTS acore_characters.solazeroth_v3_montures_compte (compte INT UNSIGNED NOT NULL,"
           " sort INT UNSIGNED NOT NULL, PRIMARY KEY (compte, sort));"]
    down = ["-- Retire le rang d'aventurier v3 et rend les ventes de montures, la formation à la monte et les vitesses.",
            "USE acore_world;",
            up[3],
            "INSERT IGNORE INTO npc_vendor SELECT * FROM solazeroth_v3_montures_ventes;",
            "INSERT IGNORE INTO trainer_spell SELECT * FROM solazeroth_v3_montures_formation;",
            "DROP TABLE IF EXISTS solazeroth_v3_aventurier_paliers, solazeroth_v3_montures,"
            " solazeroth_v3_montures_ventes, solazeroth_v3_montures_formation;",
            "DROP TABLE IF EXISTS acore_characters.solazeroth_v3_aventurier, acore_characters.solazeroth_v3_montures_compte;"]
    for suffixe, contenu in ((".up.sql", up), (".down.sql", down)):
        with open(MIGRATION + suffixe, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(contenu) + "\n")
    ecrire_lua(catalogue)


def ecrire_lua(catalogue):
    """La boutique de l'interface (lot T6 des Tarides : aussi écrite par auras_nommees.py --client)."""
    sortie = ["-- Généré par outils\\montures_v3.py (auras_nommees.py) : ne pas modifier à la main.",
              "-- Paliers du rang d'aventurier { points, récompense } et boutique des montures { sort, nom, vitesse, prix }.",
              "SolUI.PALIERS = {"]
    sortie += ["    { %d, %s }," % (p, lua(t)) for p, _, _, t in PALIERS]
    ouvertures = {v: 10 for v in (60, 65, 70)}
    ouvertures.update({v: n for n, (_, g, v, _) in enumerate(PALIERS, 1) if g == VITESSE_OUVERTE})
    sortie += ["}", "-- Palier qui ouvre chaque vitesse.", "SolUI.VITESSES_PALIER = { %s }" % ", ".join(
        "[%d] = %d" % kv for kv in sorted(ouvertures.items())), "SolUI.MONTURES = {"]
    sortie += ["    { %d, %s, %d, %d }," % (sort, lua(nom), vitesse, PRIX[vitesse]) for sort, nom, vitesse in catalogue]
    sortie.append("}")
    with open(LUA, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(sortie) + "\n")
