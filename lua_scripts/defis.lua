-- Défis du personnage (section 3.3)
-- Les règles sont appliquées par mod-challenge-modes ; ce script gère le choix (fenêtre de l'addon
-- SolAzerothDefis), la note de difficulté et les récompenses par palier.
-- Valeurs provisoires.
-- Ligue Destin (V5, décisions de l'utilisateur du 30/10/2026) : race et classe tirées au sort depuis n'importe quel
-- personnage (« .soldefi destin tirer »). Le personnage créé ensuite avec cette race et cette classe peut choisir le
-- défi Destin (indice 100, 4 points, cumulable) au niveau 1 ; le tirage est alors utilisé. Un nouveau tirage est
-- possible 24 h après le précédent, une fois celui-ci utilisé ou abandonné (« .soldefi destin abandonner »).
-- Pas de chevalier de la mort (il commence au niveau 55). Un personnage Destin ne peut ni acheter les sorts ni prendre
-- les talents d'une autre classe (formation.cpp, talents_etrangers.cpp lisent le réglage REGLAGE_DESTIN).
-- Ligues Remix (indice 101) et Chaos (indice 102), V8 (décisions de l'utilisateur du 30/10/2026) : cochées au niveau 1
-- comme les autres défis ; leurs règles sont dans le module C++ (ligues.cpp), qui lit les réglages 4 et 5.

local PREFIXE = "SOLDEFI"
local SOURCE_MODULE = "mod-challenge-modes"
local SOURCE = "solazeroth-defis"
local REGLAGE_VERROU, REGLAGE_NOTE, REGLAGE_DERNIER_NIVEAU, REGLAGE_DESTIN = 0, 1, 2, 3
local PO = 10000
local CHEVALIER_DE_LA_MORT = 6
local CANAL_CHUCHOTEMENT = 7

-- Index du réglage dans mod-challenge-modes -> points de difficulté. Iron Man (7) est désactivé.
local POINTS = { [0] = 5, [1] = 3, [2] = 3, [3] = 2, [4] = 1, [5] = 2, [6] = 2 }
local INCOMPATIBLES = { { 0, 1 }, { 4, 5 } }

local DESTIN = 100
local POINTS_DESTIN = 4
-- Ligues V8 : indice -> réglage de la source SOURCE et points (provisoires).
local LIGUES = { [101] = { reglage = 4, points = 1 }, [102] = { reglage = 5, points = 2 } }
local DELAI_TIRAGE = 24 * 3600
local RACES = { [1] = "Humain", [2] = "Orc", [3] = "Nain", [4] = "Elfe de la nuit", [5] = "Mort-vivant", [6] = "Tauren",
                [7] = "Gnome", [8] = "Troll", [10] = "Elfe de sang", [11] = "Draeneï" }
local CLASSES = { [1] = "Guerrier", [2] = "Paladin", [3] = "Chasseur", [4] = "Voleur", [5] = "Prêtre", [7] = "Chaman",
                  [8] = "Mage", [9] = "Démoniste", [11] = "Druide" }
math.randomseed(os.time())

local PALIERS = {   -- du plus haut au plus bas
    { nom = "Légende", note = 15, multiplicateur = 5, titre = 128 },  -- « l'infaillible vainqueur » (30/10/2026)
    { nom = "Or",     note = 10, multiplicateur = 3, titre = 141 },  -- « l'immortel »
    { nom = "Argent", note = 6,  multiplicateur = 2, titre = 142 },  -- « l'increvable »
    { nom = "Bronze", note = 3,  multiplicateur = 1 },
}
local OR_PAR_NIVEAU = { [20] = 20, [40] = 100, [60] = 400, [80] = 1000 }   -- en po, palier Bronze
local NIVEAUX = { 20, 40, 60, 80 }
local JETONS_PAR_POINT = 10   -- Marques du voyageur à chaque niveau récompensé, par point de note
local MARQUE = 37711   -- Marque du voyageur, monnaie (migration 035)

local PLAYER_EVENT_ON_LEVEL_CHANGE = 13
local PLAYER_EVENT_ON_COMMAND = 42

local function Palier(note)
    for _, p in ipairs(PALIERS) do
        if note >= p.note then return p end
    end
end

local function Verrouille(player)
    return player:GetPlayerSettingValue(SOURCE, REGLAGE_VERROU) == 1
end

local function Eligible(player)
    if Verrouille(player) then return false end
    local niveau = player:GetLevel()
    return niveau == 1 or (player:GetClass() == CHEVALIER_DE_LA_MORT and niveau <= 55)
end

local function Envoyer(player, message)
    player:SendAddonMessage(PREFIXE, message, CANAL_CHUCHOTEMENT, player)
end

-- Tirage du compte : race, classe (0 si aucun en attente) et date du dernier tirage, gardés aussi en mémoire.
-- L'écriture est immédiate (CharDBQuery attend la base, contrairement à CharDBExecute) : se déconnecter ou arrêter
-- le serveur juste après un tirage ne permet pas de retirer (demande de l'utilisateur du 30/10/2026).
local tirages = {}

local function Tirage(compte)
    local t = tirages[compte]
    if not t then
        t = { 0, 0, 0 }
        local q = CharDBQuery("SELECT race, classe, tire_le FROM solazeroth_destin WHERE account = " .. compte)
        if q then t = { q:GetUInt32(0), q:GetUInt32(1), q:GetUInt32(2) } end
        tirages[compte] = t
    end
    return t[1], t[2], t[3]
end

local function NoterTirage(compte, race, classe, tireLe)
    tirages[compte] = { race, classe, tireLe }
    CharDBQuery(string.format("REPLACE INTO solazeroth_destin (account, race, classe, tire_le) VALUES (%d, %d, %d, %d)",
        compte, race, classe, tireLe))
end

local function CorrespondAuTirage(player)
    local race, classe = Tirage(player:GetAccountId())
    return race > 0 and race == player:GetRace() and classe == player:GetClass()
end

local function Cles(t)
    local cles = {}
    for cle in pairs(t) do table.insert(cles, cle) end
    return cles
end

local function Tirer(player)
    local compte = player:GetAccountId()
    local race, _, tireLe = Tirage(compte)
    if race > 0 then
        Envoyer(player, "ERREUR;Ton destin est déjà tiré : crée ce personnage, ou abandonne ce destin.")
        return
    end
    local attente = tireLe + DELAI_TIRAGE - os.time()
    if attente > 0 then
        Envoyer(player, string.format("ERREUR;Prochain tirage dans %d h %02d.", math.floor(attente / 3600), math.floor(attente % 3600 / 60)))
        return
    end
    local races, classes = Cles(RACES), Cles(CLASSES)
    race = races[math.random(#races)]
    local classe = classes[math.random(#classes)]
    NoterTirage(compte, race, classe, os.time())
    player:SendBroadcastMessage(string.format("|cffffd100Ton destin :|r %s %s. Crée ce personnage : à sa première connexion, choisis le défi Destin.",
        RACES[race], CLASSES[classe]))
end

local function Abandonner(player)
    local compte = player:GetAccountId()
    local _, _, tireLe = Tirage(compte)
    NoterTirage(compte, 0, 0, tireLe)
    player:SendBroadcastMessage("Destin abandonné. Un nouveau tirage sera possible 24 h après le précédent.")
end

local function EnvoyerEtat(player)
    local actifs = {}
    for index in pairs(POINTS) do
        if player:GetPlayerSettingValue(SOURCE_MODULE, index) == 1 then
            table.insert(actifs, index)
        end
    end
    table.sort(actifs)
    if player:GetPlayerSettingValue(SOURCE, REGLAGE_DESTIN) == 1 then
        table.insert(actifs, DESTIN)
    end
    for index, ligue in pairs(LIGUES) do
        if player:GetPlayerSettingValue(SOURCE, ligue.reglage) == 1 then
            table.insert(actifs, index)
        end
    end
    local note = player:GetPlayerSettingValue(SOURCE, REGLAGE_NOTE)
    local palier = Palier(note)
    -- Destin : race et classe tirées (0 si aucune), ce personnage y correspond-il, secondes avant le prochain tirage.
    local race, classe, tireLe = Tirage(player:GetAccountId())
    Envoyer(player, table.concat({ "ETAT", Eligible(player) and 1 or 0, Verrouille(player) and 1 or 0,
        table.concat(actifs, ","), note, palier and palier.nom or "", race, classe,
        CorrespondAuTirage(player) and 1 or 0, math.max(0, tireLe + DELAI_TIRAGE - os.time()) }, ";"))
end

local function Valider(player, liste)
    if not Eligible(player) then
        Envoyer(player, "ERREUR;Les défis ne se choisissent qu'au niveau 1.")
        return
    end
    local choisis, note = {}, 0
    for texte in string.gmatch(liste or "", "%d+") do
        local index = tonumber(texte)
        if index == DESTIN then
            if not CorrespondAuTirage(player) then
                Envoyer(player, "ERREUR;Ce personnage ne correspond pas à ton destin.")
                return
            end
        elseif not POINTS[index] and not LIGUES[index] then
            Envoyer(player, "ERREUR;Défi inconnu.")
            return
        end
        if not choisis[index] then
            choisis[index] = true
            note = note + (index == DESTIN and POINTS_DESTIN or LIGUES[index] and LIGUES[index].points or POINTS[index])
        end
    end
    for _, paire in ipairs(INCOMPATIBLES) do
        if choisis[paire[1]] and choisis[paire[2]] then
            Envoyer(player, "ERREUR;Deux des défis choisis sont incompatibles.")
            return
        end
    end
    for index in pairs(choisis) do
        if index == DESTIN then
            player:UpdatePlayerSetting(SOURCE, REGLAGE_DESTIN, 1)
            local compte = player:GetAccountId()
            local _, _, tireLe = Tirage(compte)
            NoterTirage(compte, 0, 0, tireLe)
        elseif LIGUES[index] then
            player:UpdatePlayerSetting(SOURCE, LIGUES[index].reglage, 1)
        else
            player:UpdatePlayerSetting(SOURCE_MODULE, index, 1)
        end
    end
    player:UpdatePlayerSetting(SOURCE, REGLAGE_NOTE, note)
    player:UpdatePlayerSetting(SOURCE, REGLAGE_VERROU, 1)
    player:SaveToDB()
    local palier = Palier(note)
    if note > 0 then
        player:SendBroadcastMessage(string.format("|cffffd100Défis activés.|r Difficulté %d%s.", note,
            palier and (" : palier " .. palier.nom) or ""))
    else
        player:SendBroadcastMessage("Aventure sans défi. Bon jeu !")
    end
    Envoyer(player, "OK;" .. note)
    EnvoyerEtat(player)
end

local function Recompenser(player, niveau, palier, note)
    local orGagne = OR_PAR_NIVEAU[niveau] * palier.multiplicateur
    player:ModifyMoney(orGagne * PO)
    -- Marques du voyageur (objet 37711) ; si les sacs sont pleins, elles sont gardées pour la prochaine connexion.
    local jetons = note * JETONS_PAR_POINT
    if not player:AddItem(MARQUE, jetons) then
        CharDBExecute(string.format(
            "INSERT INTO solazeroth_jetons_dus (account, jetons) VALUES (%d, %d) ON DUPLICATE KEY UPDATE jetons = jetons + %d",
            player:GetAccountId(), jetons, jetons))
    end
    local message = string.format("|cffffd100Récompense de défi (niveau %d, palier %s) :|r %d po et %d Marques du voyageur",
        niveau, palier.nom, orGagne, jetons)
    if niveau == 80 and palier.titre and not player:HasTitle(palier.titre) then
        player:SetKnownTitle(palier.titre)
        message = message .. ", et un nouveau titre"
    end
    player:SendBroadcastMessage(message .. ".")
end

local function OnLevelChange(event, player, ancienNiveau)
    local note = player:GetPlayerSettingValue(SOURCE, REGLAGE_NOTE)
    local palier = Palier(note)
    if not palier then return end
    local dernier = player:GetPlayerSettingValue(SOURCE, REGLAGE_DERNIER_NIVEAU)
    local niveau = player:GetLevel()
    for _, palierNiveau in ipairs(NIVEAUX) do
        if palierNiveau > dernier and palierNiveau <= niveau then
            Recompenser(player, palierNiveau, palier, note)
            player:UpdatePlayerSetting(SOURCE, REGLAGE_DERNIER_NIVEAU, palierNiveau)
            dernier = palierNiveau
        end
    end
end

-- L'addon parle au serveur par commandes : .soldefi etat  /  .soldefi valider 0,4,6,100  /  .soldefi destin tirer|abandonner
local function OnCommand(event, player, command)
    local nom, action, reste = command:gsub("^[%.!]", ""):match("^(%S+)%s*(%S*)%s*(.*)$")
    if not player or not nom or nom:lower() ~= "soldefi" then return end
    if action == "etat" then
        EnvoyerEtat(player)
    elseif action == "valider" then
        Valider(player, reste)
    elseif action == "destin" then
        if reste == "tirer" then
            Tirer(player)
        elseif reste == "abandonner" then
            Abandonner(player)
        end
        EnvoyerEtat(player)
    end
    return false
end

RegisterPlayerEvent(PLAYER_EVENT_ON_LEVEL_CHANGE, OnLevelChange)
RegisterPlayerEvent(PLAYER_EVENT_ON_COMMAND, OnCommand)
