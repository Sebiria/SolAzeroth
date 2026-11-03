-- Lot T3 des Tarides (03/11/2026) : pourcentage des Tarides, lieux à nettoyer et leur paiement.
-- Généré par outils\zone_durotar.py tarides : ne pas modifier à la main. Ne touche pas à Durotar.
-- Parts en centièmes de % : quêtes d'histoire T01 à T30 (50 %), exploration (6 %), lieux A01 à A10 (19 %).
USE acore_world;

DELETE FROM solazeroth_v3_zone_parts WHERE zone = 17;
DELETE FROM solazeroth_v3_lieux_monstres WHERE lieu BETWEEN 11 AND 20;
DELETE FROM solazeroth_v3_lieux_chefs WHERE lieu BETWEEN 11 AND 20;
INSERT INTO solazeroth_v3_zone_parts VALUES
(17, 1, 910041, 50, 'Au-delà de la Furie-du-Sud'),
(17, 1, 910042, 150, 'La menace des trotteurs'),
(17, 1, 910043, 150, 'Les zhévras'),
(17, 1, 910044, 150, 'Spores fongiques'),
(17, 1, 910045, 150, 'La Colline des épines'),
(17, 1, 910046, 150, 'Les cendres de la Lame'),
(17, 1, 910047, 200, 'L''offensive de la Colline'),
(17, 1, 910048, 200, 'Sarilus Souillemporte'),
(17, 1, 910049, 150, 'Les bassins oubliés'),
(17, 1, 910050, 200, 'L''oasis stagnante'),
(17, 1, 910051, 200, 'Source de vie'),
(17, 1, 910052, 150, 'Les bracelets de centaure'),
(17, 1, 910053, 200, 'Hezrul Marque-de-sang'),
(17, 1, 910054, 150, 'Les flibustiers des mers du Sud'),
(17, 1, 910055, 250, 'La vengeance d''un capitaine'),
(17, 1, 910056, 100, 'La gardienne de la colline'),
(17, 1, 910057, 50, 'La route de Taurajo'),
(17, 1, 910058, 200, 'Tribus en guerre'),
(17, 1, 910059, 200, 'Les joyaux de sang d''Agammagan'),
(17, 1, 910060, 150, 'Portée disparue'),
(17, 1, 910061, 200, 'Consumé par la haine'),
(17, 1, 910062, 150, 'Les lézards-tonnerre enragés'),
(17, 1, 910063, 250, 'La géoprêtresse'),
(17, 1, 910064, 200, 'La reconquête de Gann'),
(17, 1, 910065, 150, 'Les explosifs de Gann'),
(17, 1, 910066, 100, 'La machine volante'),
(17, 1, 910067, 250, 'La larme des lunes'),
(17, 1, 910068, 250, 'Une trahison de l''intérieur'),
(17, 1, 910069, 100, 'La Larme et le rêve'),
(17, 1, 910070, 150, 'Le seuil des Lamentations'),
(17, 2, 379, 15, 'Poste de garde extérieur'),
(17, 2, 815, 15, 'La Furie-du-Sud'),
(17, 2, 458, 15, 'Route de l''or'),
(17, 2, 380, 15, 'La Croisée'),
(17, 2, 1699, 15, 'Colline des épines'),
(17, 2, 384, 15, 'Pic de Brume-funeste'),
(17, 2, 386, 15, 'Les Bassins oubliés'),
(17, 2, 388, 15, 'L''oasis stagnante'),
(17, 2, 387, 15, 'Oasis luxuriante'),
(17, 2, 392, 15, 'Cabestan'),
(17, 2, 391, 15, 'La Côte des marchands'),
(17, 2, 385, 15, 'Fort du Nord'),
(17, 2, 378, 15, 'Camp Taurajo'),
(17, 2, 1700, 15, 'Agama''gor'),
(17, 2, 1698, 15, 'Ronceplaie'),
(17, 2, 1156, 15, 'Tarides du sud'),
(17, 2, 1157, 15, 'Route de l''or méridionale'),
(17, 2, 359, 15, 'Bael Modan'),
(17, 2, 2157, 15, 'Donjon de Bael''dun'),
(17, 2, 1701, 15, 'Crête de Noirépine'),
(17, 2, 1704, 25, 'Ferme de Grol''dom'),
(17, 2, 2757, 25, 'Autel du Guerrier mort'),
(17, 2, 1599, 25, 'Campement de Mor''shan'),
(17, 2, 1703, 25, 'Le Rempart de Mor''shan'),
(17, 2, 383, 25, 'Les Collines arides'),
(17, 2, 382, 25, 'La Videfange'),
(17, 2, 381, 25, 'Mine des Pierriers'),
(17, 2, 1697, 25, 'Terres des Raptors'),
(17, 2, 1702, 25, 'Le lieu de l''Honneur'),
(17, 2, 401, 25, 'L''Escalier des marées'),
(17, 2, 720, 25, 'Île de la Dispute'),
(17, 2, 390, 25, 'Champ des Géants'),
(17, 3, 11, 100, 'Colline des épines'),
(17, 3, 12, 100, 'Pic de Brume-funeste'),
(17, 3, 13, 200, 'Oasis luxuriante'),
(17, 3, 14, 100, 'Collines arides, aires des Ensorçaile'),
(17, 3, 15, 150, 'Fort du Nord'),
(17, 3, 16, 300, 'Agama''gor'),
(17, 3, 17, 150, 'Ronceplaie'),
(17, 3, 18, 250, 'Champ des Géants, la ruche'),
(17, 3, 19, 300, 'Donjon de Bael''dun'),
(17, 3, 20, 250, 'Crête de Noirépine');
-- Troupes : plafond de 60 morts réparti au prorata des entrées ; comptées dans les sous-zones du lieu ; invocations ignorées.
INSERT INTO solazeroth_v3_lieux_monstres (lieu, creature, nombre, sous_zones, invocations) VALUES
(11, 3267, 13, '1699', 0),
(11, 3268, 9, '1699', 0),
(11, 3265, 6, '1699', 0),
(11, 3266, 16, '1699', 0),
(11, 3269, 12, '1699', 0),
(11, 3271, 4, '1699', 0),
(12, 3379, 26, '384,2138,17', 0),
(12, 3380, 19, '384,2138,17', 0),
(13, 3272, 19, '387', 0),
(13, 3273, 19, '387', 0),
(13, 3397, 2, '387', 0),
(13, 3274, 1, '387', 0),
(13, 3275, 1, '387', 0),
(13, 4316, 1, '387', 0),
(14, 3276, 13, '383', 0),
(14, 3277, 10, '383', 0),
(14, 3278, 24, '383', 0),
(14, 3279, 1, '383', 0),
(14, 3280, 12, '383', 0),
(15, 3385, 49, '385', 0),
(15, 3386, 11, '385', 0),
(16, 3258, 31, '1700', 0),
(16, 3260, 13, '1700', 0),
(16, 3263, 10, '1700', 0),
(16, 3261, 6, '1700', 0),
(17, 3261, 20, '1698', 0),
(17, 3263, 18, '1698', 0),
(17, 3260, 10, '1698', 0),
(17, 3258, 9, '1698', 0),
(18, 3252, 22, '390', 0),
(18, 3250, 19, '390', 0),
(18, 3251, 19, '390', 0),
(18, 3253, 1, '390', 0),
(19, 3376, 17, '2157,359', 0),
(19, 3377, 15, '2157,359', 0),
(19, 3378, 11, '2157,359', 0),
(20, 3458, 19, '1701', 0),
(20, 3457, 15, '1701', 0),
(20, 3459, 15, '1701', 0),
(20, 3456, 11, '1701', 0);
INSERT INTO solazeroth_v3_lieux_chefs VALUES
(11, 3438, 910060),
(12, 3986, 910061),
(13, 3396, 910062),
(15, 3393, 910063),
(16, 5863, 910064),
(19, 3414, 910065),
(20, 3435, 910066);

