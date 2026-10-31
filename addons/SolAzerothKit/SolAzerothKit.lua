-- v3, F3 (31/10/2026) : page Techniques (/sol ou /kit). La jauge du Rempart est passée dans l'interface v3 (F4,
-- Interface\FrameXML\SolUI_Perso.lua).
-- Le serveur (mod-solazeroth, v3_kit.cpp) envoie, préfixe SOLKIT :
--   "ETAT;spe;puissance;prochain_palier;sort:etat,…" (etat : 0 verrouillée, 1 débloquée, 2 équipée ; palier 0 = tout
--   est débloqué) ; "REMPART;montant;plafond".
-- Commandes : ".kit" (état), ".kit spe tank", ".kit equiper <sort> …" (hors combat).
-- Provisoire : les fenêtres de la v3 remplaceront cette page.

local PREFIXE = "SOLKIT"
local EQUIPEES_MAX, DE_DEPART, PAR_TECHNIQUE = 8, 4, 5

local etat = { spe = nil, puissance = 0, prochain = 0, techniques = {} }
local choix = {}

local function Commande(texte) SendChatMessage(texte, "SAY") end

-- SetShown n'existe pas dans le jeu 3.3.5.
local function Montrer(objet, visible)
    if visible then objet:Show() else objet:Hide() end
end

------------------------------------------------------------------------
-- Fenêtre
------------------------------------------------------------------------
local cadre = CreateFrame("Frame", "SolAzerothKitCadre", UIParent)
cadre:SetSize(640, 520)
cadre:SetPoint("CENTER")
cadre:SetFrameStrata("DIALOG")
cadre:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
                    tile = true, tileSize = 32, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 } })
cadre:EnableMouse(true)
cadre:SetMovable(true)
cadre:RegisterForDrag("LeftButton")
cadre:SetScript("OnDragStart", cadre.StartMoving)
cadre:SetScript("OnDragStop", cadre.StopMovingOrSizing)
cadre:Hide()
tinsert(UISpecialFrames, "SolAzerothKitCadre")

local titre = cadre:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
titre:SetPoint("TOP", 0, -18)
titre:SetText("Techniques")
local fermer = CreateFrame("Button", nil, cadre, "UIPanelCloseButton")
fermer:SetPoint("TOPRIGHT", -6, -6)

local entete = cadre:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
entete:SetPoint("TOPLEFT", 24, -48)
entete:SetWidth(592)
entete:SetJustifyH("LEFT")

------------------------------------------------------------------------
-- Choix de la spécialisation (une fois, à l'entrée en jeu)
------------------------------------------------------------------------
local spe = CreateFrame("Frame", nil, cadre)
spe:SetPoint("TOPLEFT", 20, -90)
spe:SetPoint("BOTTOMRIGHT", -20, 20)
local carte = CreateFrame("Frame", nil, spe)
carte:SetPoint("TOPLEFT", 0, 0)
carte:SetPoint("RIGHT", 0, 0)
carte:SetHeight(150)
carte:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                    tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
carte:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
local icone = carte:CreateTexture(nil, "ARTWORK")
icone:SetSize(48, 48)
icone:SetPoint("TOPLEFT", 14, -14)
icone:SetTexture("Interface\\Icons\\SolAzeroth_inv_shield_1h_artifactmagnar_d_01")
local nomSpe = carte:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
nomSpe:SetPoint("TOPLEFT", 76, -16)
nomSpe:SetText("Guerrier — Tank")
local texteSpe = carte:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
texteSpe:SetPoint("TOPLEFT", 76, -40)
texteSpe:SetWidth(500)
texteSpe:SetJustifyH("LEFT")
texteSpe:SetText("Passif Rempart : chaque coup encaissé remplit un bouclier qui absorbe les coups suivants. Le garder pour "
    .. "tenir, ou le dépenser pour rendre les coups.\nTu commences avec 4 techniques ; une de plus se débloque tous les "
    .. "5 points de puissance.\n\nLe choix est définitif pour l'instant. Les autres spécialisations viendront plus tard.")
local boutonSpe = CreateFrame("Button", nil, carte, "UIPanelButtonTemplate")
boutonSpe:SetSize(180, 24)
boutonSpe:SetPoint("BOTTOMRIGHT", -14, 12)
boutonSpe:SetText("Choisir cette spécialisation")
boutonSpe:SetScript("OnClick", function() Commande(".kit spe tank") end)

------------------------------------------------------------------------
-- Panel : 16 techniques sur deux colonnes, 8 à cocher
------------------------------------------------------------------------
local panel = CreateFrame("Frame", nil, cadre)
panel:SetPoint("TOPLEFT", 20, -90)
panel:SetPoint("BOTTOMRIGHT", -20, 20)

local lignes = {}
local compteur, valider, Rafraichir

local function Nombre()
    local n = 0
    for _ in pairs(choix) do n = n + 1 end
    return n
end

local function MettreAJourCompteur()
    compteur:SetText(Nombre() .. " / " .. EQUIPEES_MAX .. " équipées")
end

local function Ligne(i)
    local l = CreateFrame("CheckButton", nil, panel)
    l:SetSize(290, 40)
    l:SetPoint("TOPLEFT", ((i - 1) % 2) * 300, -math.floor((i - 1) / 2) * 44)
    l:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                    tile = true, tileSize = 16, edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    l.icone = l:CreateTexture(nil, "ARTWORK")
    l.icone:SetSize(32, 32)
    l.icone:SetPoint("LEFT", 4, 0)
    l.nom = l:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    l.nom:SetPoint("TOPLEFT", 42, -6)
    l.detail = l:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    l.detail:SetPoint("TOPLEFT", 42, -22)
    l.coche = l:CreateTexture(nil, "OVERLAY")
    l.coche:SetSize(20, 20)
    l.coche:SetPoint("RIGHT", -8, 0)
    l.coche:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    l:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink("spell:" .. self.sort)
        GameTooltip:Show()
    end)
    l:SetScript("OnLeave", function() GameTooltip:Hide() end)
    l:SetScript("OnClick", function(self)
        if not self.debloquee then return end
        if choix[self.sort] then
            choix[self.sort] = nil
        elseif Nombre() < EQUIPEES_MAX then
            choix[self.sort] = true
        end
        Rafraichir()
    end)
    return l
