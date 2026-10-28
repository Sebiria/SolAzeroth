-- Marque du voyageur : la copie de l'Insigne de justice gardait « Niveau d'objet 70 » et « Niveau 70 requis ».
USE acore_world;

UPDATE item_template SET ItemLevel = 1, RequiredLevel = 0 WHERE entry = 900100;
