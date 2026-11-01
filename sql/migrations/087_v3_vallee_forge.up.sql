-- v3 (01/11/2026, demande de l'utilisateur) : une forge et une enclume dans la vallée des Épreuves, à côté de Kaltunk
-- (premier donneur de quête), pour fabriquer maille et armes dès le départ (v3_equipement.cpp : focus de sort 1 et 3).
-- Mêmes objets qu'à Razor Hill (enclume 51702, forge ardente 50983). Hauteur du sol prise entre Kaltunk (39,0) et les
-- socles voisins (38,0). D'abord posées près de Thazz'ril : l'utilisateur les voulait plus près du départ.
USE acore_world;

DELETE FROM gameobject WHERE guid IN (9100034, 50983, 1, 14, 363, 1, 1, -601.0, -4262.0, 38.4, 2.2, 0, 0, 0.891207, 0.453596, 0, 100, 1),
(9100035, 51702, 1, 14, 363, 1, 1, -596.0, -4266.5, 38.3, 2.2, 0, 0, 0.891207, 0.453596, 0, 100, 1);
