"""Sol'Azeroth v3, lot D2 (02/11/2026) : kit du démoniste Affliction (« Démoniste — proposition.md », partie 3).

Règle de l'utilisateur (02/11/2026) : aucun dégât d'arme ; l'arme ne compte que par ses caractéristiques. Les sorts ne
font que de la puissance d'attaque : 0 de base, et une part de la puissance d'attaque du démoniste écrite dans
spell_bonus_data (ap_bonus pour les coups directs, ap_dot_bonus par tic), que le moteur ajoute lui-même. Sa puissance
d'attaque vient de son Intelligence (2 par point, v3_niveau.cpp) et de l'équipement. Un sort se lance en boucle, faible :
Trait de l'ombre. Les sorts sont magiques (critique des sorts, sans armure) et en Ombre, sauf le Trait de feu du diablotin.

Chaque technique est la copie d'un sort de Blizzard (visuel, icône, portée), retouchée comme celles du guerrier
(techniques_v3.technique) : aucun coût, aucun composant, recharge propre, hors de la famille du démoniste (le kit retire
les anciens sorts de cette famille), temps de recharge global de 0,75 s. Choix de l'utilisateur (02/11/2026, lot D4),
qui remplace l'incantation en mouvement : on s'arrête pour incanter et canaliser (Trait, Peur, Graine, Affliction
instable, les Drains), les sorts instantanés se lancent en courant ; c'est la règle des sorts de Blizzard copiés.
Les monstres gardent leur vitesse.

Aucun familier permanent (règle de l'utilisateur) : Diablotin, Marcheur du Vide et Chasseur corrompu sont des invocations
de quelques secondes (v3_demoniste.cpp). Leurs attaques sont des sorts lancés au nom du démoniste : elles suivent sa
puissance d'attaque, et la menace va sur lui (sauf la provocation du Marcheur).

Calibrage du lot D4 (simulation_demoniste.py, 02/11/2026) : l'arme compte dans la puissance d'attaque (ses dégâts par
seconde × 14, v3_niveau.cpp), d'où des parts de PA à 0,64 × celles du premier jet ; Diablotin toutes les 30 s (45
avant), Moisson à 25 % (20 avant), Transe de l'ombre. Le démoniste seul égale alors le guerrier sur les mêmes pièces
(fin de Durotar : 12 à 13 s, 77 à 88 % de vie, contre 10 à 15 s et 80 %) et gagne contre deux monstres de sa puissance
(guerrier aussi). Les sorts des zones suivantes ont reçu le même facteur, sans simulation propre.

Appelé par auras_nommees.py, qui écrit le Spell.dbc du client et la migration 123.
"""
import dbc
import techniques_v3 as t

MIGRATION = r"C:\SolAzeroth\sql\migrations\123_v3_kit_demoniste"

MOISSON, TRAIT, CORRUPTION, DIABLOTIN, AGONIE, DRAIN_DE_VIE, PEUR, MARCHEUR = range(100200, 100208)
FAIBLESSE, SIPHON, HURLEMENT, GRAINE, VOILE, DRAIN_D_AME, PIERRE, CHASSEUR, INSTABLE = (
    100208, 100209, 100210, 100211, 100213, 100214, 100215, 100216, 100217)
EXPLOSION_GRAINE, MOISSON_SOIN, TRAIT_DE_FEU, VERROU, MORSURE, TOURMENT = 100212, 100218, 100219, 100220, 100221, 100222
TRANSE = 100223
TECHNIQUES = (100201, 100217)

# Transe de l'ombre (lot D4) : le prochain Trait de l'ombre est instantané. Le modificateur de temps d'incantation ne
# touche que les sorts de sa famille qui portent son drapeau : la famille 2, qu'aucun sort de Blizzard n'utilise, et le
# drapeau du seul Trait. Le serveur la donne (10 % par tic de Corruption ou d'Agonie) et la retire au Trait instantané.
FAMILLE_SOL, DRAPEAU_TRAIT = 2, 0x1
AJOUT_POURCENT, MOD_INCANTATION = 108, 10      # SPELL_AURA_ADD_PCT_MODIFIER, SPELLMOD_CASTING_TIME
D10 = 1                                        # SpellDuration.dbc : 10 s

