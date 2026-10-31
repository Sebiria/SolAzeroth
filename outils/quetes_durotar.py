"""v3, F5c (31/10/2026) : construit les 30 quêtes d'histoire de Durotar validées par l'utilisateur.

Source des textes : « Durotar — Histoire et quêtes (brouillon).md » (titres, introductions, progressions et fins).
La mécanique (donneurs, objectifs, récompenses, zones d'objectif) est décrite ici, d'après le même document.

Écrit :
- la migration 063 (quêtes 910001-910030, récompenses 910101-910119, Ruga Brise-cendre 910001, la Sacoche du
  Totem-sinistre 910001, quêtes d'origine de Durotar et du Gouffre retirées par la table disables) ;
- l'Item.dbc du patch client, avec les récompenses (sans lui, le client ne sait pas afficher un objet nouveau).
Lit la base (lecture seule) pour la liste des quêtes d'origine et la position des PNJ.
"""
import math
import os
import re
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import dbc

MYSQL = r"C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe"
CNF = r"C:\SolAzeroth\config\mysql-acore.cnf"
HISTOIRE = os.path.join(os.path.expanduser("~"), "Documents", "Claude", "Sol'Azeroth",
                        "Durotar — Histoire et quêtes (brouillon).md")
MIGRATION = r"C:\SolAzeroth\sql\migrations\063_v3_quetes_durotar"
ITEM_DBC_ORIGINE = r"C:\SolAzeroth\data\dbc\Item.dbc"
ITEM_DBC_PATCH = r"C:\SolAzeroth\patch-client\fichiers\DBFilesClient\Item.dbc"
ECLAT, FRAGMENT_AME = 910120, 6265   # Éclat cadavérique (F6), copié du Fragment d'âme
PUISSANCES = r"C:\SolAzeroth\interface-v3\FrameXML\SolUI_Puissances.lua"

QUETE = 910000          # D01 = 910001
MARQUE = 37711          # monnaie des Marques (marques.cpp)
RUGA = 910001
SACOCHE = 910001        # objet du monde et son butin
GUID_RUGA = 9100001
GUID_SACOCHE = 9100001
DUROTAR, GOUFFRE = 14, 2437
CARTE_DUROTAR = 4       # WorldMapArea de Durotar
FAILLE = (1460, -4700)  # le Gouffre n'a pas de carte du monde : ses objectifs s'affichent à la faille

# Récompenses d'équipement : (entrée, quête, nom, objet dont on reprend l'apparence et le type, niveau d'objet = puissance)
EQUIPEMENT = [
    (910101, 2, "Bottes de la Vallée", 4972, 2),
    (910102, 4, "Gants du contremaître", 5312, 2),
    (910103, 5, "Ceinture de Zureetha", 4935, 3),
    (910104, 6, "Brassards de Hana'zua", 4969, 3),
    (910105, 7, "Plastron de la recrue", 4922, 3),
    (910106, 9, "Jambières des forges de Tranchecolline", 4917, 5),
    (910107, 11, "Cape de caravanier", 4963, 6),
    (910108, 12, "Épée d'officier de Kul Tiras", 4932, 6),
    (910109, 13, "Plastron d'éclaireur", 6502, 6),
    (910110, 16, "Gants de Lar", 5312, 8),
    (910111, 18, "Bottes de grève", 5320, 8),
    (910112, 19, "Ceinture du père de Gadrin", 5328, 9),
    (910113, 20, "Lame de Sen'jin", 5321, 10),
    (910114, 23, "Brassards ignifugés", 4969, 10),
    (910115, 24, "Jambières de l'orage", 2694, 10),
    (910116, 25, "Rempart de Margoz", 5302, 10),
    (910117, 27, "Ceinture en cuir de trogg", 5328, 12),
    (910118, 29, "Jambières de la Lame brûlante", 2694, 12),
    (910119, 30, "Lame de l'Affameur", 4932, 12),
]

