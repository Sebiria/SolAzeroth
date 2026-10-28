-- Ressources empilables par 99 (demande de l'utilisateur, V2) : marchandises (classe 7 : tissu, cuir,
-- minerais, herbes, viande, éléments, composants d'enchantement...) et composants (classe 5) qui
-- s'empilaient par 5, 10 ou 20. Celles qui s'empilaient déjà par plus de 99 ne changent pas.
USE acore_world;

CREATE TABLE solazeroth_bak015_piles AS
    SELECT entry, stackable FROM item_template WHERE class IN (5, 7) AND stackable > 1 AND stackable < 99;

UPDATE item_template SET stackable = 99 WHERE class IN (5, 7) AND stackable > 1 AND stackable < 99;
