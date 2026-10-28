-- Affixes de mécanique à cocher (section 4.4, V5, affixes_mecanique.cpp) : Enragé, Renforçant, Volcanique, Explosif.
-- Le compte coche ses affixes pour le prochain donjon, comme le rang ; l'instance les garde jusqu'à sa réinitialisation.
-- Valeur : somme de bits (1 Enragé, 2 Renforçant, 4 Volcanique, 8 Explosif).
USE acore_characters;

ALTER TABLE solazeroth_menace_compte
    ADD COLUMN affixes_prochain TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'affixes de mécanique cochés pour le prochain donjon';
ALTER TABLE solazeroth_menace_instance
    ADD COLUMN affixes TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'affixes de mécanique de cette instance';

USE acore_world;

-- 900100 : Sphère instable (Explosif). Copie de la Sphère instable de l'Oculus (28166), ciblable, sans script :
-- affixes_mecanique.cpp la fixe sur place, règle son niveau et ses PV, et la fait exploser si elle n'est pas détruite.
CREATE TEMPORARY TABLE tmp_pnj SELECT * FROM creature_template WHERE entry = 28166;
UPDATE tmp_pnj SET
    entry = 900100,
    name = 'Sphère instable',
    subname = 'Affixe Explosif',
    faction = 14,
    unit_flags = 0,
    flags_extra = 64,   -- pas d'XP
    HealthModifier = 1,
    lootid = 0, pickpocketloot = 0, skinloot = 0, mingold = 0, maxgold = 0,
    AIName = '',
    ScriptName = '';
INSERT INTO creature_template SELECT * FROM tmp_pnj;
DROP TEMPORARY TABLE tmp_pnj;
INSERT INTO creature_template_model (CreatureID, Idx, CreatureDisplayID, DisplayScale, Probability, VerifiedBuild)
VALUES (900100, 0, 17612, 1, 1, 12340);

-- 900101 : Fissure volcanique (Volcanique). Copie du déclencheur invisible 23837, hostile et sans script :
-- il lance la Pluie de feu (43440) sous les pieds du joueur.
CREATE TEMPORARY TABLE tmp_pnj SELECT * FROM creature_template WHERE entry = 23837;
UPDATE tmp_pnj SET
    entry = 900101,
    name = 'Fissure volcanique',
    subname = 'Affixe Volcanique',
    faction = 14,
    AIName = '',
    ScriptName = '';
INSERT INTO creature_template SELECT * FROM tmp_pnj;
DROP TEMPORARY TABLE tmp_pnj;
INSERT INTO creature_template_model (CreatureID, Idx, CreatureDisplayID, DisplayScale, Probability, VerifiedBuild)
SELECT 900101, Idx, CreatureDisplayID, DisplayScale, Probability, VerifiedBuild FROM creature_template_model WHERE CreatureID = 23837;
