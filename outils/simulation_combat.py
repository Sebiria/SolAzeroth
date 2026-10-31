"""v3 (31/10/2026) : simulation de combats, un joueur contre un monstre, pour l'équilibrage (demande de l'utilisateur :
« pour les équilibrages, il faut faire des simulations de combats entre un bot moi et un bot mob cible »).

Les règles reprennent celles du serveur (v3_combat.cpp, v3_kit.cpp) :
- tout coup porte ; seul le critique reste (×2, après l'armure, comme le moteur) ;
- armure = réduction fixe : chaque coup physique perd armure / ARMURE_PAR_POINT, au moins 25 % du coup passent
  (arrondi au supérieur) ;
- dégâts des monstres ×4 en mêlée (avant l'armure), ×1,5 sur la durée ; malus du joueur face à un monstre plus fort :
  -2 % par point de puissance manquant (au plus -75 %) ;
- vie des monstres ×2 ; coups des monstres d'après le moteur : (dégâts de base + PA / 14 × variance) × modificateur ×
  vitesse, et ×1,5 pour le maximum (Creature::CalculateMinMaxDamage) ;
- kit du guerrier tank : Frappe du bouclier (200 % de l'arme, 6 s, +8 % de la vie dans le Rempart), Coup de tonnerre
  (100 %, 8 s, le monstre frappe 20 % moins vite pendant 10 s), Riposte du rempart (consomme le Rempart, 150 % du
  montant, 10 s ; sans armure, supposé), mêlée automatique ;
- Rempart : 40 % de chaque coup encaissé après l'armure (absorbé ou subi), plafonné à 30 % de la vie maximale.
- contre un groupe (combat_groupe) : mêlée et Frappe du bouclier sur un monstre à la fois, Coup de tonnerre sur tous,
  et Cri de défi (12 s) qui verse 3 % de la vie maximale au Rempart par monstre attiré.

Fiches : celles du journal de combat (journaux\\combat), ou un monstre bâti depuis la base. Le joueur part de sa
dernière fiche du journal ; --equiper remplace des pièces (écart d'armure, d'arme, de Puissance d'attaque, d'Endurance).

Exemples :
  py simulation_combat.py --journal                 rejoue les combats du dernier journal
  py simulation_combat.py --monstre 3125            le joueur du dernier journal contre un Scorpide claquant
  py simulation_combat.py --monstre 3125 --equiper 910119,910116 --niveau 6
"""
import argparse
import glob
import math
import os
import random
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from quetes_durotar import sql

JOURNAUX = r"C:\SolAzeroth\journaux\combat"
ARMURE_PAR_POINT, ARMURE_MINIMUM = 20.0, 0.25
MONSTRES_VIE, MONSTRES_DEGATS, MONSTRES_DUREE = 2.0, 4.0, 1.5
MALUS_PAR_POINT, MALUS_MAX = 2.0, 75.0
REMPART_PART, REMPART_PLAFOND, REMPART_FRAPPE = 0.40, 0.30, 0.08
REMPART_CRI_DEFI = 0.03
CRITIQUE_MONSTRE = 5.0
DUREE_MAX = 180.0


class Fiche:
    def __init__(self, nom, vie, armure, bas, haut, vitesse, critique, puissance, poison=None):
        self.nom, self.vie, self.armure = nom, vie, armure
        self.bas, self.haut, self.vitesse = bas, haut, vitesse
        self.critique, self.puissance = critique, puissance
        self.poison = poison   # (dégâts par tick avant ×1,5, intervalle, premier tick) ou None

    def __repr__(self):
        return "%s : puissance %s, vie %d, armure %d, coups %d-%d toutes les %.2f s, critique %.1f %%" % (
            self.nom, self.puissance, self.vie, self.armure, self.bas, self.haut, self.vitesse, self.critique)


def apres_armure(degats, armure):
    if degats <= 0:
        return 0
    return math.ceil(max(degats - armure / ARMURE_PAR_POINT, degats * ARMURE_MINIMUM))


