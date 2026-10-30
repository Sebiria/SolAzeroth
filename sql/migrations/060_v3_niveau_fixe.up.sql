-- v3 (31/10/2026) : tout le monde est niveau 80, mais le niveau ne donne plus de force.
-- Les statistiques de base du niveau 80 deviennent celles du niveau 1 ; l'ancienne ligne est gardée pour l'annulation.
USE acore_world;

CREATE TABLE IF NOT EXISTS solazeroth_v3_stats_80 LIKE player_class_stats;
INSERT IGNORE INTO solazeroth_v3_stats_80 SELECT * FROM player_class_stats WHERE Level = 80;

-- Le chevalier de la mort (6) n'a pas de niveau 1 : il prend celui du guerrier, dont ses valeurs sont presque identiques.
UPDATE player_class_stats s80 JOIN player_class_stats s1 ON s1.Class = IF(s80.Class = 6, 1, s80.Class) AND s1.Level = 1
SET s80.BaseHP = s1.BaseHP, s80.BaseMana = s1.BaseMana, s80.Strength = s1.Strength, s80.Agility = s1.Agility,
    s80.Stamina = s1.Stamina, s80.Intellect = s1.Intellect, s80.Spirit = s1.Spirit
WHERE s80.Level = 80;
