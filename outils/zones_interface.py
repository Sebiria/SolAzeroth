"""Lot T10 des Tarides (03/11/2026) : les zones et leurs donjons, pour l'interface.

Écrit interface-v3\\FrameXML\\SolUI_Zones.lua (SolUI.ZONES), lu par :
- SolUI_Aventurier.lua : registre (noms des zones et des donjons) ;
- SolUI_Equipement.lua : menus d'artisanat par zone puis par palier (décision de l'utilisateur du 03/11/2026 : tous les
  métiers prennent le menu à deux niveaux de l'armure), niveau du donjon (Gouffre, Cavernes…), composant du transfert
  de rang et sa provenance, panoplie du donjon, marchands des pièces.

Rien n'est écrit en base. Le composant, son taux, sa puissance minimale (transfert), la panoplie et le seuil sont relus
dans les tables du serveur (solazeroth_v3_donjons_composants, _panoplies, _donjons_seuils) : l'outil s'arrête si la
liste ci-dessous ne leur correspond pas. La plage de chaque zone vient de gabarit_zone.py.

Pour une nouvelle zone : une ligne dans ZONES, puis py outils\\zones_interface.py, puis l'interface
(« Check-list — intégrer une zone.md »).

py outils\\zones_interface.py
"""
import os
import subprocess
import sys

ICI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ICI)
import gabarit_zone as gz

MYSQL = r"C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe"
CNF = os.path.join(ICI, "..", "config", "mysql-acore.cnf")
LUA = os.path.join(ICI, "..", "interface-v3", "FrameXML", "SolUI_Zones.lua")

# Une ligne par zone v3, dans l'ordre du jeu.
# - paliers d'artisanat : (puissance la plus haute des pièces du palier, nom du niveau du menu) ; les pièces de
#   puissance plus haute vont au dernier palier. Durotar garde ses deux niveaux d'avant (Rudimentaire, Inhabituel).
# - marchands : la fin de la phrase « Ces pièces s'achètent aussi, plus cher, chez les marchands … ».
# - donjon : carte, nom court (niveau du menu), « de » + nom (provenance du composant), panoplie (suffixe des noms de
#   pièces, nom affiché) et ses paliers (mêmes chiffres que les sorts sort_2, sort_4 et sort_6 de
#   solazeroth_v3_panoplies, décision 13 du brouillon des Tarides).
PANOPLIE = [(2, "+ 3 % de dégâts"), (4, "− 5 % de dégâts subis"), (6, "3 % de vol de vie")]
ZONES = [
    {"zone": 14, "nom": "Durotar", "marchands": "de Razor Hill",
     "paliers": [(4, "Rudimentaire"), (10, "Inhabituel")],
     "donjon": {"carte": 389, "court": "Gouffre", "de": "du Gouffre de Ragefeu",
                "suffixe": " du Gouffre", "panoplie": "Panoplie du Gouffre", "bonus": PANOPLIE}},
    {"zone": 17, "nom": "Les Tarides", "marchands": "de la Croisée et du Camp Taurajo",
     "paliers": [(18, "La Croisée"), (24, "Les oasis"), (30, "Taurajo")],
     "donjon": {"carte": 43, "court": "Cavernes", "de": "des Cavernes des Lamentations",
                "suffixe": " des Lamentations", "panoplie": "Panoplie des Lamentations", "bonus": PANOPLIE}},
]


def sql(requete):
    r = subprocess.run([MYSQL, "--defaults-extra-file=" + CNF, "--default-character-set=utf8mb4", "-N", "-B",
                        "acore_world", "-e", requete], capture_output=True, check=True)
    return [l.split("\t") for l in r.stdout.decode("utf-8").splitlines()]


def lua(t):
    return '"' + t.replace("\\", "\\\\").replace('"', '\\"') + '"'


