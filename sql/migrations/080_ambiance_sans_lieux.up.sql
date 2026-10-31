-- Retrait des trajets de patrouille des monstres des lieux à nettoyer parmi les routes d'ambiance (migration 053).
-- Des voyageurs d'ambiance de l'Alliance se promenaient dans le fort de Tiragarde, Durotar (31/10/2026) : ils suivaient
-- le trajet d'un Fusilier de Kul Tiras, de faction 123, amicale envers l'Alliance. La faction ne suffit pas à trier
-- (d'autres PNJ de faction 123 sont de vrais gardes) : un monstre à éliminer pour nettoyer un lieu n'est jamais un garde.
USE acore_world;
DROP TABLE IF EXISTS solazeroth_ambiance_routes_lieux;
CREATE TABLE solazeroth_ambiance_routes_lieux AS
SELECT DISTINCT r.* FROM solazeroth_ambiance_routes r
JOIN creature_addon ca ON ca.path_id = r.chemin
JOIN creature c ON c.guid = ca.guid
WHERE c.id IN (SELECT creature FROM solazeroth_v3_lieux_monstres UNION SELECT origine FROM solazeroth_v3_lieux_chefs);
DELETE r FROM solazeroth_ambiance_routes r JOIN solazeroth_ambiance_routes_lieux l ON l.chemin = r.chemin;