# Mécanique des quêtes. tuer : (créature, nombre, zone) ; go : (objet du monde, nombre, zone, texte) ;
# objets : (objet, nombre, zone). prev : quêtes à avoir rendues (toutes). marques : nombre de Marques.
Q = {
    1: dict(de=10176, a=3143, p=1, prev=[], marques=1, resume="Parle à Gornek, dans L'Antre."),
    2: dict(de=3143, a=3143, p=1, prev=[1], tuer=[(3098, 10, (-493, -4299))],
            resume="Tue 10 Sangliers tachetés dans la Vallée des épreuves."),
    3: dict(de=9796, a=9796, p=2, prev=[1], marques=1, objets=[(11583, 6, (-425, -4265)), (4862, 6, (-432, -4217))],
            resume="Rapporte 6 Pommes de cactus et 6 Queues de scorpide ouvrier à Galgar."),
    4: dict(de=11378, a=11378, p=2, prev=[1], depart=16114, tuer=[(10556, 5, (-465, -4286))],
            objets=[(16332, 1, (-88, -4275))],
            resume="Réveille 5 Péons fainéants avec la Matraque du contremaître et rapporte la Pioche de Thazz'ril, "
                   "au Convent de la Lame ardente."),
    5: dict(de=3145, a=3145, p=3, prev=[2, 4], tuer=[(3101, 8, (-95, -4285)), (3102, 6, (-95, -4285))],
            resume="Tue 8 Vils quasits et 6 Traqueurs gangrenés au Convent de la Lame ardente."),
    6: dict(de=3287, a=3287, p=3, prev=[2], objets=[(4905, 1, (-547, -4104))],
            resume="Tue Sarkoth, au nord-ouest de la Vallée, et rapporte sa pince à Hana'zua."),
    7: dict(de=3145, a=3145, p=3, prev=[5], objets=[(4859, 1, (-58, -4221))],
            resume="Tue Yarrog Plaie-d'ombre, au fond du Convent, et rapporte le Médaillon de la Lame ardente."),
    8: dict(de=3143, a=3142, p=3, prev=[6, 7], marques=1, depart=4859,
            resume="Apporte le Médaillon de la Lame ardente à Orgnil Marque-l'âme, à Tranchecolline."),
    9: dict(de=3139, a=3139, p=5, prev=[8], tuer=[(3128, 10, (-170, -5040)), (3129, 8, (-170, -5040))],
            resume="Tue 10 Marins et 8 Soldats de marine de Kul Tiras au Donjon de Tiragarde."),
    10: dict(de=3147, a=3147, p=5, prev=[8], marques=2, objets=[(4863, 3, (-35, -5284))],
             resume="Rapporte 3 Outils gnomes, sur la Côte des naufrages, à Furl Morguefront."),
    11: dict(de=3293, a=3293, p=6, prev=[8], objets=[(4918, 5, (790, -4570))],
             resume="Rapporte 5 Sacs de ravitaillement du Canyon de Tranchevent à Rezlak."),
    12: dict(de=3139, a=3139, p=6, prev=[9], objets=[(4883, 1, (-246, -5120))],
             resume="Tue le Lieutenant Benedict, au Donjon de Tiragarde, et rapporte les Ordres de l'amiral Portvaillant."),
    13: dict(de=3336, a=3336, p=6, prev=[8], tuer=[(3111, 8, (75, -4480)), (3112, 8, (75, -4480))],
             resume="Tue 8 Hurans et 8 Éclaireurs Tranchecrins dans les Terres des Tranchecrins."),
    14: dict(de=3142, a=3188, p=6, prev=[12], marques=2, resume="Va voir Maître Gadrin, au Village de Sen'jin."),
    15: dict(de=3304, a=3304, p=8, prev=[14], marques=3, objets=[(4887, 4, (-885, -5020)), (4888, 8, (-1034, -4882))],
             resume="Rapporte 4 Yeux de makrura intacts et 8 Mucus de clampant de la Grève des Sombrelances."),
    16: dict(de=3140, a=3140, p=8, prev=[14],
             go=[(3189, 1, (-1057, -4596), "Plan d'attaque : Vallée des épreuves lu"),
                 (3190, 1, (-918, -4482), "Plan d'attaque : Village de Sen'jin lu"),
                 (3192, 1, (-974, -4407), "Plan d'attaque : Orgrimmar lu")],
             resume="Lis les trois Plans d'attaque des Kolkar, à la Combe des Kolkar."),
    17: dict(de=3140, a=3140, p=9, prev=[16], marques=3, tuer=[(5808, 1, (-919, -4494))],
             resume="Tue le Seigneur de guerre Kolkanis, à la Combe des Kolkar."),
    18: dict(de=3194, a=3194, p=8, prev=[14], objets=[(4892, 4, (-1163, -5368))],
             resume="Rapporte 4 Fourrures de tigre de Durotar, prises sur les îles de l'Écho, à Vel'rin Croc."),
    19: dict(de=3188, a=3188, p=9, prev=[15], objets=[(4864, 1, (-1287, -5528))],
             resume="Reprends le Crâne de Minshina, auprès des Sombrelances emprisonnés de l'île de l'Écho."),
    20: dict(de=3188, a=3188, p=10, prev=[18, 19],
             tuer=[(3206, 8, (-1190, -5530)), (3207, 8, (-1190, -5530))], objets=[(4866, 1, (-1287, -5534))],
             resume="Tue 8 Trolls vaudou et 8 Trolls maléficiés, puis abats Zalazane et rapporte sa tête."),
    21: dict(de=3193, a=3193, p=10, prev=[20], marques=4, objets=[(4891, 1, (281, -3848))],
             resume="Retrouve l'Amulette de Kron sur les Crocilisques Gueule-d'effroi de La Furie-du-Sud."),
    22: dict(de=3190, a=3190, p=9, prev=[20], marques=4, objets=[(4886, 5, (678, -4133))],
             resume="Rapporte 5 Glandes à venin de queue-venin à Rhinag."),
    23: dict(de=3142, a=3208, p=10, prev=[20], objets=[(4871, 6, (870, -4745))],
             resume="Prends 6 Colliers brûlants aux fidèles de la Lame ardente, dans la Caverne des Terrevent, "
                    "et porte-les à Margoz."),
    24: dict(de=3208, a=3208, p=10, prev=[23], objets=[(4869, 1, (869, -4190))],
             resume="Tue Féplouf Sombrorage, sur les Falaises du Tonnerre, et rapporte sa griffe."),
    25: dict(de=3208, a=3208, p=10, prev=[23], objets=[(4903, 1, (1469, -4705))],
             resume="Tue Gazz'uz, au Rocher du crâne, et rapporte l'Œil de l'ombre ardente."),
    26: dict(de=3208, a=RUGA, p=10, prev=[24, 25], marques=4,
             resume="Parle à Ruga Brise-cendre, devant la faille du Rocher du crâne."),
    27: dict(de=RUGA, a=RUGA, p=12, prev=[26], gouffre=True,
             tuer=[(11318, 8, FAILLE), (11319, 6, FAILLE), (11517, 1, FAILLE)],
             resume="Dans le Gouffre de Ragefeu, tue 8 Troggs et 6 Chamans Ragefeu, puis leur chef, Lorgnesilex."),
    28: dict(de=RUGA, a=RUGA, p=12, prev=[26], gouffre=True, marques=5, objets=[(14381, 1, FAILLE)],
             resume="Retrouve Maur Totem-sinistre dans le Gouffre de Ragefeu et rapporte sa sacoche."),
    29: dict(de=RUGA, a=RUGA, p=12, prev=[26], gouffre=True,
             tuer=[(11518, 1, FAILLE), (11519, 1, FAILLE)], objets=[(14395, 1, FAILLE), (14396, 1, FAILLE)],
             resume="Prends Les Sorts de l'Ombre et Les Incantations du Néant aux démonistes du Gouffre, "
                    "et tue Jergosh l'Invocateur et Bazzalan."),
    30: dict(de=RUGA, a=3142, p=12, prev=[27, 28, 29], gouffre=True, marques=5, objets=[(14540, 1, FAILLE)],
             resume="Tue Taragaman l'Affameur, au fond du Gouffre, et porte son cœur à Orgnil Marque-l'âme."),
}