def combat(joueur, monstre, alea, riposte=False, reaction=1.4):
    """Un combat ; renvoie (victoire, durée, vie restante du joueur, dégâts infligés, dégâts subis).
    reaction : délai moyen (tiré entre 0 et 2 × reaction) entre la fin d'une recharge et la technique, d'après le
    journal du 31/10/2026 (Frappe du bouclier toutes les 7,4 s pour 6 s de recharge). Riposte du rempart n'est
    lancée que si riposte est vrai (l'utilisateur ne s'en servait pas)."""
    vie_j, vie_m = joueur.vie, monstre.vie
    plafond = int(joueur.vie * REMPART_PLAFOND)
    rempart = 0
    malus = min(max(0.0, monstre.puissance - joueur.puissance) * MALUS_PAR_POINT, MALUS_MAX) / 100.0
    t = 0.0
    prochain = {"melee_j": 0.1, "melee_m": 2.0 * monstre.vitesse / 2.0, "frappe": 0.0, "tonnerre": 1.5,
                "riposte": 0.0 if riposte else None, "poison": monstre.poison[2] if monstre.poison else None}
    ralenti_jusqua = -1.0
    inflige = subi = 0

    def coup_joueur(pourcent):
        d = alea.uniform(joueur.bas, joueur.haut) * pourcent * (1 - malus)
        d = apres_armure(int(d), monstre.armure)
        if alea.random() * 100 < joueur.critique:
            d *= 2
        return d

    def encaisser(d):
        nonlocal rempart, vie_j, subi
        absorbe = min(rempart, d)
        rempart -= absorbe
        rempart = min(rempart + round(absorbe * REMPART_PART), plafond + absorbe)
        reste = d - absorbe
        rempart = min(rempart + round(reste * REMPART_PART), plafond)
        vie_j -= reste
        subi += reste

    while t < DUREE_MAX:
        evenement = min((v, k) for k, v in prochain.items() if v is not None)
        t, quoi = evenement
        if quoi == "melee_j":
            d = coup_joueur(1.0)
            prochain[quoi] = t + joueur.vitesse
        elif quoi == "frappe":
            d = coup_joueur(2.0)
            rempart = min(rempart + round(joueur.vie * REMPART_FRAPPE), plafond)
            prochain[quoi] = t + 6.0 + alea.uniform(0, 2 * reaction)
        elif quoi == "tonnerre":
            d = coup_joueur(1.0)
            ralenti_jusqua = t + 10.0
            prochain[quoi] = t + 8.0 + alea.uniform(0, 2 * reaction)
        elif quoi == "riposte":
            if rempart >= plafond * 0.5 and rempart > 0:
                d = round(rempart * 1.5 * (1 - malus))
                rempart = 0
                prochain[quoi] = t + 10.0
            else:
                d = 0
                prochain[quoi] = t + 0.5
        elif quoi == "melee_m":
            brut = round(alea.randint(monstre.bas, monstre.haut) * MONSTRES_DEGATS)
            d = apres_armure(brut, joueur.armure)
            if alea.random() * 100 < monstre.critique:
                d *= 2
            encaisser(d)
            prochain[quoi] = t + monstre.vitesse * (1.25 if t < ralenti_jusqua else 1.0)
            d = 0
        else:  # poison
            encaisser(round(monstre.poison[0] * MONSTRES_DUREE))
            prochain[quoi] = t + monstre.poison[1]
            d = 0
        vie_m -= d
        inflige += d
        if vie_m <= 0:
            return True, t, vie_j, inflige, subi
        if vie_j <= 0:
            return False, t, 0, inflige, subi
    return False, t, vie_j, inflige, subi


def repas(joueur, force):
    """Le joueur après un repas (cuisine_v3.py) : +force Force, soit 2 de Puissance d'attaque par point pour le
    guerrier, et les dégâts de l'arme gagnent PA / 14 × vitesse (règle du moteur)."""
    bonus = 2 * force / 14.0 * joueur.vitesse
    return Fiche(joueur.nom + " (repas +%d)" % force, joueur.vie, joueur.armure, joueur.bas + bonus, joueur.haut + bonus,
                 joueur.vitesse, joueur.critique, joueur.puissance, joueur.poison)


