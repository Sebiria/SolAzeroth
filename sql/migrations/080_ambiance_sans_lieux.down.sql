-- Rend les trajets retirés par la migration 080.
USE acore_world;
INSERT IGNORE INTO solazeroth_ambiance_routes SELECT * FROM solazeroth_ambiance_routes_lieux;
DROP TABLE solazeroth_ambiance_routes_lieux;
