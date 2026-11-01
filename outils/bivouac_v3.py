"""Sol'Azeroth v3 (31/10/2026) : potion et feu de camp, les deux boutons à droite des techniques (document v3, F7).

Rang de départ seulement ; les améliorations par liste de courses viendront avec F7. Trois sorts, copiés de Blizzard
et retouchés comme les techniques (techniques_v3.technique) :
- Potion de soins : copie de la Potion de soins (441), soin propre au module (spell_solazeroth_v3_potion : part de la
  vie maximale, charges) ;
- Feu de camp : copie du Feu de camp simple (818), qui pose le même feu (objet 29784, foyer de cuisine), sans bois ni
  briquet. Le personnage s'assoit à côté ; se lever l'éteint (spell_solazeroth_v3_feu, v3_bivouac.cpp) ;
- Repos au coin du feu : le bonus reçu après 60 s assis près du feu, qui rend aussi les potions ;
- Repos au coin du feu, premier nœud de l'arbre du camp (31/10/2026, choix de l'utilisateur : 15 Marques) : le même,
  avec +DEGATS_REPOS % de dégâts infligés. v3_bivouac.cpp le lance à la place du premier quand le nœud est acheté.

F7 (01/11/2026, chiffres de l'utilisateur) : deux rangs de potion et deux nœuds de plus pour l'arbre du camp, chacun
avec sa liste de courses (COUTS), achetables partout et sans condition de contenu :
- potion rang 1 : 2 charges, soin 35 % ; rang 2 : en plus, 1 % de la vie par seconde pendant 10 s (Potion
  revigorante, 100034) ;
- camp nœud 2 : Repos au coin du feu de 30 minutes, vie maximale +5 %, 2 % de la vie par seconde hors combat, +5 à la
  caractéristique de la spécialisation (sort 100033, avec les +10 % de dégâts du nœud 1) ; nœud 3 : le même pendant
  40 minutes (v3_bivouac.cpp fixe la durée : pas de durée de 40 minutes dans SpellDuration.dbc).

Appelé par auras_nommees.py, qui écrit le Spell.dbc du client et la migration 067. Lancé seul (py bivouac_v3.py), il
écrit la migration 089 (listes de courses) et SolUI_Camp.lua (les mêmes, pour l'interface).
"""
import os

from techniques_v3 import AURA, DEGATS_INFLIGES, HORS_COMBAT, SOI, SOIN, VIE_POURCENT, effet, technique

MIGRATION = r"C:\SolAzeroth\sql\migrations\067_v3_bivouac"
MIGRATION_COUTS = r"C:\SolAzeroth\sql\migrations\089_v3_camp_rangs"
CAMP_LUA = r"C:\SolAzeroth\interface-v3\FrameXML\SolUI_Camp.lua"

POTION, FEU, REPOS, REPOS_FLAMME, REPOS_BRAISES, REVIGORANTE = 100029, 100030, 100031, 100032, 100033, 100034
D2MIN, D30MIN, D10 = 4, 30, 1       # SpellDuration.dbc : 120 s, 1800 s, 10 s
MOD_STAT, SOIN_POURCENT_PERIODIQUE = 29, 20   # SPELL_AURA_MOD_STAT, SPELL_AURA_OBS_MOD_HEALTH (% de la vie maximale)
# Repos des nœuds 2 et 3 : un sort par caractéristique principale (misc de l'aura : 0 Force, 1 Agilité, 3 Intelligence) ;
# v3_bivouac.cpp choisit celui de la spécialisation.
REPOS_BRAISES_STATS = [(REPOS_BRAISES, 0, "Force"), (100035, 1, "Agilité"), (100036, 3, "Intelligence")]
BONUS_CARACTERISTIQUE = 5

