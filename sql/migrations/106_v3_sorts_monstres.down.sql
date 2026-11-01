-- Rend aux monstres leurs sorts de Blizzard.
USE acore_world;
UPDATE smart_scripts s JOIN solazeroth_v3_sorts_origine o ON o.entryorguid = s.entryorguid AND o.source_type = s.source_type AND o.id = s.id AND o.link = s.link SET s.action_param1 = o.action_param1;
INSERT INTO smart_scripts SELECT * FROM solazeroth_v3_sorts_retires;
DROP TABLE solazeroth_v3_sorts_origine;
DROP TABLE solazeroth_v3_sorts_retires;
DELETE FROM spell_dbc WHERE ID IN (102000, 102001, 102002, 102003, 102004, 102005, 102006, 102007, 102008, 102009, 102010, 102011, 102012);
