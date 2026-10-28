-- En solo, la liaison à l'équipement ou à l'utilisation n'a plus de sens (décision de l'utilisateur, V2) :
-- les objets « Lié quand équipé » (bonding 2) et « Lié quand utilisé » (3) ne sont plus liés,
-- donc plus de fenêtre de confirmation. Ils peuvent aussi passer d'un personnage à l'autre du compte.
-- « Lié quand ramassé » (1) et les objets de quête (4) ne changent pas.
USE acore_world;

CREATE TABLE solazeroth_bak013_liaison AS
    SELECT entry, bonding FROM item_template WHERE bonding IN (2, 3);

UPDATE item_template SET bonding = 0 WHERE bonding IN (2, 3);
