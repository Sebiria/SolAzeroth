"""v3, lot V4 (02/11/2026) : simulation du voleur Assassinat, pour calibrer son kit sur les cibles du guerrier (mêmes
monstres, mêmes pièces du monde, en cuir et en dagues : table solazeroth_v3_versions).

Règles reprises du serveur (voleur_v3.py, v3_voleur.cpp, v3_combat.cpp) et de simulation_combat.py :
- tout coup porte (v3_combat.cpp) ; critique ×2 après l'armure ; malus face à un monstre plus fort ;
- PA : 1 × 3 + 2 × Agilité − 20 (v3_niveau.cpp), plus la PA des pièces ; les dégâts de chaque dague gagnent PA / 14 ×
  sa vitesse (règle du moteur) ; la main gauche frappe à moitié ; vie : base de la classe, 1 par point d'Endurance
  jusqu'à 20, 10 au-delà ; caractéristiques de base du niveau 1 (orc voleur) ;
- deux attaques automatiques, chacune à sa vitesse ; recharge globale 0,75 s et délai de réaction tiré entre 0 et
  2 × reaction après chaque recharge, comme le guerrier ;
- Toxines : chaque coup de mêlée (automatique ou technique) a CHANCE_TOXINES de poser un cumul de Poison mortel
  (5 au plus, 12 s, rafraîchis à chaque cumul) ; tic toutes les 3 s, sa part de PA par cumul, sans armure ; chaque
  cumul retire AFFAIBLISSEMENT aux dégâts du monstre ;
- Estropier (6 s) : un coup par main, un cumul sûr ; Envenimer : consomme les cumuls quand il y en a 5 ;
- Durotar : Évasion (−50 % de dégâts subis 6 s, sous la moitié de la vie), Coup bas (étourdit 4 s, dès le début et à
  chaque recharge), Rupture entretenue (zone 4), Éventail de couteaux dès deux monstres (Durotar, lot V6), et
  l'ouverture camouflée (Garrot) ;
- potion et passifs : mêmes clés que simulation_combat.combat.
Contre un groupe : les coups vont au premier monstre en vie, les monstres frappent tous, Coup bas en étourdit un.

py simulation_voleur.py             (rapport : voleur et guerrier côte à côte, seul puis en groupe)
py simulation_voleur.py --gouffre   (Gouffre de Ragefeu par difficulté, puis rares secrets en bleu)
py simulation_voleur.py --passifs   (gain de chaque passif, voleur et guerrier)
py simulation_voleur.py --tarides   (lot T1 : fiches des Tarides contre les monstres des secteurs)
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import equipement_v3 as e3
import simulation_combat as sim
import tests_equilibrage as te
import voleur_v3 as v3

# Orc voleur, niveau 1 (player_class_stats au niveau 80 + player_race_stats) : vie 25, Endurance 22, Agilité 20.
VIE_BASE, ENDURANCE_BASE, AGILITE_BASE = 25, 22, 20
VOLEUR = 4
GCD = 0.75
DUREE_MAX = 180.0
ENTRE = 20.0                        # entre deux combats : les recharges continuent
R = {k: v / 1000.0 for k, v in v3.RECHARGES.items()}
DUREE_POISON, TIC_POISON = 12.0, 3.0
DUREE_RUPTURE, TIC_RUPTURE, DUREE_GARROT, TIC_GARROT = 12.0, 2.0, 18.0, 3.0
VALLEE = ("estropier", "envenimer", "coup_de_pied", "evasion")
DUROTAR = VALLEE + ("camouflage", "coup_bas", "eventail")


class Voleur:
    def __init__(self, nom, vie, armure, pa, puissance, main, gauche, critique):
        self.nom, self.vie, self.armure, self.pa, self.puissance = nom, vie, armure, pa, puissance
        self.main, self.gauche, self.critique = main, gauche, critique   # (bas, haut, vitesse) avec la PA

    def __repr__(self):
        return "%s : puissance %.1f, vie %d, armure %d, PA %d, dagues %s / %s" % (
            self.nom, self.puissance, self.vie, self.armure, self.pa, self.main, self.gauche)


def stats(entree):
    o = sim.objet(entree)
    if entree in sim.VIRTUELS:
        return o
    l = sim.sql("SELECT class, subclass FROM acore_world.item_template WHERE entry = %d" % entree)[0]
    o["classe"], o["sous"] = int(l[0]), int(l[1])
    return o


def voleur(objets, guid, critique, nom="voleur", repas=0):
    """Voleur portant l'équipement du personnage, ces pièces à la place, en cuir et en dagues (versions du voleur)."""
    versions = dict((int(a), int(b)) for a, b in sim.sql(
        "SELECT origine, version FROM acore_world.solazeroth_v3_versions WHERE classe = %d" % VOLEUR))
    portes = dict(sim.porte(guid))
    for e in objets:
        portes[sim.objet(e)["emplacement"]] = e
    armure, pa, endurance, niveaux, armes = AGILITE_BASE * 2, 0, ENDURANCE_BASE, [], {}
    for slot, e in portes.items():
        o = stats(versions.get(e, e))
        if o["classe"] == 4 and o["sous"] == 3:
            # Pièce de maille fabriquée : le voleur porte celle de cuir de même puissance (armure du cuir).
            o["armure"] = round(o["armure"] * e3.ARMURE_PANOPLIE[2] / e3.ARMURE_PANOPLIE[3])
        if o["classe"] == 4 and o["sous"] == 6:
            o = stats(portes[15]) if 15 in portes else o     # bouclier fabriqué : une seconde dague
        armure += o["armure"]
        pa += o["pa"]
        endurance += o["endurance"]
        if o["classe"] == 2:
            armes[slot] = o
        if slot not in (3, 18):
            niveaux.append(o["niveau"])
    vie = VIE_BASE + min(endurance, 20) + 10 * max(0, endurance - 20)
    pa += max(0, 3 + 2 * (AGILITE_BASE + repas) - 20)
    main = armes.get(15) or {"bas": 1, "haut": 2, "vitesse": 2.0}
    gauche = armes[16] if 16 in armes and armes[16]["sous"] == 15 else main   # sinon, une seconde dague
    dague = lambda a, f: (f * (a["bas"] + pa / 14 * a["vitesse"]), f * (a["haut"] + pa / 14 * a["vitesse"]), a["vitesse"])
    puissance = round(sum(niveaux) / len(niveaux), 1) if niveaux else 1
    return Voleur(nom, vie, armure, pa, puissance, dague(main, 1.0), dague(gauche, 0.5), critique)


