-- Mesure du temps par activité (section 6.4)
-- Chaque minute, ajoute 1 minute à l'activité en cours de chaque joueur connecté.
-- Les donjons seront détaillés par rang de menace en V2.

local INTERVALLE = 60 * 1000

local function Activite(player)
    local map = player:GetMap()
    if map:IsRaid() then return "raid" end
    if map:IsDungeon() then return "donjon" end
    if map:IsArena() then return "arene" end
    if map:IsBattleground() then return "champ_bataille" end
    return "monde"
end

local function Compter()
    for _, player in ipairs(GetPlayersInWorld()) do
        CharDBExecute(string.format(
            "INSERT INTO solazeroth_temps_activite (guid, jour, activite, map_id, minutes) " ..
            "VALUES (%d, CURDATE(), '%s', %d, 1) ON DUPLICATE KEY UPDATE minutes = minutes + 1",
            player:GetGUIDLow(), Activite(player), player:GetMapId()))
    end
end

CreateLuaEvent(Compter, INTERVALLE, 0)
