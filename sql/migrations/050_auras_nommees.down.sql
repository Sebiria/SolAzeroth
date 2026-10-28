-- Retire les auras Sol'Azeroth nommées.
USE acore_world;
DELETE FROM spell_dbc WHERE ID BETWEEN 100001 AND 100003;
