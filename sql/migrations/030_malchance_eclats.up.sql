-- Protection contre la malchance et Éclats (section 6.3, malchance.cpp).
USE acore_characters;

-- Tirages ratés d'un objet rare de boss, par compte (remis à 0 quand l'objet est ramassé).
CREATE TABLE IF NOT EXISTS solazeroth_malchance (
    account  INT UNSIGNED      NOT NULL,
    item     INT UNSIGNED      NOT NULL,
    essais   SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (account, item)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Éclats de chaque boss de raid, par compte.
CREATE TABLE IF NOT EXISTS solazeroth_eclats (
    account  INT UNSIGNED      NOT NULL,
    boss     INT UNSIGNED      NOT NULL COMMENT 'entrée de la créature',
    eclats   SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (account, boss)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
