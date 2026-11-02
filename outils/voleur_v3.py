"""Sol'Azeroth v3, lot V2 (02/11/2026) : kit du voleur Assassinat (« Voleur — proposition.md », décisions de
l'utilisateur au §7 : toutes les recommandations acceptées, deux dagues obligatoires).

Mêlée avec attaque automatique, comme le guerrier : les techniques font des pourcentages des dégâts de l'arme (main
droite ; la main gauche frappe à moitié, règle du moteur). Poisons et saignements sur la durée font une part de la
puissance d'attaque (spell_bonus_data, ap_dot_bonus). Aucune ressource : ni énergie ni points de combo (règle de la v3),
les cumuls de Poison mortel en tiennent lieu.

Chaque technique est la copie d'un sort de Blizzard (visuel, icône, portée), retouchée comme celles du guerrier
(techniques_v3.technique) : aucun coût, recharge propre, hors de la famille du voleur (le kit retire les anciens sorts de
cette famille), temps de recharge global de 0,75 s, deux dagues exigées (une dague en main droite pour le moteur ; la
règle d'armes de la spécialisation n'en laisse porter aucune autre, v3_kit.cpp).

- Toxines (passif) : chaque coup de mêlée, attaque automatique ou technique, a 30 % de chances de poser un cumul de
  Poison mortel (jusqu'à 5). Déclenchement écrit dans Spell.dbc (aura PROC_TRIGGER_SPELL), que le moteur gère seul.
- Poison mortel : dégâts de Nature toutes les 3 s pendant 12 s, et la cible inflige 3 % de dégâts en moins par cumul
  (le moteur multiplie les deux effets par le nombre de cumuls).
- Envenimer consomme les cumuls : ses dégâts sont multipliés par leur nombre (v3_voleur.cpp).
- Camouflage : hors combat ; quand il se brise, l'Ouverture (3 s, v3_voleur.cpp) fait du coup suivant un Garrot
  (saignement et silence 3 s, déclenché par le moteur).
  Sans forme de camouflage : la barre d'action ne change pas.

Calibrage du lot V4 (simulation_voleur.py) : voir le document de conception.

Appelé par auras_nommees.py, qui écrit le Spell.dbc du client et la migration 129.
"""
import dbc
import techniques_v3 as t

MIGRATION = r"C:\SolAzeroth\sql\migrations\129_v3_kit_voleur"

(TOXINES, POISON, ESTROPIER, ESTROPIER_MG, ENVENIMER, COUP_DE_PIED, RUPTURE, EVASION, CAMOUFLAGE, GARROT, OUVERTURE,
 COUP_BAS, AFFAIBLISSANT, LANCER, SPRINT, DISPARITION, EVENTAIL, CAPE, FEINTE, VENDETTA, AIGUILLON,
 GARROT_SILENCE) = range(100300, 100322)
ASSOMMER = 100322                   # lot V7 : l'Éventail de couteaux lancé en Camouflage (v3_voleur.cpp)
TECHNIQUES = (100302, 100320)
SANS_RECHARGE_GLOBALE = (ESTROPIER_MG, GARROT, OUVERTURE)   # déclenchés
# AttributesEx : SPELL_ATTR1_FINISHING_MOVE_DAMAGE | SPELL_ATTR1_FINISHING_MOVE_DURATION. Les coups de grâce de
# Blizzard (Envenimer, Rupture, Coup bas, Lancer mortel) les portent : le client exige alors des points de combo, qui
# n'existent plus (signalement 27, 02/11/2026).
COUP_DE_GRACE = 0x00100000 | 0x00400000

DAGUES = (2, 1 << 15, 0)            # ITEM_CLASS_WEAPON, ITEM_SUBCLASS_WEAPON_DAGGER
DECLENCHEMENT = 42                  # SPELL_AURA_PROC_TRIGGER_SPELL
COUPS_DE_MELEE = 0x4 | 0x10         # PROC_FLAG_DONE_MELEE_AUTO_ATTACK | PROC_FLAG_DONE_SPELL_MELEE_DMG_CLASS
PERIODIQUE, FURTIVITE, IMMUNITE_ECOLE, VITESSE, RALENTI, SANCTUAIRE = 3, 16, 39, 31, 33, 79
MECANIQUE_SAIGNEMENT, MECANIQUE_ETOURDI, MECANIQUE_SILENCE = 15, 12, 9
D4_, D12, D18 = 35, 29, 85          # SpellDuration.dbc : 4, 12 et 18 s
PORTEE_30 = 4
MAGIQUE, DISTANCE = 1, 3            # SPELL_DAMAGE_CLASS_MAGIC, SPELL_DAMAGE_CLASS_RANGED
PHYSIQUE, NATURE = 1, 8