end

function Rafraichir()
    entete:SetText(etat.spe == 1 and string.format("Guerrier — Tank. Puissance %d. %s", etat.puissance,
        etat.prochain > 0 and ("Prochaine technique à " .. etat.prochain .. " de puissance.") or "Toutes les techniques sont débloquées.")
        or "Choisis ta spécialisation.")
    Montrer(spe, etat.spe == 0)
    Montrer(panel, etat.spe == 1)
    if etat.spe ~= 1 then return end
    for i, t in ipairs(etat.techniques) do
        local l = lignes[i] or Ligne(i)
        lignes[i] = l
        local nom, _, texture = GetSpellInfo(t.sort)
        l.sort = t.sort
        l.debloquee = t.etat > 0
        l.icone:SetTexture(texture)
        l.icone:SetDesaturated(not l.debloquee)
        l.nom:SetText(nom or t.sort)
        if l.debloquee then
            l.nom:SetTextColor(1, 0.82, 0)
            l.detail:SetText(choix[t.sort] and "|cff40c040Équipée|r" or "|cff909090Au repos|r")
            l:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
        else
            l.nom:SetTextColor(0.5, 0.5, 0.5)
            l.detail:SetText("|cff909090Débloquée à " .. ((i - DE_DEPART) * PAR_TECHNIQUE) .. " de puissance|r")
            l:SetBackdropColor(0.05, 0.05, 0.05, 0.6)
        end
        Montrer(l.coche, choix[t.sort] ~= nil)
    end
    MettreAJourCompteur()
end

compteur = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
compteur:SetPoint("BOTTOMLEFT", 4, 10)
valider = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
valider:SetSize(200, 24)
valider:SetPoint("BOTTOMRIGHT", -4, 6)
valider:SetText("Équiper ces techniques")
valider:SetScript("OnClick", function()
    if InCombatLockdown() then
        UIErrorsFrame:AddMessage("Les techniques se changent hors combat.", 1, 0.1, 0.1)
        return
    end
    local liste = {}
    for _, t in ipairs(etat.techniques) do
        if choix[t.sort] then liste[#liste + 1] = t.sort end
    end
    Commande(".kit equiper " .. table.concat(liste, " "))
end)
local aide = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
aide:SetPoint("BOTTOMLEFT", compteur, "TOPLEFT", 0, 8)
aide:SetText("Clique pour équiper ou ranger une technique (8 au plus), puis valide hors combat. Les techniques équipées "
    .. "se placent sur la barre d'action.")

------------------------------------------------------------------------
-- Messages du serveur
------------------------------------------------------------------------
local ecoute = CreateFrame("Frame")
ecoute:RegisterEvent("CHAT_MSG_ADDON")
ecoute:RegisterEvent("PLAYER_ENTERING_WORLD")
ecoute:SetScript("OnEvent", function(self, event, prefixe, message)
    if event == "PLAYER_ENTERING_WORLD" then
        Commande(".kit")
        return
    end
    if prefixe ~= PREFIXE then return end
    local champs = { strsplit(";", message) }
    if champs[1] == "ETAT" then
        local premier = etat.spe == nil
        etat.spe = tonumber(champs[2])
        etat.puissance = tonumber(champs[3]) or 0
        etat.prochain = tonumber(champs[4]) or 0
        etat.techniques = {}
        wipe(choix)
        for sort, e in string.gmatch(champs[5] or "", "(%d+):(%d)") do
            etat.techniques[#etat.techniques + 1] = { sort = tonumber(sort), etat = tonumber(e) }
            if e == "2" then choix[tonumber(sort)] = true end
        end
        Rafraichir()
        -- À l'entrée en jeu d'un guerrier sans spécialisation, la page s'ouvre d'elle-même.
        if premier and etat.spe == 0 and select(2, UnitClass("player")) == "WARRIOR" then cadre:Show() end
    end
end)

cadre:SetScript("OnShow", function() Commande(".kit") end)

local function Basculer()
    Montrer(cadre, not cadre:IsShown())
end

SLASH_SOLAZEROTHKIT1 = "/kit"
SlashCmdList["SOLAZEROTHKIT"] = Basculer
