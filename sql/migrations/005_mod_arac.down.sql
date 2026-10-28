-- Retour arrière de 005 : remet les tables telles qu'avant mod-arac.
-- Penser aussi à remettre les DBC d'origine (data\dbc_origine) et à retirer Patch-A.MPQ du client.
USE acore_world;

UPDATE quest_template qt INNER JOIN solazeroth_bak005_quest b ON b.ID = qt.ID SET qt.AllowableRaces = b.AllowableRaces;

DELETE FROM playercreateinfo;              INSERT INTO playercreateinfo SELECT * FROM solazeroth_bak005_playercreateinfo;
DELETE FROM playercreateinfo_action;       INSERT INTO playercreateinfo_action SELECT * FROM solazeroth_bak005_playercreateinfo_action;
DELETE FROM playercreateinfo_spell_custom; INSERT INTO playercreateinfo_spell_custom SELECT * FROM solazeroth_bak005_playercreateinfo_spell_custom;
DELETE FROM playercreateinfo_skills;       INSERT INTO playercreateinfo_skills SELECT * FROM solazeroth_bak005_playercreateinfo_skills;
DELETE FROM player_totem_model;            INSERT INTO player_totem_model SELECT * FROM solazeroth_bak005_player_totem_model;

DROP TABLE solazeroth_bak005_quest, solazeroth_bak005_playercreateinfo, solazeroth_bak005_playercreateinfo_action,
    solazeroth_bak005_playercreateinfo_spell_custom, solazeroth_bak005_playercreateinfo_skills, solazeroth_bak005_player_totem_model;