# Réglages (calibrés au lot V4, simulation_voleur.py) : la simulation lit ces mêmes valeurs.
CHANCE_TOXINES = 50                 # % par coup de mêlée
CUMULS_MAX = 5
AFFAIBLISSEMENT = 8                 # % de dégâts infligés en moins par cumul
ESTROPIER_POURCENT = 300            # chaque main (la gauche frappe à moitié)
ENVENIMER_POURCENT = 180            # par cumul consommé
EVENTAIL_POURCENT = 75              # de l'arme en main droite, sur chaque ennemi à 8 m
EVENTAIL_CUMULS = 2                 # cumuls de Poison mortel posés sur chaque ennemi touché (au plus 2 : effets 1 et 2)
ASSOMMER_DUREE = 10                 # s (durée t.D10) ; tout dégât le brise
RECHARGES = {ASSOMMER: 10000, ESTROPIER: 4000, COUP_DE_PIED: 12000, EVASION: 60000, CAMOUFLAGE: 6000, COUP_BAS: 25000,
             AFFAIBLISSANT: 10000, LANCER: 6000, SPRINT: 60000, DISPARITION: 120000, EVENTAIL: 10000, CAPE: 90000,
             FEINTE: 20000, VENDETTA: 120000, AIGUILLON: 12000}
# Part de la puissance d'attaque : coup direct, ou par tic (et par cumul pour le Poison mortel).
BONUS = {
    POISON: (0, 0.10),              # 4 tics par cumul
    RUPTURE: (0, 0.18),             # 6 tics
    GARROT: (0, 0.18),              # 6 tics
    LANCER: (0.25, 0),
}

SCRIPTS = {
    ENVENIMER: "spell_solazeroth_v3_envenimer",
    CAMOUFLAGE: "spell_solazeroth_v3_camouflage",
    EVENTAIL: "spell_solazeroth_v3_eventail",
    ASSOMMER: "spell_solazeroth_v3_assommer",
}


def sort(d, modele, ident, nom, description, infobulle="", duree=None, ecole=PHYSIQUE, icone_de=None):
    icone = d.chercher(icone_de or modele)[133]
    e = t.technique(d, modele, ident, nom, description, icone, RECHARGES.get(ident, 0), infobulle, duree)
    e[225] = ecole
    e[5] &= ~COUP_DE_GRACE
    if TECHNIQUES[0] <= ident <= TECHNIQUES[1] and ident not in SANS_RECHARGE_GLOBALE:
        e[68], e[69], e[70] = DAGUES
        e[205], e[206] = t.RECHARGE_GLOBALE, 750
    return e


def periodique(e, i, tic_ms):
    e[98 + i] = tic_ms
    e[95 + i] = PERIODIQUE