# Classes de quête « de classe » (QuestSortID négatifs) : retirées avec les autres. Les catégories de fêtes et
# d'événements restent (les fêtes du jeu passent aussi par Durotar).
CLASSES = {-61, -81, -82, -141, -161, -162, -261, -262, -263, -372}


def sql(requete):
    r = subprocess.run([MYSQL, "--defaults-extra-file=" + CNF, "--default-character-set=utf8mb4", "-N", "-B", "-e", requete],
                       capture_output=True, check=True)
    return [l.split("\t") for l in r.stdout.decode("utf-8").splitlines()]


def s(texte):
    return "'" + texte.replace("\\", "\\\\").replace("'", "''") + "'"


def lire_textes():
    """Titre, introduction, progression et fin de chaque quête, tirés du document validé."""
    textes, courant = {}, None
    for ligne in open(HISTOIRE, encoding="utf-8"):
        m = re.match(r"#### D(\d\d) — (.+)", ligne)
        if m:
            courant = textes.setdefault(int(m.group(1)), {"titre": m.group(2).strip()})
            continue
        m = re.match(r"- \*\*(Introduction|Progression|Fin)\*\*(?: \([^)]*\))? : « (.*) »\s*$", ligne)
        if m and courant is not None:
            courant[m.group(1)] = m.group(2)
    for n in Q:
        manque = {"titre", "Introduction", "Progression", "Fin"} - set(textes.get(n, {}))
        if manque:
            raise SystemExit("D%02d : textes manquants %s" % (n, manque))
    return textes


