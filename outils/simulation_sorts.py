"""v3 (01/11/2026, demande de l'utilisateur : « soit on le retire, soit on lui applique un effet mais au détriment
d'autres dégâts pour garder l'équilibre. Et ça vaut pour tous les autres mobs ») : les sorts des monstres dans la
simulation de combat.

simulation_combat.py ne joue que la mêlée des monstres (et un poison relevé dans le journal). Ici, chaque monstre lance
aussi les sorts de son script SmartAI, comme le serveur :
- délais du script (événement « en combat » : premier délai puis répétition ; « vie basse » : sous un seuil ;
  « à l'engagement » ; « hors combat » : renforcements et renforts déjà en place), chance de l'événement ;
- incantation : le monstre ne frappe pas pendant qu'il incante ;
- valeur : celle du sort au niveau d'origine du monstre (sa puissance), comme le fait v3_combat.cpp (EchelleSort,
  OnAuraApply) ; puis ×4 pour un coup physique (avant l'armure), ×2 pour un sort magique, ×1,5 pour les dégâts sur la
  durée (SolAzeroth.V3.MonstresDegats, MonstresDegatsSorts, MonstresDegatsDuree) ;
- effets joués : dégâts directs, coups d'arme, dégâts sur la durée, drain, soins (sur soi ou un allié), étourdissement
  du joueur, vitesse d'attaque, dégâts en plus (fixes ou en %), dégâts subis en %, armure (du joueur ou du monstre),
  soins reçus en %, boucliers de dégâts et effets déclenchés, renforts (diablotins, marcheurs) ;
- ignorés : ce que la v3 annule (esquive, blocage, chances de toucher), la course, la taille, les interruptions (le
  joueur n'incante pas), l'Intelligence.

combat_sorts() suit combat_groupe() de simulation_combat.py (le joueur frappe le premier monstre en vie, Coup de
tonnerre touche tous les monstres) avec la potion. Sans sorts et contre un seul monstre, il doit rendre les mêmes
chiffres que simulation_combat.combat() : c'est vérifié par py simulation_sorts.py --verifier.

py simulation_sorts.py --monstre 3205             sorts de Zalazane, et le combat avec et sans eux
"""
import argparse
import os
import random
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import dbc
import simulation_combat as sim
from quetes_durotar import sql

DBC = r"C:\SolAzeroth\data\dbc"
PHYSIQUE = 1
SOI, ENNEMI = "soi", "ennemi"
# Événements SmartAI joués (les autres ne se produisent pas contre un joueur seul qui n'incante pas).
EN_COMBAT, HORS_COMBAT, VIE_BASSE, ENGAGEMENT, A_DISTANCE, ALLIE_BLESSE, ALLIE_SANS_BUFF = 0, 1, 2, 4, 9, 14, 16
PAS_REPETABLE = 1

_spell = _durees = _bd = None
SORTS_AJOUTES = {}   # sorts Sol'Azeroth (spell_dbc) : id -> enregistrement, ajoutés par sorts_monstres_v3.py


def _charger():
    global _spell, _durees, _bd
    if _spell is None:
        _spell = {e[0]: e for e in dbc.Dbc.ouvrir(os.path.join(DBC, "Spell.dbc")).enregistrements}
        _durees = {e[0]: s32(e[1]) for e in dbc.Dbc.ouvrir(os.path.join(DBC, "SpellDuration.dbc")).enregistrements}
        _bd = {(int(l), int(c)): float(b) for l, c, b in sql(
            "SELECT level, class, damage_base FROM acore_world.creature_classlevelstats")}
        global _incantations
        _incantations = {e[0]: s32(e[1]) for e in dbc.Dbc.ouvrir(os.path.join(DBC, "SpellCastTimes.dbc")).enregistrements}
        import sorts_monstres_v3
        for e in sorts_monstres_v3.lignes(dbc.Dbc.ouvrir(os.path.join(DBC, "Spell.dbc"))):
            SORTS_AJOUTES[e[0]] = e


def s32(v):
    return struct.unpack("<i", struct.pack("<I", v))[0]


def enregistrement(sid):
    _charger()
    return SORTS_AJOUTES.get(sid) or _spell.get(sid)


