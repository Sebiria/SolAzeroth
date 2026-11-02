-- v3 (02/11/2026) : signalements 17, 18, 24 et 27.
-- - 27 : Envenimer, Rupture, Coup bas et Lancer de couteau perdent le drapeau « coup de grâce » de Blizzard (le client
--   exigeait des points de combo). Même valeur que la migration 129 régénérée (outilsoleur_v3.py).
-- - 24 : deux textes de quête ne s'adressent plus à un guerrier.
-- - 18 : à Sen'jin, Le crâne de Minshina et Zalazane s'ouvrent avec les autres quêtes du village (plus d'aller-retour
--   vers l'île de l'Écho).
-- - 17 : un Monceau Ju-Ju détruit reste détruit 5 minutes au lieu de 30 s.
USE acore_world;
UPDATE spell_dbc SET AttributesEx = 512 WHERE ID IN (100304, 100306, 100313);
UPDATE spell_dbc SET AttributesEx = 262656 WHERE ID = 100311;
UPDATE quest_template SET QuestDescription = 'Les sangliers tachetés ont pris goût à nos réserves. Ils chargent les péons et renversent les tas de bois. Ce n''est qu''un sanglier, me diras-tu. Mais qui ne sait pas tenir face à une charge ne tiendra face à rien. Tue-en dix. Apprends comment ils frappent, et comment ils tombent.' WHERE ID = 910002;
UPDATE quest_offer_reward SET RewardText = 'Ils réfléchiront avant de revenir. Tu as l''œil d''un éclaireur et le bras d''un combattant. Ce plastron est à toi. Mais souviens-toi : le kraal du nord, la géomaîtresse Mouchette et ses gardes de guerre. Un jour, il faudra s''en occuper aussi.' WHERE ID = 910013;
UPDATE quest_template_addon SET PrevQuestID = 910014 WHERE ID IN (910019, 910020);
UPDATE gameobject SET spawntimesecs = 300 WHERE id = 102986;