def quetes_d_origine():
    ids = {QUETE + n for n in Q}
    ou = "(map = 1 AND zoneId = 14) OR map = 389"
    candidats = set()
    for requete in (
            "SELECT DISTINCT quest FROM acore_world.creature_queststarter WHERE id IN "
            "(SELECT DISTINCT id FROM acore_world.creature WHERE %s)" % ou,
            "SELECT DISTINCT quest FROM acore_world.gameobject_queststarter WHERE id IN "
            "(SELECT DISTINCT id FROM acore_world.gameobject WHERE %s)" % ou,
            "SELECT DISTINCT i.startquest FROM acore_world.item_template i JOIN acore_world.creature_loot_template l "
            "ON l.Item = i.entry JOIN (SELECT DISTINCT id FROM acore_world.creature WHERE %s) c ON c.id = l.Entry "
            "WHERE i.startquest <> 0" % ou,
            "SELECT ID FROM acore_world.quest_template WHERE QuestSortID IN (14, 363, 2437)"):
        candidats |= {int(l[0]) for l in sql(requete)}
    deja = {int(l[0]) for l in sql("SELECT entry FROM acore_world.disables WHERE sourceType = 1 AND comment <> "
                                   "'Sol''Azeroth v3 : quete d''origine de Durotar'")}
    tri = {int(i): int(t) for i, t in sql("SELECT ID, QuestSortID FROM acore_world.quest_template WHERE ID IN (%s)"
                                          % ",".join(map(str, sorted(candidats))))}
    return sorted(i for i, t in tri.items()
                  if i not in ids and i not in deja and (t >= 0 or t in CLASSES))


