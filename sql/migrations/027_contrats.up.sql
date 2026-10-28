-- Tableau de contrats (section 6.1, contrats.cpp) : réserve du compte (3 par jour, jusqu'à 9)
-- et les 3 contrats de chaque personnage (proposés ou en cours).
USE acore_characters;

CREATE TABLE IF NOT EXISTS solazeroth_contrats_reserve (
    account  INT UNSIGNED     NOT NULL PRIMARY KEY,
    charges  TINYINT UNSIGNED NOT NULL COMMENT 'contrats disponibles (9 au plus)',
    jour     INT UNSIGNED     NOT NULL COMMENT 'dernier jour de recharge (jours locaux, bascule à 6 h)'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS solazeroth_contrats (
    guid         INT UNSIGNED      NOT NULL,
    slot         TINYINT UNSIGNED  NOT NULL COMMENT '1 à 3',
    type         TINYINT UNSIGNED  NOT NULL COMMENT '1 chasse, 2 donjon imposé, 3 prime de zone, 4 commande d artisan',
    cible        INT UNSIGNED      NOT NULL COMMENT 'zone (chasse, prime) ou donjon LFGDungeons',
    detail       INT UNSIGNED      NOT NULL COMMENT 'famille de monstres (chasse) ou rang minimal (donjon)',
    objectif     SMALLINT UNSIGNED NOT NULL,
    progression  SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    actif        TINYINT UNSIGNED  NOT NULL DEFAULT 0 COMMENT '0 proposé, 1 accepté',
    niveau       TINYINT UNSIGNED  NOT NULL COMMENT 'niveau du personnage au tirage (récompense)',
    PRIMARY KEY (guid, slot)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
