-- Annule la migration 134.
USE acore_world;
UPDATE item_template SET BuyPrice = BuyPrice DIV 3 WHERE entry BETWEEN 910201 AND 910299 AND BuyPrice > 0;
