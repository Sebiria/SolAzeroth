-- Chaîne d'histoire « Le fil du Fléau » (section 4.7, V6 ; décisions de l'utilisateur du 28/10/2026 : fil du Fléau de 1 à 80,
-- chapitres conditionnés par le niveau et le niveau d'objet, pas de raccourci jusqu'au Roi-liche).
-- Un chroniqueur à Hurlevent et à Orgrimmar donne 16 quêtes (900200 à 900215), l'une après l'autre. Chaque chapitre se
-- valide par des boss d'origine ou des quêtes d'origine (témoins 900121 à 900125, crédités par histoire.cpp).
USE acore_world;

-- 900120 : chroniqueur. Copie du garde de Hurlevent (68), amical envers tous (35), donneur de quêtes et dialogue (3).
CREATE TEMPORARY TABLE tmp_pnj SELECT * FROM creature_template WHERE entry = 68;
UPDATE tmp_pnj SET entry = 900120, name = 'Chroniqueur de la Croisade', subname = 'Le fil du Fléau', faction = 35,
    npcflag = 3, flags_extra = 2, gossip_menu_id = 0, lootid = 0, pickpocketloot = 0, skinloot = 0, mingold = 0,
    maxgold = 0, AIName = '', ScriptName = 'npc_solazeroth_chroniqueur';
INSERT INTO creature_template SELECT * FROM tmp_pnj;
DROP TEMPORARY TABLE tmp_pnj;
INSERT INTO creature_template_model (CreatureID, Idx, CreatureDisplayID, DisplayScale, Probability, VerifiedBuild)
VALUES (900120, 0, 26228, 1, 1, 0);  -- croisé d'argent

-- Témoins (sans apparition) : seulement des cibles de crédit pour les objectifs de quête.
CREATE TEMPORARY TABLE tmp_pnj SELECT * FROM creature_template WHERE entry = 900110;
UPDATE tmp_pnj SET entry = 900121, name = 'Témoin : Retour à Angrathar', ScriptName = '';
INSERT INTO creature_template SELECT * FROM tmp_pnj;
DROP TEMPORARY TABLE tmp_pnj;
CREATE TEMPORARY TABLE tmp_pnj SELECT * FROM creature_template WHERE entry = 900110;
UPDATE tmp_pnj SET entry = 900122, name = 'Témoin : bataille pour Fossoyeuse', ScriptName = '';
INSERT INTO creature_template SELECT * FROM tmp_pnj;
DROP TEMPORARY TABLE tmp_pnj;
CREATE TEMPORARY TABLE tmp_pnj SELECT * FROM creature_template WHERE entry = 900110;
UPDATE tmp_pnj SET entry = 900123, name = 'Témoin : gambit de Tirion', ScriptName = '';
INSERT INTO creature_template SELECT * FROM tmp_pnj;
DROP TEMPORARY TABLE tmp_pnj;
CREATE TEMPORARY TABLE tmp_pnj SELECT * FROM creature_template WHERE entry = 900110;
UPDATE tmp_pnj SET entry = 900124, name = 'Témoin : chute du Chevalier noir', ScriptName = '';
INSERT INTO creature_template SELECT * FROM tmp_pnj;
DROP TEMPORARY TABLE tmp_pnj;
CREATE TEMPORARY TABLE tmp_pnj SELECT * FROM creature_template WHERE entry = 900110;
UPDATE tmp_pnj SET entry = 900125, name = 'Témoin : salles des Reflets', ScriptName = '';
INSERT INTO creature_template SELECT * FROM tmp_pnj;
DROP TEMPORARY TABLE tmp_pnj;

-- Apparitions : à côté de l'aubergiste de la Rose dorée (Hurlevent) et de Gryshka (Orgrimmar).
INSERT INTO creature (guid, id, map, zoneId, areaId, spawnMask, phaseMask, position_x, position_y, position_z, orientation, spawntimesecs) VALUES
(9001200, 900120, 0, 1519, 0, 1, 1, -8865.0, 671.0, 97.99, 2.06, 300),
(9001201, 900120, 1, 1637, 0, 1, 1, 1631.5, -4437.2, 15.76, 5.90, 300);

