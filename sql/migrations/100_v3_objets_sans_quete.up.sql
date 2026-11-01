-- v3 (01/11/2026, signalement de l'utilisateur) : un objet qui lance une quête retirée (table disables) ne lance plus
-- rien ; il disparaît du butin et des marchands (à Durotar : l'Enveloppe vieillie du coffre de Benedict, l'Œil
-- d'ombre ardente). Les lignes retirées sont gardées pour la migration inverse.
USE acore_world;
DROP TABLE IF EXISTS solazeroth_v3_sans_quete_objets;
CREATE TABLE solazeroth_v3_sans_quete_objets (entry INT UNSIGNED NOT NULL PRIMARY KEY)
SELECT DISTINCT i.entry FROM item_template i JOIN disables d ON d.sourceType = 1 AND d.entry = i.startquest WHERE i.startquest > 0;
DROP TABLE IF EXISTS solazeroth_v3_sans_quete_creature;
CREATE TABLE solazeroth_v3_sans_quete_creature SELECT t.* FROM creature_loot_template t JOIN solazeroth_v3_sans_quete_objets o ON o.entry = t.Item WHERE t.Reference = 0;
DELETE t FROM creature_loot_template t JOIN solazeroth_v3_sans_quete_objets o ON o.entry = t.Item WHERE t.Reference = 0;
DROP TABLE IF EXISTS solazeroth_v3_sans_quete_gameobject;
CREATE TABLE solazeroth_v3_sans_quete_gameobject SELECT t.* FROM gameobject_loot_template t JOIN solazeroth_v3_sans_quete_objets o ON o.entry = t.Item WHERE t.Reference = 0;
DELETE t FROM gameobject_loot_template t JOIN solazeroth_v3_sans_quete_objets o ON o.entry = t.Item WHERE t.Reference = 0;
DROP TABLE IF EXISTS solazeroth_v3_sans_quete_reference;
CREATE TABLE solazeroth_v3_sans_quete_reference SELECT t.* FROM reference_loot_template t JOIN solazeroth_v3_sans_quete_objets o ON o.entry = t.Item WHERE t.Reference = 0;
DELETE t FROM reference_loot_template t JOIN solazeroth_v3_sans_quete_objets o ON o.entry = t.Item WHERE t.Reference = 0;
DROP TABLE IF EXISTS solazeroth_v3_sans_quete_item;
CREATE TABLE solazeroth_v3_sans_quete_item SELECT t.* FROM item_loot_template t JOIN solazeroth_v3_sans_quete_objets o ON o.entry = t.Item WHERE t.Reference = 0;
DELETE t FROM item_loot_template t JOIN solazeroth_v3_sans_quete_objets o ON o.entry = t.Item WHERE t.Reference = 0;
DROP TABLE IF EXISTS solazeroth_v3_sans_quete_pickpocketing;
CREATE TABLE solazeroth_v3_sans_quete_pickpocketing SELECT t.* FROM pickpocketing_loot_template t JOIN solazeroth_v3_sans_quete_objets o ON o.entry = t.Item WHERE t.Reference = 0;
DELETE t FROM pickpocketing_loot_template t JOIN solazeroth_v3_sans_quete_objets o ON o.entry = t.Item WHERE t.Reference = 0;
DROP TABLE IF EXISTS solazeroth_v3_sans_quete_fishing;
CREATE TABLE solazeroth_v3_sans_quete_fishing SELECT t.* FROM fishing_loot_template t JOIN solazeroth_v3_sans_quete_objets o ON o.entry = t.Item WHERE t.Reference = 0;
DELETE t FROM fishing_loot_template t JOIN solazeroth_v3_sans_quete_objets o ON o.entry = t.Item WHERE t.Reference = 0;
DROP TABLE IF EXISTS solazeroth_v3_sans_quete_skinning;
CREATE TABLE solazeroth_v3_sans_quete_skinning SELECT t.* FROM skinning_loot_template t JOIN solazeroth_v3_sans_quete_objets o ON o.entry = t.Item WHERE t.Reference = 0;
DELETE t FROM skinning_loot_template t JOIN solazeroth_v3_sans_quete_objets o ON o.entry = t.Item WHERE t.Reference = 0;
DROP TABLE IF EXISTS solazeroth_v3_sans_quete_marchands;
CREATE TABLE solazeroth_v3_sans_quete_marchands SELECT v.* FROM npc_vendor v JOIN solazeroth_v3_sans_quete_objets o ON o.entry = v.item;
DELETE v FROM npc_vendor v JOIN solazeroth_v3_sans_quete_objets o ON o.entry = v.item;
