-- Audit du jeu, lot 6b (02/11/2026, C8) : trois rares secrets de Durotar. Généré par outils\rares_secrets_v3.py :
-- ne pas modifier à la main. Scripts : v3_rares_secrets.cpp.
USE acore_world;

-- Bijou et bague : bleus, puissance 18, sans condition ni rangs, uniques.
CREATE TEMPORARY TABLE sol_objet SELECT * FROM item_template WHERE entry = 21568;
UPDATE sol_objet SET entry = 910300, name = 'Braise du Gardien', description = 'Elle ne s''éteint jamais tout à fait ; la Lame la croyait perdue.', Quality = 3, bonding = 1, ItemLevel = 18, RequiredLevel = 0, RequiredSkill = 0, RequiredSkillRank = 0, AllowableClass = -1, AllowableRace = -1, maxcount = 1, BuyPrice = 0, SellPrice = 0, RandomProperty = 0, RandomSuffix = 0, itemset = 0, spellid_1 = 0, spelltrigger_1 = 0, spellid_2 = 0, spelltrigger_2 = 0, armor = 0, dmg_min1 = 0, dmg_max1 = 0, block = 0, stat_type1 = 38, stat_value1 = 6, stat_type2 = 7, stat_value2 = 1, stat_type3 = 0, stat_value3 = 0, stat_type4 = 0, stat_value4 = 0, stat_type5 = 0, stat_value5 = 0, stat_type6 = 0, stat_value6 = 0, stat_type7 = 0, stat_value7 = 0, stat_type8 = 0, stat_value8 = 0, stat_type9 = 0, stat_value9 = 0, stat_type10 = 0, stat_value10 = 0;
INSERT INTO item_template SELECT * FROM sol_objet;
DROP TEMPORARY TABLE sol_objet;
INSERT INTO item_template_locale (ID, locale, Name, Description, VerifiedBuild) VALUES (910300, 'frFR', 'Braise du Gardien', '', 0);
UPDATE item_template_locale SET Description = 'Elle ne s''éteint jamais tout à fait ; la Lame la croyait perdue.' WHERE ID = 910300 AND locale = 'frFR';
CREATE TEMPORARY TABLE sol_objet SELECT * FROM item_template WHERE entry = 6332;
UPDATE sol_objet SET entry = 910301, name = 'Perle de Hurlevague', description = 'Le capitaine la serrait encore quand la mer l''a rendu à la côte.', Quality = 3, bonding = 1, ItemLevel = 18, RequiredLevel = 0, RequiredSkill = 0, RequiredSkillRank = 0, AllowableClass = -1, AllowableRace = -1, maxcount = 1, BuyPrice = 0, SellPrice = 0, RandomProperty = 0, RandomSuffix = 0, itemset = 0, spellid_1 = 0, spelltrigger_1 = 0, spellid_2 = 0, spelltrigger_2 = 0, armor = 0, dmg_min1 = 0, dmg_max1 = 0, block = 0, stat_type1 = 38, stat_value1 = 6, stat_type2 = 7, stat_value2 = 1, stat_type3 = 0, stat_value3 = 0, stat_type4 = 0, stat_value4 = 0, stat_type5 = 0, stat_value5 = 0, stat_type6 = 0, stat_value6 = 0, stat_type7 = 0, stat_value7 = 0, stat_type8 = 0, stat_value8 = 0, stat_type9 = 0, stat_value9 = 0, stat_type10 = 0, stat_value10 = 0;
INSERT INTO item_template SELECT * FROM sol_objet;
DROP TEMPORARY TABLE sol_objet;
INSERT INTO item_template_locale (ID, locale, Name, Description, VerifiedBuild) VALUES (910301, 'frFR', 'Perle de Hurlevague', '', 0);
UPDATE item_template_locale SET Description = 'Le capitaine la serrait encore quand la mer l''a rendu à la côte.' WHERE ID = 910301 AND locale = 'frFR';