def lignes(d):
    l = []
    p = lambda x: "%d %%" % round(x * 100)

    # Passif d'identité (17498 : le modèle du Rempart) : le moteur pose le poison.
    e = t.technique(d, 17498, TOXINES, "Toxines",
                    "Passif. Chaque coup de mêlée a %d %% de chances de poser un cumul de Poison mortel sur la cible "
                    "(jusqu'à %d). Chaque cumul fait des dégâts de Nature et réduit de %d %% les dégâts de la cible. "
                    "Envenimer consomme les cumuls." % (CHANCE_TOXINES, CUMULS_MAX, AFFAIBLISSEMENT),
                    d.chercher(31226)[133], 0, duree=t.INFINIE)
    e[4], e[5:12] = t.PASSIF | t.SANS_ANNULATION, [0] * 7
    t.effet(e, 0, t.AURA, 0, t.SOI, aura=DECLENCHEMENT, declencheur=POISON)
    e[34], e[35] = COUPS_DE_MELEE, CHANCE_TOXINES
    l.append(e)

    e = sort(d, 2818, POISON, "Poison mortel", "",
             "Dégâts de Nature toutes les 3 s. Dégâts infligés réduits de %d %% par cumul." % AFFAIBLISSEMENT,
             duree=D12, ecole=NATURE)
    e[49] = CUMULS_MAX
    e[213] = MAGIQUE
    t.effet(e, 0, t.AURA, 1, t.CIBLE)
    periodique(e, 0, 3000)
    t.effet(e, 1, t.AURA, -AFFAIBLISSEMENT, t.CIBLE, aura=t.DEGATS_INFLIGES, misc=127)
    l.append(e)

    # Départ (2 techniques)
    e = sort(d, 1329, ESTROPIER, "Estropier",
             "Frappe avec les deux dagues : %d %% des dégâts de chaque arme (la main gauche frappe à moitié). Pose un "
             "cumul de Poison mortel." % ESTROPIER_POURCENT)
    t.effet(e, 0, t.ARME_POURCENT, ESTROPIER_POURCENT, t.CIBLE)
    t.effet(e, 1, t.DECLENCHER, 0, t.CIBLE, declencheur=ESTROPIER_MG)
    t.effet(e, 2, t.DECLENCHER, 0, t.CIBLE, declencheur=POISON)
    l.append(e)
    e = sort(d, 27576, ESTROPIER_MG, "Estropier", "")       # garde le drapeau « main gauche » de Blizzard
    t.effet(e, 0, t.ARME_POURCENT, ESTROPIER_POURCENT, t.CIBLE)
    l.append(e)

    e = sort(d, 32645, ENVENIMER, "Envenimer",
             "Consomme les cumuls de Poison mortel de la cible : %d %% des dégâts de l'arme par cumul. Il faut au "
             "moins un cumul." % ENVENIMER_POURCENT)
    t.effet(e, 0, t.ARME_POURCENT, ENVENIMER_POURCENT, t.CIBLE)
    l.append(e)

    # Durotar, au fil de l'histoire (5)
    e = sort(d, 1766, COUP_DE_PIED, "Coup de pied", "Interrompt l'incantation de la cible et la réduit au silence 3 s.",
             "Réduit au silence.", duree=t.D3)
    t.effet(e, 0, t.INTERRUPTION, 0, t.CIBLE)
    t.effet(e, 1, t.AURA, 0, t.CIBLE, aura=t.SILENCE)
    e[84] = MECANIQUE_SILENCE
    l.append(e)

    e = sort(d, 5277, EVASION, "Évasion", "Dégâts subis réduits de 50 % pendant 6 s.", "Dégâts subis réduits de 50 %.",
             duree=t.D6)
    t.effet(e, 0, t.AURA, -50, t.SOI, aura=t.DEGATS_SUBIS, misc=127)
    l.append(e)

    # Camouflage : les effets de Blizzard, sans la forme (la barre d'action ne change pas).
    origine = d.chercher(1784)
    e = sort(d, 1784, CAMOUFLAGE, "Camouflage",
             "Hors combat. Vous avancez sans être vu, plus lentement. Le premier coup qui vous révèle est un Garrot : "
             "%s de votre puissance d'attaque en 18 s, et la cible est réduite au silence 3 s."
             % p(6 * BONUS[GARROT][1]), "Camouflé.", duree=t.INFINIE)
    e[71:122] = origine[71:122]
    e[216:219], e[229:232] = origine[216:219], origine[229:232]
    t.effet(e, 0)
    e[4] |= t.HORS_COMBAT
    l.append(e)
    # Ouverture : posée quand le camouflage se brise (v3_voleur.cpp) ; le moteur la consomme au coup suivant.
    e = sort(d, 1784, OUVERTURE, "Ouverture", "", "Votre prochain coup est un Garrot.", duree=t.D3)
    t.effet(e, 0, t.AURA, 0, t.SOI, aura=DECLENCHEMENT, declencheur=GARROT)
    e[34], e[35], e[36] = COUPS_DE_MELEE, 100, 1
    l.append(e)
    e = sort(d, 703, GARROT, "Garrot", "", "Saigne toutes les 3 s.", duree=D18)
    t.effet(e, 0, t.AURA, 1, t.CIBLE)
    periodique(e, 0, 3000)
    e[83] = MECANIQUE_SAIGNEMENT
    t.effet(e, 1, t.DECLENCHER, 0, t.CIBLE, declencheur=GARROT_SILENCE)
    l.append(e)
    e = sort(d, 1330, GARROT_SILENCE, "Garrot", "", "Réduit au silence.", duree=t.D3)
    t.effet(e, 0, t.AURA, 0, t.CIBLE, aura=t.SILENCE)
    e[83] = MECANIQUE_SILENCE
    l.append(e)

    e = sort(d, 408, COUP_BAS, "Coup bas", "Étourdit la cible 4 s.", "Étourdi.", duree=D4_, icone_de=1833)
    t.effet(e, 0, t.AURA, 0, t.CIBLE, aura=t.ETOURDI)
    e[83] = MECANIQUE_ETOURDI
    l.append(e)

    e = sort(d, 1943, RUPTURE, "Rupture",
             "La cible saigne : %s de votre puissance d'attaque en 12 s." % p(6 * BONUS[RUPTURE][1]),
             "Saigne toutes les 2 s.", duree=D12)
    t.effet(e, 0, t.AURA, 1, t.CIBLE)
    periodique(e, 0, 2000)
    e[83] = MECANIQUE_SAIGNEMENT
    l.append(e)

    # Panel des zones suivantes (9)
    e = sort(d, 3409, AFFAIBLISSANT, "Poison affaiblissant",
             "100 % des dégâts de l'arme ; la cible est ralentie de 50 % pendant 8 s.", "Vitesse réduite de 50 %.",
             duree=t.D8)
    e[46] = 2
    t.effet(e, 0, t.ARME_POURCENT, 100, t.CIBLE)
    t.effet(e, 1, t.AURA, -50, t.CIBLE, aura=RALENTI)
    l.append(e)

    e = sort(d, 26679, LANCER, "Lancer de couteau",
             "Lance une dague sur la cible (jusqu'à 30 m) : %s de votre puissance d'attaque." % p(BONUS[LANCER][0]))
    e[46], e[213] = PORTEE_30, DISTANCE
    e[4] &= ~0x2                    # sans l'emplacement d'arme à distance (SPELL_ATTR0_USES_RANGED_SLOT)
    e[68], e[69], e[70] = DAGUES
    t.effet(e, 0, t.DEGATS, 0, t.CIBLE)
    l.append(e)

    e = sort(d, 2983, SPRINT, "Sprint", "Vitesse de course augmentée de 70 % pendant 8 s.",
             "Vitesse de course augmentée de 70 %.", duree=t.D8)
    t.effet(e, 0, t.AURA, 70, t.SOI, aura=VITESSE)
    l.append(e)

    e = sort(d, 1856, DISPARITION, "Disparition",
             "Les ennemis vous perdent de vue, et vous entrez en camouflage.")
    t.effet(e, 0, SANCTUAIRE, 0, t.SOI)
    t.effet(e, 1, t.DECLENCHER, 0, t.SOI, declencheur=CAMOUFLAGE)
    l.append(e)

    e = sort(d, 51723, EVENTAIL, "Éventail de couteaux", "Dégâts autour de soi (8 m) : %d %% des dégâts de l'arme, et %d cumuls de Poison mortel "
             "sur chaque ennemi touché. En Camouflage, il devient Assommer (sa propre recharge)." % (EVENTAIL_POURCENT,
                                                                                             EVENTAIL_CUMULS))
    t.effet(e, 0, t.ARME_POURCENT, EVENTAIL_POURCENT, t.AUTOUR_DE_SOI, t.ZONE_SOURCE, t.R8)
    # Lot V6 : le poison sur chaque ennemi touché (le moteur lance le sort déclenché sur chaque cible de la zone).
    for i in range(1, 1 + EVENTAIL_CUMULS):
        t.effet(e, i, t.DECLENCHER, 0, t.AUTOUR_DE_SOI, t.ZONE_SOURCE, t.R8, declencheur=POISON)
    l.append(e)

    # Lot V7 (idée de l'utilisateur) : lancé par l'Éventail en Camouflage, sur la cible. Le Camouflage reste (attribut
    # de Blizzard gardé) ; tout dégât le brise (drapeau d'interruption gardé, seuil de dégâts du moteur retiré).
    e = sort(d, 6770, ASSOMMER, "Assommer",
             "En Camouflage, par l'Éventail de couteaux : la cible, hors combat, est neutralisée %d s. Tout dégât la "
             "libère. Vous restez camouflé." % ASSOMMER_DUREE, "Assommé.", duree=t.D10)
    t.effet(e, 0, t.AURA, 0, t.CIBLE, aura=t.ETOURDI)
    e[32] |= 0x2                    # AURA_INTERRUPT_FLAG_TAKE_DAMAGE
    e[34:37] = [0, 0, 0]
    e[205], e[206] = t.RECHARGE_GLOBALE, 750
    l.append(e)

    e = sort(d, 31224, CAPE, "Cape d'ombre", "Insensible aux sorts pendant 5 s.", "Insensible aux sorts.", duree=t.D5)
    t.effet(e, 0, t.AURA, 0, t.SOI, aura=IMMUNITE_ECOLE, misc=126)
    l.append(e)

    e = sort(d, 1966, FEINTE, "Feinte", "La cible inflige 40 % de dégâts en moins pendant 5 s.",
             "Dégâts infligés réduits de 40 %.", duree=t.D5)
    t.effet(e, 0, t.AURA, -40, t.CIBLE, aura=t.DEGATS_INFLIGES, misc=127)
    l.append(e)

    e = sort(d, 51662, VENDETTA, "Vendetta", "La cible subit 20 % de dégâts en plus pendant 30 s.",
             "Dégâts subis augmentés de 20 %.", duree=t.D30)
    e[46] = 2
    t.effet(e, 0, t.AURA, 20, t.CIBLE, aura=t.DEGATS_SUBIS, misc=127)
    l.append(e)

    e = sort(d, 5938, AIGUILLON, "Aiguillon perfide",
             "100 % des dégâts de l'arme, et deux cumuls de Poison mortel.")
    t.effet(e, 0, t.ARME_POURCENT, 100, t.CIBLE)
    t.effet(e, 1, t.DECLENCHER, 0, t.CIBLE, declencheur=POISON)
    t.effet(e, 2, t.DECLENCHER, 0, t.CIBLE, declencheur=POISON)
    l.append(e)
    return l


