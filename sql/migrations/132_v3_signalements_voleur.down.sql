-- Annule la migration 132.
USE acore_world;
UPDATE spell_dbc SET AttributesEx = 1049088 WHERE ID IN (100304, 100306, 100313);
UPDATE spell_dbc SET AttributesEx = 4456960 WHERE ID = 100311;
UPDATE quest_template SET QuestDescription = 'Les sangliers tachetés ont pris goût à nos réserves. Ils chargent les péons et renversent les tas de bois. Ce n''est qu''un sanglier, me diras-tu. Mais un guerrier qui ne sait pas tenir face à une charge ne tiendra face à rien. Tue-en dix. Apprends comment ils frappent, et comment ils tombent.' WHERE ID = 910002;
UPDATE quest_offer_reward SET RewardText = 'Ils réfléchiront avant de revenir. Tu as l''œil d''un éclaireur et la main d''un guerrier. Ce plastron est à toi. Mais souviens-toi : le kraal du nord, la géomaîtresse Mouchette et ses gardes de guerre. Un jour, il faudra s''en occuper aussi.' WHERE ID = 910013;
UPDATE quest_template_addon SET PrevQuestID = 910015 WHERE ID IN (910019, 910020);
UPDATE gameobject SET spawntimesecs = 30 WHERE id = 102986;
