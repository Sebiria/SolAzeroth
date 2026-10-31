-- v3, F5f (31/10/2026) : accès au Gouffre de Ragefeu par Ruga Brise-cendre, à 60 % de Durotar (v3_gouffre.cpp).
USE acore_world;

-- Ruga parle (dialogue) en plus de donner ses quêtes, avec l'option « Descendre dans la faille ».
UPDATE creature_template SET npcflag = npcflag | 1, ScriptName = 'npc_solazeroth_ruga' WHERE entry = 910001;
DELETE FROM npc_text WHERE ID = 910001;
INSERT INTO npc_text (ID, text0_0, text0_1, Probability0) VALUES (910001,
    'La faille descend jusqu''au Gouffre de Ragefeu. Personne ne passe sans avoir prouvé qu''il connaît sa terre.',
    'La faille descend jusqu''au Gouffre de Ragefeu. Personne ne passe sans avoir prouvé qu''il connaît sa terre.', 1);

-- La sortie du Gouffre ramène devant Ruga, au Rocher du crâne, et non plus dans Orgrimmar.
UPDATE areatrigger_teleport SET target_map = 1, target_position_x = 1462.5, target_position_y = -4693.5,
    target_position_z = 6.6, target_orientation = 3.47 WHERE ID = 2226;