def renforce(v, rangs=0, repos=True):
    """Rangs d'objet (+10 % par rang) et Repos du feu (vie +5 %, dégâts +10 % ; l'Agilité vient de voleur(repas=5))."""
    f = 1 + 0.1 * rangs
    g = f * (1.10 if repos else 1.0)
    arme = lambda a: (a[0] * g, a[1] * g, a[2])
    vie = round(v.vie * f * (1.05 if repos else 1.0))
    return Voleur(v.nom, vie, round(v.armure * f), v.pa * g, v.puissance * f, arme(v.main), arme(v.gauche), v.critique)


def combat(j, monstres, alea, kit=DUROTAR, reaction=1.4, recharges=None, potion=None, passifs=None):
    """Un combat ; renvoie (victoire, durée, vie restante, dégâts infligés, dégâts subis)."""
    p = passifs or {}
    rf = p.get("recharge", 1.0)
    vies = [m.vie for m in monstres]
    cumuls = [0] * len(monstres)
    fin_poison = [-1.0] * len(monstres)
    etourdi = [-1.0] * len(monstres)
    rupture, garrot = [-1.0] * len(monstres), [-1.0] * len(monstres)
    vie_j = j.vie
    t = 0.0
    malus = [min(max(0.0, m.puissance - j.puissance) * sim.MALUS_PAR_POINT, sim.MALUS_MAX) / 100.0 for m in monstres]
    pret = dict(recharges or {})
    for k in list(pret):
        pret[k] -= ENTRE
    evasion = -1.0
    inflige = subi = 0
    souffle_pris = False
    charges, potion_prete, soins = (potion[0] if potion else 0), 0.0, 0
    prochain = {"main": 0.1, "gauche": 0.2, "gcd": 0.0, "tic": TIC_POISON, "saigne": TIC_RUPTURE}
    for i, m in enumerate(monstres):
        prochain["m%d" % i] = m.vitesse
        if m.poison:
            prochain["v%d" % i] = m.poison[2]

    def cible():
        return next((i for i, v in enumerate(vies) if v > 0), None)

    def facteur(i):
        f = p.get("inflige", 1.0)
        if "bourreau" in p and vies[i] < monstres[i].vie * p["bourreau"][0]:
            f += p["bourreau"][1]
        if "premier" in p and vies[i] > monstres[i].vie * p["premier"][0]:
            f += p["premier"][1]
        return f

    def coup(i, arme, pourcent, toxines=True):
        d = alea.uniform(arme[0], arme[1]) * pourcent * (1 - malus[i])
        d = sim.apres_armure(int(d), monstres[i].armure, j.puissance)
        if alea.random() * 100 < j.critique:
            d *= 2
        if toxines and alea.random() * 100 < v3.CHANCE_TOXINES:
            poser(i)
        return round(d * facteur(i))

    def poser(i, n=1):
        cumuls[i] = min(v3.CUMULS_MAX, cumuls[i] + n)
        fin_poison[i] = t + DUREE_POISON

    def blesser(i, d):
        nonlocal inflige, vie_j
        d = min(d, max(0, vies[i]))
        vies[i] -= d
        inflige += d
        if d > 0 and "vol" in p:
            vie_j = min(j.vie, vie_j + round(d * p["vol"]))

    def encaisser(d):
        nonlocal vie_j, subi, souffle_pris
        d = round(d * p.get("subis", 1.0) * (0.5 if t < evasion else 1.0))
        vie_j -= d
        subi += d
        if "souffle" in p and not souffle_pris and 0 < vie_j < j.vie * p["souffle"][0]:
            souffle_pris = True
            vie_j = min(j.vie, vie_j + round(j.vie * p["souffle"][1]))

    def boire():
        nonlocal vie_j, charges, potion_prete, soins
        if charges and t >= potion_prete and vie_j < j.vie * sim.SEUIL_POTION:
            vie_j = min(j.vie, vie_j + round(j.vie * potion[1] / 100.0))
            charges -= 1
            potion_prete = t + sim.RECHARGE_POTION
            if potion[2]:
                soins = potion[3]
                prochain["soin"] = t + 1.0

    def pret_a(k):
        return k in kit and t >= pret.get(k, -99.0)

    # Ouverture camouflée : le premier coup est un Garrot.
    if "camouflage" in kit:
        garrot[0] = t + DUREE_GARROT
    # Lot V7 : en Camouflage, l'Éventail assomme le second monstre ; le voleur ouvre ensuite sur le premier.
    assomme = [-1.0] * len(monstres)
    if "camouflage" in kit and "eventail" in kit and len(monstres) >= 2:
        assomme[1] = float(v3.ASSOMMER_DUREE)
    while t < DUREE_MAX:
        t, quoi = min((v, k) for k, v in prochain.items() if v is not None)
        i = cible()
        if i is None:
            break
        if quoi in ("main", "gauche"):
            arme = j.main if quoi == "main" else j.gauche
            blesser(i, coup(i, arme, 1.0))
            prochain[quoi] = t + arme[2]
        elif quoi == "gcd":
            d = 0
            if pret_a("coup_bas") and etourdi[i] < t:
                etourdi[i] = t + 4.0
                pret["coup_bas"] = t + R[v3.COUP_BAS] * rf
            elif pret_a("evasion") and vie_j < j.vie * 0.5:
                evasion = t + 6.0
                pret["evasion"] = t + R[v3.EVASION] * rf
            elif pret_a("eventail") and sum(1 for v in vies if v > 0) >= 2 and not any(a > t for a in assomme):
                # Éventail de couteaux : chaque monstre vivant (tous au contact), chacun peut recevoir les Toxines.
                for k in range(len(monstres)):
                    if vies[k] > 0:
                        blesser(k, coup(k, j.main, v3.EVENTAIL_POURCENT / 100.0))
                        poser(k, v3.EVENTAIL_CUMULS)
                pret["eventail"] = t + R[v3.EVENTAIL] * rf
            elif "envenimer" in kit and cumuls[i] >= v3.CUMULS_MAX:
                d = coup(i, j.main, v3.ENVENIMER_POURCENT / 100.0 * cumuls[i], toxines=False)
                cumuls[i] = 0
            elif pret_a("rupture") and rupture[i] < t + TIC_RUPTURE:
                rupture[i] = t + DUREE_RUPTURE
            elif pret_a("estropier"):
                d = coup(i, j.main, v3.ESTROPIER_POURCENT / 100.0) + coup(i, j.gauche, v3.ESTROPIER_POURCENT / 100.0)
                poser(i)
                pret["estropier"] = t + R[v3.ESTROPIER] * rf
            else:
                prochain["gcd"] = t + 0.1
                continue
            blesser(i, d)
            prochain["gcd"] = t + GCD + alea.uniform(0, 2 * reaction)
        elif quoi == "tic":
            for k in range(len(monstres)):
                if cumuls[k] and t > fin_poison[k]:
                    cumuls[k] = 0
                if cumuls[k] and vies[k] > 0:
                    blesser(k, round(v3.BONUS[v3.POISON][1] * j.pa * cumuls[k] * (1 - malus[k]) * facteur(k)))
                if garrot[k] >= t and vies[k] > 0:
                    blesser(k, round(v3.BONUS[v3.GARROT][1] * j.pa * (1 - malus[k]) * facteur(k)))
            prochain[quoi] = t + TIC_POISON
        elif quoi == "saigne":
            for k in range(len(monstres)):
                if rupture[k] >= t and vies[k] > 0:
                    blesser(k, round(v3.BONUS[v3.RUPTURE][1] * j.pa * (1 - malus[k]) * facteur(k)))
            prochain[quoi] = t + TIC_RUPTURE
        elif quoi == "soin":
            vie_j = min(j.vie, vie_j + round(j.vie * potion[2] / 100.0))
            soins -= 1
            prochain[quoi] = t + 1.0 if soins > 0 else None
        elif quoi[0] == "m":
            k = int(quoi[1:])
            m = monstres[k]
            if vies[k] <= 0:
                prochain[quoi] = None
                continue
            if etourdi[k] >= t:
                prochain[quoi] = etourdi[k] + 0.01
                continue
            if assomme[k] >= t:
                prochain[quoi] = assomme[k] + 0.01
                continue
            brut = round(alea.randint(m.bas, m.haut) * sim.MONSTRES_DEGATS * getattr(m, "courbe_degats", 1.0))
            d = sim.apres_armure(brut, j.armure, m.puissance)
            if alea.random() * 100 < m.critique:
                d *= 2
            d = round(d * (1 - v3.AFFAIBLISSEMENT / 100.0 * cumuls[k]))
            encaisser(d)
            prochain[quoi] = t + m.vitesse
            retour = round(d * p.get("epines", 0.0))
            if "contre" in p and alea.random() < p["contre"]:
                retour += coup(i, j.main, 1.0)
            blesser(i, retour)
        else:  # poison du monstre
            k = int(quoi[1:])
            if vies[k] > 0:
                encaisser(round(monstres[k].poison[0] * sim.MONSTRES_DUREE))
                prochain[quoi] = t + monstres[k].poison[1]
            else:
                prochain[quoi] = None
        if vie_j > 0:
            boire()
        if all(v <= 0 for v in vies):
            if recharges is not None:
                recharges.update(pret)
            return True, t, vie_j, inflige, subi
        if vie_j <= 0:
            if recharges is not None:
                recharges.update(pret)
            return False, t, 0, inflige, subi
    if recharges is not None:
        recharges.update(pret)
    return False, t, vie_j, inflige, subi


