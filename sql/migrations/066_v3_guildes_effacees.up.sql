-- Sol'Azeroth v3, F5d (31/10/2026) : plus de guildes (demande de l'utilisateur). Les « Coffres de <nom> » de la V2
-- (banque de compte par la banque de guilde) sont effacés ; leurs banques étaient vides. Sans guilde, un personnage
-- se supprime de nouveau depuis l'écran de choix.
USE acore_characters;
DELETE FROM guild_bank_item;
DELETE FROM guild_bank_eventlog;
DELETE FROM guild_bank_right;
DELETE FROM guild_bank_tab;
DELETE FROM guild_eventlog;
DELETE FROM guild_member_withdraw;
DELETE FROM guild_member;
DELETE FROM guild_rank;
DELETE FROM guild;
DELETE FROM solazeroth_banque_compte;
