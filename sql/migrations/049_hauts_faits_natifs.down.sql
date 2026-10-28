-- Retire les hauts faits Sol'Azeroth natifs (les hauts faits du compte restent dans solazeroth_hf_obtenus).
USE acore_world;
DELETE FROM achievement_category_dbc WHERE ID BETWEEN 15100 AND 15199;
DELETE FROM achievement_dbc WHERE ID BETWEEN 9000 AND 9999;
DELETE FROM achievement_criteria_dbc WHERE ID BETWEEN 16000 AND 16999;
DELETE FROM acore_characters.character_achievement WHERE achievement BETWEEN 9000 AND 9999;
DELETE FROM acore_characters.character_achievement_progress WHERE criteria BETWEEN 16000 AND 16999;