def enchanter(joueur, vie=0, armure=0, force=0, degats=0):
    """Le joueur avec des enchantements (enchantement_v3.py) : vie, armure, Force (2 de Puissance d'attaque par point
    pour le guerrier) et dégâts d'arme ajoutés à chaque coup."""
    bonus = 2 * force / 14.0 * joueur.vitesse + degats
    return Fiche(joueur.nom + " (enchanté)", joueur.vie + vie, joueur.armure + armure, joueur.bas + bonus,
                 joueur.haut + bonus, joueur.vitesse, joueur.critique, joueur.puissance, joueur.poison)


def combat_groupe(joueur, monstres, alea, cri=True, reaction=1.4):
    """Un combat contre plusieurs monstres arrivés ensemble ; même renvoi que combat(). Le joueur frappe le premier
    monstre encore en vie ; Coup de tonnerre touche et ralentit tous les monstres ; Cri de défi est lancé dès qu'il est
    prêt s'il reste un monstre."""
    vie_j = joueur.vie
    vies = [m.vie for m in monstres]
    plafond = int(joueur.vie * REMPART_PLAFOND)
    rempart = 0
    t = 0.0
    prochain = {"melee_j": 0.1, "frappe": 0.0, "tonnerre": 1.5, "cri": 0.0 if cri else None}
    for i, m in enumerate(monstres):
        prochain[("melee_m", i)] = m.vitesse * alea.uniform(0.5, 1.0)
    ralenti_jusqua = -1.0
    inflige = subi = 0

    def malus(m):
        return min(max(0.0, m.puissance - joueur.puissance) * MALUS_PAR_POINT, MALUS_MAX) / 100.0

    def coup(m, pourcent):
        d = apres_armure(int(alea.uniform(joueur.bas, joueur.haut) * pourcent * (1 - malus(m))), m.armure)
        return d * 2 if alea.random() * 100 < joueur.critique else d

    def encaisser(d):
        nonlocal rempart, vie_j, subi
        absorbe = min(rempart, d)
        rempart -= absorbe
        rempart = min(rempart + round(absorbe * REMPART_PART), plafond + absorbe)
        reste = d - absorbe
        rempart = min(rempart + round(reste * REMPART_PART), plafond)
        vie_j -= reste
        subi += reste

    while t < DUREE_MAX:
        t, quoi = min((v, k) for k, v in prochain.items() if v is not None)
        vivants = [i for i, v in enumerate(vies) if v > 0]
        cible = vivants[0]
        degats = {}
        if quoi == "melee_j":
            degats[cible] = coup(monstres[cible], 1.0)
            prochain[quoi] = t + joueur.vitesse
        elif quoi == "frappe":
            degats[cible] = coup(monstres[cible], 2.0)
            rempart = min(rempart + round(joueur.vie * REMPART_FRAPPE), plafond)
            prochain[quoi] = t + 6.0 + alea.uniform(0, 2 * reaction)
        elif quoi == "tonnerre":
            for i in vivants:
                degats[i] = coup(monstres[i], 1.0)
            ralenti_jusqua = t + 10.0
            prochain[quoi] = t + 8.0 + alea.uniform(0, 2 * reaction)
        elif quoi == "cri":
            rempart = min(rempart + round(joueur.vie * REMPART_CRI_DEFI) * len(vivants), plafond)
            prochain[quoi] = t + 12.0 + alea.uniform(0, 2 * reaction)
        else:
            i = quoi[1]
            m = monstres[i]
            d = apres_armure(round(alea.randint(m.bas, m.haut) * MONSTRES_DEGATS), joueur.armure)
            encaisser(d * 2 if alea.random() * 100 < m.critique else d)
            prochain[quoi] = t + m.vitesse * (1.25 if t < ralenti_jusqua else 1.0)
        for i, d in degats.items():
            vies[i] -= d
            inflige += d
            if vies[i] <= 0:
                prochain[("melee_m", i)] = None
        if all(v <= 0 for v in vies):
            return True, t, vie_j, inflige, subi
        if vie_j <= 0:
            return False, t, 0, inflige, subi
    return False, t, vie_j, inflige, subi


