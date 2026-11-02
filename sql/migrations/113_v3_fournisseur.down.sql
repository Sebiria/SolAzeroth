USE acore_world;
DELETE FROM creature WHERE guid = 9100030;
DELETE FROM creature_template_model WHERE CreatureID = 910030;
DELETE FROM creature_template WHERE entry = 910030;
DROP TABLE IF EXISTS solazeroth_v3_fournisseur;
USE acore_characters;
DROP TABLE IF EXISTS solazeroth_v3_fournisseur_achats;
