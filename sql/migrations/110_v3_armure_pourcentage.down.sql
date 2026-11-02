-- Rend à nos pièces leur armure d'avant le lot 3a.
USE acore_world;
UPDATE item_template i JOIN solazeroth_v3_armure_origine o ON o.entry = i.entry SET i.armor = o.armor;
DROP TABLE solazeroth_v3_armure_origine;
