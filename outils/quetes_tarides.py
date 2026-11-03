"""Lot T2 des Tarides (03/11/2026) : les 30 quêtes d'histoire, T01 à T30, et la quête-pont D31 depuis Durotar.

Source : « Les Tarides — Histoire et quêtes (brouillon).md », §2 (titres, introductions, progressions, fins) et D31
(§1, « Le passage de Durotar aux Tarides »). La mécanique est décrite ici, d'après le même document. Les quêtes passent
par le générateur de Durotar (quetes_durotar.quetes_sql), paramétré par la zone : rien n'est dupliqué.

Écrit la migration 139 :
- quêtes 910041 à 910070 (T01 à T30 ; T31 à T36 seront 910071 à 910076, lot T5) et D31 (910031, Orgnil -> Kargal,
  hors pourcentage) ;
- « se prend avec » (T07, T08, T11, T13, T21, T25) : quête en cours, remplie ou rendue (conditions 9, 28 et 8) ;
- 21 récompenses (910701 à 910721) au barème d'equipement_v3.py, et non à leurs chiffres d'origine ; leurs rangs 1 à 5 ;
  leurs versions par classe (solazeroth_v3_versions) : tissu, orbes et dagues pour le démoniste (910731 à 910753),
  cuir et dagues de main gauche pour le voleur (910761 à 910783), avec leurs rangs ;
- or : puissance × 30 cuivres ; Marques des quêtes sans pièce : 5 (acte I), 6 (II), 7 (III), 8 (IV) ;
- quêtes d'origine des Tarides retirées (disables, dont 5042 et 5043) ; la passe des objets qui lancent une quête
  retirée (comme la migration 100, avec la règle de la 108) ; faux indicateurs de quête retirés (comme la 120) ;
- objectifs d'origine repris : zone de déclenchement 216 (T09), Fissure bouillonnante (T10), Cadavre battu (T20) ;
- Sarilus Souillemporte (3986) passe de la faction 118 (Fossoyeuse, amie de la Horde) à 554 (Lame ardente) ;
  Takar le Prophète (6244) entre dans le Camp Taurajo, à la faction 29 (Orgrimmar : la 12 était Hurlevent) ;
  Géoprêtresse Gukk'rok (5863) réapparaît en 5 minutes au lieu de 19 900 s ;
- cris des chefs en table (solazeroth_v3_cris, v3_paroles.cpp) : ceux de Durotar et les 7 chefs des Tarides.
Tout ce qui touche à Blizzard a sa table de retour (solazeroth_v3_t2_*).

py quetes_durotar.py tarides   (écrit la migration, l'Item.dbc du patch et SolUI_Puissances.lua)
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import equipement_v3 as e3
import quetes_durotar as qd
import tissu_v3
from quetes_durotar import s, sql

ICI = os.path.dirname(os.path.abspath(__file__))
DOC = os.path.join(os.path.expanduser("~"), "Documents", "Claude", "Sol'Azeroth",
                   "Les Tarides — Histoire et quêtes (brouillon).md")
MIGRATION = os.path.join(ICI, "..", "sql", "migrations", "139_v3_tarides_histoire")

TARIDES, CARTE_TARIDES = 17, 11          # zone, WorldMapArea des Tarides
QUETE = 910040                           # T01 = 910041
D31, D30 = 910031, 910030
COMMENTAIRE = "Sol''Azeroth v3 : quete d''origine des Tarides"

# Acte I : 14 à 16 ; acte II : 16 (T09), 18 à 22 ; acte III : 22 (T17), 25 à 27 ; acte IV : 27 à 30. p : la puissance
# de la quête (or, niveau de la pièce, affichage) : le haut de la plage des monstres visés (T02, T03 et T05 recalés
# sur la base, lot T1). tuer : (créature, nombre, centre[, libellé]) ; go : (objet du monde, nombre, centre, libellé) ;
# objets : (objet, nombre, centre) ; prev : quêtes à avoir rendues ; avec : quête à avoir en cours, remplie ou rendue.
Q = {
    D31: dict(cle="D31", de=3142, a=3337, p=14, prev=[D30],
              resume="Passe le pont de la Furie-du-Sud et présente-toi à Kargal Balafre-glorieuse, au Poste de garde "
                     "extérieur."),
    1: dict(de=3337, a=3429, p=14, marques=5, resume="Suis la route de l'ouest jusqu'à la Croisée et parle à Thork."),
    2: dict(de=3338, a=3338, p=15, prev=[1], objets=[(5087, 7, [(-78, -2535), (-349, -2598)])],
            resume="Rapporte 7 Becs de trotteur des plaines à Sergra Sombreronce."),
    3: dict(de=3338, a=3338, p=15, prev=[2], objets=[(5086, 4, (-343, -2583))],
            resume="Rapporte 4 Sabots de zhévra à Sergra Sombreronce."),
    4: dict(de=3390, a=3390, p=16, prev=[1], marques=5, objets=[(5012, 4, (78, -1927))],
            resume="Rapporte 4 Spores fongiques des Bassins oubliés à l'apothicaire Helbrim."),
    5: dict(de=3429, a=3429, p=16, prev=[1],
            tuer=[(3267, 8, (-154, -2930)), (3268, 8, (-154, -2930)), (3265, 3, (-154, -2930))],
            resume="Tue 8 Sourciers, 8 Tisseuses d'épines et 3 Chasseurs Tranchecrin à la Colline des épines."),
    6: dict(de=3521, a=3429, p=16, tuer=[(3379, 8, (363, -2172)), (3380, 6, (363, -2172))],
            resume="Tue 8 Cogneurs et 6 Acolytes de la Lame ardente au Pic de Brume-funeste, puis préviens Thork, "
                   "à la Croisée."),
    7: dict(de=3429, a=3429, p=16, avec=5, tuer=[(3269, 8, (-112, -3308)), (3266, 8, (-112, -3308))],
            objets=[(5063, 1, (-214, -3308))],
            resume="Tue 8 Géomanciennes et 8 Défenseurs Tranchecrin au sommet de la Colline des épines, et rapporte "
                   "la Défense de Kreenig Grondegroin."),
    8: dict(de=3521, a=3429, p=16, avec=6, tuer=[(3986, 1, (319, -2264))],
            resume="Abats Sarilus Souillemporte, au sommet du Pic de Brume-funeste, et porte ses lettres à Thork."),
    9: dict(de=3448, a=3448, p=16, prev=[8], marques=6, explorer=(216, (90, -1943), "Explorer les Bassins oubliés"),
            resume="Va voir les Bassins oubliés, au nord-ouest de la Croisée."),
    10: dict(de=3448, a=3448, p=19, prev=[9], depart=5068,
             go=[(3737, 1, (-1276, -3012), "Graines séchées jetées dans la fissure")],
             resume="Jette les Graines séchées dans la Fissure bouillonnante de l'Oasis stagnante."),
    11: dict(de=3448, a=3448, p=19, avec=10, objets=[(5098, 8, (-1070, -2118))],
             resume="Rapporte 8 Carapaces de Gueule d'acier altérées à Tonga Totem-runique."),
    12: dict(de=3389, a=3389, p=19, prev=[8], objets=[(5030, 12, (-1015, -2090))],
             resume="Rapporte 12 Bracelets de centaure pris aux Kolkar de l'Oasis luxuriante."),
    13: dict(de=3389, a=3389, p=22, avec=12, objets=[(5025, 1, (-1167, -2042))],
             resume="Abats Hezrul Marque-de-sang, à l'Oasis luxuriante, et rapporte sa tête."),
    14: dict(de=3391, a=3391, p=18, prev=[8], marques=6, tuer=[(3381, 12, (-1525, -3844)), (3382, 6, (-1525, -3844))],
             resume="Tue 12 Brigands et 6 Canonniers des mers du Sud sur la Côte des marchands."),
    15: dict(de=3339, a=3339, p=22, prev=[14],
             tuer=[(3393, 1, (-2080, -3644)), (3455, 1, (-2094, -3496)), (3454, 1, (-2210, -3778))],
             objets=[(5078, 6, (-2067, -3624))],
             resume="Au Fort du Nord, tue le Capitaine Beaumont, le Canonnier Whessan et le Canonnier Smythe, et "
                    "rapporte 6 Médailles de Theramore."),
    16: dict(de=3448, a=8418, p=21, prev=[11, 13], marques=6,
             resume="Monte voir Falla Vent-de-sagesse, au sommet de la colline des Cavernes."),
    17: dict(de=8418, a=3418, p=22, prev=[16], resume="Rejoins Kirge Corne-sévère, au Camp Taurajo."),
    18: dict(de=3430, a=3430, p=25, prev=[17],
             tuer=[(3260, 6, (-2063, -2192)), (3261, 8, (-2032, -2403)), (3263, 8, (-1832, -2193))],
             resume="Tue 6 Sourciers, 8 Tisseurs d'épines et 8 Géomanciennes Dos-hirsute à Agama'gor et à Ronceplaie."),
    19: dict(de=3430, a=3430, p=25, prev=[18], objets=[(5075, 4, (-1817, -1818))],
             resume="Rapporte 4 Joyaux de sang d'Agama'gor à Mutiledent."),
    20: dict(de=3432, a=3432, p=25, prev=[16], marques=7, tuer=[(10668, 1, (-1787, -2376), "Olgra retrouvée")],
             resume="Retrouve Olgra, la femme de Mankrik, au sud, près de Ronceplaie."),
    21: dict(de=3432, a=3432, p=25, avec=20, objets=[(5085, 15, (-1817, -1818))],
             resume="Rapporte 15 Défenses de huran Dos-hirsute à Mankrik."),
    22: dict(de=3387, a=3387, p=27, prev=[17], objets=[(5143, 3, (-2607, -2133))],
             resume="Rapporte 3 Sangs de lézard-tonnerre à Jorn Oeil-des-cieux."),
    23: dict(de=3418, a=3418, p=27, prev=[19], tuer=[(5863, 1, (-1907, -1753))],
             resume="Abats la Géoprêtresse Gukk'rok, au cœur d'Agama'gor."),
    24: dict(de=3341, a=3341, p=27, prev=[23], tuer=[(3374, 10, (-4142, -2196)), (3375, 5, (-4142, -2196))],
             objets=[(5006, 1, (-4213, -2274))],
             resume="À Bael Modan, tue 10 Excavateurs et 5 Contremaîtres de Bael'dun, et rapporte le Journal de "
                    "Khazgorm."),
    25: dict(de=3341, a=3341, p=30, avec=24, marques=8,
             objets=[(5017, 4, (-4074, -2375)), (5018, 4, (-4074, -2375)), (5019, 4, (-4074, -2375))],
             resume="Rapporte à Gann 4 Nitroglycérine, 4 Pulpe de bois et 4 Nitrate de sodium, pris aux soldats de "
                    "Bael'dun."),
    26: dict(de=3341, a=3341, p=29, prev=[25], depart=5021,
             go=[(3644, 1, (-4173, -2137), "Machine volante de Bael Modan détruite")],
             resume="Pose le Bâton explosif de Gann contre la Machine volante de Bael Modan."),
    27: dict(de=3421, a=3421, p=30, prev=[26], tuer=[(3414, 1, (-4077, -2362))], objets=[(5038, 1, (-4080, -2355))],
             resume="Abats le Général Doublenattes, en haut du Donjon de Bael'dun, et prends la Larme des lunes dans "
                    "son coffre."),
    28: dict(de=3430, a=3418, p=30, prev=[23],
             objets=[(5074, 1, (-3815, -1955)), (5073, 1, (-4002, -1817)), (5072, 1, (-3829, -1446))],
             resume="Rapporte à Kirge Corne-sévère les crânes de Kuz, de Nak et de Lok Plaie-des-orcs, sur la Crête "
                    "de Noirépine."),
    29: dict(de=3421, a=8418, p=30, prev=[27], marques=8, depart=5038, objets=[(5038, 1, (-602, -2260))],
             resume="Apporte la Larme des lunes à Falla Vent-de-sagesse, au sommet de la colline des Cavernes."),
    30: dict(de=8418, a=5768, p=30, prev=[28, 29], marques=8,
             resume="Présente-toi à Ebru, dans la grotte des disciples, au-dessus de l'entrée des Cavernes."),
}

# Récompenses : (entrée, quête, nom, objet d'origine pour l'apparence et le type). Puissance = celle de la quête.
# Maille, boucliers et épées pour le monde ; un seul nom, neutre, pour toutes les versions (conventions du brouillon).
RECOMPENSES = [
    (910701, 2, "Bottes de la savane", 3302),
    (910702, 3, "Gants de Sombreronce", 2980),
    (910703, 5, "Jambières des caravanes", 3305),
    (910704, 6, "Brassards d'Ak'Zeloth", 14723),
    (910705, 7, "Lame de Thork", 1219),
    (910706, 8, "Garde de Brume-funeste", 5325),
    (910707, 10, "Ceinture de Totem-runique", 2857),
    (910708, 11, "Cotte des gueules d'acier", 3306),
    (910709, 12, "Cape de Seuil-de-mort", 5542),
    (910710, 13, "Lame d'Hezrul", 16891),
    (910711, 15, "Épaulières du second", 3480),
    (910712, 17, "Brassards de Corne-sévère", 14743),
    (910713, 18, "Jambières de Mutiledent", 14748),
    (910714, 19, "Garde d'Agammagan", 4820),
    (910715, 21, "Gants d'Olgra", 15463),
    (910716, 22, "Bottes d'Oeil-des-cieux", 1955),
    (910717, 23, "Couvre-chef de Corne-sévère", 6389),
    (910718, 24, "Cotte de Cime-de-pierre", 3049),
    (910719, 26, "Ceinture de Bael Modan", 4712),
    (910720, 27, "Garde de Doublenattes", 4064),
    (910721, 28, "Lame de Noirépine", 753),
]
MAILLE, BOUCLIER, CAPE = 3, 6, 16
# Versions : apparences de tissu_v3.py (celles de Durotar), plus la tête et les épaules, nouvelles aux Tarides.
TISSU = {**tissu_v3.MODELES, 1: 7048, 3: 4314}          # Chaperon azur en soie, Épaulières à double couture
CUIR = {**tissu_v3.MODELES_CUIR, 1: 3392, 3: 4709}      # Casque annelé, Mantelet sylvestre en cuir
PREMIERE_TISSU, PREMIERE_DAGUE, PREMIERE_CUIR, PREMIERE_DAGUE_MG = 910731, 910751, 910761, 910781
DEMONISTE, VOLEUR = tissu_v3.DEMONISTE, tissu_v3.VOLEUR

ZONE = dict(nom="Les Tarides", prefixe="T", doc=DOC, base=QUETE, quetes=Q, tri=TARIDES, carte=CARTE_TARIDES,
            recompenses={q: e for e, q, *_ in RECOMPENSES},
            origine_ou="map = 1 AND zoneId = %d" % TARIDES, origine_tri=(TARIDES,), commentaire=COMMENTAIRE)

# Cris des chefs à l'engagement (v3_paroles.cpp), une fois par apparition : ceux de Durotar (repris du code) et les
# 7 chefs des Tarides (comparatif, 11.2).
CRIS = [
    (3183, 14, "Les recrues de Thrall… La Lame ardente a faim de chair fraîche !"),           # Yarrog Plaie-d'ombre
    (3192, 14, "Un orc dans mon donjon ? Gardes ! Abattez-le !"),                            # Lieutenant Benedict
    (5808, 14, "La combe est aux Kolkar ! Tu n'en sortiras pas vivant."),                    # Kolkanis
    (3205, 14, "Mes enfants, à moi ! Vol'jin paiera pour cette insolence !"),                # Zalazane
    (3203, 14, "Tu tombes mal : je préparais justement un petit feu…"),                      # Féplouf Sombrorage
    (3204, 14, "L'Œil m'a montré ta venue. Il m'a aussi montré ta mort."),                   # Gazz'uz
    (11517, 2437, "Intrus ! Les Ragefeu vont t'écraser !"),                                  # Lorgnesilex
    (11518, 2437, "Les ombres répondent à mon appel, pas au tien !"),                        # Jergosh l'Invocateur
    (11519, 2437, "Tu oses descendre dans l'antre de la Lame ?"),                            # Bazzalan
    (11520, 2437, "Encore un cœur à dévorer ! Approche !"),                                  # Taragaman l'Affameur
    (3438, 17, "La colline est aux Tranchecrins ! Tes os nourriront les ronces."),           # Kreenig Grondegroin
    (3986, 17, "Encore un chien de Thrall ? Le rêve te rendra fou, comme les autres."),      # Sarilus Souillemporte
    (3396, 17, "L'eau m'a parlé de toi. Elle veut ton sang !"),                              # Hezrul Marque-de-sang
    (3393, 17, "La Horde dans mon fort ? Canonniers, feu à volonté !"),                      # Capitaine Beaumont
    (5863, 17, "Le sang d'Agammagan ne sera jamais à toi !"),                                # Géoprêtresse Gukk'rok
    (3414, 17, "La gemme appartient à Bael'dun ! Tu n'y toucheras pas !"),                   # Général Doublenattes
    (3435, 17, "Lok écrase les orcs, et tous ceux qui marchent avec eux !"),                 # Lok Plaie-des-orcs
]

# Takar le Prophète (6244), maître du démoniste à l'étape 2 : son unique apparition entre dans le Camp Taurajo, entre
# Gahroot et Yonada, sur la plate-forme de Ruga Totem-de-rage (z relevé sur leurs apparitions).
TAKAR, GUID_TAKAR, PLACE_TAKAR = 6244, 14333, (-2400.5, -1924.5, 96.8255, 0.56)
SARILUS, LAME_ARDENTE = 3986, 554           # faction des Cogneurs et Acolytes de la Lame ardente (3379, 3380)
ORGRIMMAR = 29
GUKKROK, GUID_GUKKROK, DELAI_GUKKROK = 5863, 20939, 300
BASSINS, FISSURE, CADAVRE_MENU = 216, 3737, 2871
ORIGINE = {"bassins": 870, "fissure": 877, "cadavre": 4921}


def puissance(n):
    return Q[n]["p"]


# --- Pièces et versions -------------------------------------------------------------------------------------------

def modeles():
    return e3.objets({m for *_, m in RECOMPENSES} | set(TISSU.values()) | set(CUIR.values()) | {tissu_v3.DAGUE})


def versions_par_piece(sources):
    """(classe, origine, version, nom, modèle, puissance) : le démoniste reçoit le tissu, l'orbe ou la dague ; le voleur
    le cuir, la dague de main gauche ou la dague. La cape (tissu) va à tous."""
    lignes, n_tissu, n_dague, n_cuir, n_mg = [], PREMIERE_TISSU, PREMIERE_DAGUE, PREMIERE_CUIR, PREMIERE_DAGUE_MG
    for e, q, nom, source in RECOMPENSES:
        m = sources[source]
        classe, sc, emplacement = int(m["class"]), int(m["subclass"]), int(m["InventoryType"])
        p = puissance(q)
        if classe == 2:
            lignes.append((DEMONISTE, e, n_dague, nom, tissu_v3.DAGUE, p))
            lignes.append((VOLEUR, e, n_dague, nom, tissu_v3.DAGUE, p))
            n_dague += 1
        elif sc == BOUCLIER:
            lignes.append((DEMONISTE, e, n_tissu, nom, TISSU[tissu_v3.MAIN_GAUCHE], p))
            lignes.append((VOLEUR, e, n_mg, nom, tissu_v3.DAGUE, p))
            n_tissu += 1
            n_mg += 1
        elif sc == MAILLE:
            lignes.append((DEMONISTE, e, n_tissu, nom, TISSU[emplacement], p))
            lignes.append((VOLEUR, e, n_cuir, nom, CUIR[emplacement], p))
            n_tissu += 1
            n_cuir += 1
    return lignes


def pieces():
    """Toutes les pièces à écrire : (entrée, nom, modèle, puissance, vendable), récompenses puis versions (sans les
    doublons : une dague sert au démoniste et au voleur)."""
    sources = modeles()
    liste = [(e, nom, source, puissance(q), True) for e, q, nom, source in RECOMPENSES]
    vues = set()
    for _, _, v, nom, modele, p in versions_par_piece(sources):
        if v not in vues:
            vues.add(v)
            liste.append((v, nom, modele, p, False))
    return liste


def versions():
    """(classe, origine, version, nom), pour SolUI_Versions.lua (tissu_v3.ecrire_versions_lua)."""
    return [(c, o, v, nom) for c, o, v, nom, _, _ in versions_par_piece(modeles())]


def lignes_dbc():
    """Item.dbc : (entrée, entrée dont on copie la ligne, genre), la base avant ses rangs. Sans lecture de la base :
    les versions se numérotent dans l'ordre des récompenses, comme versions_par_piece."""
    lignes, vues = [], set()
    n_tissu, n_dague, n_cuir, n_mg = PREMIERE_TISSU, PREMIERE_DAGUE, PREMIERE_CUIR, PREMIERE_DAGUE_MG
    for e, q, nom, source in RECOMPENSES:
        lignes.append((e, source))
        genre = GENRES[e]
        if genre == "arme":
            lignes.append((n_dague, tissu_v3.DAGUE))
            n_dague += 1
        elif genre == "main gauche":
            lignes += [(n_tissu, TISSU[tissu_v3.MAIN_GAUCHE]), (n_mg, tissu_v3.DAGUE)]
            n_tissu += 1
            n_mg += 1
        elif genre != "cape":
            lignes += [(n_tissu, TISSU[genre]), (n_cuir, CUIR[genre])]
            n_tissu += 1
            n_cuir += 1
    resultat = []
    for e, source in lignes:
        if e in vues:
            continue
        vues.add(e)
        resultat.append((e, source, None))
        resultat += [(e3.entree_rang(e, r), e, None) for r in range(1, e3.RANGS + 1)]
    return resultat


