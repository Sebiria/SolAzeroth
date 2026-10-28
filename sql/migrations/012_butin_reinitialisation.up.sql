-- Butin des boss de donjon au choix (butin.cpp) et réinitialisation libre (reinitialisation.cpp)
USE acore_characters;

CREATE TABLE IF NOT EXISTS solazeroth_butin_attente (
    jeton   INT UNSIGNED NOT NULL PRIMARY KEY,
    guid    INT UNSIGNED NOT NULL COMMENT 'personnage',
    boss    VARCHAR(100) NOT NULL,
    objets  VARCHAR(255) NOT NULL COMMENT 'entrées d''objets séparées par des virgules',
    KEY idx_guid (guid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

USE acore_world;

REPLACE INTO command (name, security, help) VALUES
    ('reinitialiser', 0, 'Syntaxe : .reinitialiser\nRéinitialise tous tes donjons et raids (hors instance). La prochaine entrée crée une instance neuve.'),
    ('solbutin', 0, 'Utilisée par l''addon Sol''Azeroth - Butin.'),
    ('solbutin liste', 0, 'Syntaxe : .solbutin liste\nRenvoie les choix de butin en attente.'),
    ('solbutin choisir', 0, 'Syntaxe : .solbutin choisir $jeton $objet');
