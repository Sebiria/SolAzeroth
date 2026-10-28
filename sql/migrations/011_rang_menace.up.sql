-- Rang de menace de compte (sections 4.2 à 4.4), géré par le module mod-solazeroth (menace.cpp)
USE acore_characters;

CREATE TABLE IF NOT EXISTS solazeroth_menace_reussites (
    account   INT UNSIGNED      NOT NULL,
    map_id    SMALLINT UNSIGNED NOT NULL COMMENT 'donjon réussi (dernier boss tué)',
    rang_max  TINYINT UNSIGNED  NOT NULL COMMENT 'plus haut rang réussi dans ce donjon',
    PRIMARY KEY (account, map_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS solazeroth_menace_instance (
    instance_id INT UNSIGNED     NOT NULL PRIMARY KEY,
    rang        TINYINT UNSIGNED NOT NULL DEFAULT 0,
    verrouille  TINYINT UNSIGNED NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

USE acore_world;

-- Objet 900001 : Pierre de menace, copiée de l'ancien Autel du défi (même apparence)
CREATE TEMPORARY TABLE tmp_pierre SELECT * FROM gameobject_template WHERE entry = 254605;
UPDATE tmp_pierre SET entry = 900001, name = 'Pierre de menace', ScriptName = 'go_solazeroth_pierre_menace';
INSERT INTO gameobject_template SELECT * FROM tmp_pierre;
DROP TEMPORARY TABLE tmp_pierre;

REPLACE INTO command (name, security, help) VALUES
    ('menace', 0, 'Syntaxe : .menace\nAffiche le rang de menace débloqué sur le compte, l''affixe de la semaine et le rang de l''instance actuelle.');
