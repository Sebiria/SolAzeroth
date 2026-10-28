-- Marques des boss de donjon une seule fois par personnage, par boss et par rang de menace (marques.cpp, demande de
-- l'utilisateur du 29/10/2026). On retient le plus haut rang déjà payé : une victoire à un rang plus haut paie aussi
-- les rangs inférieurs pas encore payés ; une victoire à un rang déjà payé ou plus bas ne rapporte plus de Marques.
USE acore_characters;

CREATE TABLE IF NOT EXISTS solazeroth_marques_boss (
    guid INT UNSIGNED     NOT NULL,
    boss INT UNSIGNED     NOT NULL,
    rang TINYINT UNSIGNED NOT NULL COMMENT 'plus haut rang de menace déjà payé',
    PRIMARY KEY (guid, boss)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
