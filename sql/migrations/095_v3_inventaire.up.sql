-- v3 (01/11/2026, demandes de l'utilisateur) :
-- - plantes et filons de la vallée des Épreuves (migrations 086 et 094) : repousse de 30 minutes au lieu de 3 ;
-- - épice douce (2678) en vente chez Duokna (3158, fournitures générales de la vallée) ;
-- - Besace d'aventurier (910235) : sac de 34 places, copié du Sac à dos de voyageur (4500). Avec le sac à dos (16),
--   l'inventaire compte 50 places ; elle est posée d'office dans le premier emplacement de sac et ne s'enlève pas
--   (v3_inventaire.cpp). Client : Item.dbc (outils\quetes_durotar.py).
USE acore_world;

UPDATE gameobject SET spawntimesecs = 1800 WHERE guid BETWEEN 9100028 AND 9100033 OR guid BETWEEN 9100036 AND 9100049;

DELETE FROM npc_vendor WHERE entry = 3158 AND item = 2678;
INSERT INTO npc_vendor (entry, slot, item, maxcount, incrtime, ExtendedCost) VALUES (3158, 0, 2678, 0, 0, 0);

DELETE FROM item_template WHERE entry = 910235;
CREATE TEMPORARY TABLE solazeroth_besace SELECT * FROM item_template WHERE entry = 4500;
UPDATE solazeroth_besace SET entry = 910235, name = 'Adventurer''s Satchel', ContainerSlots = 34, bonding = 1,
    maxcount = 1, BuyPrice = 0, SellPrice = 0, Quality = 1, description = '';
INSERT INTO item_template SELECT * FROM solazeroth_besace;
DROP TEMPORARY TABLE solazeroth_besace;

DELETE FROM item_template_locale WHERE ID = 910235;
INSERT INTO item_template_locale (ID, locale, Name, Description) VALUES (910235, 'frFR', 'Besace d''aventurier', '');
