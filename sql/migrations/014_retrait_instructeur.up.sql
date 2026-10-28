-- L'addon d'apprentissage (formation.cpp) remplace les PNJ bonus : on retire l'Instructeur des maîtrises
-- (PNJ 900000) et ses 4 apparitions à Orgrimmar et Hurlevent. Le transmogrificateur (190010) reste.
USE acore_world;

DELETE FROM creature WHERE id = 900000;
DELETE FROM creature_template_model WHERE CreatureID = 900000;
DELETE FROM creature_template WHERE entry = 900000;

REPLACE INTO command (name, security, help) VALUES
    ('solform', 0, 'Utilisée par l''addon Sol''Azeroth - Apprentissage.'),
    ('solform liste', 0, 'Syntaxe : .solform liste'),
    ('solform acheter', 0, 'Syntaxe : .solform acheter $catégorie $id');