def lire():
    """Relit les donjons en base et les ajoute aux zones ; une erreur par écart."""
    composants = {int(c): (int(o), int(p), int(t)) for c, o, p, t in
                  sql("SELECT carte, composant, puissance_min, taux FROM solazeroth_v3_donjons_composants")}
    seuils = {int(c): int(z) for c, z in sql("SELECT carte, zone FROM solazeroth_v3_donjons_seuils")}
    panoplies = [(int(a), int(b), n) for a, b, n in
                 sql("SELECT premiere, derniere, nom FROM solazeroth_v3_panoplies ORDER BY ordre")]
    erreurs, plages = [], {z["zone"]: z["plage"] for z in gz.ZONES}
    for i, z in enumerate(ZONES):
        d = z["donjon"]
        if seuils.get(d["carte"]) != z["zone"]:
            erreurs.append("%s : la carte %d n'a pas de seuil pour la zone %d" % (z["nom"], d["carte"], z["zone"]))
        if d["carte"] not in composants:
            erreurs.append("%s : la carte %d n'a pas de composant de donjon" % (z["nom"], d["carte"]))
            continue
        d["composant"], d["puissanceMin"], d["taux"] = composants[d["carte"]]
        d["nomComposant"] = sql("SELECT IFNULL((SELECT Name FROM item_template_locale WHERE ID = %d AND "
                                "locale = 'frFR'), (SELECT name FROM item_template WHERE entry = %d))"
                                % (d["composant"], d["composant"]))[0][0]
        if i >= len(panoplies):
            erreurs.append("%s : pas de panoplie en base (ordre %d)" % (z["nom"], i + 1))
        else:
            d["nom"] = panoplies[i][2]
            noms = [n for (n,) in sql("SELECT IFNULL(l.Name, t.name) FROM item_template t LEFT JOIN "
                                      "item_template_locale l ON l.ID = t.entry AND l.locale = 'frFR' "
                                      "WHERE t.entry BETWEEN %d AND %d" % panoplies[i][:2])]
            sans = [n for n in noms if d["suffixe"] not in n]
            if sans:
                erreurs.append("%s : pièces de la panoplie sans « %s » : %s" % (z["nom"], d["suffixe"].strip(),
                                                                               ", ".join(sans[:3])))
        if z["zone"] not in plages:
            erreurs.append("%s : zone absente de gabarit_zone.py" % z["nom"])
        else:
            z["debut"] = plages[z["zone"]][0]
    return erreurs


def ecrire():
    l = ["-- Généré par outils\\zones_interface.py : ne pas modifier à la main.",
         "-- Lot T10 des Tarides : les zones v3 et leurs donjons, pour l'interface (registre, menus d'artisanat par zone",
         "-- puis par palier, composant et panoplie du donjon, marchands des pièces). debut : début de la plage de la zone",
         "-- (gabarit_zone.py) ; paliers : { puissance la plus haute des pièces, nom du niveau du menu }.",
         "SolUI.ZONES = {"]
    for z in ZONES:
        d = z["donjon"]
        l.append("    { id = %d, nom = %s, debut = %d, marchands = %s," % (z["zone"], lua(z["nom"]), z["debut"],
                                                                         lua(z["marchands"])))
        l.append("      paliers = { %s }," % ", ".join("{ %d, %s }" % (p, lua(n)) for p, n in z["paliers"]))
        l.append("      donjon = { carte = %d, nom = %s, court = %s, de = %s," % (d["carte"], lua(d["nom"]),
                                                                              lua(d["court"]), lua(d["de"])))
        l.append("          composant = %d, nomComposant = %s, taux = %d, puissanceMin = %d,"
                 % (d["composant"], lua(d["nomComposant"]), d["taux"], d["puissanceMin"]))
        l.append("          suffixe = %s, panoplie = %s, bonus = { %s } } }," % (
            lua(d["suffixe"]), lua(d["panoplie"]), ", ".join("{ %d, %s }" % (n, lua(t)) for n, t in d["bonus"])))
    l.append("}")
    with open(LUA, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(l) + "\n")


def main():
    erreurs = lire()
    for e in erreurs:
        print("ERREUR", e)
    if erreurs:
        return 1
    ecrire()
    print("%d zones : SolUI_Zones.lua écrit." % len(ZONES))
    return 0


if __name__ == "__main__":
    sys.exit(main())
