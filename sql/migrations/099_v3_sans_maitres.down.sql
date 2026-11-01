USE acore_world;
INSERT IGNORE INTO creature SELECT * FROM solazeroth_v3_maitres_creature;
INSERT IGNORE INTO creature_addon SELECT * FROM solazeroth_v3_maitres_addon;
INSERT IGNORE INTO game_event_creature SELECT * FROM solazeroth_v3_maitres_evenements;
UPDATE creature_template ct JOIN solazeroth_v3_maitres m ON m.entry = ct.entry SET ct.npcflag = m.npcflag;
DROP TABLE solazeroth_v3_maitres_evenements;
DROP TABLE solazeroth_v3_maitres_addon;
DROP TABLE solazeroth_v3_maitres_creature;
DROP TABLE solazeroth_v3_maitres;