# Genre de chaque récompense (pour Item.dbc sans lire la base) : emplacement de la maille, ou arme, main gauche, cape.
GENRES = {910701: 8, 910702: 10, 910703: 7, 910704: 9, 910705: "arme", 910706: "main gauche", 910707: 6, 910708: 5,
          910709: "cape", 910710: "arme", 910711: 3, 910712: 9, 910713: 7, 910714: "main gauche", 910715: 10,
          910716: 8, 910717: 1, 910718: 5, 910719: 6, 910720: "main gauche", 910721: "arme"}


def pieces_sql():
    """Pièces aux rangs 0 à 5, au barème (equipement_v3.caracteristiques ; orbes : tissu_v3.caracteristiques), rangs
    et versions. Bouclier : le blocage de son objet d'origine, +10 % par rang, comme Durotar."""
    armures, armes = e3.baremes()
    sources = modeles()
    liste = pieces()
    toutes = [e3.entree_rang(e, r) if r else e for e, *_ in liste for r in range(e3.RANGS + 1)]
    up = ["DELETE FROM item_template WHERE entry IN (%s);" % ", ".join(map(str, toutes))]
    for e, nom, source, p, vendable in liste:
        m = sources[source]
        c = tissu_v3.caracteristiques(m, p, armures, armes)
        bloc = int(m["block"]) if int(m["class"]) == 4 and int(m["subclass"]) == BOUCLIER else 0
        for r in range(e3.RANGS + 1):
            entree = e3.entree_rang(e, r) if r else e
            up.append("CREATE TEMPORARY TABLE sol_objet SELECT * FROM item_template WHERE entry = %d;" % source)
            up.append("UPDATE sol_objet SET entry = %d, name = %s, description = '', Quality = 2, bonding = 1, "
                      "ItemLevel = %d, RequiredLevel = 0, RequiredSkill = 0, RequiredSkillRank = 0, AllowableClass = -1, "
                      "AllowableRace = -1, BuyPrice = 0, SellPrice = %d, RandomProperty = 0, RandomSuffix = 0, "
                      "spellid_1 = 0, spelltrigger_1 = 0, %s;"
                      % (entree, s("%s +%d" % (nom, r) if r else nom), p, p * 25 if vendable else 0,
                         e3.colonnes_sql(e3.au_rang(c, r, bloc))))
            up.append("INSERT INTO item_template SELECT * FROM sol_objet;")
            up.append("DROP TEMPORARY TABLE sol_objet;")
    bases = [e for e, *_ in liste]
    up.append("DELETE FROM solazeroth_v3_rangs WHERE base IN (%s);" % ", ".join(map(str, bases)))
    up.append("INSERT INTO solazeroth_v3_rangs VALUES %s;" % ", ".join(
        "(%d, %d, %d)" % (e3.entree_rang(e, r) if r else e, e, r) for e in bases for r in range(e3.RANGS + 1)))
    lignes = []
    for classe, o, v, *_ in versions_par_piece(sources):
        for r in range(e3.RANGS + 1):
            lignes.append("(%d, %d, %d)" % ((e3.entree_rang(o, r), classe, e3.entree_rang(v, r)) if r else (o, classe, v)))
    up.append("INSERT INTO solazeroth_v3_versions VALUES %s;" % ", ".join(lignes))
    origines = [e for e, *_ in RECOMPENSES]
    toutes_origines = [e3.entree_rang(o, r) if r else o for o in origines for r in range(e3.RANGS + 1)]
    down = ["DELETE FROM solazeroth_v3_versions WHERE origine IN (%s);" % ", ".join(map(str, toutes_origines)),
            "DELETE FROM solazeroth_v3_rangs WHERE base IN (%s);" % ", ".join(map(str, bases)),
            "DELETE FROM item_template WHERE entry IN (%s);" % ", ".join(map(str, toutes))]
    return up, down, [(e, nom, source, p, sources, armures, armes) for e, nom, source, p, _ in liste]