# Listes de courses (objets de la Collection ; 0 = or, en cuivre). Rang 1 du feu : 15 Marques (v3_bivouac.cpp).
ECLAT, INSIGNE = 910120, 910140
PACIFIQUE, FEUILLARGENT, RACINE, CUIVRE, LIN, CUIR, PIERRE = 2447, 765, 2449, 2770, 2589, 2318, 2835
MALACHITE_TAILLEE, OEIL_TIGRE_TAILLE = 910180, 910181
GENRES = {"potion": 1, "feu": 2}
COUTS = {
    ("potion", 1): {PACIFIQUE: 12, FEUILLARGENT: 8, RACINE: 4, ECLAT: 50, 0: 4000},
    ("potion", 2): {RACINE: 12, OEIL_TIGRE_TAILLE: 2, ECLAT: 120, INSIGNE: 20, 0: 10000},
    ("feu", 2): {CUIVRE: 20, LIN: 16, CUIR: 12, ECLAT: 60, INSIGNE: 20},
    ("feu", 3): {PIERRE: 8, CUIVRE: 20, MALACHITE_TAILLEE: 2, ECLAT: 160, INSIGNE: 40, 0: 8000},
}
NOMS = {("potion", 1): "Potion de Durotar", ("potion", 2): "Potion revigorante",
        ("feu", 1): "Flamme du guerrier", ("feu", 2): "Braises tenaces", ("feu", 3): "Feu de bivouac"}
EFFETS = {
    ("potion", 0): "1 charge, rend 30 % de la vie.",
    ("potion", 1): "2 charges, rendent 35 % de la vie.",
    ("potion", 2): "2 charges, rendent 35 % de la vie, puis 1 % par seconde pendant 10 s.",
    ("feu", 0): "Repos au coin du feu : vie maximale +5 % pendant 30 minutes, 1 % de la vie par seconde hors combat.",
    ("feu", 1): "Le Repos donne aussi +10 % de dégâts.",
    ("feu", 2): "Repos : vie maximale +5 %, +10 % de dégâts, +5 à la caractéristique principale de la spécialisation, 2 % de la vie par seconde hors combat, 30 minutes.",
    ("feu", 3): "Le même Repos, pendant 40 minutes.",
}

SCRIPTS = {POTION: "spell_solazeroth_v3_potion", FEU: "spell_solazeroth_v3_feu"}

# Valeurs du rang de départ : les mêmes que v3_bivouac.cpp, pour les descriptions.
SOIN_POTION, CHARGES, RECHARGE_POTION = 30, 1, 30
REGEN_FEU, BONUS_VIE, DEGATS_REPOS = 6, 5, 10


def lignes(d, icones):
    i = icones
    t = []

    e = technique(d, 441, POTION, "Potion de soins",
                  "Rend %d %% de la vie maximale. %d charge(s), rendue(s) par le Repos au coin du feu et en zone de repos."
                  % (SOIN_POTION, CHARGES), i["inv_alchemy_80_potion01red"], RECHARGE_POTION * 1000)
    effet(e, 0, SOIN, 1, SOI)
    e[205], e[206] = 0, 0           # ne déclenche pas le temps de recharge global : utilisable entre deux techniques
    t.append(e)

    modele = d.chercher(818)
    e = technique(d, 818, FEU, "Feu de camp",
                  "Allume un feu pour 2 minutes et t'assoit à côté ; te lever l'éteint. Assis, tu récupères %d %% de ta vie "
                  "toutes les 2 s. Au bout de 60 s : Repos au coin du feu, et tes potions reviennent." % REGEN_FEU,
                  i["campfire_rootflame"], 120000, duree=D2MIN)
    e[4] |= HORS_COMBAT
    # Le premier effet de Blizzard pose le feu : technique() l'a vidé, on le reprend tel quel.
    for colonne in (71, 74, 77, 80, 83, 86, 89, 92, 95, 98, 101, 104, 107, 110, 113, 116, 119, 216, 229):
        e[colonne] = modele[colonne]
    t.append(e)

    e = technique(d, 12975, REPOS, "Repos au coin du feu",
                  "Vie maximale +%d %% pendant 30 minutes. Hors combat, rend 1 %% de la vie maximale par seconde."
                  % BONUS_VIE, i["campfire_rootflame"], 0,
                  "Vie maximale augmentée de %d %%. Hors combat, 1 %% de la vie maximale rendu par seconde." % BONUS_VIE,
                  duree=D30MIN)
    e[131] = 0
    effet(e, 0, AURA, BONUS_VIE, SOI, aura=VIE_POURCENT)
    t.append(e)

    e = technique(d, 12975, REPOS_FLAMME, "Repos au coin du feu",
                  "Vie maximale +%d %% et dégâts infligés +%d %% pendant 30 minutes. Hors combat, rend 1 %% de la vie "
                  "maximale par seconde." % (BONUS_VIE, DEGATS_REPOS), i["campfire_rootflame"], 0,
                  "Vie maximale augmentée de %d %%, dégâts infligés de %d %%. Hors combat, 1 %% de la vie maximale rendu "
                  "par seconde." % (BONUS_VIE, DEGATS_REPOS), duree=D30MIN)
    e[131] = 0
    effet(e, 0, AURA, BONUS_VIE, SOI, aura=VIE_POURCENT)
    effet(e, 1, AURA, DEGATS_REPOS, SOI, aura=DEGATS_INFLIGES, misc=127)
    t.append(e)

    for sort, misc, carac in REPOS_BRAISES_STATS:
        e = technique(d, 12975, sort, "Repos au coin du feu",
                      "Vie maximale +%d %%, dégâts infligés +%d %% et %s +%d pendant 30 minutes (40 avec le Feu de "
                      "bivouac). Hors combat, rend 2 %% de la vie maximale par seconde."
                      % (BONUS_VIE, DEGATS_REPOS, carac, BONUS_CARACTERISTIQUE), i["campfire_rootflame"], 0,
                      "Vie maximale augmentée de %d %%, dégâts infligés de %d %%, %s de %d. Hors combat, 2 %% de la vie "
                      "maximale rendus par seconde." % (BONUS_VIE, DEGATS_REPOS, carac, BONUS_CARACTERISTIQUE),
                      duree=D30MIN)
        e[131] = 0
        effet(e, 0, AURA, BONUS_VIE, SOI, aura=VIE_POURCENT)
        effet(e, 1, AURA, DEGATS_REPOS, SOI, aura=DEGATS_INFLIGES, misc=127)
        effet(e, 2, AURA, BONUS_CARACTERISTIQUE, SOI, aura=MOD_STAT, misc=misc)
        t.append(e)

    e = technique(d, 441, REVIGORANTE, "Potion revigorante", "Rend 1 % de la vie maximale par seconde pendant 10 s.",
                  i["inv_alchemy_80_potion01red"], 0, "1 % de la vie maximale rendu par seconde.", duree=D10)
    effet(e, 0, AURA, 1, SOI, aura=SOIN_POURCENT_PERIODIQUE)
    e[98] = 1000                    # une fois par seconde
    t.append(e)
    return t


