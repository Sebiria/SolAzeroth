-- Yarrog Plaie-d'ombre (apparition 12303) remis en jeu : la migration 065 l'avait caché comme PNJ d'ambiance de
-- Durotar (faction 7 prise pour non hostile), alors qu'il porte le Médaillon de la Lame ardente (quête 910007).
-- outils\sans_guildes.py est corrigé : il n'est plus dans la liste.
USE acore_world;
UPDATE creature c JOIN solazeroth_v3_phases_origine o ON o.genre = 'pnj' AND o.guid = c.guid
SET c.phaseMask = o.phaseMask WHERE c.guid = 12303;
DELETE FROM solazeroth_v3_phases_origine WHERE genre = 'pnj' AND guid = 12303;
