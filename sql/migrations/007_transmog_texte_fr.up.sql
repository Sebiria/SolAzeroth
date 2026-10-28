-- Texte français du transmogrificateur (npc_text 601083) : les retours à la ligne y sont écrits
-- en toutes lettres (\r\n) au lieu de vrais retours à la ligne. On les remplace.
USE acore_world;

CREATE TABLE solazeroth_bak007_npc_text_locale AS
    SELECT * FROM npc_text_locale WHERE ID = 601083 AND Locale = 'frFR';

UPDATE npc_text_locale
SET Text0_0 = REPLACE(REPLACE(Text0_0, '\\ r\\n', '\n'), '\\r\\n', '\n'),
    Text0_1 = REPLACE(REPLACE(Text0_1, '\\ r\\n', '\n'), '\\r\\n', '\n')
WHERE ID = 601083 AND Locale = 'frFR';
