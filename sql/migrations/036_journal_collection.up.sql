-- Journal de collection (section 7.3, V4 étape 5, journal_collection.cpp) : une case par objet de chaque boss.
-- Cases : objets propres à chaque boss de rencontre (instance_encounters), toutes difficultés comprises, tirés de sa
-- table de butin et des réserves qui lui sont propres (réserve partagée par 4 tables de butin au plus : on écarte
-- les réserves du monde). Objets gardés : armes, armures, recettes et divers de qualité rare ou mieux, plus les
-- montures et mascottes. Calculé une fois ici (5 355 objets, 393 boss au 28/10/2026).
-- Collection du compte : solazeroth_collection (objet obtenu sur le corps d'un boss, par le choix de butin, ou par les
-- Éclats ; pas les achats chez l'intendant).
USE acore_world;

CREATE TABLE IF NOT EXISTS solazeroth_journal (
    boss INT UNSIGNED NOT NULL,
    item INT UNSIGNED NOT NULL,
    PRIMARY KEY (boss, item),
    KEY (item)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TEMPORARY TABLE tmp_boss AS
    SELECT DISTINCT e.creditEntry AS boss, t.lootid
    FROM instance_encounters e
    JOIN creature_template t ON t.entry IN (
        SELECT e.creditEntry
        UNION SELECT difficulty_entry_1 FROM creature_template WHERE entry = e.creditEntry
        UNION SELECT difficulty_entry_2 FROM creature_template WHERE entry = e.creditEntry
        UNION SELECT difficulty_entry_3 FROM creature_template WHERE entry = e.creditEntry)
    WHERE e.creditType = 0 AND t.lootid <> 0;

CREATE TEMPORARY TABLE tmp_reserves AS
    SELECT Reference AS reserve, COUNT(DISTINCT Entry) AS tables_butin
    FROM creature_loot_template WHERE Reference <> 0 GROUP BY Reference;

CREATE TEMPORARY TABLE tmp_objets (boss INT UNSIGNED, item INT UNSIGNED);
-- Objets directs
INSERT INTO tmp_objets SELECT b.boss, l.Item FROM tmp_boss b
    JOIN creature_loot_template l ON l.Entry = b.lootid WHERE l.Reference = 0;
-- Réserves propres au boss
INSERT INTO tmp_objets SELECT b.boss, r.Item FROM tmp_boss b
    JOIN creature_loot_template l ON l.Entry = b.lootid
    JOIN tmp_reserves x ON x.reserve = l.Reference AND x.tables_butin <= 4
    JOIN reference_loot_template r ON r.Entry = l.Reference WHERE r.Reference = 0;
-- Réserves imbriquées dans ces réserves
INSERT INTO tmp_objets SELECT b.boss, r2.Item FROM tmp_boss b
    JOIN creature_loot_template l ON l.Entry = b.lootid
    JOIN tmp_reserves x ON x.reserve = l.Reference AND x.tables_butin <= 4
    JOIN reference_loot_template r ON r.Entry = l.Reference
    JOIN reference_loot_template r2 ON r2.Entry = r.Reference WHERE r.Reference <> 0 AND r2.Reference = 0;

INSERT IGNORE INTO solazeroth_journal (boss, item)
    SELECT DISTINCT o.boss, o.item FROM tmp_objets o JOIN item_template t ON t.entry = o.item
    WHERE (t.Quality >= 3 AND t.class IN (2, 4, 9, 15)) OR (t.class = 15 AND t.subclass IN (2, 5));

DROP TEMPORARY TABLE tmp_boss;
DROP TEMPORARY TABLE tmp_reserves;
DROP TEMPORARY TABLE tmp_objets;

USE acore_characters;

CREATE TABLE IF NOT EXISTS solazeroth_collection (
    account INT UNSIGNED NOT NULL,
    item    INT UNSIGNED NOT NULL,
    date    INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (account, item)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
