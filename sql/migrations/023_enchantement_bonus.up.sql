-- Enchantement de bonus (section 4.5, bonus.cpp) : rang mémorisé avec chaque choix de butin et chaque objet obtenu.
USE acore_characters;

ALTER TABLE solazeroth_butin_attente ADD COLUMN rang TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'rang de menace à la mort du boss';

CREATE TABLE IF NOT EXISTS solazeroth_objets_rang (
    item_guid     INT UNSIGNED     NOT NULL PRIMARY KEY,
    rang          TINYINT UNSIGNED NOT NULL COMMENT 'niveau d''objet effectif = niveau d''origine + rang (section 5.1)',
    enchantement  INT UNSIGNED     NOT NULL COMMENT 'SpellItemEnchantment posé dans PROP_ENCHANTMENT_SLOT_0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
