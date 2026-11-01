-- v3 (01/11/2026, demande de l'utilisateur) : une enclume dans la vallée des Épreuves, à côté de Kaltunk
-- (premier donneur de quête), pour fabriquer maille et armes dès le départ (v3_equipement.cpp : focus de sort 1 et 3).
-- Mêmes objets qu'à Razor Hill (enclume 51702, forge ardente 50983). Forge à la place et dans la direction
-- où l'utilisateur a quitté le jeu (Samassan), enclume à 4 m sur sa droite. D'abord posées près de Thazz'ril, puis de Kaltunk ;
-- la forge a ensuite été retirée à la demande de l'utilisateur (l'enclume suffit à fabriquer).
USE acore_world;

DELETE FROM gameobject WHERE guid IN (9100034, 9100035);
INSERT INTO gameobject (guid, id, map, zoneId, areaId, spawnMask, phaseMask, position_x, position_y, position_z, orientation, rotation0, rotation1, rotation2, rotation3, spawntimesecs, animprogress, state) VALUES
(9100035, 51702, 1, 14, 363, 1, 1, -640.0, -4254.4, 38.29, 6.275, 0, 0, 0.004068, -0.999992, 0, 100, 1);
