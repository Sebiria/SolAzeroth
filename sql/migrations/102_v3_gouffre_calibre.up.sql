-- v3 (01/11/2026) : calibrage du Gouffre de Ragefeu (puissance abaissée, packs de 2). Généré par
-- outils\gouffre_v3.py : ne pas modifier à la main.
USE acore_world;
CREATE TABLE IF NOT EXISTS solazeroth_v3_gouffre_origine SELECT entry, minlevel, maxlevel, `rank`, HealthModifier, DamageModifier FROM creature_template WHERE entry IN (11318, 11319, 11320, 11321, 11322, 11324, 11323, 11517, 11518, 11519, 11520);
UPDATE creature_template SET minlevel = 10, maxlevel = 11, `rank` = 0, HealthModifier = 0.85, DamageModifier = 0.85 WHERE entry = 11318;
UPDATE creature_template SET minlevel = 10, maxlevel = 11, `rank` = 0, HealthModifier = 0.85, DamageModifier = 0.85 WHERE entry = 11319;
UPDATE creature_template SET minlevel = 10, maxlevel = 10, `rank` = 0, HealthModifier = 0.85, DamageModifier = 0.85 WHERE entry = 11320;
UPDATE creature_template SET minlevel = 10, maxlevel = 10, `rank` = 0, HealthModifier = 0.85, DamageModifier = 0.85 WHERE entry = 11321;
UPDATE creature_template SET minlevel = 10, maxlevel = 11, `rank` = 0, HealthModifier = 0.85, DamageModifier = 0.85 WHERE entry = 11322;
UPDATE creature_template SET minlevel = 10, maxlevel = 11, `rank` = 0, HealthModifier = 0.85, DamageModifier = 0.85 WHERE entry = 11324;
UPDATE creature_template SET minlevel = 11, maxlevel = 11, `rank` = 1, HealthModifier = 0.70, DamageModifier = 0.70 WHERE entry = 11323;
UPDATE creature_template SET minlevel = 12, maxlevel = 12, HealthModifier = 0.94, DamageModifier = 0.94 WHERE entry = 11517;
UPDATE creature_template SET minlevel = 12, maxlevel = 12, HealthModifier = 1.26, DamageModifier = 1.26 WHERE entry = 11518;
UPDATE creature_template SET minlevel = 12, maxlevel = 12, HealthModifier = 0.94, DamageModifier = 0.94 WHERE entry = 11519;
UPDATE creature_template SET minlevel = 12, maxlevel = 12, HealthModifier = 0.94, DamageModifier = 0.94 WHERE entry = 11520;
CREATE TABLE IF NOT EXISTS solazeroth_v3_gouffre_apparitions SELECT * FROM creature WHERE guid IN (48655, 48649, 48666, 48665, 48695, 48694, 48691, 48688, 48687, 48689, 48705, 48693, 48692, 48701, 48702, 48714, 48722, 48719, 48732, 48735, 48743, 48745);
CREATE TABLE IF NOT EXISTS solazeroth_v3_gouffre_apparitions_addon SELECT * FROM creature_addon WHERE guid IN (48655, 48649, 48666, 48665, 48695, 48694, 48691, 48688, 48687, 48689, 48705, 48693, 48692, 48701, 48702, 48714, 48722, 48719, 48732, 48735, 48743, 48745);
DELETE FROM creature_addon WHERE guid IN (48655, 48649, 48666, 48665, 48695, 48694, 48691, 48688, 48687, 48689, 48705, 48693, 48692, 48701, 48702, 48714, 48722, 48719, 48732, 48735, 48743, 48745);
DELETE FROM creature WHERE guid IN (48655, 48649, 48666, 48665, 48695, 48694, 48691, 48688, 48687, 48689, 48705, 48693, 48692, 48701, 48702, 48714, 48722, 48719, 48732, 48735, 48743, 48745);
