-- Signalement du 03/11/2026 : « Les péons qui ne dorment plus » affichait « Péon fainéant tué » (objectif sans libellé).
USE acore_world;
UPDATE quest_template SET ObjectiveText1 = 'Péons fainéants réveillés' WHERE ID = 910004;