# Effets et auras propres au démoniste (SharedDefines.h, SpellAuraDefines.h)
FACTICE, SOIN_POURCENT, ATTAQUE_MOI = 3, 136, 114
PERIODIQUE, DRAIN, PEUR_AURA = 3, 53, 7
MECANIQUE_PEUR, MECANIQUE_HORREUR = 5, 24
D4_, D12, D18, D24 = 35, 29, 85, 106          # SpellDuration.dbc : 4, 12, 18 et 24 s
INCANTATION_1_5 = 16                           # SpellCastTimes.dbc : 1,5 s
INSTANTANE = 1
PORTEE_MELEE = 2                               # SpellRange.dbc : contact
CANALISE = 0x4 | 0x4000                        # SPELL_ATTR1_IS_CHANNELED | SPELL_ATTR1_TRACK_TARGET_IN_CHANNEL
MAGIQUE = 1                                    # SPELL_DAMAGE_CLASS_MAGIC
OMBRE, FEU = 32, 4

# Part de la puissance d'attaque (calibrée au lot D4) : coup direct, ou par tic.
BONUS = {
    TRAIT: (0.16, 0),               # 1,5 s d'incantation, sans recharge : le sort faible, en boucle
    CORRUPTION: (0, 0.13),          # 5 tics : 65 % en 15 s
    AGONIE: (0, 0.08),              # 12 tics : 50 %, puis 100 %, puis 150 % de ce tic (v3_demoniste.cpp)
    DRAIN_DE_VIE: (0, 0.16),        # 5 tics, rend autant
    SIPHON: (0, 0.13),              # 4 tics, rend la moitié
    GRAINE: (0, 0.10),              # 6 tics
    EXPLOSION_GRAINE: (0.32, 0),
    VOILE: (0.38, 0),
    DRAIN_D_AME: (0, 0.13),         # 5 tics, double sous 25 % de vie
    INSTABLE: (0, 0.16),            # 5 tics, +50 % sur une cible qui porte Corruption et Agonie
    TRAIT_DE_FEU: (0.10, 0),        # toutes les 2 s pendant 15 s
    MORSURE: (0.10, 0),             # toutes les 2 s pendant 15 s
}

SCRIPTS = {
    DIABLOTIN: "spell_solazeroth_v3_invocation",
    MARCHEUR: "spell_solazeroth_v3_invocation",
    CHASSEUR: "spell_solazeroth_v3_invocation",
    GRAINE: "spell_solazeroth_v3_graine",
    TRAIT: "spell_solazeroth_v3_trait",
    PEUR: "spell_solazeroth_v3_peur",
    HURLEMENT: "spell_solazeroth_v3_peur",
}

# Invocations : copie de la créature de Blizzard, entrée, nom, script.
INVOCATIONS = [(416, 910050, "Diablotin", "npc_solazeroth_v3_diablotin"),
               (1860, 910051, "Marcheur du Vide", "npc_solazeroth_v3_marcheur"),
               (417, 910052, "Chasseur corrompu", "npc_solazeroth_v3_chasseur")]


def sort(d, modele, ident, nom, description, recharge, infobulle="", duree=None, incantation=INSTANTANE,
         ecole=OMBRE, attributs1=0):
    icone = d.chercher(modele)[133]
    e = t.technique(d, modele, ident, nom, description, icone, recharge, infobulle, duree)
    e[5] = attributs1
    e[28] = incantation
    e[213] = MAGIQUE
    e[225] = ecole
    if TECHNIQUES[0] <= ident <= TECHNIQUES[1]:
        e[205], e[206] = t.RECHARGE_GLOBALE, 750
    return e


def periodique(e, i, aura, tic_ms, multiple=0.0):
    e[98 + i] = tic_ms
    if multiple:
        e[101 + i] = dbc.depuis_flottant(multiple)
    e[95 + i] = aura


