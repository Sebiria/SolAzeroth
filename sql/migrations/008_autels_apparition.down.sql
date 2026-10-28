-- Retour arrière de 008 : remet les autels à leur place d'origine
USE acore_world;

DELETE FROM gameobject WHERE id = 254605;
INSERT INTO gameobject SELECT * FROM solazeroth_bak008_autels;
DROP TABLE solazeroth_bak008_autels;
