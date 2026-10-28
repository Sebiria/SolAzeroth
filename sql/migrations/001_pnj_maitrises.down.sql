-- Retour arrière de 001 : supprime le PNJ 900000 et ses apparitions
USE acore_world;

DELETE FROM creature WHERE id = 900000;
DELETE FROM creature_template_model WHERE CreatureID = 900000;
DELETE FROM creature_template WHERE entry = 900000;
