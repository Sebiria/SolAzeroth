-- Retire la potion et le feu de camp v3.
USE acore_world;
DELETE FROM spell_dbc WHERE ID IN (100029, 100030, 100031, 100032);
DELETE FROM spell_script_names WHERE spell_id IN (100029, 100030, 100031, 100032);
DROP TABLE acore_characters.solazeroth_v3_bivouac;
