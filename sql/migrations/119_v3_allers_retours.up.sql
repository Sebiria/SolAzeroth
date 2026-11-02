-- Audit du jeu, lot 6b (02/11/2026, C8 ; choix de l'utilisateur : « donner ensemble ») : les quêtes qui se font au
-- même endroit se prennent ensemble (Convent : D04, D05, D07 ; Tiragarde : D09, D12 ; Combe des Kolkar : D16, D17 ;
-- îles de l'Écho : D18, D19, D20). Introductions de D05 et D20 accordées.
USE acore_world;
DELETE FROM conditions WHERE SourceTypeOrReferenceId = 19 AND SourceEntry = 910005;
UPDATE quest_template_addon SET PrevQuestID = 910002 WHERE ID = 910005;
DELETE FROM conditions WHERE SourceTypeOrReferenceId = 19 AND SourceEntry = 910007;
UPDATE quest_template_addon SET PrevQuestID = 910002 WHERE ID = 910007;
DELETE FROM conditions WHERE SourceTypeOrReferenceId = 19 AND SourceEntry = 910012;
UPDATE quest_template_addon SET PrevQuestID = 910008 WHERE ID = 910012;
DELETE FROM conditions WHERE SourceTypeOrReferenceId = 19 AND SourceEntry = 910017;
UPDATE quest_template_addon SET PrevQuestID = 910014 WHERE ID = 910017;
DELETE FROM conditions WHERE SourceTypeOrReferenceId = 19 AND SourceEntry = 910020;
UPDATE quest_template_addon SET PrevQuestID = 910015 WHERE ID = 910020;
UPDATE quest_template SET QuestDescription = REPLACE(QuestDescription, 'Les péons ont raison d''avoir peur. Ce que tu as vu là-bas, ce sont des démons. De petits démons, mais des démons quand même.', 'Les péons ont raison d''avoir peur. Ceux qui reviennent du Convent parlent de démons, et ils ne mentent pas : de petits démons, mais des démons quand même.') WHERE ID = 910005;
UPDATE quest_template SET QuestDescription = REPLACE(QuestDescription, 'Le moment est venu. Zalazane a perdu le crâne, ses gardes ne voient plus nos éclaireurs, et nos guerriers ont l''esprit clair.', 'Le moment approche. Zalazane tient sa force du crâne de Minshina : reprends-le, et ses gardes ne verront plus nos éclaireurs, nos guerriers retrouveront l''esprit clair.') WHERE ID = 910020;