def simuler(j, monstres, n=1000, graine=1, **options):
    alea = random.Random(graine)
    recharges = {}
    return sim.resumer([combat(j, monstres, alea, recharges=recharges, **options) for _ in range(n)], j, n)


def guerrier_de_reference():
    fiches = (sim.au_present(c) for chemin in list(reversed(te.journaux())) + [te.REFERENCE]
              for c in reversed(sim.lire_journal(chemin)) if c["joueur"])
    g = next(fiches)
    guid = int(sim.sql("SELECT guid FROM acore_characters.characters WHERE name = '%s'" % g.nom)[0][0])
    return g, guid


def rapport():
    guerrier, guid = guerrier_de_reference()
    monstres = [sim.monstre_depuis_base(e, n) for e, n in te.MONSTRES]
    panoplies = {nom: o for nom, o in te.PANOPLIES.items() if "fabriquée" not in nom}
    resultats = []
    for nom, objets in panoplies.items():
        g = sim.equiper(guerrier, objets, guid)
        v = voleur(objets, guid, g.critique)
        kit = VALLEE if "vallée" in nom else DUROTAR
        print("\n%s : %s ; guerrier vie %d, armure %d" % (nom, v, g.vie, g.armure))
        for m in monstres:
            rv = simuler(v, [m], 1000, kit=kit)
            rg = sim.simuler(g, m, 1000)
            print("  %-26s P%-2d | voleur %5.1f %% %5.1f s vie %5.1f %% | guerrier %5.1f %% %5.1f s vie %5.1f %%%s"
                  % (m.nom[:26], m.puissance, rv["victoire"], rv["duree"], rv["vie_restante"],
                     rg["victoire"], rg["duree"], rg["vie_restante"], te.verdict(g, m, rv)))
            if abs(m.puissance - g.puissance) <= 2:
                resultats.append((rv, rg))
        for taille in (2, 3):
            proches = [m for m in monstres if abs(m.puissance - v.puissance) <= 1][:1]
            if not proches:
                continue
            groupe = [proches[0]] * taille
            rv = simuler(v, groupe, 400, kit=kit)
            rg = sim.simuler_groupe(g, groupe, 400)
            print("  groupe de %d %-14s P%-2d | voleur %5.1f %% %5.1f s vie %5.1f %% | guerrier %5.1f %% %5.1f s vie %5.1f %%"
                  % (taille, proches[0].nom[:14], proches[0].puissance, rv["victoire"], rv["duree"], rv["vie_restante"],
                     rg["victoire"], rg["duree"], rg["vie_restante"]))
    if resultats:
        moy = lambda cle, k: sum(r[k][cle] for r in resultats) / len(resultats)
        print("\nContre sa puissance (±2) : voleur %.1f %% %.1f s vie %.1f %% | guerrier %.1f %% %.1f s vie %.1f %%" % (
            moy("victoire", 0), moy("duree", 0), moy("vie_restante", 0),
            moy("victoire", 1), moy("duree", 1), moy("vie_restante", 1)))
    return resultats


