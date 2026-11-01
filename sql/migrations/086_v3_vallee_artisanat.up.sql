-- v3 (01/11/2026, demande de l'utilisateur) : de quoi fabriquer dès la vallée des Épreuves.
-- - 6 filons de cuivre (1731) sur les bords rocheux de la vallée, aux places de Scorpides ouvriers (hauteur du sol
--   reprise de leur apparition), 3 minutes de réapparition ;
-- - du tissu de lin sur les Vils quasits (3101) : 40 %, 1 ou 2.
-- Les recettes rudimentaires (puissance 3 et 4, sans forge) sont dans la migration 078 (outils\equipement_v3.py).
USE acore_world;

DELETE FROM gameobject WHERE guid BETWEEN 9100028 AND 9100033;
INSERT INTO gameobject (guid, id, map, zoneId, areaId, spawnMask, phaseMask, position_x, position_y, position_z, orientation, rotation0, rotation1, rotation2, rotation3, spawntimesecs, animprogress, state) VALUES
(9100028, 1731, 1, 14, 363, 1, 1, -788.5, -4286.5, 52.8, 0.0, 0, 0, 0, 1, 180, 100, 1),
(9100029, 1731, 1, 14, 363, 1, 1, -610.7, -4084.1, 77.5, 1.0, 0, 0, 0, 1, 180, 100, 1),
(9100030, 1731, 1, 14, 363, 1, 1, -513.2, -4156.6, 77.4, 2.0, 0, 0, 0, 1, 180, 100, 1),
(9100031, 1731, 1, 14, 363, 1, 1, -448.1, -4486.2, 55.3, 3.0, 0, 0, 0, 1, 180, 100, 1),
(9100032, 1731, 1, 14, 363, 1, 1, -304.9, -4437.5, 59.2, 4.0, 0, 0, 0, 1, 180, 100, 1),
(9100033, 1731, 1, 14, 363, 1, 1, -212.5, -4170.8, 65.0, 5.0, 0, 0, 0, 1, 180, 100, 1);

DELETE FROM creature_loot_template WHERE Entry = 3101 AND Item = 2589;
INSERT INTO creature_loot_template (Entry, Item, Reference, Chance, QuestRequired, LootMode, GroupId, MinCount, MaxCount, Comment)
VALUES (3101, 2589, 0, 40, 0, 1, 0, 1, 2, 'Sol''Azeroth v3 - Vile Familiar - Linen Cloth');
