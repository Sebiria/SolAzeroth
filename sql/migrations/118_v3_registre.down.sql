USE acore_world;
UPDATE solazeroth_v3_aventurier_paliers SET points = 2000 WHERE palier = 10;
UPDATE solazeroth_v3_aventurier_paliers SET genre = 7, valeur = 2 WHERE palier = 12;
UPDATE solazeroth_v3_aventurier_paliers SET genre = 7, valeur = 3 WHERE palier = 20;
UPDATE solazeroth_v3_aventurier_paliers SET genre = 7, valeur = 4 WHERE palier = 30;
UPDATE solazeroth_v3_aventurier_paliers SET genre = 7, valeur = 5 WHERE palier = 38;
USE acore_characters;
DROP TABLE IF EXISTS solazeroth_v3_maitrise;
