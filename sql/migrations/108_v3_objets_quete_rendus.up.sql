-- v3 (02/11/2026, audit du jeu, lot 0) : la migration 100 a retiré du butin les objets qui lancent une quête retirée,
-- dont l'Œil d'ombre ardente (4903), que demande la quête v3 « Ombres ardentes » (910025) : sans lui, Ruga ne laissait
-- jamais descendre dans le Gouffre. Les objets encore demandés par une quête active reviennent dans le butin et ne
-- lancent plus leur ancienne quête.
USE acore_world;
CREATE TABLE solazeroth_v3_objets_quete_rendus (entry INT UNSIGNED NOT NULL PRIMARY KEY, startquest INT UNSIGNED NOT NULL)
SELECT DISTINCT i.entry, i.startquest FROM solazeroth_v3_sans_quete_objets o JOIN item_template i ON i.entry = o.entry
JOIN quest_template q ON o.entry IN (q.RequiredItemId1, q.RequiredItemId2, q.RequiredItemId3, q.RequiredItemId4,
  q.RequiredItemId5, q.RequiredItemId6, q.ItemDrop1, q.ItemDrop2, q.ItemDrop3, q.ItemDrop4)
WHERE NOT EXISTS (SELECT 1 FROM disables d WHERE d.sourceType = 1 AND d.entry = q.ID);
INSERT IGNORE INTO creature_loot_template SELECT t.* FROM solazeroth_v3_sans_quete_creature t
JOIN solazeroth_v3_objets_quete_rendus r ON r.entry = t.Item;
DELETE t FROM solazeroth_v3_sans_quete_creature t JOIN solazeroth_v3_objets_quete_rendus r ON r.entry = t.Item;
INSERT IGNORE INTO gameobject_loot_template SELECT t.* FROM solazeroth_v3_sans_quete_gameobject t
JOIN solazeroth_v3_objets_quete_rendus r ON r.entry = t.Item;
DELETE t FROM solazeroth_v3_sans_quete_gameobject t JOIN solazeroth_v3_objets_quete_rendus r ON r.entry = t.Item;
DELETE o FROM solazeroth_v3_sans_quete_objets o JOIN solazeroth_v3_objets_quete_rendus r ON r.entry = o.entry;
UPDATE item_template i JOIN solazeroth_v3_objets_quete_rendus r ON r.entry = i.entry SET i.startquest = 0;
