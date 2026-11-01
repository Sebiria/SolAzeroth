USE acore_world;

DELETE FROM gameobject WHERE guid BETWEEN 9100028 AND 9100033;
DELETE FROM creature_loot_template WHERE Entry = 3101 AND Item = 2589;
