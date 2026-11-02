"""Prépare les fichiers de l'interface v3 (F4) dans patch-client\\fichiers, avant construire_patch.py.

Usage : py -3.11 outils\\interface_v3.py   (Pillow et fontTools ; le Pillow de 3.14 est cassé)

- Polices : graisses statiques tirées d'Inter variable (interface-v3\\sources\\InterVariable.ttf, rsms/inter v4.1,
  licence OFL) -> Interface\\SolAzeroth\\Polices\\Inter-*.ttf.
- Textures (TGA 32 bits, tracées ici) -> Interface\\SolAzeroth\\Textures\\*.tga.
- Code : interface-v3\\FrameXML\\*.lua, copié dans Interface\\FrameXML et ajouté au FrameXML.toc du client
  (repris de ses archives, avant « ## add new modules above here »).
- Audit du jeu, lot 6a (02/11/2026, C9 ; choix de l'utilisateur : « grisés bientôt ») : création limitée à l'orc et au
  troll guerriers. Le CharacterCreate.lua du client (GlueXML) est repris de ses archives et modifié ici (creation()) :
  les autres races et classes restent visibles, grisées, avec « pas encore prêt » au survol ; le serveur les refuse
  aussi (scripts\configurer.ps1, CharacterCreating.Disabled.RaceMask et ClassMask).
"""
import math
import os
import shutil
import subprocess
import sys

from PIL import Image, ImageDraw

RACINE = r"C:\SolAzeroth"
SOURCES = os.path.join(RACINE, "interface-v3")
FICHIERS = os.path.join(RACINE, "patch-client", "fichiers")
POLICES = os.path.join(FICHIERS, "Interface", "SolAzeroth", "Polices")
TEXTURES = os.path.join(FICHIERS, "Interface", "SolAzeroth", "Textures")
FRAMEXML = os.path.join(FICHIERS, "Interface", "FrameXML")

# Ordre de chargement de notre code dans FrameXML.toc.
CODE = ["SolUI_Base.lua", "SolUI_Cacher.lua", "SolUI_Perso.lua", "SolUI_Techniques.lua", "SolUI_Cible.lua", "SolUI_Plaques.lua",
        "SolUI_Zone.lua", "SolUI_Cartes.lua", "SolUI_Puissances.lua", "SolUI_Versions.lua", "SolUI_Quetes.lua", "SolUI_Dialogue.lua",
        "SolUI_Discussion.lua", "SolUI_Camp.lua", "SolUI_Bivouac.lua", "SolUI_Raccourcis.lua",
        "SolUI_Catalogue.lua", "SolUI_Annexes.lua", "SolUI_Joaillerie.lua", "SolUI_Collection.lua", "SolUI_Inventaire.lua", "SolUI_Recettes.lua", "SolUI_RecettesGouffre.lua", "SolUI_RecettesSurplus.lua", "SolUI_Cuisine.lua",
        "SolUI_Enchantements.lua", "SolUI_Equipement.lua", "SolUI_AventurierDonnees.lua", "SolUI_Aventurier.lua", "SolUI_PassifsDonnees.lua", "SolUI_Passifs.lua", "SolUI_Lexique.lua", "SolUI_Paroles.lua", "SolUI_Carnets.lua", "SolUI_Barre.lua", "SolUI_Soldes.lua", "SolUI_Signalement.lua",
        "SolUI_Reglages.lua", "SolUI_Options.lua", "SolUI_Fiche.lua"]
GENERES = {"SolUI_Cartes.lua"}   # écrits par ce script, pas copiés de interface-v3\FrameXML

GRAISSES = {"Light": 300, "Regular": 400, "SemiBold": 600, "Bold": 700}

SUR = 4  # suréchantillonnage des textures (anticrénelage)


# ---------------------------------------------------------------- Polices

def polices():
    from fontTools.ttLib import TTFont
    from fontTools.varLib import instancer

    os.makedirs(POLICES, exist_ok=True)
    source = os.path.join(SOURCES, "sources", "InterVariable.ttf")
    for nom, graisse in GRAISSES.items():
        police = instancer.instantiateVariableFont(TTFont(source), {"wght": graisse, "opsz": 14})
        police.save(os.path.join(POLICES, "Inter-%s.ttf" % nom))
    shutil.copy2(os.path.join(SOURCES, "sources", "Inter-LICENSE.txt"), os.path.join(POLICES, "Inter-LICENSE.txt"))


