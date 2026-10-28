-- Retour arrière de 033 (raids terminés et défis par boss oubliés ; hauts faits des fins retirés)
USE acore_characters;
DROP TABLE IF EXISTS solazeroth_raids_reussis;
DROP TABLE IF EXISTS solazeroth_defis_reussis;
DELETE FROM solazeroth_hf_obtenus WHERE hf IN (51, 52, 53);

USE acore_world;
DELETE FROM solazeroth_hauts_faits WHERE id IN (51, 52, 53);
