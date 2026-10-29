-- Amélioration des objets (calibrage final G6, 29/10/2026) : des Marques du voyageur montent le rang d'un objet de 1.
-- Le serveur (mod-solazeroth, bonus.cpp) envoie "DEBUT", puis "OBJET;sac;case;objet;rang;bonus;bonus suivant;carac"
-- pour chaque objet améliorable, puis "FIN;prix;rang max". Commandes : ".solameliorer liste",
-- ".solameliorer monter <sac> <case>" (sac -1 : équipement porté, case 1 à 19 ; sac 0 à 4 : sacs).
-- Infobulles : "RANGS;objet:suffixe:rang:valeur:carac,..." (".solameliorer rangs") donne le rang des objets du
-- personnage, écrit juste sous la ligne de son bonus (« +18 Endurance ») partout où l'objet apparaît.

local PREFIXE = "SOLAMELIO"
local PAR_PAGE, LIGNES = 12, 6

local objets, recus = {}, {}
local prix, rangMax = 100, 5
local page = 1

local function Commande(texte) SendChatMessage(texte, "SAY") end

local CARACS = { [3] = ITEM_MOD_AGILITY_SHORT, [4] = ITEM_MOD_STRENGTH_SHORT, [5] = ITEM_MOD_INTELLECT_SHORT,
                 [6] = ITEM_MOD_SPIRIT_SHORT, [7] = ITEM_MOD_STAMINA_SHORT }

-- Ex. « Rang 2 (+12 Endurance). Au rang 3 : +18 Endurance. »
local function LigneRang(o)
    local carac = CARACS[o.stat] or ""
    local actuel = o.rang > 0 and string.format("Rang %d (+%d %s)", o.rang, o.avant, carac) or "Sans rang"
    return string.format("%s. Au rang %d : +%d %s.%s", actuel, o.rang + 1, o.apres, carac, o.sac == -1 and " Porté." or "")
end

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
    b.rang:SetWidth(240)
    b.rang:SetJustifyH("LEFT")
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
            b.rang:SetText(LigneRang(o))
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
evenements:RegisterEvent("ADDON_LOADED")
evenements:RegisterEvent("PLAYER_ENTERING_WORLD")

local delai = 0
local function DemanderRangs(self, ecoule)
    delai = delai + ecoule
    if delai >= 3 then
        self:SetScript("OnUpdate", nil)
        Commande(".solameliorer rangs")
    end
end

evenements:SetScript("OnEvent", function(self, event, prefixe, message)
    if event == "ADDON_LOADED" then
        if prefixe ~= "SolAzerothAmelioration" then return end
        SolAzerothAmeliorationDB = SolAzerothAmeliorationDB or {}
        SolAzerothAmeliorationDB.rangs = SolAzerothAmeliorationDB.rangs or {}
        return
    end
    if event == "PLAYER_ENTERING_WORLD" then
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        self:SetScript("OnUpdate", DemanderRangs)
        return
    end
    if event ~= "CHAT_MSG_ADDON" then
        if cadre:IsShown() then aDemander = true end
        return
    end
    if prefixe ~= PREFIXE then return end
    local type, a, b, c, d, e, f, g = strsplit(";", message)
    if type == "DEBUT" then
        recus = {}
    elseif type == "OBJET" then
        table.insert(recus, { sac = tonumber(a), case = tonumber(b), objet = tonumber(c), rang = tonumber(d),
                              avant = tonumber(e), apres = tonumber(f), stat = tonumber(g) })
    elseif type == "RANGS" then
        for objet, suffixe, rang, valeur, stat in string.gmatch(a or "", "(%d+):(%-?%d+):(%d+):(%d+):(%d+)") do
            SolAzerothAmeliorationDB.rangs[objet .. ":" .. suffixe] = { rang = tonumber(rang), valeur = tonumber(valeur), stat = tonumber(stat) }
        end
    elseif type == "FIN" then
        objets, prix, rangMax = recus, tonumber(a) or prix, tonumber(b) or rangMax
        Afficher()
    end
end)

SLASH_SOLAZEROTHAMELIORER1 = "/ameliorer"
SlashCmdList["SOLAZEROTHAMELIORER"] = function()
    if cadre:IsShown() then cadre:Hide() else cadre:Show() end
end

------------------------------------------------------------------------
-- Rang dans l'infobulle des objets
------------------------------------------------------------------------
local function AjouterRang(infobulle)
    local _, lien = infobulle:GetItem()
    local objet, suffixe = (lien or ""):match("item:(%d+):%-?%d+:%-?%d+:%-?%d+:%-?%d+:%-?%d+:(%-?%d+)")
    local info = objet and SolAzerothAmeliorationDB and SolAzerothAmeliorationDB.rangs[objet .. ":" .. suffixe]
    if type(info) ~= "table" then return end
    local texteRang = string.format("|cffffd100Rang de menace %d|r", info.rang)
    -- La ligne du bonus est la dernière « +valeur caractéristique » (le bonus suit les caractéristiques de base).
    local bonus = CARACS[info.stat] and ("+" .. info.valeur .. " " .. CARACS[info.stat])
    local nom = infobulle:GetName()
    for i = infobulle:NumLines(), 2, -1 do
        local ligne = _G[nom .. "TextLeft" .. i]
        local texte = ligne and ligne:GetText()
        if bonus and texte and texte:find(bonus, 1, true) then
            ligne:SetText(texte .. "\n" .. texteRang)
            infobulle:Show()
            return
        end
    end
    infobulle:AddLine(texteRang)
    infobulle:Show()
end

for _, infobulle in ipairs({ GameTooltip, ItemRefTooltip, ShoppingTooltip1, ShoppingTooltip2 }) do
    infobulle:HookScript("OnTooltipSetItem", AjouterRang)
end
