-- Mode défi en extérieur. Le serveur (mod-solazeroth, defi_exterieur.cpp) envoie
-- "EXT;niveau;max;repos;pv;dégâts;xp;or;marques" (multiplicateurs par niveau, séparés par des virgules).
-- Choix : ".solext choisir <niveau>", en zone de repos (partout avant le niveau 10 : pas d'auberge en zone de départ).
-- Ouverture : clic droit sur le bouton de la minicarte du rang de menace, ou /exterieur.

local PREFIXE = "SOLEXT"

local etat = { niveau = 0, max = 5, repos = false, pv = {}, degats = {}, xp = {}, gainOr = {}, marques = {} }

local function Commande(texte) SendChatMessage(texte, "SAY") end

local cadre = CreateFrame("Frame", "SolAzerothExterieurCadre", UIParent)
cadre:SetSize(430, 250)
cadre:SetPoint("CENTER", 0, 80)
cadre:SetFrameStrata("DIALOG")
cadre:SetBackdrop({
    bgFile = "Interface\\AchievementFrame\\UI-Achievement-Parchment-Horizontal",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
    edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 },
})
cadre:EnableMouse(true)
cadre:SetMovable(true)
cadre:RegisterForDrag("LeftButton")
cadre:SetScript("OnDragStart", cadre.StartMoving)
cadre:SetScript("OnDragStop", cadre.StopMovingOrSizing)
cadre:Hide()
tinsert(UISpecialFrames, "SolAzerothExterieurCadre")

local entete = cadre:CreateTexture(nil, "ARTWORK")
entete:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
entete:SetSize(300, 64)
entete:SetPoint("TOP", 0, 12)
local titre = cadre:CreateFontString(nil, "OVERLAY", "GameFontNormal")
titre:SetPoint("TOP", entete, "TOP", 0, -14)
titre:SetText("Défi en extérieur")

local fermer = CreateFrame("Button", nil, cadre, "UIPanelCloseButton")
fermer:SetPoint("TOPRIGHT", -6, -6)

local intro = cadre:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
intro:SetPoint("TOP", 0, -34)
intro:SetWidth(390)
intro:SetText("Hors des donjons, les monstres que vous affrontez deviennent plus coriaces. En échange, vous gagnez plus.")

local actuel = cadre:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
actuel:SetPoint("TOP", 0, -72)

local boutons = {}
for i = 0, 5 do
    local b = CreateFrame("Button", nil, cadre, "UIPanelButtonTemplate")
    b:SetSize(52, 26)
    b:SetPoint("TOPLEFT", 31 + i * 62, -100)
    b:SetText(i == 0 and "Aucun" or tostring(i))
    b:SetScript("OnClick", function() Commande(".solext choisir " .. i) end)
    boutons[i] = b
end

local effets = cadre:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
effets:SetPoint("TOP", 0, -138)
effets:SetWidth(390)

local note = cadre:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
note:SetPoint("BOTTOM", 0, 22)
note:SetWidth(390)

-- Multiplicateur du niveau n en pourcentage ajouté (1.35 -> 35).
local function Pourcent(liste, n) return math.floor(((liste[n] or 1) - 1) * 100 + 0.5) end

local function Effets(n)
    if n == 0 then return "Monstres normaux, gains normaux." end
    return string.format(
        "Monstres : |cffff6060+%d %% de résistance, +%d %% de dégâts|r\nGains : |cff60ff60+%d %% d'XP, +%d %% d'or ramassé, +%d %% de Marques des quêtes|r",
        Pourcent(etat.pv, n), Pourcent(etat.degats, n), Pourcent(etat.xp, n), Pourcent(etat.gainOr, n), Pourcent(etat.marques, n))
end

for i = 0, 5 do
    boutons[i]:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(i == 0 and "Aucun défi" or ("Niveau " .. i), 1, 0.82, 0)
        GameTooltip:AddLine(Effets(i), 1, 1, 1)
        GameTooltip:Show()
    end)
    boutons[i]:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function Lire(texte)
    local liste = {}
    for v in string.gmatch(texte or "", "[^,]+") do liste[#liste + 1] = tonumber(v) or 1 end
    return liste
end

local function Rafraichir()
    local n = etat.niveau
    actuel:SetText(n == 0 and "Niveau actuel : aucun" or ("Niveau actuel : " .. n))
    for i = 0, 5 do
        local b = boutons[i]
        if i > etat.max then b:Hide() else b:Show() end
        if i == n or not etat.repos then b:Disable() else b:Enable() end
    end
    effets:SetText(Effets(n))
    if etat.repos then
        note:SetText(UnitLevel("player") < 10 and "Avant le niveau 10, vous pouvez changer de niveau partout, hors combat."
            or "Vous êtes en zone de repos : vous pouvez changer de niveau.")
    else
        note:SetText("|cffff8040Le niveau ne se change qu'en zone de repos (auberge, capitale), hors combat.|r")
    end
end

local evenements = CreateFrame("Frame")
evenements:RegisterEvent("CHAT_MSG_ADDON")
evenements:RegisterEvent("PLAYER_UPDATE_RESTING")
evenements:SetScript("OnEvent", function(self, event, prefixe, message)
    if event == "PLAYER_UPDATE_RESTING" then
        etat.repos = (IsResting() or UnitLevel("player") < 10) and true or false
        if cadre:IsShown() then Rafraichir() end
        return
    end
    if prefixe ~= PREFIXE then return end
    local champs = { strsplit(";", message) }
    if champs[1] ~= "EXT" then return end
    etat.niveau = tonumber(champs[2]) or 0
    etat.max = tonumber(champs[3]) or 5
    etat.repos = champs[4] == "1"
    etat.pv = Lire(champs[5])
    etat.degats = Lire(champs[6])
    etat.xp = Lire(champs[7])
    etat.gainOr = Lire(champs[8])
    etat.marques = Lire(champs[9])
    Rafraichir()
end)

local function Basculer()
    if cadre:IsShown() then
        cadre:Hide()
    else
        etat.repos = (IsResting() or UnitLevel("player") < 10) and true or false
        cadre:Show()
        Rafraichir()
        Commande(".solext etat")
    end
end

SLASH_SOLAZEROTHEXTERIEUR1 = "/exterieur"
SlashCmdList["SOLAZEROTHEXTERIEUR"] = Basculer

-- Clic droit sur le bouton de la minicarte du rang de menace.
local bouton = SolAzerothMenaceBoutonMinicarte
if bouton then
    local clicGauche = bouton:GetScript("OnClick")
    bouton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    bouton:SetScript("OnClick", function(self, clic)
        if clic == "RightButton" then Basculer() elseif clicGauche then clicGauche(self, clic) end
    end)
    local survol = bouton:GetScript("OnEnter")
    bouton:SetScript("OnEnter", function(self)
        if survol then survol(self) end
        GameTooltip:AddLine("Clic droit : défi en extérieur", 1, 1, 1)
        GameTooltip:Show()
    end)
end