# --- Passes reprises de Durotar -----------------------------------------------------------------------------------

def objets_sans_quete_sql():
    """Passe des migrations 100 et 108, pour les quêtes retirées par ce lot : un objet qui lance une quête retirée ne la
    lance plus. S'il est demandé par une quête active, il reste dans le butin (startquest à 0) ; sinon il quitte le
    butin et les marchands. Tables de retour solazeroth_v3_t2_sans_quete_*."""
    sources = ["creature", "gameobject", "reference", "item", "pickpocketing", "fishing", "skinning"]
    up = ["CREATE TABLE solazeroth_v3_t2_sans_quete_objets (entry INT UNSIGNED NOT NULL PRIMARY KEY, startquest INT "
          "UNSIGNED NOT NULL, demande TINYINT UNSIGNED NOT NULL) SELECT DISTINCT i.entry, i.startquest, 0 AS demande "
          "FROM item_template i JOIN disables d ON d.sourceType = 1 AND d.entry = i.startquest AND d.comment = '%s' "
          "WHERE i.startquest > 0;" % COMMENTAIRE,
          "UPDATE solazeroth_v3_t2_sans_quete_objets o SET o.demande = 1 WHERE EXISTS (SELECT 1 FROM quest_template q "
          "WHERE o.entry IN (q.RequiredItemId1, q.RequiredItemId2, q.RequiredItemId3, q.RequiredItemId4, "
          "q.RequiredItemId5, q.RequiredItemId6, q.ItemDrop1, q.ItemDrop2, q.ItemDrop3, q.ItemDrop4) AND NOT EXISTS "
          "(SELECT 1 FROM disables d WHERE d.sourceType = 1 AND d.entry = q.ID));"]
    down = []
    for src in sources:
        t = "solazeroth_v3_t2_sans_quete_%s" % src
        up.append("CREATE TABLE %s SELECT t.* FROM %s_loot_template t JOIN solazeroth_v3_t2_sans_quete_objets o "
                  "ON o.entry = t.Item AND o.demande = 0 WHERE t.Reference = 0;" % (t, src))
        up.append("DELETE t FROM %s_loot_template t JOIN solazeroth_v3_t2_sans_quete_objets o ON o.entry = t.Item "
                  "AND o.demande = 0 WHERE t.Reference = 0;" % src)
        down += ["INSERT IGNORE INTO %s_loot_template SELECT * FROM %s;" % (src, t), "DROP TABLE %s;" % t]
    up += ["CREATE TABLE solazeroth_v3_t2_sans_quete_marchands SELECT v.* FROM npc_vendor v JOIN "
           "solazeroth_v3_t2_sans_quete_objets o ON o.entry = v.item AND o.demande = 0;",
           "DELETE v FROM npc_vendor v JOIN solazeroth_v3_t2_sans_quete_objets o ON o.entry = v.item AND o.demande = 0;",
           "UPDATE item_template i JOIN solazeroth_v3_t2_sans_quete_objets o ON o.entry = i.entry SET i.startquest = 0;"]
    down += ["INSERT IGNORE INTO npc_vendor SELECT * FROM solazeroth_v3_t2_sans_quete_marchands;",
             "DROP TABLE solazeroth_v3_t2_sans_quete_marchands;",
             "UPDATE item_template i JOIN solazeroth_v3_t2_sans_quete_objets o ON o.entry = i.entry "
             "SET i.startquest = o.startquest;",
             "DROP TABLE solazeroth_v3_t2_sans_quete_objets;"]
    return up, down


