-- Retour arrière de 014 : remet l'Instructeur des maîtrises et ses apparitions (contenu de 001 et 006).
-- Remettre aussi archives\maitrises.lua dans lua_scripts pour qu'il fonctionne.
USE acore_world;

DELETE FROM command WHERE name IN ('solform', 'solform liste', 'solform acheter');

SOURCE C:/SolAzeroth/sql/migrations/001_pnj_maitrises.up.sql
USE acore_world;
REPLACE INTO `creature` VALUES (5300681,900000,1,0,0,1,1,0,1631.87,-4413.22,16.8368,3.3222,300,0,0,15505,0,0,0,0,0,'',NULL,0,NULL);
REPLACE INTO `creature` VALUES (5300683,900000,0,0,0,1,1,0,-8848.53,630.77,95.0734,0.456662,300,0,0,15505,0,0,0,0,0,'',NULL,0,NULL);
