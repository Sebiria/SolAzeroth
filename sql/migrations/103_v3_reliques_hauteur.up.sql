-- v3 (01/11/2026) : deux reliques avaient grimpé (recalage au sol qui cherchait au-dessus) ; retour à leur hauteur
-- d'origine, le recalage (désormais vers le bas seulement) les reposera au sol.
USE acore_world;
UPDATE gameobject SET position_z = 24.9 WHERE guid = 9100024;
UPDATE gameobject SET position_z = -18.0 WHERE guid = 9100027;
UPDATE gameobject SET position_z = 25.8 WHERE guid = 9100023;
