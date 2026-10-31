-- Retire l'Éclat cadavérique.
USE acore_world;
DELETE FROM item_template_locale WHERE ID = 910120;
DELETE FROM item_template WHERE entry = 910120;
