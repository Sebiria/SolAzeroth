"""v3, lot D4 (02/11/2026) : simulation du démoniste Affliction, pour calibrer ses parts de puissance d'attaque et ses
invocations sur les cibles du guerrier (mêmes monstres, mêmes pièces du monde, en tissu).

Règles reprises du serveur (v3_demoniste.cpp, demoniste_v3.py, v3_combat.cpp) et de simulation_combat.py :
- aucun dégât d'arme, aucune attaque automatique ; chaque sort fait sa part de la PA (spell_bonus_data) ; sorts
  magiques : sans armure, critique des sorts ×1,5 sur les coups directs seulement ; malus face à un monstre plus fort ;
- PA : 1 × 3 + 2 × Intelligence − 20 (v3_niveau.cpp), plus la PA des pièces ; vie : base de la classe, 1 par point
  d'Endurance jusqu'à 20, 10 au-delà ; caractéristiques de base du niveau 1 (orc démoniste) ;
- on s'arrête pour incanter et canaliser (choix de l'utilisateur, lot D4) : le démoniste reste sur place, ouvre à 30 m,
  et le monstre arrive à sa vitesse de course (speed_run × 7 m/s). Chaque coup reçu retarde une incantation de 0,5 s
  et retire 25 % de sa durée à une canalisation, deux fois au plus (Spell::Delayed, DelayedChannel) ;
- recharge globale 0,75 s ; délai de réaction tiré entre 0 et 2 × reaction après chaque recharge, comme le guerrier ;
- Moisson : 25 % des dégâts sur la durée rendus en vie ; Drain de vie rend aussi ses dégâts ; Agonie par tiers
  (×0,5, ×1, ×1,5) ;
- Diablotin (15 s) : Trait de feu toutes les 2 s, sans être attaqué. Marcheur du Vide (10 s) : provoque les monstres à
  15 m, qui le frappent ; sa vie est celle du démoniste × PART_MARCHEUR, son armure la sienne ;
- arme (v3_niveau.cpp) : elle ne frappe pas ; ses dégâts par seconde × 14 s'ajoutent à la PA ;
- Transe de l'ombre : chaque tic de Corruption ou d'Agonie a CHANCE_TRANSE de rendre le prochain Trait instantané ;
- Peur (6 s) : brisée quand le monstre a perdu SEUIL_PEUR de sa vie maximale depuis qu'il fuit (v3_demoniste.cpp ;
  le moteur prenait 1/4,75 de la vie d'un guerrier du niveau du lanceur, 80 : jamais atteint) ; le monstre revient en
  RETOUR_PEUR × le temps de fuite (il fuit en zigzag, pas en ligne droite : supposé).
- potion (lot D5) : comme simulation_combat.py, bue sous SEUIL_POTION de la vie, rang 2 avec son soin sur la durée.
Le cas « je recule en posant Corruption et Agonie » n'est pas simulé : il est lent, et la référence est le combat où
l'on s'arrête pour incanter.

py simulation_demoniste.py      (rapport : démoniste et guerrier côte à côte, seul puis en groupe)
py simulation_demoniste.py --gouffre   (lot D5 : Gouffre de Ragefeu par difficulté, puis rares secrets en bleu)
"""
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import demoniste_v3 as d3
import equipement_v3 as e3
import simulation_combat as sim
import tests_equilibrage as te

# Orc démoniste, niveau 1 (player_class_stats au niveau 80 + player_race_stats) : vie 23, Endurance 22, Intelligence
# 19, Agilité 17 (2 d'armure par point).
VIE_BASE, ENDURANCE_BASE, INTELLIGENCE_BASE, AGILITE_BASE = 23, 22, 19, 17
CRITIQUE_SORTS = 1.8                # base de la classe et Intelligence au niveau 80 (%)
PORTEE, CONTACT = 30.0, 2.0
VITESSE_COURSE = 7.0
GCD, INCANTATION = 0.75, 1.5
RETARD, RETARDS_MAX = 0.5, 2
RETOUR_PEUR = 0.5
SEUIL_PEUR = 0.15
CHANCE_TRANSE = 0.10
PART_MARCHEUR = 1.0                 # v3_demoniste.cpp
PART_MOISSON = 0.25                  # v3_demoniste.cpp
# Recharges (demoniste_v3.py) et durées des invocations (v3_demoniste.cpp), en s.
RECHARGES = {"marcheur": 60.0, "diablotin": 30.0, "peur": 20.0, "drain": 10.0}
DUREES = {"marcheur": 10.0, "diablotin": 15.0}
DUREE_MAX = 180.0
CHARGE = 51756                      # rares_secrets_v3.py
ENTRE = 20.0                        # entre deux combats (butin, marche) : les recharges continuent

