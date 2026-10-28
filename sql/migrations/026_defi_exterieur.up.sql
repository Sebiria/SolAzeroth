-- Mode défi en extérieur (section 6.6, defi_exterieur.cpp) : niveau de défi de 0 à 5 par personnage.
USE acore_characters;

CREATE TABLE IF NOT EXISTS solazeroth_defi_exterieur (
    guid    INT UNSIGNED     NOT NULL PRIMARY KEY,
    niveau  TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0 = désactivé'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
