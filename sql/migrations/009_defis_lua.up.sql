-- Défis (section 3.3) : l'Autel du défi est désormais géré par lua_scripts/defis.lua (il ouvre la fenêtre
-- de l'addon) au lieu du menu C++ de mod-challenge-modes. Les règles des défis restent appliquées par le module.
USE acore_world;

UPDATE gameobject_template SET ScriptName = '' WHERE entry = 254605;

-- Jetons gagnés avant l'arrivée de la monnaie (V2) : versés automatiquement quand elle existera.
USE acore_characters;

CREATE TABLE IF NOT EXISTS solazeroth_jetons_dus (
    account  INT UNSIGNED NOT NULL PRIMARY KEY,
    jetons   INT UNSIGNED NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