# Kits : techniques apprises (ordre de v3_kit.cpp).
VALLEE = ("trait", "corruption", "diablotin", "drain", "peur")
DUROTAR = VALLEE + ("marcheur", "agonie")


def parts():
    """Parts de PA de demoniste_v3.BONUS : (direct, par tic)."""
    b = d3.BONUS
    return {"trait": b[d3.TRAIT][0], "corruption": b[d3.CORRUPTION][1], "agonie": b[d3.AGONIE][1],
            "drain": b[d3.DRAIN_DE_VIE][1], "feu": b[d3.TRAIT_DE_FEU][0]}


class Demoniste:
    def __init__(self, nom, vie, armure, pa, puissance):
        self.nom, self.vie, self.armure, self.pa, self.puissance = nom, vie, armure, pa, puissance


def stats(entree):
    l = sim.sql("SELECT class, subclass, InventoryType, armor, ItemLevel, %s FROM acore_world.item_template WHERE entry = %d"
                % (", ".join("stat_type%d, stat_value%d" % (i, i) for i in range(1, 11)), entree))[0]
    s = {}
    for i in range(10):
        t, v = int(l[5 + 2 * i]), int(l[6 + 2 * i])
        s[t] = s.get(t, 0) + v
    return {"classe": int(l[0]), "sous": int(l[1]), "type": int(l[2]), "armure": int(l[3]), "niveau": int(l[4]),
            "pa": s.get(38, 0) + 2 * s.get(5, 0), "endurance": s.get(7, 0)}


def portable(o):
    """Ce que le démoniste porte : tissu, cape, bijoux et armes (pas de bouclier ni de maille)."""
    if o["classe"] == 4:
        return o["sous"] in (0, 1) or o["type"] == 16
    return True


def demoniste(objets, guid, nom="démoniste", repas=0, vie_enchant=0, armure_enchant=0):
    """Démoniste portant l'équipement du personnage, ces pièces à la place, tout en version tissu (table
    solazeroth_v3_conversions)."""
    versions = dict((int(a), int(b)) for a, b in sim.sql("SELECT origine, version FROM acore_world.solazeroth_v3_conversions"))
    portes = dict(sim.porte(guid))
    for e in objets:
        portes[sim.objet(e)["emplacement"]] = e
    armure, pa, endurance, niveaux = AGILITE_BASE * 2 + armure_enchant, 0, ENDURANCE_BASE, []
    for slot, e in portes.items():
        o = stats(versions.get(e, e))
        if not portable(o):
            # Pièce fabriquée : le démoniste porte celle de tissu de même puissance (même barème, armure du tissu), et
            # un orbe sans armure à la place d'un bouclier.
            o["armure"] = round(o["armure"] * e3.ARMURE_PANOPLIE[1] / e3.ARMURE_PANOPLIE[3]) if o["sous"] == 3 else 0
        armure += o["armure"]
        pa += o["pa"]
        endurance += o["endurance"]
        if slot not in (3, 18):
            niveaux.append(o["niveau"])
    vie = VIE_BASE + min(endurance, 20) + 10 * max(0, endurance - 20) + vie_enchant
    pa += max(0, 3 + 2 * (INTELLIGENCE_BASE + repas) - 20)
    if 15 in portes:
        arme = sim.objet(portes[15])
        pa += round((arme["bas"] + arme["haut"]) / 2 / arme["vitesse"] * 14)
    puissance = round(sum(niveaux) / len(niveaux), 1) if niveaux else 1
    return Demoniste(nom, vie, armure, pa, puissance)


def vitesse(entree):
    return float(sim.sql("SELECT speed_run FROM acore_world.creature_template WHERE entry = %d" % entree)[0][0]) * VITESSE_COURSE


