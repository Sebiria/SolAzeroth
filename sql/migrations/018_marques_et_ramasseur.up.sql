-- Monnaie « Marque du voyageur » (section 7.5), achats de compte et mascotte ramasseuse (marques.cpp, ramasseur.cpp)
USE acore_world;

-- Objet 900100 : Marque du voyageur, copiée de l'Insigne de justice (même icône), rangée dans les sacs
-- (pas dans l'onglet Monnaie, qui demande le patch client de V7), empilable par 5000.
CREATE TEMPORARY TABLE tmp_marque SELECT * FROM item_template WHERE entry = 29434;
UPDATE tmp_marque SET entry = 900100, name = 'Marque du voyageur', description = 'Monnaie de Sol''Azeroth.',
    BagFamily = 0, stackable = 5000, maxcount = 0, bonding = 0, SellPrice = 0;
INSERT INTO item_template SELECT * FROM tmp_marque;
DROP TEMPORARY TABLE tmp_marque;

-- La Bombinette (mascotte 9656) prend l'apparence de l'Alarme-bombe 2600 de Gnomeregan.
CREATE TABLE solazeroth_bak018_bombinette AS SELECT * FROM creature_template_model WHERE CreatureID = 9656;
CREATE TABLE solazeroth_bak018_bombinette_nom AS SELECT * FROM creature_template_locale WHERE entry = 9656;
UPDATE creature_template_model SET CreatureDisplayID = 6888 WHERE CreatureID = 9656 AND Idx = 0;
REPLACE INTO creature_template_locale (entry, locale, Name, Title, VerifiedBuild)
    VALUES (9656, 'frFR', 'Alarme-bombe ramasseuse', '', 0);

USE acore_characters;

CREATE TABLE IF NOT EXISTS solazeroth_compte_achats (
    account  INT UNSIGNED     NOT NULL,
    achat    VARCHAR(32)      NOT NULL COMMENT 'ex. ramasseur',
    le       DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (account, achat)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
