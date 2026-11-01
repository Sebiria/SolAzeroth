-- v3, F7 (01/11/2026) : listes de courses des rangs de potion et des nœuds du camp. Généré par
-- outils\bivouac_v3.py : ne pas modifier à la main. genre 1 = potion, 2 = feu ; objet 0 = or (en cuivre).
USE acore_world;
DROP TABLE IF EXISTS solazeroth_v3_camp_couts;
CREATE TABLE solazeroth_v3_camp_couts (genre TINYINT UNSIGNED NOT NULL, rang TINYINT UNSIGNED NOT NULL, objet INT UNSIGNED NOT NULL, nombre INT UNSIGNED NOT NULL, PRIMARY KEY (genre, rang, objet));
INSERT INTO solazeroth_v3_camp_couts VALUES (2, 2, 2770, 20), (2, 2, 2589, 16), (2, 2, 2318, 12), (2, 2, 910120, 60), (2, 2, 910140, 20), (2, 3, 2835, 8), (2, 3, 2770, 20), (2, 3, 910180, 2), (2, 3, 910120, 160), (2, 3, 910140, 40), (2, 3, 0, 8000), (1, 1, 2447, 12), (1, 1, 765, 8), (1, 1, 2449, 4), (1, 1, 910120, 50), (1, 1, 0, 4000), (1, 2, 2449, 12), (1, 2, 910181, 2), (1, 2, 910120, 120), (1, 2, 910140, 20), (1, 2, 0, 10000);