-- Chefs renforcés : copies des chefs d'histoire, comme la migration 075 (mêmes statistiques, butin, SmartAI,
-- textes et sorts ; leur mort compte pour l'original). Pas de technique en plus : M1 à M8 viennent au lot T4.
DELETE FROM creature_template WHERE entry IN (910060, 910061, 910062, 910063, 910064, 910065, 910066);
DELETE FROM creature_template_model WHERE CreatureID IN (910060, 910061, 910062, 910063, 910064, 910065, 910066);
DELETE FROM creature_template_locale WHERE entry IN (910060, 910061, 910062, 910063, 910064, 910065, 910066);
DELETE FROM creature_template_spell WHERE CreatureID IN (910060, 910061, 910062, 910063, 910064, 910065, 910066);
DELETE FROM creature_text WHERE CreatureID IN (910060, 910061, 910062, 910063, 910064, 910065, 910066);
DELETE FROM smart_scripts WHERE entryorguid IN (910060, 910061, 910062, 910063, 910064, 910065, 910066) AND source_type = 0;
DROP TEMPORARY TABLE IF EXISTS solazeroth_copie;
CREATE TEMPORARY TABLE solazeroth_copie (origine INT UNSIGNED NOT NULL, copie INT UNSIGNED NOT NULL);
INSERT INTO solazeroth_copie VALUES (3438, 910060), (3986, 910061), (3396, 910062), (3393, 910063), (5863, 910064), (3414, 910065), (3435, 910066);
DROP TEMPORARY TABLE IF EXISTS solazeroth_t;
CREATE TEMPORARY TABLE solazeroth_t SELECT t.* FROM creature_template t JOIN solazeroth_copie c ON c.origine = t.entry;
UPDATE solazeroth_t t JOIN solazeroth_copie c ON c.origine = t.entry
    SET t.KillCredit1 = t.entry, t.subname = 'Chef renforcé', t.pickpocketloot = 0, t.entry = c.copie;
