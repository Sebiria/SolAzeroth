-- Rend aux monstres normaux la fréquence de sorts d'origine (migration 070).
USE acore_world;
UPDATE smart_scripts ss JOIN solazeroth_v3_sorts_monstres s
  ON s.entryorguid = ss.entryorguid AND s.source_type = ss.source_type AND s.id = ss.id AND s.link = ss.link
SET ss.event_param3 = s.event_param3, ss.event_param4 = s.event_param4;
DROP TABLE solazeroth_v3_sorts_monstres;
