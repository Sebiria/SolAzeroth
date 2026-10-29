-- Chapitre d'histoire vers 45-48 (calibrage final E7, décision de l'utilisateur du 29/10/2026).
-- « Les cultes de la mort » s'insère entre le Porte-froid (37) et les Maleterres (55) : Zul'Farrak et le temple
-- d'Atal'Hakkar, accessibles aux deux camps. La chaîne passe à 17 chapitres (titres renumérotés).
USE acore_world;

CREATE TEMPORARY TABLE chapitre_qt SELECT * FROM quest_template WHERE ID = 900203;
UPDATE chapitre_qt SET ID = 900216, QuestLevel = 48, MinLevel = 45, RewardMoney = 24000,
    LogTitle = 'Le fil du Fléau 4/17 : Les cultes de la mort',
    LogDescription = 'Tue le féticheur Zum''rah à Zul''Farrak, Jammal''an le prophète et l''Ombre d''Eranikus au temple d''Atal''Hakkar.',
    QuestDescription = 'Le Fléau n''a rien inventé, $N. Bien avant Kel''Thuzad, les trolls savaient arracher les morts à leur repos.$B$BÀ Zul''Farrak, au cœur du Tanaris, le féticheur Zum''rah relève les morts du cimetière de la cité. Sous les eaux du marais des Chagrins, dans le temple d''Atal''Hakkar, le prophète Jammal''an sacrifie les siens pour rappeler le dieu du sang, et l''ombre du dragon Eranikus, rongée par le Cauchemar, garde le sanctuaire.$B$BLe Culte des damnés recrute là où la mort a déjà des serviteurs. Prive-le de ces alliés.',
    RequiredNpcOrGo1 = 7271, RequiredNpcOrGo2 = 5710, RequiredNpcOrGo3 = 5709;
INSERT INTO quest_template SELECT * FROM chapitre_qt;
DROP TEMPORARY TABLE chapitre_qt;

CREATE TEMPORARY TABLE chapitre_qa SELECT * FROM quest_template_addon WHERE ID = 900203;
UPDATE chapitre_qa SET ID = 900216, PrevQuestID = 900202;
INSERT INTO quest_template_addon SELECT * FROM chapitre_qa;
DROP TEMPORARY TABLE chapitre_qa;
UPDATE quest_template_addon SET PrevQuestID = 900216 WHERE ID = 900203;

INSERT INTO quest_offer_reward (ID, RewardText) VALUES (900216,
    'Les trolls ont joué avec la mort bien avant le Roi-liche. Arthas n''a eu qu''à ramasser leurs secrets. Les Maleterres t''attendent.');
INSERT INTO quest_request_items (ID, CompletionText) VALUES (900216, 'Alors, $N ? Le chapitre est-il écrit ?');
INSERT INTO creature_queststarter (id, quest) VALUES (900120, 900216);
INSERT INTO creature_questender (id, quest) VALUES (900120, 900216);

-- Chapitres 4 à 16 décalés d'un rang, nouveau chapitre 4 au niveau 45.
UPDATE solazeroth_histoire SET chapitre = chapitre + 1 WHERE chapitre >= 4 ORDER BY chapitre DESC;
INSERT INTO solazeroth_histoire (chapitre, quete, niveau, ilvl) VALUES (4, 900216, 45, 0);
UPDATE quest_template SET LogTitle = REPLACE(LogTitle, 'Fléau 1/16 :', 'Fléau 1/17 :') WHERE ID = 900200;
UPDATE quest_template SET LogTitle = REPLACE(LogTitle, 'Fléau 2/16 :', 'Fléau 2/17 :') WHERE ID = 900201;
UPDATE quest_template SET LogTitle = REPLACE(LogTitle, 'Fléau 3/16 :', 'Fléau 3/17 :') WHERE ID = 900202;
UPDATE quest_template SET LogTitle = REPLACE(LogTitle, 'Fléau 4/16 :', 'Fléau 5/17 :') WHERE ID = 900203;
UPDATE quest_template SET LogTitle = REPLACE(LogTitle, 'Fléau 5/16 :', 'Fléau 6/17 :') WHERE ID = 900204;
UPDATE quest_template SET LogTitle = REPLACE(LogTitle, 'Fléau 6/16 :', 'Fléau 7/17 :') WHERE ID = 900205;
UPDATE quest_template SET LogTitle = REPLACE(LogTitle, 'Fléau 7/16 :', 'Fléau 8/17 :') WHERE ID = 900206;
UPDATE quest_template SET LogTitle = REPLACE(LogTitle, 'Fléau 8/16 :', 'Fléau 9/17 :') WHERE ID = 900207;
UPDATE quest_template SET LogTitle = REPLACE(LogTitle, 'Fléau 9/16 :', 'Fléau 10/17 :') WHERE ID = 900208;
UPDATE quest_template SET LogTitle = REPLACE(LogTitle, 'Fléau 10/16 :', 'Fléau 11/17 :') WHERE ID = 900209;
UPDATE quest_template SET LogTitle = REPLACE(LogTitle, 'Fléau 11/16 :', 'Fléau 12/17 :') WHERE ID = 900210;
UPDATE quest_template SET LogTitle = REPLACE(LogTitle, 'Fléau 12/16 :', 'Fléau 13/17 :') WHERE ID = 900211;
UPDATE quest_template SET LogTitle = REPLACE(LogTitle, 'Fléau 13/16 :', 'Fléau 14/17 :') WHERE ID = 900212;
UPDATE quest_template SET LogTitle = REPLACE(LogTitle, 'Fléau 14/16 :', 'Fléau 15/17 :') WHERE ID = 900213;
UPDATE quest_template SET LogTitle = REPLACE(LogTitle, 'Fléau 15/16 :', 'Fléau 16/17 :') WHERE ID = 900214;
UPDATE quest_template SET LogTitle = REPLACE(LogTitle, 'Fléau 16/16 :', 'Fléau 17/17 :') WHERE ID = 900215;
