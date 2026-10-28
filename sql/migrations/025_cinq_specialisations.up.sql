-- Cinq spécialisations (section 3.8, specialisations.cpp) : emplacements achetés, et pour chacun ses talents,
-- glyphes et barres d'action. L'emplacement actif vit dans les tables normales du jeu ; il est recopié ici au changement.
USE acore_characters;

CREATE TABLE IF NOT EXISTS solazeroth_spes (
    guid      INT UNSIGNED     NOT NULL PRIMARY KEY,
    actif     TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'emplacement en cours (1 à 5)',
    possedes  TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'emplacements achetés (1 à 5)'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS solazeroth_spes_noms (
    guid  INT UNSIGNED     NOT NULL,
    slot  TINYINT UNSIGNED NOT NULL,
    nom   VARCHAR(24)      NOT NULL,
    PRIMARY KEY (guid, slot)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS solazeroth_spes_talents (
    guid    INT UNSIGNED     NOT NULL,
    slot    TINYINT UNSIGNED NOT NULL,
    talent  INT UNSIGNED     NOT NULL COMMENT 'Talent.dbc',
    rang    TINYINT UNSIGNED NOT NULL COMMENT '0 = premier rang',
    PRIMARY KEY (guid, slot, talent)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS solazeroth_spes_glyphes (
    guid         INT UNSIGNED     NOT NULL,
    slot         TINYINT UNSIGNED NOT NULL,
    emplacement  TINYINT UNSIGNED NOT NULL COMMENT '0 à 5',
    glyphe       INT UNSIGNED     NOT NULL COMMENT 'GlyphProperties.dbc',
    PRIMARY KEY (guid, slot, emplacement)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS solazeroth_spes_actions (
    guid    INT UNSIGNED     NOT NULL,
    slot    TINYINT UNSIGNED NOT NULL,
    bouton  TINYINT UNSIGNED NOT NULL,
    action  INT UNSIGNED     NOT NULL,
    type    TINYINT UNSIGNED NOT NULL,
    PRIMARY KEY (guid, slot, bouton)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
