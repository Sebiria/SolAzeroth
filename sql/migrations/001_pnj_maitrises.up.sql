-- PNJ 900000 : Instructeur des maîtrises (section 3.7)
-- Copie de Woo Ping (11867, maître d'armes de Hurlevent), rendu neutre et à menu simple.
USE acore_world;

CREATE TEMPORARY TABLE tmp_pnj SELECT * FROM creature_template WHERE entry = 11867;
UPDATE tmp_pnj SET
    entry = 900000,
    name = 'Instructeur des maîtrises',
    subname = 'Armes et armures',
    npcflag = 1,        -- menu (gossip) uniquement, géré par lua_scripts/maitrises.lua
    faction = 35,       -- amical pour tous
    gossip_menu_id = 0,
    ScriptName = '',
    AIName = '';
INSERT INTO creature_template SELECT * FROM tmp_pnj;
DROP TEMPORARY TABLE tmp_pnj;

INSERT INTO creature_template_model (CreatureID, Idx, CreatureDisplayID, DisplayScale, Probability, VerifiedBuild)
VALUES (900000, 0, 11804, 1, 1, 12340);
