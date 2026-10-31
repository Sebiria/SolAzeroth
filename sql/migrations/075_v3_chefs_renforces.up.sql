-- v3, F5e (31/10/2026) : chefs renforcés des lieux à nettoyer (document de Durotar, §4.1.1 et point 16).
-- Chaque chef renforcé est une copie de l'original : mêmes statistiques, même butin (le médaillon de Yarrog tombe
-- donc aussi), mêmes scripts SmartAI, et la mort de la copie compte pour l'original (KillCredit1 : la quête
-- d'histoire est validée). Il n'apparaît que quand la troupe du lieu est tombée (v3_zone.cpp).
-- Techniques en plus (lignes SmartAI 10 et suivantes) :
--   T1 Yarrog : 2 Vils quasits toutes les 20 s ;
--   T2 Benedict : à 50 % de vie, 4 Soldats de marine de Kul Tiras ;
--   T3 Kolkanis : Piétinement (étourdit 2 s) et Choc martial (repousse) toutes les 15 s ; à 50 %, 2 Estafettes ;
--   T4 Zalazane : Maléfice (grenouille, 5 s : pas de version à 3 s) toutes les 25 s ; Garde guérisseuse à briser
--      toutes les 30 s ;
--   T5 Gazz'uz : Pluie de feu toutes les 15 s ; à 30 %, 2 Fanatiques.
-- Les renforts apparaissent à côté du joueur et l'attaquent ; ils disparaissent 15 s après la fin du combat.
USE acore_world;

DELETE FROM creature_template WHERE entry BETWEEN 910010 AND 910014;
DELETE FROM creature_template_model WHERE CreatureID BETWEEN 910010 AND 910014;
DELETE FROM creature_template_locale WHERE entry BETWEEN 910010 AND 910014;
DELETE FROM smart_scripts WHERE entryorguid BETWEEN 910010 AND 910014 AND source_type = 0;

DROP TEMPORARY TABLE IF EXISTS solazeroth_copie;
CREATE TEMPORARY TABLE solazeroth_copie (origine INT UNSIGNED NOT NULL, copie INT UNSIGNED NOT NULL);
INSERT INTO solazeroth_copie VALUES (3183, 910010), (3192, 910011), (5808, 910012), (3205, 910013), (3204, 910014);

DROP TEMPORARY TABLE IF EXISTS solazeroth_t;
CREATE TEMPORARY TABLE solazeroth_t SELECT t.* FROM creature_template t JOIN solazeroth_copie c ON c.origine = t.entry;
UPDATE solazeroth_t t JOIN solazeroth_copie c ON c.origine = t.entry
    SET t.KillCredit1 = t.entry, t.subname = 'Chef renforcé', t.pickpocketloot = 0, t.entry = c.copie;
INSERT INTO creature_template SELECT * FROM solazeroth_t;
DROP TEMPORARY TABLE solazeroth_t;

CREATE TEMPORARY TABLE solazeroth_t SELECT m.* FROM creature_template_model m JOIN solazeroth_copie c ON c.origine = m.CreatureID;
UPDATE solazeroth_t m JOIN solazeroth_copie c ON c.origine = m.CreatureID SET m.CreatureID = c.copie;
INSERT INTO creature_template_model SELECT * FROM solazeroth_t;
DROP TEMPORARY TABLE solazeroth_t;

INSERT INTO creature_template_locale (entry, locale, Name, Title, VerifiedBuild)
    SELECT c.copie, 'frFR', COALESCE(NULLIF(l.Name, ''), t.name), 'Chef renforcé', 0
    FROM solazeroth_copie c JOIN creature_template t ON t.entry = c.origine
    LEFT JOIN creature_template_locale l ON l.entry = c.origine AND l.locale = 'frFR';

CREATE TEMPORARY TABLE solazeroth_t SELECT s.* FROM smart_scripts s JOIN solazeroth_copie c ON c.origine = s.entryorguid
    WHERE s.source_type = 0;
UPDATE solazeroth_t s JOIN solazeroth_copie c ON c.origine = s.entryorguid SET s.entryorguid = c.copie;
INSERT INTO smart_scripts SELECT * FROM solazeroth_t;
DROP TEMPORARY TABLE solazeroth_t;
DROP TEMPORARY TABLE solazeroth_copie;

