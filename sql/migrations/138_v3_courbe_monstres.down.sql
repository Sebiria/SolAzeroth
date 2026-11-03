-- Retire la courbe des monstres (migration 138).
USE acore_world;
DROP TABLE IF EXISTS solazeroth_v3_courbe_puissance, solazeroth_v3_courbe_entrees;
