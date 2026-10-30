-- Rend au niveau 80 ses statistiques de base d'origine (060_v3_niveau_fixe.up.sql).
USE acore_world;

REPLACE INTO player_class_stats SELECT * FROM solazeroth_v3_stats_80;
DROP TABLE solazeroth_v3_stats_80;
