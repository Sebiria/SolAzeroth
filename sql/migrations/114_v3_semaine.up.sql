-- Audit du jeu, lot 4a (02/11/2026) : objectif de la semaine, au compte (v3_semaine.cpp).
USE acore_characters;
CREATE TABLE IF NOT EXISTS solazeroth_v3_semaine (compte INT UNSIGNED NOT NULL PRIMARY KEY, semaine INT UNSIGNED NOT NULL,
    progres INT UNSIGNED NOT NULL, paye TINYINT UNSIGNED NOT NULL) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
