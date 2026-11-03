"""Sol'Azeroth : icônes d'objets repeintes dans le style « bronze et parchemin » (demande du 03/11/2026).

L'icône d'un objet et son modèle porté viennent de la même ligne d'ItemDisplayInfo.dbc (colonne 5 : InventoryIcon_1) :
l'icône montre donc déjà la pièce telle qu'on la voit équipée. On garde le même dessin, en meilleure définition : la
version retail de la même icône (même nom, https://wow.zamimg.com/images/wow/icons/large/<nom>.jpg, 56 x 56), passée
en 64 x 64 avec un vernis peint, un étalonnage chaud et un assombrissement des bords. Le BLP prend le nom de l'icône
d'origine (Interface\\Icons\\<nom>.blp) et la remplace partout dans le jeu.

Les icônes sont celles de nos objets (item_template, entrée >= 900000) ; les téléchargements sont gardés dans
C:\\SolAzeroth\\icones-retail\\objets. Celles déjà prises sur retail (SolAzeroth_*) ne sont pas touchées.

Usage : py -3.11 outils\\icones_bronze.py   puis   py outils\\construire_patch.py
"""
import math
import os
import time
import urllib.error
import urllib.request

import dbc
from butin_v3 import requete
from icones_retail import DOSSIER, ITEMDISPLAYINFO, blp_avec_mipmaps

SOURCES = r"C:\SolAzeroth\icones-retail\objets"
ADRESSE = "https://wow.zamimg.com/images/wow/icons/large/{}.jpg"


def icones_des_objets():
    d = dbc.Dbc.ouvrir(ITEMDISPLAYINFO)
    noms = {e[0]: d.texte(e[5]) for e in d.enregistrements}
    affichages = {int(l[0]) for l in requete("SELECT DISTINCT displayid FROM item_template WHERE entry >= 900000")}
    return sorted({noms[a] for a in affichages if a in noms and noms[a] and not noms[a].startswith("SolAzeroth_")})


def telecharger(nom):
    chemin = os.path.join(SOURCES, nom.lower() + ".jpg")
    if not os.path.exists(chemin):
        try:
            with urllib.request.urlopen(ADRESSE.format(nom.lower()), timeout=20) as r:
                donnees = r.read()
        except urllib.error.HTTPError:
            return None
        with open(chemin, "wb") as f:
            f.write(donnees)
        time.sleep(0.2)
    return chemin


def bronzer(image):
    """Vernis peint (médian puis netteté), un quart de camaïeu bronze, bords assombris."""
    from PIL import Image, ImageEnhance, ImageFilter, ImageOps
    image = image.convert("RGB").resize((64, 64), Image.LANCZOS)
    image = image.filter(ImageFilter.MedianFilter(3)).filter(ImageFilter.UnsharpMask(1.2, 60, 2))
    camaieu = ImageOps.colorize(ImageOps.grayscale(image), (34, 24, 10), (246, 230, 190), (150, 112, 58))
    image = Image.blend(image, camaieu, 0.28)
    image = ImageEnhance.Contrast(ImageEnhance.Color(image).enhance(0.92)).enhance(1.08)
    pixels = image.load()
    for y in range(64):
        for x in range(64):
            k = 1 - 0.42 * max(0.0, math.hypot(x - 31.5, y - 31.5) / 45.0 - 0.45) / 0.55
            r, v, b = pixels[x, y]
            pixels[x, y] = (int(r * k), int(v * k), int(b * k))
    return image


def convertir():
    from PIL import Image
    os.makedirs(SOURCES, exist_ok=True)
    faites, absentes = 0, []
    for nom in icones_des_objets():
        chemin = telecharger(nom)
        if not chemin:
            absentes.append(nom)
            continue
        with open(os.path.join(DOSSIER, nom + ".blp"), "wb") as f:
            f.write(blp_avec_mipmaps(bronzer(Image.open(chemin))))
        faites += 1
    return faites, absentes


if __name__ == "__main__":
    faites, absentes = convertir()
    print(faites, "icônes repeintes ;", len(absentes), "absentes de retail (gardées d'origine) :", ", ".join(absentes))