-- Chapitres : niveau et niveau d'objet requis (0 : 90 % de l'ilvl attendu au niveau du chapitre, ecart.cpp).
CREATE TABLE solazeroth_histoire (
    chapitre TINYINT UNSIGNED NOT NULL PRIMARY KEY,
    quete INT UNSIGNED NOT NULL,
    niveau TINYINT UNSIGNED NOT NULL,
    ilvl SMALLINT UNSIGNED NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
INSERT INTO solazeroth_histoire VALUES
(1, 900200, 20, 0),
(2, 900201, 35, 0),
(3, 900202, 37, 0),
(4, 900203, 58, 0),
(5, 900204, 68, 0),
(6, 900205, 70, 0),
(7, 900206, 73, 0),
(8, 900207, 74, 0),
(9, 900208, 76, 0),
(10, 900209, 77, 0),
(11, 900210, 80, 175),
(12, 900211, 80, 185),
(13, 900212, 80, 200),
(14, 900213, 80, 213),
(15, 900214, 80, 219),
(16, 900215, 80, 225);

-- Quêtes d'origine qui créditent un témoin.
CREATE TABLE solazeroth_histoire_temoins (
    quete INT UNSIGNED NOT NULL PRIMARY KEY,
    temoin INT UNSIGNED NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
INSERT INTO solazeroth_histoire_temoins VALUES
(12499, 900121),
(12500, 900121),
(13377, 900122),
(13267, 900122),
(13403, 900123),
(13364, 900123),
(13664, 900124),
(24480, 900125),
(24561, 900125);

-- Quêtes.
INSERT INTO quest_template (ID, QuestType, QuestLevel, MinLevel, QuestInfoID, RewardXPDifficulty, RewardMoney, Flags, LogTitle, LogDescription, QuestDescription, QuestCompletionLog, RequiredNpcOrGo1, RequiredNpcOrGoCount1) VALUES
(900200, 2, 20, 18, 81, 5, 10000, 0, 'Le fil du Fléau 1/16 : Ombres sur Lordaeron', 'Tue l''archimage Arugal au donjon d''Ombrecroc, puis reviens voir le chroniqueur.', 'Tu veux comprendre ce qui menace Azeroth, $N ? Alors commence par le commencement. Bien avant le Norfendre, une ombre s''est étendue sur Lordaeron. Au donjon d''Ombrecroc, l''archimage Arugal a ouvert la porte à des horreurs qu''il ne maîtrisait plus. On dit qu''il servait déjà, sans le savoir, des maîtres bien plus anciens.$B$BVa au donjon d''Ombrecroc et mets fin à sa folie.', 'Retourne voir le chroniqueur de la Croisade.', 4275, 1);
INSERT INTO quest_template_addon (ID, PrevQuestID) VALUES (900200, 0);
INSERT INTO quest_offer_reward (ID, RewardText) VALUES (900200, 'Arugal n''était qu''un pion. Mais chaque pion tombé nous rapproche de celui qui joue.');
INSERT INTO quest_request_items (ID, CompletionText) VALUES (900200, 'Alors, $N ? Le chapitre est-il écrit ?');
INSERT INTO creature_queststarter (id, quest) VALUES (900120, 900200);
INSERT INTO creature_questender (id, quest) VALUES (900120, 900200);
INSERT INTO quest_template (ID, QuestType, QuestLevel, MinLevel, QuestInfoID, RewardXPDifficulty, RewardMoney, Flags, LogTitle, LogDescription, QuestDescription, QuestCompletionLog, RequiredNpcOrGo1, RequiredNpcOrGoCount1, RequiredNpcOrGo2, RequiredNpcOrGoCount2) VALUES
(900201, 2, 35, 33, 81, 5, 17500, 0, 'Le fil du Fléau 2/16 : La Croisade écarlate', 'Tue Hérode et la grande inquisitrice Blanchetête au Monastère écarlate.', 'Quand le Fléau a ravagé Lordaeron, certains survivants ont juré de purifier le monde par le feu. La Croisade écarlate est née de cette peur. Elle a perdu la raison, et le Fléau s''en réjouit : chaque croisé fanatique est une arme de plus contre les vivants.$B$BAu Monastère écarlate, abats Hérode et la grande inquisitrice Blanchetête.', 'Retourne voir le chroniqueur de la Croisade.', 3975, 1, 3977, 1);
INSERT INTO quest_template_addon (ID, PrevQuestID) VALUES (900201, 900200);
INSERT INTO quest_offer_reward (ID, RewardText) VALUES (900201, 'La haine aveugle sert toujours l''ennemi. Souviens-t''en quand viendra ton tour de choisir.');
INSERT INTO quest_request_items (ID, CompletionText) VALUES (900201, 'Alors, $N ? Le chapitre est-il écrit ?');
INSERT INTO creature_queststarter (id, quest) VALUES (900120, 900201);
INSERT INTO creature_questender (id, quest) VALUES (900120, 900201);
INSERT INTO quest_template (ID, QuestType, QuestLevel, MinLevel, QuestInfoID, RewardXPDifficulty, RewardMoney, Flags, LogTitle, LogDescription, QuestDescription, QuestCompletionLog, RequiredNpcOrGo1, RequiredNpcOrGoCount1, RequiredNpcOrGo2, RequiredNpcOrGoCount2) VALUES
(900202, 2, 37, 35, 81, 5, 18500, 0, 'Le fil du Fléau 3/16 : Le Porte-froid', 'Tue Tuten''kash et Amnennar le Porte-froid aux Souilles de Tranchebauge.', 'Le Fléau n''est pas resté au nord. Dans les Souilles de Tranchebauge, la liche Amnennar le Porte-froid a pris le contrôle des huttes des hommes-sangliers. C''est l''un des premiers serviteurs du Roi-liche en Kalimdor.$B$BDescends dans les Souilles, abats Tuten''kash et Amnennar.', 'Retourne voir le chroniqueur de la Croisade.', 7355, 1, 7358, 1);
INSERT INTO quest_template_addon (ID, PrevQuestID) VALUES (900202, 900201);
INSERT INTO quest_offer_reward (ID, RewardText) VALUES (900202, 'Une liche de moins. Mais la source de leur pouvoir dort toujours sous la glace.');
INSERT INTO quest_request_items (ID, CompletionText) VALUES (900202, 'Alors, $N ? Le chapitre est-il écrit ?');
INSERT INTO creature_queststarter (id, quest) VALUES (900120, 900202);
INSERT INTO creature_questender (id, quest) VALUES (900120, 900202);
INSERT INTO quest_template (ID, QuestType, QuestLevel, MinLevel, QuestInfoID, RewardXPDifficulty, RewardMoney, Flags, LogTitle, LogDescription, QuestDescription, QuestCompletionLog, RequiredNpcOrGo1, RequiredNpcOrGoCount1, RequiredNpcOrGo2, RequiredNpcOrGoCount2, RequiredNpcOrGo3, RequiredNpcOrGoCount3) VALUES
(900203, 2, 58, 56, 81, 5, 29000, 0, 'Le fil du Fléau 4/16 : Les Maleterres', 'Tue le sombre maître Gandling à la Scholomance, le baron Vaillefendre et Balnazzar à Stratholme.', 'Les Maleterres sont la blessure ouverte de Lordaeron. À la Scholomance, le sombre maître Gandling forme des nécromanciens pour le Fléau. À Stratholme, le baron Vaillefendre règne sur la ville que le prince Arthas a lui-même purgée, et le seigneur de l''effroi Balnazzar s''y cache sous un masque.$B$BTranche ces trois têtes.', 'Retourne voir le chroniqueur de la Croisade.', 1853, 1, 10440, 1, 10813, 1);
INSERT INTO quest_template_addon (ID, PrevQuestID) VALUES (900203, 900202);
INSERT INTO quest_offer_reward (ID, RewardText) VALUES (900203, 'Tu as vu ce qu''Arthas a laissé derrière lui. Il est temps de comprendre ce qu''il est devenu.');
INSERT INTO quest_request_items (ID, CompletionText) VALUES (900203, 'Alors, $N ? Le chapitre est-il écrit ?');
INSERT INTO creature_queststarter (id, quest) VALUES (900120, 900203);
INSERT INTO creature_questender (id, quest) VALUES (900120, 900203);
INSERT INTO quest_template (ID, QuestType, QuestLevel, MinLevel, QuestInfoID, RewardXPDifficulty, RewardMoney, Flags, LogTitle, LogDescription, QuestDescription, QuestCompletionLog, RequiredNpcOrGo1, RequiredNpcOrGoCount1, RequiredNpcOrGo2, RequiredNpcOrGoCount2) VALUES
(900204, 2, 68, 66, 81, 5, 34000, 0, 'Le fil du Fléau 5/16 : Les ennemis du Roi-liche', 'Tue l''exarque Maladaar aux cryptes Auchenaï et Kael''thas Haut-Soleil à la Terrasse des Magistères.', 'Avant de devenir le Roi-liche, Arthas a dû vaincre ceux qui voulaient détruire le Trône de glace. Illidan et Kael''thas ont été envoyés pour le briser. En Outreterre, leurs alliés et leurs secrets survivent encore. Dans les cryptes Auchenaï, l''exarque Maladaar garde des âmes que le Fléau convoite.$B$BAbats Maladaar, puis Kael''thas Haut-Soleil à la Terrasse des Magistères.', 'Retourne voir le chroniqueur de la Croisade.', 18373, 1, 24664, 1);
INSERT INTO quest_template_addon (ID, PrevQuestID) VALUES (900204, 900203);
INSERT INTO quest_offer_reward (ID, RewardText) VALUES (900204, 'Ceux qui devaient arrêter Arthas sont tombés. Il ne reste que nous.');
INSERT INTO quest_request_items (ID, CompletionText) VALUES (900204, 'Alors, $N ? Le chapitre est-il écrit ?');
INSERT INTO creature_queststarter (id, quest) VALUES (900120, 900204);
INSERT INTO creature_questender (id, quest) VALUES (900120, 900204);
INSERT INTO quest_template (ID, QuestType, QuestLevel, MinLevel, QuestInfoID, RewardXPDifficulty, RewardMoney, Flags, LogTitle, LogDescription, QuestDescription, QuestCompletionLog, RequiredNpcOrGo1, RequiredNpcOrGoCount1, RequiredNpcOrGo2, RequiredNpcOrGoCount2) VALUES
(900205, 2, 70, 68, 81, 5, 35000, 0, 'Le fil du Fléau 6/16 : Les rivages du Norfendre', 'Tue Ingvar le Pilleur au donjon d''Utgarde et Keristrasza au Nexus.', 'Le Norfendre, enfin. Avant d''affronter le Fléau, il faut tenir les côtes. Au donjon d''Utgarde, les Vrykuls d''Ingvar le Pilleur servent le Roi-liche. Au Nexus, Keristrasza est retenue par Malygos.$B$BBriser ces deux étaux.', 'Retourne voir le chroniqueur de la Croisade.', 23954, 1, 26723, 1);
INSERT INTO quest_template_addon (ID, PrevQuestID) VALUES (900205, 900204);
INSERT INTO quest_offer_reward (ID, RewardText) VALUES (900205, 'Les côtes sont à nous. La vraie guerre commence maintenant.');
INSERT INTO quest_request_items (ID, CompletionText) VALUES (900205, 'Alors, $N ? Le chapitre est-il écrit ?');
INSERT INTO creature_queststarter (id, quest) VALUES (900120, 900205);
INSERT INTO creature_questender (id, quest) VALUES (900120, 900205);
INSERT INTO quest_template (ID, QuestType, QuestLevel, MinLevel, QuestInfoID, RewardXPDifficulty, RewardMoney, Flags, LogTitle, LogDescription, QuestDescription, QuestCompletionLog, RequiredNpcOrGo1, RequiredNpcOrGoCount1, RequiredNpcOrGo2, RequiredNpcOrGoCount2) VALUES
(900206, 2, 73, 71, 81, 5, 36500, 0, 'Le fil du Fléau 7/16 : Les royaumes souterrains', 'Tue Anub''arak à Azjol-Nérub et le prophète Tharon''ja au donjon de Drak''Tharon.', 'Sous les glaces, l''ancien royaume nérubien d''Azjol-Nérub s''est rendu au Roi-liche. Anub''arak, son ancien roi, est devenu l''un de ses généraux. Au donjon de Drak''Tharon, les trolls Drakkari se sont alliés au Fléau sous la conduite du prophète Tharon''ja.$B$BDescends et frappe-les tous les deux.', 'Retourne voir le chroniqueur de la Croisade.', 29120, 1, 26632, 1);
INSERT INTO quest_template_addon (ID, PrevQuestID) VALUES (900206, 900205);
INSERT INTO quest_offer_reward (ID, RewardText) VALUES (900206, 'Tu as frappé le Fléau dans ses propres entrailles. Il va répondre.');
INSERT INTO quest_request_items (ID, CompletionText) VALUES (900206, 'Alors, $N ? Le chapitre est-il écrit ?');
INSERT INTO creature_queststarter (id, quest) VALUES (900120, 900206);
INSERT INTO creature_questender (id, quest) VALUES (900120, 900206);
INSERT INTO quest_template (ID, QuestType, QuestLevel, MinLevel, QuestInfoID, RewardXPDifficulty, RewardMoney, Flags, LogTitle, LogDescription, QuestDescription, QuestCompletionLog, RequiredNpcOrGo1, RequiredNpcOrGoCount1, ObjectiveText1, RequiredNpcOrGo2, RequiredNpcOrGoCount2, ObjectiveText2) VALUES
(900207, 2, 74, 72, 81, 5, 37000, 0, 'Le fil du Fléau 8/16 : Le Portail du Courroux', 'Termine la quête « Retour à Angrathar » et la bataille pour Fossoyeuse.', 'Devant le Portail du Courroux, l''Alliance et la Horde ont uni leurs forces contre le Fléau. Ce jour-là, la trahison a tout changé. Puis la bataille pour Fossoyeuse a rappelé que les vivants se déchirent aussi entre eux.$B$BVis ces deux moments : le retour à Angrathar et la bataille pour Fossoyeuse.', 'Retourne voir le chroniqueur de la Croisade.', 900121, 1, 'Portail du Courroux vécu', 900122, 1, 'Bataille pour Fossoyeuse vécue');
INSERT INTO quest_template_addon (ID, PrevQuestID) VALUES (900207, 900206);
INSERT INTO quest_offer_reward (ID, RewardText) VALUES (900207, 'Tu sais maintenant ce que coûte la victoire. Et ce que coûte la division.');
INSERT INTO quest_request_items (ID, CompletionText) VALUES (900207, 'Alors, $N ? Le chapitre est-il écrit ?');
INSERT INTO creature_queststarter (id, quest) VALUES (900120, 900207);
INSERT INTO creature_questender (id, quest) VALUES (900120, 900207);
INSERT INTO quest_template (ID, QuestType, QuestLevel, MinLevel, QuestInfoID, RewardXPDifficulty, RewardMoney, Flags, LogTitle, LogDescription, QuestDescription, QuestCompletionLog, RequiredNpcOrGo1, RequiredNpcOrGoCount1, ObjectiveText1, RequiredNpcOrGo2, RequiredNpcOrGoCount2) VALUES
(900208, 2, 76, 74, 81, 5, 38000, 0, 'Le fil du Fléau 9/16 : Les échos du passé', 'Vaincs Mal''Ganis à l''Épuration de Stratholme et tue le héraut Volazj à Ahn''kahet.', 'Pour vaincre Arthas, il faut comprendre sa chute. Les Gardiens du temps peuvent te montrer l''épuration de Stratholme, le jour où le prince a choisi de tout sacrifier pour vaincre Mal''Ganis. À Ahn''kahet, le héraut Volazj murmure des secrets plus anciens encore.$B$BAffronte Mal''Ganis aux Grottes du temps et Volazj à Ahn''kahet.', 'Retourne voir le chroniqueur de la Croisade.', 31006, 1, 'Mal''Ganis vaincu', 29311, 1);
INSERT INTO quest_template_addon (ID, PrevQuestID) VALUES (900208, 900207);
INSERT INTO quest_offer_reward (ID, RewardText) VALUES (900208, 'Tu as vu l''instant où Arthas est tombé. Ne laisse pas ce souvenir te détourner.');
INSERT INTO quest_request_items (ID, CompletionText) VALUES (900208, 'Alors, $N ? Le chapitre est-il écrit ?');
INSERT INTO creature_queststarter (id, quest) VALUES (900120, 900208);
INSERT INTO creature_questender (id, quest) VALUES (900120, 900208);
INSERT INTO quest_template (ID, QuestType, QuestLevel, MinLevel, QuestInfoID, RewardXPDifficulty, RewardMoney, Flags, LogTitle, LogDescription, QuestDescription, QuestCompletionLog, RequiredNpcOrGo1, RequiredNpcOrGoCount1, ObjectiveText1) VALUES
(900209, 2, 77, 75, 81, 5, 38500, 0, 'Le fil du Fléau 10/16 : La Couronne de glace', 'Termine la quête « Le gambit de Tirion » dans la Couronne de glace.', 'La Croisade d''argent prépare l''assaut final dans la Couronne de glace. Tirion Fordring a un plan audacieux pour affronter le Roi-liche en personne au cœur de sa forteresse.$B$BAide Tirion jusqu''au bout de son gambit.', 'Retourne voir le chroniqueur de la Croisade.', 900123, 1, 'Gambit de Tirion vécu');
INSERT INTO quest_template_addon (ID, PrevQuestID) VALUES (900209, 900208);
INSERT INTO quest_offer_reward (ID, RewardText) VALUES (900209, 'Tu as vu le Roi-liche de tes yeux. Tu sais ce qui t''attend.');
INSERT INTO quest_request_items (ID, CompletionText) VALUES (900209, 'Alors, $N ? Le chapitre est-il écrit ?');
INSERT INTO creature_queststarter (id, quest) VALUES (900120, 900209);
INSERT INTO creature_questender (id, quest) VALUES (900120, 900209);
INSERT INTO quest_template (ID, QuestType, QuestLevel, MinLevel, QuestInfoID, RewardXPDifficulty, RewardMoney, Flags, LogTitle, LogDescription, QuestDescription, QuestCompletionLog, RequiredNpcOrGo1, RequiredNpcOrGoCount1) VALUES
(900210, 2, 80, 78, 62, 5, 40000, 64, 'Le fil du Fléau 11/16 : Naxxramas', 'Tue Kel''Thuzad à Naxxramas.', 'Avant la Citadelle, la nécropole de Naxxramas flotte au-dessus de la Désolation des dragons. Kel''Thuzad, le plus fidèle serviteur d''Arthas, y prépare la peste qui doit effacer les vivants.$B$BMonte à bord et abats Kel''Thuzad.', 'Retourne voir le chroniqueur de la Croisade.', 15990, 1);
INSERT INTO quest_template_addon (ID, PrevQuestID) VALUES (900210, 900209);
INSERT INTO quest_offer_reward (ID, RewardText) VALUES (900210, 'Kel''Thuzad est tombé. Le Roi-liche a perdu son bras droit.');
INSERT INTO quest_request_items (ID, CompletionText) VALUES (900210, 'Alors, $N ? Le chapitre est-il écrit ?');
INSERT INTO creature_queststarter (id, quest) VALUES (900120, 900210);
INSERT INTO creature_questender (id, quest) VALUES (900120, 900210);
INSERT INTO quest_template (ID, QuestType, QuestLevel, MinLevel, QuestInfoID, RewardXPDifficulty, RewardMoney, Flags, LogTitle, LogDescription, QuestDescription, QuestCompletionLog, RequiredNpcOrGo1, RequiredNpcOrGoCount1, RequiredNpcOrGo2, RequiredNpcOrGoCount2, ObjectiveText2) VALUES
(900211, 2, 80, 78, 81, 5, 40000, 0, 'Le fil du Fléau 12/16 : Le tournoi d''Argent', 'Tue le Chevalier noir à l''Épreuve du champion et termine « La chute du Chevalier noir ».', 'Au tournoi d''Argent, la Croisade choisit ses champions. Mais le Roi-liche a envoyé l''un des siens : le Chevalier noir, qu''on disait mort.$B$BRemporte l''épreuve du champion, abats le Chevalier noir et perce le secret de son retour.', 'Retourne voir le chroniqueur de la Croisade.', 35451, 1, 900124, 1, 'Chute du Chevalier noir vécue');
INSERT INTO quest_template_addon (ID, PrevQuestID) VALUES (900211, 900210);
INSERT INTO quest_offer_reward (ID, RewardText) VALUES (900211, 'Tu es désormais un champion de la Croisade. Les portes de la Citadelle vont s''ouvrir.');
INSERT INTO quest_request_items (ID, CompletionText) VALUES (900211, 'Alors, $N ? Le chapitre est-il écrit ?');
INSERT INTO creature_queststarter (id, quest) VALUES (900120, 900211);
INSERT INTO creature_questender (id, quest) VALUES (900120, 900211);
INSERT INTO quest_template (ID, QuestType, QuestLevel, MinLevel, QuestInfoID, RewardXPDifficulty, RewardMoney, Flags, LogTitle, LogDescription, QuestDescription, QuestCompletionLog, RequiredNpcOrGo1, RequiredNpcOrGoCount1, RequiredNpcOrGo2, RequiredNpcOrGoCount2, RequiredNpcOrGo3, RequiredNpcOrGoCount3, ObjectiveText3) VALUES
(900212, 2, 80, 78, 81, 5, 40000, 0, 'Le fil du Fléau 13/16 : Les portes de la Citadelle', 'Tue le Dévoreur d''âmes et Tyrannus, puis réussis la fuite des salles des Reflets.', 'Au pied de la Citadelle, trois épreuves gardent l''entrée : la Forge des âmes, la fosse de Saron, et les salles des Reflets où l''épée Deuillelame attend.$B$BAbats le Dévoreur d''âmes, le seigneur du Fléau Tyrannus, puis échappe au Roi-liche dans les salles des Reflets.', 'Retourne voir le chroniqueur de la Croisade.', 36502, 1, 36658, 1, 900125, 1, 'Fuite des salles des Reflets réussie');
INSERT INTO quest_template_addon (ID, PrevQuestID) VALUES (900212, 900211);
INSERT INTO quest_offer_reward (ID, RewardText) VALUES (900212, 'Tu as regardé le Roi-liche en face et tu as survécu. Il est temps d''entrer.');
INSERT INTO quest_request_items (ID, CompletionText) VALUES (900212, 'Alors, $N ? Le chapitre est-il écrit ?');
INSERT INTO creature_queststarter (id, quest) VALUES (900120, 900212);
INSERT INTO creature_questender (id, quest) VALUES (900120, 900212);
INSERT INTO quest_template (ID, QuestType, QuestLevel, MinLevel, QuestInfoID, RewardXPDifficulty, RewardMoney, Flags, LogTitle, LogDescription, QuestDescription, QuestCompletionLog, RequiredNpcOrGo1, RequiredNpcOrGoCount1, RequiredNpcOrGo2, RequiredNpcOrGoCount2, RequiredNpcOrGo3, RequiredNpcOrGoCount3) VALUES
(900213, 2, 80, 78, 62, 5, 40000, 64, 'Le fil du Fléau 14/16 : La Flèche inférieure', 'Tue le seigneur Gargamoelle, Dame Murmemort et le Porte-mort Saurcroc à la Citadelle de la Couronne de glace.', 'La Citadelle de la Couronne de glace. Ses premières salles sont gardées par le seigneur Gargamoelle, Dame Murmemort et le Porte-mort Saurcroc. Entre les deux, les canonnières de l''Alliance et de la Horde se disputent le ciel.$B$BOuvre la voie.', 'Retourne voir le chroniqueur de la Croisade.', 36612, 1, 36855, 1, 37813, 1);
INSERT INTO quest_template_addon (ID, PrevQuestID) VALUES (900213, 900212);
INSERT INTO quest_offer_reward (ID, RewardText) VALUES (900213, 'La Flèche est à nous. Les trois ailes de la Citadelle t''attendent.');
INSERT INTO quest_request_items (ID, CompletionText) VALUES (900213, 'Alors, $N ? Le chapitre est-il écrit ?');
INSERT INTO creature_queststarter (id, quest) VALUES (900120, 900213);
INSERT INTO creature_questender (id, quest) VALUES (900120, 900213);
INSERT INTO quest_template (ID, QuestType, QuestLevel, MinLevel, QuestInfoID, RewardXPDifficulty, RewardMoney, Flags, LogTitle, LogDescription, QuestDescription, QuestCompletionLog, RequiredNpcOrGo1, RequiredNpcOrGoCount1, RequiredNpcOrGo2, RequiredNpcOrGoCount2, RequiredNpcOrGo3, RequiredNpcOrGoCount3, RequiredNpcOrGo4, RequiredNpcOrGoCount4) VALUES
(900214, 2, 80, 78, 62, 5, 40000, 64, 'Le fil du Fléau 15/16 : Les trois ailes', 'Tue le professeur Putricide, le prince Valanar, la reine de sang Lana''thel et Sindragosa.', 'Trois ailes mènent au sommet. La Peste, où le professeur Putricide prépare ses horreurs. Le Sang, où règnent le conseil des princes et la reine Lana''thel. Le Givre, où Valithria Marcherêve doit être sauvée et où Sindragosa garde la dernière porte.$B$BTraverse les trois ailes.', 'Retourne voir le chroniqueur de la Croisade.', 36678, 1, 37970, 1, 37955, 1, 36853, 1);
INSERT INTO quest_template_addon (ID, PrevQuestID) VALUES (900214, 900213);
INSERT INTO quest_offer_reward (ID, RewardText) VALUES (900214, 'Les trois ailes sont tombées. Il ne reste que le Trône de glace.');
INSERT INTO quest_request_items (ID, CompletionText) VALUES (900214, 'Alors, $N ? Le chapitre est-il écrit ?');
INSERT INTO creature_queststarter (id, quest) VALUES (900120, 900214);
INSERT INTO creature_questender (id, quest) VALUES (900120, 900214);
INSERT INTO quest_template (ID, QuestType, QuestLevel, MinLevel, QuestInfoID, RewardXPDifficulty, RewardMoney, Flags, LogTitle, LogDescription, QuestDescription, QuestCompletionLog, RequiredNpcOrGo1, RequiredNpcOrGoCount1) VALUES
(900215, 2, 80, 78, 62, 5, 40000, 64, 'Le fil du Fléau 16/16 : Le Trône de glace', 'Tue le Roi-liche au sommet de la Citadelle de la Couronne de glace.', 'Tout ce chemin mène ici. Au sommet de la Citadelle, sur le Trône de glace, le Roi-liche t''attend avec Tirion Fordring.$B$BMets fin au règne d''Arthas.', 'Retourne voir le chroniqueur de la Croisade.', 36597, 1);
INSERT INTO quest_template_addon (ID, PrevQuestID) VALUES (900215, 900214);
INSERT INTO quest_offer_reward (ID, RewardText) VALUES (900215, 'Le Roi-liche est tombé. Il faut toujours un Roi-liche... mais aujourd''hui, Azeroth respire. Ton histoire est complète, $N.');
INSERT INTO quest_request_items (ID, CompletionText) VALUES (900215, 'Alors, $N ? Le chapitre est-il écrit ?');
INSERT INTO creature_queststarter (id, quest) VALUES (900120, 900215);
INSERT INTO creature_questender (id, quest) VALUES (900120, 900215);

