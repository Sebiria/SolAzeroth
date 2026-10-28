-- Retour arrière de 040 : plus de thème de la semaine
USE acore_characters;

ALTER TABLE solazeroth_contrats DROP COLUMN theme;

USE acore_world;

DROP TABLE solazeroth_themes;
