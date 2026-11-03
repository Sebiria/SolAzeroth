-- 03/11/2026 (signalement de l'utilisateur) : prix d'achat x3 de nos pièces chez les marchands de Razor Hill
-- (outils\equipement_v3.py, prix) ; la puissance requise à l'achat est vérifiée par v3_equipement.cpp.
USE acore_world;
UPDATE item_template SET BuyPrice = BuyPrice * 3 WHERE entry BETWEEN 910201 AND 910299 AND BuyPrice > 0;