def valeur(e, i, niveau, classe):
    """Valeur moyenne de l'effet i au niveau d'origine du monstre (règles du moteur, puis rapport de v3_combat.cpp)."""
    base, des, ppl = s32(e[80 + i]) + 1, s32(e[74 + i]), dbc.flottant(e[77 + i])
    v = base + (abs(des) - 1) / 2.0 if abs(des) > 1 else float(base)
    max_niv, base_niv, sort_niv = e[37], e[38], e[39]
    if ppl:
        n = min(niveau, max_niv) if max_niv else niveau
        v += (max(n, base_niv) - max(base_niv, sort_niv)) * ppl
    elif e[4] & 0x80000 and sort_niv and (niveau, classe) in _bd and (sort_niv, classe) in _bd:
        v *= _bd[(niveau, classe)] / _bd[(sort_niv, classe)]   # SPELL_ATTR0_SCALES_WITH_CREATURE_LEVEL
    return v


def duree(e):
    d = _durees.get(e[40], 0)
    return d / 1000.0 if d > 0 else 600.0


def effets(sid, niveau, classe, cible_script):
    """Ce que fait le sort, en effets simples : [(genre, qui, valeur, durée, extra)]."""
    e = enregistrement(sid)
    if not e:
        return []
    physique = e[225] == PHYSIQUE
    dure = duree(e)
    sortie = []
    for i in range(3):
        effet, aura = e[71 + i], e[95 + i]
        if not effet:
            continue
        v = valeur(e, i, niveau, classe)
        qui = SOI if (e[86 + i] == 1 or cible_script == 1) else ENNEMI
        intervalle = (e[98 + i] or 3000) / 1000.0
        misc = s32(e[110 + i])
        if effet == 2:
            sortie.append(("direct", ENNEMI, v, 0, physique))
        elif effet in (17, 58, 121):
            sortie.append(("arme", ENNEMI, v, 0, None))
        elif effet == 31:
            sortie.append(("arme_pct", ENNEMI, v, 0, None))
        elif effet == 10:
            sortie.append(("soin", SOI, v, 0, None))
        elif effet in (28, 56) and misc > 0:
            sortie.append(("renfort", SOI, misc, 0, None))
        elif effet in (6, 27, 35):
            if aura == 3:
                sortie.append(("dot", ENNEMI, v, dure, intervalle))
            elif aura == 53:
                sortie.append(("drain", ENNEMI, v, dure, intervalle))
            elif aura == 8:
                sortie.append(("hot", SOI, v, dure, intervalle))
            elif aura == 12:
                sortie.append(("etourdi", ENNEMI, 0, min(dure, 10.0), None))
            elif aura == 13:
                sortie.append(("degats_plus" if qui == SOI else "degats_moins", qui, abs(v), dure, None))
            elif aura == 79:
                sortie.append(("degats_pct", qui, v, dure, None))
            elif aura == 87:
                sortie.append(("subis_pct", qui, v, dure, None))
            elif aura == 138:
                sortie.append(("hate_pct", qui, v, dure, None))
            elif aura == 22 and misc & 1:
                sortie.append(("armure", qui, v, dure, e[49]))
            elif aura == 101 and misc & 1:
                sortie.append(("armure_pct", qui, v, dure, e[49]))
            elif aura == 118:
                sortie.append(("soins_pct", qui, v, dure, None))
            elif aura == 15:
                sortie.append(("epines", SOI, v * 2, dure, None))
            elif aura == 42 and e[116 + i]:
                t = enregistrement(e[116 + i])
                if t:
                    sous = [x for x in effets(e[116 + i], niveau, classe, 2) if x[0] == "direct"]
                    if sous:
                        sens = "subi" if e[34] & 0x2A8 else "porte"   # touché en mêlée ou à distance / frappe
                        sortie.append(("declenche", SOI, sous[0][2] * (4 if sous[0][4] else 2), dure,
                                       (sens, e[35] / 100.0, e[36] or 999)))
            elif aura == 29 and qui == ENNEMI and misc == 0:
                sortie.append(("force", ENNEMI, v, dure, None))
            elif aura == 99 and qui == ENNEMI:
                sortie.append(("pa", ENNEMI, v, dure, None))
    return sortie


