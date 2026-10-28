-- Autels du défi (objet 254605) déplacés à 4 mètres devant le point d'apparition de chaque zone de départ,
-- tournés vers le joueur. Positions calculées depuis playercreateinfo (une classe représentative par race).
USE acore_world;

CREATE TABLE solazeroth_bak008_autels AS SELECT * FROM gameobject WHERE id = 254605;

CREATE TEMPORARY TABLE tmp_autels (guid INT UNSIGNED PRIMARY KEY, race TINYINT UNSIGNED, class TINYINT UNSIGNED);
INSERT INTO tmp_autels VALUES
    (5530536, 1, 1),   -- Comté du Nord : humains
    (5530537, 3, 1),   -- Vallée de Frigecrête : nains, gnomes
    (5530538, 4, 1),   -- Sombrevallon : elfes de la nuit
    (5530539, 11, 1),  -- Val d'Ammen : draeneï
    (5530540, 2, 1),   -- Vallée des Épreuves : orcs, trolls
    (5530541, 5, 1),   -- Le Glas : morts-vivants
    (5530542, 6, 1),   -- Camp Narache : taurens
    (5530543, 10, 2),  -- Île de Haut-Soleil : elfes de sang
    (5530544, 1, 6);   -- Achérus : chevaliers de la mort

UPDATE gameobject g
INNER JOIN tmp_autels t ON t.guid = g.guid
INNER JOIN playercreateinfo p ON p.race = t.race AND p.class = t.class
SET g.map = p.map,
    g.position_x = p.position_x + 4 * COS(p.orientation),
    g.position_y = p.position_y + 4 * SIN(p.orientation),
    g.position_z = p.position_z,
    g.orientation = MOD(p.orientation + PI(), 2 * PI()),
    g.rotation0 = 0,
    g.rotation1 = 0,
    g.rotation2 = SIN(MOD(p.orientation + PI(), 2 * PI()) / 2),
    g.rotation3 = COS(MOD(p.orientation + PI(), 2 * PI()) / 2);

DROP TEMPORARY TABLE tmp_autels;
