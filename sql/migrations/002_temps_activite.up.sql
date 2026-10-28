-- Mesure du temps par activité (section 6.4), alimentée par lua_scripts/temps_activite.lua
USE acore_characters;

CREATE TABLE IF NOT EXISTS solazeroth_temps_activite (
    guid      INT UNSIGNED      NOT NULL COMMENT 'personnage',
    jour      DATE              NOT NULL,
    activite  VARCHAR(32)       NOT NULL COMMENT 'monde, donjon, raid, champ_bataille, arene',
    map_id    SMALLINT UNSIGNED NOT NULL,
    minutes   INT UNSIGNED      NOT NULL DEFAULT 0,
    PRIMARY KEY (guid, jour, activite, map_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