def incantation(e):
    return max(0, _incantations.get(e[28], 0)) / 1000.0


def sorts_du_monstre(entree, niveau, classe=None):
    """Sorts du script SmartAI : [{id, evenement, p, chance, unique, cible, incantation, effets}]."""
    _charger()
    if classe is None:
        classe = int(sql("SELECT unit_class FROM acore_world.creature_template WHERE entry = %d" % entree)[0][0])
    liste = []
    for ev, chance, drapeaux, p1, p2, p3, p4, sid, cible in sql(
            "SELECT event_type, event_chance, event_flags, event_param1, event_param2, event_param3, event_param4, "
            "action_param1, target_type FROM acore_world.smart_scripts WHERE source_type = 0 AND entryorguid = %d AND "
            "action_type IN (11, 85, 86, 134) ORDER BY id" % entree):
        ev, sid, cible = int(ev), int(sid), int(cible)
        e = enregistrement(sid)
        if not e or ev not in (EN_COMBAT, HORS_COMBAT, VIE_BASSE, ENGAGEMENT, A_DISTANCE, ALLIE_BLESSE, ALLIE_SANS_BUFF):
            continue
        ef = effets(sid, niveau, classe, cible)
        if not ef:
            continue
        liste.append({"id": sid, "evenement": ev, "p": [int(p1), int(p2), int(p3), int(p4)], "chance": int(chance),
                      "unique": bool(int(drapeaux) & PAS_REPETABLE), "cible": cible,
                      "incantation": incantation(e) if ev not in (HORS_COMBAT, ALLIE_SANS_BUFF) else 0.0,
                      "effets": ef})
    return liste


def monstre_avec_sorts(entree, niveau=None, renforts=True):
    m = sim.monstre_depuis_base(entree, niveau)
    classe = int(sql("SELECT unit_class FROM acore_world.creature_template WHERE entry = %d" % entree)[0][0])
    m.sorts = sorts_du_monstre(entree, m.puissance, classe)
    m.renforts = []
    if renforts:
        for s in m.sorts:
            for genre, _, v, _, _ in s["effets"]:
                if genre == "renfort" and s["evenement"] in (HORS_COMBAT, ENGAGEMENT, ALLIE_SANS_BUFF):
                    try:
                        m.renforts.append(monstre_avec_sorts(int(v), m.puissance, renforts=False))
                    except IndexError:
                        pass
    return m


# --- Combat ---------------------------------------------------------------------------------------------------------
class Etat:
    def __init__(self, m):
        self.m, self.vie, self.incante_jusqua = m, m.vie, 0.0
        self.plus = []        # (fin, dégâts fixes en plus par coup)
        self.pct = []         # (fin, % de dégâts)
        self.hate = []        # (fin, % de vitesse d'attaque)
        self.subis = []       # (fin, % de dégâts subis)
        self.armure = []      # (fin, armure en plus)
        self.epines = []      # (fin, dégâts rendus à chaque coup du joueur)
        self.declenche = []   # [fin, dégâts, sens, chance, charges]
        self.hots = []        # [prochain, fin, valeur, intervalle]

    def actifs(self, liste, t):
        return [x for x in liste if x[0] > t]


