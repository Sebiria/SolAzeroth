-- Rend les trajets retirés par la migration 071.
USE acore_world;
INSERT IGNORE INTO solazeroth_ambiance_routes SELECT * FROM solazeroth_ambiance_routes_hostiles;
DROP TABLE solazeroth_ambiance_routes_hostiles;