def simuler_groupe(joueur, monstres, n=2000, graine=1, **options):
    alea = random.Random(graine)
    return resumer([combat_groupe(joueur, monstres, alea, **options) for _ in range(n)], joueur, n)


def simuler(joueur, monstre, n=2000, graine=1, **options):
    alea = random.Random(graine)
    return resumer([combat(joueur, monstre, alea, **options) for _ in range(n)], joueur, n)


def resumer(resultats, joueur, n):
    victoires = [r for r in resultats if r[0]]
    duree = sum(r[1] for r in resultats) / n
    return {
        "victoire": 100.0 * len(victoires) / n,
        "duree": duree,
        "vie_restante": 100.0 * sum(r[2] for r in victoires) / max(1, len(victoires)) / joueur.vie,
        "dps_joueur": sum(r[3] for r in resultats) / sum(r[1] for r in resultats),
        "dps_monstre": sum(r[4] for r in resultats) / sum(r[1] for r in resultats),
    }


def rapport(joueur, monstre, r):
    tuer = monstre.vie / max(0.01, r["dps_joueur"])
    survivre = joueur.vie / max(0.01, r["dps_monstre"])
    return ("victoire %5.1f %% | durée %5.1f s | vie restante %5.1f %% | joueur %.1f/s (tue en %.0f s) | "
            "monstre %.1f/s (tue en %.0f s)" % (r["victoire"], r["duree"], r["vie_restante"], r["dps_joueur"], tuer,
                                               r["dps_monstre"], survivre))


# --- Fiches du journal --------------------------------------------------------------------------------------------
JOUEUR = re.compile(r"Joueur (\S+) : puissance ([\d.]+), vie \d+/(\d+), armure (\d+) .*arme ([\d.]+)-([\d.]+) toutes les "
                    r"([\d.]+) s, critique ([\d.]+) %")
MONSTRE = re.compile(r"Monstre (.+?) \(entrée (\d+)\) : puissance (\d+), vie \d+/(\d+), armure (\d+), coups (\d+)-(\d+) "
                     r"toutes les ([\d.]+) s")
BILAN = re.compile(r"Bilan du combat (\d+) : ([\d.]+) s, (\d+) monstre.*vie (\d+)/(\d+)")
POISON = re.compile(r"-> (\S+) \| (.+?) \((\d+)\) \[périodique\] \| (\d+) \| armure -0 \| absorbé (\d+)")


def dernier_journal():
    fichiers = glob.glob(os.path.join(JOURNAUX, "*.log"))
    return max(fichiers, key=os.path.getmtime) if fichiers else None


def lire_journal(chemin):
    """Combats du journal : [{joueur, monstres, bilan, poison}]."""
    combats, courant = [], None
    with open(chemin, encoding="utf-8") as f:
        for ligne in f:
            if ligne.startswith("=== Combat"):
                courant = {"joueur": None, "monstres": [], "bilan": None, "ticks": []}
                combats.append(courant)
            elif courant is None:
                continue
            elif m := JOUEUR.search(ligne):
                courant["joueur"] = Fiche(m[1], int(m[3]), int(m[4]), float(m[5]), float(m[6]), float(m[7]), float(m[8]),
                                          float(m[2]))
            elif m := MONSTRE.search(ligne):
                courant["monstres"].append(Fiche(m[1], int(m[4]), int(m[5]), int(m[6]), int(m[7]), float(m[8]),
                                                 CRITIQUE_MONSTRE, int(m[3])))
                courant["monstres"][-1].entree = int(m[2])
            elif m := POISON.search(ligne):
                temps = float(ligne.split("s")[0])
                courant["ticks"].append((temps, int(m[4]) + int(m[5])))
            elif m := BILAN.search(ligne):
                courant["bilan"] = {"duree": float(m[2]), "tues": int(m[3]), "vie": int(m[4])}
    for c in combats:
        if c["ticks"] and c["monstres"]:
            ticks = c["ticks"]
            intervalle = (ticks[-1][0] - ticks[0][0]) / max(1, len(ticks) - 1) if len(ticks) > 1 else 3.0
            moyenne = sum(d for _, d in ticks) / len(ticks)
            c["monstres"][0].poison = (moyenne / MONSTRES_DUREE, intervalle, ticks[0][0])
    return combats


