-- Rend les Insignes (les Marques déjà versées restent dans les sacs).
USE acore_world;
UPDATE quest_offer_reward q JOIN solazeroth_v3_marques_textes t ON t.ID = q.ID SET q.RewardText = t.RewardText;
DROP TABLE solazeroth_v3_marques_textes;
UPDATE solazeroth_v3_camp_couts SET objet = 910140 WHERE objet = 37711;
USE acore_characters;
REPLACE INTO solazeroth_v3_collection (guid, objet, nombre) SELECT guid, 910140, nombre FROM solazeroth_v3_marques_insignes;
DROP TABLE solazeroth_v3_marques_insignes;
