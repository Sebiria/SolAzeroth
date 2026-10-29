-- Mise à l'échelle du monde avec retard (section 9.1, V8 ; décisions de l'utilisateur du 29/10/2026) : option par
-- personnage, désactivée par défaut. Monstres de toute zone sous le niveau du joueur remontés à son niveau moins 2 ou 3.
USE acore_characters;

CREATE TABLE IF NOT EXISTS solazeroth_echelle (
    guid   INT UNSIGNED     NOT NULL PRIMARY KEY,
    actif  TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '1 = monstres à mon niveau'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