# --- Fiches bâties depuis la base ---------------------------------------------------------------------------------
def monstre_depuis_base(entree, niveau=None):
    l = sql("SELECT COALESCE(NULLIF(lo.Name, ''), t.name), t.minlevel, t.maxlevel, t.unit_class, t.`exp`, "
            "t.HealthModifier, t.DamageModifier, t.ArmorModifier, t.BaseAttackTime, t.BaseVariance, t.`rank` "
            "FROM acore_world.creature_template t LEFT JOIN acore_world.creature_template_locale lo "
            "ON lo.entry = t.entry AND lo.locale = 'frFR' WHERE t.entry = %d" % entree)[0]
    nom, bas, haut, classe, extension = l[0], int(l[1]), int(l[2]), int(l[3]), int(l[4])
    vie_mod, degats_mod, armure_mod = float(l[5]), float(l[6]), float(l[7])
    vitesse, variance = int(l[8]) / 1000.0, float(l[9])
    niveau = niveau or haut
    s = sql("SELECT basehp%d, basearmor, attackpower, damage_base, damage_exp1, damage_exp2 FROM "
            "acore_world.creature_classlevelstats WHERE level = %d AND class = %d" % (extension, niveau, classe))[0]
    base = float(s[3 + extension])
    pa = float(s[2])
    minimum = (base + pa / 14.0 * variance) * degats_mod * vitesse
    maximum = (base * 1.5 + pa / 14.0 * variance) * degats_mod * vitesse
    fiche = Fiche(nom, round(int(s[0]) * vie_mod * MONSTRES_VIE), round(int(s[1]) * armure_mod),
                  round(minimum), round(maximum), vitesse, CRITIQUE_MONSTRE, niveau)
    fiche.entree = entree
    return fiche


EMPLACEMENTS = {1: 0, 3: 2, 5: 4, 20: 4, 6: 5, 7: 6, 8: 7, 9: 8, 10: 9, 16: 14, 13: 15, 17: 15, 21: 15, 14: 16,
                22: 16, 23: 16}


def objet(entree):
    l = sql("SELECT InventoryType, armor, dmg_min1, dmg_max1, delay, %s, ItemLevel FROM acore_world.item_template "
            "WHERE entry = %d"
            % (", ".join("stat_type%d, stat_value%d" % (i, i) for i in range(1, 11)), entree))[0]
    stats = {}
    for i in range(10):
        t, v = int(l[5 + 2 * i]), int(l[6 + 2 * i])
        if t:
            stats[t] = stats.get(t, 0) + v
    return {"emplacement": EMPLACEMENTS.get(int(l[0])), "armure": int(l[1]), "bas": float(l[2]), "haut": float(l[3]),
            "vitesse": int(l[4]) / 1000.0, "pa": stats.get(38, 0) + 2 * stats.get(4, 0), "endurance": stats.get(7, 0),
            "niveau": int(l[25])}


def porte(guid):
    """Pièces portées par un personnage (base des personnages, telle qu'à sa dernière sauvegarde)."""
    return {int(s): int(e) for s, e in sql(
        "SELECT ci.slot, ii.itemEntry FROM acore_characters.character_inventory ci JOIN acore_characters.item_instance "
        "ii ON ii.guid = ci.item WHERE ci.guid = %d AND ci.bag = 0 AND ci.slot < 19" % guid)}


