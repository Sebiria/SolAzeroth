"""Sol'Azeroth v3 (31/10/2026) : potion et feu de camp, les deux boutons à droite des techniques (document v3, F7).

Rang de départ seulement ; les améliorations par liste de courses viendront avec F7. Trois sorts, copiés de Blizzard
et retouchés comme les techniques (techniques_v3.technique) :
- Potion de soins : copie de la Potion de soins (441), soin propre au module (spell_solazeroth_v3_potion : part de la
  vie maximale, charges) ;
- Feu de camp : copie du Feu de camp simple (818), qui pose le même feu (objet 29784, foyer de cuisine), sans bois ni
  briquet. Le personnage s'assoit à côté ; se lever l'éteint (spell_solazeroth_v3_feu, v3_bivouac.cpp) ;
- Repos au coin du feu : le bonus reçu après 60 s assis près du feu, qui rend aussi les potions.

Appelé par auras_nommees.py, qui écrit le Spell.dbc du client et la migration 067.
"""
from techniques_v3 import AURA, HORS_COMBAT, SOI, SOIN, VIE_POURCENT, effet, technique

MIGRATION = r"C:\SolAzeroth\sql\migrations\067_v3_bivouac"

POTION, FEU, REPOS = 100029, 100030, 100031
D2MIN, D30MIN = 4, 30               # SpellDuration.dbc : 120 s, 1800 s

SCRIPTS = {POTION: "spell_solazeroth_v3_potion", FEU: "spell_solazeroth_v3_feu"}

# Valeurs du rang de départ : les mêmes que v3_bivouac.cpp, pour les descriptions.
SOIN_POTION, CHARGES, RECHARGE_POTION = 30, 1, 30
REGEN_FEU, BONUS_VIE = 6, 5


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
    return t
