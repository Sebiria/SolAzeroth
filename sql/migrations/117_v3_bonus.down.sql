USE acore_world;
DELETE FROM spell_dbc WHERE ID IN (101600, 101601, 101602, 101603, 101604, 101605, 101606, 101607, 101608);
DELETE FROM solazeroth_v3_recettes WHERE objet = 2862;
DELETE FROM solazeroth_v3_recettes_composants WHERE objet = 2862;
DELETE FROM solazeroth_v3_recettes WHERE objet = 2304;
DELETE FROM solazeroth_v3_recettes_composants WHERE objet = 2304;
DELETE FROM solazeroth_v3_recettes WHERE objet = 20744;
DELETE FROM solazeroth_v3_recettes_composants WHERE objet = 20744;
-- Sorts et objets d'origine : rejouer les migrations 050 et 079.
USE acore_characters;
DROP TABLE IF EXISTS solazeroth_v3_variantes;
