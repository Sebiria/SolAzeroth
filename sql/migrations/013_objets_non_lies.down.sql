-- Retour arrière de 013 : remet les liaisons d'origine
USE acore_world;

UPDATE item_template it INNER JOIN solazeroth_bak013_liaison b ON b.entry = it.entry SET it.bonding = b.bonding;
DROP TABLE solazeroth_bak013_liaison;
