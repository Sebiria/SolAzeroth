-- Annule le lot T0 des Tarides (migration 135). Généré par outils\prealables_tarides.py.
USE acore_world;
INSERT IGNORE INTO npc_vendor SELECT * FROM solazeroth_v3_marchands_retires;
DROP TABLE solazeroth_v3_marchands_retires;
UPDATE areatrigger_teleport SET target_position_x = -740.059, target_position_y = -2214.23, target_position_z = 16.1374, target_orientation = 5.68 WHERE ID = 226;
DELETE FROM creature WHERE guid IN (9100100, 9100101);
DELETE FROM areatrigger_scripts WHERE entry IN (244, 442);
DROP TABLE solazeroth_v3_entrees_scellees;
UPDATE creature_template SET ScriptName = 'npc_solazeroth_ruga' WHERE entry = 910001;
DROP TABLE solazeroth_v3_donjons_seuils;
DROP TABLE solazeroth_v3_lieux_chefs_quetes;
ALTER TABLE solazeroth_v3_lieux_monstres DROP COLUMN sous_zones, DROP COLUMN invocations;
