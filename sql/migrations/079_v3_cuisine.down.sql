-- Retire la cuisine v3 et rend aux plats leur sort de nourriture.
USE acore_world;
UPDATE item_template i JOIN solazeroth_v3_plats_origine o ON o.entry = i.entry SET i.spellid_1 = o.spellid_1, i.description = o.description;
DROP TABLE IF EXISTS solazeroth_v3_plats, solazeroth_v3_plats_composants, solazeroth_v3_plats_origine;
DELETE FROM spell_dbc WHERE ID IN (101000, 101500, 101501, 101502, 101001, 101503, 101504, 101505, 101002, 101506, 101507, 101508, 101003, 101509, 101510, 101511, 101004, 101512, 101513, 101514);
DELETE FROM spell_script_names WHERE ScriptName = 'spell_solazeroth_v3_plat';
