-- Retour arrière de 052 : seules les capitales, Shattrath et Dalaran sont animées
USE acore_world;

DELETE FROM solazeroth_ambiance_lieux WHERE aire <> 0;
ALTER TABLE solazeroth_ambiance_lieux
    DROP PRIMARY KEY,
    DROP COLUMN aire,
    ADD PRIMARY KEY (carte, zone);
