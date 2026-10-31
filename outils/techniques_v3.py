"""Sol'Azeroth v3, F3 (31/10/2026) : kit du guerrier tank (document v3, partie 3).

Chaque technique est la copie d'un sort de Blizzard (visuel, ciblage), retouchée : aucun coût, aucune posture, aucune
arme ni bouclier requis, recharge propre, sans temps de recharge global, valeurs fixes. Les dégâts sont des
pourcentages des dégâts de l'arme, pour suivre l'équipement. Ce qui ne s'écrit pas dans Spell.dbc (Rempart, dégâts
selon le Rempart, bonus de Ravage) est fait par le module (v3_kit.cpp, SpellScripts nommés ci-dessous).

Appelé par auras_nommees.py, qui écrit le Spell.dbc du client et la migration 061.
"""
import dbc
from hauts_faits_natifs import FRFR, MASQUE

MIGRATION = r"C:\SolAzeroth\sql\migrations\061_v3_kit_guerrier"

TEXTES = [136, 153, 170, 187]       # nom, rang, description, infobulle de l'aura
SANS_ANNULATION = 0x80000000        # SPELL_ATTR0_CANT_CANCEL
PASSIF = 0x40                       # SPELL_ATTR0_PASSIVE
HORS_COMBAT = 0x10000000            # SPELL_ATTR0_NOT_IN_COMBAT_ONLY_PEACEFUL (Charge de Blizzard)

# Effets, auras et cibles (SharedDefines.h, SpellAuraDefines.h)
SOIN, DECLENCHER, AURA, ARME_POURCENT, DEGATS, SAUT, INTERRUPTION, ATTIRER = 10, 64, 6, 31, 2, 42, 68, 124
AURA_FACTICE, PROVOCATION, ETOURDI, SILENCE, ABSORPTION = 4, 11, 12, 27, 69
DEGATS_INFLIGES, DEGATS_SUBIS, ARMURE_POURCENT, VIE_POURCENT, HATE_MELEE, RENVOI = 79, 87, 101, 133, 138, 28
SOI, CIBLE, AUTOUR_DE_SOI, ZONE_SOURCE, ZONE_DEST, DEST_CIBLE, DEST_POINT, CONE = 1, 6, 22, 15, 16, 53, 87, 104
# Durées (SpellDuration.dbc) et rayons (SpellRadius.dbc)
D1, D2, D3, D5, D6, D8, D10, D15, D30, INFINIE = 36, 39, 27, 28, 32, 31, 1, 8, 9, 21
R5, R8, R10, R15 = 8, 14, 13, 18
PORTEE_25 = 34                      # SpellRange.dbc : 0 à 25 m

FRAPPE_DU_BOUCLIER, RIPOSTE, SECOND_SOUFFLE, RAVAGE, VENGEANCE, DERNIER_REMPART, REMPART, CRI_DE_DEFI = (
    100011, 100014, 100016, 100017, 100025, 100026, 100010, 100015)

SCRIPTS = {
    REMPART: "spell_solazeroth_v3_rempart",
    FRAPPE_DU_BOUCLIER: "spell_solazeroth_v3_frappe_bouclier",
    CRI_DE_DEFI: "spell_solazeroth_v3_cri_defi",
    RIPOSTE: "spell_solazeroth_v3_riposte",
    SECOND_SOUFFLE: "spell_solazeroth_v3_second_souffle",
    RAVAGE: "spell_solazeroth_v3_ravage",
    VENGEANCE: "spell_solazeroth_v3_vengeance",
    DERNIER_REMPART: "spell_solazeroth_v3_dernier_rempart",
}


def textes(d, e, nom, description, infobulle=""):
    for debut, chaine in zip(TEXTES, [nom, "", description, infobulle]):
        e[debut:debut + 16] = [0] * 16
        if chaine:
            e[debut] = e[debut + FRFR] = d.ajouter_texte(chaine)
        e[debut + 16] = MASQUE if chaine else 0


def effet(e, i, type_=0, valeur=0, cible_a=0, cible_b=0, rayon=0, aura=0, misc=0, declencheur=0):
    """Remplace l'effet i ; valeur = montant voulu (le jeu ajoute 1 à la base quand le dé a une face)."""
    e[71 + i] = type_
    e[74 + i] = 1 if type_ else 0
    e[77 + i] = 0
    e[80 + i] = (valeur - 1) & 0xFFFFFFFF if type_ else 0
    e[83 + i] = 0
    e[86 + i], e[89 + i], e[92 + i], e[95 + i] = cible_a, cible_b, rayon, aura
    e[98 + i] = e[101 + i] = e[104 + i] = e[107 + i] = 0
    e[110 + i], e[113 + i], e[116 + i], e[119 + i] = misc, 0, declencheur, 0
    e[216 + i] = dbc.depuis_flottant(1.0)
    e[229 + i] = 0


