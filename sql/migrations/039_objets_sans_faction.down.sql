-- Retour arrière de 039 : remet les limites de faction d'origine des armes et armures
USE acore_world;

UPDATE item_template t JOIN solazeroth_objets_faction_origine o ON o.entry = t.entry
SET t.FlagsExtra = o.FlagsExtra, t.AllowableRace = o.AllowableRace;

DROP TABLE solazeroth_objets_faction_origine;
