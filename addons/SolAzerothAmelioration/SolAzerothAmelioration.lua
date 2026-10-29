-- Amélioration des objets (calibrage final G6, 29/10/2026) : des Marques du voyageur montent le rang d'un objet de 1.
-- Le serveur (mod-solazeroth, bonus.cpp) envoie "DEBUT", puis "OBJET;sac;case;objet;rang;gain" pour chaque objet
-- améliorable, puis "FIN;prix;rang max". Commandes : ".solameliorer liste", ".solameliorer monter <sac> <case>"
-- (sac -1 : équipement porté, case 1 à 19 ; sac 0 à 4 : sacs).

local PREFIXE = "SOLAMELIO"
local PAR_PAGE, LIGNES = 12, 6

local objets, recus = {}, {}
local prix, rangMax = 100, 5
local page = 1

local function Commande(texte) SendChatMessage(texte, "SAY") end

local function Lien(o)
    if o.sac == -1 then return GetInventoryItemLink("player", o.case) end
    return GetContainerItemLink(o.sac, o.case)
end

------------------------------------------------------------------------
-- Fenêtre
------------------------------------------------------------------------
local cadre = CreateFrame("Frame", "SolAzerothAmeliorationCadre", UIParent)
cadre:SetSize(640, 400)
cadre:SetPoint("CENTER", 0, 60)
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
tinsert(UISpecialFrames, "SolAzerothAmeliorationCadre")

local entete = cadre:CreateTexture(nil, "ARTWORK")
entete:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
entete:SetSize(360, 64)
entete:SetPoint("TOP", 0, 12)
local titre = cadre:CreateFontString(nil, "OVERLAY", "GameFontNormal")
titre:SetPoint("TOP", entete, "TOP", 0, -14)
titre:SetText("Amélioration")

local fermer = CreateFrame("Button", nil, cadre, "UIPanelCloseButton")
fermer:SetPoint("TOPRIGHT", -6, -6)

local consigne = cadre:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
consigne:SetPoint("TOP", 0, -36)
consigne:SetWidth(580)

local vide = cadre:CreateFontString(nil, "OVERLAY", "GameFontNormal")
vide:SetPoint("CENTER")
vide:SetText("Aucun objet à améliorer : armes et armures vertes ou mieux, portées ou dans les sacs.")
vide:SetWidth(500)

local boutons = {}
for i = 1, PAR_PAGE do
    local b = CreateFrame("Button", nil, cadre)
    b:SetSize(36, 36)
    local colonne, ligne = math.floor((i - 1) / LIGNES), (i - 1) % LIGNES
    b:SetPoint("TOPLEFT", 30 + colonne * 300, -66 - ligne * 46)
    b.icone = b:CreateTexture(nil, "ARTWORK")
    b.icone:SetAllPoints()
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b.nom = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    b.nom:SetPoint("TOPLEFT", b, "TOPRIGHT", 6, -2)
    b.nom:SetWidth(240)
    b.nom:SetJustifyH("LEFT")
    b.rang = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    b.rang:SetPoint("TOPLEFT", b.nom, "BOTTOMLEFT", 0, -3)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.objet.sac == -1 then
            GameTooltip:SetInventoryItem("player", self.objet.case)
        else
            GameTooltip:SetBagItem(self.objet.sac, self.objet.case)
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnClick", function(self)
        local o = self.objet
        StaticPopup_Show("SOLAZEROTH_AMELIORER", Lien(o) or "cet objet", (o.rang + 1) .. " pour " .. prix, o)
    end)
    boutons[i] = b
end

StaticPopupDialogs["SOLAZEROTH_AMELIORER"] = {
    text = "Monter %s au rang %s Marques du voyageur ?",
    button1 = YES,
    button2 = NO,
    OnAccept = function(self, o)
        Commande(".solameliorer monter " .. o.sac .. " " .. o.case)
    end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

local pageTexte = cadre:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
pageTexte:SetPoint("BOTTOM", 0, 26)
local precedent = CreateFrame("Button", nil, cadre, "UIPanelButtonTemplate")
precedent:SetSize(90, 22)
precedent:SetPoint("BOTTOMLEFT", 24, 20)
precedent:SetText("Précédent")
local suivant = CreateFrame("Button", nil, cadre, "UIPanelButtonTemplate")
suivant:SetSize(90, 22)
suivant:SetPoint("BOTTOMRIGHT", -24, 20)
suivant:SetText("Suivant")

local function Afficher()
    consigne:SetText(string.format("%d Marques du voyageur par rang, jusqu'au rang %d. Au-delà, le rang vient des donjons et des raids.", prix, rangMax))
    local pages = math.max(1, math.ceil(#objets / PAR_PAGE))
    page = math.min(page, pages)
    for i, b in ipairs(boutons) do
        local o = objets[(page - 1) * PAR_PAGE + i]
        if o then
            b.objet = o
            b.icone:SetTexture(GetItemIcon(o.objet) or "Interface\\Icons\\INV_Misc_QuestionMark")
            b.nom:SetText(Lien(o) or "...")
            b.rang:SetText(string.format("Rang %d → %d : +%d%s", o.rang, o.rang + 1, o.gain, o.sac == -1 and " (porté)" or ""))
            b:Show()
        else
            b:Hide()
        end
    end
    if #objets == 0 then vide:Show() else vide:Hide() end
    pageTexte:SetText(pages > 1 and string.format("Page %d / %d", page, pages) or "")
    if page > 1 then precedent:Show() else precedent:Hide() end
    if page < pages then suivant:Show() else suivant:Hide() end
end

precedent:SetScript("OnClick", function() page = page - 1 Afficher() end)
suivant:SetScript("OnClick", function() page = page + 1 Afficher() end)

-- Les sacs et l'équipement changent : nouvelle liste, au plus une demande par seconde.
local aDemander, attente = false, 0
cadre:SetScript("OnShow", function() Commande(".solameliorer liste") end)
cadre:SetScript("OnUpdate", function(self, ecoule)
    attente = attente + ecoule
    if aDemander and attente > 1 then
        aDemander, attente = false, 0
        Commande(".solameliorer liste")
    end
end)

------------------------------------------------------------------------
-- Échanges avec le serveur
------------------------------------------------------------------------
local evenements = CreateFrame("Frame")
evenements:RegisterEvent("CHAT_MSG_ADDON")
evenements:RegisterEvent("BAG_UPDATE")
evenements:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
evenements:SetScript("OnEvent", function(self, event, prefixe, message)
    if event ~= "CHAT_MSG_ADDON" then
        if cadre:IsShown() then aDemander = true end
        return
    end
    if prefixe ~= PREFIXE then return end
    local type, a, b, c, d, e = strsplit(";", message)
    if type == "DEBUT" then
        recus = {}
    elseif type == "OBJET" then
        table.insert(recus, { sac = tonumber(a), case = tonumber(b), objet = tonumber(c), rang = tonumber(d), gain = tonumber(e) })
    elseif type == "FIN" then
        objets, prix, rangMax = recus, tonumber(a) or prix, tonumber(b) or rangMax
        Afficher()
    end
end)

SLASH_SOLAZEROTHAMELIORER1 = "/ameliorer"
SlashCmdList["SOLAZEROTHAMELIORER"] = function()
    if cadre:IsShown() then cadre:Hide() else cadre:Show() end
end
