-- Retour arrière de 038 : retire les colonnes des affixes de mécanique et les créatures 900100 et 900101
USE acore_characters;

ALTER TABLE solazeroth_menace_compte DROP COLUMN affixes_prochain;
ALTER TABLE solazeroth_menace_instance DROP COLUMN affixes;

USE acore_world;

DELETE FROM creature_template_model WHERE CreatureID IN (900100, 900101);
DELETE FROM creature_template WHERE entry IN (900100, 900101);
