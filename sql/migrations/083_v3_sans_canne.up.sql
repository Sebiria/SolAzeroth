-- v3 (31/10/2026, demande de l'utilisateur) : la pêche se fait sans canne (sorts de pêche, migration 073), les cannes
-- à pêche (armes, sous-classe 20) sont retirées du jeu : marchands, butins et récompenses de quête. Ce qui est retiré
-- est gardé dans les tables solazeroth_v3_cannes_*, pour la migration de retour.
USE acore_world;

CREATE TABLE IF NOT EXISTS solazeroth_v3_cannes_marchands SELECT v.* FROM npc_vendor v
    JOIN item_template i ON i.entry = v.item WHERE i.class = 2 AND i.subclass = 20;
DELETE v FROM npc_vendor v JOIN item_template i ON i.entry = v.item WHERE i.class = 2 AND i.subclass = 20;

CREATE TABLE IF NOT EXISTS solazeroth_v3_cannes_butins (source VARCHAR(32) NOT NULL, Entry INT UNSIGNED NOT NULL,
    Item INT UNSIGNED NOT NULL, Reference INT NOT NULL, Chance FLOAT NOT NULL, QuestRequired TINYINT NOT NULL,
    LootMode SMALLINT UNSIGNED NOT NULL, GroupId TINYINT UNSIGNED NOT NULL, MinCount TINYINT UNSIGNED NOT NULL,
    MaxCount TINYINT UNSIGNED NOT NULL, Comment VARCHAR(255));
INSERT INTO solazeroth_v3_cannes_butins SELECT 'creature', l.Entry, l.Item, l.Reference, l.Chance, l.QuestRequired,
    l.LootMode, l.GroupId, l.MinCount, l.MaxCount, l.Comment FROM creature_loot_template l
    JOIN item_template i ON i.entry = l.Item WHERE i.class = 2 AND i.subclass = 20;
INSERT INTO solazeroth_v3_cannes_butins SELECT 'gameobject', l.Entry, l.Item, l.Reference, l.Chance, l.QuestRequired,
    l.LootMode, l.GroupId, l.MinCount, l.MaxCount, l.Comment FROM gameobject_loot_template l
    JOIN item_template i ON i.entry = l.Item WHERE i.class = 2 AND i.subclass = 20;
INSERT INTO solazeroth_v3_cannes_butins SELECT 'reference', l.Entry, l.Item, l.Reference, l.Chance, l.QuestRequired,
    l.LootMode, l.GroupId, l.MinCount, l.MaxCount, l.Comment FROM reference_loot_template l
    JOIN item_template i ON i.entry = l.Item WHERE i.class = 2 AND i.subclass = 20;
INSERT INTO solazeroth_v3_cannes_butins SELECT 'fishing', l.Entry, l.Item, l.Reference, l.Chance, l.QuestRequired,
    l.LootMode, l.GroupId, l.MinCount, l.MaxCount, l.Comment FROM fishing_loot_template l
    JOIN item_template i ON i.entry = l.Item WHERE i.class = 2 AND i.subclass = 20;
INSERT INTO solazeroth_v3_cannes_butins SELECT 'item', l.Entry, l.Item, l.Reference, l.Chance, l.QuestRequired,
    l.LootMode, l.GroupId, l.MinCount, l.MaxCount, l.Comment FROM item_loot_template l
    JOIN item_template i ON i.entry = l.Item WHERE i.class = 2 AND i.subclass = 20;
DELETE l FROM creature_loot_template l JOIN item_template i ON i.entry = l.Item WHERE i.class = 2 AND i.subclass = 20;
DELETE l FROM gameobject_loot_template l JOIN item_template i ON i.entry = l.Item WHERE i.class = 2 AND i.subclass = 20;
DELETE l FROM reference_loot_template l JOIN item_template i ON i.entry = l.Item WHERE i.class = 2 AND i.subclass = 20;
DELETE l FROM fishing_loot_template l JOIN item_template i ON i.entry = l.Item WHERE i.class = 2 AND i.subclass = 20;
DELETE l FROM item_loot_template l JOIN item_template i ON i.entry = l.Item WHERE i.class = 2 AND i.subclass = 20;

-- Récompenses de quête : la canne est retirée de la liste (les autres récompenses restent).
CREATE TABLE IF NOT EXISTS solazeroth_v3_cannes_quetes SELECT ID, RewardItem1, RewardAmount1, RewardItem2, RewardAmount2,
    RewardItem3, RewardAmount3, RewardItem4, RewardAmount4, RewardChoiceItemID1, RewardChoiceItemQuantity1,
    RewardChoiceItemID2, RewardChoiceItemQuantity2, RewardChoiceItemID3, RewardChoiceItemQuantity3, RewardChoiceItemID4,
    RewardChoiceItemQuantity4, RewardChoiceItemID5, RewardChoiceItemQuantity5, RewardChoiceItemID6,
    RewardChoiceItemQuantity6 FROM quest_template q WHERE EXISTS (SELECT 1 FROM item_template i WHERE i.class = 2
    AND i.subclass = 20 AND i.entry IN (q.RewardItem1, q.RewardItem2, q.RewardItem3, q.RewardItem4,
    q.RewardChoiceItemID1, q.RewardChoiceItemID2, q.RewardChoiceItemID3, q.RewardChoiceItemID4, q.RewardChoiceItemID5,
    q.RewardChoiceItemID6));
DROP TEMPORARY TABLE IF EXISTS sol_cannes;
CREATE TEMPORARY TABLE sol_cannes SELECT entry FROM item_template WHERE class = 2 AND subclass = 20;
UPDATE quest_template SET RewardItem1 = 0, RewardAmount1 = 0 WHERE RewardItem1 IN (SELECT entry FROM sol_cannes);
UPDATE quest_template SET RewardItem2 = 0, RewardAmount2 = 0 WHERE RewardItem2 IN (SELECT entry FROM sol_cannes);
UPDATE quest_template SET RewardItem3 = 0, RewardAmount3 = 0 WHERE RewardItem3 IN (SELECT entry FROM sol_cannes);
UPDATE quest_template SET RewardItem4 = 0, RewardAmount4 = 0 WHERE RewardItem4 IN (SELECT entry FROM sol_cannes);
UPDATE quest_template SET RewardChoiceItemID1 = 0, RewardChoiceItemQuantity1 = 0 WHERE RewardChoiceItemID1 IN (SELECT entry FROM sol_cannes);
UPDATE quest_template SET RewardChoiceItemID2 = 0, RewardChoiceItemQuantity2 = 0 WHERE RewardChoiceItemID2 IN (SELECT entry FROM sol_cannes);
UPDATE quest_template SET RewardChoiceItemID3 = 0, RewardChoiceItemQuantity3 = 0 WHERE RewardChoiceItemID3 IN (SELECT entry FROM sol_cannes);
UPDATE quest_template SET RewardChoiceItemID4 = 0, RewardChoiceItemQuantity4 = 0 WHERE RewardChoiceItemID4 IN (SELECT entry FROM sol_cannes);
UPDATE quest_template SET RewardChoiceItemID5 = 0, RewardChoiceItemQuantity5 = 0 WHERE RewardChoiceItemID5 IN (SELECT entry FROM sol_cannes);
UPDATE quest_template SET RewardChoiceItemID6 = 0, RewardChoiceItemQuantity6 = 0 WHERE RewardChoiceItemID6 IN (SELECT entry FROM sol_cannes);
DROP TEMPORARY TABLE sol_cannes;