def positions():
    entrees = {q[k] for q in Q.values() for k in ("de", "a")} - {RUGA}
    lignes = sql("SELECT id, ROUND(AVG(position_x)), ROUND(AVG(position_y)) FROM acore_world.creature "
                 "WHERE id IN (%s) GROUP BY id" % ",".join(map(str, sorted(entrees))))
    pos = {int(i): (int(float(x)), int(float(y))) for i, x, y in lignes}
    pos[RUGA] = FAILLE
    manque = entrees - set(pos)
    if manque:
        raise SystemExit("PNJ sans apparition : %s" % sorted(manque))
    return pos


def octogone(centre, rayon=45):
    return [(round(centre[0] + rayon * math.cos(i * math.pi / 4)), round(centre[1] + rayon * math.sin(i * math.pi / 4)))
            for i in range(8)]


def construire():
    textes = lire_textes()
    origine = quetes_d_origine()
    pos = positions()
    recompense = {q: e for e, q, *_ in EQUIPEMENT}
    up, down = [], []
    w = up.append

    w("-- v3, F5c (31/10/2026) : les 30 quêtes d'histoire de Durotar, validées par l'utilisateur (document")
    w("-- « Durotar — Histoire et quêtes »). Généré par outils\\quetes_durotar.py : ne pas modifier à la main.")
    w("USE acore_world;")
    w("")
    w("-- Quêtes d'origine de Durotar, de la Vallée des épreuves et du Gouffre de Ragefeu : retirées (%d)." % len(origine))
    w("INSERT INTO disables (sourceType, entry, flags, params_0, params_1, comment) VALUES")
    w(",\n".join("(1, %d, 0, '', '', 'Sol''Azeroth v3 : quete d''origine de Durotar')" % i for i in origine) + ";")
    w("")

    w("-- Récompenses d'équipement : apparence et type repris d'un objet existant, niveau d'objet = puissance.")
    for e, n, nom, source, ilvl in EQUIPEMENT:
        w("CREATE TEMPORARY TABLE sol_objet SELECT * FROM item_template WHERE entry = %d;" % source)
        w("UPDATE sol_objet SET entry = %d, name = %s, description = '', Quality = 2, bonding = 1, ItemLevel = %d, "
          "RequiredLevel = 0, AllowableClass = -1, AllowableRace = -1, BuyPrice = 0, SellPrice = %d, "
          "RandomProperty = 0, RandomSuffix = 0;" % (e, s(nom), ilvl, ilvl * 25))
        w("INSERT INTO item_template SELECT * FROM sol_objet;")
        w("DROP TEMPORARY TABLE sol_objet;")
    w("")

    w("-- Ruga Brise-cendre, gardienne de la faille du Rocher du crâne (apparence de Zureetha Mireloin).")
    w("CREATE TEMPORARY TABLE sol_pnj SELECT * FROM creature_template WHERE entry = 3145;")
    w("UPDATE sol_pnj SET entry = %d, name = 'Ruga Brise-cendre', subname = 'Gardienne de la faille', npcflag = 2, "
      "gossip_menu_id = 0, AIName = '', ScriptName = '';" % RUGA)
    w("INSERT INTO creature_template SELECT * FROM sol_pnj;")
    w("DROP TEMPORARY TABLE sol_pnj;")
    w("INSERT INTO creature_template_model (CreatureID, Idx, CreatureDisplayID, DisplayScale, Probability, VerifiedBuild) "
      "SELECT %d, Idx, CreatureDisplayID, DisplayScale, Probability, VerifiedBuild FROM creature_template_model "
      "WHERE CreatureID = 3145;" % RUGA)
    w("INSERT INTO creature (guid, id, map, zoneId, areaId, spawnMask, phaseMask, equipment_id, position_x, position_y, "
      "position_z, orientation, spawntimesecs, wander_distance, MovementType) VALUES "
      "(%d, %d, 1, 14, 817, 1, 1, 0, 1459.5, -4694.5, 6.6, 0.33, 300, 0, 0);" % (GUID_RUGA, RUGA))
    w("")

    w("-- Sacoche du Totem-sinistre (D28), posée contre le corps de Maur dans le Gouffre (il n'a pas de butin).")
    w("CREATE TEMPORARY TABLE sol_go SELECT * FROM gameobject_template WHERE entry = 58595;")
    w("UPDATE sol_go SET entry = %d, name = 'Sacoche du Totem-sinistre', Data1 = %d, ScriptName = '', AIName = '';"
      % (SACOCHE, SACOCHE))
    w("INSERT INTO gameobject_template SELECT * FROM sol_go;")
    w("DROP TEMPORARY TABLE sol_go;")
    w("INSERT INTO gameobject_loot_template (Entry, Item, Reference, Chance, QuestRequired, LootMode, GroupId, MinCount, "
      "MaxCount, Comment) VALUES (%d, 14381, 0, 100, 1, 1, 0, 1, 1, 'Sol''Azeroth v3 : D28');" % SACOCHE)
    w("INSERT INTO gameobject (guid, id, map, zoneId, areaId, spawnMask, phaseMask, position_x, position_y, position_z, "
      "orientation, rotation0, rotation1, rotation2, rotation3, spawntimesecs, animprogress, state) VALUES "
      "(%d, %d, 389, 2437, 2437, 1, 1, -146.6, 24.6, -38.6, 0, 0, 0, 0, 1, 60, 100, 1);" % (GUID_SACOCHE, SACOCHE))
    w("")

    w("-- D12 : les Ordres de l'amiral Portvaillant tombent sur le Lieutenant Benedict.")
    w("INSERT INTO creature_loot_template (Entry, Item, Reference, Chance, QuestRequired, LootMode, GroupId, MinCount, "
      "MaxCount, Comment) VALUES (3192, 4883, 0, 100, 1, 1, 0, 1, 1, 'Sol''Azeroth v3 : D12');")
    w("")

    w("-- Les quêtes.")
    for n, q in Q.items():
        t = textes[n]
        ident = QUETE + n
        tuer, go, objets = q.get("tuer", []), q.get("go", []), q.get("objets", [])
        req = [(e, c) for e, c, _ in tuer] + [(-e, c) for e, c, _, _ in go]
        champs = {
            "ID": ident, "QuestType": 2, "QuestLevel": -1, "MinLevel": 0,
            "QuestSortID": GOUFFRE if q.get("gouffre") else DUROTAR,
            "RewardMoney": q["p"] * 30, "StartItem": q.get("depart", 0),
            "POIContinent": 1, "POIx": pos[q["a"]][0], "POIy": pos[q["a"]][1],
            "LogTitle": s(t["titre"]), "LogDescription": s(q["resume"]), "QuestDescription": s(t["Introduction"]),
            "QuestCompletionLog": s("Retourne voir %s." % ("Ruga Brise-cendre" if q["a"] == RUGA else nom_pnj(q["a"]))),
        }
        recompenses = []
        if n in recompense:
            recompenses.append((recompense[n], 1))
        if q.get("marques"):
            recompenses.append((MARQUE, q["marques"]))
        for i, (e, c) in enumerate(recompenses, 1):
            champs["RewardItem%d" % i], champs["RewardAmount%d" % i] = e, c
        for i, (e, c) in enumerate(req, 1):
            champs["RequiredNpcOrGo%d" % i], champs["RequiredNpcOrGoCount%d" % i] = e, c
        for i, (_, _, _, texte) in enumerate(go, len(tuer) + 1):
            champs["ObjectiveText%d" % i] = s(texte)
        for i, (e, c, _) in enumerate(objets, 1):
            champs["RequiredItemId%d" % i], champs["RequiredItemCount%d" % i] = e, c
        w("INSERT INTO quest_template (%s) VALUES (%s);" % (", ".join(champs), ", ".join(str(v) for v in champs.values())))

        prev = q["prev"]
        w("INSERT INTO quest_template_addon (ID, PrevQuestID, ProvidedItemCount) VALUES (%d, %d, %d);"
          % (ident, QUETE + prev[0] if len(prev) == 1 else 0, 1 if q.get("depart") else 0))
        if len(prev) > 1:   # plusieurs quêtes à avoir rendues : conditions (toutes dans le même groupe = toutes requises)
            for p in prev:
                w("INSERT INTO conditions (SourceTypeOrReferenceId, SourceGroup, SourceEntry, SourceId, ElseGroup, "
                  "ConditionTypeOrReference, ConditionTarget, ConditionValue1, ConditionValue2, ConditionValue3, "
                  "NegativeCondition, ErrorType, ErrorTextId, ScriptName, Comment) VALUES "
                  "(19, 0, %d, 0, 0, 8, 0, %d, 0, 0, 0, 0, 0, '', 'Sol''Azeroth v3 : D%02d demande D%02d');"
                  % (ident, QUETE + p, n, p))
        w("INSERT INTO quest_request_items (ID, EmoteOnComplete, EmoteOnIncomplete, CompletionText) VALUES (%d, 1, 1, %s);"
          % (ident, s(t["Progression"])))
        w("INSERT INTO quest_offer_reward (ID, Emote1, RewardText) VALUES (%d, 1, %s);" % (ident, s(t["Fin"])))
        w("INSERT INTO creature_queststarter (id, quest) VALUES (%d, %d);" % (q["de"], ident))
        w("INSERT INTO creature_questender (id, quest) VALUES (%d, %d);" % (q["a"], ident))

        # Zones d'objectif sur la carte : index 0-3 pour les créatures et objets du monde, 4-9 pour les objets à
        # ramasser (règle du client 3.3.5), -1 pour le PNJ qui reçoit la quête.
        zones = [(i, z) for i, (_, _, z) in enumerate(tuer)] + [(len(tuer) + i, z) for i, (_, _, z, _) in enumerate(go)] \
            + [(4 + i, z) for i, (_, _, z) in enumerate(objets)] + [(-1, pos[q["a"]])]
        for numero, (index, centre) in enumerate(zones):
            w("INSERT INTO quest_poi (QuestID, id, ObjectiveIndex, MapID, WorldMapAreaId, Floor, Priority, Flags) "
              "VALUES (%d, %d, %d, 1, %d, 0, 0, 1);" % (ident, numero, index, CARTE_DUROTAR))
            points = octogone(centre) if index >= 0 else [centre]
            w("INSERT INTO quest_poi_points (QuestID, Idx1, Idx2, X, Y) VALUES %s;"
              % ", ".join("(%d, %d, %d, %d, %d)" % (ident, numero, k, x, y) for k, (x, y) in enumerate(points)))
    up.append("")

    premiere, derniere = QUETE + min(Q), QUETE + max(Q)
    objets = ", ".join(str(e) for e, *_ in EQUIPEMENT)
    down += [
        "-- Annule 063 : retire les quêtes de Durotar v3 et rend les quêtes d'origine.",
        "USE acore_world;",
        "DELETE FROM disables WHERE sourceType = 1 AND comment = 'Sol''Azeroth v3 : quete d''origine de Durotar';",
        "DELETE FROM quest_template WHERE ID BETWEEN %d AND %d;" % (premiere, derniere),
        "DELETE FROM quest_template_addon WHERE ID BETWEEN %d AND %d;" % (premiere, derniere),
        "DELETE FROM quest_request_items WHERE ID BETWEEN %d AND %d;" % (premiere, derniere),
        "DELETE FROM quest_offer_reward WHERE ID BETWEEN %d AND %d;" % (premiere, derniere),
        "DELETE FROM quest_poi WHERE QuestID BETWEEN %d AND %d;" % (premiere, derniere),
        "DELETE FROM quest_poi_points WHERE QuestID BETWEEN %d AND %d;" % (premiere, derniere),
        "DELETE FROM conditions WHERE SourceTypeOrReferenceId = 19 AND SourceEntry BETWEEN %d AND %d;" % (premiere, derniere),
        "DELETE FROM creature_queststarter WHERE quest BETWEEN %d AND %d;" % (premiere, derniere),
        "DELETE FROM creature_questender WHERE quest BETWEEN %d AND %d;" % (premiere, derniere),
        "DELETE FROM item_template WHERE entry IN (%s);" % objets,
        "DELETE FROM creature WHERE guid = %d;" % GUID_RUGA,
        "DELETE FROM creature_template_model WHERE CreatureID = %d;" % RUGA,
        "DELETE FROM creature_template WHERE entry = %d;" % RUGA,
        "DELETE FROM gameobject WHERE guid = %d;" % GUID_SACOCHE,
        "DELETE FROM gameobject_loot_template WHERE Entry = %d;" % SACOCHE,
        "DELETE FROM gameobject_template WHERE entry = %d;" % SACOCHE,
        "DELETE FROM creature_loot_template WHERE Entry = 3192 AND Item = 4883;",
        "",
    ]

    for suffixe, lignes in ((".up.sql", up), (".down.sql", down)):
        with open(MIGRATION + suffixe, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(lignes))

    item_dbc()
    print("%d quêtes, %d récompenses, %d quêtes d'origine retirées" % (len(Q), len(EQUIPEMENT), len(origine)))


