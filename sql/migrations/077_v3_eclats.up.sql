-- v3, F6 (31/10/2026) : l'Éclat cadavérique (910120), monnaie des rangs d'objet (F8), donné à la mort des monstres
-- (v3_collection.cpp). Copie du Fragment d'âme (6265) en composant ordinaire : classe 7, sous-classe 11, qualité
-- inhabituelle, pile de 1000, ni prix ni lien.
USE acore_world;

DELETE FROM item_template WHERE entry = 910120;
DROP TEMPORARY TABLE IF EXISTS eclat;
CREATE TEMPORARY TABLE eclat SELECT * FROM item_template WHERE entry = 6265;
UPDATE eclat SET entry = 910120, class = 7, subclass = 11, name = 'Corpse Shard', Quality = 2, Flags = 0,
    BuyCount = 1, BuyPrice = 0, SellPrice = 0, stackable = 1000, maxcount = 0, bonding = 0, ItemLevel = 1,
    RequiredLevel = 0, description = 'Arraché aux morts. Sert à monter le rang des objets.', BagFamily = 0,
    spellid_1 = 0, spellcharges_1 = 0, ScriptName = '';
INSERT INTO item_template SELECT * FROM eclat;
DROP TEMPORARY TABLE eclat;

DELETE FROM item_template_locale WHERE ID = 910120;
INSERT INTO item_template_locale (ID, locale, Name, Description) VALUES
    (910120, 'frFR', 'Éclat cadavérique', 'Arraché aux morts. Sert à monter le rang des objets.');
