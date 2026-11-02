-- Version publique (02/11/2026) : export des signalements vers un fichier .txt par le lanceur (v3_signalement.cpp,
-- scripts\signalements.ps1). exporte = 1 : déjà exporté (installation de développement ; ailleurs, la ligne est
-- supprimée). classe et nom_lieu rendent le fichier lisible sans la base.
ALTER TABLE acore_characters.solazeroth_v3_signalements
    ADD COLUMN classe TINYINT UNSIGNED NOT NULL DEFAULT 0 AFTER niveau,
    ADD COLUMN nom_lieu VARCHAR(160) NOT NULL DEFAULT '' AFTER lieu,
    ADD COLUMN exporte TINYINT UNSIGNED NOT NULL DEFAULT 0;
