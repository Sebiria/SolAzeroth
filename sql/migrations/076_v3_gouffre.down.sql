-- Rend au Gouffre de Ragefeu sa sortie vers Orgrimmar et retire le dialogue de Ruga Brise-cendre.
USE acore_world;
UPDATE creature_template SET npcflag = npcflag & ~1, ScriptName = '' WHERE entry = 910001;
DELETE FROM npc_text WHERE ID = 910001;
UPDATE areatrigger_teleport SET target_map = 1, target_position_x = 1813.49, target_position_y = -4418.58,
    target_position_z = -18.57, target_orientation = 1.78 WHERE ID = 2226;
