-- Retire de nouveau du butin les objets rendus par la migration 108.
USE acore_world;
UPDATE item_template i JOIN solazeroth_v3_objets_quete_rendus r ON r.entry = i.entry SET i.startquest = r.startquest;
INSERT IGNORE INTO solazeroth_v3_sans_quete_objets SELECT entry FROM solazeroth_v3_objets_quete_rendus;
INSERT INTO solazeroth_v3_sans_quete_creature SELECT t.* FROM creature_loot_template t
JOIN solazeroth_v3_objets_quete_rendus r ON r.entry = t.Item WHERE t.Reference = 0;
DELETE t FROM creature_loot_template t JOIN solazeroth_v3_objets_quete_rendus r ON r.entry = t.Item WHERE t.Reference = 0;
INSERT INTO solazeroth_v3_sans_quete_gameobject SELECT t.* FROM gameobject_loot_template t
JOIN solazeroth_v3_objets_quete_rendus r ON r.entry = t.Item WHERE t.Reference = 0;
DELETE t FROM gameobject_loot_template t JOIN solazeroth_v3_objets_quete_rendus r ON r.entry = t.Item WHERE t.Reference = 0;
DROP TABLE solazeroth_v3_objets_quete_rendus;
