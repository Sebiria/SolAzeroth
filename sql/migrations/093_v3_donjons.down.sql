-- Retire les difficultés de donjon, la réputation des donjons et les passifs v3.
USE acore_world;
DELETE FROM spell_dbc WHERE ID IN (100040, 100041, 100042, 100043, 100044);
DROP TABLE IF EXISTS acore_characters.solazeroth_v3_reputation, acore_characters.solazeroth_v3_passifs, acore_characters.solazeroth_v3_donjons;
