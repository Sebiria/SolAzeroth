-- Armes et armures sans limite de faction (demande de l'utilisateur du 29/10/2026) : en solo, réserver un objet à la
-- Horde ou à l'Alliance n'a pas de sens, et des objets reçus ne pouvaient pas s'équiper (bagues de PvP, etc.).
-- - drapeaux « Horde seulement » (1) et « Alliance seulement » (2) de FlagsExtra retirés ;
-- - races autorisées « toutes les races de l'Alliance » (1101) ou « de la Horde » (690) remplacées par « toutes » (-1).
-- Les limites de race précises (une seule race), de classe, de niveau, de métier et de réputation restent.
-- Valeurs d'origine gardées dans solazeroth_objets_faction_origine pour le retour arrière.
USE acore_world;

CREATE TABLE IF NOT EXISTS solazeroth_objets_faction_origine (
    entry         INT UNSIGNED NOT NULL PRIMARY KEY,
    FlagsExtra    INT UNSIGNED NOT NULL,
    AllowableRace INT          NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO solazeroth_objets_faction_origine (entry, FlagsExtra, AllowableRace)
SELECT entry, FlagsExtra, AllowableRace FROM item_template
WHERE class IN (2, 4) AND ((FlagsExtra & 3) <> 0 OR AllowableRace IN (1101, 690));

UPDATE item_template SET FlagsExtra = FlagsExtra & ~3
WHERE class IN (2, 4) AND (FlagsExtra & 3) <> 0;

UPDATE item_template SET AllowableRace = -1
WHERE class IN (2, 4) AND AllowableRace IN (1101, 690);
