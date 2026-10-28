-- Rang de menace : une réussite se compte par donjon (identifiant de donjon du jeu, « lastEncounterDungeon »)
-- et non plus par carte. Les 4 ailes du Monastère écarlate partagent la carte 189 mais sont 4 donjons.
USE acore_characters;

CREATE TABLE solazeroth_bak019_reussites AS SELECT * FROM solazeroth_menace_reussites;

ALTER TABLE solazeroth_menace_reussites
    ADD COLUMN donjon SMALLINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'identifiant de donjon du jeu' AFTER account,
    DROP PRIMARY KEY;

-- Réussites déjà enregistrées (compte 1) : Ragefeu (4), Monastère - Cimetière (18) et Bibliothèque (165), rang 0.
UPDATE solazeroth_menace_reussites SET donjon = 4 WHERE map_id = 389;
UPDATE solazeroth_menace_reussites SET donjon = 18 WHERE map_id = 189;
INSERT INTO solazeroth_menace_reussites (account, donjon, map_id, rang_max)
    SELECT account, 165, 189, rang_max FROM solazeroth_menace_reussites WHERE map_id = 189 AND donjon = 18;

ALTER TABLE solazeroth_menace_reussites ADD PRIMARY KEY (account, donjon);
