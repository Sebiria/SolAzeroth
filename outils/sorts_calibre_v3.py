"""v3 (01/11/2026, demande de l'utilisateur : « on lui applique un effet mais au détriment d'autres dégâts pour garder
l'équilibre. Et ça vaut pour tous les autres mobs ») : recalibrage des monstres de Durotar et du Gouffre avec leurs
sorts (simulation_sorts.py).

Jusqu'ici, tous les réglages (vie, dégâts) venaient de simulations sans les sorts des monstres. Pour garder la
difficulté voulue, chaque monstre qui lance des sorts est réglé pour que le joueur subisse, en moyenne, autant de dégâts
avec ses sorts que sans eux :
- d'abord sa mêlée baisse (DamageModifier × f, f entre F_MIN et 1) ;
- si cela ne suffit pas, ses sorts baissent aussi (facteur g entre G_MIN et 1 sur leurs dégâts et leurs soins, table
  solazeroth_v3_sorts_facteur lue par v3_combat.cpp) ;
- un monstre dont les sorts pèsent peu garde ses réglages (f = 1 : on ne le rend pas plus dur) ;
- il doit aussi rester battable aussi souvent : si ses soins font traîner le combat au-delà de 3 minutes (défaite en
  simulation), ses sorts baissent jusqu'à retrouver la part de victoires d'avant (à VICTOIRE points près).
Le joueur : la fiche de Sebiria la plus proche de la puissance du monstre (journaux de combat), potion de départ.

py sorts_calibre_v3.py  (écrit la migration 107 et affiche les réglages)
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import simulation_camp as camp
import simulation_sorts as ss
import sorts_monstres_v3 as smv
from quetes_durotar import sql

MIGRATION = r"C:\SolAzeroth\sql\migrations\107_v3_sorts_calibre"
F_MIN, G_MIN = 0.3, 0.2
VICTOIRE = 3.0
TOLERANCE = 1.05          # écart de dégâts subis accepté avant de régler
POTION = (1, 30, 0, 0)
N, N_FINAL = 300, 1000


def reference(puissance, fiches):
    return min(fiches, key=lambda f: abs(f.puissance - puissance))


def regler(subi, cible, bas, haut):
    """Le facteur (entre bas et haut) pour lequel subi(k) vaut cible ; subi croît avec k."""
    for _ in range(9):
        k = (bas + haut) / 2
        if subi(k) > cible:
            haut = k
        else:
            bas = k
    return round((bas + haut) / 2, 2)


def main():
    fiches = [f for f in camp.fiches() if f.nom == "Sebiria"]
    reglages = []
    for entree in sorted(smv.monstres_zone()):
        try:
            m = ss.monstre_avec_sorts(entree)
        except IndexError:
            continue
        if not m.sorts or m.puissance > 15 or m.vie <= 1:
            continue
        j = reference(m.puissance, fiches)
        sans = ss.simuler(j, m, N_FINAL, sorts=False, potion=POTION)
        cible = sans["subi"] * TOLERANCE

        def subi(f, g=1.0, n=N):
            return ss.simuler(j, m, n, melee=f, facteur_sorts=g, potion=POTION)["subi"]

        f, g = 1.0, 1.0
        if subi(1.0) > cible:
            if subi(F_MIN) > cible:
                f = F_MIN
                g = G_MIN if subi(F_MIN, G_MIN) > cible else regler(lambda k: subi(F_MIN, k), cible, G_MIN, 1.0)
            else:
                f = regler(subi, cible, F_MIN, 1.0)
        def victoire(g):
            return ss.simuler(j, m, N, melee=f, facteur_sorts=g, potion=POTION)["victoire"]
        if victoire(g) < sans["victoire"] - VICTOIRE:
            bas, haut = G_MIN, g
            for _ in range(8):
                k = (bas + haut) / 2
                if victoire(k) < sans["victoire"] - VICTOIRE:
                    haut = k
                else:
                    bas = k
            g = round(bas, 2)
        avant = ss.simuler(j, m, N_FINAL, potion=POTION)
        apres = ss.simuler(j, m, N_FINAL, melee=f, facteur_sorts=g, potion=POTION)
        reglages.append((entree, m, f, g))
        print("%6d %-32s P%-2d (fiche %.1f) | sans sorts %5.1f %% %3.0f %% vie | avec %5.1f %% %3.0f %% | réglé "
              "f %.2f g %.2f : %5.1f %% %3.0f %%" % (
                  entree, m.nom[:32], m.puissance, j.puissance, sans["victoire"], sans["vie_restante"],
                  avant["victoire"], avant["vie_restante"], f, g, apres["victoire"], apres["vie_restante"]),
              flush=True)

    changes = [(e, f, g) for e, _, f, g in reglages if f < 1.0 or g < 1.0]
    liste = ", ".join(str(e) for e, _, _ in changes) or "0"
    up = ["-- v3 (01/11/2026) : monstres de Durotar et du Gouffre recalibrés avec leurs sorts. Généré par",
          "-- outils\\sorts_calibre_v3.py : ne pas modifier à la main.",
          "USE acore_world;",
          "CREATE TABLE solazeroth_v3_sorts_calibre_origine SELECT entry, DamageModifier FROM creature_template WHERE "
          "entry IN (%s);" % liste,
          "CREATE TABLE IF NOT EXISTS solazeroth_v3_sorts_facteur (entry INT UNSIGNED NOT NULL PRIMARY KEY, facteur "
          "FLOAT NOT NULL) ENGINE=InnoDB;"]
    for e, f, g in changes:
        if f < 1.0:
            up.append("UPDATE creature_template SET DamageModifier = ROUND(DamageModifier * %.2f, 3) WHERE entry = %d;"
                      % (f, e))
        if g < 1.0:
            up.append("REPLACE INTO solazeroth_v3_sorts_facteur VALUES (%d, %.2f);" % (e, g))
    up.append("")
    down = ["-- Rend aux monstres leurs réglages d'avant le recalibrage avec leurs sorts.",
            "USE acore_world;",
            "UPDATE creature_template t JOIN solazeroth_v3_sorts_calibre_origine o ON o.entry = t.entry SET "
            "t.DamageModifier = o.DamageModifier;",
            "DROP TABLE solazeroth_v3_sorts_calibre_origine;",
            "DROP TABLE solazeroth_v3_sorts_facteur;", ""]
    for suffixe, lignes in ((".up.sql", up), (".down.sql", down)):
        with open(MIGRATION + suffixe, "w", encoding="utf-8", newline="\n") as fichier:
            fichier.write("\n".join(lignes))
    print("Migration 107 écrite : %d monstres réglés sur %d avec des sorts." % (len(changes), len(reglages)))


if __name__ == "__main__":
    main()
