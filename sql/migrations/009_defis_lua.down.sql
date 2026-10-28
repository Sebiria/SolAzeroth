-- Retour arrière de 009
USE acore_world;

UPDATE gameobject_template SET ScriptName = 'gobject_challenge_modes' WHERE entry = 254605;

USE acore_characters;

DROP TABLE IF EXISTS solazeroth_jetons_dus;
