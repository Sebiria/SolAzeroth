-- Absence pour inactivité (demande de l'utilisateur du 28/10/2026). Le client passe seul en « Absent » après
-- 5 minutes sans action, puis demande la déconnexion au bout de 30 minutes. Le serveur refuse cette déconnexion
-- (PreventAFKLogout = 2 dans worldserver.conf), mais seulement si le personnage est marqué absent : on garde donc
-- la marque et on cache ici les messages qui l'annoncent.

local function Motif(modele)
    return "^" .. modele:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%%%s", ".*") .. "$"
end

local MOTIFS = { Motif(MARKED_AFK), Motif(MARKED_AFK_MESSAGE), Motif(CLEARED_AFK) }

ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", function(_, _, message)
    for _, m in ipairs(MOTIFS) do
        if message:find(m) then return true end
    end
end)
