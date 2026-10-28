-- Prime de zone (section 6.1, contrats.cpp) : la cible nommée est-elle déjà tuée ?
USE acore_characters;

ALTER TABLE solazeroth_contrats ADD COLUMN cible_tuee TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'prime de zone : cible nommée tuée';
