-- Audit du jeu, lot 5 (02/11/2026) : les difficultés des donjons s'ouvrent en réussissant la précédente ; les paliers
-- 12, 20, 30 et 38 du rang donnent des Marques du voyageur ; palier 10 (la monte) à 1 950 points (outils\test_paliers_v3.py).
-- Maîtrise des modes de zone : monstres tués par compte, zone et mode (v3_aventurier.cpp).
USE acore_world;
UPDATE solazeroth_v3_aventurier_paliers SET points = 1950 WHERE palier = 10;
UPDATE solazeroth_v3_aventurier_paliers SET genre = 7, valeur = 50 WHERE palier = 12;
UPDATE solazeroth_v3_aventurier_paliers SET genre = 7, valeur = 100 WHERE palier = 20;
UPDATE solazeroth_v3_aventurier_paliers SET genre = 7, valeur = 150 WHERE palier = 30;
UPDATE solazeroth_v3_aventurier_paliers SET genre = 7, valeur = 200 WHERE palier = 38;
USE acore_characters;
CREATE TABLE IF NOT EXISTS solazeroth_v3_maitrise (compte INT UNSIGNED NOT NULL, zone INT UNSIGNED NOT NULL,
    mode TINYINT UNSIGNED NOT NULL, tues INT UNSIGNED NOT NULL, PRIMARY KEY (compte, zone, mode)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
