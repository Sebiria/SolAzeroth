-- Audit du jeu, lot 4a (02/11/2026) : fournisseur de matériaux de Razor Hill. Généré par
-- outils\fournisseur_v3.py : ne pas modifier à la main (prix et hypothèses y sont écrits).
USE acore_world;
CREATE TABLE IF NOT EXISTS solazeroth_v3_fournisseur (objet INT UNSIGNED NOT NULL PRIMARY KEY, nom VARCHAR(64) NOT NULL, prix INT UNSIGNED NOT NULL, plafond INT UNSIGNED NOT NULL) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
DELETE FROM solazeroth_v3_fournisseur;
INSERT INTO solazeroth_v3_fournisseur VALUES (2770, 'Minerai de cuivre', 800, 20);
INSERT INTO solazeroth_v3_fournisseur VALUES (2835, 'Pierre brute', 4000, 20);
INSERT INTO solazeroth_v3_fournisseur VALUES (2589, 'Etoffe de lin', 2000, 20);
INSERT INTO solazeroth_v3_fournisseur VALUES (2318, 'Cuir léger', 1333, 20);
INSERT INTO solazeroth_v3_fournisseur VALUES (2934, 'Lanières de cuir déchirées', 2000, 20);
DELETE FROM creature_template WHERE entry = 910030;
DELETE FROM creature_template_model WHERE CreatureID = 910030;
DELETE FROM creature WHERE guid = 9100030;
CREATE TEMPORARY TABLE sol_pnj SELECT * FROM creature_template WHERE entry = 3168;
UPDATE sol_pnj SET entry = 910030, name = 'Mogra', subname = 'Matériaux', npcflag = 1, gossip_menu_id = 0, AIName = '', ScriptName = 'npc_solazeroth_v3_fournisseur';
INSERT INTO creature_template SELECT * FROM sol_pnj;
DROP TEMPORARY TABLE sol_pnj;
INSERT INTO creature_template_model (CreatureID, Idx, CreatureDisplayID, DisplayScale, Probability, VerifiedBuild) SELECT 910030, Idx, CreatureDisplayID, DisplayScale, Probability, VerifiedBuild FROM creature_template_model WHERE CreatureID = 3168;
INSERT INTO creature (guid, id, map, zoneId, areaId, spawnMask, phaseMask, equipment_id, position_x, position_y, position_z, orientation, spawntimesecs, wander_distance, MovementType) VALUES (9100030, 910030, 1, 14, 362, 1, 1, 0, 325.9, -4767.6, 12.6, 1.60, 300, 0, 0);
USE acore_characters;
CREATE TABLE IF NOT EXISTS solazeroth_v3_fournisseur_achats (guid INT UNSIGNED NOT NULL, objet INT UNSIGNED NOT NULL, jour INT UNSIGNED NOT NULL, nombre INT UNSIGNED NOT NULL, PRIMARY KEY (guid, objet)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
