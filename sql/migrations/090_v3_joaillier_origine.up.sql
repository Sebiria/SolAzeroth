-- v3, F8 (01/11/2026) : la joaillerie d'origine disparaît au profit de la nôtre (onglet Joaillerie, migration 085).
-- On retire ce que 16 maîtres joailliers enseignent (listes 111 à 113 : apprentissage et recettes) et les dessins
-- de joaillier (objets classe 9, sous-classe 10) vendus, ou tombés sur les monstres, les objets et les coffres.
-- Tout est gardé dans des tables solazeroth_v3_joaillier_* pour le retour arrière.
USE acore_world;

CREATE TABLE IF NOT EXISTS solazeroth_v3_joaillier_formation LIKE trainer_spell;
INSERT IGNORE INTO solazeroth_v3_joaillier_formation SELECT * FROM trainer_spell WHERE TrainerId IN (111, 112, 113);
DELETE FROM trainer_spell WHERE TrainerId IN (111, 112, 113);

CREATE TEMPORARY TABLE sol_dessins SELECT entry FROM item_template WHERE class = 9 AND subclass = 10;

CREATE TABLE IF NOT EXISTS solazeroth_v3_joaillier_vendeurs LIKE npc_vendor;
INSERT IGNORE INTO solazeroth_v3_joaillier_vendeurs SELECT * FROM npc_vendor WHERE item IN (SELECT entry FROM sol_dessins);
DELETE FROM npc_vendor WHERE item IN (SELECT entry FROM sol_dessins);

CREATE TABLE IF NOT EXISTS solazeroth_v3_joaillier_butin_monstres LIKE creature_loot_template;
INSERT IGNORE INTO solazeroth_v3_joaillier_butin_monstres
    SELECT * FROM creature_loot_template WHERE Item IN (SELECT entry FROM sol_dessins);
DELETE FROM creature_loot_template WHERE Item IN (SELECT entry FROM sol_dessins);

CREATE TABLE IF NOT EXISTS solazeroth_v3_joaillier_butin_references LIKE reference_loot_template;
INSERT IGNORE INTO solazeroth_v3_joaillier_butin_references
    SELECT * FROM reference_loot_template WHERE Item IN (SELECT entry FROM sol_dessins);
DELETE FROM reference_loot_template WHERE Item IN (SELECT entry FROM sol_dessins);

CREATE TABLE IF NOT EXISTS solazeroth_v3_joaillier_butin_coffres LIKE gameobject_loot_template;
INSERT IGNORE INTO solazeroth_v3_joaillier_butin_coffres
    SELECT * FROM gameobject_loot_template WHERE Item IN (SELECT entry FROM sol_dessins);
DELETE FROM gameobject_loot_template WHERE Item IN (SELECT entry FROM sol_dessins);

CREATE TABLE IF NOT EXISTS solazeroth_v3_joaillier_butin_objets LIKE item_loot_template;
INSERT IGNORE INTO solazeroth_v3_joaillier_butin_objets
    SELECT * FROM item_loot_template WHERE Item IN (SELECT entry FROM sol_dessins);
DELETE FROM item_loot_template WHERE Item IN (SELECT entry FROM sol_dessins);

DROP TEMPORARY TABLE sol_dessins;
