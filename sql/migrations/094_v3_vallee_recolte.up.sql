-- v3 (01/11/2026, demande de l'utilisateur) : les zones de départ ont de quoi débuter les métiers de récolte.
-- Vallée des Épreuves : 10 plantes (4 Pacifiques 1618, 4 Feuillargents 1617, 2 Terrestrines 1619) aux places de
-- Sangliers marbrés, et 4 filons de cuivre (1731) de plus aux places de Scorpides ouvriers (hauteur du sol reprise
-- de leur apparition), 3 minutes de réapparition. S'ajoute aux 6 filons de la migration 086.
USE acore_world;

DELETE FROM gameobject WHERE guid BETWEEN 9100036 AND 9100049;
INSERT INTO gameobject (guid, id, map, zoneId, areaId, spawnMask, phaseMask, position_x, position_y, position_z, orientation, rotation0, rotation1, rotation2, rotation3, spawntimesecs, animprogress, state) VALUES
(9100036, 1618, 1, 14, 363, 1, 1, -391.3, -4283.4, 49.2, 4.0, 0, 0, 0, 1, 180, 100, 1),
(9100037, 1617, 1, 14, 363, 1, 1, -612.6, -4448.1, 45.6, 5.0, 0, 0, 0, 1, 180, 100, 1),
(9100038, 1618, 1, 14, 363, 1, 1, -514.3, -4345.0, 38.3, 0.0, 0, 0, 0, 1, 180, 100, 1),
(9100039, 1617, 1, 14, 363, 1, 1, -717.0, -4150.8, 30.1, 1.0, 0, 0, 0, 1, 180, 100, 1),
(9100040, 1619, 1, 14, 363, 1, 1, -281.0, -4322.8, 62.1, 2.0, 0, 0, 0, 1, 180, 100, 1),
(9100041, 1618, 1, 14, 363, 1, 1, -349.3, -4184.4, 59.2, 3.0, 0, 0, 0, 1, 180, 100, 1),
(9100042, 1617, 1, 14, 363, 1, 1, -675.7, -4350.4, 44.6, 4.0, 0, 0, 0, 1, 180, 100, 1),
(9100043, 1618, 1, 14, 363, 1, 1, -412.6, -4382.8, 39.3, 5.0, 0, 0, 0, 1, 180, 100, 1),
(9100044, 1619, 1, 14, 363, 1, 1, -476.1, -4255.1, 46.1, 0.0, 0, 0, 0, 1, 180, 100, 1),
(9100045, 1617, 1, 14, 363, 1, 1, -754.9, -4219.8, 43.0, 1.0, 0, 0, 0, 1, 180, 100, 1),
(9100046, 1731, 1, 14, 363, 1, 1, -415.4, -4055.6, 52.3, 2.0, 0, 0, 0, 1, 180, 100, 1),
(9100047, 1731, 1, 14, 363, 1, 1, -425.4, -4150.1, 52.1, 3.0, 0, 0, 0, 1, 180, 100, 1),
(9100048, 1731, 1, 14, 363, 1, 1, -519.0, -4076.9, 69.9, 4.0, 0, 0, 0, 1, 180, 100, 1),
(9100049, 1731, 1, 14, 363, 1, 1, -180.7, -4243.6, 56.9, 5.0, 0, 0, 0, 1, 180, 100, 1);
