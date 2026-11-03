-- Rend aux monstres des Tarides et des Cavernes leurs sorts de Blizzard (migration 137).
USE acore_world;
UPDATE smart_scripts s JOIN solazeroth_v3_sorts_tarides_origine o ON o.entryorguid = s.entryorguid AND o.source_type = s.source_type AND o.id = s.id AND o.link = s.link SET s.action_param1 = o.action_param1;
INSERT INTO smart_scripts SELECT * FROM solazeroth_v3_sorts_tarides_retires;
DROP TABLE solazeroth_v3_sorts_tarides_origine;
DROP TABLE solazeroth_v3_sorts_tarides_retires;
DELETE FROM spell_dbc WHERE ID IN (102013, 102014, 102015, 102016, 102017, 102018);