def technique(d, modele, ident, nom, description, icone, recharge, infobulle="", duree=None):
    e = list(d.chercher(modele))
    e[0] = ident
    e[1] = 0                        # pas de catégorie : chaque technique a sa propre recharge
    e[4] &= ~HORS_COMBAT
    e[12:16] = [0] * 4              # aucune posture
    e[20:28] = [0] * 8              # aucun état ni aura requis (Vengeance de Blizzard demandait un blocage)
    e[29], e[30] = recharge, 0
    e[37:40] = [0] * 3
    e[42:46] = [0] * 4              # aucun coût
    e[50:68] = [0] * 18             # ni totem ni composant
    e[68], e[69], e[70] = 0xFFFFFFFF, 0, 0   # aucune arme ni bouclier requis
    e[122:131] = [0] * 9
    e[133], e[134] = icone, 0
    e[204], e[205], e[206] = 0, 0, 0          # aucun temps de recharge global (demande de l'utilisateur, 31/10/2026)
    e[208:212] = [0] * 4            # hors de la famille du guerrier : ni talent ni script de Blizzard ne s'y accroche
    e[213] = 2                      # dégâts de mêlée
    e[226] = 0
    e[232] = 0
    if duree is not None:
        e[40] = duree
    for i in range(3):
        effet(e, i)
    textes(d, e, nom, description, infobulle)
    return e


