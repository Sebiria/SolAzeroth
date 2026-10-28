-- Retour arrière de 053 : plus de voyageurs sur les routes
USE acore_world;

DELETE FROM solazeroth_ambiance_lieux WHERE genre = 1;
ALTER TABLE solazeroth_ambiance_lieux DROP COLUMN genre;
DROP TABLE solazeroth_ambiance_routes;
