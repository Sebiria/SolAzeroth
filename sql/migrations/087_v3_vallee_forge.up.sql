-- v3 (01/11/2026, demande de l'utilisateur) : une forge et une enclume dans la vallée des Épreuves, près du contremaître
-- Thazz'ril, pour fabriquer maille et armes dès le départ (v3_equipement.cpp : focus de sort 1 et 3). Mêmes objets qu'à
-- Razor Hill (enclume 51702, forge ardente 50983). Hauteur prise sur l'apparition de Thazz'ril (40,1).
USE acore_world;

DELETE FROM gameobject WHERE guid IN (9100034, 9100035);
INSERT INTO gameobject (guid, id, map, zoneId, areaId, spawnMask, phaseMask, position_x, position_y, position_z, orientation, rotation0, rotation1, rotation2, rotation3, spawntimesecs, animprogress, state) VALUES
(9100034, 50983, 1, 14, 363, 1, 1, -604.5, -4314.5, 40.1, 4.3, 0, 0, 0.836899, -0.547358, 0, 100, 1),
(9100035, 51702, 1, 14, 363, 1, 1, -600.0, -4320.5, 40.1, 4.3, 0, 0, 0.836899, -0.547358, 0, 100, 1);
