-- Retire le désenchantement et l'enchantement v3.
USE acore_world;
UPDATE item_template i JOIN solazeroth_v3_desenchantement_origine o ON o.entry = i.entry SET i.DisenchantID = o.DisenchantID, i.RequiredDisenchantSkill = o.RequiredDisenchantSkill;
DROP TABLE IF EXISTS solazeroth_v3_enchantements, solazeroth_v3_enchantements_types, solazeroth_v3_enchantements_composants, solazeroth_v3_desenchantement_origine;
