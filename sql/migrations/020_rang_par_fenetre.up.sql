-- Rang de menace réglé à l'avance dans une fenêtre d'addon (menace.cpp, SolAzerothMenace) au lieu de la pierre.
USE acore_characters;

CREATE TABLE IF NOT EXISTS solazeroth_menace_compte (
    account        INT UNSIGNED     NOT NULL PRIMARY KEY,
    rang_prochain  TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'rang appliqué au prochain donjon réinitialisé'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

USE acore_world;

-- La Pierre de menace (objet 900001) n'est plus utilisée.
CREATE TABLE solazeroth_bak020_pierre AS SELECT * FROM gameobject_template WHERE entry = 900001;
DELETE FROM gameobject_template WHERE entry = 900001;

REPLACE INTO command (name, security, help) VALUES
    ('solmenace', 0, 'Utilisée par l''addon Sol''Azeroth - Rang de menace (/rang).'),
    ('solmenace etat', 0, 'Syntaxe : .solmenace etat'),
    ('solmenace choisir', 0, 'Syntaxe : .solmenace choisir $rang\nRègle le rang de menace du prochain donjon (et du donjon actuel tant que le premier combat n''a pas eu lieu).');
