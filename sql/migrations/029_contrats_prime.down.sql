-- Retour arrière de 029 (les primes de zone en cours deviennent incomplètes)
USE acore_characters;

DELETE FROM solazeroth_contrats WHERE type = 3;
ALTER TABLE solazeroth_contrats DROP COLUMN cible_tuee;
