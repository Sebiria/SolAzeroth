-- Rend la joaillerie d'origine : formation des maîtres joailliers et dessins, depuis les tables de sauvegarde.
USE acore_world;

INSERT IGNORE INTO trainer_spell SELECT * FROM solazeroth_v3_joaillier_formation;
INSERT IGNORE INTO npc_vendor SELECT * FROM solazeroth_v3_joaillier_vendeurs;
INSERT IGNORE INTO creature_loot_template SELECT * FROM solazeroth_v3_joaillier_butin_monstres;
INSERT IGNORE INTO reference_loot_template SELECT * FROM solazeroth_v3_joaillier_butin_references;
INSERT IGNORE INTO gameobject_loot_template SELECT * FROM solazeroth_v3_joaillier_butin_coffres;
INSERT IGNORE INTO item_loot_template SELECT * FROM solazeroth_v3_joaillier_butin_objets;

DROP TABLE solazeroth_v3_joaillier_formation, solazeroth_v3_joaillier_vendeurs, solazeroth_v3_joaillier_butin_monstres,
    solazeroth_v3_joaillier_butin_references, solazeroth_v3_joaillier_butin_coffres, solazeroth_v3_joaillier_butin_objets;
