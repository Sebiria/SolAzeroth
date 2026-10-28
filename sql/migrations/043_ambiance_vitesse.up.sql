-- PNJ d'ambiance : vitesse de course d'un joueur (1, soit 7 m/s). Le modèle copié du garde (68) courait à 1.43,
-- ce qui faisait paraître les coureurs accélérés (retour de l'utilisateur du 28/10/2026).
USE acore_world;

UPDATE creature_template SET speed_walk = 1, speed_run = 1 WHERE entry = 900110;
