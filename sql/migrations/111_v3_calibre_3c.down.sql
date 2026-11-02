-- Rend aux monstres leurs réglages d'avant le lot 3c.
USE acore_world;
UPDATE creature_template t JOIN solazeroth_v3_calibre_3c_origine o ON o.entry = t.entry SET t.DamageModifier = o.DamageModifier, t.HealthModifier = o.HealthModifier;
DELETE FROM solazeroth_v3_sorts_facteur;
INSERT INTO solazeroth_v3_sorts_facteur SELECT * FROM solazeroth_v3_sorts_facteur_3c;
DELETE FROM smart_scripts WHERE source_type = 0 AND entryorguid IN (910010, 910011, 910012, 910013, 910014);
INSERT INTO smart_scripts SELECT * FROM solazeroth_v3_chefs_3c_origine;
DROP TABLE solazeroth_v3_chefs_3c_origine;
DROP TABLE solazeroth_v3_calibre_3c_origine;
DROP TABLE solazeroth_v3_sorts_facteur_3c;
