-- Retire la recette de l'Huile de sorcier mineure et rend son sort à l'huile (le Thon garde la vitesse
-- d'incantation : rejouer la migration 117 pour l'ôter).
USE acore_world;
DELETE FROM solazeroth_v3_recettes WHERE objet = 20744;
DELETE FROM solazeroth_v3_recettes_composants WHERE objet = 20744;
UPDATE item_template SET spellid_1 = 25117 WHERE entry = 20744;
DELETE FROM spell_dbc WHERE ID = 101608;