def lua_texte(t):
    return '"%s"' % t.replace("\\", "\\\\").replace('"', '\\"')


def main():
    lignes = ["(%d, %d, %d, %d)" % (GENRES[g], r, o, n) for (g, r), c in sorted(COUTS.items()) for o, n in c.items()]
    up = ["-- v3, F7 (01/11/2026) : listes de courses des rangs de potion et des nœuds du camp. Généré par",
          "-- outils\\bivouac_v3.py : ne pas modifier à la main. genre 1 = potion, 2 = feu ; objet 0 = or (en cuivre).",
          "USE acore_world;",
          "DROP TABLE IF EXISTS solazeroth_v3_camp_couts;",
          "CREATE TABLE solazeroth_v3_camp_couts (genre TINYINT UNSIGNED NOT NULL, rang TINYINT UNSIGNED NOT NULL, "
          "objet INT UNSIGNED NOT NULL, nombre INT UNSIGNED NOT NULL, PRIMARY KEY (genre, rang, objet));",
          "INSERT INTO solazeroth_v3_camp_couts VALUES %s;" % ", ".join(lignes), ""]
    down = ["USE acore_world;", "DROP TABLE IF EXISTS solazeroth_v3_camp_couts;", ""]
    for suffixe, texte in ((".up.sql", up), (".down.sql", down)):
        with open(MIGRATION_COUTS + suffixe, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(texte))

    lua = ["-- Généré par outils\\bivouac_v3.py : ne pas modifier à la main.",
           "-- F7 : rangs de la potion et nœuds de l'arbre du camp. couts : { { objet, nombre }, … } (objet 0 : or, en cuivre).",
           "SolUI.CAMP = {"]
    for genre, maximum in (("potion", 2), ("feu", 3)):
        lua.append("    %s = {" % genre)
        for r in range(maximum + 1):
            couts = COUTS.get((genre, r), {})
            lua.append("        [%d] = { nom = %s, effet = %s, couts = { %s } }," % (
                r, lua_texte(NOMS.get((genre, r), "")), lua_texte(EFFETS[(genre, r)]),
                ", ".join("{ %d, %d }" % kv for kv in couts.items())))
        lua.append("    },")
    lua.append("}")
    with open(CAMP_LUA, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lua) + "\n")
    print("Migration 089 et SolUI_Camp.lua écrits.")


if __name__ == "__main__":
    main()