def lignes(d, icones):
    i = icones
    t = []

    # Passif d'identité, visible dans le grimoire, et le bouclier qu'il remplit.
    e = technique(d, 17498, 100009, "Rempart",
                  "Passif. Chaque coup encaissé, après l'armure, verse 25 % de ses dégâts dans le Rempart, un bouclier qui "
                  "absorbe les coups suivants, plafonné à 30 % de la vie maximale. Il se vide doucement hors combat. "
                  "Riposte du rempart et Second souffle le consomment.",
                  i["inv_shield_1h_artifactmagnar_d_01"], 0, duree=INFINIE)
    e[4], e[5:12] = PASSIF | SANS_ANNULATION, [0] * 7
    effet(e, 0, AURA, 0, SOI, aura=AURA_FACTICE)
    t.append(e)
    e = technique(d, 17498, REMPART, "Rempart", "Absorbe les dégâts.", i["inv_shield_1h_artifactmagnar_d_01"], 0,
                  "Absorbe les dégâts.", duree=INFINIE)
    e[4], e[5:12] = SANS_ANNULATION, [0] * 7
    effet(e, 0, AURA, 0, SOI, aura=ABSORPTION, misc=127)
    t.append(e)

    # Les 8 techniques de départ (partie 3.2)
    e = technique(d, 23922, FRAPPE_DU_BOUCLIER, "Frappe du bouclier",
                  "Frappe la cible : 200 % des dégâts de l'arme. Verse 5 % de la vie maximale dans le Rempart.",
                  i["ability_warrior_shieldcharge"], 6000)
    effet(e, 0, ARME_POURCENT, 200, CIBLE)
    t.append(e)

    e = technique(d, 6343, 100012, "Coup de tonnerre",
                  "Dégâts autour de soi (8 m) : 100 % des dégâts de l'arme. Les ennemis touchés frappent 20 % moins "
                  "vite pendant 10 s.", i["warrior_talent_icon_bloodandthunder"], 8000,
                  "Vitesse d'attaque réduite de 20 %.", duree=D10)
    effet(e, 0, ARME_POURCENT, 100, AUTOUR_DE_SOI, ZONE_SOURCE, R8)
    effet(e, 1, AURA, -20, AUTOUR_DE_SOI, ZONE_SOURCE, R8, aura=HATE_MELEE)
    t.append(e)

    e = technique(d, 100, 100013, "Charge", "Bondit sur la cible (8 à 25 m) et l'étourdit 1 s. Utilisable en combat.",
                  i["ability_warrior_charge"], 15000)
    effet(e, 0, 96, 0, CIBLE)       # SPELL_EFFECT_CHARGE
    effet(e, 2, DECLENCHER, 0, CIBLE, declencheur=100028)
    t.append(e)
    e = technique(d, 7922, 100028, "Charge", "", i["ability_warrior_charge"], 0, "Étourdi.", duree=D1)
    effet(e, 0, AURA, 0, CIBLE, aura=ETOURDI)
    e[83] = 12                      # MECHANIC_STUN
    t.append(e)

    e = technique(d, 6572, RIPOSTE, "Riposte du rempart",
                  "Consomme tout le Rempart : inflige 150 % du montant consommé à la cible et aux ennemis à 8 m "
                  "autour d'elle.", i["inv_shield_1h_artifactmagnar_d_02"], 10000)
    effet(e, 0, DEGATS, 1, DEST_CIBLE, ZONE_DEST, R8)
    t.append(e)

    # 31/10/2026 : la provocation ne servait à rien en solo (le joueur est la seule cible). Chaque ennemi attiré
    # remplit le Rempart à la place (v3_kit.cpp), choix de l'utilisateur.
    e = technique(d, 1161, CRI_DE_DEFI, "Cri de défi",
                  "Attire vers soi tous les ennemis à moins de 15 m. Chaque ennemi attiré verse 3 % de votre vie "
                  "maximale dans le Rempart.", i["ability_warrior_bullrush"], 12000)
    effet(e, 0, ATTIRER, 0, AUTOUR_DE_SOI, ZONE_SOURCE, R15, misc=250)
    effet(e, 1)
    t.append(e)

    e = technique(d, 12975, SECOND_SOUFFLE, "Second souffle", "Consomme tout le Rempart : rend autant de points de vie.",
                  i["ability_warrior_renewedvigor"], 45000)
    e[131] = 12582                  # visuel de Régénération enragée
    effet(e, 0, SOIN, 1, SOI)
    t.append(e)

    e = technique(d, 1680, RAVAGE, "Ravage",
                  "Dégâts autour de soi (8 m) : 100 % des dégâts de l'arme, +10 % par ennemi touché (jusqu'à +50 %).",
                  i["warrior_talent_icon_ravager"], 10000)
    effet(e, 0, ARME_POURCENT, 100, AUTOUR_DE_SOI, ZONE_SOURCE, R8)
    t.append(e)

    e = technique(d, 871, 100018, "Mur protecteur", "Dégâts subis réduits de 50 % pendant 8 s.",
                  i["ability_warrior_shieldwall"], 90000, "Dégâts subis réduits de 50 %.", duree=D8)
    effet(e, 0, AURA, -50, SOI, aura=DEGATS_SUBIS, misc=127)
    t.append(e)

    # Les 8 techniques du panel (partie 3.3)
    e = technique(d, 72, 100019, "Heurt de bouclier", "Interrompt l'incantation de la cible et la réduit au silence 3 s.",
                  i["ability_warrior_shieldbreak"], 12000, "Réduit au silence.", duree=D3)
    effet(e, 0, INTERRUPTION, 0, CIBLE)
    effet(e, 1, AURA, 0, CIBLE, aura=SILENCE)
    e[84] = 9                       # MECHANIC_SILENCE
    t.append(e)

    e = technique(d, 7386, 100020, "Fracasser armure", "Réduit l'armure de la cible de 10 % pendant 30 s. Se cumule 3 fois.",
                  i["ability_warrior_colossussmash"], 8000, "Armure réduite de 10 % par cumul.", duree=D30)
    e[49] = 3
    effet(e, 0, AURA, -10, CIBLE, aura=ARMURE_POURCENT, misc=1)
    t.append(e)

    e = technique(d, 676, 100021, "Désarmement", "La cible inflige 50 % de dégâts en moins pendant 6 s.",
                  i["ability_warrior_disarm"], 30000, "Dégâts infligés réduits de 50 %.", duree=D6)
    effet(e, 0, AURA, -50, CIBLE, aura=DEGATS_INFLIGES, misc=127)
    t.append(e)

    e = technique(d, 46968, 100022, "Onde de choc", "Cône devant soi (10 m) : 150 % des dégâts de l'arme, étourdit 2 s.",
                  i["ability_warrior_shockwave"], 20000, "Étourdi.", duree=D2)
    effet(e, 0, AURA, 0, CONE, rayon=R10, aura=ETOURDI)
    e[83] = 12
    effet(e, 1, ARME_POURCENT, 150, CONE, rayon=R10)
    t.append(e)

    e = technique(d, 6544, 100023, "Bond héroïque",
                  "Saute vers un point (jusqu'à 25 m) : 100 % des dégâts de l'arme aux ennemis à 5 m de l'arrivée.",
                  i["ability_heroicleap"], 20000)
    e[46] = PORTEE_25
    effet(e, 0, SAUT, 0, DEST_POINT, misc=10)
    effet(e, 1, DECLENCHER, 0, DEST_POINT, declencheur=100027)
    t.append(e)
    e = technique(d, 52174, 100027, "Bond héroïque", "", i["ability_heroicleap"], 0)
    effet(e, 0, ARME_POURCENT, 100, ZONE_DEST, rayon=R5)
    t.append(e)

    e = technique(d, 23920, 100024, "Renvoi de sort", "Renvoie le prochain sort reçu dans les 5 s.",
                  i["ability_warrior_shieldreflection"], 20000, "Renvoie le prochain sort.", duree=D5)
    effet(e, 0, AURA, 100, SOI, aura=RENVOI)
    t.append(e)

    e = technique(d, 6572, VENGEANCE, "Vengeance",
                  "Utilisable seulement si le Rempart est plein : 300 % des dégâts de l'arme à la cible. Ne consomme "
                  "pas le Rempart.", i["warrior_talent_icon_igniteweapon"], 8000)
    effet(e, 0, ARME_POURCENT, 300, CIBLE)
    t.append(e)

    e = technique(d, 12975, DERNIER_REMPART, "Dernier rempart",
                  "Vie maximale +30 % pendant 15 s, et le Rempart se remplit.",
                  i["ability_warrior_improveddisciplines"], 120000, "Vie maximale augmentée de 30 %.", duree=D15)
    e[131] = 2758                   # visuel du Dernier rempart de Blizzard
    effet(e, 0, AURA, 30, SOI, aura=VIE_POURCENT)
    t.append(e)
    return t