def item_dbc():
    """Item.dbc du client : une ligne par récompense, copiée de l'objet source (type, apparence, emplacement), et
    l'Éclat cadavérique (F6, migration 077), copié du Fragment d'âme en composant (classe 7, sous-classe 11), puis les
    pièces fabriquées et les rangs d'equipement_v3.py (E1, migration 078)."""
    import equipement_v3
    table = dbc.Dbc.ouvrir(ITEM_DBC_ORIGINE)
    existants = {e[0] for e in table.enregistrements}
    for e, _, _, source, _ in EQUIPEMENT + [(ECLAT, 0, "", FRAGMENT_AME, 0)] + \
            [(e, 0, "", source, 0) for e, source in equipement_v3.lignes_dbc()]:
        if e not in existants:
            ligne = list(table.chercher(source))
            ligne[0] = e
            if e == ECLAT:
                ligne[1], ligne[2] = 7, 11
            table.enregistrements.append(ligne)
    table.enregistrer(ITEM_DBC_PATCH)


_noms = {}


def nom_pnj(entree):
    if not _noms:
        for e, n in sql("SELECT t.entry, COALESCE(NULLIF(l.Name, ''), t.name) FROM acore_world.creature_template t "
                        "LEFT JOIN acore_world.creature_template_locale l ON l.entry = t.entry AND l.locale = 'frFR' "
                        "WHERE t.entry IN (%s)" % ",".join(str(q["a"]) for q in Q.values() if q["a"] != RUGA)):
            _noms[int(e)] = n
    return _noms[entree]


def puissances():
    """Puissance de chaque quête pour l'interface (SolUI_Quetes.lua). Les quêtes restent au niveau du joueur
    (QuestLevel -1) : à leur niveau d'origine, le client les jugerait trop faciles et cacherait leur « ! »."""
    lignes = ["-- Généré par outils\\quetes_durotar.py : ne pas modifier à la main.",
              "-- Quête -> puissance conseillée (document de Durotar).",
              "SolUI.PUISSANCES_QUETES = {"]
    lignes += ["    [%d] = %d," % (QUETE + n, q["p"]) for n, q in sorted(Q.items())]
    lignes.append("}")
    with open(PUISSANCES, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lignes) + "\n")


if __name__ == "__main__":
    construire()
    puissances()
