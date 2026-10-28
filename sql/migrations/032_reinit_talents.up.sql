-- Réinitialisation payante des talents depuis l'interface (talents_etrangers.cpp) : prix croissant par personnage.
-- nombre = réinitialisations comptées pour le prix ; derniere = date de la dernière (secondes depuis 1970).
USE acore_characters;

CREATE TABLE IF NOT EXISTS solazeroth_reinit_talents (
    guid     INT UNSIGNED    NOT NULL PRIMARY KEY,
    nombre   INT UNSIGNED    NOT NULL DEFAULT 0,
    derniere BIGINT UNSIGNED NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
