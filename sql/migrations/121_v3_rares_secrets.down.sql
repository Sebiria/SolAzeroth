-- Retire les rares secrets ; la monture revient en boutique à 135 %. Bijou, bague et montures déjà gagnés
-- disparaissent (objets) ou restent au compte (monture).
USE acore_world;
DELETE FROM creature WHERE guid BETWEEN 9100040 AND 9100042;
DELETE FROM smart_scripts WHERE source_type = 0 AND entryorguid IN (910040, 910041, 910042);
DELETE FROM creature_loot_template WHERE Entry IN (910040, 910041, 910042);
DELETE FROM creature_template WHERE entry IN (910040, 910041, 910042);
DELETE FROM creature_template_model WHERE CreatureID IN (910040, 910041, 910042);
DELETE FROM creature_equip_template WHERE CreatureID IN (910040, 910041, 910042);
DELETE FROM creature_template_locale WHERE entry IN (910040, 910041, 910042);
DELETE FROM item_template WHERE entry IN (910300, 910301);
DELETE FROM item_template_locale WHERE ID IN (910300, 910301);
DROP TABLE IF EXISTS solazeroth_v3_rares_secrets, acore_characters.solazeroth_v3_rares_vaincus;
INSERT IGNORE INTO solazeroth_v3_montures VALUES (24242, 135, 900);
UPDATE spell_dbc SET EffectBasePoints_2 = 134 WHERE ID = 24242;
