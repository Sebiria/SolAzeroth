-- v3, F3 (31/10/2026) : spécialisation et techniques équipées de chaque personnage (v3_kit.cpp).
USE acore_characters;

CREATE TABLE IF NOT EXISTS solazeroth_v3_kit (
    guid      INT UNSIGNED NOT NULL COMMENT 'characters.guid',
    spe       TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0 : à choisir, 1 : guerrier tank',
    equipees  VARCHAR(128) NOT NULL DEFAULT '' COMMENT 'sorts des techniques équipées, séparés par des espaces',
    PRIMARY KEY (guid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