def combat(j, monstres, alea, kit=DUROTAR, reaction=1.4, p=None, recharges=None, potion=None):
    """Un combat contre des monstres arrivés ensemble ; renvoie (victoire, durée, vie restante, infligés, subis).
    recharges : temps restant de chaque recharge au début du combat, mis à jour pour le combat suivant."""
    p = p or parts()
    n = len(monstres)
    vies = [m.vie for m in monstres]
    malus = [min(max(0.0, m.puissance - j.puissance) * sim.MALUS_PAR_POINT, sim.MALUS_MAX) / 100.0 for m in monstres]
    arrivee = [(PORTEE - CONTACT) / m.course for m in monstres]
    coup_m = [arrivee[i] + monstres[i].vitesse * alea.uniform(0.3, 1.0) for i in range(n)]
    peur_debut, peur_jusqua, peur_degats = [-1.0] * n, [-1.0] * n, [0] * n
    corruption, agonie = [[] for _ in range(n)], [[] for _ in range(n)]   # tics à venir : (temps, dégâts)
    recharges = recharges if recharges is not None else {}
    pret = {s: recharges.get(s, 0.0) for s in kit}

    def terminer(*resultat):
        for s in kit:
            recharges[s] = max(0.0, pret[s] - resultat[1] - ENTRE)
        return resultat
    vie, t, libre = j.vie, 0.0, 0.0
    marcheur_jusqua, vie_marcheur = -1.0, 0
    diablotin_jusqua, feu = -1.0, None
    transe = False
    drain = None                              # (cible, tics restants, prochain tic, intervalle)
    incantation = None                        # (sort, cible, fin, retards)
    inflige = subi = 0
    charges, potion_prete, soins, soin = (potion[0] if potion else 0), 0.0, 0, None

    def boire():
        nonlocal vie, charges, potion_prete, soins, soin
        if charges and t >= potion_prete and vie < j.vie * sim.SEUIL_POTION:
            vie = min(j.vie, vie + round(j.vie * potion[1] / 100.0))
            charges -= 1
            potion_prete = t + sim.RECHARGE_POTION
            if potion[2]:
                soins, soin = potion[3], t + 1.0

    def vivants():
        return [i for i in range(n) if vies[i] > 0]

    def frapper(i, part, direct):
        nonlocal inflige
        if vies[i] <= 0:
            return 0
        dg = j.pa * part * (1 - malus[i])
        if direct and alea.random() * 100 < CRITIQUE_SORTS:
            dg *= 1.5
        dg = max(1, round(dg))
        vies[i] -= dg
        inflige += dg
        if peur_jusqua[i] > t:
            peur_degats[i] += dg
            if peur_degats[i] >= SEUIL_PEUR * monstres[i].vie:
                peur_jusqua[i] = t
                coup_m[i] = min(coup_m[i], retour(i))
        return dg

    def retour(i):
        """Fin de la peur, plus le retour du monstre."""
        return peur_jusqua[i] + (peur_jusqua[i] - peur_debut[i]) * RETOUR_PEUR

    def soigner(x):
        nonlocal vie
        vie = min(j.vie, vie + x)

    def au_contact(i):
        return t >= arrivee[i] and t >= retour(i)

    while t < DUREE_MAX:
        cibles = vivants()
        if not cibles:
            return terminer(True, t, vie, inflige, subi)
        c = cibles[0]
        # Prochain événement : action du démoniste, coups des monstres, tics.
        evenements = [(libre, "agir")]
        if incantation:
            evenements.append((incantation[2], "fin"))
        if drain:
            evenements.append((drain[2], "drain"))
        if feu is not None:
            evenements.append((feu, "feu"))
        if soin is not None:
            evenements.append((soin, "soin"))
        for i in cibles:
            evenements.append((coup_m[i], ("coup", i)))
            if corruption[i]:
                evenements.append((corruption[i][0][0], ("corruption", i)))
            if agonie[i]:
                evenements.append((agonie[i][0][0], ("agonie", i)))
        t, quoi = min(evenements, key=lambda e: e[0])
        if t >= DUREE_MAX:
            break
        if isinstance(quoi, tuple) and quoi[0] == "coup":
            i = quoi[1]
            m = monstres[i]
            if t < retour(i):
                coup_m[i] = retour(i)
                continue
            coup_m[i] = t + m.vitesse
            brut = round(alea.randint(m.bas, m.haut) * sim.MONSTRES_DEGATS)
            if t < marcheur_jusqua and vie_marcheur > 0:
                vie_marcheur -= sim.apres_armure(brut, j.armure, m.puissance)
                if vie_marcheur <= 0:
                    marcheur_jusqua = t
                continue
            dg = sim.apres_armure(brut, j.armure, m.puissance)
            if alea.random() * 100 < m.critique:
                dg *= 2
            vie -= dg
            subi += dg
            if vie <= 0:
                return terminer(False, t, 0, inflige, subi)
            boire()
            # Le coup retarde l'incantation ou écourte la canalisation.
            if incantation and incantation[3] < RETARDS_MAX:
                s, ci, fin, r = incantation
                incantation = (s, ci, fin + RETARD, r + 1)
            elif drain and drain[4] < RETARDS_MAX:
                ci, reste, prochain, pas, r = drain
                drain = (ci, max(0, reste - 1.25), prochain, pas, r + 1)
                if drain[1] < 1:
                    drain = None
                    libre = t
            continue
        if isinstance(quoi, tuple):
            genre, i = quoi
            liste = corruption[i] if genre == "corruption" else agonie[i]
            _, part = liste.pop(0)
            soigner(round(frapper(i, part, False) * PART_MOISSON))
            if alea.random() < CHANCE_TRANSE:
                transe = True
            continue
        if quoi == "soin":
            soigner(round(j.vie * potion[2] / 100.0))
            soins -= 1
            soin = t + 1.0 if soins > 0 else None
            continue
        if quoi == "feu":
            frapper(c, p["feu"], True)
            feu = t + 2.0 if t + 2.0 <= diablotin_jusqua else None
            continue
        if quoi == "drain":
            ci, reste, _, pas, r = drain
            dg = frapper(ci, p["drain"], False)
            soigner(dg + round(dg * PART_MOISSON))
            reste -= 1
            drain = (ci, reste, t + pas, pas, r) if reste >= 1 and vies[ci] > 0 else None
            if not drain:
                libre = t
            continue
        if quoi == "fin":
            s, ci, _, _ = incantation
            incantation = None
            if s == "trait":
                frapper(ci, p["trait"], True)
            elif s == "peur" and vies[ci] > 0:
                peur_debut[ci], peur_jusqua[ci], peur_degats[ci] = t, t + 6.0, 0
                coup_m[ci] = max(coup_m[ci], retour(ci))
            libre = t
            continue
        # Agir : le démoniste choisit, s'il n'incante ni ne canalise.
        if incantation or drain:
            libre = DUREE_MAX + 1        # attend la fin de l'incantation ou de la canalisation
            continue
        contact = [i for i in cibles if au_contact(i)]

        def lancer(s):
            return s in pret and t >= pret[s]

        action = None
        if lancer("marcheur") and contact and marcheur_jusqua < t:
            action = "marcheur"
        elif lancer("diablotin") and diablotin_jusqua < t:
            action = "diablotin"
        else:
            sans_corruption = [i for i in cibles if not corruption[i]]
            sans_agonie = [i for i in cibles if not agonie[i]]
            if lancer("corruption") and sans_corruption:
                action = ("corruption", sans_corruption[0])
            elif lancer("agonie") and sans_agonie:
                action = ("agonie", sans_agonie[0])
            elif lancer("peur") and contact and marcheur_jusqua < t:
                # En groupe : sur un autre monstre que la cible.
                action = ("peur", next((i for i in contact if i != c), c))
            elif lancer("drain"):
                action = "drain"
            elif lancer("trait"):
                action = "trait"
        if action is None:
            libre = t + 0.1
            continue
        if action == "marcheur":
            marcheur_jusqua, vie_marcheur = t + DUREES["marcheur"], round(j.vie * PART_MARCHEUR)
            for i in contact:
                coup_m[i] = max(coup_m[i], t + 0.5)
            pret["marcheur"] = t + RECHARGES["marcheur"] + alea.uniform(0, 2 * reaction)
            libre = t + GCD
        elif action == "diablotin":
            diablotin_jusqua, feu = t + DUREES["diablotin"], t + 1.0
            pret["diablotin"] = t + RECHARGES["diablotin"] + alea.uniform(0, 2 * reaction)
            libre = t + GCD
        elif isinstance(action, tuple) and action[0] == "peur":
            incantation = ("peur", action[1], t + INCANTATION, 0)
            pret["peur"] = t + RECHARGES["peur"] + alea.uniform(0, 2 * reaction)
            libre = DUREE_MAX + 1
        elif isinstance(action, tuple):
            s, i = action
            if s == "corruption":
                corruption[i] = [(t + 3.0 * k, p["corruption"]) for k in range(1, 6)]
            else:
                agonie[i] = [(t + 2.0 * k, p["agonie"] * (0.5 if k <= 4 else 1.0 if k <= 8 else 1.5)) for k in range(1, 13)]
            libre = t + GCD
        elif action == "drain":
            drain = (c, 5, t + 1.0, 1.0, 0)
            pret["drain"] = t + RECHARGES["drain"] + alea.uniform(0, 2 * reaction)
            libre = DUREE_MAX + 1
        else:
            if action == "trait" and transe:
                transe = False
                frapper(c, p["trait"], True)
                libre = t + GCD
                continue
            incantation = (action, c, t + INCANTATION, 0)
            libre = DUREE_MAX + 1
    return terminer(False, t, vie, inflige, subi)


