-- Retour arrière de 019
USE acore_characters;

DROP TABLE solazeroth_menace_reussites;
CREATE TABLE solazeroth_menace_reussites (
    account   INT UNSIGNED      NOT NULL,
    map_id    SMALLINT UNSIGNED NOT NULL,
    rang_max  TINYINT UNSIGNED  NOT NULL,
    PRIMARY KEY (account, map_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
INSERT INTO solazeroth_menace_reussites SELECT * FROM solazeroth_bak019_reussites;
DROP TABLE solazeroth_bak019_reussites;
