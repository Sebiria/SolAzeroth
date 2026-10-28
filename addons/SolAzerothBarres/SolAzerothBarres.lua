-- Barres de postures et de totems (demande de l'utilisateur du 30/10/2026, grimoire universel, section 3.9).
-- Le jeu place la barre de totems du chaman (MultiCastActionBarFrame) à l'endroit de la barre de postures, auras et
-- formes (ShapeshiftBarFrame), car un chaman n'a pas de postures. Un paladin qui achète des totems a les deux :
-- elles se superposaient. Ici, la barre de totems se place au-dessus de la barre de postures, et « /barres »
-- déverrouille les deux pour les déplacer à la souris (positions gardées par personnage).
-- Ces barres sont protégées : on ne les déplace jamais en combat (on attend la fin du combat).

local BARRES = {
    { cle = "postures", nom = "Postures, auras et formes", cadre = function() return ShapeshiftBarFrame end },
    { cle = "totems", nom = "Totems", cadre = function() return MultiCastActionBarFrame end },
}

local deverrouille = false
local enAttente = false

-- Place les barres : position choisie à la souris, sinon totems au-dessus des postures, postures à leur place d'origine.
local function Appliquer()
    if InCombatLockdown() then
        enAttente = true
        return
    end
    enAttente = false
    local db = SolAzerothBarresDB
    if not db then return end
    for _, b in ipairs(BARRES) do
        local cadre, pos = b.cadre(), db[b.cle]
        if cadre then
            if pos then
                cadre:ClearAllPoints()
                cadre:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", pos[1], pos[2])
            elseif b.cle == "totems" and ShapeshiftBarFrame then
                cadre:ClearAllPoints()
                cadre:SetPoint("BOTTOMLEFT", ShapeshiftBarFrame, "TOPLEFT", 0, 6)
            end
        end
    end
end

-- Le jeu replace ces barres à chaque changement d'interface : on repasse derrière lui.
hooksecurefunc("UIParent_ManageFramePositions", Appliquer)

------------------------------------------------------------------------
-- Poignées de déplacement (visibles une fois déverrouillé)
------------------------------------------------------------------------
local poignees = {}

for _, b in ipairs(BARRES) do
    local p = CreateFrame("Frame", nil, UIParent)
    p:SetFrameStrata("DIALOG")
    p:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                    edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    p:SetBackdropColor(0, 0.6, 0, 0.5)
    p:SetBackdropBorderColor(0.3, 1, 0.3)
    p:EnableMouse(true)
    p:SetMovable(true)
    p:RegisterForDrag("LeftButton")
    p.texte = p:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    p.texte:SetPoint("CENTER")
    p.texte:SetText(b.nom)
    p:SetScript("OnDragStart", p.StartMoving)
    p:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SolAzerothBarresDB[b.cle] = { math.floor(self:GetLeft() + 0.5), math.floor(self:GetBottom() + 0.5) }
        Appliquer()
    end)
    p:Hide()
    p.barre = b
    poignees[#poignees + 1] = p
end

-- Chaque poignée recouvre sa barre (taille de la barre, au moins assez grande pour être attrapée).
local function PlacerPoignees()
    for _, p in ipairs(poignees) do
        local cadre = p.barre.cadre()
        if cadre and cadre:IsShown() and cadre:GetLeft() then
            p:ClearAllPoints()
            p:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", cadre:GetLeft(), cadre:GetBottom())
            p:SetSize(math.max(cadre:GetWidth(), 160), math.max(cadre:GetHeight(), 30))
            p:Show()
        else
            p:Hide()
        end
    end
end

local function Basculer(argument)
    if argument == "reset" then
        if InCombatLockdown() then
            print("|cffffd100Barres :|r impossible en combat.")
            return
        end
        SolAzerothBarresDB = {}
        ReloadUI()
        return
    end
    if InCombatLockdown() then
        print("|cffffd100Barres :|r impossible en combat.")
        return
    end
    deverrouille = not deverrouille
    if deverrouille then
        PlacerPoignees()
        print("|cffffd100Barres :|r glisse les cadres verts pour déplacer les barres, puis tape /barres pour verrouiller. (/barres reset : places d'origine)")
    else
        for _, p in ipairs(poignees) do p:Hide() end
        print("|cffffd100Barres :|r verrouillées.")
    end
end

SLASH_SOLAZEROTHBARRES1 = "/barres"
SlashCmdList["SOLAZEROTHBARRES"] = function(texte) Basculer(strtrim(strlower(texte or ""))) end

------------------------------------------------------------------------
-- Événements
------------------------------------------------------------------------
local evenements = CreateFrame("Frame")
evenements:RegisterEvent("ADDON_LOADED")
evenements:RegisterEvent("PLAYER_ENTERING_WORLD")
evenements:RegisterEvent("PLAYER_REGEN_ENABLED")
evenements:RegisterEvent("PLAYER_REGEN_DISABLED")
evenements:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
evenements:RegisterEvent("UPDATE_MULTI_CAST_ACTIONBAR")
evenements:SetScript("OnEvent", function(self, event, nom)
    if event == "ADDON_LOADED" then
        if nom ~= "SolAzerothBarres" then return end
        SolAzerothBarresDB = SolAzerothBarresDB or {}
        return
    end
    if event == "PLAYER_REGEN_DISABLED" then
        -- En combat, on range les poignées : les barres ne peuvent plus bouger.
        if deverrouille then
            deverrouille = false
            for _, p in ipairs(poignees) do p:Hide() end
        end
        return
    end
    if event == "PLAYER_REGEN_ENABLED" and not enAttente then return end
    Appliquer()
end)
