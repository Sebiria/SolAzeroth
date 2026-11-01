-- Rend au Gouffre de Ragefeu ses monstres d'origine.
USE acore_world;
UPDATE creature_template t JOIN solazeroth_v3_gouffre_origine o ON o.entry = t.entry SET t.minlevel = o.minlevel, t.maxlevel = o.maxlevel, t.`rank` = o.`rank`, t.HealthModifier = o.HealthModifier, t.DamageModifier = o.DamageModifier;
DROP TABLE solazeroth_v3_gouffre_origine;
INSERT IGNORE INTO creature SELECT * FROM solazeroth_v3_gouffre_apparitions;
INSERT IGNORE INTO creature_addon SELECT * FROM solazeroth_v3_gouffre_apparitions_addon;
DROP TABLE solazeroth_v3_gouffre_apparitions, solazeroth_v3_gouffre_apparitions_addon;
