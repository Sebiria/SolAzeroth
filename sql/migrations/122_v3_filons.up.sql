-- Audit du jeu, lot 7 (02/11/2026) : filons minés, pour mesurer le rythme de minage en jeu (v3_filons.cpp, « .filons »).
CREATE TABLE IF NOT EXISTS acore_characters.solazeroth_v3_filons (
    guid INT UNSIGNED NOT NULL,
    joue INT UNSIGNED NOT NULL COMMENT 'temps de jeu total du personnage, en secondes',
    zone INT UNSIGNED NOT NULL,
    objet INT UNSIGNED NOT NULL,
    KEY (guid, joue)
);
