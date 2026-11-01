-- v3 (01/11/2026, demande de l'utilisateur) : la Combe des Kolkar (lieu A05) passe de 20 à 30 monstres à éliminer :
-- 18 Manœuvres kolkar (3119) et 11 Estafettes kolkar (3120), plus Kolkanis renforcé. Il n'y en a que 12 et 7 sur
-- place (5 min de réapparition) : il faut attendre une partie des réapparitions. Source : « Durotar — Histoire et
-- quêtes (brouillon).md », § 4.1.1 (outils\zone_durotar.py).
UPDATE acore_world.solazeroth_v3_lieux_monstres SET nombre = 18 WHERE lieu = 5 AND creature = 3119;
UPDATE acore_world.solazeroth_v3_lieux_monstres SET nombre = 11 WHERE lieu = 5 AND creature = 3120;
