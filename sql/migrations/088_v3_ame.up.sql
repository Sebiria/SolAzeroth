-- v3, F10 (01/11/2026) : l'âme (v3_ame.cpp). Âme de chaque personnage, de 0 à 100, et nombre de morts comptées.
-- Sans ligne, l'âme est pleine ; à 0, le personnage est verrouillé (« Âme éteinte »).
USE acore_characters;

CREATE TABLE IF NOT EXISTS solazeroth_v3_ame (
    guid INT UNSIGNED NOT NULL PRIMARY KEY,
    ame TINYINT UNSIGNED NOT NULL DEFAULT 100,
    morts INT UNSIGNED NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
