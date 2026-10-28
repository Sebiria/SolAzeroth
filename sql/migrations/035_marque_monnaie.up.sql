-- Marque du voyageur en vraie monnaie (demande de l'utilisateur, 28/10/2026) : l'objet 900100 n'existe pas dans le
-- client (icône « ? »). On reprend l'objet 37711, jeton de test de Blizzard jamais utilisé en jeu, déjà connu du client
-- comme monnaie (CurrencyTypes.dbc, catégorie « Divers ») : vraie icône, rangé dans l'onglet Monnaie de la fiche de
-- personnage et non dans les sacs. Sans patch client. Les Marques existantes sont mises de côté (solazeroth_jetons_dus)
-- et rendues à la prochaine connexion sous la nouvelle forme (marques.cpp).
USE acore_world;

CREATE TABLE solazeroth_bak035_marque AS SELECT * FROM item_template WHERE entry = 37711;
CREATE TABLE solazeroth_bak035_marque_nom AS SELECT * FROM item_template_locale WHERE ID = 37711;

UPDATE item_template SET name = 'Marque du voyageur', description = 'Monnaie de Sol''Azeroth.',
    stackable = 2147483647, maxcount = 0, ItemLevel = 1, RequiredLevel = 0, bonding = 0, SellPrice = 0, BuyPrice = 0
    WHERE entry = 37711;
REPLACE INTO item_template_locale (ID, locale, Name, Description, VerifiedBuild)
    VALUES (37711, 'frFR', 'Marque du voyageur', 'Monnaie de Sol''Azeroth.', 0);

USE acore_characters;

INSERT INTO solazeroth_jetons_dus (account, jetons)
    SELECT * FROM (SELECT c.account AS compte, SUM(i.count) AS n FROM item_instance i
                   JOIN character_inventory ci ON ci.item = i.guid JOIN characters c ON c.guid = ci.guid
                   WHERE i.itemEntry = 900100 GROUP BY c.account) AS s
    ON DUPLICATE KEY UPDATE jetons = jetons + s.n;
DELETE ci FROM character_inventory ci JOIN item_instance i ON i.guid = ci.item WHERE i.itemEntry = 900100;
DELETE FROM item_instance WHERE itemEntry = 900100;
