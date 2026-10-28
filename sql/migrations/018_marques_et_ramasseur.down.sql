-- Retour arrière de 018 (les marques déjà détenues par les personnages disparaissent avec l'objet)
USE acore_world;

DELETE FROM item_template WHERE entry = 900100;
DELETE FROM creature_template_locale WHERE entry = 9656;
INSERT INTO creature_template_locale SELECT * FROM solazeroth_bak018_bombinette_nom;
DELETE FROM creature_template_model WHERE CreatureID = 9656;
INSERT INTO creature_template_model SELECT * FROM solazeroth_bak018_bombinette;
DROP TABLE solazeroth_bak018_bombinette, solazeroth_bak018_bombinette_nom;

USE acore_characters;

DROP TABLE IF EXISTS solazeroth_compte_achats;
