-- Remet banquiers, guildes, coffres, PNJ d'ambiance et hauts faits natifs (la progression effacée ne revient pas).
USE acore_world;
UPDATE creature_template t JOIN solazeroth_v3_drapeaux_origine o ON o.genre = 'modele' AND o.cle = t.entry SET t.npcflag = o.npcflag;
UPDATE creature c JOIN solazeroth_v3_drapeaux_origine o ON o.genre = 'apparition' AND o.cle = c.guid SET c.npcflag = o.npcflag;
UPDATE gameobject g JOIN solazeroth_v3_phases_origine o ON o.genre = 'objet' AND o.guid = g.guid SET g.phaseMask = o.phaseMask;
UPDATE creature c JOIN solazeroth_v3_phases_origine o ON o.genre = 'pnj' AND o.guid = c.guid SET c.phaseMask = o.phaseMask;
DROP TABLE solazeroth_v3_drapeaux_origine;
DROP TABLE solazeroth_v3_phases_origine;
DELETE FROM disables WHERE sourceType = 4 AND comment = 'Sol''Azeroth v3 : haut fait natif';
