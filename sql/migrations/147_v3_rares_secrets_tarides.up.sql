-- Lot T6 des Tarides (03/11/2026) : cinq rares secrets des Tarides. Généré par outils\rares_secrets_v3.py tarides :
-- ne pas modifier à la main. Scripts : v3_rares_secrets.cpp ; liste dans solazeroth_v3_rares_secrets (migration 121).
USE acore_world;

-- Collier, bague et deux bijoux : bleus, puissance 38, sans condition ni rangs, uniques.
CREATE TEMPORARY TABLE sol_objet SELECT * FROM item_template WHERE entry = 7731;
UPDATE sol_objet SET entry = 910302, name = 'Collier du rêve brisé', description = 'Vylas le portait quand le cauchemar l''a pris ; il en garde le froid.', Quality = 3, bonding = 1, ItemLevel = 38, RequiredLevel = 0, RequiredSkill = 0, RequiredSkillRank = 0, AllowableClass = -1, AllowableRace = -1, maxcount = 1, BuyPrice = 0, SellPrice = 0, RandomProperty = 0, RandomSuffix = 0, itemset = 0, spellid_1 = 0, spelltrigger_1 = 0, spellid_2 = 0, spelltrigger_2 = 0, armor = 0, dmg_min1 = 0, dmg_max1 = 0, block = 0, stat_type1 = 38, stat_value1 = 13, stat_type2 = 7, stat_value2 = 3, stat_type3 = 0, stat_value3 = 0, stat_type4 = 0, stat_value4 = 0, stat_type5 = 0, stat_value5 = 0, stat_type6 = 0, stat_value6 = 0, stat_type7 = 0, stat_value7 = 0, stat_type8 = 0, stat_value8 = 0, stat_type9 = 0, stat_value9 = 0, stat_type10 = 0, stat_value10 = 0;
INSERT INTO item_template SELECT * FROM sol_objet;
DROP TEMPORARY TABLE sol_objet;
INSERT INTO item_template_locale (ID, locale, Name, Description, VerifiedBuild) VALUES (910302, 'frFR', 'Collier du rêve brisé', '', 0);
UPDATE item_template_locale SET Description = 'Vylas le portait quand le cauchemar l''a pris ; il en garde le froid.' WHERE ID = 910302 AND locale = 'frFR';
CREATE TEMPORARY TABLE sol_objet SELECT * FROM item_template WHERE entry = 5007;
UPDATE sol_objet SET entry = 910303, name = 'Anneau d''épine de sang', description = 'Taillé dans une épine du Rejeton : il pique encore la main qui le serre.', Quality = 3, bonding = 1, ItemLevel = 38, RequiredLevel = 0, RequiredSkill = 0, RequiredSkillRank = 0, AllowableClass = -1, AllowableRace = -1, maxcount = 1, BuyPrice = 0, SellPrice = 0, RandomProperty = 0, RandomSuffix = 0, itemset = 0, spellid_1 = 0, spelltrigger_1 = 0, spellid_2 = 0, spelltrigger_2 = 0, armor = 0, dmg_min1 = 0, dmg_max1 = 0, block = 0, stat_type1 = 38, stat_value1 = 13, stat_type2 = 7, stat_value2 = 3, stat_type3 = 0, stat_value3 = 0, stat_type4 = 0, stat_value4 = 0, stat_type5 = 0, stat_value5 = 0, stat_type6 = 0, stat_value6 = 0, stat_type7 = 0, stat_value7 = 0, stat_type8 = 0, stat_value8 = 0, stat_type9 = 0, stat_value9 = 0, stat_type10 = 0, stat_value10 = 0;
INSERT INTO item_template SELECT * FROM sol_objet;
DROP TEMPORARY TABLE sol_objet;
INSERT INTO item_template_locale (ID, locale, Name, Description, VerifiedBuild) VALUES (910303, 'frFR', 'Anneau d''épine de sang', '', 0);
UPDATE item_template_locale SET Description = 'Taillé dans une épine du Rejeton : il pique encore la main qui le serre.' WHERE ID = 910303 AND locale = 'frFR';
CREATE TEMPORARY TABLE sol_objet SELECT * FROM item_template WHERE entry = 4381;
UPDATE sol_objet SET entry = 910304, name = 'Régulateur surchauffé', description = 'Il chauffe toujours un peu ; le prototype n''a jamais su s''arrêter.', Quality = 3, bonding = 1, ItemLevel = 38, RequiredLevel = 0, RequiredSkill = 0, RequiredSkillRank = 0, AllowableClass = -1, AllowableRace = -1, maxcount = 1, BuyPrice = 0, SellPrice = 0, RandomProperty = 0, RandomSuffix = 0, itemset = 0, spellid_1 = 0, spelltrigger_1 = 0, spellid_2 = 0, spelltrigger_2 = 0, armor = 0, dmg_min1 = 0, dmg_max1 = 0, block = 0, stat_type1 = 38, stat_value1 = 13, stat_type2 = 7, stat_value2 = 3, stat_type3 = 0, stat_value3 = 0, stat_type4 = 0, stat_value4 = 0, stat_type5 = 0, stat_value5 = 0, stat_type6 = 0, stat_value6 = 0, stat_type7 = 0, stat_value7 = 0, stat_type8 = 0, stat_value8 = 0, stat_type9 = 0, stat_value9 = 0, stat_type10 = 0, stat_value10 = 0;
INSERT INTO item_template SELECT * FROM sol_objet;
DROP TEMPORARY TABLE sol_objet;
INSERT INTO item_template_locale (ID, locale, Name, Description, VerifiedBuild) VALUES (910304, 'frFR', 'Régulateur surchauffé', '', 0);
UPDATE item_template_locale SET Description = 'Il chauffe toujours un peu ; le prototype n''a jamais su s''arrêter.' WHERE ID = 910304 AND locale = 'frFR';
CREATE TEMPORARY TABLE sol_objet SELECT * FROM item_template WHERE entry = 19992;
UPDATE sol_objet SET entry = 910305, name = 'Dent de Mâchoire-des-sables', description = 'Arrachée au requin qui nageait dans le sable ; elle grince encore.', Quality = 3, bonding = 1, ItemLevel = 38, RequiredLevel = 0, RequiredSkill = 0, RequiredSkillRank = 0, AllowableClass = -1, AllowableRace = -1, maxcount = 1, BuyPrice = 0, SellPrice = 0, RandomProperty = 0, RandomSuffix = 0, itemset = 0, spellid_1 = 0, spelltrigger_1 = 0, spellid_2 = 0, spelltrigger_2 = 0, armor = 0, dmg_min1 = 0, dmg_max1 = 0, block = 0, stat_type1 = 38, stat_value1 = 13, stat_type2 = 7, stat_value2 = 3, stat_type3 = 0, stat_value3 = 0, stat_type4 = 0, stat_value4 = 0, stat_type5 = 0, stat_value5 = 0, stat_type6 = 0, stat_value6 = 0, stat_type7 = 0, stat_value7 = 0, stat_type8 = 0, stat_value8 = 0, stat_type9 = 0, stat_value9 = 0, stat_type10 = 0, stat_value10 = 0;
INSERT INTO item_template SELECT * FROM sol_objet;
DROP TEMPORARY TABLE sol_objet;
INSERT INTO item_template_locale (ID, locale, Name, Description, VerifiedBuild) VALUES (910305, 'frFR', 'Dent de Mâchoire-des-sables', '', 0);
UPDATE item_template_locale SET Description = 'Arrachée au requin qui nageait dans le sable ; elle grince encore.' WHERE ID = 910305 AND locale = 'frFR';