# ---------------------------------------------------------------- Textures

def enregistrer(image, nom, largeur, hauteur):
    image.resize((largeur, hauteur), Image.LANCZOS).save(os.path.join(TEXTURES, nom + ".tga"))


def blanc(largeur, hauteur):
    return Image.new("RGBA", (largeur * SUR, hauteur * SUR), (255, 255, 255, 0))


def arc(nom, epaisseur):
    """Arc gauche du cercle de la maquette Synthèse (rayon 125), de 35° à 145° depuis le bas, extrémités rondes.

    La texture (128 x 512) couvre une zone de 64 x 256 unités, centre du cercle en (128, 128) : l'interface la recadre
    verticalement pour la remplir de bas en haut (SolUI_Perso.lua)."""
    l, h = 128, 512
    image = blanc(l, h)
    dessin = ImageDraw.Draw(image)
    echelle = SUR * 2  # 2 pixels par unité
    cx, cy, r, e = 128 * echelle, 128 * echelle, 125 * echelle, epaisseur * echelle
    # Angles de Pillow : 0° à droite, sens horaire. 35° depuis le bas, côté gauche = 90 + 35 = 125°.
    dessin.arc((cx - r - e / 2, cy - r - e / 2, cx + r + e / 2, cy + r + e / 2), 125, 235, fill="white", width=int(e))
    for angle in (125, 235):
        x = cx + r * math.cos(math.radians(angle))
        y = cy + r * math.sin(math.radians(angle))
        dessin.ellipse((x - e / 2, y - e / 2, x + e / 2, y + e / 2), fill="white")
    enregistrer(image, nom, l, h)


def anneau(nom, taille, epaisseur, plein=False):
    image = blanc(taille, taille)
    dessin = ImageDraw.Draw(image)
    e = epaisseur * SUR
    t = taille * SUR
    if plein:
        dessin.ellipse((0, 0, t - 1, t - 1), fill="white")
    else:
        dessin.ellipse((e / 2, e / 2, t - e / 2, t - e / 2), outline="white", width=int(e))
    enregistrer(image, nom, taille, taille)


def rectangle_arrondi(nom, taille, rayon, epaisseur=None):
    image = blanc(taille, taille)
    dessin = ImageDraw.Draw(image)
    t, r = taille * SUR, rayon * SUR
    if epaisseur is None:
        dessin.rounded_rectangle((0, 0, t - 1, t - 1), r, fill="white")
    else:
        e = epaisseur * SUR
        dessin.rounded_rectangle((e / 2, e / 2, t - e / 2, t - e / 2), r, outline="white", width=int(e))
    enregistrer(image, nom, taille, taille)


def halo(nom, taille, interieur):
    """Lueur douce autour d'un bouton : forte au bord du bouton, nulle au bord de la texture."""
    image = Image.new("RGBA", (taille, taille), (255, 255, 255, 0))
    pixels = image.load()
    demi = taille / 2
    for y in range(taille):
        for x in range(taille):
            # distance à un carré de demi-côté « interieur » (en pixels), comme un rectangle arrondi épais
            dx = max(abs(x + 0.5 - demi) - interieur, 0)
            dy = max(abs(y + 0.5 - demi) - interieur, 0)
            d = math.hypot(dx, dy) / (demi - interieur)
            pixels[x, y] = (255, 255, 255, int(255 * max(0.0, 1 - d) ** 2))
    image.save(os.path.join(TEXTURES, nom + ".tga"))


def losange(nom, taille, epaisseur, plein=False):
    image = blanc(taille, taille)
    dessin = ImageDraw.Draw(image)
    t, e = taille * SUR, epaisseur * SUR
    m = e
    dessin.polygon([(t / 2, m), (t - m, t / 2), (t / 2, t - m), (m, t / 2)], outline="white", width=int(e),
                   fill="white" if plein else None)
    enregistrer(image, nom, taille, taille)