def faux_indicateurs_sql():
    """Passe de la migration 120 pour la zone 17 : un PNJ qui garde le drapeau « donneur de quête » sans aucune quête
    active (toutes ses quêtes sont retirées) le perd. Les PNJ des abords des Cavernes (zone 718) et de la carte 43
    attendent le lot T5, avec leurs quêtes."""
    active = ("NOT EXISTS (SELECT 1 FROM disables d WHERE d.sourceType = 1 AND d.entry = q.quest)")
    up = ["CREATE TABLE solazeroth_v3_t2_faux_indicateurs (entry INT UNSIGNED NOT NULL PRIMARY KEY) SELECT DISTINCT "
          "t.entry FROM creature c JOIN creature_template t ON t.entry = c.id WHERE c.map = 1 AND c.zoneId = %d "
          "AND (t.npcflag & 2) "
          "AND NOT EXISTS (SELECT 1 FROM creature_queststarter q WHERE q.id = t.entry AND %s) "
          "AND NOT EXISTS (SELECT 1 FROM creature_questender q WHERE q.id = t.entry AND %s);" % (TARIDES, active, active),
          "UPDATE creature_template t JOIN solazeroth_v3_t2_faux_indicateurs f ON f.entry = t.entry "
          "SET t.npcflag = t.npcflag & ~2;"]
    down = ["UPDATE creature_template t JOIN solazeroth_v3_t2_faux_indicateurs f ON f.entry = t.entry "
            "SET t.npcflag = t.npcflag | 2;",
            "DROP TABLE solazeroth_v3_t2_faux_indicateurs;"]
    return up, down