def lignes(d):
    l = []

    # Passif d'identité (17498 : le modèle du Rempart).
    e = t.technique(d, 17498, MOISSON, "Moisson",
                    "Passif. 25 % des dégâts de vos sorts sur la durée vous reviennent en vie. Chaque dégât de "
                    "Corruption ou de Malédiction d'agonie a 10 % de chances de rendre votre prochain Trait de l'ombre "
                    "instantané (Transe de l'ombre). Votre arme ne frappe pas : ses dégâts par seconde × 14 s'ajoutent à "
                    "votre puissance d'attaque.",
                    d.chercher(63108)[133], 0, duree=t.INFINIE)
    e[4], e[5:12] = t.PASSIF | t.SANS_ANNULATION, [0] * 7
    t.effet(e, 0, t.AURA, 0, t.SOI, aura=t.AURA_FACTICE)
    l.append(e)
    e = sort(d, 689, MOISSON_SOIN, "Moisson", "", 0)
    t.effet(e, 0, t.SOIN, 1, t.SOI)
    l.append(e)

    # Départ (2 techniques)
    e = sort(d, 686, TRAIT, "Trait de l'ombre",
             "Projette un trait d'ombre sur la cible : 16 % de votre puissance d'attaque.", 0,
             incantation=INCANTATION_1_5)
    t.effet(e, 0, t.DEGATS, 0, t.CIBLE)
    e[208], e[209] = FAMILLE_SOL, DRAPEAU_TRAIT
    l.append(e)

    e = sort(d, 17941, TRANSE, "Transe de l'ombre", "", 0, "Votre prochain Trait de l'ombre est instantané.",
             duree=D10)
    t.effet(e, 0, t.AURA, -100, t.SOI, aura=AJOUT_POURCENT, misc=MOD_INCANTATION)
    e[122] = DRAPEAU_TRAIT
    e[208] = FAMILLE_SOL
    l.append(e)

    e = sort(d, 172, CORRUPTION, "Corruption",
             "Corrompt la cible : 65 % de votre puissance d'attaque en 15 s.", 0, "Dégâts d'Ombre toutes les 3 s.",
             duree=t.D15)
    t.effet(e, 0, t.AURA, 1, t.CIBLE)
    periodique(e, 0, PERIODIQUE, 3000)
    l.append(e)

    # Durotar, au fil de l'histoire (5)
    e = sort(d, 688, DIABLOTIN, "Diablotin",
             "Invoque un diablotin pendant 15 s. Il lance des traits de feu sur votre cible (10 % de votre puissance "
             "d'attaque toutes les 2 s) et n'attire pas les monstres.", 30000)
    t.effet(e, 0, FACTICE, 0, t.SOI)
    l.append(e)
    e = sort(d, 3110, TRAIT_DE_FEU, "Trait de feu", "", 0, ecole=FEU)
    e[46] = 4                       # 30 m
    t.effet(e, 0, t.DEGATS, 0, t.CIBLE)
    l.append(e)

    e = sort(d, 980, AGONIE, "Malédiction d'agonie",
             "Maudit la cible : 96 % de votre puissance d'attaque en 24 s, de plus en plus fort.",
             0, "Dégâts d'Ombre croissants toutes les 2 s.", duree=D24)
    t.effet(e, 0, t.AURA, 1, t.CIBLE)
    periodique(e, 0, PERIODIQUE, 2000)
    l.append(e)

    e = sort(d, 689, DRAIN_DE_VIE, "Drain de vie",
             "Canalisé, 5 s : 16 % de votre puissance d'attaque chaque seconde, et vous rend autant.", 10000,
             "Vie drainée chaque seconde.", duree=t.D5, attributs1=CANALISE)
    t.effet(e, 0, t.AURA, 1, t.CIBLE)
    periodique(e, 0, DRAIN, 1000, 1.0)
    l.append(e)

    e = sort(d, 5782, PEUR, "Peur",
             "La cible fuit, terrifiée, pendant 6 s. La peur se brise quand elle a perdu 15 % de sa vie.", 20000,
             "Terrifié.", duree=t.D6, incantation=INCANTATION_1_5)
    t.effet(e, 0, t.AURA, 0, t.CIBLE, aura=PEUR_AURA)
    e[83] = MECANIQUE_PEUR
    l.append(e)

    e = sort(d, 697, MARCHEUR, "Marcheur du Vide",
             "Invoque un marcheur du Vide pendant 10 s. Il attire à lui les ennemis à 15 m et encaisse leurs coups.",
             60000)
    t.effet(e, 0, FACTICE, 0, t.SOI)
    l.append(e)
    e = sort(d, 3716, TOURMENT, "Tourment", "", 0, "Provoqué.", duree=t.D10)
    t.effet(e, 0, ATTAQUE_MOI, 0, t.AUTOUR_DE_SOI, t.ZONE_SOURCE, t.R15)
    t.effet(e, 1, t.AURA, 0, t.AUTOUR_DE_SOI, t.ZONE_SOURCE, t.R15, aura=t.PROVOCATION)
    l.append(e)

    # Panel des zones suivantes (9)
    e = sort(d, 702, FAIBLESSE, "Malédiction de faiblesse",
             "La cible inflige 20 % de dégâts en moins pendant 30 s.", 10000, "Dégâts infligés réduits de 20 %.",
             duree=t.D30)
    t.effet(e, 0, t.AURA, -20, t.CIBLE, aura=t.DEGATS_INFLIGES, misc=127)
    l.append(e)

    e = sort(d, 172, SIPHON, "Siphon de vie",
             "52 % de votre puissance d'attaque en 12 s ; vous rend la moitié des dégâts.", 10000,
             "Vie drainée toutes les 3 s.", duree=D12)
    e[133] = d.chercher(63108)[133]
    t.effet(e, 0, t.AURA, 1, t.CIBLE)
    periodique(e, 0, DRAIN, 3000, 0.5)
    l.append(e)

    e = sort(d, 5484, HURLEMENT, "Hurlement de terreur",
             "Les ennemis à 10 m fuient, terrifiés, pendant 4 s, ou jusqu'à perdre 15 % de leur vie.", 40000,
             "Terrifié.", duree=D4_)
    t.effet(e, 0, t.AURA, 0, t.AUTOUR_DE_SOI, t.ZONE_SOURCE, 13, aura=PEUR_AURA)
    e[83] = MECANIQUE_PEUR
    l.append(e)

    e = sort(d, 27243, GRAINE, "Graine de corruption",
             "60 % de votre puissance d'attaque en 18 s. À la fin, ou si la cible meurt, la graine explose : 32 % "
             "de votre puissance d'attaque aux ennemis à 10 m.", 15000, "Dégâts d'Ombre toutes les 3 s.", duree=D18,
             incantation=INCANTATION_1_5)
    t.effet(e, 0, t.AURA, 1, t.CIBLE)
    periodique(e, 0, PERIODIQUE, 3000)
    l.append(e)
    e = sort(d, 27285, EXPLOSION_GRAINE, "Graine de corruption", "", 0)
    t.effet(e, 0, t.DEGATS, 0, t.DEST_POINT, t.ZONE_DEST, 13)
    l.append(e)

    e = sort(d, 6789, VOILE, "Voile mortel",
             "38 % de votre puissance d'attaque, et la cible, horrifiée, fuit pendant 3 s.", 30000, "Horrifié.",
             duree=t.D3)
    t.effet(e, 0, t.DEGATS, 0, t.CIBLE)
    t.effet(e, 1, t.AURA, 0, t.CIBLE, aura=PEUR_AURA)
    e[84] = MECANIQUE_HORREUR
    l.append(e)

    e = sort(d, 1120, DRAIN_D_AME, "Drain d'âme",
             "Canalisé, 5 s : 13 % de votre puissance d'attaque chaque seconde, le double sur une cible sous 25 % de "
             "vie.", 15000, "Âme drainée.", duree=t.D5, attributs1=CANALISE)
    t.effet(e, 0, t.AURA, 1, t.CIBLE)
    periodique(e, 0, PERIODIQUE, 1000)
    l.append(e)

    e = sort(d, 6201, PIERRE, "Pierre de soins", "Vous rend 30 % de votre vie maximale.", 120000)
    t.effet(e, 0, SOIN_POURCENT, 30, t.SOI)
    l.append(e)

    e = sort(d, 691, CHASSEUR, "Chasseur corrompu",
             "Invoque un chasseur corrompu pendant 15 s. Il interrompt l'incantation de votre cible et la réduit au "
             "silence 3 s, puis la mord (10 % de votre puissance d'attaque toutes les 2 s).", 45000)
    t.effet(e, 0, FACTICE, 0, t.SOI)
    l.append(e)
    e = sort(d, 19647, VERROU, "Verrou magique", "", 0, "Réduit au silence.", duree=t.D3)
    e[46] = 4
    t.effet(e, 0, t.INTERRUPTION, 0, t.CIBLE)
    t.effet(e, 1, t.AURA, 0, t.CIBLE, aura=t.SILENCE)
    e[84] = 9                       # MECANIQUE_SILENCE
    l.append(e)
    e = sort(d, 54049, MORSURE, "Morsure de l'ombre", "", 0)
    e[46] = PORTEE_MELEE
    t.effet(e, 0, t.DEGATS, 0, t.CIBLE)
    l.append(e)

    e = sort(d, 30108, INSTABLE, "Affliction instable",
             "80 % de votre puissance d'attaque en 15 s ; +50 % sur une cible qui porte déjà Corruption et "
             "Malédiction d'agonie.", 12000, "Dégâts d'Ombre toutes les 3 s.", duree=t.D15, incantation=INCANTATION_1_5)
    t.effet(e, 0, t.AURA, 1, t.CIBLE)
    periodique(e, 0, PERIODIQUE, 3000)
    l.append(e)
    return l