def combat_sorts(joueur, monstres, alea, potion=None, reaction=1.4, sorts=True, melee=1.0, facteur_sorts=1.0,
                 cri=True):
    """Combat contre des monstres (avec leurs sorts et leurs renforts). melee : facteur sur la mêlée des monstres
    (réglage de DamageModifier) ; facteur_sorts : sur les dégâts et soins de leurs sorts. Renvoie (victoire, durée,
    vie restante, dégâts infligés, dégâts subis)."""
    tous = []
    for m in monstres:
        tous.append(m)
        if sorts:
            tous.extend(getattr(m, "renforts", []))
    etats = [Etat(m) for m in tous]
    for e in etats:
        e.principal = any(e.m is m for m in monstres)   # le facteur de mêlée ne touche pas les renforts
    vie_j = joueur.vie
    plafond = int(joueur.vie * sim.REMPART_PLAFOND)
    rempart = 0
    t = 0.0
    prochain = {"melee_j": 0.1, "frappe": 0.0, "tonnerre": 1.5, "cri": 0.0 if cri and len(etats) > 1 else None,
                "soin": None}
    for i, e in enumerate(etats):
        prochain[("melee_m", i)] = 2.0 * e.m.vitesse / 2.0 if len(etats) == 1 else e.m.vitesse * alea.uniform(0.5, 1.0)
    ralenti_jusqua = -1.0
    etourdi_jusqua = -1.0
    inflige = subi = 0
    charges, potion_prete, soins_restants = (potion[0] if potion else 0), 0.0, 0
    dots = []      # [prochain tick, fin, valeur par tick, intervalle, drain : indice du monstre ou None, clé]
    debuffs = {}   # clé -> (fin, genre, valeur, cumuls)
    minuteries = {}

    def actif(genre):
        return [(v, c) for (f, g, v, c) in debuffs.values() if g == genre and f > t]

    def armure_joueur():
        a = joueur.armure + sum(v * c for v, c in actif("armure"))
        a *= 1 + sum(v * c for v, c in actif("armure_pct")) / 100.0
        return max(0, a)

    def soigner_joueur(montant):
        nonlocal vie_j
        f = 1 + sum(v for v, _ in actif("soins_pct")) / 100.0
        vie_j = min(joueur.vie, vie_j + round(montant * max(0.0, f)))

    def boire():
        nonlocal charges, potion_prete, soins_restants
        if charges and t >= potion_prete and vie_j < joueur.vie * sim.SEUIL_POTION:
            soigner_joueur(joueur.vie * potion[1] / 100.0)
            charges -= 1
            potion_prete = t + sim.RECHARGE_POTION
            if potion[2]:
                soins_restants = potion[3]
                prochain["soin"] = t + 1.0

    def malus(m):
        return min(max(0.0, m.puissance - joueur.puissance) * sim.MALUS_PAR_POINT, sim.MALUS_MAX) / 100.0

    def coup(i, pourcent):
        e = etats[i]
        moins = sum(v for v, _ in actif("degats_moins"))
        pa = sum(v for v, _ in actif("force")) * 2 + sum(v for v, _ in actif("pa"))   # valeurs négatives
        brut = alea.uniform(joueur.bas, joueur.haut) + pa / 14.0 * joueur.vitesse - moins
        brut *= pourcent * (1 - malus(e.m)) * (1 + sum(v for v, _ in actif("degats_pct")) / 100.0)
        armure = e.m.armure + sum(v for _, v in e.actifs(e.armure, t))
        d = sim.apres_armure(int(max(0, brut)), max(0, armure), joueur.puissance)
        if alea.random() * 100 < joueur.critique:
            d *= 2
        d = round(d * (1 + sum(v for _, v in e.actifs(e.subis, t)) / 100.0))
        # Ce que le joueur subit en frappant : boucliers de dégâts et effets déclenchés quand on touche le monstre.
        rendu = sum(v for _, v in e.actifs(e.epines, t))
        for x in e.declenche:
            if x[0] > t and x[2] == "subi" and x[4] > 0 and alea.random() < x[3]:
                rendu += x[1]
                x[4] -= 1
        if rendu:
            encaisser(round(rendu * facteur_sorts))
        return d

    def encaisser(d):
        nonlocal rempart, vie_j, subi
        absorbe = min(rempart, d)
        rempart -= absorbe
        rempart = min(rempart + round(absorbe * sim.REMPART_PART), plafond + absorbe)
        reste = d - absorbe
        rempart = min(rempart + round(reste * sim.REMPART_PART), plafond)
        vie_j -= reste
        subi += reste

    def frappe_monstre(i, pourcent=1.0, plus=0.0, sort=False):
        """Coup de mêlée, ou coup d'arme d'un sort (sort : tout le coup suit facteur_sorts, comme EchelleSort au
        serveur ; les bonus fixes des auras du monstre, eux, ne le suivent pas)."""
        e = etats[i]
        bonus = sum(v for _, v in e.actifs(e.plus, t)) + plus
        brut = (alea.randint(e.m.bas, e.m.haut) * (melee if e.principal else 1.0) * pourcent + bonus)             * sim.MONSTRES_DEGATS
        if sort:
            brut *= facteur_sorts
        brut *= 1 + sum(v for _, v in e.actifs(e.pct, t)) / 100.0
        d = sim.apres_armure(round(brut), armure_joueur(), e.m.puissance)
        if alea.random() * 100 < e.m.critique:
            d *= 2
        for x in e.declenche:
            if x[0] > t and x[2] == "porte" and x[4] > 0 and alea.random() < x[3]:
                d += round(x[1] * facteur_sorts)
                x[4] -= 1
        encaisser(d)

    def lancer(i, s):
        """Effet d'un sort de monstre (à la fin de son incantation)."""
        nonlocal etourdi_jusqua
        e = etats[i]
        for genre, qui, v, dure, extra in s["effets"]:
            fin = t + dure
            if genre == "direct":
                d = v * facteur_sorts
                encaisser(sim.apres_armure(round(d * sim.MONSTRES_DEGATS), armure_joueur(), e.m.puissance) if extra
                          else round(d * 2))
            elif genre == "arme":
                frappe_monstre(i, 1.0, v, True)
            elif genre == "arme_pct":
                frappe_monstre(i, v / 100.0, 0.0, True)
            elif genre in ("dot", "drain"):
                cle = (i, s["id"], genre)
                dots[:] = [x for x in dots if x[5] != cle]   # réappliqué : rafraîchi
                dots.append([t + extra, fin, v * facteur_sorts, extra, i if genre == "drain" else None, cle])
            elif genre == "soin":
                cible = min((j for j, x in enumerate(etats) if x.vie > 0), key=lambda j: etats[j].vie / etats[j].m.vie)
                c = etats[cible] if s["evenement"] == ALLIE_BLESSE else e
                c.vie = min(c.m.vie, c.vie + round(v * facteur_sorts))
            elif genre == "hot":
                e.hots.append([t + extra, fin, v * facteur_sorts, extra])
            elif genre == "etourdi":
                etourdi_jusqua = max(etourdi_jusqua, fin)
            elif genre == "degats_plus":
                e.plus.append((fin, v))
            elif genre == "degats_pct" and qui == SOI:
                e.pct.append((fin, v))
            elif genre == "subis_pct" and qui == SOI:
                e.subis.append((fin, v))
            elif genre == "hate_pct" and qui == SOI:
                e.hate.append((fin, v))
            elif genre == "armure" and qui == SOI:
                e.armure.append((fin, v))
            elif genre == "epines":
                e.epines.append((fin, v))
            elif genre == "declenche":
                e.declenche.append([fin, v, extra[0], extra[1], extra[2]])
            elif qui == ENNEMI and genre in ("degats_moins", "degats_pct", "hate_pct", "armure", "armure_pct",
                                             "soins_pct", "force", "pa"):
                cle = (s["id"], genre)
                cumuls = 1
                if cle in debuffs and debuffs[cle][0] > t and genre in ("armure", "armure_pct"):
                    cumuls = min((extra or 1) or 1, debuffs[cle][3] + 1)
                debuffs[cle] = (fin, genre, v, cumuls)

    # Minuteries des sorts ; ceux d'avant le combat (renforcements, renforts) sont déjà là.
    if sorts:
        for i, e in enumerate(etats):
            for n, s in enumerate(e.m.sorts):
                ev, p = s["evenement"], s["p"]
                if ev in (HORS_COMBAT, ALLIE_SANS_BUFF):
                    if alea.random() * 100 < s["chance"]:
                        lancer(i, dict(s, effets=[x for x in s["effets"] if x[0] != "renfort"]))
                elif ev in (ENGAGEMENT, A_DISTANCE):
                    minuteries[(i, n)] = 0.0
                elif ev == EN_COMBAT:
                    minuteries[(i, n)] = alea.uniform(p[0], max(p[0], p[1])) / 1000.0
                elif ev in (VIE_BASSE, ALLIE_BLESSE):
                    minuteries[(i, n)] = 0.0
    for k, v in minuteries.items():
        prochain[("sort",) + k] = v
    prochain["tick"] = None

    def prochain_tick():
        ticks = [x[0] for x in dots] + [h[0] for e in etats for h in e.hots]
        return min(ticks) if ticks else None

    while t < sim.DUREE_MAX:
        prochain["tick"] = prochain_tick()
        t, quoi = min(((v, k) for k, v in prochain.items() if v is not None), key=lambda x: x[0])
        vivants = [i for i, e in enumerate(etats) if e.vie > 0]
        cible = vivants[0]
        degats = {}
        joueur_agit = quoi in ("melee_j", "frappe", "tonnerre", "cri")
        if joueur_agit and t < etourdi_jusqua:
            prochain[quoi] = etourdi_jusqua
            continue
        hate_j = 1 - sum(v for v, _ in actif("hate_pct")) / 100.0   # valeurs négatives : plus lent
        if quoi == "melee_j":
            degats[cible] = coup(cible, 1.0)
            prochain[quoi] = t + joueur.vitesse * max(1.0, hate_j)
        elif quoi == "frappe":
            degats[cible] = coup(cible, 2.0)
            rempart = min(rempart + round(joueur.vie * sim.REMPART_FRAPPE), plafond)
            prochain[quoi] = t + 6.0 + alea.uniform(0, 2 * reaction)
        elif quoi == "tonnerre":
            for i in vivants:
                degats[i] = coup(i, 1.0)
            ralenti_jusqua = t + 10.0
            prochain[quoi] = t + 8.0 + alea.uniform(0, 2 * reaction)
        elif quoi == "cri":
            rempart = min(rempart + round(joueur.vie * sim.REMPART_CRI_DEFI) * len(vivants), plafond)
            prochain[quoi] = t + 12.0 + alea.uniform(0, 2 * reaction)
        elif quoi == "soin":
            soigner_joueur(joueur.vie * potion[2] / 100.0)
            soins_restants -= 1
            prochain[quoi] = t + 1.0 if soins_restants > 0 else None
        elif quoi == "tick":
            for x in list(dots):
                if x[0] <= t:
                    if x[0] <= x[1] + 1e-6:
                        d = round(x[2] * sim.MONSTRES_DUREE)
                        encaisser(d)
                        if x[4] is not None and etats[x[4]].vie > 0:
                            etats[x[4]].vie = min(etats[x[4]].m.vie, etats[x[4]].vie + d)
                    x[0] += x[3]
                    if x[0] > x[1] + 1e-6:
                        dots.remove(x)
            for e in etats:
                for h in list(e.hots):
                    if h[0] <= t:
                        if e.vie > 0:
                            e.vie = min(e.m.vie, e.vie + round(h[2]))
                        h[0] += h[3]
                        if h[0] > h[1] + 1e-6:
                            e.hots.remove(h)
        elif quoi[0] == "melee_m":
            i = quoi[1]
            e = etats[i]
            if t < e.incante_jusqua:
                prochain[quoi] = e.incante_jusqua
                continue
            frappe_monstre(i)
            hate = 1 + sum(v for _, v in e.actifs(e.hate, t)) / 100.0
            prochain[quoi] = t + e.m.vitesse * (1.25 if t < ralenti_jusqua else 1.0) / max(0.2, hate)
        elif quoi[0] == "sort":
            _, i, n = quoi
            e = etats[i]
            s = e.m.sorts[n]
            ev, p = s["evenement"], s["p"]
            pret = True
            if ev == VIE_BASSE and not (p[0] <= 100.0 * e.vie / e.m.vie <= p[1]):
                pret = False
            if ev == ALLIE_BLESSE and not any(x.vie > 0 and x.m.vie - x.vie >= p[0] for x in etats):
                pret = False
            if pret and t < e.incante_jusqua:
                prochain[quoi] = e.incante_jusqua
                continue
            if pret and alea.random() * 100 < s["chance"]:
                if s["incantation"] > 0:
                    e.incante_jusqua = t + s["incantation"]
                    prochain[("fin",) + quoi[1:]] = e.incante_jusqua
                else:
                    lancer(i, s)
                repete = (p[2], p[3]) if ev in (EN_COMBAT, VIE_BASSE, ALLIE_BLESSE) else (0, 0)
                if s["unique"] or ev in (ENGAGEMENT, A_DISTANCE) or repete[1] == 0:
                    prochain[quoi] = None
                else:
                    prochain[quoi] = t + max(0.5, alea.uniform(repete[0], max(repete[0], repete[1])) / 1000.0)
            else:
                prochain[quoi] = t + (0.5 if not pret else max(0.5, alea.uniform(p[2], max(p[2], p[3])) / 1000.0
                                                                if ev == EN_COMBAT else 0.5))
        elif quoi[0] == "fin":
            _, i, n = quoi
            prochain[quoi] = None
            if etats[i].vie > 0:
                lancer(i, etats[i].m.sorts[n])
        if vie_j > 0:
            boire()
        for i, d in degats.items():
            etats[i].vie -= d
            inflige += d
            if etats[i].vie <= 0:
                for k in list(prochain):
                    if isinstance(k, tuple) and len(k) > 1 and k[1] == i:
                        prochain[k] = None
        if all(e.vie <= 0 for e in etats):
            return True, t, max(0, vie_j), inflige, subi
        if vie_j <= 0:
            return False, t, 0, inflige, subi
    return False, t, vie_j, inflige, subi


