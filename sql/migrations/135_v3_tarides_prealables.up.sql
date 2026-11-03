-- Lot T0 des Tarides (03/11/2026) : préalables. Généré par outils\prealables_tarides.py : ne pas modifier à la main.
USE acore_world;

-- Lieux comptés par sous-zone ; créatures invoquées ignorées si invocations = 0 (Durotar : 1, comme avant).
ALTER TABLE solazeroth_v3_lieux_monstres ADD COLUMN sous_zones VARCHAR(64) NOT NULL DEFAULT '', ADD COLUMN invocations TINYINT UNSIGNED NOT NULL DEFAULT 1;
-- Quêtes écrites à la main qui retiennent un chef renforcé (en plus de celles que v3_zone.cpp trouve seul).
CREATE TABLE solazeroth_v3_lieux_chefs_quetes (lieu INT UNSIGNED NOT NULL, quete INT UNSIGNED NOT NULL, PRIMARY KEY (lieu, quete));

-- Seuils de donjon (v3_gouffre.cpp, .teleportdonjon). Dans les refus, {pourcent} et {seuil} sont remplacés.
CREATE TABLE solazeroth_v3_donjons_seuils (carte INT UNSIGNED NOT NULL PRIMARY KEY, zone INT UNSIGNED NOT NULL, seuil INT UNSIGNED NOT NULL, quete INT UNSIGNED NOT NULL, pnj INT UNSIGNED NOT NULL, texte INT UNSIGNED NOT NULL, x FLOAT NOT NULL, y FLOAT NOT NULL, z FLOAT NOT NULL, o FLOAT NOT NULL, choix VARCHAR(255) NOT NULL, refus_quete VARCHAR(255) NOT NULL, refus_pourcent VARCHAR(255) NOT NULL, refus_entree VARCHAR(255) NOT NULL) DEFAULT CHARSET=utf8mb4;
INSERT INTO solazeroth_v3_donjons_seuils VALUES (389, 14, 6000, 910026, 910001, 910001, 3.81, -14.82, -17.84, 4.39, 'Descendre dans la faille.', 'Margoz garde l''œil sur cette faille. Va d''abord le voir, au sud du Rocher du crâne.', 'Durotar ne parle pas encore assez de toi : {pourcent} de la zone. Reviens à {seuil}.', 'Le Gouffre de Ragefeu se passe par la faille du Rocher du crâne, gardée par Ruga Brise-cendre. ');
UPDATE creature_template SET ScriptName = 'npc_solazeroth_v3_seuil' WHERE entry = 910001;

-- Entrées scellées : le Kraal et les Souilles de Tranchebauge.
CREATE TABLE solazeroth_v3_entrees_scellees (declencheur INT UNSIGNED NOT NULL PRIMARY KEY, carte INT UNSIGNED NOT NULL, message VARCHAR(255) NOT NULL) DEFAULT CHARSET=utf8mb4;
INSERT INTO solazeroth_v3_entrees_scellees VALUES (244, 47, 'Cette entrée est scellée.'), (442, 129, 'Cette entrée est scellée.');
DELETE FROM areatrigger_scripts WHERE entry IN (244, 442);
INSERT INTO areatrigger_scripts (entry, ScriptName) VALUES (244, 'at_solazeroth_v3_scelle'), (442, 'at_solazeroth_v3_scelle');
DELETE FROM creature WHERE guid IN (9100100, 9100101);
INSERT INTO creature (guid, id, map, zoneId, areaId, spawnMask, phaseMask, equipment_id, position_x, position_y, position_z, orientation, spawntimesecs, wander_distance, curhealth, MovementType) VALUES (9100100, 8016, 1, 17, 1717, 1, 1, 1, -4452.4, -1647, 86.11, 1.13, 275, 0, 3048, 0), (9100101, 8016, 1, 17, 1316, 1, 1, 1, -4654.5, -2536.8, 86.97, 0, 275, 0, 3048, 0);

-- Sortie des Cavernes des Lamentations : devant Ebru.
UPDATE areatrigger_teleport SET target_position_x = -800, target_position_y = -2035.5, target_position_z = 96.9, target_orientation = 4.18 WHERE ID = 226;

-- Équipement de Blizzard retiré des marchands de Durotar et des Tarides (table de retour).
CREATE TABLE solazeroth_v3_marchands_retires SELECT v.* FROM npc_vendor v JOIN item_template i ON i.entry = v.item WHERE v.entry IN (SELECT DISTINCT id FROM creature WHERE zoneId IN (14, 17)) AND i.class IN (2, 4) AND i.entry < 900000 AND i.InventoryType NOT IN (0, 4, 18, 19) AND NOT (i.class = 2 AND i.subclass IN (14, 20));
DELETE v FROM npc_vendor v JOIN solazeroth_v3_marchands_retires r ON r.entry = v.entry AND r.item = v.item AND r.ExtendedCost = v.ExtendedCost;
