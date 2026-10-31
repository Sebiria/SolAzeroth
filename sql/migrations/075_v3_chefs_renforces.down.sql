-- Retire les chefs renforcés des lieux à nettoyer.
USE acore_world;
DELETE FROM creature_template WHERE entry BETWEEN 910010 AND 910014;
DELETE FROM creature_template_model WHERE CreatureID BETWEEN 910010 AND 910014;
DELETE FROM creature_template_locale WHERE entry BETWEEN 910010 AND 910014;
DELETE FROM smart_scripts WHERE entryorguid BETWEEN 910010 AND 910014 AND source_type = 0;
