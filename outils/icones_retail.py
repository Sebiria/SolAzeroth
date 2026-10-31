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
    "inv_alchemy_80_potion01red",           # Potion de soins (bivouac_v3.py)
    "campfire_rootflame",                   # Feu de camp : icône 7479490 de Wowhead (Rootflame Campfire), sans nom
]

# Part centrale gardée (le reste est coupé) : le feu de camp était petit dans son bouton (demande du 31/10/2026).
RECADRAGE = {"campfire_rootflame": 0.72}


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
        image = Image.open(os.path.join(SOURCES, nom + ".jpg")).convert("RGB")
        if nom in RECADRAGE:
            cote = image.width * RECADRAGE[nom]
            marge = (image.width - cote) / 2
            image = image.crop((round(marge), round(marge), round(marge + cote), round(marge + cote)))
        image = image.resize((64, 64), Image.LANCZOS)
        with open(os.path.join(DOSSIER, "SolAzeroth_" + nom + ".blp"), "wb") as f:
            f.write(blp_avec_mipmaps(image))


def blp_avec_mipmaps(image):
    """BLP2 compressé en DXT1, sans transparence, avec ses 7 niveaux de réduction (64 à 1 pixel).

    C'est le format des icônes de Blizzard (Ability_Warrior_ShieldBash : compression 2, alpha 0, réductions 0x11).
    Essais en jeu du 31/10/2026 : un BLP à palette, avec ou sans réductions, s'affichait en carré vert sur les barres
    d'action (seul le curseur du glisser-déposer le montrait). Aucune icône de Blizzard n'est à palette.
    """
    import io
    import struct
    from PIL import Image
    niveaux = []
    taille = image.size[0]
    while taille >= 1:
        reduite = image if taille == image.size[0] else image.resize((taille, taille), Image.LANCZOS)
        dds = io.BytesIO()
        reduite.save(dds, "DDS", pixel_format="DXT1")
        niveaux.append(dds.getvalue()[128:])   # blocs DXT1, sans l'en-tête DDS de 128 octets
        taille //= 2
    bgra = bytes(1024)                         # palette inutilisée, présente dans l'en-tête comme chez Blizzard
    position = 20 + 64 + 64 + len(bgra)
    positions, tailles = [], []
    for n in niveaux:
        positions.append(position)
        tailles.append(len(n))
        position += len(n)
    positions += [0] * (16 - len(positions))
    tailles += [0] * (16 - len(tailles))
    # type 1, compression 2 (DXT), alpha 0, type d'alpha 0 (DXT1), réductions présentes (0x11)
    entete = b"BLP2" + struct.pack("<I4BII", 1, 2, 0, 0, 0x11, image.size[0], image.size[1])
    return entete + struct.pack("<16I", *positions) + struct.pack("<16I", *tailles) + bgra + b"".join(niveaux)


if __name__ == "__main__":
    convertir()
    print(len(ajouter_au_dbc(ICONES)), "icônes retail converties et inscrites dans SpellIcon.dbc.")
