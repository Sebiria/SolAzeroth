-- Retour arrière de 034 (Renom, sacs réclamés et affixes d'instance oubliés)
USE acore_characters;
DROP TABLE IF EXISTS solazeroth_renom;
DROP TABLE IF EXISTS solazeroth_renom_sacs;
ALTER TABLE solazeroth_menace_instance DROP COLUMN affixe;
