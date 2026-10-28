-- Témoins de l'histoire (900121 à 900125, migration 045) : un modèle, pour éviter l'avertissement au démarrage.
USE acore_world;

INSERT INTO creature_template_model (CreatureID, Idx, CreatureDisplayID, DisplayScale, Probability, VerifiedBuild)
SELECT t.entry, 0, m.CreatureDisplayID, 1, 1, 0 FROM creature_template t
JOIN creature_template_model m ON m.CreatureID = 900110 AND m.Idx = 0
WHERE t.entry BETWEEN 900121 AND 900125;
