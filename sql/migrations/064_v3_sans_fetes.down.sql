-- Annule 064 : rend les fêtes et leurs quêtes.
USE acore_world;
UPDATE game_event e JOIN solazeroth_v3_fetes_origine o ON o.eventEntry = e.eventEntry
    SET e.holiday = o.holiday, e.holidayStage = o.holidayStage, e.start_time = o.start_time, e.end_time = o.end_time;
DROP TABLE solazeroth_v3_fetes_origine;
DELETE FROM disables WHERE sourceType = 1 AND comment = 'Sol''Azeroth v3 : quete de fete';
