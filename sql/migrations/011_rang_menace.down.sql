-- Retour arrière de 011
USE acore_world;

DELETE FROM command WHERE name = 'menace';
DELETE FROM gameobject_template WHERE entry = 900001;

USE acore_characters;

DROP TABLE IF EXISTS solazeroth_menace_instance;
DROP TABLE IF EXISTS solazeroth_menace_reussites;