-- Apparitions d'origine des rares copiés (Bras-de-pierre, Requin du sable) : retirées, table de retour.
CREATE TABLE solazeroth_v3_t6_apparitions SELECT * FROM creature WHERE guid IN (20635, 43494);
CREATE TABLE solazeroth_v3_t6_apparitions_addon SELECT * FROM creature_addon WHERE guid IN (20635, 43494);
DELETE FROM creature_addon WHERE guid IN (20635, 43494);
DELETE FROM creature WHERE guid IN (20635, 43494);

-- Les rares : puissance 35, rang 4 (rare), vie et dégâts réglés par simulation ; sans le script d'origine.
CREATE TEMPORARY TABLE sol_t SELECT * FROM creature_template WHERE entry = 3840;
UPDATE sol_t SET entry = 910043, name = 'Vylas Crocsonge', subname = 'Druide du Croc égaré', KillCredit1 = 0, KillCredit2 = 0, pickpocketloot = 0, `rank` = 4, minlevel = 35, maxlevel = 35, HealthModifier = 0.697, DamageModifier = 1.589, AIName = 'SmartAI', ScriptName = '', lootid = 910043, mingold = 0, maxgold = 0;
INSERT INTO creature_template SELECT * FROM sol_t;
DROP TEMPORARY TABLE sol_t;
INSERT INTO creature_template_model (CreatureID, Idx, CreatureDisplayID, DisplayScale, Probability, VerifiedBuild) SELECT 910043, Idx, CreatureDisplayID, DisplayScale, Probability, VerifiedBuild FROM creature_template_model WHERE CreatureID = 3840;
INSERT INTO creature_template_locale (entry, locale, Name, Title, VerifiedBuild) VALUES (910043, 'frFR', 'Vylas Crocsonge', 'Druide du Croc égaré', 0);
UPDATE creature_template_model SET DisplayScale = DisplayScale * 1.3 WHERE CreatureID = 910043;
INSERT INTO creature_equip_template (CreatureID, ID, ItemID1, ItemID2, ItemID3, VerifiedBuild) SELECT 910043, ID, ItemID1, ItemID2, ItemID3, 0 FROM creature_equip_template WHERE CreatureID = 3840;
INSERT INTO creature (guid, id, map, zoneId, areaId, spawnMask, phaseMask, equipment_id, position_x, position_y, position_z, orientation, spawntimesecs, wander_distance, MovementType) VALUES (9100043, 910043, 1, 17, 0, 1, 1, 1, -1055, -2285, 91.9, 0.6, 1800, 0, 0);
INSERT INTO creature_loot_template (Entry, Item, Reference, Chance, QuestRequired, LootMode, GroupId, MinCount, MaxCount, Comment) VALUES (910043, 910302, 0, 100, 0, 1, 0, 1, 1, 'Sol''Azeroth v3 : rare secret');
CREATE TEMPORARY TABLE sol_t SELECT * FROM creature_template WHERE entry = 4514;
UPDATE sol_t SET entry = 910044, name = 'Échine-de-ronce', subname = 'Rejeton d''Agammagan', KillCredit1 = 0, KillCredit2 = 0, pickpocketloot = 0, `rank` = 4, minlevel = 35, maxlevel = 35, HealthModifier = 0.843, DamageModifier = 1.051, AIName = 'SmartAI', ScriptName = '', lootid = 910044, mingold = 0, maxgold = 0;
INSERT INTO creature_template SELECT * FROM sol_t;
DROP TEMPORARY TABLE sol_t;
INSERT INTO creature_template_model (CreatureID, Idx, CreatureDisplayID, DisplayScale, Probability, VerifiedBuild) SELECT 910044, Idx, CreatureDisplayID, DisplayScale, Probability, VerifiedBuild FROM creature_template_model WHERE CreatureID = 4514;
INSERT INTO creature_template_locale (entry, locale, Name, Title, VerifiedBuild) VALUES (910044, 'frFR', 'Échine-de-ronce', 'Rejeton d''Agammagan', 0);
UPDATE creature_template_model SET DisplayScale = DisplayScale * 1.3 WHERE CreatureID = 910044;
INSERT INTO creature_equip_template (CreatureID, ID, ItemID1, ItemID2, ItemID3, VerifiedBuild) SELECT 910044, ID, ItemID1, ItemID2, ItemID3, 0 FROM creature_equip_template WHERE CreatureID = 4514;
INSERT INTO creature (guid, id, map, zoneId, areaId, spawnMask, phaseMask, equipment_id, position_x, position_y, position_z, orientation, spawntimesecs, wander_distance, MovementType) VALUES (9100044, 910044, 1, 17, 0, 1, 1, 1, -3250, -1860, 93.0, 1.0, 1800, 0, 0);
INSERT INTO creature_loot_template (Entry, Item, Reference, Chance, QuestRequired, LootMode, GroupId, MinCount, MaxCount, Comment) VALUES (910044, 910303, 0, 100, 0, 1, 0, 1, 1, 'Sol''Azeroth v3 : rare secret');
CREATE TEMPORARY TABLE sol_t SELECT * FROM creature_template WHERE entry = 3439;
UPDATE sol_t SET entry = 910045, name = 'Prototype XT-0', subname = '', KillCredit1 = 0, KillCredit2 = 0, pickpocketloot = 0, `rank` = 4, minlevel = 35, maxlevel = 35, HealthModifier = 0.557, DamageModifier = 1.531, AIName = 'SmartAI', ScriptName = '', lootid = 910045, mingold = 0, maxgold = 0, faction = 16;
INSERT INTO creature_template SELECT * FROM sol_t;
DROP TEMPORARY TABLE sol_t;
INSERT INTO creature_template_model (CreatureID, Idx, CreatureDisplayID, DisplayScale, Probability, VerifiedBuild) SELECT 910045, Idx, CreatureDisplayID, DisplayScale, Probability, VerifiedBuild FROM creature_template_model WHERE CreatureID = 3439;
INSERT INTO creature_template_locale (entry, locale, Name, Title, VerifiedBuild) VALUES (910045, 'frFR', 'Prototype XT-0', '', 0);
UPDATE creature_template_model SET DisplayScale = DisplayScale * 1.3 WHERE CreatureID = 910045;
INSERT INTO creature_equip_template (CreatureID, ID, ItemID1, ItemID2, ItemID3, VerifiedBuild) SELECT 910045, ID, ItemID1, ItemID2, ItemID3, 0 FROM creature_equip_template WHERE CreatureID = 3439;
INSERT INTO creature (guid, id, map, zoneId, areaId, spawnMask, phaseMask, equipment_id, position_x, position_y, position_z, orientation, spawntimesecs, wander_distance, MovementType) VALUES (9100045, 910045, 1, 17, 0, 1, 1, 1, 1241, -3596, 90.3, 2.4, 1800, 0, 0);
INSERT INTO creature_loot_template (Entry, Item, Reference, Chance, QuestRequired, LootMode, GroupId, MinCount, MaxCount, Comment) VALUES (910045, 910304, 0, 100, 0, 1, 0, 1, 1, 'Sol''Azeroth v3 : rare secret');
CREATE TEMPORARY TABLE sol_t SELECT * FROM creature_template WHERE entry = 5837;
UPDATE sol_t SET entry = 910046, name = 'Bras-de-pierre', subname = 'Khan déchu des Kolkar', KillCredit1 = 0, KillCredit2 = 0, pickpocketloot = 0, `rank` = 4, minlevel = 35, maxlevel = 35, HealthModifier = 0.903, DamageModifier = 0.993, AIName = 'SmartAI', ScriptName = '', lootid = 0, mingold = 0, maxgold = 0;
INSERT INTO creature_template SELECT * FROM sol_t;
DROP TEMPORARY TABLE sol_t;
INSERT INTO creature_template_model (CreatureID, Idx, CreatureDisplayID, DisplayScale, Probability, VerifiedBuild) SELECT 910046, Idx, CreatureDisplayID, DisplayScale, Probability, VerifiedBuild FROM creature_template_model WHERE CreatureID = 5837;
INSERT INTO creature_template_locale (entry, locale, Name, Title, VerifiedBuild) VALUES (910046, 'frFR', 'Bras-de-pierre', 'Khan déchu des Kolkar', 0);
UPDATE creature_template_model SET DisplayScale = DisplayScale * 1.3 WHERE CreatureID = 910046;
INSERT INTO creature_equip_template (CreatureID, ID, ItemID1, ItemID2, ItemID3, VerifiedBuild) SELECT 910046, ID, ItemID1, ItemID2, ItemID3, 0 FROM creature_equip_template WHERE CreatureID = 5837;
INSERT INTO creature (guid, id, map, zoneId, areaId, spawnMask, phaseMask, equipment_id, position_x, position_y, position_z, orientation, spawntimesecs, wander_distance, MovementType) VALUES (9100046, 910046, 1, 17, 0, 1, 1, 1, 395, -1360, 92.3, 3.1, 1800, 0, 0);
CREATE TEMPORARY TABLE sol_t SELECT * FROM creature_template WHERE entry = 5435;
UPDATE sol_t SET entry = 910047, name = 'Mâchoire-des-sables', subname = 'Requin du sable', KillCredit1 = 0, KillCredit2 = 0, pickpocketloot = 0, `rank` = 4, minlevel = 35, maxlevel = 35, HealthModifier = 0.909, DamageModifier = 1.000, AIName = 'SmartAI', ScriptName = '', lootid = 910047, mingold = 0, maxgold = 0;
INSERT INTO creature_template SELECT * FROM sol_t;
DROP TEMPORARY TABLE sol_t;
INSERT INTO creature_template_model (CreatureID, Idx, CreatureDisplayID, DisplayScale, Probability, VerifiedBuild) SELECT 910047, Idx, CreatureDisplayID, DisplayScale, Probability, VerifiedBuild FROM creature_template_model WHERE CreatureID = 5435;
INSERT INTO creature_template_locale (entry, locale, Name, Title, VerifiedBuild) VALUES (910047, 'frFR', 'Mâchoire-des-sables', 'Requin du sable', 0);
UPDATE creature_template_model SET DisplayScale = DisplayScale * 1.3 WHERE CreatureID = 910047;
INSERT INTO creature_equip_template (CreatureID, ID, ItemID1, ItemID2, ItemID3, VerifiedBuild) SELECT 910047, ID, ItemID1, ItemID2, ItemID3, 0 FROM creature_equip_template WHERE CreatureID = 5435;
INSERT INTO creature_template_movement (CreatureId, Ground, Swim, Flight, Rooted, Chase, Random) VALUES (910047, 1, 1, 0, 0, 0, 0);
INSERT INTO creature (guid, id, map, zoneId, areaId, spawnMask, phaseMask, equipment_id, position_x, position_y, position_z, orientation, spawntimesecs, wander_distance, MovementType) VALUES (9100047, 910047, 1, 17, 0, 1, 1, 1, -1222, -3888, 12.1, 0.8, 1800, 0, 0);
INSERT INTO creature_loot_template (Entry, Item, Reference, Chance, QuestRequired, LootMode, GroupId, MinCount, MaxCount, Comment) VALUES (910047, 910305, 0, 100, 0, 1, 0, 1, 1, 'Sol''Azeroth v3 : rare secret');
INSERT INTO smart_scripts (entryorguid, source_type, id, link, event_type, event_phase_mask, event_chance, event_flags, event_param1, event_param2, event_param3, event_param4, event_param5, event_param6, action_type, action_param1, action_param2, action_param3, action_param4, action_param5, action_param6, target_type, target_param1, target_param2, target_param3, target_param4, target_x, target_y, target_z, target_o, comment) VALUES
(910043, 0, 0, 0, 0, 0, 100, 0, 8000, 10000, 25000, 25000, 0, 0, 11, 31541, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Vylas - Sommeil (5 s)'),
(910043, 0, 1, 0, 2, 0, 100, 1, 0, 50, 0, 0, 0, 0, 11, 8599, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Vylas - Enrager sous 50 %'),
(910043, 0, 2, 0, 2, 0, 100, 0, 0, 50, 6000, 8000, 0, 0, 11, 14795, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Vylas - Poison de Peau-de-venin sous 50 %'),
(910044, 0, 0, 0, 9, 0, 100, 0, 8, 30, 12000, 15000, 0, 0, 11, 51756, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Échine-de-ronce - Charge des ronces à plus de 8 m'),
(910044, 0, 1, 0, 0, 0, 100, 0, 6000, 8000, 20000, 20000, 0, 0, 11, 51439, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Échine-de-ronce - Contrecoup (renvoi, 6 s)'),
(910045, 0, 0, 0, 0, 0, 100, 0, 5000, 7000, 15000, 15000, 0, 0, 11, 17207, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'XT-0 - Tourbillon'),
(910045, 0, 1, 0, 2, 0, 100, 1, 0, 30, 0, 0, 0, 0, 11, 8269, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'XT-0 - Surchauffe (Frénésie) sous 30 %'),
(910046, 0, 0, 0, 4, 0, 100, 0, 0, 0, 0, 0, 0, 0, 11, 51756, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Bras-de-pierre - Charge kolkar'),
(910046, 0, 1, 0, 0, 0, 100, 0, 6000, 8000, 18000, 18000, 0, 0, 11, 8078, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Bras-de-pierre - Coup de tonnerre'),
(910047, 0, 0, 0, 4, 0, 100, 0, 0, 0, 0, 0, 0, 0, 11, 51756, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Mâchoire-des-sables - Surgir du sable'),
(910047, 0, 1, 0, 0, 0, 100, 0, 5000, 7000, 20000, 20000, 0, 0, 11, 9493, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Mâchoire-des-sables - Déchirure');

-- Liste lue par v3_rares_secrets.cpp (table de la migration 121) ; vaincus par personnage.
REPLACE INTO solazeroth_v3_rares_secrets VALUES (910043, 17, 0), (910044, 17, 0), (910045, 17, 0), (910046, 17, 48954), (910047, 17, 0);

-- La monture devient secrète : hors de la boutique, vitesse 60 % (montures_v3.SECRETES, Spell.dbc du patch).
DELETE FROM solazeroth_v3_montures WHERE sort IN (48954, 49322);
UPDATE spell_dbc SET EffectBasePoints_2 = 59 WHERE ID IN (48954, 49322);
