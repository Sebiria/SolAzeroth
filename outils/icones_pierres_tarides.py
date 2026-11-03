"""Lot T8 des Tarides (03/11/2026) : icônes des trois pierres taillées des Tarides, sans téléchargement.

Chacune est une variante recolorée d'une pierre taillée de Durotar (icônes retail de icones_retail.py), écrite dans
icones-retail\\sources : Agate mousse taillée (vert mousse, d'après la Malachite taillée), Jade taillé (vert de jade
clair) et Pierre de lune taillée (blanc bleuté, d'après l'Œil ténébreux taillé). icones_retail.py les convertit ensuite
en BLP comme les autres.

py -3.11 icones_pierres_tarides.py   (il faut Pillow)
"""
import colorsys
import os

from PIL import Image

SOURCES = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "icones-retail", "sources")
# (icône écrite, icône de départ, teinte visée de 0 à 1, saturation multipliée, luminosité multipliée)
VARIANTES = [
    ("solazeroth_cutgem_agate", "inv_jewelcrafting_80_cutgem01_green", 0.22, 0.55, 0.95),
    ("solazeroth_cutgem_jade", "inv_jewelcrafting_80_cutgem01_green", 0.42, 0.75, 1.10),
    ("solazeroth_cutgem_lune", "inv_jewelcrafting_80_cutgem01_purple", 0.58, 0.25, 1.35),
]


def recolorer(image, teinte, saturation, luminosite):
    pixels = image.load()
    for x in range(image.width):
        for y in range(image.height):
            r, g, b = (c / 255 for c in pixels[x, y])
            h, s, v = colorsys.rgb_to_hsv(r, g, b)
            if s > 0.15:   # le cadre et les reflets gris restent
                h, s = teinte, min(1.0, s * saturation)
            v = min(1.0, v * luminosite)
            pixels[x, y] = tuple(round(c * 255) for c in colorsys.hsv_to_rgb(h, s, v))
    return image


def main():
    for nom, depart, teinte, saturation, luminosite in VARIANTES:
        image = Image.open(os.path.join(SOURCES, depart + ".jpg")).convert("RGB")
        recolorer(image, teinte, saturation, luminosite).save(os.path.join(SOURCES, nom + ".jpg"), quality=95)
        print("écrit :", nom + ".jpg")


if __name__ == "__main__":
    main()
