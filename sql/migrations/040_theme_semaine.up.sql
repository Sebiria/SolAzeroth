-- Thème de la semaine (section 6.1, V5 ; décision de l'utilisateur du 30/10/2026 : à la semaine plutôt qu'au mois).
-- Chaque semaine, un thème = une famille de monstres + un métier, pris dans l'ordre de cette table (tour à tour).
-- Les contrats qui collent au thème sont mis en tête de liste et rapportent plus de Marques (contrats.cpp).
-- Familles (creature_template.type) : 1 Bêtes, 2 Draconiens, 3 Démons, 4 Élémentaires, 5 Géants, 6 Morts-vivants,
-- 7 Humanoïdes, 9 Mécaniques. Métiers (SkillLine) : 164 Forge, 165 Travail du cuir, 171 Alchimie, 197 Couture,
-- 202 Ingénierie, 333 Enchantement, 755 Joaillerie, 773 Calligraphie.
USE acore_world;

CREATE TABLE IF NOT EXISTS solazeroth_themes (
    ordre       TINYINT UNSIGNED  NOT NULL PRIMARY KEY,
    nom         VARCHAR(60)       NOT NULL,
    famille     TINYINT UNSIGNED  NOT NULL,
    metier      SMALLINT UNSIGNED NOT NULL,
    description VARCHAR(255)      NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO solazeroth_themes (ordre, nom, famille, metier, description) VALUES
(1, 'La grande traque',      1, 165, 'Les bêtes sauvages pullulent et les tanneurs manquent de cuir.'),
(2, 'L''ombre du Fléau',     6, 171, 'Les morts se relèvent : les alchimistes préparent remèdes et huiles saintes.'),
(3, 'Les portes de la Légion', 3, 333, 'Des démons franchissent le voile ; les enchanteurs renforcent les défenses.'),
(4, 'Les éléments déchaînés', 4, 755, 'Les élémentaires s''agitent, et leurs gemmes attirent les joailliers.'),
(5, 'Le pas des géants',     5, 164, 'Les géants descendent des montagnes : les forgerons ont du travail.'),
(6, 'Bandits et renégats',   7, 197, 'Les routes ne sont plus sûres ; les tailleurs habillent les patrouilles.'),
(7, 'Le vol des dragons',    2, 773, 'Les draconiens se montrent ; les scribes copient les anciens savoirs.'),
(8, 'La révolte des machines', 9, 202, 'Des machines s''emballent : les ingénieurs sont appelés en renfort.');

USE acore_characters;

ALTER TABLE solazeroth_contrats ADD COLUMN theme TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'contrat pris au thème de la semaine (Marques en plus)';