-- Les rares : puissance 15, rang 4 (rare), vie et dégâts réglés par simulation ; sans le script d'origine.
CREATE TEMPORARY TABLE sol_t SELECT * FROM creature_template WHERE entry = 3206;
UPDATE sol_t SET entry = 910040, name = 'Zal''mara la Renégate', subname = '', KillCredit1 = 0, KillCredit2 = 0, pickpocketloot = 0, `rank` = 4, minlevel = 15, maxlevel = 15, HealthModifier = 1.670, DamageModifier = 1.447, AIName = 'SmartAI', ScriptName = '', lootid = 0, mingold = 0, maxgold = 0;
INSERT INTO creature_template SELECT * FROM sol_t;
DROP TEMPORARY TABLE sol_t;
INSERT INTO creature_template_model (CreatureID, Idx, CreatureDisplayID, DisplayScale, Probability, VerifiedBuild) SELECT 910040, Idx, CreatureDisplayID, DisplayScale, Probability, VerifiedBuild FROM creature_template_model WHERE CreatureID = 3206;
INSERT INTO creature_template_locale (entry, locale, Name, Title, VerifiedBuild) VALUES (910040, 'frFR', 'Zal''mara la Renégate', '', 0);
UPDATE creature_template_model SET DisplayScale = DisplayScale * 1.3 WHERE CreatureID = 910040;
INSERT INTO creature_equip_template (CreatureID, ID, ItemID1, ItemID2, ItemID3, VerifiedBuild) SELECT 910040, ID, ItemID1, ItemID2, ItemID3, 0 FROM creature_equip_template WHERE CreatureID = 3206;
INSERT INTO creature (guid, id, map, zoneId, areaId, spawnMask, phaseMask, equipment_id, position_x, position_y, position_z, orientation, spawntimesecs, wander_distance, MovementType) VALUES (9100040, 910040, 1, 14, 0, 1, 1, 1, -1626, -5350, 7.2, 2.0, 1800, 0, 0);
CREATE TEMPORARY TABLE sol_t SELECT * FROM creature_template WHERE entry = 3197;
UPDATE sol_t SET entry = 910041, name = 'Gardien cendré', subname = 'La Lame ardente', KillCredit1 = 0, KillCredit2 = 0, pickpocketloot = 0, `rank` = 4, minlevel = 15, maxlevel = 15, HealthModifier = 2.172, DamageModifier = 1.157, AIName = 'SmartAI', ScriptName = '', lootid = 910041, mingold = 0, maxgold = 0;
INSERT INTO creature_template SELECT * FROM sol_t;
DROP TEMPORARY TABLE sol_t;
INSERT INTO creature_template_model (CreatureID, Idx, CreatureDisplayID, DisplayScale, Probability, VerifiedBuild) SELECT 910041, Idx, CreatureDisplayID, DisplayScale, Probability, VerifiedBuild FROM creature_template_model WHERE CreatureID = 3197;
INSERT INTO creature_template_locale (entry, locale, Name, Title, VerifiedBuild) VALUES (910041, 'frFR', 'Gardien cendré', 'La Lame ardente', 0);
UPDATE creature_template_model SET DisplayScale = DisplayScale * 1.3 WHERE CreatureID = 910041;
INSERT INTO creature_equip_template (CreatureID, ID, ItemID1, ItemID2, ItemID3, VerifiedBuild) SELECT 910041, ID, ItemID1, ItemID2, ItemID3, 0 FROM creature_equip_template WHERE CreatureID = 3197;
INSERT INTO creature (guid, id, map, zoneId, areaId, spawnMask, phaseMask, equipment_id, position_x, position_y, position_z, orientation, spawntimesecs, wander_distance, MovementType) VALUES (9100041, 910041, 1, 14, 0, 1, 1, 1, 1470, -4930, 8.3, 5.2, 1800, 0, 0);
INSERT INTO creature_loot_template (Entry, Item, Reference, Chance, QuestRequired, LootMode, GroupId, MinCount, MaxCount, Comment) VALUES (910041, 910300, 0, 100, 0, 1, 0, 1, 1, 'Sol''Azeroth v3 : rare secret');
CREATE TEMPORARY TABLE sol_t SELECT * FROM creature_template WHERE entry = 3128;
UPDATE sol_t SET entry = 910042, name = 'Capitaine Hurlevague', subname = 'Noyé de Kul Tiras', KillCredit1 = 0, KillCredit2 = 0, pickpocketloot = 0, `rank` = 4, minlevel = 15, maxlevel = 15, HealthModifier = 1.602, DamageModifier = 1.285, AIName = 'SmartAI', ScriptName = '', lootid = 910042, mingold = 0, maxgold = 0;
INSERT INTO creature_template SELECT * FROM sol_t;
DROP TEMPORARY TABLE sol_t;
INSERT INTO creature_template_model (CreatureID, Idx, CreatureDisplayID, DisplayScale, Probability, VerifiedBuild) SELECT 910042, Idx, CreatureDisplayID, DisplayScale, Probability, VerifiedBuild FROM creature_template_model WHERE CreatureID = 3128;
INSERT INTO creature_template_locale (entry, locale, Name, Title, VerifiedBuild) VALUES (910042, 'frFR', 'Capitaine Hurlevague', 'Noyé de Kul Tiras', 0);
UPDATE creature_template_model SET DisplayScale = DisplayScale * 1.3 WHERE CreatureID = 910042;
INSERT INTO creature_equip_template (CreatureID, ID, ItemID1, ItemID2, ItemID3, VerifiedBuild) SELECT 910042, ID, ItemID1, ItemID2, ItemID3, 0 FROM creature_equip_template WHERE CreatureID = 3128;
INSERT INTO creature (guid, id, map, zoneId, areaId, spawnMask, phaseMask, equipment_id, position_x, position_y, position_z, orientation, spawntimesecs, wander_distance, MovementType) VALUES (9100042, 910042, 1, 14, 0, 1, 1, 1, 300, -5165, 0.9, 1.4, 1800, 0, 0);
INSERT INTO creature_loot_template (Entry, Item, Reference, Chance, QuestRequired, LootMode, GroupId, MinCount, MaxCount, Comment) VALUES (910042, 910301, 0, 100, 0, 1, 0, 1, 1, 'Sol''Azeroth v3 : rare secret');
INSERT INTO smart_scripts (entryorguid, source_type, id, link, event_type, event_phase_mask, event_chance, event_flags, event_param1, event_param2, event_param3, event_param4, event_param5, event_param6, action_type, action_param1, action_param2, action_param3, action_param4, action_param5, action_param6, target_type, target_param1, target_param2, target_param3, target_param4, target_x, target_y, target_z, target_o, comment) VALUES
(910040, 0, 0, 0, 0, 0, 100, 0, 4000, 6000, 12000, 15000, 0, 0, 11, 744, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Zal''mara - Venin'),
(910040, 0, 1, 0, 2, 0, 100, 1, 0, 30, 0, 0, 0, 0, 11, 8269, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Zal''mara - Frénésie sous 30 %'),
(910041, 0, 0, 0, 0, 0, 100, 0, 6000, 8000, 16000, 18000, 0, 0, 11, 11990, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Gardien cendré - Pluie de feu'),
(910041, 0, 1, 0, 0, 0, 100, 0, 2000, 3000, 30000, 30000, 0, 0, 11, 702, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Gardien cendré - Malédiction de faiblesse'),
(910042, 0, 0, 0, 4, 0, 100, 0, 0, 0, 0, 0, 0, 0, 11, 51756, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Hurlevague - Charge'),
(910042, 0, 1, 0, 0, 0, 100, 0, 5000, 7000, 10000, 12000, 0, 0, 11, 11971, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Hurlevague - Fracasser armure');

-- Liste lue par v3_rares_secrets.cpp ; vaincus par personnage.
CREATE TABLE IF NOT EXISTS solazeroth_v3_rares_secrets (creature INT UNSIGNED NOT NULL PRIMARY KEY, zone INT UNSIGNED NOT NULL, monture INT UNSIGNED NOT NULL);
REPLACE INTO solazeroth_v3_rares_secrets VALUES (910040, 14, 24242), (910041, 14, 0), (910042, 14, 0);
CREATE TABLE IF NOT EXISTS acore_characters.solazeroth_v3_rares_vaincus (guid INT UNSIGNED NOT NULL, creature INT UNSIGNED NOT NULL, PRIMARY KEY (guid, creature));

-- La monture devient secrète : hors de la boutique, vitesse 60 % (montures_v3.SECRETES, Spell.dbc du patch).
DELETE FROM solazeroth_v3_montures WHERE sort = 24242;
UPDATE spell_dbc SET EffectBasePoints_2 = 59 WHERE ID = 24242;