INSERT INTO creature_template SELECT * FROM solazeroth_t;
DROP TEMPORARY TABLE solazeroth_t;
CREATE TEMPORARY TABLE solazeroth_t SELECT x.* FROM creature_template_model x JOIN solazeroth_copie c ON c.origine = x.CreatureID;
UPDATE solazeroth_t x JOIN solazeroth_copie c ON c.origine = x.CreatureID SET x.CreatureID = c.copie;
INSERT INTO creature_template_model SELECT * FROM solazeroth_t;
DROP TEMPORARY TABLE solazeroth_t;
CREATE TEMPORARY TABLE solazeroth_t SELECT x.* FROM creature_template_spell x JOIN solazeroth_copie c ON c.origine = x.CreatureID;
UPDATE solazeroth_t x JOIN solazeroth_copie c ON c.origine = x.CreatureID SET x.CreatureID = c.copie;
INSERT INTO creature_template_spell SELECT * FROM solazeroth_t;
DROP TEMPORARY TABLE solazeroth_t;
CREATE TEMPORARY TABLE solazeroth_t SELECT x.* FROM creature_text x JOIN solazeroth_copie c ON c.origine = x.CreatureID;
UPDATE solazeroth_t x JOIN solazeroth_copie c ON c.origine = x.CreatureID SET x.CreatureID = c.copie;
INSERT INTO creature_text SELECT * FROM solazeroth_t;
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

-- Puissance (décision 5) : celle du chef d'histoire à son apparition (table du lot T1), fixée par entrée ;
-- la correction de la courbe du chef d'histoire le suit.
DELETE FROM solazeroth_v3_puissance_entrees WHERE entree IN (910060, 910061, 910062, 910063, 910064, 910065, 910066);
DELETE FROM solazeroth_v3_courbe_entrees WHERE entree IN (910060, 910061, 910062, 910063, 910064, 910065, 910066);
INSERT INTO solazeroth_v3_puissance_entrees (entree, zone, fixe, secteur, origine_min, origine_max, puissance_min, puissance_max)
    SELECT c.copie, 17, 1, COALESCE(e.secteur, 0), t.minlevel, t.minlevel, LEAST(a.puissance_max, GREATEST(a.puissance_min, IF(a.origine_max <= a.origine_min, ROUND((a.puissance_min + a.puissance_max) / 2), ROUND(a.puissance_min + (t.minlevel - a.origine_min) * (a.puissance_max - a.puissance_min) / (a.origine_max - a.origine_min))))), LEAST(a.puissance_max, GREATEST(a.puissance_min, IF(a.origine_max <= a.origine_min, ROUND((a.puissance_min + a.puissance_max) / 2), ROUND(a.puissance_min + (t.minlevel - a.origine_min) * (a.puissance_max - a.puissance_min) / (a.origine_max - a.origine_min)))))
    FROM solazeroth_copie c JOIN creature_template t ON t.entry = c.origine
    JOIN creature o ON o.id = c.origine JOIN solazeroth_v3_puissance_apparitions a ON a.guid = o.guid
    LEFT JOIN solazeroth_v3_puissance_entrees e ON e.entree = c.origine;
INSERT INTO solazeroth_v3_courbe_entrees (entree, vie, degats)
    SELECT c.copie, x.vie, x.degats FROM solazeroth_copie c JOIN solazeroth_v3_courbe_entrees x ON x.entree = c.origine;
DROP TEMPORARY TABLE solazeroth_copie;

-- Paiement des lieux (décision 2), à la première fermeture : Marques, cuivre, éclats et composants (objet:nombre).
-- Barème provisoire du brouillon, à régler au calibrage final. Durotar n'a pas de ligne : rien ne change pour lui.
CREATE TABLE IF NOT EXISTS solazeroth_v3_lieux_recompenses (lieu INT UNSIGNED NOT NULL PRIMARY KEY, marques INT UNSIGNED NOT NULL, cuivre INT UNSIGNED NOT NULL, eclats INT UNSIGNED NOT NULL, composants VARCHAR(128) NOT NULL DEFAULT '');
DELETE FROM solazeroth_v3_lieux_recompenses WHERE lieu BETWEEN 11 AND 20;
INSERT INTO solazeroth_v3_lieux_recompenses VALUES
(11, 20, 12000, 15, '2318:3,774:1'),
(12, 20, 12000, 15, '2589:4,785:1'),
(13, 40, 37000, 46, '2592:4,2450:2'),
(14, 20, 18500, 23, '2592:4,2453:2'),
(15, 30, 43000, 54, '2592:5,2771:2'),
(16, 60, 85500, 108, '2319:7,3356:3'),
(17, 30, 43000, 54, '2319:5,785:2'),
(18, 50, 71500, 90, '3355:3,2775:2'),
(19, 60, 132000, 165, '2592:7,1705:2'),
(20, 50, 110000, 138, '2319:6,3356:2,1705:1');
CREATE TABLE IF NOT EXISTS acore_characters.solazeroth_v3_lieux_payes (guid INT UNSIGNED NOT NULL, lieu INT UNSIGNED NOT NULL, PRIMARY KEY (guid, lieu));
