-- Sol'Azeroth v3, F5d (31/10/2026) : notre fenêtre de discussion, à la place des fenêtres de Blizzard (demande de
-- l'utilisateur). Les messages gardent la mise en forme du jeu (ChatFrame_OnEvent : noms, canaux, liens d'objets),
-- mais chaque catégorie s'affiche ou non au choix du joueur (bouton en haut à droite, gardé avec la disposition) :
-- discussion, PNJ, butin, progression, sorts appris ou oubliés, messages du système.
-- Les fenêtres de Blizzard restent chargées mais n'affichent plus rien ; ce qu'elles recevaient directement (messages
-- des addons, aide des commandes) passe dans la nôtre. La zone de saisie reste celle du jeu (Entrée, /, R…).

local S = SolUI

S.DISPOSITION.chat = { point = "BOTTOMLEFT", x = 20, y = 46, echelle = 1 }

local CATEGORIES = {
    { cle = "chatDiscussion", nom = "Discussion", evenements = { "SAY", "YELL", "EMOTE", "TEXT_EMOTE", "WHISPER",
        "WHISPER_INFORM", "AFK", "DND", "IGNORED", "PARTY", "PARTY_LEADER", "RAID", "RAID_LEADER", "RAID_WARNING",
        "BATTLEGROUND", "BATTLEGROUND_LEADER", "CHANNEL", "CHANNEL_JOIN", "CHANNEL_LEAVE", "CHANNEL_NOTICE",
        "CHANNEL_NOTICE_USER", "CHANNEL_LIST" } },
    { cle = "chatPnj", nom = "Paroles des PNJ", evenements = { "MONSTER_SAY", "MONSTER_YELL", "MONSTER_EMOTE",
        "MONSTER_WHISPER", "MONSTER_PARTY", "RAID_BOSS_EMOTE", "RAID_BOSS_WHISPER" } },
    { cle = "chatButin", nom = "Butin et argent", evenements = { "LOOT", "MONEY", "OPENING", "TRADESKILLS" } },
    { cle = "chatProgression", nom = "Progression", evenements = { "COMBAT_XP_GAIN", "COMBAT_HONOR_GAIN",
        "COMBAT_FACTION_CHANGE", "SKILL", "ACHIEVEMENT" }, autres = { "PLAYER_LEVEL_UP" } },
    { cle = "chatSorts", nom = "Sorts appris ou oubliés" },   -- messages du système, reconnus à leur texte
    { cle = "chatSysteme", nom = "Système", evenements = { "SYSTEM" }, autres = { "TIME_PLAYED_MSG" } },
}
for _, c in ipairs(CATEGORIES) do
    S.OPTIONS[c.cle] = 1
end

