-- Retour arrière de 016 (les guildes déjà créées restent : les dissoudre en jeu si besoin)
USE acore_world;

DELETE FROM command WHERE name = 'coffre';

USE acore_characters;

DROP TABLE IF EXISTS solazeroth_banque_compte;
