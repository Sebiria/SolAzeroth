-- v3 : plat choisi dans le bouton de repas (SolUI_Bivouac.lua), gardé d'une session à l'autre (v3_bivouac.cpp).
ALTER TABLE acore_characters.solazeroth_v3_bivouac ADD COLUMN repas INT UNSIGNED NOT NULL DEFAULT 0;
