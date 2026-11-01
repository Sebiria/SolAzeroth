USE acore_world;

UPDATE gameobject SET spawntimesecs = 180 WHERE guid BETWEEN 9100028 AND 9100033 OR guid BETWEEN 9100036 AND 9100049;
DELETE FROM npc_vendor WHERE entry = 3158 AND item = 2678;
DELETE FROM item_template_locale WHERE ID = 910235;
DELETE FROM item_template WHERE entry = 910235;
