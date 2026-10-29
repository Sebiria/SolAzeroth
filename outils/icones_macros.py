"""Sol'Azeroth : plus d'icônes pour les macros (demande de l'utilisateur du 29/10/2026).

Une macro ne peut prendre qu'une icône de SpellIcon.dbc (GetMacroIconInfo) : une icône de la liste des objets
(GetMacroItemIconInfo, ItemDisplayInfo.dbc) reste vide sur une macro (essai en jeu du 29/10/2026). Ce script ajoute
à SpellIcon.dbc les icônes des objets et celles des archives du client (Interface\\Icons : hauts faits, montures,
boss...) qui n'y sont pas encore, et écrit le résultat dans patch-client\\fichiers\\DBFilesClient\\SpellIcon.dbc.
Le serveur n'utilise pas ce fichier.

Usage : py outils\\icones_macros.py   puis   py outils\\construire_patch.py
"""
import glob
import os

import dbc
import mpq

DBC_SERVEUR = r"C:\SolAzeroth\data\dbc"
SORTIE = r"C:\SolAzeroth\patch-client\fichiers\DBFilesClient\SpellIcon.dbc"
PREFIXE = "interface\\icons\\"


def icones_du_client():
    client = open(r"C:\SolAzeroth\config\client.txt", encoding="utf-8-sig").readline().strip()
    archives = glob.glob(os.path.join(client, "Data", "*.MPQ")) + glob.glob(os.path.join(client, "Data", "*", "*.MPQ"))
    icones = {}
    for archive in sorted(archives):
        if os.path.basename(archive).lower() == "patch-frfr-4.mpq":   # le patch de Sol'Azeroth lui-même
            continue
        for nom in mpq.lister(archive):
            bas = nom.lower().replace("/", "\\")
            if bas.startswith(PREFIXE) and bas.endswith(".blp"):
                icones.setdefault(bas[len(PREFIXE):-4], nom.replace("/", "\\")[len(PREFIXE):-4])
    return icones


def nom_court(chemin):
    return chemin.lower().replace("/", "\\").split("\\")[-1]


def main():
    sorts = dbc.Dbc.ouvrir(os.path.join(DBC_SERVEUR, "SpellIcon.dbc"))
    connues = {nom_court(sorts.texte(e[1])) for e in sorts.enregistrements}
    candidates = icones_du_client()
    objets = dbc.Dbc.ouvrir(os.path.join(DBC_SERVEUR, "ItemDisplayInfo.dbc"))
    for e in objets.enregistrements:
        if e[5]:   # InventoryIcon_1 : l'icône existe dans le client même si les archives ne la listent pas
            nom = objets.texte(e[5]).replace("/", "\\").split("\\")[-1]
            candidates.setdefault(nom.lower(), nom)

    prochain = max(e[0] for e in sorts.enregistrements) + 1
    ajoutees = 0
    for bas, nom in sorted(candidates.items()):
        if bas in connues:
            continue
        sorts.enregistrements.append([prochain, sorts.ajouter_texte("Interface\\Icons\\" + nom)])
        prochain += 1
        ajoutees += 1
    os.makedirs(os.path.dirname(SORTIE), exist_ok=True)
    sorts.enregistrer(SORTIE)
    print(f"{ajoutees} icônes ajoutées ({len(sorts.enregistrements)} au total) : {SORTIE}")


if __name__ == "__main__":
    main()
