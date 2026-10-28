-- Retour arrière de 051 : seul Hurlevent est animé
USE acore_world;

DROP TABLE solazeroth_ambiance_lieux;
DELETE FROM solazeroth_ambiance_apparences WHERE camp = 1;
ALTER TABLE solazeroth_ambiance_apparences DROP COLUMN camp;
