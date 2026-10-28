-- La mascotte ramasseuse reprend l'apparence d'origine de la Bombinette : l'Alarme-bombe 2600 sonnait l'alarme
-- en permanence (animation de repos du modèle).
USE acore_world;

UPDATE creature_template_model SET CreatureDisplayID = 8909 WHERE CreatureID = 9656 AND Idx = 0;
REPLACE INTO creature_template_locale (entry, locale, Name, Title, VerifiedBuild)
    VALUES (9656, 'frFR', 'Bombinette ramasseuse', '', 0);