def avec_bonus(v, b):
    """Bonus du défi des rares secrets approchés pour le voleur : vie et armure, dégâts subis sur la vie, dégâts
    infligés, critique et hâte sur les dégâts des dagues et la PA. Lot T6 des Tarides : sorti de gouffre() pour
    rares_secrets_v3.controle."""
    f = b.get("inflige", 1.0) * (1 + b.get("hate", 0.0))
    arme = lambda a: (a[0] * f, a[1] * f, a[2])
    return Voleur(v.nom, round(v.vie * b.get("vie", 1.0) / b.get("subis", 1.0)), round(v.armure * b.get("armure", 1.0)),
                  v.pa * f, v.puissance, arme(v.main), arme(v.gauche), v.critique + b.get("critique", 0.0))


def gouffre():
    """Gouffre de Ragefeu (élite et dernier boss, difficultés 1 à 5, potion F7, Repos) et rares secrets (tout en bleu
    du Gouffre), voleur contre guerrier aux mêmes pièces."""
    import simulation_camp as camp
    import simulation_donjons as donjons
    import simulation_modes as modes
    import rares_secrets_v3 as rares
    guerrier, guid = guerrier_de_reference()
    n = donjons.N
    for titre, objets in (("fin de Durotar (quêtes)", te.PANOPLIES["fin de Durotar (quêtes)"]),
                          ("tout en bleu du Gouffre", rares.GOUFFRE)):
        g0 = sim.equiper(guerrier, objets, guid)
        v0 = voleur(objets, guid, g0.critique, repas=5)
        print("\nGouffre, %s : victoires (%%) voleur / guerrier, contre le Massacreur (élite) puis Taragaman (boss)"
              % titre)
        print("   %-18s %s" % ("", "   ".join("diff. %d        " % d for d in range(1, 6))))
        for r in (0, 2, 4):
            g, v = camp.repos(modes.rangs(g0, r), 5), renforce(v0, r)
            cases = []
            for diff in range(1, 6):
                paire = []
                for entree in (donjons.ELITE, donjons.BOSS):
                    if diff == 1:
                        m = sim.monstre_depuis_base(entree)
                    else:
                        ecart, f, techniques = donjons.DIFFICULTES[diff]
                        m = modes.renforcer(sim.monstre_depuis_base(entree, modes.puissance_visee(g0, ecart, entree)),
                                            f, 1 + donjons.TECHNIQUE * techniques)
                    rv = simuler(v, [m], n, potion=donjons.POTION_F7)
                    rg = sim.simuler(g, m, n, potion=donjons.POTION_F7)
                    paire.append("%3.0f/%3.0f" % (rv["victoire"], rg["victoire"]))
                cases.append(" ".join(paire))
            print("   %-18s %s" % ("+ %d rangs d'objet" % r, "   ".join(cases)))
    import simulation_lot4c as lot4c
    g, b = rares.fiche()
    v = renforce(voleur(rares.GOUFFRE, guid, g.critique, repas=5))
    vb = avec_bonus(v, b)
    print("\nRares secrets (réglés en jeu, puissance %d), tout en bleu du Gouffre, Repos, potion F7 : victoires (%%) "
          "sans / avec les autres bonus" % rares.PUISSANCE_RARE)
    for entree, origine, nom, *_ in rares.RARES:
        m = sim.monstre_depuis_base(entree, rares.PUISSANCE_RARE)
        print("   %-24s vie %5d | voleur %5.1f / %5.1f | guerrier %5.1f / %5.1f"
              % (nom, m.vie, simuler(v, [m], n, potion=donjons.POTION_F7)["victoire"],
                 simuler(vb, [m], n, potion=donjons.POTION_F7)["victoire"],
                 sim.simuler(g, m, n, potion=donjons.POTION_F7)["victoire"], lot4c.essai(g, m, b)))


