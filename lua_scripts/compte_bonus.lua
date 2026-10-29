-- Bonus de compte (section 3.4)
-- XP : +10 % par classe déjà montée au niveau 80 sur un autre personnage du compte, plafond +50 %.
-- Réputation : doublée pour une faction déjà exaltée sur un autre personnage du compte.
-- Histoire (V6, décision de l'utilisateur du 28/10/2026) : +5 % d'XP par chapitre du « fil du Fléau » (quêtes 900200 à
-- 900215, histoire.cpp) déjà terminé par un autre personnage du compte, en plus du bonus des classes (16 chapitres :
-- +32 %).
-- Calibrage final (29/10/2026) : bonus réduits (classes +25 % → +10 %, plafond +150 % → +50 %, chapitres +5 % → +2 %),
-- car ils se multipliaient avec le bonus du Codex sur l'XP de quête (un 2e personnage montait 1-80 en ~20 h).

local BONUS_XP_PAR_CLASSE = 0.10
local BONUS_XP_MAX = 0.50
local BONUS_XP_PAR_CHAPITRE = 0.02
local PREMIER_CHAPITRE, DERNIER_CHAPITRE = 900200, 900215
local NIVEAU_MAX = 80
local RANG_EXALTE = 7

local PLAYER_EVENT_ON_LOGIN = 3
local PLAYER_EVENT_ON_GIVE_XP = 12
local PLAYER_EVENT_ON_LEVEL_CHANGE = 13
local PLAYER_EVENT_ON_REPUTATION_CHANGE = 15

local bonusXp = {}       -- [guid] = multiplicateur supplémentaire
local exaltees = {}      -- [compte] = { [faction] = true }

local function ChargerBonusXp(player)
    local guid = player:GetGUIDLow()
    local q = CharDBQuery(string.format(
        "SELECT COUNT(DISTINCT class) FROM characters WHERE account = %d AND guid <> %d AND level >= %d",
        player:GetAccountId(), guid, NIVEAU_MAX))
    local classes = q and q:GetUInt32(0) or 0
    q = CharDBQuery(string.format(
        "SELECT COUNT(DISTINCT r.quest) FROM character_queststatus_rewarded r JOIN characters c ON c.guid = r.guid " ..
        "WHERE c.account = %d AND c.guid <> %d AND r.quest BETWEEN %d AND %d",
        player:GetAccountId(), guid, PREMIER_CHAPITRE, DERNIER_CHAPITRE))
    local chapitres = q and q:GetUInt32(0) or 0
    bonusXp[guid] = math.min(classes * BONUS_XP_PAR_CLASSE, BONUS_XP_MAX) + chapitres * BONUS_XP_PAR_CHAPITRE
end

local function ChargerExaltees(compte)
    exaltees[compte] = {}
    local q = CharDBQuery("SELECT faction FROM solazeroth_compte_exalte WHERE account = " .. compte)
    if q then
        repeat
            exaltees[compte][q:GetUInt32(0)] = true
        until not q:NextRow()
    end
end

local function OnLogin(event, player)
    ChargerBonusXp(player)
    ChargerExaltees(player:GetAccountId())
    local bonus = bonusXp[player:GetGUIDLow()]
    if bonus > 0 then
        player:SendBroadcastMessage(string.format("Bonus de compte : +%d %% d'XP.", bonus * 100))
    end
end

local function OnGiveXp(event, player, amount)
    local bonus = bonusXp[player:GetGUIDLow()]
    if not bonus or bonus == 0 then return end
    return math.floor(amount * (1 + bonus))
end

local function OnLevelChange(event, player)
    -- Un personnage qui atteint le 80 compte pour les autres dès leur prochaine connexion.
    ChargerBonusXp(player)
end

local function OnReputationChange(event, player, faction, standing, incremental)
    local compte = player:GetAccountId()
    if not exaltees[compte] then ChargerExaltees(compte) end

    if player:GetReputationRank(faction) == RANG_EXALTE and not exaltees[compte][faction] then
        exaltees[compte][faction] = true
        CharDBExecute(string.format(
            "INSERT IGNORE INTO solazeroth_compte_exalte (account, faction, guid) VALUES (%d, %d, %d)",
            compte, faction, player:GetGUIDLow()))
        return
    end

    if incremental and standing > 0 and exaltees[compte][faction] then
        local q = CharDBQuery(string.format(
            "SELECT guid FROM solazeroth_compte_exalte WHERE account = %d AND faction = %d", compte, faction))
        if q and q:GetUInt32(0) ~= player:GetGUIDLow() then
            return standing * 2
        end
    end
end

RegisterPlayerEvent(PLAYER_EVENT_ON_LOGIN, OnLogin)
RegisterPlayerEvent(PLAYER_EVENT_ON_GIVE_XP, OnGiveXp)
RegisterPlayerEvent(PLAYER_EVENT_ON_LEVEL_CHANGE, OnLevelChange)
RegisterPlayerEvent(PLAYER_EVENT_ON_REPUTATION_CHANGE, OnReputationChange)
