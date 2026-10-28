-- Retour arrière de 045 : plus de chaîne d'histoire
USE acore_world;

DELETE FROM creature_queststarter WHERE quest BETWEEN 900200 AND 900215;
DELETE FROM creature_questender WHERE quest BETWEEN 900200 AND 900215;
DELETE FROM quest_request_items WHERE ID BETWEEN 900200 AND 900215;
DELETE FROM quest_offer_reward WHERE ID BETWEEN 900200 AND 900215;
DELETE FROM quest_template_addon WHERE ID BETWEEN 900200 AND 900215;
DELETE FROM quest_template WHERE ID BETWEEN 900200 AND 900215;
DELETE FROM creature WHERE guid IN (9001200, 9001201);
DELETE FROM creature_template_model WHERE CreatureID = 900120;
DELETE FROM creature_template WHERE entry BETWEEN 900120 AND 900125;
DROP TABLE solazeroth_histoire;
DROP TABLE solazeroth_histoire_temoins;
