-- Rend aux monstres leurs réglages d'avant le recalibrage avec leurs sorts.
USE acore_world;
UPDATE creature_template t JOIN solazeroth_v3_sorts_calibre_origine o ON o.entry = t.entry SET t.DamageModifier = o.DamageModifier;
DROP TABLE solazeroth_v3_sorts_calibre_origine;
DROP TABLE solazeroth_v3_sorts_facteur;
