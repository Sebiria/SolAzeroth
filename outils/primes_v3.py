"""v3 (01/11/2026, demande de l'utilisateur : « recalibre les primes ») : A13 Dent-de-l'Écho, A16 Gangretisseur Arrogg et
A17 Capitaine Plate-défense restaient imbattables (0 % en simulation, même avec deux rangs d'objet de plus) : deux rares
élites de Blizzard (vie x3, dégâts x1,7) et notre requin (dégâts x7,5, puissance 12 et 13 pour une prime annoncée à 11).

Même méthode que le Gouffre (gouffre_v3.py) : puissance de la prime (11), vie et dégâts réglés pour que la fiche de
référence (60 % de Durotar, Repos et potion rang 2) gagne environ CIBLE % du combat seul, et qu'avec un rang d'objet de
plus elle dépasse SEREIN %. Les techniques (pluie de feu, traqueur, charge, entraîner au fond, frénésie) ne sont pas
simulées : à vérifier en jeu.

py primes_v3.py  (écrit la migration 105 et affiche les réglages)
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gouffre_v3 as g
import simulation_camp as camp
import simulation_combat as sim
import simulation_modes as modes
from quetes_durotar import sql

MIGRATION = r"C:\SolAzeroth\sql\migrations\105_v3_primes_calibre"
PRIMES = {910021: ("A13 Dent-de-l'Écho", 11), 5822: ("A16 Gangretisseur", 11), 5824: ("A17 Plate-défense", 11)}


def main():
    reference = max(camp.fiches(), key=lambda f: f.puissance)
    j60 = camp.repos(reference, 5)
    j100 = camp.repos(modes.rangs(reference, 1), 5)
    print("Fiche de référence : %s" % reference)
    reglages = {}
    for e, (nom, niveau) in PRIMES.items():
        def taux(j, k):
            return sim.simuler(j, g.monstre(e, niveau, k, k), g.N, potion=g.POTION)["victoire"]
        k = g.regler(lambda k: taux(j60, k))
        while k > 0.1 and taux(j60, k) < g.CIBLE:   # courbe raide : la dichotomie peut finir juste en dessous
            k = round(k - 0.02, 2)
        reglages[e] = (niveau, k)
        t100 = taux(j100, k)
        print("%s : puissance %d, vie et dégâts x %.2f ; %.0f %% / %.0f %%%s" % (
            nom, niveau, k, taux(j60, k), t100, "" if t100 >= g.SEREIN else "  (< %d %%)" % g.SEREIN))

    liste = ", ".join(map(str, PRIMES))
    up = ["-- v3 (01/11/2026) : calibrage des primes A13, A16 et A17. Généré par outils\\primes_v3.py : ne pas modifier",
          "-- à la main.",
          "USE acore_world;",
          "CREATE TABLE IF NOT EXISTS solazeroth_v3_primes_origine SELECT entry, minlevel, maxlevel, HealthModifier, "
          "DamageModifier FROM creature_template WHERE entry IN (%s);" % liste]
    for e, (niveau, k) in reglages.items():
        up.append("UPDATE creature_template SET minlevel = %d, maxlevel = %d, HealthModifier = %.2f, DamageModifier = "
                  "%.2f WHERE entry = %d;" % (niveau, niveau, k, k, e))
    up.append("")
    down = ["-- Rend aux trois primes leurs réglages d'origine.",
            "USE acore_world;",
            "UPDATE creature_template t JOIN solazeroth_v3_primes_origine o ON o.entry = t.entry SET t.minlevel = "
            "o.minlevel, t.maxlevel = o.maxlevel, t.HealthModifier = o.HealthModifier, t.DamageModifier = o.DamageModifier;",
            "DROP TABLE solazeroth_v3_primes_origine;", ""]
    for suffixe, lignes in ((".up.sql", up), (".down.sql", down)):
        with open(MIGRATION + suffixe, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(lignes))
    print("Migration 105 écrite.")


if __name__ == "__main__":
    main()
