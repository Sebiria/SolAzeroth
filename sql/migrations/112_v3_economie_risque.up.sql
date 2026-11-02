-- Audit du jeu, lot 4a (02/11/2026, C4 du consensus) : économie du risque.
-- - solazeroth_v3_annexes_jour : jour (depuis 1970) où chaque défi répétable a payé plein tarif (v3_annexes.cpp).
-- - solazeroth_v3_puissance_max : puissance de base la plus haute atteinte, sur laquelle les modes de zone se calent
--   (v3_combat.cpp, v3_modes.cpp).
USE acore_characters;

CREATE TABLE IF NOT EXISTS solazeroth_v3_annexes_jour (
    guid INT UNSIGNED NOT NULL,
    quete INT UNSIGNED NOT NULL,
    jour INT UNSIGNED NOT NULL,
    PRIMARY KEY (guid, quete)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS solazeroth_v3_puissance_max (
    guid INT UNSIGNED NOT NULL PRIMARY KEY,
    maximum FLOAT NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
