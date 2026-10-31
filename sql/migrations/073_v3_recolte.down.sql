-- Rend la pioche aux sorts de minage.
USE acore_world;
DELETE FROM spell_dbc WHERE ID IN (2575, 2576, 3564, 10248, 29354, 50310);
