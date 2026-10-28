-- Rendements décroissants des raids (section 4.7, V6) : passages du jour par personnage et par raid (raids.cpp).
USE acore_characters;

CREATE TABLE solazeroth_raid_passages (
    guid INT UNSIGNED NOT NULL,
    map SMALLINT UNSIGNED NOT NULL,
    jour INT UNSIGNED NOT NULL,         -- AAAAMMJJ, jour de l'ordinateur
    passages SMALLINT UNSIGNED NOT NULL,
    instance INT UNSIGNED NOT NULL,     -- dernière instance entrée (une nouvelle instance = un passage de plus)
    PRIMARY KEY (guid, map, jour)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
