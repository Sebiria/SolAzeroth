"""Sol'Azeroth v3 : icônes modernes prises sur la version retail (demande de l'utilisateur du 31/10/2026).

Les images viennent du serveur d'icônes de Wowhead (https://wow.zamimg.com/images/wow/icons/large/<nom>.jpg, 56 x 56),
rangées dans C:\\SolAzeroth\\icones-retail\\sources. Ce script :
- les convertit en BLP 64 x 64 dans patch-client\\fichiers\\Interface\\Icons (il faut Pillow : py -3.11, celui de
  Python 3.14 est cassé) ;
- les ajoute à patch-client\\fichiers\\DBFilesClient\\SpellIcon.dbc (fonction ajouter_au_dbc, aussi appelée par
  icones_macros.py, qui réécrit ce fichier).

Usage : py -3.11 outils\\icones_retail.py   puis   py outils\\auras_nommees.py   puis   py outils\\construire_patch.py
"""
import os

import dbc

SOURCES = r"C:\SolAzeroth\icones-retail\sources"
DOSSIER = r"C:\SolAzeroth\patch-client\fichiers\Interface\Icons"
SPELLICON = r"C:\SolAzeroth\patch-client\fichiers\DBFilesClient\SpellIcon.dbc"

# Icônes utilisées par le kit du guerrier tank (techniques_v3.py).
ICONES = [
    "inv_shield_1h_artifactmagnar_d_01",    # Rempart
    "inv_shield_1h_artifactmagnar_d_02",    # Riposte du rempart
    "ability_warrior_shieldcharge",         # Frappe du bouclier
    "warrior_talent_icon_bloodandthunder",  # Coup de tonnerre
    "ability_warrior_charge",               # Charge
    "ability_warrior_bullrush",             # Cri de défi
    "ability_warrior_renewedvigor",         # Second souffle
    "warrior_talent_icon_ravager",          # Ravage
    "ability_warrior_shieldwall",           # Mur protecteur
    "ability_warrior_shieldbreak",          # Heurt de bouclier
    "ability_warrior_colossussmash",        # Fracasser armure
    "ability_warrior_disarm",               # Désarmement
    "ability_warrior_shockwave",            # Onde de choc
    "ability_heroicleap",                   # Bond héroïque
    "ability_warrior_shieldreflection",     # Renvoi de sort
    "warrior_talent_icon_igniteweapon",     # Vengeance
    "ability_warrior_improveddisciplines",  # Dernier rempart
]


def chemin_jeu(nom):
    return "Interface\\Icons\\SolAzeroth_" + nom


def ajouter_au_dbc(icones):
    """Ajoute les icônes absentes de SpellIcon.dbc (patch client) ; rend {nom: identifiant}."""
    d = dbc.Dbc.ouvrir(SPELLICON)
    connues = {d.texte(e[1]).lower(): e[0] for e in d.enregistrements}
    prochain = max(e[0] for e in d.enregistrements) + 1
    ids = {}
    for nom in icones:
        chemin = chemin_jeu(nom)
        if chemin.lower() not in connues:
            d.enregistrements.append([prochain, d.ajouter_texte(chemin)])
            connues[chemin.lower()] = prochain
            prochain += 1
        ids[nom] = connues[chemin.lower()]
    d.enregistrer(SPELLICON)
    return ids


def identifiants():
    """{nom: identifiant} des icônes déjà ajoutées (sans modifier le fichier)."""
    d = dbc.Dbc.ouvrir(SPELLICON)
    connues = {d.texte(e[1]).lower(): e[0] for e in d.enregistrements}
    return {nom: connues[chemin_jeu(nom).lower()] for nom in ICONES}


def convertir():
    from PIL import Image
    os.makedirs(DOSSIER, exist_ok=True)
    for nom in ICONES:
        image = Image.open(os.path.join(SOURCES, nom + ".jpg")).convert("RGB").resize((64, 64), Image.LANCZOS)
        with open(os.path.join(DOSSIER, "SolAzeroth_" + nom + ".blp"), "wb") as f:
            f.write(blp_avec_mipmaps(image))


def blp_avec_mipmaps(image):
    """BLP2 à palette, avec ses 7 niveaux de réduction (64 à 1 pixel).

    Le BLP de Pillow n'a qu'un niveau : le curseur l'affiche, mais les barres d'action, qui lisent un niveau réduit,
    montraient un carré vert (essai en jeu du 31/10/2026). Les icônes de Blizzard ont toutes leurs réductions.
    """
    import struct
    from PIL import Image
    palette = image.quantize(256)
    niveaux = []
    taille = image.size[0]
    while taille >= 1:
        reduite = image if taille == image.size[0] else image.resize((taille, taille), Image.LANCZOS)
        niveaux.append(reduite.quantize(palette=palette, dither=Image.Dither.NONE).tobytes())
        taille //= 2
    couleurs = palette.getpalette()[:768] + [0] * (768 - len(palette.getpalette()[:768]))
    bgra = b"".join(struct.pack("<4B", couleurs[i * 3 + 2], couleurs[i * 3 + 1], couleurs[i * 3], 255) for i in range(256))
    position = 20 + 64 + 64 + len(bgra)
    positions, tailles = [], []
    for n in niveaux:
        positions.append(position)
        tailles.append(len(n))
        position += len(n)
    positions += [0] * (16 - len(positions))
    tailles += [0] * (16 - len(tailles))
    # type 1, compression 1 (palette), sans alpha, réductions présentes (comme les icônes de Blizzard : 0x11)
    entete = b"BLP2" + struct.pack("<I4BII", 1, 1, 0, 0, 0x11, image.size[0], image.size[1])
    return entete + struct.pack("<16I", *positions) + struct.pack("<16I", *tailles) + bgra + b"".join(niveaux)


if __name__ == "__main__":
    convertir()
    print(len(ajouter_au_dbc(ICONES)), "icônes retail converties et inscrites dans SpellIcon.dbc.")