def simuler(j, monstres, n=1000, graine=1, **options):
    """Combats enchaînés : les longues recharges (invocations) ne sont pas prêtes à chaque combat."""
    alea = random.Random(graine)
    recharges = {}
    return sim.resumer([combat(j, monstres, alea, recharges=recharges, **options) for _ in range(n)], j, n)


def monstre(entree, niveau):
    m = sim.monstre_depuis_base(entree, niveau)
    m.course = vitesse(entree)
    return m


def rapport(kits=None):
    fiches = (sim.au_present(c) for chemin in list(reversed(te.journaux())) + [te.REFERENCE]
              for c in reversed(sim.lire_journal(chemin)) if c["joueur"])
    guerrier = next(fiches)
    guid = int(sim.sql("SELECT guid FROM acore_characters.characters WHERE name = '%s'" % guerrier.nom)[0][0])
    monstres = [monstre(e, n) for e, n in te.MONSTRES]
    panoplies = {nom: o for nom, o in te.PANOPLIES.items() if "fabriquée" not in nom}
    resultats = []
    for nom, objets in panoplies.items():
        g = sim.equiper(guerrier, objets, guid)
        dm = demoniste(objets, guid)
        kit = VALLEE if "vallée" in nom else DUROTAR
        print("\n%s : démoniste puissance %.1f, vie %d, armure %d, PA %d ; guerrier vie %d, armure %d" % (
            nom, dm.puissance, dm.vie, dm.armure, dm.pa, g.vie, g.armure))
        for m in monstres:
            rd = simuler(dm, [m], 1000, kit=kit)
            rg = sim.simuler(g, m, 1000)
            print("  %-26s P%-2d %4.1f m/s | démoniste %5.1f %% %5.1f s vie %5.1f %% | guerrier %5.1f %% %5.1f s vie %5.1f %%%s"
                  % (m.nom[:26], m.puissance, m.course, rd["victoire"], rd["duree"], rd["vie_restante"],
                     rg["victoire"], rg["duree"], rg["vie_restante"], te.verdict(g, m, rd)))
            if abs(m.puissance - g.puissance) <= 2:
                resultats.append((rd, rg))
        for taille in (2, 3):
            proches = [m for m in monstres if abs(m.puissance - dm.puissance) <= 1][:1]
            if not proches:
                continue
            groupe = [proches[0]] * taille
            rd = simuler(dm, groupe, 400, kit=kit)
            rg = sim.simuler_groupe(g, groupe, 400)
            print("  groupe de %d %-14s P%-2d        | démoniste %5.1f %% %5.1f s vie %5.1f %% | guerrier %5.1f %% %5.1f s vie %5.1f %%"
                  % (taille, proches[0].nom[:14], proches[0].puissance, rd["victoire"], rd["duree"], rd["vie_restante"],
                     rg["victoire"], rg["duree"], rg["vie_restante"]))
    return resultats