# --- La migration -------------------------------------------------------------------------------------------------

def controler_textes(textes):
    """Conventions du brouillon : aucune classe nommée, aucune pièce propre à une classe dans un texte de quête."""
    # Au singulier : « ses meilleurs guerriers » parle des monstres, pas du joueur.
    interdit = re.compile(r"\b(épées?|boucliers?|heaumes?|gantelets?|guerrier|guerrière|démoniste|voleur|voleuse)\b")
    for n, t in textes.items():
        for champ, texte in t.items():
            m = interdit.search(texte.lower())
            if m:
                raise SystemExit("%s (%s) : « %s » interdit" % (qd.etiquette(ZONE, n), champ, m.group(1)))
    for _, _, nom, _ in RECOMPENSES:
        m = interdit.search(nom.lower())
        if m:
            raise SystemExit("Récompense « %s » : « %s » interdit" % (nom, m.group(1)))


def controler_dbc():
    """lignes_dbc() se passe de la base : elle doit donner les mêmes pièces, sur les mêmes modèles, que pieces()."""
    attendu = {e: source for e, _, source, _, _ in pieces()}
    lu = {e: source for e, source, _ in lignes_dbc() if e < 920000}
    if lu != attendu:
        raise SystemExit("lignes_dbc() et pieces() divergent : %s" % sorted(set(lu.items()) ^ set(attendu.items())))


