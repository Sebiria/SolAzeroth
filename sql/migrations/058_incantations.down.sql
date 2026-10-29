-- Retire les sorts à incantation Sol'Azeroth.
USE acore_world;
DELETE FROM spell_dbc WHERE ID IN (100004);
DELETE FROM spell_script_names WHERE spell_id IN (100004);