def simuler(joueur, monstres, n=1000, graine=1, **options):
    alea = random.Random(graine)
    if not isinstance(monstres, list):
        monstres = [monstres]
    r = [combat_sorts(joueur, monstres, alea, **options) for _ in range(n)]
    sortie = sim.resumer(r, joueur, n)
    sortie["subi"] = sum(x[4] for x in r) / n
    return sortie


def decrire(m):
    lignes = []
    for s in m.sorts:
        lignes.append("  %6d ev%d %s inc %.1fs : %s" % (s["id"], s["evenement"], s["p"], s["incantation"], ", ".join(
            "%s %s %.1f%s" % (g, q, v, (" %.0fs" % d) if d else "") for g, q, v, d, _ in s["effets"])))
    for r in m.renforts:
        lignes.append("  renfort : %s" % r)
    return "\n".join(lignes)


def verifier():
    """Sans sorts, contre un seul monstre : mêmes chiffres que simulation_combat.combat() (à quelques % près : les
    dés ne tombent pas dans le même ordre)."""
    import simulation_camp as camp
    j = camp.repos(max(camp.fiches(), key=lambda f: f.puissance), 5)
    ecart = 0.0
    for entree in (3125, 3099, 3122, 3123, 3110):
        m = sim.monstre_depuis_base(entree)
        a = sim.simuler(j, m, 1000, potion=(2, 35, 1, 10))
        b = simuler(j, m, 1000, sorts=False, potion=(2, 35, 1, 10))
        e = abs(a["dps_monstre"] - b["dps_monstre"]) / max(0.01, a["dps_monstre"])
        ecart = max(ecart, e)
        print("%-30s victoire %5.1f / %5.1f  dps monstre %.2f / %.2f  durée %.1f / %.1f" % (
            m.nom, a["victoire"], b["victoire"], a["dps_monstre"], b["dps_monstre"], a["duree"], b["duree"]))
    print("écart maximal du dps des monstres : %.0f %%" % (100 * ecart))
    return ecart < 0.08


if __name__ == "__main__":
    a = argparse.ArgumentParser()
    a.add_argument("--monstre", type=int)
    a.add_argument("--verifier", action="store_true")
    o = a.parse_args()
    if o.verifier:
        sys.exit(0 if verifier() else 1)
    if o.monstre:
        import simulation_camp as camp
        j = camp.repos(max(camp.fiches(), key=lambda f: f.puissance), 5)
        m = monstre_avec_sorts(o.monstre)
        print(m)
        print(decrire(m))
        print("sans sorts :", sim.rapport(j, m, simuler(j, m, sorts=False, potion=(2, 35, 1, 10))))
        print("avec sorts :", sim.rapport(j, m, simuler(j, m, potion=(2, 35, 1, 10))))
