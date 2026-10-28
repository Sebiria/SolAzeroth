-- Codex (sections 1.3 et 7.1, V4, codex.cpp) : raids terminés et boss dont le défi est réussi, par compte,
-- et les trois hauts faits des fins (critère 6 : pourcentage de la fin « valeur » du Codex ; 1 Histoire, 2 Maître, 3 100 %).
USE acore_characters;

CREATE TABLE IF NOT EXISTS solazeroth_raids_reussis (
    account INT UNSIGNED NOT NULL,
    map_id  INT UNSIGNED NOT NULL,
    PRIMARY KEY (account, map_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS solazeroth_defis_reussis (
    account INT UNSIGNED NOT NULL,
    boss    INT UNSIGNED NOT NULL,
    PRIMARY KEY (account, boss)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

USE acore_world;

INSERT INTO solazeroth_hauts_faits (id, categorie, nom, description, critere, valeur, quantite, liste, talent) VALUES
(51, 7, 'Fin : Histoire', 'Atteindre 100 % de la fin « Histoire » du Codex.', 6, 1, 100, '', 0),
(52, 7, 'Fin : Maître', 'Atteindre 100 % de la fin « Maître » du Codex.', 6, 2, 100, '', 0),
(53, 7, 'Fin : 100 %', 'Atteindre 100 % du Codex.', 6, 3, 100, '', 0);