def bouclier(nom, taille, epaisseur):
    """Petit bouclier au trait, d'après la maquette (losange du passif)."""
    image = blanc(taille, taille)
    dessin = ImageDraw.Draw(image)
    k = taille * SUR / 12.0
    points = [(6, 1), (10, 2.5), (10, 6), (9, 8.6), (6, 11), (3, 8.6), (2, 6), (2, 2.5), (6, 1)]
    dessin.line([(x * k, y * k) for x, y in points], fill="white", width=int(epaisseur * SUR), joint="curve")
    enregistrer(image, nom, taille, taille)


def faucille(nom, taille, epaisseur):
    """Petite faucille au trait (losange du passif Moisson du démoniste, lot D2) : lame en arc, manche oblique."""
    image = blanc(taille, taille)
    dessin = ImageDraw.Draw(image)
    k = taille * SUR / 12.0
    largeur = int(epaisseur * SUR)
    dessin.arc((1.5 * k, 1.5 * k, 9.5 * k, 9.5 * k), 150, 360, fill="white", width=largeur)   # dos de la lame
    dessin.arc((2.8 * k, 3.6 * k, 8.8 * k, 9.6 * k), 165, 345, fill="white", width=largeur)   # tranchant
    dessin.line([(9.4 * k, 5.5 * k), (7.4 * k, 11 * k)], fill="white", width=largeur)          # manche
    dessin.line([(2.0 * k, 7.5 * k), (2.9 * k, 7.4 * k)], fill="white", width=largeur)          # pointe
    enregistrer(image, nom, taille, taille)


def epingle(nom, retrait=0.0, flou=0):
    """Épingle de la mini-carte (maquette « Épingle », 01/11/2026) dans une texture de 64 x 64 : rond en haut, pointe en
    bas au centre (le point visé). Rond de rayon 23 centré en (32, 25,6), pointe en (32, 61,4). « retrait » rétrécit la
    forme de ce nombre de pixels (intérieur, sous le contour) ; « flou » l'adoucit (ombre)."""
    image = blanc(64, 64)
    dessin = ImageDraw.Draw(image)
    k = SUR
    cx, cy, r, pointe = 32 * k, 25.6 * k, (23 - retrait) * k, (61.4 - retrait * 1.6) * k
    dessin.ellipse((cx - r, cy - r, cx + r, cy + r), fill="white")
    # Tangentes du rond vers la pointe.
    d = pointe - cy
    angle = math.asin(min(1.0, r / d))
    tx = r * math.cos(angle)
    ty = r * math.sin(angle)
    dessin.polygon([(cx - tx, cy + ty), (cx + tx, cy + ty), (cx, pointe)], fill="white")
    if flou:
        from PIL import ImageFilter
        image = image.filter(ImageFilter.GaussianBlur(flou * k))
    enregistrer(image, nom, 64, 64)


def fleche(nom):
    """Petit triangle tourné vers la droite, au centre d'une texture de 32 x 32 (tourné en jeu par SetTexCoord)."""
    image = blanc(32, 32)
    dessin = ImageDraw.Draw(image)
    k = SUR
    dessin.polygon([(10 * k, 8 * k), (24 * k, 16 * k), (10 * k, 24 * k)], fill="white")
    enregistrer(image, nom, 32, 32)


def textures():
    os.makedirs(TEXTURES, exist_ok=True)
    arc("Arc", 3)
    arc("ArcLarge", 5)
    anneau("Anneau", 128, 3)
    anneau("Rond", 64, 0, plein=True)
    rectangle_arrondi("Bouton", 128, 28)
    rectangle_arrondi("BoutonBord", 128, 28, 3)
    halo("Halo", 64, 20)
    losange("Losange", 64, 3)
    losange("LosangePlein", 64, 3, plein=True)   # fond du losange du passif (02/11/2026)
    bouclier("Bouclier", 64, 1.8)   # trait plus épais : losange du passif plus lisible (02/11/2026)
    faucille("Moisson", 64, 1.8)
    epingle("Epingle")
    epingle("EpingleCreux", 4)
    epingle("EpingleOmbre", 0, 2)
    fleche("Fleche")
    enregistrer(blanc(8, 8), "Vide", 8, 8)   # transparente : flèche d'objectif du jeu sur la mini-carte