def ecrire(insertions, identifiants, s):
    """Migration 123 : sorts, scripts, parts de puissance d'attaque et invocations."""
    ids = ", ".join(map(str, identifiants))
    creatures = ", ".join(str(c[1]) for c in INVOCATIONS)
    up = ["-- v3, lot D2 : kit du démoniste Affliction. Généré par outils\\auras_nommees.py (demoniste_v3.py) : ne pas "
          "modifier à la main.",
          "-- Le client lit les mêmes sorts dans patch-frFR-4.MPQ ; la Moisson, l'Agonie et les invocations sont dans "
          "v3_demoniste.cpp.",
          "USE acore_world;",
          "DELETE FROM spell_dbc WHERE ID IN (%s);" % ids,
          "DELETE FROM spell_script_names WHERE spell_id IN (%s);" % ids,
          "DELETE FROM spell_bonus_data WHERE entry IN (%s);" % ids,
          "DELETE FROM creature_template WHERE entry IN (%s);" % creatures,
          "DELETE FROM creature_template_model WHERE CreatureID IN (%s);" % creatures,
          "DELETE FROM creature_template_locale WHERE entry IN (%s);" % creatures]
    sql = list(insertions)
    sql += ["INSERT INTO spell_script_names (spell_id, ScriptName) VALUES (%d, '%s');" % x for x in sorted(SCRIPTS.items())]
    sql += ["INSERT INTO spell_bonus_data (entry, direct_bonus, dot_bonus, ap_bonus, ap_dot_bonus, comments) VALUES "
            "(%d, 0, 0, %.2f, %.2f, 'Sol''Azeroth v3, démoniste');" % (i, a, b) for i, (a, b) in sorted(BONUS.items())]
    for origine, entree, nom, script in INVOCATIONS:
        sql += ["CREATE TEMPORARY TABLE sol_t SELECT * FROM creature_template WHERE entry = %d;" % origine,
                "UPDATE sol_t SET entry = %d, name = %s, subname = '', minlevel = 80, maxlevel = 80, faction = 35, "
                "AIName = '', ScriptName = '%s', KillCredit1 = 0, KillCredit2 = 0, lootid = 0, pickpocketloot = 0, "
                "skinloot = 0, mingold = 0, maxgold = 0, PetSpellDataId = 0, npcflag = 0;" % (entree, s(nom), script),
                "INSERT INTO creature_template SELECT * FROM sol_t;",
                "DROP TEMPORARY TABLE sol_t;",
                "INSERT INTO creature_template_model (CreatureID, Idx, CreatureDisplayID, DisplayScale, Probability, "
                "VerifiedBuild) SELECT %d, Idx, CreatureDisplayID, DisplayScale, Probability, VerifiedBuild FROM "
                "creature_template_model WHERE CreatureID = %d;" % (entree, origine),
                "INSERT INTO creature_template_locale (entry, locale, Name, Title, VerifiedBuild) VALUES (%d, 'frFR', %s, "
                "'', 0);" % (entree, s(nom))]
    down = ["-- Retire le kit du démoniste Affliction v3.", "USE acore_world;"] + up[3:]
    for suffixe, contenu in ((".up.sql", up + sql), (".down.sql", down)):
        with open(MIGRATION + suffixe, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(contenu) + "\n")