def tarides():
    """Lot T1 des Tarides : voleur et guerrier aux pièces d'arrivée refaites à chaque point de la zone
    (fiches_zones.joueurs, Repos du feu 3, potion rang 2), contre les monstres des secteurs (mêlée seule, comme
    rapport())."""
    import fiches_zones as fz
    for nom, puissance in te.PANOPLIES_TARIDES.items():
        g, _, v = fz.joueurs(puissance)
        print("\nTarides, %s : %s ; guerrier vie %d, armure %d" % (nom, v, g.vie, g.armure))
        for e, p in te.MONSTRES_TARIDES:
            if not puissance - 2 <= p <= puissance + 3:
                continue
            m = sim.courber(sim.monstre_depuis_base(e, p))      # courbe des monstres (migration 138)
            rv = simuler(v, [m], 1000, potion=te.POTION_TARIDES)
            rg = sim.simuler(g, m, 1000, potion=te.POTION_TARIDES)
            print("  %-26s P%-2d | voleur perdue %5.1f %% %5.1f s | guerrier perdue %5.1f %% %5.1f s%s" % (
                m.nom[:26], p, te.perdue(rv), rv["duree"], te.perdue(rg), rg["duree"],
                te.verdict_perdue(v, m, te.perdue(rv))))


def passifs():
    """Gain de chaque passif de donjon, en points de victoires, contre un fouette-queue réglé pour que chaque classe
    gagne environ une fois sur deux, sur la panoplie de fin de Durotar avec le Repos et la potion F7."""
    import simulation_camp as camp
    import simulation_donjons as donjons
    import simulation_modes as modes
    guerrier, guid = guerrier_de_reference()
    objets = te.PANOPLIES["fin de Durotar (quêtes)"]
    g = camp.repos(sim.equiper(guerrier, objets, guid), 5)
    v = renforce(voleur(objets, guid, g.critique, repas=5))
    n = donjons.N

    def regle(taux):
        bas, haut = 0.2, 6.0
        for _ in range(16):
            k = (bas + haut) / 2
            t = taux(k, None)
            if 45 <= t <= 55:
                break
            bas, haut = (k, haut) if t > 55 else (bas, k)
        return k, t

    monstre_k = lambda k: modes.renforcer(sim.monstre_depuis_base(3122, math.floor(g.puissance)), k, 1.0)
    tv = lambda k, q: simuler(v, [monstre_k(k)], n, potion=donjons.POTION_F7, passifs=q)["victoire"]
    tg = lambda k, q: sim.simuler(g, monstre_k(k), n, potion=donjons.POTION_F7, passifs=q)["victoire"]
    kv, t0v = regle(tv)
    kg, t0g = regle(tg)
    print("Passifs : gain en points de victoires contre un fouette-queue réglé à %.0f %% (voleur, × %.2f) et %.0f %% "
          "(guerrier, × %.2f)" % (t0v, kv, t0g, kg))
    for nom, q in donjons.PASSIFS.items():
        print("   %-46s voleur %+4.0f | guerrier %+4.0f" % (nom, tv(kv, q) - t0v, tg(kg, q) - t0g))


if __name__ == "__main__":
    (passifs() if "--passifs" in sys.argv else gouffre() if "--gouffre" in sys.argv
     else tarides() if "--tarides" in sys.argv else rapport())
