-- Retire le chapitre « Les cultes de la mort » (059_chapitre_cultes.up.sql).
USE acore_world;

DELETE FROM solazeroth_histoire WHERE quete = 900216;
UPDATE solazeroth_histoire SET chapitre = chapitre - 1 WHERE chapitre >= 5 ORDER BY chapitre ASC;
UPDATE quest_template_addon SET PrevQuestID = 900202 WHERE ID = 900203;
DELETE FROM creature_queststarter WHERE quest = 900216;
DELETE FROM creature_questender WHERE quest = 900216;
DELETE FROM quest_request_items WHERE ID = 900216;
DELETE FROM quest_offer_reward WHERE ID = 900216;
DELETE FROM quest_template_addon WHERE ID = 900216;
DELETE FROM quest_template WHERE ID = 900216;
UPDATE quest_template SET LogTitle = REPLACE(LogTitle, 'Fléau 1/17 :', 'Fléau 1/16 :') WHERE ID = 900200;
UPDATE quest_template SET LogTitle = REPLACE(LogTitle, 'Fléau 2/17 :', 'Fléau 2/16 :') WHERE ID = 900201;
UPDATE quest_template SET LogTitle = REPLACE(LogTitle, 'Fléau 3/17 :', 'Fléau 3/16 :') WHERE ID = 900202;
UPDATE quest_template SET LogTitle = REPLACE(LogTitle, 'Fléau 5/17 :', 'Fléau 4/16 :') WHERE ID = 900203;
UPDATE quest_template SET LogTitle = REPLACE(LogTitle, 'Fléau 6/17 :', 'Fléau 5/16 :') WHERE ID = 900204;
UPDATE quest_template SET LogTitle = REPLACE(LogTitle, 'Fléau 7/17 :', 'Fléau 6/16 :') WHERE ID = 900205;
UPDATE quest_template SET LogTitle = REPLACE(LogTitle, 'Fléau 8/17 :', 'Fléau 7/16 :') WHERE ID = 900206;
UPDATE quest_template SET LogTitle = REPLACE(LogTitle, 'Fléau 9/17 :', 'Fléau 8/16 :') WHERE ID = 900207;
UPDATE quest_template SET LogTitle = REPLACE(LogTitle, 'Fléau 10/17 :', 'Fléau 9/16 :') WHERE ID = 900208;
UPDATE quest_template SET LogTitle = REPLACE(LogTitle, 'Fléau 11/17 :', 'Fléau 10/16 :') WHERE ID = 900209;
UPDATE quest_template SET LogTitle = REPLACE(LogTitle, 'Fléau 12/17 :', 'Fléau 11/16 :') WHERE ID = 900210;
UPDATE quest_template SET LogTitle = REPLACE(LogTitle, 'Fléau 13/17 :', 'Fléau 12/16 :') WHERE ID = 900211;
UPDATE quest_template SET LogTitle = REPLACE(LogTitle, 'Fléau 14/17 :', 'Fléau 13/16 :') WHERE ID = 900212;
UPDATE quest_template SET LogTitle = REPLACE(LogTitle, 'Fléau 15/17 :', 'Fléau 14/16 :') WHERE ID = 900213;
UPDATE quest_template SET LogTitle = REPLACE(LogTitle, 'Fléau 16/17 :', 'Fléau 15/16 :') WHERE ID = 900214;
UPDATE quest_template SET LogTitle = REPLACE(LogTitle, 'Fléau 17/17 :', 'Fléau 16/16 :') WHERE ID = 900215;
