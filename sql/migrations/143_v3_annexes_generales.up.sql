-- Lot T4 des Tarides (03/11/2026) : v3_annexes.cpp en tables. Lignes de Durotar seulement (valeurs du code).
-- Généré par outils\annexes_durotar.py generales : ne pas modifier à la main.
USE acore_world;
ALTER TABLE solazeroth_v3_annexes ADD COLUMN zone INT UNSIGNED NOT NULL DEFAULT 14;
ALTER TABLE solazeroth_v3_reliques ADD COLUMN zone INT UNSIGNED NOT NULL DEFAULT 14;
ALTER TABLE solazeroth_v3_vagues ADD COLUMN epreuve INT UNSIGNED NOT NULL DEFAULT 1 FIRST, ADD COLUMN puissance TINYINT UNSIGNED NOT NULL DEFAULT 0, DROP PRIMARY KEY, ADD PRIMARY KEY (epreuve, vague, creature);

-- Épreuves de vagues : gardien, quêtes, crédits de mi-parcours et de fin.
CREATE TABLE solazeroth_v3_epreuves (epreuve INT UNSIGNED NOT NULL PRIMARY KEY, pnj INT UNSIGNED NOT NULL, zone INT UNSIGNED NOT NULL, quete INT UNSIGNED NOT NULL, quete2 INT UNSIGNED NOT NULL, credit_mi INT UNSIGNED NOT NULL, vague_mi TINYINT UNSIGNED NOT NULL, credit_fin INT UNSIGNED NOT NULL, nom VARCHAR(64) NOT NULL, consigne VARCHAR(128) NOT NULL);
INSERT INTO solazeroth_v3_epreuves VALUES (1, 910023, 14, 910227, 910327, 910026, 5, 910028, 'Épreuve des esprits', 'Ne t''éloigne pas du rocher.');

-- Renforts des objets du monde, pendant leurs quêtes (puissance 0 : celle de l'entrée, comme avant).
CREATE TABLE solazeroth_v3_renforts (objet_monde INT UNSIGNED NOT NULL PRIMARY KEY, creature INT UNSIGNED NOT NULL, nombre TINYINT UNSIGNED NOT NULL, quetes VARCHAR(64) NOT NULL, puissance TINYINT UNSIGNED NOT NULL);
INSERT INTO solazeroth_v3_renforts VALUES (3240, 3122, 2, '910222,910522', 0), (102986, 3207, 1, '910224,910524', 0);

-- Bonus des familles de reliques et carte des reliques, par zone.
CREATE TABLE solazeroth_v3_reliques_familles (famille TINYINT UNSIGNED NOT NULL PRIMARY KEY, zone INT UNSIGNED NOT NULL, nom VARCHAR(64) NOT NULL, objet INT UNSIGNED NOT NULL, cuivre INT UNSIGNED NOT NULL, composant INT UNSIGNED NOT NULL, nombre INT UNSIGNED NOT NULL);
INSERT INTO solazeroth_v3_reliques_familles VALUES (0, 14, 'Lame ardente', 910131, 0, 0, 0), (1, 14, 'Kul Tiras', 0, 30000, 1210, 2), (2, 14, 'Sombrelances', 910132, 0, 0, 0);
CREATE TABLE solazeroth_v3_reliques_cartes (zone INT UNSIGNED NOT NULL PRIMARY KEY, marques INT UNSIGNED NOT NULL, cuivre INT UNSIGNED NOT NULL, seuil INT UNSIGNED NOT NULL);
INSERT INTO solazeroth_v3_reliques_cartes VALUES (14, 30, 20000, 8);

-- Techniques sans SmartAI. Genres : 1 carapace (a : % des dégâts gardés, b : ms après un étourdissement) ;
-- 2 flaque à la mort (a : dix-millièmes de vie par 500 ms, b : durée, sort) ; 3 zone marquée (quête, a : délai,
-- b : frappe après, c : dix-millièmes de vie, sort, creature2 : aura du marqueur) ; 4 frères d'armes (a : m,
-- b : % en moins, creature2) ; 5 renvoi (a : % des coups de mêlée) ; 6 rage voisine (a : m, b : % par mort,
-- c : cumul) ; 7 mur répété (a : délai, b : durée, sort) ; 8 sable grouillant (quête, a : délai, b : puissance,
-- creature2).
CREATE TABLE solazeroth_v3_techniques (creature INT UNSIGNED NOT NULL, genre TINYINT UNSIGNED NOT NULL, quete INT UNSIGNED NOT NULL, a INT UNSIGNED NOT NULL, b INT UNSIGNED NOT NULL, c INT UNSIGNED NOT NULL, sort INT UNSIGNED NOT NULL, creature2 INT UNSIGNED NOT NULL, PRIMARY KEY (creature, genre));
INSERT INTO solazeroth_v3_techniques VALUES (3141, 1, 0, 50, 6000, 0, 0, 0), (3225, 2, 0, 300, 6000, 0, 26573, 0), (3226, 2, 0, 300, 6000, 0, 26573, 0), (3227, 2, 0, 300, 6000, 0, 26573, 0), (3228, 2, 0, 300, 6000, 0, 26573, 0), (3203, 3, 910229, 8000, 2500, 2000, 403, 20545);

-- Records d'épreuve et cartes achetées, par épreuve et par zone (recopiés de solazeroth_v3_annexes_joueur).
CREATE TABLE IF NOT EXISTS acore_characters.solazeroth_v3_epreuves_joueur (guid INT UNSIGNED NOT NULL, epreuve INT UNSIGNED NOT NULL, vague TINYINT UNSIGNED NOT NULL DEFAULT 0, temps INT UNSIGNED NOT NULL DEFAULT 0, jour INT UNSIGNED NOT NULL DEFAULT 0, PRIMARY KEY (guid, epreuve));
INSERT IGNORE INTO acore_characters.solazeroth_v3_epreuves_joueur SELECT guid, 1, vague, temps, jour FROM acore_characters.solazeroth_v3_annexes_joueur WHERE vague > 0 OR jour > 0;
CREATE TABLE IF NOT EXISTS acore_characters.solazeroth_v3_reliques_cartes_joueur (guid INT UNSIGNED NOT NULL, zone INT UNSIGNED NOT NULL, PRIMARY KEY (guid, zone));
INSERT IGNORE INTO acore_characters.solazeroth_v3_reliques_cartes_joueur SELECT guid, 14 FROM acore_characters.solazeroth_v3_annexes_joueur WHERE carte = 1;