# ---------------------------------------------------------------- Code et FrameXML.toc

def dossier_client():
    with open(os.path.join(RACINE, "config", "client.txt"), encoding="utf-8-sig") as f:
        return f.readline().strip()


LIRE_TOC = r"""
import os, sys
sys.path.insert(0, sys.argv[1])
import mpq
for archive in ["patch-frFR-3.MPQ", "patch-frFR-2.MPQ", "patch-frFR.MPQ", "locale-frFR.MPQ"]:
    contenu = mpq.lire(os.path.join(sys.argv[2], archive), sys.argv[3])
    if contenu:
        sys.stdout.buffer.write(contenu)
        break
"""


def du_client(nom):
    """Un fichier de l'interface du client, du patch de langue le plus récent au plus ancien.

    La lecture des MPQ (mpyq) n'est installée que pour Python 3.14 : on passe par lui."""
    data = os.path.join(dossier_client(), "Data", "frFR")
    outils = os.path.dirname(os.path.abspath(__file__))
    contenu = subprocess.run(["py", "-3.14", "-c", LIRE_TOC, outils, data, nom], capture_output=True, check=True).stdout
    if not contenu:
        raise RuntimeError(nom + " introuvable dans les archives du client")
    return contenu.decode("utf-8")


def toc_du_client():
    return du_client("Interface\\FrameXML\\FrameXML.toc")


# Lot 6a : ce qui est prêt à la création (noms de fichier de GetAvailableRaces et GetAvailableClasses).
# Démoniste, lot D1 (02/11/2026) : ouvert à la création.
RACES_PRETES, CLASSES_PRETES = ("ORC", "TROLL"), ("WARRIOR", "WARLOCK")
PAS_PRET = "|cffff9080Pas encore prêt : seuls l'orc et le troll, guerriers ou démonistes, ont leur zone de départ.|r"
CREATION = [
    # Les races et classes qui ne sont pas prêtes : grisées, avec le message au survol.
    ("""		if ( select(i+2, ...) == 1 ) then
			button.enable = true;
			SetButtonDesaturated(button);""",
     """		if ( select(i+2, ...) == 1 and SOL_PRETES[strupper(select(i+1, ...))] ) then
			button.enable = true;
			SetButtonDesaturated(button);"""),
    ("""			button.tooltip = _G[strupper(select(i+1, ...).."_".."DISABLED")];
		end
		index = index + 1;
	end
	for i=CharacterCreate.numRaces + 1, MAX_RACES, 1 do""",
     """			button.tooltip = select(i+2, ...) == 1 and (select(i, ...).."|n"..SOL_PAS_PRET)
				or _G[strupper(select(i+1, ...).."_".."DISABLED")];
		end
		index = index + 1;
	end
	for i=CharacterCreate.numRaces + 1, MAX_RACES, 1 do"""),
    ("""		if ( (select(i+2, ...) == 1) and (IsRaceClassValid(CharacterCreate.selectedRace, index)) ) then""",
     """		if ( (select(i+2, ...) == 1) and (IsRaceClassValid(CharacterCreate.selectedRace, index))
			and SOL_PRETES[strupper(select(i+1, ...))] ) then"""),
    ("""			button.tooltip = _G[strupper(select(i+1, ...).."_".."DISABLED")];
			_G["CharacterCreateClassButton"..index.."DisableTexture"]:Show();""",
     """			button.tooltip = (select(i+2, ...) == 1 and IsRaceClassValid(CharacterCreate.selectedRace, index))
				and (select(i, ...).."|n"..SOL_PAS_PRET) or _G[strupper(select(i+1, ...).."_".."DISABLED")];
			_G["CharacterCreateClassButton"..index.."DisableTexture"]:Show();"""),
    # À l'ouverture (le jeu tire une combinaison au hasard) : un orc guerrier si le tirage n'est pas prêt.
    ("""		ResetCharCustomize();
		CharacterCreateNameEdit:SetText("");""",
     """		ResetCharCustomize();
		SolChoixPret();
		CharacterCreateNameEdit:SetText("");"""),
]


