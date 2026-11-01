"""v3 (01/11/2026, audit « Sorts des monstres — audit.md », accord de l'utilisateur : « Oui, vas-y ») : sorts des
monstres de Durotar et du Gouffre de Ragefeu.

- Les sorts sans effet en v3 (esquive, blocage, chances de toucher, Intelligence, armure ou caractéristique minuscule)
  sont remplacés par un effet lisible, ou retirés.
- Règle pour tous les monstres : leurs renforcements sont en pourcentage, plus en points fixes. Un bonus fixe s'ajoute
  à chaque coup avant le ×4 des monstres et ne suit pas leur réglage de dégâts : la Frénésie de Dent-de-l'Écho donnait
  +50 par coup, soit +200 (198 relevé le 01/11/2026, mort du personnage).
- Chaque remplacement est une copie du sort de Blizzard (nom, icône, visuel, incantation) dont les effets changent ;
  le client lit les mêmes sorts dans patch-frFR-4.MPQ (Spell.dbc écrit par auras_nommees.py).

py sorts_monstres_v3.py  (écrit la migration 106)
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import dbc
from hauts_faits_natifs import DBC_SERVEUR, FRFR, MASQUE
from quetes_durotar import sql

MIGRATION = r"C:\SolAzeroth\sql\migrations\106_v3_sorts_monstres"
TEXTES = [136, 153, 170, 187]       # nom, rang, description, infobulle de l'aura
TOUS = 127                          # toutes les écoles
AURA, A_DEGATS_SUR_DUREE = 6, 3
A_DEGATS_PCT, A_HATE, A_SUBIS_PCT, A_ARMURE_PCT, A_SOINS_PCT = 79, 138, 87, 101, 118
ENNEMI, SOI = 6, 1
# Durées (SpellDuration.dbc) : 3, 4, 6, 8, 10, 20, 30 s et 2 min.
D3, D4, D6, D8, D10, D20, D30, D2MIN = 27, 35, 32, 31, 1, 18, 9, 4
SCALES_WITH_CREATURE_LEVEL = 0x80000

# (id, modèle, nom ou None pour garder celui du modèle, infobulle, durée, cumuls,
#  effets [(n° d'effet du modèle à remplacer, aura, valeur, misc, cible ou None pour garder celle du modèle)])
SORTS = [
    (102000, 7289, None, "Rapetissé : dégâts infligés réduits de 15 %.", D10, 0,
     [(0, A_DEGATS_PCT, -15, TOUS, None)]),
    (102001, 7272, None, "Aveuglé : vitesse d'attaque réduite de 20 %.", D6, 0,
     [(0, A_HATE, -20, 0, None)]),
    (102002, 5426, "Carapace", "Dégâts subis réduits de 50 %.", D6, 0,
     [(0, A_SUBIS_PCT, -50, TOUS, None)]),
    (102003, 3248, "Bouclier levé", "Dégâts subis réduits de 40 %.", D6, 0,
     [(0, A_SUBIS_PCT, -40, TOUS, None)]),
    (102004, 11971, None, "Armure réduite de 10 % par cumul.", D30, 5,
     [(0, A_ARMURE_PCT, -10, 1, None)]),
    (102005, 6950, None, "Armure réduite de 10 % par cumul.", D30, 5,
     [(0, A_ARMURE_PCT, -10, 1, None)]),
    (102006, 6818, "Souillure", "Soins reçus réduits de 25 %.", D10, 0,
     [(0, A_SOINS_PCT, -25, 0, ENNEMI)]),
    (102007, 3604, None, "Saignement : 3 dégâts toutes les 2 s.", D8, 0,
     [(0, A_DEGATS_SUR_DUREE, 3, 0, None)]),
    (102008, 702, None, "Dégâts infligés réduits de 15 %.", D20, 0,
     [(0, A_DEGATS_PCT, -15, TOUS, None), (1, 0, 0, 0, None)]),
    (102009, 18267, None, "Dégâts infligés réduits de 20 %.", D30, 0,
     [(0, A_DEGATS_PCT, -20, TOUS, None)]),
    (102010, 8269, None, "Vitesse d'attaque augmentée de 50 % et dégâts de 25 %.", D2MIN, 0,
     [(0, A_DEGATS_PCT, 25, TOUS, None), (1, A_HATE, 50, 0, None), (2, 0, 0, 0, None)]),
    (102011, 6268, None, "Vitesse de course augmentée, dégâts augmentés de 50 %.", D3, 0,
     [(1, A_DEGATS_PCT, 50, TOUS, None)]),
    (102012, 3385, None, "Vitesse de course augmentée, dégâts augmentés de 50 %.", D4, 0,
     [(1, A_DEGATS_PCT, 50, TOUS, None)]),
]
# Sort de Blizzard -> remplacement, dans les scripts des monstres de Durotar et du Gouffre.
REMPLACE = {7289: 102000, 7272: 102001, 5426: 102002, 3248: 102003, 11971: 102004, 6950: 102005, 6818: 102006,
            6951: 102006, 5413: 102006, 3604: 102007, 702: 102008, 18267: 102009, 8269: 102010, 6268: 102011,
            3385: 102012}
# (monstre, sort) retirés : sans effet en v3 et sans remplacement utile.
RETIRES = [(3192, 7164), (3192, 72), (5826, 2484), (3121, 17498)]
# Invocations retirées partout dans la zone (marcheur du Vide, diablotin) : un renfort double le combat d'un lanceur de
# sorts (0 % de victoires en simulation même ses dégâts réduits), contre la règle des packs de 2 au plus du Gouffre.
INVOCATIONS = [12746, 11939]
CAST = "(11, 85, 86, 134)"


def lignes(d):
    sortie = []
    for ident, modele, nom, texte, duree, cumuls, effets in SORTS:
        e = list(d.chercher(modele))
        e[0] = ident
        e[4] &= ~SCALES_WITH_CREATURE_LEVEL
        e[40] = duree
        e[49] = cumuls
        for n, aura, valeur, misc, cible in effets:
            e[71 + n] = AURA if aura else 0
            e[95 + n] = aura
            e[74 + n] = 0                   # pas de dés : valeur fixe
            e[77 + n] = 0                   # ni de points par niveau
            e[80 + n] = (valeur - 1) & 0xFFFFFFFF
            e[110 + n] = misc
            e[98 + n] = 2000 if aura == A_DEGATS_SUR_DUREE else 0
            if cible:
                e[86 + n] = cible
            if not aura:
                e[86 + n] = e[89 + n] = 0
        for debut, chaine in zip(TEXTES, [nom, None, texte, texte]):
            if chaine is None:
                continue
            e[debut:debut + 16] = [0] * 16
            e[debut] = e[debut + FRFR] = d.ajouter_texte(chaine)
            e[debut + 16] = MASQUE
        sortie.append(e)
    return sortie


def monstres_zone():
    """Monstres de Durotar et du Gouffre (hors PNJ à fonction et monstres d'événement)."""
    return [int(x[0]) for x in sql(
        "SELECT DISTINCT c.id FROM acore_world.creature c JOIN acore_world.creature_template t ON t.entry = c.id "
        "WHERE ((c.map = 1 AND c.zoneId = 14) OR c.map = 389) AND t.npcflag = 0 AND NOT EXISTS (SELECT 1 FROM "
        "acore_world.game_event_creature g WHERE g.guid = c.guid)")]


def main():
    import auras_nommees as an
    d = dbc.Dbc.ouvrir(os.path.join(DBC_SERVEUR, "Spell.dbc"))
    rangs = lignes(d)
    types = an.types_colonnes()
    ids = ", ".join(str(s[0]) for s in SORTS)
    liste = ", ".join(map(str, sorted(monstres_zone())))
    anciens = ", ".join(map(str, sorted(REMPLACE)))
    retires = " OR ".join("(entryorguid = %d AND action_param1 = %d)" % r for r in RETIRES)
    retires += " OR (entryorguid IN (%s) AND action_param1 IN (%s))" % (liste, ", ".join(map(str, INVOCATIONS)))
    up = ["-- v3 (01/11/2026) : sorts des monstres de Durotar et du Gouffre (audit « Sorts des monstres — audit.md »).",
          "-- Généré par outils\\sorts_monstres_v3.py : ne pas modifier à la main. Le client lit les mêmes sorts dans",
          "-- patch-frFR-4.MPQ.",
          "USE acore_world;",
          "DELETE FROM spell_dbc WHERE ID IN (%s);" % ids]
    up += ["INSERT INTO spell_dbc VALUES (%s);" % ", ".join(an.valeur_sql(d, t, v) for t, v in zip(types, e)) for e in rangs]
    up += ["CREATE TABLE solazeroth_v3_sorts_origine SELECT entryorguid, source_type, id, link, action_param1 FROM "
           "smart_scripts WHERE source_type = 0 AND entryorguid IN (%s) AND action_type IN %s AND action_param1 IN (%s);"
           % (liste, CAST, anciens)]
    for ancien, nouveau in sorted(REMPLACE.items()):
        up.append("UPDATE smart_scripts SET action_param1 = %d WHERE source_type = 0 AND entryorguid IN (%s) AND "
                  "action_type IN %s AND action_param1 = %d;" % (nouveau, liste, CAST, ancien))
    up += ["CREATE TABLE solazeroth_v3_sorts_retires SELECT * FROM smart_scripts WHERE source_type = 0 AND action_type "
           "IN %s AND (%s);" % (CAST, retires),
           "DELETE FROM smart_scripts WHERE source_type = 0 AND action_type IN %s AND (%s);" % (CAST, retires), ""]
    down = ["-- Rend aux monstres leurs sorts de Blizzard.",
            "USE acore_world;",
            "UPDATE smart_scripts s JOIN solazeroth_v3_sorts_origine o ON o.entryorguid = s.entryorguid AND o.source_type "
            "= s.source_type AND o.id = s.id AND o.link = s.link SET s.action_param1 = o.action_param1;",
            "INSERT INTO smart_scripts SELECT * FROM solazeroth_v3_sorts_retires;",
            "DROP TABLE solazeroth_v3_sorts_origine;",
            "DROP TABLE solazeroth_v3_sorts_retires;",
            "DELETE FROM spell_dbc WHERE ID IN (%s);" % ids, ""]
    for suffixe, contenu in ((".up.sql", up), (".down.sql", down)):
        with open(MIGRATION + suffixe, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(contenu))
    print("Migration 106 écrite : %d sorts, %d remplacements, %d retraits et %d invocations retirées." % (
        len(SORTS), len(REMPLACE), len(RETIRES), len(INVOCATIONS)))


if __name__ == "__main__":
    main()
