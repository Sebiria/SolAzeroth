-- Retour du lot T9 des Tarides : marchands, Hraq et bateau d'origine.
USE acore_world;
DELETE FROM npc_vendor WHERE entry IN (3479, 3483, 3486, 10380) AND item BETWEEN 910500 AND 910595;
INSERT IGNORE INTO npc_vendor SELECT * FROM solazeroth_v3_t9_ventes_origine;
UPDATE creature_template c JOIN solazeroth_v3_t9_pnj_origine o ON o.entry = c.entry SET c.npcflag = o.npcflag, c.gossip_menu_id = o.gossip_menu_id, c.ScriptName = o.ScriptName;
DELETE FROM solazeroth_v3_fournisseur WHERE pnj = 3477;
INSERT IGNORE INTO transports SELECT * FROM solazeroth_v3_t9_transports_origine;
DROP TABLE IF EXISTS solazeroth_v3_t9_ventes_origine, solazeroth_v3_t9_pnj_origine, solazeroth_v3_t9_transports_origine;
