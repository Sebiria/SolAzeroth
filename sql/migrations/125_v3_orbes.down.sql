-- Retire les orbes à fabriquer. Ceux que possèdent les personnages disparaissent.
USE acore_world;
DELETE FROM npc_vendor WHERE entry = 3166 AND item = 910236;
DELETE FROM solazeroth_v3_recettes_composants WHERE objet IN (910237, 910236, 910272);
DELETE FROM solazeroth_v3_recettes WHERE objet IN (910237, 910236, 910272);
DELETE FROM solazeroth_v3_rangs WHERE base IN (910237, 910236, 910272);
DELETE FROM item_template WHERE entry IN (910237, 910236, 910272, 922371, 922372, 922373, 922374, 922375, 922361, 922362, 922363, 922364, 922365, 922721, 922722, 922723, 922724, 922725);
