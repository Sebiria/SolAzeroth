-- v3 (01/11/2026, signalement de l'utilisateur) : plus de maîtres de classe, de profession ni de familiers dans le
-- monde ; les techniques, la Formation et les fenêtres d'artisanat les remplacent. Les maîtres de monte restent.
-- Un maître qui donne ou reprend une quête reste, sans sa fonction de maître (drapeaux 16, 32 et 64 retirés) ; les
-- autres apparitions disparaissent, gardées dans des tables de sauvegarde pour le retour en arrière.
USE acore_world;

CREATE TABLE solazeroth_v3_maitres (entry INT UNSIGNED NOT NULL PRIMARY KEY, npcflag INT UNSIGNED NOT NULL,
    quetes TINYINT UNSIGNED NOT NULL) ENGINE=InnoDB;
INSERT INTO solazeroth_v3_maitres (entry, npcflag, quetes)
SELECT ct.entry, ct.npcflag, ct.entry IN (SELECT id FROM creature_queststarter UNION SELECT id FROM creature_questender)
FROM creature_template ct
WHERE ct.npcflag & 16 AND ct.entry NOT IN (SELECT cdt.CreatureId FROM creature_default_trainer cdt
    JOIN trainer t ON t.Id = cdt.TrainerId WHERE t.Type = 1);

CREATE TABLE solazeroth_v3_maitres_creature LIKE creature;
INSERT INTO solazeroth_v3_maitres_creature
SELECT c.* FROM creature c JOIN solazeroth_v3_maitres m ON m.entry = c.id WHERE m.quetes = 0;
CREATE TABLE solazeroth_v3_maitres_addon LIKE creature_addon;
INSERT INTO solazeroth_v3_maitres_addon
SELECT a.* FROM creature_addon a JOIN solazeroth_v3_maitres_creature c ON c.guid = a.guid;
CREATE TABLE solazeroth_v3_maitres_evenements LIKE game_event_creature;
INSERT INTO solazeroth_v3_maitres_evenements
SELECT g.* FROM game_event_creature g JOIN solazeroth_v3_maitres_creature c ON c.guid = g.guid;

DELETE g FROM game_event_creature g JOIN solazeroth_v3_maitres_creature c ON c.guid = g.guid;
DELETE a FROM creature_addon a JOIN solazeroth_v3_maitres_creature c ON c.guid = a.guid;
DELETE cr FROM creature cr JOIN solazeroth_v3_maitres_creature c ON c.guid = cr.guid;

UPDATE creature_template ct JOIN solazeroth_v3_maitres m ON m.entry = ct.entry
SET ct.npcflag = ct.npcflag & ~(16 | 32 | 64) WHERE m.quetes = 1;
