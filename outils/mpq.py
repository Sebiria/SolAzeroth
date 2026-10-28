"""Sol'Azeroth : lecture et écriture d'archives MPQ (format v1, celui du client 3.3.5).

Lecture : s'appuie sur la bibliothèque mpyq (pip install mpyq).
Écriture : archive v1, fichiers compressés en zlib secteur par secteur, non chiffrés,
avec un (listfile) pour que les outils puissent relire la liste des fichiers.
"""
import struct
import zlib

import mpyq

TAILLE_SECTEUR = 4096  # 512 << 3

_TABLE = []


def _preparer_table():
    graine = 0x00100001
    table = [0] * 0x500
    for i in range(0x100):
        index = i
        for _ in range(5):
            graine = (graine * 125 + 3) % 0x2AAAAB
            haut = (graine & 0xFFFF) << 16
            graine = (graine * 125 + 3) % 0x2AAAAB
            table[index] = haut | (graine & 0xFFFF)
            index += 0x100
    return table


_TABLE = _preparer_table()


def hacher(nom, type_hachage):
    """Hachage MPQ : 0 = position dans la table, 1 et 2 = vérifications, 3 = clé."""
    graine1, graine2 = 0x7FED7FED, 0xEEEEEEEE
    for c in nom.upper().replace("/", "\\"):
        valeur = ord(c)
        graine1 = _TABLE[(type_hachage << 8) + valeur] ^ ((graine1 + graine2) & 0xFFFFFFFF)
        graine2 = (valeur + graine1 + graine2 + (graine2 << 5) + 3) & 0xFFFFFFFF
    return graine1


def _chiffrer(donnees, cle):
    mots = struct.unpack("<%dI" % (len(donnees) // 4), donnees)
    graine = 0xEEEEEEEE
    sortie = []
    for mot in mots:
        graine = (graine + _TABLE[0x400 + (cle & 0xFF)]) & 0xFFFFFFFF
        sortie.append((mot ^ (cle + graine)) & 0xFFFFFFFF)
        cle = ((((~cle) << 0x15) + 0x11111111) | (cle >> 0x0B)) & 0xFFFFFFFF
        graine = (mot + graine + (graine << 5) + 3) & 0xFFFFFFFF
    return struct.pack("<%dI" % len(sortie), *sortie)


def _compresser(contenu):
    """Découpe en secteurs : table des positions, puis chaque secteur (0x02 + zlib, ou brut)."""
    secteurs = []
    for debut in range(0, len(contenu), TAILLE_SECTEUR):
        brut = contenu[debut:debut + TAILLE_SECTEUR]
        compresse = b"\x02" + zlib.compress(brut, 9)
        secteurs.append(compresse if len(compresse) < len(brut) else brut)
    position = 4 * (len(secteurs) + 1)
    positions = [position]
    for s in secteurs:
        position += len(s)
        positions.append(position)
    return struct.pack("<%dI" % len(positions), *positions) + b"".join(secteurs)


def ecrire(chemin, fichiers):
    """Écrit une archive MPQ. fichiers : dict {nom interne (ex. 'DBFilesClient\\\\Spell.dbc'): bytes}."""
    fichiers = dict(fichiers)
    noms = sorted(fichiers)
    fichiers["(listfile)"] = ("\r\n".join(noms) + "\r\n").encode("ascii")
    noms.append("(listfile)")

    taille_hachage = 16
    while taille_hachage < len(noms) * 2:
        taille_hachage *= 2

    corps = bytearray()
    blocs = []
    for nom in noms:
        contenu = fichiers[nom]
        donnees = _compresser(contenu)
        blocs.append((32 + len(corps), len(donnees), len(contenu), 0x80000200))
        corps += donnees

    hachage = [(0xFFFFFFFF, 0xFFFFFFFF, 0xFFFF, 0xFFFF, 0xFFFFFFFF)] * taille_hachage
    for index, nom in enumerate(noms):
        position = hacher(nom, 0) % taille_hachage
        while hachage[position][4] != 0xFFFFFFFF:
            position = (position + 1) % taille_hachage
        hachage[position] = (hacher(nom, 1), hacher(nom, 2), 0, 0, index)

    table_hachage = b"".join(struct.pack("<IIHHI", *e) for e in hachage)
    table_blocs = b"".join(struct.pack("<IIII", *b) for b in blocs)
    position_hachage = 32 + len(corps)
    position_blocs = position_hachage + len(table_hachage)
    taille_totale = position_blocs + len(table_blocs)

    entete = struct.pack("<4sIIHHIIII", b"MPQ\x1a", 32, taille_totale, 0, 3,
                         position_hachage, position_blocs, taille_hachage, len(blocs))
    with open(chemin, "wb") as f:
        f.write(entete)
        f.write(corps)
        f.write(_chiffrer(table_hachage, hacher("(hash table)", 3)))
        f.write(_chiffrer(table_blocs, hacher("(block table)", 3)))


def lire(chemin, nom):
    """Renvoie le contenu d'un fichier de l'archive (bytes), ou None s'il n'y est pas."""
    return mpyq.MPQArchive(chemin, listfile=False).read_file(nom)


def lister(chemin):
    """Liste des fichiers d'après le (listfile) ; vide si l'archive n'en a pas."""
    archive = mpyq.MPQArchive(chemin)
    return [n.decode() if isinstance(n, bytes) else n for n in (archive.files or [])]