def creation():
    """CharacterCreate.lua du client, limité à ce qui est prêt."""
    texte = du_client("Interface\\GlueXML\\CharacterCreate.lua").replace("\r\n", "\n")
    for avant, apres in CREATION:
        assert texte.count(avant) == 1, avant
        texte = texte.replace(avant, apres)
    prets = ", ".join("%s = true" % n for n in RACES_PRETES + CLASSES_PRETES)
    texte += "\n".join([
        "",
        "-- Sol'Azeroth, lot 6a : ajouté par outils\\interface_v3.py (creation()).",
        "SOL_PRETES = { %s };" % prets,
        "SOL_PAS_PRET = \"%s\";" % PAS_PRET,
        "local function SolIndex(prets, ...)",
        "\tfor i = 1, select(\"#\", ...), 3 do",
        "\t\tif ( select(i+2, ...) == 1 and prets[strupper(select(i+1, ...))] ) then return (i + 2) / 3; end",
        "\tend",
        "end",
        "function SolChoixPret()",
        "\tlocal _, race = GetNameForRace();",
        "\tif ( not race or not SOL_PRETES[strupper(race)] ) then",
        "\t\tlocal index = SolIndex({ ORC = true }, GetAvailableRaces());",
        "\t\tif ( index ) then SetSelectedRace(index); end",
        "\tend",
        "\tlocal _, classe = GetSelectedClass();",
        "\tif ( not classe or not SOL_PRETES[strupper(classe)] ) then",
        "\t\tlocal index = SolIndex({ WARRIOR = true }, GetAvailableClasses());",
        "\t\tif ( index ) then SetSelectedClass(index); end",
        "\tend",
        "end",
        ""])
    dossier = os.path.join(FICHIERS, "Interface", "GlueXML")
    os.makedirs(dossier, exist_ok=True)
    with open(os.path.join(dossier, "CharacterCreate.lua"), "w", encoding="utf-8", newline="\r\n") as f:
        f.write(texte)


def cartes():
    """Taille en mètres du jeu de chaque carte de zone (WorldMapArea.dbc), pour placer les repères de la mini-carte."""
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import dbc
    table = dbc.Dbc.ouvrir(os.path.join(RACINE, "data", "dbc", "WorldMapArea.dbc"))
    lignes = ["-- Généré par outils\\interface_v3.py depuis WorldMapArea.dbc : ne pas modifier à la main.",
              "-- Carte de zone (nom de fichier, GetMapInfo) -> largeur et hauteur en mètres du jeu, bord gauche (y du jeu)",
              "-- et bord haut (x du jeu), carte du serveur (continent).",
              "SolUI.CARTES = {"]
    for e in table.enregistrements:
        gauche, droite, haut, bas = (dbc.flottant(v) for v in e[4:8])
        if gauche != droite and haut != bas:
            lignes.append("    [\"%s\"] = { %.1f, %.1f, %.1f, %.1f, %d }," % (table.texte(e[3]), gauche - droite,
                                                                        haut - bas, gauche, haut, e[1]))
    lignes.append("}")
    with open(os.path.join(FRAMEXML, "SolUI_Cartes.lua"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lignes) + "\n")


def code():
    os.makedirs(FRAMEXML, exist_ok=True)
    for nom in CODE:
        if nom not in GENERES:
            shutil.copy2(os.path.join(SOURCES, "FrameXML", nom), os.path.join(FRAMEXML, nom))
    cartes()
    lignes = toc_du_client().splitlines()
    repere = next(i for i, l in enumerate(lignes) if l.startswith("## add new modules above here"))
    lignes[repere:repere] = ["# Sol'Azeroth v3 (F4) : interface"] + CODE + [""]
    with open(os.path.join(FRAMEXML, "FrameXML.toc"), "w", encoding="utf-8", newline="\r\n") as f:
        f.write("\n".join(lignes) + "\n")


if __name__ == "__main__":
    polices()
    textures()
    code()
    creation()
    print("Interface v3 préparée dans", FICHIERS)
