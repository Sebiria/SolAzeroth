-- Retour arrière de 010 : remet les autels
USE acore_world;

INSERT INTO gameobject SELECT * FROM solazeroth_bak010_autels;
DROP TABLE solazeroth_bak010_autels;
