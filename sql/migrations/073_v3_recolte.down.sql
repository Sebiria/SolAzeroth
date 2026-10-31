-- Rend la pioche aux sorts de minage et la canne à la pêche.
USE acore_world;
DELETE FROM spell_dbc WHERE ID IN (2575, 2576, 3564, 10248, 29354, 50310, 7620, 7731, 7732, 18248, 33095, 51294);
