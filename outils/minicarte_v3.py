"""Sol'Azeroth v3 : sans les points d'exclamation et d'interrogation du jeu sur la mini-carte (demande de l'utilisateur
du 01/11/2026). Les épingles de SolUI_Quetes.lua les remplacent.

La mini-carte dessine ses marques avec Interface\\Minimap\\ObjectIcons.blp : une grille de cases de 32 pixels
(256 x 64). Ligne du bas, cases 2 à 6 : « ! » jaune, « ? » jaune, « ! » bleu, « ? » bleu, « ! » vert. Ce script reprend
le fichier du client et rend ces cases transparentes, à chaque niveau de réduction, sans rien réencoder : le fichier
est en DXT5 (compression 2, alpha 8 bits, type d'alpha 7), où chaque bloc de 4 x 4 pixels commence par ses 8 octets
d'alpha ; des alphas à zéro effacent le bloc. Les autres marques (groupe, suivi des points de récolte) restent.

Usage : py outils\\minicarte_v3.py   puis   py outils\\construire_patch.py
"""
import glob
import os
import struct

import mpq

SORTIE = r"C:\SolAzeroth\patch-client\fichiers\Interface\Minimap\ObjectIcons.blp"
NOM = "interface\\minimap\\objecticons.blp"
CASES = (32, 32, 192, 64)   # gauche, haut, droite, bas (pixels de la plus grande image)


def original():
    """Le fichier du client qui l'emporte : le dernier patch qui le contient (hors celui de Sol'Azeroth)."""
    client = open(r"C:\SolAzeroth\config\client.txt", encoding="utf-8-sig").readline().strip()
    archives = glob.glob(os.path.join(client, "Data", "*.MPQ")) + glob.glob(os.path.join(client, "Data", "*", "*.MPQ"))
    trouve = None
    for archive in sorted(archives, key=lambda a: (os.path.dirname(a) != os.path.join(client, "Data"), a.lower())):
        if os.path.basename(archive).lower() == "patch-frfr-4.mpq":
            continue
        for nom in mpq.lister(archive):
            if nom.lower().replace("/", "\\") == NOM:
                trouve = mpq.lire(archive, nom)
    return trouve


def effacer(donnees):
    donnees = bytearray(donnees)
    assert donnees[:4] == b"BLP2" and donnees[8:11] == bytes((2, 8, 7)), "ObjectIcons.blp n'est plus en DXT5"
    largeur, hauteur = struct.unpack("<II", donnees[12:20])
    positions = struct.unpack("<16I", donnees[20:84])
    gauche, haut, droite, bas = CASES
    niveau = 0
    while niveau < 16 and positions[niveau]:
        blocs_ligne = max(1, (largeur >> niveau) // 4)
        reduction = 1 << niveau
        for by in range(haut // reduction // 4, max(haut // reduction // 4 + 1, bas // reduction // 4)):
            for bx in range(gauche // reduction // 4, max(gauche // reduction // 4 + 1, droite // reduction // 4)):
                debut = positions[niveau] + (by * blocs_ligne + bx) * 16
                donnees[debut:debut + 8] = bytes(8)
        niveau += 1
        if niveau > 3:
            break   # cases de moins de 4 pixels : plus petites qu'un bloc, laissées telles quelles
    return bytes(donnees)


if __name__ == "__main__":
    donnees = original()
    assert donnees, "ObjectIcons.blp introuvable dans le client"
    os.makedirs(os.path.dirname(SORTIE), exist_ok=True)
    with open(SORTIE, "wb") as f:
        f.write(effacer(donnees))
    print("Écrit :", SORTIE)
