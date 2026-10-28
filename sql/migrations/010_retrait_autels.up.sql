-- Les défis se choisissent uniquement par l'addon (bouton de la minicarte) : on retire les 9 Autels du défi.
-- Le modèle d'objet 254605 reste en base, seules les apparitions sont supprimées.
USE acore_world;

CREATE TABLE solazeroth_bak010_autels AS SELECT * FROM gameobject WHERE id = 254605;
DELETE FROM gameobject WHERE id = 254605;
