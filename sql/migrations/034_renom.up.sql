-- Renom du compte (section 7.2, V4, renom.cpp) : points (maximum atteint), affixe choisi au menu (rang 5),
-- Marques déjà réclamées (bits par rang), sacs réclamés par personnage ; affixe propre à chaque instance (menace.cpp).
USE acore_characters;

CREATE TABLE IF NOT EXISTS solazeroth_renom (
    account INT UNSIGNED     NOT NULL PRIMARY KEY,
    points  INT UNSIGNED     NOT NULL DEFAULT 0,
    affixe  TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0 semaine, 1 Fortifié, 2 Tyrannique',
    marques INT UNSIGNED     NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS solazeroth_renom_sacs (
    guid INT UNSIGNED     NOT NULL,
    rang TINYINT UNSIGNED NOT NULL,
    PRIMARY KEY (guid, rang)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE solazeroth_menace_instance ADD COLUMN affixe TINYINT UNSIGNED NOT NULL DEFAULT 0;
