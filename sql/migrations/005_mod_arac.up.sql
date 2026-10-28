-- mod-arac : toutes les races avec toutes les classes (section 3.1)
-- Le module n'a pas de code C++ : son SQL n'est pas appliqué automatiquement par le serveur.
-- On copie d'abord les tables qu'il modifie, pour pouvoir revenir en arrière (005_mod_arac.down.sql).
USE acore_world;

CREATE TABLE solazeroth_bak005_quest AS
    SELECT qt.ID, qt.AllowableRaces FROM quest_template qt
    INNER JOIN quest_template_addon qa ON qa.ID = qt.ID
    WHERE qa.AllowableClasses != 0 AND qt.AllowableRaces != 0;
CREATE TABLE solazeroth_bak005_playercreateinfo AS SELECT * FROM playercreateinfo;
CREATE TABLE solazeroth_bak005_playercreateinfo_action AS SELECT * FROM playercreateinfo_action;
CREATE TABLE solazeroth_bak005_playercreateinfo_spell_custom AS SELECT * FROM playercreateinfo_spell_custom;
CREATE TABLE solazeroth_bak005_playercreateinfo_skills AS SELECT * FROM playercreateinfo_skills;
CREATE TABLE solazeroth_bak005_player_totem_model AS SELECT * FROM player_totem_model;

SOURCE C:/SolAzeroth/azerothcore/modules/mod-arac/data/sql/db-world/arac.sql
