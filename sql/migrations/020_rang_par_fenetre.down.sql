-- Retour arrière de 020 (le code C++ de la pierre est à reprendre dans l'historique du module)
USE acore_world;

DELETE FROM command WHERE name IN ('solmenace', 'solmenace etat', 'solmenace choisir');
INSERT INTO gameobject_template SELECT * FROM solazeroth_bak020_pierre;
DROP TABLE solazeroth_bak020_pierre;

USE acore_characters;

DROP TABLE IF EXISTS solazeroth_menace_compte;
