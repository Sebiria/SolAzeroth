-- Hauts faits du compte (section 7.4, V4, hauts_faits.cpp) : définitions, compteurs et hauts faits obtenus.
-- Les 50 premiers donnent chacun un point de talent (validés par l'utilisateur le 27/10/2026).
-- Critères : 1 donjons (liste d'identifiants LFGDungeons ; valeur = rang de menace minimal ; quantité = nombre requis)
--            2 compteur (liste = clé du compteur ; quantité = seuil)
--            3 haut fait natif obtenu par un personnage du compte (valeur = identifiant Achievement.dbc)
--            4 métiers (liste de compétences ; valeur = niveau minimal ; quantité = nombre de métiers requis)
--            5 sort connu par un personnage du compte (valeur = sort)
-- Catégories : 1 Donjons, 2 Défis de boss, 3 Défi extérieur, 4 Contrats, 5 Métiers, 6 Monde, 7 Exploits.
USE acore_world;

CREATE TABLE IF NOT EXISTS solazeroth_hauts_faits (
    id           INT UNSIGNED     NOT NULL PRIMARY KEY,
    categorie    TINYINT UNSIGNED NOT NULL,
    nom          VARCHAR(100)     NOT NULL,
    description  VARCHAR(255)     NOT NULL,
    critere      TINYINT UNSIGNED NOT NULL,
    valeur       INT UNSIGNED     NOT NULL DEFAULT 0,
    quantite     INT UNSIGNED     NOT NULL DEFAULT 1,
    liste        VARCHAR(255)     NOT NULL DEFAULT '',
    talent       TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '1 = donne un point de talent'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO solazeroth_hauts_faits (id, categorie, nom, description, critere, valeur, quantite, liste, talent) VALUES
-- Donjons
( 1, 1, 'Gouffre de Ragefeu', 'Finir le Gouffre de Ragefeu au rang de menace 3.', 1, 3, 1, '4', 1),
( 2, 1, 'Les Mortemines', 'Finir les Mortemines au rang de menace 3.', 1, 3, 1, '6', 1),
( 3, 1, 'Cavernes des lamentations', 'Finir les Cavernes des lamentations au rang de menace 3.', 1, 3, 1, '1', 1),
( 4, 1, 'Donjon d''Ombrecroc', 'Finir le donjon d''Ombrecroc au rang de menace 4.', 1, 4, 1, '8', 1),
( 5, 1, 'Monastère écarlate', 'Finir les quatre ailes du Monastère écarlate au rang de menace 3.', 1, 3, 4, '18,163,164,165', 1),
( 6, 1, 'Gnomeregan', 'Finir Gnomeregan au rang de menace 4.', 1, 4, 1, '14', 1),
( 7, 1, 'Uldaman', 'Finir Uldaman au rang de menace 5.', 1, 5, 1, '22', 1),
( 8, 1, 'Zul''Farrak', 'Finir Zul''Farrak au rang de menace 5.', 1, 5, 1, '24', 1),
( 9, 1, 'Maraudon', 'Finir Maraudon au rang de menace 5.', 1, 5, 1, '26,272,273', 1),
(10, 1, 'Temple englouti', 'Finir le Temple englouti au rang de menace 5.', 1, 5, 1, '28', 1),
(11, 1, 'Profondeurs de Rochenoire', 'Finir les Profondeurs de Rochenoire au rang de menace 5.', 1, 5, 1, '30,276', 1),
(12, 1, 'Stratholme', 'Finir Stratholme au rang de menace 5.', 1, 5, 1, '40,274', 1),
(13, 1, 'Scholomance', 'Finir la Scholomance au rang de menace 5.', 1, 5, 1, '2', 1),
(14, 1, 'Bas du pic Rochenoire', 'Finir le Bas du pic Rochenoire au rang de menace 5.', 1, 5, 1, '32', 1),
(15, 1, 'Hache-tripes', 'Finir une aile de Hache-tripes au rang de menace 5.', 1, 5, 1, '34,36,38', 1),
(16, 1, 'Héros de l''Outreterre', 'Finir 5 donjons différents d''Outreterre au rang de menace 5.', 1, 5, 5, '136,137,138,140,146,147,148,149,150,151,170,171,172,173,174,198', 1),
(17, 1, 'Héros du Norfendre', 'Finir 5 donjons différents du Norfendre au rang de menace 5.', 1, 5, 5, '202,203,204,206,207,208,209,214,216,218,220,225,245,251,253,255', 1),
(18, 1, 'Conquérant du Norfendre', 'Finir tous les donjons du Norfendre au rang de menace 3.', 1, 3, 16, '202,203,204,206,207,208,209,214,216,218,220,225,245,251,253,255', 1),
-- Défis de boss
(19, 2, 'Défis de boss I', 'Réussir 10 défis de boss.', 2, 0, 10, 'defis_boss', 1),
(20, 2, 'Défis de boss II', 'Réussir 25 défis de boss.', 2, 0, 25, 'defis_boss', 1),
(21, 2, 'Défis de boss III', 'Réussir 40 défis de boss.', 2, 0, 40, 'defis_boss', 1),
(22, 2, 'Défis de boss IV', 'Réussir 200 défis de boss.', 2, 0, 200, 'defis_boss', 1),
(23, 2, 'Sans filet', 'Réussir 50 défis « Sans filet ».', 2, 0, 50, 'defis_sans_filet', 1),
-- Défi extérieur
(24, 3, 'Aventurier aguerri I', 'Rendre 50 quêtes en défi extérieur de niveau 3 ou plus.', 2, 0, 50, 'quetes_defi3', 1),
(25, 3, 'Aventurier aguerri II', 'Rendre 150 quêtes en défi extérieur de niveau 3 ou plus.', 2, 0, 150, 'quetes_defi3', 1),
(26, 3, 'Aventurier aguerri III', 'Rendre 500 quêtes en défi extérieur de niveau 3 ou plus.', 2, 0, 500, 'quetes_defi3', 1),
(27, 3, 'Chasseur intrépide I', 'Tuer 300 monstres de son niveau en défi extérieur de niveau 5.', 2, 0, 300, 'tues_defi5', 1),
(28, 3, 'Chasseur intrépide II', 'Tuer 1 000 monstres de son niveau en défi extérieur de niveau 5.', 2, 0, 1000, 'tues_defi5', 1),
-- Contrats
(29, 4, 'Premières chasses', 'Remplir 5 contrats de chasse.', 2, 0, 5, 'chasses', 1),
(30, 4, 'Contractuel I', 'Remplir 15 contrats.', 2, 0, 15, 'contrats', 1),
(31, 4, 'Contractuel II', 'Remplir 40 contrats.', 2, 0, 40, 'contrats', 1),
(32, 4, 'Contractuel III', 'Remplir 100 contrats.', 2, 0, 100, 'contrats', 1),
(33, 4, 'Chasseur de primes I', 'Abattre 3 cibles de prime de zone.', 2, 0, 3, 'primes', 1),
(34, 4, 'Chasseur de primes II', 'Abattre 10 cibles de prime de zone.', 2, 0, 10, 'primes', 1),
(35, 4, 'Chasseur de primes III', 'Abattre 25 cibles de prime de zone.', 2, 0, 25, 'primes', 1),
-- Métiers
(36, 5, 'Apprenti confirmé', 'Monter un métier principal à 150.', 4, 150, 1, '164,165,171,182,186,197,202,333,393,755,773', 1),
(37, 5, 'Double savoir-faire', 'Monter deux métiers principaux à 225.', 4, 225, 2, '164,165,171,182,186,197,202,333,393,755,773', 1),
(38, 5, 'Artisan', 'Monter deux métiers principaux à 300.', 4, 300, 2, '164,165,171,182,186,197,202,333,393,755,773', 1),
(39, 5, 'Maître artisan', 'Monter deux métiers principaux à 375.', 4, 375, 2, '164,165,171,182,186,197,202,333,393,755,773', 1),
(40, 5, 'Touche-à-tout', 'Monter la cuisine, le secourisme et la pêche à 300.', 4, 300, 3, '185,129,356', 1),
(41, 5, 'Grand maître de tout', 'Monter tous les métiers principaux et secondaires à 450.', 4, 450, 14, '164,165,171,182,186,197,202,333,393,755,773,185,129,356', 1),
-- Monde (hauts faits natifs)
(42, 6, 'Exploration de Kalimdor', 'Obtenir le haut fait « Exploration de Kalimdor » avec un personnage.', 3, 43, 1, '', 1),
(43, 6, 'Exploration des Royaumes de l''est', 'Obtenir le haut fait « Exploration des Royaumes de l''est » avec un personnage.', 3, 42, 1, '', 1),
(44, 6, 'Exploration de l''Outreterre', 'Obtenir le haut fait « Exploration de l''Outreterre » avec un personnage.', 3, 44, 1, '', 1),
(45, 6, 'Exploration du Norfendre', 'Obtenir le haut fait « Exploration du Norfendre » avec un personnage.', 3, 45, 1, '', 1),
(46, 6, 'Ami de tous', 'Obtenir le haut fait « 10 réputations exaltées » avec un personnage.', 3, 524, 1, '', 1),
-- Exploits
(47, 7, 'Survivant', 'Atteindre le niveau 40 avec un personnage Hardcore.', 2, 0, 1, 'hardcore_40', 1),
(48, 7, 'Destrier de la mort', 'Obtenir la monture du baron Rivendare (Stratholme).', 5, 17481, 1, '', 1),
(49, 7, 'Karazhan', 'Vaincre le prince Malchezaar à Karazhan.', 2, 0, 1, 'boss_15690', 1),
(50, 7, 'Le Roi-liche', 'Vaincre le Roi-liche à la citadelle de la Couronne de glace.', 2, 0, 1, 'boss_36597', 1);

USE acore_characters;

CREATE TABLE IF NOT EXISTS solazeroth_compteurs (
    account  INT UNSIGNED NOT NULL,
    cle      VARCHAR(32)  NOT NULL,
    valeur   INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (account, cle)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS solazeroth_hf_obtenus (
    account  INT UNSIGNED NOT NULL,
    hf       INT UNSIGNED NOT NULL,
    date     INT UNSIGNED NOT NULL COMMENT 'horodatage Unix',
    PRIMARY KEY (account, hf)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
