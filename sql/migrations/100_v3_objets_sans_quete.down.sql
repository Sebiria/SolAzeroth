-- Rend le butin et les ventes retirés par la migration 100.
USE acore_world;
INSERT IGNORE INTO creature_loot_template SELECT * FROM solazeroth_v3_sans_quete_creature;
DROP TABLE solazeroth_v3_sans_quete_creature;
INSERT IGNORE INTO gameobject_loot_template SELECT * FROM solazeroth_v3_sans_quete_gameobject;
DROP TABLE solazeroth_v3_sans_quete_gameobject;
INSERT IGNORE INTO reference_loot_template SELECT * FROM solazeroth_v3_sans_quete_reference;
DROP TABLE solazeroth_v3_sans_quete_reference;
INSERT IGNORE INTO item_loot_template SELECT * FROM solazeroth_v3_sans_quete_item;
DROP TABLE solazeroth_v3_sans_quete_item;
INSERT IGNORE INTO pickpocketing_loot_template SELECT * FROM solazeroth_v3_sans_quete_pickpocketing;
DROP TABLE solazeroth_v3_sans_quete_pickpocketing;
INSERT IGNORE INTO fishing_loot_template SELECT * FROM solazeroth_v3_sans_quete_fishing;
DROP TABLE solazeroth_v3_sans_quete_fishing;
INSERT IGNORE INTO skinning_loot_template SELECT * FROM solazeroth_v3_sans_quete_skinning;
DROP TABLE solazeroth_v3_sans_quete_skinning;
INSERT IGNORE INTO npc_vendor SELECT * FROM solazeroth_v3_sans_quete_marchands;
DROP TABLE solazeroth_v3_sans_quete_marchands;
DROP TABLE solazeroth_v3_sans_quete_objets;
