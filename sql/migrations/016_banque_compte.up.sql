-- Banque de compte (banque.cpp) : guilde personnelle de chaque compte
USE acore_characters;

CREATE TABLE IF NOT EXISTS solazeroth_banque_compte (
    account   INT UNSIGNED NOT NULL PRIMARY KEY,
    guild_id  INT UNSIGNED NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

USE acore_world;

REPLACE INTO command (name, security, help) VALUES
    ('coffre', 0, 'Syntaxe : .coffre\nFait apparaître le coffre du compte (banque de guilde) à côté de toi pendant 2 minutes, hors combat et hors instance.');
