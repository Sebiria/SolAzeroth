-- Retire l'économie des Tarides (lot T7).
SET SESSION sql_mode = '';
USE acore_world;
DELETE FROM solazeroth_v3_camp_couts WHERE (genre = 1 AND rang IN (3, 4)) OR (genre = 2 AND rang IN (4, 5));
DROP TABLE IF EXISTS solazeroth_v3_camp_rangs;
UPDATE item_template i JOIN solazeroth_v3_plats_origine o ON o.entry = i.entry SET i.spellid_1 = o.spellid_1, i.description = o.description WHERE i.entry IN (3726, 3727, 5474, 5476, 5477, 5478, 5479, 5525, 4592, 7676);
DELETE FROM solazeroth_v3_plats_origine WHERE entry IN (3726, 3727, 5474, 5476, 5477, 5478, 5479, 5525, 4592, 7676);
DELETE FROM solazeroth_v3_plats WHERE zone = 17;
DELETE FROM solazeroth_v3_plats_composants WHERE objet IN (3726, 3727, 5474, 5476, 5477, 5478, 5479, 5525, 4592, 7676);
DELETE FROM spell_dbc WHERE ID IN (100037, 100038, 100039, 100045, 100046, 100047, 101005, 101515, 101516, 101517, 101006, 101518, 101519, 101520, 101007, 101521, 101522, 101523, 101008, 101524, 101525, 101526, 101009, 101527, 101528, 101529, 101010, 101530, 101531, 101532, 101011, 101533, 101534, 101535, 101012, 101536, 101537, 101538, 101013, 101539, 101540, 101541, 101014, 101542, 101543, 101544);
DELETE FROM spell_script_names WHERE spell_id IN (101005, 101006, 101007, 101008, 101009, 101010, 101011, 101012, 101013, 101014);
DROP TABLE IF EXISTS solazeroth_v3_annexes_bareme;
ALTER TABLE solazeroth_v3_donjons_composants DROP COLUMN puissance_min;
DROP TABLE IF EXISTS acore_characters.solazeroth_v3_dernier_donjon;
