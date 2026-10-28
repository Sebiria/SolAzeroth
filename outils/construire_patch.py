"""Construit le patch client unique de Sol'Azeroth : C:\\SolAzeroth\\patch-client\\patch-frFR-4.MPQ.

Le patch reprend tous les fichiers du dossier patch-client\\fichiers (chemins relatifs = chemins dans le jeu,
par exemple fichiers\\DBFilesClient\\CharBaseInfo.dbc). Le lanceur le copie dans Data\\frFR du client.
"""
import os

import mpq

RACINE = r"C:\SolAzeroth\patch-client"
SOURCE = os.path.join(RACINE, "fichiers")
SORTIE = os.path.join(RACINE, "patch-frFR-4.MPQ")


def construire():
    fichiers = {}
    for dossier, _, noms in os.walk(SOURCE):
        for nom in noms:
            if nom == "LISEZMOI.txt":
                continue
            chemin = os.path.join(dossier, nom)
            with open(chemin, "rb") as f:
                fichiers[os.path.relpath(chemin, SOURCE)] = f.read()
    mpq.ecrire(SORTIE, fichiers)
    return sorted(fichiers)


if __name__ == "__main__":
    contenu = construire()
    print("Patch construit :", SORTIE)
    for nom in contenu:
        print("  " + nom)