-- event_type 0 : en combat (délai initial min/max, répétition min/max) ; 2 : vie entre min et max % (une fois avec
-- event_flags 1). action 11 : lancer un sort (2 = sans incantation) ; 12 : invoquer (créature, type 4 = disparaît
-- après N ms hors combat, durée, attaquer la cible). Cible 2 : la cible du chef ; 1 : lui-même.
INSERT INTO smart_scripts (entryorguid, source_type, id, link, event_type, event_phase_mask, event_chance, event_flags,
    event_param1, event_param2, event_param3, event_param4, event_param5, event_param6, action_type, action_param1,
    action_param2, action_param3, action_param4, action_param5, action_param6, target_type, target_param1,
    target_param2, target_param3, target_param4, target_x, target_y, target_z, target_o, comment) VALUES
(910010, 0, 10, 0, 0, 0, 100, 0, 8000, 8000, 20000, 20000, 0, 0, 12, 3101, 4, 15000, 1, 0, 0, 2, 0, 0, 0, 0, 3, 3, 0, 0, 'Yarrog renforcé - T1 - Vil quasit'),
(910010, 0, 11, 0, 0, 0, 100, 0, 8000, 8000, 20000, 20000, 0, 0, 12, 3101, 4, 15000, 1, 0, 0, 2, 0, 0, 0, 0, -3, -3, 0, 0, 'Yarrog renforcé - T1 - Vil quasit'),
(910011, 0, 10, 0, 2, 0, 100, 1, 0, 50, 0, 0, 0, 0, 12, 3129, 4, 15000, 1, 0, 0, 2, 0, 0, 0, 0, 6, 6, 0, 0, 'Benedict renforcé - T2 - Alarme'),
(910011, 0, 11, 0, 2, 0, 100, 1, 0, 50, 0, 0, 0, 0, 12, 3129, 4, 15000, 1, 0, 0, 2, 0, 0, 0, 0, -6, 6, 0, 0, 'Benedict renforcé - T2 - Alarme'),
(910011, 0, 12, 0, 2, 0, 100, 1, 0, 50, 0, 0, 0, 0, 12, 3129, 4, 15000, 1, 0, 0, 2, 0, 0, 0, 0, 6, -6, 0, 0, 'Benedict renforcé - T2 - Alarme'),
(910011, 0, 13, 0, 2, 0, 100, 1, 0, 50, 0, 0, 0, 0, 12, 3129, 4, 15000, 1, 0, 0, 2, 0, 0, 0, 0, -6, -6, 0, 0, 'Benedict renforcé - T2 - Alarme'),
(910012, 0, 10, 0, 0, 0, 100, 0, 6000, 9000, 15000, 15000, 0, 0, 11, 25056, 2, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Kolkanis renforcé - T3 - Piétinement'),
(910012, 0, 11, 0, 0, 0, 100, 0, 6000, 9000, 15000, 15000, 0, 0, 11, 45, 2, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Kolkanis renforcé - T3 - Choc martial'),
(910012, 0, 12, 0, 2, 0, 100, 1, 0, 50, 0, 0, 0, 0, 12, 3120, 4, 15000, 1, 0, 0, 2, 0, 0, 0, 0, 5, 5, 0, 0, 'Kolkanis renforcé - T3 - Estafette'),
(910012, 0, 13, 0, 2, 0, 100, 1, 0, 50, 0, 0, 0, 0, 12, 3120, 4, 15000, 1, 0, 0, 2, 0, 0, 0, 0, -5, -5, 0, 0, 'Kolkanis renforcé - T3 - Estafette'),
(910013, 0, 10, 0, 0, 0, 100, 0, 10000, 12000, 25000, 25000, 0, 0, 11, 17172, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Zalazane renforcé - T4 - Maléfice'),
(910013, 0, 11, 0, 0, 0, 100, 0, 15000, 15000, 30000, 30000, 0, 0, 11, 4971, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 'Zalazane renforcé - T4 - Garde guérisseuse'),
(910014, 0, 10, 0, 0, 0, 100, 0, 7000, 9000, 15000, 15000, 0, 0, 11, 11990, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 'Gazz''uz renforcé - T5 - Pluie de feu'),
(910014, 0, 11, 0, 2, 0, 100, 1, 0, 30, 0, 0, 0, 0, 12, 3197, 4, 15000, 1, 0, 0, 2, 0, 0, 0, 0, 5, 5, 0, 0, 'Gazz''uz renforcé - T5 - Fanatique'),
(910014, 0, 12, 0, 2, 0, 100, 1, 0, 30, 0, 0, 0, 0, 12, 3197, 4, 15000, 1, 0, 0, 2, 0, 0, 0, 0, -5, -5, 0, 0, 'Gazz''uz renforcé - T5 - Fanatique');