def equiper(joueur, nouveaux, guid, pa_total=None):
    """Joueur avec ces pièces à la place de celles qu'il porte (écarts d'armure, de vie, de PA et d'arme). Sa puissance
    devient la moyenne des niveaux d'objet portés, hors chemise et tabard, comme sur le serveur (sans les rangs)."""
    actuel = porte(guid)
    portes = dict(actuel)
    f = Fiche(joueur.nom, joueur.vie, joueur.armure, joueur.bas, joueur.haut, joueur.vitesse, joueur.critique,
              joueur.puissance)
    pa_arme = None
    for entree in nouveaux:
        n = objet(entree)
        ancien = objet(actuel[n["emplacement"]]) if n["emplacement"] in actuel else None
        a = ancien or {"armure": 0, "pa": 0, "endurance": 0, "bas": 0, "haut": 0, "vitesse": 0}
        f.armure += n["armure"] - a["armure"]
        f.vie += 10 * (n["endurance"] - a["endurance"])
        delta_pa = n["pa"] - a["pa"]
        portes[n["emplacement"]] = entree
        if n["emplacement"] == 15:
            # Part de la PA dans la fiche : arme affichée - dégâts de l'arme portée.
            pa_arme = (joueur.bas - a["bas"]) / max(0.01, a["vitesse"]) * 14 if a["vitesse"] else 0
            f.vitesse = n["vitesse"]
            f.bas = n["bas"] + pa_arme / 14 * f.vitesse
            f.haut = n["haut"] + pa_arme / 14 * f.vitesse
        f.bas += delta_pa / 14 * f.vitesse
        f.haut += delta_pa / 14 * f.vitesse
    niveaux = [objet(e)["niveau"] for s, e in portes.items() if s not in (3, 18)]
    f.puissance = round(sum(niveaux) / len(niveaux), 1) if niveaux else joueur.puissance
    return f


def main():
    p = argparse.ArgumentParser(description="Simulation de combats v3 (joueur contre monstre).")
    p.add_argument("--journal", nargs="?", const="", help="rejouer un journal (le dernier par défaut)")
    p.add_argument("--monstre", type=int, help="entrée du monstre (creature_template)")
    p.add_argument("--niveau", type=int, help="niveau d'origine du monstre (par défaut son maximum)")
    p.add_argument("--equiper", help="entrées d'objets à porter, séparées par des virgules")
    p.add_argument("--guid", type=int, default=20, help="personnage dont on lit l'équipement (20 : Test)")
    p.add_argument("-n", type=int, default=2000)
    p.add_argument("--riposte", action="store_true", help="lancer Riposte du rempart (Rempart à moitié plein)")
    a = p.parse_args()
    chemin = a.journal or dernier_journal()
    combats = lire_journal(chemin)
    joueur = next((c["joueur"] for c in reversed(combats) if c["joueur"]), None)
    if a.monstre:
        if a.equiper:
            joueur = equiper(joueur, [int(x) for x in a.equiper.split(",")], a.guid)
        monstre = monstre_depuis_base(a.monstre, a.niveau)
        print("Joueur  :", joueur)
        print("Monstre :", monstre)
        print(rapport(joueur, monstre, simuler(joueur, monstre, a.n, riposte=a.riposte)))
        return
    print("Journal :", chemin)
    for i, c in enumerate(combats, 1):
        if not c["joueur"] or len(c["monstres"]) != 1:
            continue
        j, m = c["joueur"], c["monstres"][0]
        b = c["bilan"] or {}
        print("Combat %d : %s contre %s" % (i, j.nom, m.nom))
        print("  réel    : %s, %.1f s, vie restante %s" % ("victoire" if b.get("tues") else "défaite", b.get("duree", 0),
                                                         b.get("vie")))
        print("  simulé  :", rapport(j, m, simuler(j, m, a.n, riposte=a.riposte)))


if __name__ == "__main__":
    main()
