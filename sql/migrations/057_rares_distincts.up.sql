-- Élites rares du Codex comptées par créature différente (calibrage final, 29/10/2026), alimentée par codex.cpp.
USE acore_characters;

CREATE TABLE IF NOT EXISTS solazeroth_rares_tues (
    account  INT UNSIGNED NOT NULL,
    entry    INT UNSIGNED NOT NULL COMMENT 'creature_template.entry',
    PRIMARY KEY (account, entry)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
