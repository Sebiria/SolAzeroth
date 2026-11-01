-- v3 (02/11/2026, audit du jeu, lot 0) : le Journal de bord détrempé (910157) gardait la page de l'objet copié (396,
-- une histoire d'Elune et du Bois de la Pénombre). Les reliques n'ont pas de page héritée (annexes_durotar.py corrigé).
USE acore_world;
CREATE TABLE solazeroth_v3_reliques_pages SELECT entry, PageText, PageMaterial FROM item_template
WHERE entry BETWEEN 910150 AND 910165 AND PageText > 0;
UPDATE item_template SET PageText = 0, PageMaterial = 0 WHERE entry BETWEEN 910150 AND 910165;
