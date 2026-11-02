-- Retire les bâtons à fabriquer. Ceux que possèdent les personnages disparaissent.
USE acore_world;
DELETE FROM solazeroth_v3_recettes_composants WHERE objet IN (910455, 910456, 910273);
DELETE FROM solazeroth_v3_recettes WHERE objet IN (910455, 910456, 910273);
DELETE FROM solazeroth_v3_rangs WHERE base IN (910455, 910456, 910273);
DELETE FROM item_template WHERE entry IN (910455, 910456, 910273, 924551, 924552, 924553, 924554, 924555, 924561, 924562, 924563, 924564, 924565, 922731, 922732, 922733, 922734, 922735);
