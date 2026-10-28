-- Retour arrière de 042 : plus de PNJ d'ambiance
USE acore_world;

DELETE FROM creature_template_model WHERE CreatureID = 900110;
DELETE FROM creature_template WHERE entry = 900110;
DROP TABLE solazeroth_ambiance_apparences;
DROP TABLE solazeroth_ambiance_armes;
