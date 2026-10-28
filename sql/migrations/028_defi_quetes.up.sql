-- Défi en extérieur (section 6.6, defi_exterieur.cpp) : niveau de défi le plus bas tenu pendant chaque quête en cours.
-- Le bonus de Marques et d'XP d'une quête rendue utilise ce niveau (on ne peut pas monter le niveau juste avant de rendre).
USE acore_characters;

CREATE TABLE IF NOT EXISTS solazeroth_defi_quetes (
    guid    INT UNSIGNED     NOT NULL,
    quest   INT UNSIGNED     NOT NULL,
    niveau  TINYINT UNSIGNED NOT NULL,
    PRIMARY KEY (guid, quest)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
