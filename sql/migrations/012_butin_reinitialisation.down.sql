-- Retour arrière de 012
USE acore_world;

DELETE FROM command WHERE name IN ('reinitialiser', 'solbutin', 'solbutin liste', 'solbutin choisir');

USE acore_characters;

DROP TABLE IF EXISTS solazeroth_butin_attente;
