-- Recache Yarrog Plaie-d'ombre, comme avant la migration 072.
USE acore_world;
INSERT IGNORE INTO solazeroth_v3_phases_origine SELECT 'pnj', guid, phaseMask FROM creature WHERE guid = 12303;
UPDATE creature SET phaseMask = 1073741824 WHERE guid = 12303;
