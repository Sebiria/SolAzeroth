-- v3 (31/10/2026, décision de l'utilisateur) : plus aucune fête ni aucun événement de saison.
-- Les événements retirés ne démarrent plus jamais (leurs PNJ, décors et quêtes n'apparaissent plus), et toutes les
-- quêtes de fête sont retirées par la table disables. Restent les événements qui ne sont pas des fêtes (appels aux
-- armes des champs de bataille, cycles de jour et de nuit, cloches, joutes du Tournoi d'argent…).
USE acore_world;

-- Fêtes du calendrier, foire de Sombrelune, Nouvel an, cadeaux du Voile d'hiver, bière du mois, concours de pêche et
-- poissons de saison.
CREATE TABLE IF NOT EXISTS solazeroth_v3_fetes_origine SELECT * FROM game_event WHERE eventEntry IN
    (1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 14, 15, 23, 24, 26, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45,
     50, 51, 52, 62, 63, 64, 70, 71, 72, 77, 78, 90, 91);
UPDATE game_event e JOIN solazeroth_v3_fetes_origine o ON o.eventEntry = e.eventEntry
    SET e.holiday = 0, e.holidayStage = 0, e.start_time = '2000-01-01 14:00:00', e.end_time = '2000-01-01 14:00:00';

-- Quêtes de fête : catégories de fête (Saisonnier, Sombrelune, fête lunaire, solstice, Fête des Brasseurs, jardin
-- des Nobles, Bienfaits du pèlerin, De l'amour dans l'air, Semaine des enfants, Jour des morts) et quêtes liées aux
-- événements retirés.
INSERT IGNORE INTO disables (sourceType, entry, flags, params_0, params_1, comment)
SELECT 1, ID, 0, '', '', 'Sol''Azeroth v3 : quete de fete' FROM quest_template
WHERE QuestSortID IN (-22, -41, -284, -364, -366, -369, -370, -374, -375, -376)
   OR ID IN (SELECT questId FROM game_event_seasonal_questrelation WHERE eventEntry IN (SELECT eventEntry FROM solazeroth_v3_fetes_origine))
   OR ID IN (SELECT quest FROM game_event_creature_quest WHERE eventEntry IN (SELECT eventEntry FROM solazeroth_v3_fetes_origine))
   OR ID IN (SELECT quest FROM game_event_gameobject_quest WHERE eventEntry IN (SELECT eventEntry FROM solazeroth_v3_fetes_origine));
