-- Retire le pourcentage des Tarides, leurs chefs renforcés et le paiement des lieux. Durotar ne bouge pas.
USE acore_world;
DELETE FROM solazeroth_v3_zone_parts WHERE zone = 17;
DELETE FROM solazeroth_v3_lieux_monstres WHERE lieu BETWEEN 11 AND 20;
DELETE FROM solazeroth_v3_lieux_chefs WHERE lieu BETWEEN 11 AND 20;
DELETE FROM acore_characters.solazeroth_v3_lieux WHERE lieu BETWEEN 11 AND 20;
DELETE FROM creature_template WHERE entry IN (910060, 910061, 910062, 910063, 910064, 910065, 910066);
DELETE FROM creature_template_model WHERE CreatureID IN (910060, 910061, 910062, 910063, 910064, 910065, 910066);
DELETE FROM creature_template_locale WHERE entry IN (910060, 910061, 910062, 910063, 910064, 910065, 910066);
DELETE FROM creature_template_spell WHERE CreatureID IN (910060, 910061, 910062, 910063, 910064, 910065, 910066);
DELETE FROM creature_text WHERE CreatureID IN (910060, 910061, 910062, 910063, 910064, 910065, 910066);
DELETE FROM smart_scripts WHERE entryorguid IN (910060, 910061, 910062, 910063, 910064, 910065, 910066) AND source_type = 0;
DELETE FROM solazeroth_v3_puissance_entrees WHERE entree IN (910060, 910061, 910062, 910063, 910064, 910065, 910066);
DELETE FROM solazeroth_v3_courbe_entrees WHERE entree IN (910060, 910061, 910062, 910063, 910064, 910065, 910066);
DROP TABLE IF EXISTS solazeroth_v3_lieux_recompenses;
DROP TABLE IF EXISTS acore_characters.solazeroth_v3_lieux_payes;