def construire():
    textes = qd.lire_textes(ZONE)
    controler_textes(textes)
    controler_dbc()
    origine = qd.quetes_d_origine(ZONE)
    for q in (5042, 5043):
        if q not in origine:
            raise SystemExit("La quête %d devait être retirée" % q)
    pos = qd.positions(ZONE)
    ids = sorted(qd.ident(ZONE, n) for n in Q)
    liste = ", ".join(map(str, ids))

    up = ["-- Lot T2 des Tarides (03/11/2026) : les 30 quêtes d'histoire (T01 à T30) et la quête-pont D31. Généré par",
          "-- outils\\quetes_tarides.py (py quetes_durotar.py tarides) : ne pas modifier à la main.",
          "SET SESSION sql_mode = '';",
          "USE acore_world;",
          "",
          "-- Quêtes d'origine des Tarides (zone 17) : retirées (%d), dont 5042 et 5043 (suites du Joyau de sang)." % len(origine)]
    up += qd.disables_sql(ZONE, origine)
    down = ["-- Annule 139 : retire l'histoire des Tarides et rend ce qui a été changé.",
            "SET SESSION sql_mode = '';",
            "USE acore_world;"]

    o_up, o_down = objets_sans_quete_sql()
    up += ["", "-- Objets qui lancent une quête retirée (passe des migrations 100 et 108)."] + o_up

    p_up, p_down, _ = pieces_sql()
    up += ["", "-- Récompenses au barème (equipement_v3.py), rangs 1 à 5, versions par classe."] + p_up

    up += ["", "-- Les quêtes."] + qd.quetes_sql(ZONE, textes, pos)

    t09, t10, t20 = qd.ident(ZONE, 9), qd.ident(ZONE, 10), qd.ident(ZONE, 20)
    up += ["",
           "-- Objectifs d'origine repris : la zone des Bassins oubliés (870 -> T09), la Fissure bouillonnante (877 -> T10),",
           "-- l'option du Cadavre battu (4921 -> T20).",
           "UPDATE areatrigger_involvedrelation SET quest = %d WHERE id = %d;" % (t09, BASSINS),
           "UPDATE gameobject_template SET Data1 = %d WHERE entry = %d;" % (t10, FISSURE),
           "UPDATE conditions SET ConditionValue1 = %d WHERE SourceTypeOrReferenceId = 15 AND SourceGroup = %d AND "
           "ConditionTypeOrReference = 9 AND ConditionValue1 = %d;" % (t20, CADAVRE_MENU, ORIGINE["cadavre"]),
           "",
           "-- Sarilus (faction de la Lame ardente), Takar (dans le Camp Taurajo, faction d'Orgrimmar), Gukk'rok (5 min).",
           "CREATE TABLE solazeroth_v3_t2_pnj_origine SELECT entry, faction FROM creature_template WHERE entry IN (%d, %d);"
           % (SARILUS, TAKAR),
           "CREATE TABLE solazeroth_v3_t2_apparitions_origine SELECT guid, position_x, position_y, position_z, orientation, "
           "spawntimesecs FROM creature WHERE guid IN (%d, %d);" % (GUID_TAKAR, GUID_GUKKROK),
           "UPDATE creature_template SET faction = %d WHERE entry = %d;" % (LAME_ARDENTE, SARILUS),
           "UPDATE creature_template SET faction = %d WHERE entry = %d;" % (ORGRIMMAR, TAKAR),
           "UPDATE creature SET position_x = %g, position_y = %g, position_z = %g, orientation = %g, areaId = 378, "
           "wander_distance = 0, MovementType = 0 WHERE guid = %d;" % (PLACE_TAKAR + (GUID_TAKAR,)),
           "UPDATE creature SET spawntimesecs = %d WHERE guid = %d;" % (DELAI_GUKKROK, GUID_GUKKROK),
           "",
           "-- Cris des chefs (v3_paroles.cpp lit cette table au démarrage).",
           "CREATE TABLE solazeroth_v3_cris (creature INT UNSIGNED NOT NULL PRIMARY KEY, zone INT UNSIGNED NOT NULL, "
           "texte VARCHAR(255) NOT NULL) DEFAULT CHARSET=utf8mb4;",
           "INSERT INTO solazeroth_v3_cris VALUES %s;" % ", ".join("(%d, %d, %s)" % (c, z, s(t)) for c, z, t in CRIS)]

    f_up, f_down = faux_indicateurs_sql()
    up += ["", "-- Faux indicateurs de quête de la zone 17 (passe de la migration 120)."] + f_up + [""]

    down += f_down + [
        "DROP TABLE solazeroth_v3_cris;",
        "UPDATE creature c JOIN solazeroth_v3_t2_apparitions_origine o ON o.guid = c.guid SET c.position_x = o.position_x, "
        "c.position_y = o.position_y, c.position_z = o.position_z, c.orientation = o.orientation, "
        "c.spawntimesecs = o.spawntimesecs;",
        "UPDATE creature SET areaId = 1156 WHERE guid = %d;" % GUID_TAKAR,
        "DROP TABLE solazeroth_v3_t2_apparitions_origine;",
        "UPDATE creature_template t JOIN solazeroth_v3_t2_pnj_origine o ON o.entry = t.entry SET t.faction = o.faction;",
        "DROP TABLE solazeroth_v3_t2_pnj_origine;",
        "UPDATE conditions SET ConditionValue1 = %d WHERE SourceTypeOrReferenceId = 15 AND SourceGroup = %d AND "
        "ConditionTypeOrReference = 9 AND ConditionValue1 = %d;" % (ORIGINE["cadavre"], CADAVRE_MENU, t20),
        "UPDATE gameobject_template SET Data1 = %d WHERE entry = %d;" % (ORIGINE["fissure"], FISSURE),
        "UPDATE areatrigger_involvedrelation SET quest = %d WHERE id = %d;" % (ORIGINE["bassins"], BASSINS),
        "DELETE FROM quest_template WHERE ID IN (%s);" % liste,
        "DELETE FROM quest_template_addon WHERE ID IN (%s);" % liste,
        "DELETE FROM quest_request_items WHERE ID IN (%s);" % liste,
        "DELETE FROM quest_offer_reward WHERE ID IN (%s);" % liste,
        "DELETE FROM quest_poi WHERE QuestID IN (%s);" % liste,
        "DELETE FROM quest_poi_points WHERE QuestID IN (%s);" % liste,
        "DELETE FROM conditions WHERE SourceTypeOrReferenceId = 19 AND SourceEntry IN (%s);" % liste,
        "DELETE FROM creature_queststarter WHERE quest IN (%s);" % liste,
        "DELETE FROM creature_questender WHERE quest IN (%s);" % liste,
    ] + p_down + o_down + [
        "DELETE FROM disables WHERE sourceType = 1 AND comment = '%s';" % COMMENTAIRE, ""]

    for suffixe, lignes in ((".up.sql", up), (".down.sql", down)):
        with open(MIGRATION + suffixe, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(lignes))
    tissu_v3.ecrire_versions_lua()
    print("%d quêtes, %d récompenses, %d pièces avec les versions, %d quêtes d'origine retirées : migration 139 écrite."
          % (len(Q), len(RECOMPENSES), len(pieces()), len(origine)))


def rapport():
    """Récompenses au barème, pour relecture : pièce, puissance, armure ou dégâts, PA, Endurance."""
    _, _, liste = pieces_sql()
    for e, nom, source, p, sources, armures, armes in liste:
        c = tissu_v3.caracteristiques(sources[source], p, armures, armes)
        print(e, nom, "puissance", p, c)


if __name__ == "__main__":
    if "--rapport" in sys.argv:
        rapport()
    else:
        raise SystemExit("py quetes_durotar.py tarides (ou py quetes_tarides.py --rapport)")
