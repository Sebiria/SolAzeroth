-- Retour avant le calibrage final.
USE acore_world;

UPDATE solazeroth_hauts_faits SET nom = 'Gouffre de Ragefeu', liste = '4',
    description = 'Finir le Gouffre de Ragefeu au rang de menace 3 ou plus.'
WHERE id = 1;
UPDATE achievement_dbc SET Title_Lang_enUS = 'Gouffre de Ragefeu', Title_Lang_koKR = 'Gouffre de Ragefeu',
    Description_Lang_enUS = 'Finir le Gouffre de Ragefeu au rang de menace 3 ou plus.',
    Description_Lang_koKR = 'Finir le Gouffre de Ragefeu au rang de menace 3 ou plus.'
WHERE ID = 9001;
UPDATE achievement_criteria_dbc
SET Description_Lang_enUS = 'Finir le Gouffre de Ragefeu au rang de menace 3 ou plus.',
    Description_Lang_koKR = 'Finir le Gouffre de Ragefeu au rang de menace 3 ou plus.'
WHERE ID = 16001;

UPDATE solazeroth_hauts_faits SET liste = 'defis_boss',
    description = REPLACE(description, ' sur des boss de son niveau.', '.')
WHERE id IN (19, 20, 21, 22, 23);
UPDATE achievement_dbc
SET Description_Lang_enUS = REPLACE(Description_Lang_enUS, ' sur des boss de son niveau.', '.'),
    Description_Lang_koKR = REPLACE(Description_Lang_koKR, ' sur des boss de son niveau.', '.')
WHERE ID IN (9019, 9020, 9021, 9022, 9023);
UPDATE achievement_criteria_dbc
SET Description_Lang_enUS = REPLACE(Description_Lang_enUS, ' sur des boss de son niveau.', '.'),
    Description_Lang_koKR = REPLACE(Description_Lang_koKR, ' sur des boss de son niveau.', '.')
WHERE ID IN (16019, 16020, 16021, 16022, 16023);
UPDATE solazeroth_hauts_faits SET liste = 'defis_sans_filet' WHERE id = 23;

UPDATE solazeroth_histoire SET niveau = 58 WHERE chapitre = 4;
UPDATE quest_template SET MinLevel = 56, QuestLevel = 58 WHERE ID = 900203;

UPDATE trainer_spell SET MoneyCost = 50000000 WHERE SpellId = 34091;
