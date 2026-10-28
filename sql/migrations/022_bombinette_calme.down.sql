-- Retour arrière de 022 : apparence de l'Alarme-bombe 2600
USE acore_world;

UPDATE creature_template_model SET CreatureDisplayID = 6888 WHERE CreatureID = 9656 AND Idx = 0;
REPLACE INTO creature_template_locale (entry, locale, Name, Title, VerifiedBuild)
    VALUES (9656, 'frFR', 'Alarme-bombe ramasseuse', '', 0);