def renforce(dm, rangs=0, repos=True):
    """Le démoniste avec des rangs d'objet (+10 % par rang, comme simulation_modes.rangs) et le Repos du feu (vie
    +5 %, dégâts +10 % ; les 5 d'Intelligence sont donnés par demoniste(repas=5))."""
    f = 1 + 0.1 * rangs
    vie, pa = round(dm.vie * f), dm.pa * f
    if repos:
        vie, pa = round(vie * 1.05), pa * 1.10
    return Demoniste(dm.nom, vie, round(dm.armure * f), pa, dm.puissance * f)


def gouffre():
    """Lot D5 : le Gouffre de Ragefeu (élite et dernier boss, difficultés 1 à 5, potion F7, Repos) et les rares
    secrets (tout en bleu du Gouffre), démoniste contre guerrier aux mêmes pièces."""
    import simulation_camp as camp
    import simulation_donjons as donjons
    import simulation_modes as modes
    import rares_secrets_v3 as rares
    fiches = (sim.au_present(c) for chemin in list(reversed(te.journaux())) + [te.REFERENCE]
              for c in reversed(sim.lire_journal(chemin)) if c["joueur"])
    guerrier = next(fiches)
    guid = int(sim.sql("SELECT guid FROM acore_characters.characters WHERE name = '%s'" % guerrier.nom)[0][0])
    n = donjons.N
    for titre, objets in (("fin de Durotar (quêtes)", te.PANOPLIES["fin de Durotar (quêtes)"]),
                          ("tout en bleu du Gouffre", rares.GOUFFRE)):
        g0 = sim.equiper(guerrier, objets, guid)
        d0 = demoniste(objets, guid, repas=5)
        print("\nGouffre, %s : victoires (%%) démoniste / guerrier, contre le Massacreur (élite) puis Taragaman (boss)"
              % titre)
        print("   %-18s %s" % ("", "   ".join("diff. %d        " % d for d in range(1, 6))))
        for r in (0, 2, 4):
            g, dm = camp.repos(modes.rangs(g0, r), 5), renforce(d0, r)
            cases = []
            for diff in range(1, 6):
                paire = []
                for entree in (donjons.ELITE, donjons.BOSS):
                    if diff == 1:
                        m = sim.monstre_depuis_base(entree)
                    else:
                        ecart, facteur, techniques = donjons.DIFFICULTES[diff]
                        m = modes.renforcer(sim.monstre_depuis_base(entree, modes.puissance_visee(g0, ecart, entree)),
                                            facteur, 1 + donjons.TECHNIQUE * techniques)
                    m.course = vitesse(entree)
                    rd = simuler(dm, [m], n, potion=donjons.POTION_F7)
                    rg = sim.simuler(g, m, n, potion=donjons.POTION_F7)
                    paire.append("%3.0f/%3.0f" % (rd["victoire"], rg["victoire"]))
                cases.append(" ".join(paire))
            print("   %-18s %s" % ("+ %d rangs d'objet" % r, "   ".join(cases)))
    import simulation_lot4c as lot4c
    g, b = rares.fiche()
    dm = renforce(demoniste(rares.GOUFFRE, guid, repas=5))
    # Bonus du défi (repas, consommables, critique), approchés pour le démoniste : vie et armure sur la fiche, dégâts
    # subis sur la vie, dégâts infligés, critique (×1,5) et hâte sur la PA ; le vol de vie est ignoré (Moisson).
    db = Demoniste(dm.nom, round(dm.vie * b.get("vie", 1.0) / b.get("subis", 1.0)), round(dm.armure * b.get("armure", 1.0)),
                   dm.pa * b.get("inflige", 1.0) * (1 + b.get("critique", 0.0) * 0.5 / 100) * (1 + b.get("hate", 0.0)),
                   dm.puissance)
    print("\nRares secrets (réglés en jeu, puissance %d), tout en bleu du Gouffre, Repos, potion F7 : victoires (%%) "
          "sans / avec les autres bonus" % rares.PUISSANCE_RARE)
    for entree, origine, nom, _, _, _, _, techniques, *_ in rares.RARES:
        m = sim.monstre_depuis_base(entree, rares.PUISSANCE_RARE)
        # Une Charge à l'entrée en combat (Hurlevague) le met au contact tout de suite.
        m.course = 1000.0 if any(e == 4 and sort == CHARGE for e, _, _, sort, *_ in techniques) else vitesse(entree)
        print("   %-24s vie %5d | démoniste %5.1f / %5.1f | guerrier %5.1f / %5.1f"
              % (nom, m.vie, simuler(dm, [m], n, potion=donjons.POTION_F7)["victoire"],
                 simuler(db, [m], n, potion=donjons.POTION_F7)["victoire"],
                 sim.simuler(g, m, n, potion=donjons.POTION_F7)["victoire"], lot4c.essai(g, m, b)))


if __name__ == "__main__":
    gouffre() if "--gouffre" in sys.argv else rapport()
