-- Retrait des trajets de patrouille des monstres hostiles parmi les routes d'ambiance (migration 053). Des voyageurs
-- d'ambiance se promenaient dans la grotte de la Lame ardente, vallée des Épreuves (31/10/2026) : ils suivaient les
-- trajets des Familiers vils, de faction 7 (« Creature »), pris à tort pour des PNJ non hostiles. Même cas pour les
-- factions 15, 34, 122, 189 et 2107 (Défias, sangliers-épines, géants, mineurs de Bael'dun…).
USE acore_world;
DROP TABLE IF EXISTS solazeroth_ambiance_routes_hostiles;
CREATE TABLE solazeroth_ambiance_routes_hostiles AS
SELECT DISTINCT r.* FROM solazeroth_ambiance_routes r
JOIN creature_addon ca ON ca.path_id = r.chemin
JOIN creature c ON c.guid = ca.guid
JOIN creature_template ct ON ct.entry = c.id
WHERE ct.faction IN (7, 15, 34, 122, 189, 2107);
DELETE r FROM solazeroth_ambiance_routes r JOIN solazeroth_ambiance_routes_hostiles h ON h.chemin = r.chemin;
