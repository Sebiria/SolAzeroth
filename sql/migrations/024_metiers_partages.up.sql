-- Métiers partagés sur le compte (section 3.2, metiers.cpp) : niveau de chaque métier et recettes connues, par compte.
USE acore_characters;

CREATE TABLE IF NOT EXISTS solazeroth_metiers_compte (
    account  INT UNSIGNED      NOT NULL,
    skill    SMALLINT UNSIGNED NOT NULL COMMENT 'SkillLine du métier',
    valeur   SMALLINT UNSIGNED NOT NULL COMMENT 'meilleure valeur atteinte sur le compte',
    maximum  SMALLINT UNSIGNED NOT NULL COMMENT 'meilleur plafond (rang Apprenti à Grand maître)',
    PRIMARY KEY (account, skill)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS solazeroth_recettes_compte (
    account  INT UNSIGNED NOT NULL,
    spell    INT UNSIGNED NOT NULL COMMENT 'recette, rang de métier ou spécialisation',
    PRIMARY KEY (account, spell)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
