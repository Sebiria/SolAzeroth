-- Retour arrière de 023 (les enchantements déjà posés restent sur les objets)
USE acore_characters;

DROP TABLE IF EXISTS solazeroth_objets_rang;
ALTER TABLE solazeroth_butin_attente DROP COLUMN rang;
