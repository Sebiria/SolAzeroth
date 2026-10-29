-- Calibrage final (décisions de l'utilisateur du 29/10/2026, « Calibrage final — propositions.md »).
USE acore_world;

-- Ragefeu est à Orgrimmar, la Prison à Hurlevent : chaque camp a du mal à atteindre le donjon de l'autre.
-- Le haut fait n° 1 accepte donc l'un ou l'autre (identifiants LFGDungeons 4 et 12).
UPDATE solazeroth_hauts_faits SET nom = 'Ragefeu ou Prison', liste = '4,12',
    description = 'Finir le Gouffre de Ragefeu ou la Prison de Hurlevent au rang de menace 3 ou plus.'
WHERE id = 1;
UPDATE achievement_dbc SET Title_Lang_enUS = 'Ragefeu ou Prison', Title_Lang_koKR = 'Ragefeu ou Prison',
    Description_Lang_enUS = 'Finir le Gouffre de Ragefeu ou la Prison de Hurlevent au rang de menace 3 ou plus.',
    Description_Lang_koKR = 'Finir le Gouffre de Ragefeu ou la Prison de Hurlevent au rang de menace 3 ou plus.'
WHERE ID = 9001;
UPDATE achievement_criteria_dbc
SET Description_Lang_enUS = 'Finir le Gouffre de Ragefeu ou la Prison de Hurlevent au rang de menace 3 ou plus.',
    Description_Lang_koKR = 'Finir le Gouffre de Ragefeu ou la Prison de Hurlevent au rang de menace 3 ou plus.'
WHERE ID = 16001;

-- Rien ne compte sur un boss gris : les hauts faits « Défis de boss I à IV » comptent les défis à son niveau.
UPDATE solazeroth_hauts_faits SET liste = 'defis_boss_niveau',
    description = REPLACE(description, 'défis de boss.', 'défis de boss sur des boss de son niveau.')
WHERE id IN (19, 20, 21, 22);
UPDATE achievement_dbc
SET Description_Lang_enUS = REPLACE(Description_Lang_enUS, 'défis de boss.', 'défis de boss sur des boss de son niveau.'),
    Description_Lang_koKR = REPLACE(Description_Lang_koKR, 'défis de boss.', 'défis de boss sur des boss de son niveau.')
WHERE ID IN (9019, 9020, 9021, 9022);
UPDATE achievement_criteria_dbc
SET Description_Lang_enUS = REPLACE(Description_Lang_enUS, 'défis de boss.', 'défis de boss sur des boss de son niveau.'),
    Description_Lang_koKR = REPLACE(Description_Lang_koKR, 'défis de boss.', 'défis de boss sur des boss de son niveau.')
WHERE ID IN (16019, 16020, 16021, 16022);
UPDATE solazeroth_hauts_faits SET description = 'Réussir 50 défis « Sans filet » sur des boss de son niveau.' WHERE id = 23;
UPDATE achievement_dbc SET Description_Lang_enUS = 'Réussir 50 défis « Sans filet » sur des boss de son niveau.',
    Description_Lang_koKR = 'Réussir 50 défis « Sans filet » sur des boss de son niveau.' WHERE ID = 9023;
UPDATE achievement_criteria_dbc SET Description_Lang_enUS = 'Réussir 50 défis « Sans filet » sur des boss de son niveau.',
    Description_Lang_koKR = 'Réussir 50 défis « Sans filet » sur des boss de son niveau.' WHERE ID = 16023;

-- Chapitre 4 (Maleterres) au niveau 55 au lieu de 58 : 21 niveaux le séparaient du chapitre 3 (37).
UPDATE solazeroth_histoire SET niveau = 55 WHERE chapitre = 4;
UPDATE quest_template SET MinLevel = 53, QuestLevel = 55 WHERE ID = 900203;

-- Vol artisan : 5 000 po → 3 000 po (≈ 60 h de revenu au niveau 70).
UPDATE trainer_spell SET MoneyCost = 30000000 WHERE SpellId = 34091;
