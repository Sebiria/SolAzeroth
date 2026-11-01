-- Remet les 5 filons et 5 plantes retirés de la Vallée des Épreuves.
USE acore_world;
DELETE FROM gameobject WHERE guid IN (9100032, 9100038, 9100042, 9100043, 9100044, 9100045, 9100046, 9100047, 9100048, 9100049);
INSERT INTO gameobject (guid, id, map, zoneId, areaId, spawnMask, phaseMask, position_x, position_y, position_z, orientation, rotation0, rotation1, rotation2, rotation3, spawntimesecs, animprogress, state, ScriptName, VerifiedBuild, Comment) VALUES
(9100032, 1731, 1, 14, 363, 1, 1, -304.9, -4437.5, 59.2, 4, 0, 0, 0, 1, 1800, 100, 1, '', NULL, NULL),
(9100038, 1618, 1, 14, 363, 1, 1, -514.3, -4345, 38.3, 0, 0, 0, 0, 1, 1800, 100, 1, '', NULL, NULL),
(9100042, 1617, 1, 14, 363, 1, 1, -675.7, -4350.4, 44.6, 4, 0, 0, 0, 1, 1800, 100, 1, '', NULL, NULL),
(9100043, 1618, 1, 14, 363, 1, 1, -412.6, -4382.8, 39.3, 5, 0, 0, 0, 1, 1800, 100, 1, '', NULL, NULL),
(9100044, 1619, 1, 14, 363, 1, 1, -476.1, -4255.1, 46.1, 0, 0, 0, 0, 1, 1800, 100, 1, '', NULL, NULL),
(9100045, 1617, 1, 14, 363, 1, 1, -754.9, -4219.8, 43, 1, 0, 0, 0, 1, 1800, 100, 1, '', NULL, NULL),
(9100046, 1731, 1, 14, 363, 1, 1, -415.4, -4055.6, 52.3, 2, 0, 0, 0, 1, 1800, 100, 1, '', NULL, NULL),
(9100047, 1731, 1, 14, 363, 1, 1, -425.4, -4150.1, 52.1, 3, 0, 0, 0, 1, 1800, 100, 1, '', NULL, NULL),
(9100048, 1731, 1, 14, 363, 1, 1, -519, -4076.9, 69.9, 4, 0, 0, 0, 1, 1800, 100, 1, '', NULL, NULL),
(9100049, 1731, 1, 14, 363, 1, 1, -180.7, -4243.6, 56.9, 5, 0, 0, 0, 1, 1800, 100, 1, '', NULL, NULL);