-- « Vous avez appris un nouveau sort : %s. » -> motif Lua.
local SORTS = {}
for _, nom in ipairs({ "ERR_LEARN_SPELL_S", "ERR_LEARN_ABILITY_S", "ERR_LEARN_PASSIVE_S", "ERR_SPELL_UNLEARNED_S" }) do
    local texte = _G[nom]
    if texte then
        table.insert(SORTS, "^" .. texte:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"):gsub("%%%%s", ".+") .. "$")
    end
end
local function EstUnSort(message)
    for _, motif in ipairs(SORTS) do
        if message:find(motif) then return true end
    end
end

------------------------------------------------------------------------
-- Fenêtre
------------------------------------------------------------------------
local bloc = CreateFrame("Frame", "SolUIDiscussion", S.racine)
bloc:SetSize(440, 200)
S.Placer(bloc, "chat")

local fond = CreateFrame("Frame", nil, bloc)
fond:SetAllPoints()
S.Panneau(fond, 0.55)
fond:SetAlpha(0)

local chat = CreateFrame("ScrollingMessageFrame", "SolUIChat", bloc)
chat:SetPoint("TOPLEFT", 10, -8)
chat:SetPoint("BOTTOMRIGHT", -10, 8)
S.Police(chat, "Regular", 13)
chat:SetShadowColor(0, 0, 0, 0.9)
chat:SetShadowOffset(1, -1)
chat:SetJustifyH("LEFT")
chat:SetMaxLines(300)
chat:SetFading(true)
chat:SetTimeVisible(90)
chat:SetFadeDuration(4)
chat:SetIndentedWordWrap(true)
chat:EnableMouseWheel(true)
chat:SetScript("OnMouseWheel", function(self, sens)
    if IsShiftKeyDown() then
        if sens > 0 then self:ScrollToTop() else self:ScrollToBottom() end
    elseif sens > 0 then self:ScrollUp(); self:ScrollUp()
    else self:ScrollDown(); self:ScrollDown() end
end)
chat:SetScript("OnHyperlinkClick", ChatFrame_OnHyperlinkShow)
-- Champs attendus par la mise en forme du jeu (ChatFrame_OnEvent).
chat.channelList, chat.zoneChannelList, chat.messageTypeList = {}, {}, {}
chat.tellTimer = GetTime()
chat:SetID(1)   -- réglages de la fenêtre 1 du jeu (taille de police des icônes de raid)

-- Le fond n'apparaît que sous la souris ou pendant la saisie : le reste du temps, seuls les messages se voient.
local function Fond()
    local visible = bloc:IsMouseOver() or ChatFrameEditBox:IsShown() or S.EnEdition()
    fond:SetAlpha(visible and 1 or 0)
end
bloc:SetScript("OnUpdate", Fond)

------------------------------------------------------------------------
-- Événements
------------------------------------------------------------------------
local afficher = {}   -- événement -> clé de la catégorie

local function MajCanaux()
    wipe(chat.channelList)
    wipe(chat.zoneChannelList)
    local liste = { GetChannelList() }
    for i = 1, #liste, 2 do chat.channelList[liste[i]] = liste[i + 1] end
end

for _, c in ipairs(CATEGORIES) do
    for _, type in ipairs(c.evenements or {}) do
        afficher["CHAT_MSG_" .. type] = c.cle
        chat:RegisterEvent("CHAT_MSG_" .. type)
    end
    for _, evenement in ipairs(c.autres or {}) do
        afficher[evenement] = c.cle
        chat:RegisterEvent(evenement)
    end
end
for _, evenement in ipairs({ "PLAYER_ENTERING_WORLD", "UPDATE_CHAT_COLOR", "CHANNEL_UI_UPDATE",
        "UPDATE_CHAT_COLOR_NAME_BY_CLASS" }) do
    chat:RegisterEvent(evenement)
end

chat:SetScript("OnEvent", function(self, evenement, ...)
    if evenement == "PLAYER_ENTERING_WORLD" or evenement == "CHANNEL_UI_UPDATE" then MajCanaux() end
    if evenement == "CHAT_MSG_CHANNEL_NOTICE" then MajCanaux() end
    local cle = afficher[evenement]
    if cle then
        if evenement == "CHAT_MSG_SYSTEM" and EstUnSort((...) or "") then cle = "chatSorts" end
        if S.OPTIONS[cle] ~= 1 then return end
    end
    ChatFrame_OnEvent(self, evenement, ...)
end)

------------------------------------------------------------------------
-- Fenêtres de Blizzard : muettes et rangées
------------------------------------------------------------------------
for i = 1, NUM_CHAT_WINDOWS do
    local cadre = _G["ChatFrame" .. i]
    if cadre then
        cadre:SetScript("OnEvent", nil)
        S.Ranger(cadre)
        S.Ranger(_G["ChatFrame" .. i .. "Tab"])
    end
end
S.Ranger(ChatFrameMenuButton)
-- Ce que le jeu et les addons écrivent directement dans la fenêtre principale arrive dans la nôtre.
ChatFrame1.AddMessage = function(_, ...) chat:AddMessage(...) end

-- Zone de saisie : sous la fenêtre, avec nos couleurs.
ChatFrameEditBox:SetParent(S.racine)
ChatFrameEditBox:ClearAllPoints()
ChatFrameEditBox:SetPoint("TOPLEFT", bloc, "BOTTOMLEFT", 0, -2)
ChatFrameEditBox:SetPoint("TOPRIGHT", bloc, "BOTTOMRIGHT", 0, -2)
ChatFrameEditBox:SetHeight(28)
for _, region in ipairs({ ChatFrameEditBox:GetRegions() }) do
    if region:GetObjectType() == "Texture" then region:SetAlpha(0) end
end
local fondSaisie = CreateFrame("Frame", nil, ChatFrameEditBox)
fondSaisie:SetAllPoints()
fondSaisie:SetFrameLevel(math.max(0, ChatFrameEditBox:GetFrameLevel() - 1))
S.Panneau(fondSaisie, 0.9)
fondSaisie:SetBackdropBorderColor(S.Couleur("ambre", 0.7))

------------------------------------------------------------------------
-- Choix des catégories
------------------------------------------------------------------------
local filtre = CreateFrame("Button", nil, bloc)
filtre:SetSize(22, 22)
filtre:SetPoint("TOPRIGHT", -4, -4)
filtre:SetFrameLevel(chat:GetFrameLevel() + 2)
for i = -1, 1 do
    local trait = S.Texture(filtre, "ARTWORK", nil, S.Couleur("texte", 0.85))
    trait:SetSize(14 - (i + 1) * 4, 2)
    trait:SetPoint("CENTER", 0, -i * 4)
end
filtre:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Ce qui s'affiche")
end)
filtre:SetScript("OnLeave", function() GameTooltip:Hide() end)
filtre:SetScript("OnUpdate", function(self) self:SetAlpha(fond:GetAlpha()) end)

local deroulant = CreateFrame("Frame", "SolUIChatFiltre", UIParent, "UIDropDownMenuTemplate")
filtre:SetScript("OnClick", function(self)
    local liste = { { text = "Afficher dans la discussion", isTitle = true, notCheckable = true } }
    for _, c in ipairs(CATEGORIES) do
        table.insert(liste, { text = c.nom, checked = S.OPTIONS[c.cle] == 1, keepShownOnClick = true,
            func = function() S.ModifierOption(c.cle, S.OPTIONS[c.cle] == 1 and 0 or 1) end })
    end
    EasyMenu(liste, deroulant, self, 0, 0, "MENU")
end)
