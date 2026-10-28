-- Sauvegardes Sol'Azeroth (V0)
-- .sauvegarder          -> demande une sauvegarde immédiate
-- .sauvegarder 15       -> règle l'intervalle automatique (5, 10, 15, 30 ou 60 minutes)
-- .sauvegarder ?        -> affiche l'intervalle actuel
-- Le lanceur lit les fichiers du dossier runtime et fait la sauvegarde.

local RUNTIME = "C:/SolAzeroth/runtime/"
local FICHIER_DEMANDE = RUNTIME .. "save_request.flag"
local FICHIER_INTERVALLE = RUNTIME .. "save_interval.txt"
local FICHIER_RESULTAT = RUNTIME .. "save_done.txt"
local INTERVALLE_DEFAUT = 15
local INTERVALLES = { [5] = true, [10] = true, [15] = true, [30] = true, [60] = true }

local PLAYER_EVENT_ON_COMMAND = 42

local function LireIntervalle()
    local f = io.open(FICHIER_INTERVALLE, "r")
    if not f then return INTERVALLE_DEFAUT end
    local valeur = tonumber(f:read("*l"))
    f:close()
    return valeur or INTERVALLE_DEFAUT
end

local function EcrireFichier(chemin, contenu)
    local f = io.open(chemin, "w")
    if not f then return false end
    f:write(contenu)
    f:close()
    return true
end

local function Repondre(player, message)
    if player then
        player:SendBroadcastMessage(message)
    else
        print(message)
    end
end

local function OnCommand(event, player, command)
    local texte = command:gsub("^[%.!]", "")
    local nom, argument = texte:match("^(%S+)%s*(%S*)")
    if not nom or nom:lower() ~= "sauvegarder" then
        return
    end

    if argument == "" then
        if EcrireFichier(FICHIER_DEMANDE, os.date("%Y-%m-%d %H:%M:%S")) then
            Repondre(player, "Sauvegarde demandée...")
        else
            Repondre(player, "|cffff0000Sauvegarde impossible :|r le dossier " .. RUNTIME .. " est introuvable.")
        end
    elseif argument == "?" then
        Repondre(player, "Sauvegarde automatique toutes les " .. LireIntervalle() .. " minutes.")
    else
        local minutes = tonumber(argument)
        if minutes and INTERVALLES[minutes] then
            EcrireFichier(FICHIER_INTERVALLE, tostring(minutes))
            Repondre(player, "Sauvegarde automatique réglée sur " .. minutes .. " minutes.")
        else
            Repondre(player, "Intervalles possibles : 5, 10, 15, 30 ou 60 minutes. Exemple : .sauvegarder 15")
        end
    end
    return false
end

-- Le lanceur écrit le résultat de la sauvegarde manuelle : on prévient les joueurs connectés.
local function VerifierResultat()
    local f = io.open(FICHIER_RESULTAT, "r")
    if not f then return end
    local resultat = f:read("*l")
    f:close()
    os.remove(FICHIER_RESULTAT)

    local message
    if resultat == "OK" then
        message = "|cff00ff00Sauvegarde effectuée.|r (" .. os.date("%H:%M") .. ")"
    else
        message = "|cffff0000La sauvegarde a échoué.|r Regarde la fenêtre du lanceur."
    end
    for _, player in ipairs(GetPlayersInWorld()) do
        player:SendBroadcastMessage(message)
    end
end

os.remove(FICHIER_RESULTAT)
RegisterPlayerEvent(PLAYER_EVENT_ON_COMMAND, OnCommand)
CreateLuaEvent(VerifierResultat, 1000, 0)
