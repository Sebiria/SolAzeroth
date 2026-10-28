"""Sol'Azeroth : lecture et écriture des fichiers DBC (format WDBC du client 3.3.5).

Chaque enregistrement est une liste de champs de 4 octets, lus comme entiers non signés.
Les chaînes sont des positions dans le bloc de texte : utiliser texte() et ajouter_texte().
Les flottants se lisent avec flottant() et s'écrivent avec depuis_flottant().
"""
import struct


class Dbc:
    def __init__(self, donnees):
        magie, nb, nb_champs, taille_enr, taille_texte = struct.unpack_from("<4s4I", donnees)
        if magie != b"WDBC" or taille_enr != nb_champs * 4:
            raise ValueError("DBC non pris en charge")
        self.nb_champs = nb_champs
        self.enregistrements = [
            list(struct.unpack_from("<%dI" % nb_champs, donnees, 20 + i * taille_enr))
            for i in range(nb)
        ]
        debut = 20 + nb * taille_enr
        self.bloc_texte = bytearray(donnees[debut:debut + taille_texte])
        self._positions = {}

    @classmethod
    def ouvrir(cls, chemin):
        with open(chemin, "rb") as f:
            return cls(f.read())

    def texte(self, position):
        fin = self.bloc_texte.index(b"\0", position)
        return self.bloc_texte[position:fin].decode("utf-8")

    def ajouter_texte(self, chaine):
        """Ajoute une chaîne (réutilisée si déjà ajoutée) et renvoie sa position."""
        if not chaine:
            return 0
        if chaine not in self._positions:
            self._positions[chaine] = len(self.bloc_texte)
            self.bloc_texte += chaine.encode("utf-8") + b"\0"
        return self._positions[chaine]

    def chercher(self, identifiant, colonne=0):
        for enr in self.enregistrements:
            if enr[colonne] == identifiant:
                return enr
        return None

    def octets(self):
        entete = struct.pack("<4s4I", b"WDBC", len(self.enregistrements), self.nb_champs,
                             self.nb_champs * 4, len(self.bloc_texte))
        corps = b"".join(struct.pack("<%dI" % self.nb_champs, *e) for e in self.enregistrements)
        return entete + corps + bytes(self.bloc_texte)

    def enregistrer(self, chemin):
        with open(chemin, "wb") as f:
            f.write(self.octets())


def flottant(valeur):
    return struct.unpack("<f", struct.pack("<I", valeur))[0]


def depuis_flottant(valeur):
    return struct.unpack("<I", struct.pack("<f", valeur))[0]
