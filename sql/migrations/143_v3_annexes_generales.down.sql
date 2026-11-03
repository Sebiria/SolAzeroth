-- Annule 143 : les records et la carte de Durotar reviennent dans solazeroth_v3_annexes_joueur.
USE acore_world;
INSERT INTO acore_characters.solazeroth_v3_annexes_joueur (guid, carte, vague, temps, jour) SELECT guid, 0, vague, temps, jour FROM acore_characters.solazeroth_v3_epreuves_joueur WHERE epreuve = 1 ON DUPLICATE KEY UPDATE vague = VALUES(vague), temps = VALUES(temps), jour = VALUES(jour);
INSERT INTO acore_characters.solazeroth_v3_annexes_joueur (guid, carte) SELECT guid, 1 FROM acore_characters.solazeroth_v3_reliques_cartes_joueur WHERE zone = 14 ON DUPLICATE KEY UPDATE carte = 1;
DROP TABLE acore_characters.solazeroth_v3_epreuves_joueur, acore_characters.solazeroth_v3_reliques_cartes_joueur;
DROP TABLE solazeroth_v3_epreuves, solazeroth_v3_renforts, solazeroth_v3_reliques_familles, solazeroth_v3_reliques_cartes, solazeroth_v3_techniques;
DELETE FROM solazeroth_v3_vagues WHERE epreuve <> 1;
ALTER TABLE solazeroth_v3_vagues DROP PRIMARY KEY, DROP COLUMN epreuve, DROP COLUMN puissance, ADD PRIMARY KEY (vague, creature);
DELETE FROM solazeroth_v3_annexes WHERE zone <> 14;
DELETE FROM solazeroth_v3_reliques WHERE zone <> 14;
ALTER TABLE solazeroth_v3_annexes DROP COLUMN zone;
ALTER TABLE solazeroth_v3_reliques DROP COLUMN zone;
