-- Retour arrière de 007
USE acore_world;

DELETE FROM npc_text_locale WHERE ID = 601083 AND Locale = 'frFR';
INSERT INTO npc_text_locale SELECT * FROM solazeroth_bak007_npc_text_locale;
DROP TABLE solazeroth_bak007_npc_text_locale;
