-- Pas de « Mal de résurrection » (sort 15007) après une résurrection par l'esprit guérisseur (demande de l'utilisateur, V2).
-- Le jeu l'applique juste après l'événement de résurrection : on le retire un instant plus tard.

local MAL_DE_RESURRECTION = 15007
local PLAYER_EVENT_ON_LOGIN = 3
local PLAYER_EVENT_ON_RESURRECT = 36

local function Retirer(player)
    if player:HasAura(MAL_DE_RESURRECTION) then
        player:RemoveAura(MAL_DE_RESURRECTION)
    end
end

local function OnResurrect(event, player)
    player:RegisterEvent(function(_, _, _, p) Retirer(p) end, 200, 1)
end

local function OnLogin(event, player)
    Retirer(player)
end

RegisterPlayerEvent(PLAYER_EVENT_ON_RESURRECT, OnResurrect)
RegisterPlayerEvent(PLAYER_EVENT_ON_LOGIN, OnLogin)
