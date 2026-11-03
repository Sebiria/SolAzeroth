-- Annule le lot T1 des Tarides (migration 136). Généré par outils\puissance_tarides.py.
USE acore_world;
UPDATE creature SET ScriptName = '' WHERE guid IN (9100100, 9100101);
ALTER TABLE solazeroth_v3_entrees_scellees DROP COLUMN garde, DROP COLUMN replique;
UPDATE gameobject SET position_x = -4471.07, position_y = -1945, position_z = 118.288, areaId = 0 WHERE guid = 212956;
INSERT IGNORE INTO creature SELECT * FROM solazeroth_v3_tarides_retraits;
INSERT IGNORE INTO creature_addon SELECT * FROM solazeroth_v3_tarides_retraits_addon;
INSERT IGNORE INTO creature_formations SELECT * FROM solazeroth_v3_tarides_retraits_formations;
DROP TABLE solazeroth_v3_tarides_retraits, solazeroth_v3_tarides_retraits_addon, solazeroth_v3_tarides_retraits_formations;
DROP TABLE solazeroth_v3_puissance_entrees, solazeroth_v3_puissance_apparitions, solazeroth_v3_puissance_secteurs;
