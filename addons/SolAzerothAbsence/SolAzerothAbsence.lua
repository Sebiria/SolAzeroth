-- Absence pour inactivité (demande de l'utilisateur du 28/10/2026). Le client passe seul en « Absent » après
-- 5 minutes sans action, puis demande la déconnexion au bout de 30 minutes. Le serveur refuse cette déconnexion
-- (PreventAFKLogout = 2 dans worldserver.conf), mais seulement si le personnage est marqué absent : on garde donc
-- la marque et on cache ici les messages qui l'annoncent. Déconnexion et Quitter du menu lèvent la marque avant de partir.

local function Motif(modele)
    return "^" .. modele:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%%%s", ".*") .. "$"
end

local MOTIFS = { Motif(MARKED_AFK), Motif(MARKED_AFK_MESSAGE), Motif(CLEARED_AFK) }

ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", function(_, _, message)
    for _, m in ipairs(MOTIFS) do
        if message:find(m) then return true end
    end
end)

-- Le serveur refuse aussi la déconnexion demandée par le joueur quand il est absent (retour de l'utilisateur du
-- 30/10/2026). Appuyer sur « Déconnexion » ou « Quitter » retire donc la marque d'abord : le bouton enfoncé envoie
-- la levée de l'absence, le clic relâché envoie la déconnexion, et le serveur les traite dans cet ordre.
local function LeverAbsence()
    if UnitIsAFK("player") then SendChatMessage("", "AFK") end
end
GameMenuButtonLogout:HookScript("OnMouseDown", LeverAbsence)
GameMenuButtonQuit:HookScript("OnMouseDown", LeverAbsence)
