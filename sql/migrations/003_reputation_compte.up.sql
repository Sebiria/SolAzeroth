-- Factions exaltées sur le compte (section 3.4), alimentée par lua_scripts/compte_bonus.lua
USE acore_characters;

CREATE TABLE IF NOT EXISTS solazeroth_compte_exalte (
    account  INT UNSIGNED      NOT NULL,
    faction  SMALLINT UNSIGNED NOT NULL,
    guid     INT UNSIGNED      NOT NULL COMMENT 'premier personnage exalté',
    le       DATETIME          NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (account, faction)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
