-- Retire « ou plus » des objectifs de rang et de niveau de défi.
USE acore_world;

UPDATE solazeroth_hauts_faits
SET description = REGEXP_REPLACE(description, '(rang de menace [0-9]+|défi extérieur de niveau [0-9]+) ou plus\\.$', '$1.');

UPDATE achievement_dbc
SET Description_Lang_enUS = REGEXP_REPLACE(Description_Lang_enUS, '(rang de menace [0-9]+|défi extérieur de niveau [0-9]+) ou plus\\.$', '$1.'),
    Description_Lang_koKR = REGEXP_REPLACE(Description_Lang_koKR, '(rang de menace [0-9]+|défi extérieur de niveau [0-9]+) ou plus\\.$', '$1.')
WHERE ID BETWEEN 9000 AND 9999;

UPDATE achievement_criteria_dbc
SET Description_Lang_enUS = REGEXP_REPLACE(Description_Lang_enUS, '(rang de menace [0-9]+|défi extérieur de niveau [0-9]+) ou plus\\.$', '$1.'),
    Description_Lang_koKR = REGEXP_REPLACE(Description_Lang_koKR, '(rang de menace [0-9]+|défi extérieur de niveau [0-9]+) ou plus\\.$', '$1.')
WHERE ID BETWEEN 16000 AND 16999;