def ecrire(insertions, identifiants):
    """Migration 129 : sorts, scripts et parts de puissance d'attaque."""
    ids = ", ".join(map(str, identifiants))
    up = ["-- v3, lot V2 : kit du voleur Assassinat. Généré par outils\\auras_nommees.py (voleur_v3.py) : ne pas modifier "
          "à la main.",
          "-- Le client lit les mêmes sorts dans patch-frFR-4.MPQ ; Envenimer et le Garrot d'ouverture sont dans "
          "v3_voleur.cpp.",
          "USE acore_world;",
          "DELETE FROM spell_dbc WHERE ID IN (%s);" % ids,
          "DELETE FROM spell_script_names WHERE spell_id IN (%s);" % ids,
          "DELETE FROM spell_bonus_data WHERE entry IN (%s);" % ids]
    sql = list(insertions)
    sql += ["INSERT INTO spell_script_names (spell_id, ScriptName) VALUES (%d, '%s');" % x for x in sorted(SCRIPTS.items())]
    sql += ["INSERT INTO spell_bonus_data (entry, direct_bonus, dot_bonus, ap_bonus, ap_dot_bonus, comments) VALUES "
            "(%d, 0, 0, %.2f, %.2f, 'Sol''Azeroth v3, voleur');" % (i, a, b) for i, (a, b) in sorted(BONUS.items())]
    down = ["-- Retire le kit du voleur Assassinat v3.", "USE acore_world;"] + up[3:]
    for suffixe, contenu in ((".up.sql", up + sql), (".down.sql", down)):
        with open(MIGRATION + suffixe, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(contenu) + "\n")
