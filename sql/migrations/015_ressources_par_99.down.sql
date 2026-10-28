-- Retour arrière de 015 : tailles de pile d'origine
USE acore_world;

UPDATE item_template it INNER JOIN solazeroth_bak015_piles b ON b.entry = it.entry SET it.stackable = b.stackable;
DROP TABLE solazeroth_bak015_piles;
