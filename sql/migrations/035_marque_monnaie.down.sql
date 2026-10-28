-- Retour arrière de 035 : les Marques (objet 37711) sont remises de côté pour être rendues en objet 900100
-- (avec l'ancien code), et l'objet 37711 reprend sa forme d'origine.
USE acore_characters;

INSERT INTO solazeroth_jetons_dus (account, jetons)
    SELECT * FROM (SELECT c.account AS compte, SUM(i.count) AS n FROM item_instance i
                   JOIN character_inventory ci ON ci.item = i.guid JOIN characters c ON c.guid = ci.guid
                   WHERE i.itemEntry = 37711 GROUP BY c.account) AS s
    ON DUPLICATE KEY UPDATE jetons = jetons + s.n;
DELETE ci FROM character_inventory ci JOIN item_instance i ON i.guid = ci.item WHERE i.itemEntry = 37711;
DELETE FROM item_instance WHERE itemEntry = 37711;

USE acore_world;
DELETE FROM item_template WHERE entry = 37711;
INSERT INTO item_template SELECT * FROM solazeroth_bak035_marque;
DELETE FROM item_template_locale WHERE ID = 37711;
INSERT INTO item_template_locale SELECT * FROM solazeroth_bak035_marque_nom;
DROP TABLE solazeroth_bak035_marque;
DROP TABLE solazeroth_bak035_marque_nom;
