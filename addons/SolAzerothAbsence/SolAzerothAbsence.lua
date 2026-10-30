-- Absence pour inactivité (demande de l'utilisateur du 28/10/2026). Le client passe seul en « Absent » après
-- 5 minutes sans action, puis demande la déconnexion au bout de 30 minutes. Le serveur refuse cette déconnexion
-- (PreventAFKLogout = 2 dans worldserver.conf), mais seulement si le personnage est marqué absent : on garde donc
-- la marque et on cache ici les messages qui l'annoncent. Toute demande de départ du joueur lève la marque avant (plus bas).

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
-- 30/10/2026). Toute façon de partir retire donc la marque d'abord, sans que le joueur ait à le savoir :
-- « Déconnexion » ou « Quitter » du menu dès que le bouton est enfoncé (la déconnexion part au relâchement), et les
-- commandes (/camp, /déco, /quitter…) dès qu'elles sont tapées, avant Entrée. Le serveur traite les deux dans l'ordre.
local derniereLevee = 0
local function LeverAbsence()
    -- « /AFK » bascule la marque : une seconde levée avant la réponse du serveur la remettrait.
    if UnitIsAFK("player") and GetTime() - derniereLevee > 3 then
        derniereLevee = GetTime()
        SendChatMessage("", "AFK")
    end
end
GameMenuButtonLogout:HookScript("OnMouseDown", LeverAbsence)
GameMenuButtonQuit:HookScript("OnMouseDown", LeverAbsence)

local COMMANDES = {}
for _, base in ipairs({ "SLASH_LOGOUT", "SLASH_QUIT" }) do
    local i = 1
    while _G[base .. i] do
        COMMANDES[strlower(_G[base .. i])] = true
        i = i + 1
    end
end
for i = 1, NUM_CHAT_WINDOWS do
    local saisie = _G["ChatFrame" .. i .. "EditBox"]
    if saisie then
        saisie:HookScript("OnTextChanged", function(self)
            local commande = strlower(self:GetText()):match("^%s*(/%S+)%s*$")
            if commande and COMMANDES[commande] then LeverAbsence() end
        end)
    end
end
