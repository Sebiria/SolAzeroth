"""Lot T0 des Tarides (03/11/2026) : préalables (« Les Tarides — Histoire et quêtes (brouillon).md », §5.3).

Écrit la migration 135 :
- lieux à nettoyer comptés par sous-zone : colonnes « sous_zones » (liste de GetAreaId(), vide pour toute la zone) et
  « invocations » (0 : les créatures invoquées ne comptent pas ; 1, Durotar : elles comptent, comme avant) dans
  solazeroth_v3_lieux_monstres (v3_zone.cpp) ;
- quêtes écrites à la main sur un chef renforcé : solazeroth_v3_lieux_chefs_quetes (lieu, quête), en plus de celles
  que v3_zone.cpp trouve seul (objectif « tuer » ou objet du butin du chef) ;
- seuils de donjon en table : solazeroth_v3_donjons_seuils (v3_gouffre.cpp, .teleportdonjon). Une seule ligne pour
  l'instant, le Gouffre de Ragefeu, avec exactement ses chiffres et ses phrases d'avant. Ebru (Cavernes des
  Lamentations, zone 718, pourcentage de la zone 17) viendra au lot T5, avec la quête T30 ;
- entrées scellées : solazeroth_v3_entrees_scellees et areatrigger_scripts, au Kraal (244, carte 47) et aux Souilles
  (442, carte 129) de Tranchebauge, avec une Garde des Tarides (8016) à chaque porte ; leurs répliques au lot T1 ;
- sortie des Cavernes (226) redirigée devant Ebru, et non plus au milieu des déviants ;
- équipement de Blizzard retiré des marchands de Durotar (zone 14) et des Tarides (zone 17), gardé dans la table de
  retour solazeroth_v3_marchands_retires. Restent les fournitures (pas d'équipement), les chemises et tabards, les
  outils (armes « divers ») et les cannes à pêche : armuriers, aubergistes et fournisseurs gardent leur rôle.

py prealables_tarides.py  (écrit la migration et liste les marchands touchés ; lecture seule de la base)
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from quetes_durotar import s, sql

ICI = os.path.dirname(os.path.abspath(__file__))
MIGRATION = os.path.join(ICI, "..", "sql", "migrations", "135_v3_tarides_prealables")
ZONES_MARCHANDS = (14, 17)   # Durotar et les Tarides (décision 2 du comparatif)

# Équipement qui compte dans la puissance (CalculerPuissance : tout emplacement sauf chemise et tabard). On garde
# les objets sans emplacement, les chemises (4), tabards (19) et sacs (18), les outils (armes « divers », 14 : pioche,
# marteau de forgeron) et les cannes à pêche (20). Nos propres pièces (900000 et plus) ne sont pas touchées.
EQUIPEMENT = ("i.class IN (2, 4) AND i.entry < 900000 AND i.InventoryType NOT IN (0, 4, 18, 19) "
              "AND NOT (i.class = 2 AND i.subclass IN (14, 20))")
MARCHANDS = "SELECT DISTINCT id FROM creature WHERE zoneId IN (%s)" % ", ".join(map(str, ZONES_MARCHANDS))

# Gouffre de Ragefeu : chiffres et phrases de v3_gouffre.cpp avant le lot T0 (F5f, 31/10/2026).
SEUILS = [dict(
    carte=389, zone=14, seuil=6000, quete=910026, pnj=910001, texte=910001, x=3.81, y=-14.82, z=-17.84, o=4.39,
    choix="Descendre dans la faille.",
    refus_quete="Margoz garde l'œil sur cette faille. Va d'abord le voir, au sud du Rocher du crâne.",
    refus_pourcent="Durotar ne parle pas encore assez de toi : {pourcent} de la zone. Reviens à {seuil}.",
    refus_entree="Le Gouffre de Ragefeu se passe par la faille du Rocher du crâne, gardée par Ruga Brise-cendre. ",
)]
SCRIPT_RUGA_AVANT = "npc_solazeroth_ruga"

# Entrées scellées (brouillon, « Entrées fermées » ; point 6 du §5.2).
SCELLE = "Cette entrée est scellée."
SCELLEES = [(244, 47), (442, 129)]
# Gardes des Tarides (8016, Horde) devant chaque porte : (guid, sous-zone, x, y, z, orientation). Au Kraal, à 10 m du
# centre de la zone 244, du côté opposé au Serviteur de Tranchebauge le plus proche (39 m du centre) : à plus de 40 m
# de lui. Aux Souilles, à 12 m au nord du centre de la zone 442. Hauteurs : celle de la zone de déclenchement, à
# vérifier en jeu.
GARDES = [(9100100, 1717, -4452.4, -1647.0, 86.11, 1.13), (9100101, 1316, -4654.5, -2536.8, 86.97, 0.0)]

# Sortie des Cavernes (226) : devant Ebru (-802,2 ; -2039,2 ; 96,6), entre elle et Kalldan, tourné vers elle.
SORTIE = (226, -800.0, -2035.5, 96.9, 4.18)
SORTIE_AVANT = (-740.059, -2214.23, 16.1374, 5.68)


def main():
    up, down = [], []
    w = up.append
    w("-- Lot T0 des Tarides (03/11/2026) : préalables. Généré par outils\\prealables_tarides.py : ne pas modifier à la main.")
    w("USE acore_world;")
    w("")
    w("-- Lieux comptés par sous-zone ; créatures invoquées ignorées si invocations = 0 (Durotar : 1, comme avant).")
    # Lot T3 : la migration 074 crée maintenant la table avec ces colonnes ; on ne les ajoute que si elles manquent.
    w("SET @manque = (SELECT COUNT(*) = 0 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = 'acore_world' "
      "AND TABLE_NAME = 'solazeroth_v3_lieux_monstres' AND COLUMN_NAME = 'sous_zones');")
    w("SET @requete = IF(@manque, 'ALTER TABLE solazeroth_v3_lieux_monstres ADD COLUMN sous_zones VARCHAR(64) NOT NULL "
      "DEFAULT '''', ADD COLUMN invocations TINYINT UNSIGNED NOT NULL DEFAULT 1', 'DO 0');")
    w("PREPARE requete FROM @requete;")
    w("EXECUTE requete;")
    w("DEALLOCATE PREPARE requete;")
    w("-- Quêtes écrites à la main qui retiennent un chef renforcé (en plus de celles que v3_zone.cpp trouve seul).")
    w("CREATE TABLE solazeroth_v3_lieux_chefs_quetes (lieu INT UNSIGNED NOT NULL, quete INT UNSIGNED NOT NULL, "
      "PRIMARY KEY (lieu, quete));")
    w("")
    w("-- Seuils de donjon (v3_gouffre.cpp, .teleportdonjon). Dans les refus, {pourcent} et {seuil} sont remplacés.")
    w("CREATE TABLE solazeroth_v3_donjons_seuils (carte INT UNSIGNED NOT NULL PRIMARY KEY, zone INT UNSIGNED NOT NULL, "
      "seuil INT UNSIGNED NOT NULL, quete INT UNSIGNED NOT NULL, pnj INT UNSIGNED NOT NULL, texte INT UNSIGNED NOT NULL, "
      "x FLOAT NOT NULL, y FLOAT NOT NULL, z FLOAT NOT NULL, o FLOAT NOT NULL, choix VARCHAR(255) NOT NULL, "
      "refus_quete VARCHAR(255) NOT NULL, refus_pourcent VARCHAR(255) NOT NULL, refus_entree VARCHAR(255) NOT NULL) "
      "DEFAULT CHARSET=utf8mb4;")
    for d in SEUILS:
        w("INSERT INTO solazeroth_v3_donjons_seuils VALUES (%d, %d, %d, %d, %d, %d, %g, %g, %g, %g, %s, %s, %s, %s);"
          % (d["carte"], d["zone"], d["seuil"], d["quete"], d["pnj"], d["texte"], d["x"], d["y"], d["z"], d["o"],
             s(d["choix"]), s(d["refus_quete"]), s(d["refus_pourcent"]), s(d["refus_entree"])))
        w("UPDATE creature_template SET ScriptName = 'npc_solazeroth_v3_seuil' WHERE entry = %d;" % d["pnj"])
    w("")
    w("-- Entrées scellées : le Kraal et les Souilles de Tranchebauge.")
    w("CREATE TABLE solazeroth_v3_entrees_scellees (declencheur INT UNSIGNED NOT NULL PRIMARY KEY, carte INT UNSIGNED "
      "NOT NULL, message VARCHAR(255) NOT NULL) DEFAULT CHARSET=utf8mb4;")
    w("INSERT INTO solazeroth_v3_entrees_scellees VALUES %s;"
      % ", ".join("(%d, %d, %s)" % (t, c, s(SCELLE)) for t, c in SCELLEES))
    triggers = ", ".join(str(t) for t, _ in SCELLEES)
    w("DELETE FROM areatrigger_scripts WHERE entry IN (%s);" % triggers)
    w("INSERT INTO areatrigger_scripts (entry, ScriptName) VALUES %s;"
      % ", ".join("(%d, 'at_solazeroth_v3_scelle')" % t for t, _ in SCELLEES))
    gardes = ", ".join(str(g[0]) for g in GARDES)
    w("DELETE FROM creature WHERE guid IN (%s);" % gardes)
    w("INSERT INTO creature (guid, id, map, zoneId, areaId, spawnMask, phaseMask, equipment_id, position_x, position_y, "
      "position_z, orientation, spawntimesecs, wander_distance, curhealth, MovementType) VALUES %s;"
      % ", ".join("(%d, 8016, 1, 17, %d, 1, 1, 1, %g, %g, %g, %g, 275, 0, 3048, 0)" % g for g in GARDES))
    w("")
    w("-- Sortie des Cavernes des Lamentations : devant Ebru.")
    w("UPDATE areatrigger_teleport SET target_position_x = %g, target_position_y = %g, target_position_z = %g, "
      "target_orientation = %g WHERE ID = %d;" % (SORTIE[1], SORTIE[2], SORTIE[3], SORTIE[4], SORTIE[0]))
    w("")
    w("-- Équipement de Blizzard retiré des marchands de Durotar et des Tarides (table de retour).")
    w("CREATE TABLE solazeroth_v3_marchands_retires SELECT v.* FROM npc_vendor v JOIN item_template i ON i.entry = v.item "
      "WHERE v.entry IN (%s) AND %s;" % (MARCHANDS, EQUIPEMENT))
    w("DELETE v FROM npc_vendor v JOIN solazeroth_v3_marchands_retires r ON r.entry = v.entry AND r.item = v.item "
      "AND r.ExtendedCost = v.ExtendedCost;")

    d = down.append
    d("-- Annule le lot T0 des Tarides (migration 135). Généré par outils\\prealables_tarides.py.")
    d("USE acore_world;")
    d("INSERT IGNORE INTO npc_vendor SELECT * FROM solazeroth_v3_marchands_retires;")
    d("DROP TABLE solazeroth_v3_marchands_retires;")
    d("UPDATE areatrigger_teleport SET target_position_x = %g, target_position_y = %g, target_position_z = %g, "
      "target_orientation = %g WHERE ID = %d;" % (SORTIE_AVANT + (SORTIE[0],)))
    d("DELETE FROM creature WHERE guid IN (%s);" % gardes)
    d("DELETE FROM areatrigger_scripts WHERE entry IN (%s);" % triggers)
    d("DROP TABLE solazeroth_v3_entrees_scellees;")
    for x in SEUILS:
        d("UPDATE creature_template SET ScriptName = %s WHERE entry = %d;" % (s(SCRIPT_RUGA_AVANT), x["pnj"]))
    d("DROP TABLE solazeroth_v3_donjons_seuils;")
    d("DROP TABLE solazeroth_v3_lieux_chefs_quetes;")
    d("ALTER TABLE solazeroth_v3_lieux_monstres DROP COLUMN sous_zones, DROP COLUMN invocations;")

    for suffixe, lignes in ((".up.sql", up), (".down.sql", down)):
        with open(MIGRATION + suffixe, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(lignes) + "\n")
    print("Migration écrite :", os.path.normpath(MIGRATION) + ".up.sql")

    print("Marchands dont l'équipement de Blizzard sera retiré :")
    for zone, entree, nom, n in sql(
            "SELECT c.zoneId, v.entry, COALESCE(l.Name, t.name), COUNT(*) FROM acore_world.npc_vendor v "
            "JOIN acore_world.item_template i ON i.entry = v.item JOIN acore_world.creature_template t ON t.entry = v.entry "
            "LEFT JOIN acore_world.creature_template_locale l ON l.entry = t.entry AND l.locale = 'frFR' "
            "JOIN (SELECT DISTINCT id, zoneId FROM acore_world.creature WHERE zoneId IN (%s)) c ON c.id = v.entry "
            "WHERE %s GROUP BY c.zoneId, v.entry, l.Name, t.name ORDER BY c.zoneId, v.entry"
            % (", ".join(map(str, ZONES_MARCHANDS)), EQUIPEMENT)):
        print("  zone %s, %s %s : %s objet(s)" % (zone, entree, nom, n))


if __name__ == "__main__":
    main()
