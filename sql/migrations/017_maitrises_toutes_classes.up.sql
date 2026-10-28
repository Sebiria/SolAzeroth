-- Maîtrises d'armes et d'armures autorisées à toutes les races et classes (sections 3.7 et 3.9).
-- Sans ces lignes, le serveur efface à chaque connexion les compétences « interdites » par SkillRaceClassInfo.dbc
-- (ex. dagues ou ambidextrie pour un paladin) et les sorts qui les apprennent : les achats disparaissaient.
-- Lignes ajoutées par la table de surcharge skillraceclassinfo_dbc, masques race et classe à 0 = tout le monde ;
-- drapeaux, niveau et palier copiés de la ligne d'origine de chaque compétence.
USE acore_world;

INSERT INTO skillraceclassinfo_dbc (ID, SkillID, RaceMask, ClassMask, Flags, MinLevel, SkillTierID, SkillCostIndex) VALUES
    (900000, 43, 0, 0, 128, 0, 0, 0),
    (900001, 44, 0, 0, 128, 0, 0, 0),
    (900002, 45, 0, 0, 128, 0, 0, 0),
    (900003, 46, 0, 0, 128, 0, 0, 0),
    (900004, 54, 0, 0, 128, 0, 0, 0),
    (900005, 55, 0, 0, 128, 0, 0, 0),
    (900006, 95, 0, 0, 640, 0, 0, 0),
    (900007, 118, 0, 0, 146, 1, 0, 0),
    (900008, 136, 0, 0, 128, 0, 0, 0),
    (900009, 160, 0, 0, 128, 0, 0, 0),
    (900010, 162, 0, 0, 128, 0, 0, 0),
    (900011, 172, 0, 0, 128, 0, 0, 0),
    (900012, 173, 0, 0, 128, 0, 0, 0),
    (900013, 176, 0, 0, 128, 0, 0, 0),
    (900014, 226, 0, 0, 128, 0, 0, 0),
    (900015, 228, 0, 0, 128, 0, 0, 0),
    (900016, 229, 0, 0, 128, 20, 0, 0),
    (900017, 293, 0, 0, 128, 40, 0, 0),
    (900018, 413, 0, 0, 128, 40, 0, 0),
    (900019, 414, 0, 0, 128, 0, 0, 0),
    (900020, 415, 0, 0, 128, 0, 0, 0),
    (900021, 433, 0, 0, 128, 0, 0, 0),
    (900022, 473, 0, 0, 130, 0, 0, 0);
