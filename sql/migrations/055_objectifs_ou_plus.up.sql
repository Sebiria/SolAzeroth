-- Objectifs sans ambiguïté (demande de l'utilisateur du 29/10/2026) : « au rang de menace 3 » devient
-- « au rang de menace 3 ou plus », « en défi extérieur de niveau 5 » devient « … de niveau 5 ou plus ».
-- Même changement dans les hauts faits natifs (achievement_dbc, achievement_criteria_dbc : français et anglais).
USE acore_world;

UPDATE solazeroth_hauts_faits
SET description = REGEXP_REPLACE(description, '(rang de menace [0-9]+|défi extérieur de niveau [0-9]+)\\.$', '$1 ou plus.')
WHERE description NOT LIKE '%ou plus%';

UPDATE achievement_dbc
SET Description_Lang_enUS = REGEXP_REPLACE(Description_Lang_enUS, '(rang de menace [0-9]+|défi extérieur de niveau [0-9]+)\\.$', '$1 ou plus.'),
    Description_Lang_koKR = REGEXP_REPLACE(Description_Lang_koKR, '(rang de menace [0-9]+|défi extérieur de niveau [0-9]+)\\.$', '$1 ou plus.')
WHERE ID BETWEEN 9000 AND 9999 AND Description_Lang_enUS NOT LIKE '%ou plus%';

UPDATE achievement_criteria_dbc
SET Description_Lang_enUS = REGEXP_REPLACE(Description_Lang_enUS, '(rang de menace [0-9]+|défi extérieur de niveau [0-9]+)\\.$', '$1 ou plus.'),
    Description_Lang_koKR = REGEXP_REPLACE(Description_Lang_koKR, '(rang de menace [0-9]+|défi extérieur de niveau [0-9]+)\\.$', '$1 ou plus.')
WHERE ID BETWEEN 16000 AND 16999 AND Description_Lang_enUS NOT LIKE '%ou plus%';
