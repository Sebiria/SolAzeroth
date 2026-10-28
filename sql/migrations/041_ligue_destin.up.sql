-- Ligue Destin (section 3.3, V5 ; décisions de l'utilisateur du 30/10/2026) : race et classe tirées au sort.
-- Le tirage se fait depuis n'importe quel personnage (fenêtre des défis) ; le personnage créé ensuite avec cette race
-- et cette classe peut choisir le défi Destin au niveau 1. Un tirage par compte ; un nouveau tirage 24 h après le
-- précédent, une fois celui-ci utilisé ou abandonné (lua_scripts/defis.lua).
USE acore_characters;

CREATE TABLE IF NOT EXISTS solazeroth_destin (
    account INT UNSIGNED     NOT NULL PRIMARY KEY,
    race    TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'race tirée (0 : aucun tirage en attente)',
    classe  TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'classe tirée',
    tire_le INT UNSIGNED     NOT NULL DEFAULT 0 COMMENT 'date du dernier tirage (secondes depuis 1970)'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
