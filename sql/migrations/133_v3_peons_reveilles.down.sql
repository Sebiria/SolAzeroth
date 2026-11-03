-- Annule la migration 133.
USE acore_world;
UPDATE quest_template SET ObjectiveText1 = NULL WHERE ID = 910004;
