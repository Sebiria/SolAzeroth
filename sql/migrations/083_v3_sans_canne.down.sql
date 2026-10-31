-- Rend les cannes à pêche aux marchands, aux butins et aux récompenses de quête.
USE acore_world;
INSERT IGNORE INTO npc_vendor SELECT * FROM solazeroth_v3_cannes_marchands;
INSERT IGNORE INTO creature_loot_template (Entry, Item, Reference, Chance, QuestRequired, LootMode, GroupId, MinCount, MaxCount, Comment)
    SELECT Entry, Item, Reference, Chance, QuestRequired, LootMode, GroupId, MinCount, MaxCount, Comment FROM solazeroth_v3_cannes_butins WHERE source = 'creature';
INSERT IGNORE INTO gameobject_loot_template (Entry, Item, Reference, Chance, QuestRequired, LootMode, GroupId, MinCount, MaxCount, Comment)
    SELECT Entry, Item, Reference, Chance, QuestRequired, LootMode, GroupId, MinCount, MaxCount, Comment FROM solazeroth_v3_cannes_butins WHERE source = 'gameobject';
INSERT IGNORE INTO reference_loot_template (Entry, Item, Reference, Chance, QuestRequired, LootMode, GroupId, MinCount, MaxCount, Comment)
    SELECT Entry, Item, Reference, Chance, QuestRequired, LootMode, GroupId, MinCount, MaxCount, Comment FROM solazeroth_v3_cannes_butins WHERE source = 'reference';
INSERT IGNORE INTO fishing_loot_template (Entry, Item, Reference, Chance, QuestRequired, LootMode, GroupId, MinCount, MaxCount, Comment)
    SELECT Entry, Item, Reference, Chance, QuestRequired, LootMode, GroupId, MinCount, MaxCount, Comment FROM solazeroth_v3_cannes_butins WHERE source = 'fishing';
INSERT IGNORE INTO item_loot_template (Entry, Item, Reference, Chance, QuestRequired, LootMode, GroupId, MinCount, MaxCount, Comment)
    SELECT Entry, Item, Reference, Chance, QuestRequired, LootMode, GroupId, MinCount, MaxCount, Comment FROM solazeroth_v3_cannes_butins WHERE source = 'item';
UPDATE quest_template q JOIN solazeroth_v3_cannes_quetes o ON o.ID = q.ID SET q.RewardItem1 = o.RewardItem1,
    q.RewardAmount1 = o.RewardAmount1, q.RewardItem2 = o.RewardItem2, q.RewardAmount2 = o.RewardAmount2,
    q.RewardItem3 = o.RewardItem3, q.RewardAmount3 = o.RewardAmount3, q.RewardItem4 = o.RewardItem4,
    q.RewardAmount4 = o.RewardAmount4, q.RewardChoiceItemID1 = o.RewardChoiceItemID1,
    q.RewardChoiceItemQuantity1 = o.RewardChoiceItemQuantity1, q.RewardChoiceItemID2 = o.RewardChoiceItemID2,
    q.RewardChoiceItemQuantity2 = o.RewardChoiceItemQuantity2, q.RewardChoiceItemID3 = o.RewardChoiceItemID3,
    q.RewardChoiceItemQuantity3 = o.RewardChoiceItemQuantity3, q.RewardChoiceItemID4 = o.RewardChoiceItemID4,
    q.RewardChoiceItemQuantity4 = o.RewardChoiceItemQuantity4, q.RewardChoiceItemID5 = o.RewardChoiceItemID5,
    q.RewardChoiceItemQuantity5 = o.RewardChoiceItemQuantity5, q.RewardChoiceItemID6 = o.RewardChoiceItemID6,
    q.RewardChoiceItemQuantity6 = o.RewardChoiceItemQuantity6;
DROP TABLE solazeroth_v3_cannes_marchands, solazeroth_v3_cannes_butins, solazeroth_v3_cannes_quetes;
