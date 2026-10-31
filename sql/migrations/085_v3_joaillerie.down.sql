-- Retire la joaillerie. Les pierres taillées rangées restent en Collection, sans emploi.
USE acore_world;
DROP TABLE solazeroth_v3_prospection, solazeroth_v3_tailles, solazeroth_v3_rangs_pierres;
DELETE FROM solazeroth_v3_collectionnables WHERE entry IN (910180, 910181, 910182);
DELETE FROM item_template WHERE entry IN (910180, 910181, 910182);
DELETE FROM item_template_locale WHERE ID IN (910180, 910181, 910182);
