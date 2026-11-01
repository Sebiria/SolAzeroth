-- v3, F9 (01/11/2026) : mode de zone choisi par chaque personnage (v3_modes.cpp) : 0 aucun, 1 normal, 2 difficile,
-- 3 cauchemar.
USE acore_characters;

CREATE TABLE IF NOT EXISTS solazeroth_v3_modes (
    guid INT UNSIGNED NOT NULL,
    zone INT UNSIGNED NOT NULL,
    mode TINYINT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (guid, zone)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
