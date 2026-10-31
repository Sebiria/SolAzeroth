-- v3 (31/10/2026, journal de combat de Test contre les Familiers vils) : les monstres normaux lancent leurs sorts deux
-- fois moins souvent. Leur vie étant doublée, un combat dure deux fois plus longtemps : sans cela, un lanceur de sorts
-- place deux fois plus de sorts qu'à l'origine, et les sorts ne passent pas par l'armure (Boule de feu toutes les 5 à 7 s).
-- Seuls les sorts répétés en combat (SmartAI, événement 0, action 11) des monstres de rang normal sont touchés.
USE acore_world;
DROP TABLE IF EXISTS solazeroth_v3_sorts_monstres;
CREATE TABLE solazeroth_v3_sorts_monstres AS
SELECT ss.entryorguid, ss.source_type, ss.id, ss.link, ss.event_param3, ss.event_param4
FROM smart_scripts ss JOIN creature_template ct ON ct.entry = ss.entryorguid
WHERE ss.source_type = 0 AND ss.event_type = 0 AND ss.action_type = 11 AND ss.event_param3 > 0 AND ct.`rank` = 0;
UPDATE smart_scripts ss JOIN solazeroth_v3_sorts_monstres s
  ON s.entryorguid = ss.entryorguid AND s.source_type = ss.source_type AND s.id = ss.id AND s.link = ss.link
SET ss.event_param3 = s.event_param3 * 2, ss.event_param4 = s.event_param4 * 2;
