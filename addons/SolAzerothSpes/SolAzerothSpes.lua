-- Cinq spécialisations. Le serveur (mod-solazeroth, specialisations.cpp) envoie
-- "SPE;actif;possédés;prix_suivant_po;nom1|a/b/c;…;nom5|a/b/c".
-- Commandes : ".solspe etat", ".solspe activer N", ".solspe acheter", ".solspe nom N texte".

local PREFIXE = "SOLSPE"
local EMPLACEMENTS = 5

local etat = { actif = 1, possedes = 1, prix = 0, spes = {} }

local function Commande(texte) SendChatMessage(texte, "SAY") end

------------------------------------------------------------------------
-- Fenêtre
------------------------------------------------------------------------
local cadre = CreateFrame("Frame", "SolAzerothSpesCadre", UIParent)
cadre:SetSize(640, 400)
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
tinsert(UISpecialFrames, "SolAzerothSpesCadre")

local entete = cadre:CreateTexture(nil, "ARTWORK")
entete:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
entete:SetSize(300, 64)
entete:SetPoint("TOP", 0, 12)
local titre = cadre:CreateFontString(nil, "OVERLAY", "GameFontNormal")
titre:SetPoint("TOP", entete, "TOP", 0, -14)
titre:SetText("Spécialisations")

local fermer = CreateFrame("Button", nil, cadre, "UIPanelCloseButton")
fermer:SetPoint("TOPRIGHT", -6, -6)

local aide = cadre:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
aide:SetPoint("BOTTOM", 0, 20)
aide:SetWidth(600)
aide:SetText("Chaque spécialisation garde ses talents, ses glyphes et ses barres d'action. Changement hors combat.")

-- Arbre où la spé a le plus de points, ex. « Protection (5/51/15) », puis son icône et les points par arbre.
local function Resume(repartition)
    local points = { strsplit("/", repartition or "0/0/0") }
    local meilleur, total = 0, 0
    for i = 1, 3 do
        points[i] = tonumber(points[i]) or 0
        total = total + points[i]
        if points[i] > (points[meilleur] or 0) then meilleur = i end
    end
    if total == 0 then return "|cff999999Aucun talent|r", "Interface\\Icons\\INV_Misc_QuestionMark", points end
    local nom, icone = GetTalentTabInfo(meilleur)
    return string.format("%s (%d/%d/%d)", nom or "", points[1], points[2], points[3]), icone, points
end

StaticPopupDialogs["SOLAZEROTH_SPE_NOM"] = {
    text = "Nom de la spécialisation %d :",
    button1 = ACCEPT, button2 = CANCEL,
    hasEditBox = 1, maxLetters = 24,
    OnAccept = function(self, slot)
        local nom = self.editBox:GetText()
        if nom and nom ~= "" then Commande(".solspe nom " .. slot .. " " .. nom) end
    end,
    EditBoxOnEnterPressed = function(self, slot)
        local nom = self:GetText()
        if nom and nom ~= "" then Commande(".solspe nom " .. slot .. " " .. nom) end
        self:GetParent():Hide()
    end,
    timeout = 0, whileDead = 1, hideOnEscape = 1,
}

-- Cartes (V7) : la spécialisation active en grande carte en haut, avec ses trois arbres ; les autres en grille dessous.
local GRANDE_L, GRANDE_H, PETITE_L, PETITE_H = 600, 120, 296, 80
local lignes = {}
for i = 1, EMPLACEMENTS do
    local l = CreateFrame("Frame", nil, cadre)
    l:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                    edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })

    l.icone = l:CreateTexture(nil, "ARTWORK")
    l.icone:SetPoint("TOPLEFT", 10, -10)
    l.nom = l:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    l.nom:SetPoint("TOPLEFT", l.icone, "TOPRIGHT", 10, -2)
    l.nom:SetWidth(170)
    l.nom:SetJustifyH("LEFT")
    l.resume = l:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    l.resume:SetPoint("TOPLEFT", l.nom, "BOTTOMLEFT", 0, -4)
    l.resume:SetWidth(200)
    l.resume:SetJustifyH("LEFT")

    -- Points par arbre, sur la grande carte seulement
    l.barres = {}
    for a = 1, 3 do
        local b = CreateFrame("StatusBar", nil, l)
        b:SetSize(150, 10)
        b:SetPoint("TOPLEFT", 236, -24 - (a - 1) * 30)
        b:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        b:SetStatusBarColor(1, 0.82, 0)
        b:SetMinMaxValues(0, 71)
        local fond = b:CreateTexture(nil, "BACKGROUND")
        fond:SetAllPoints()
        fond:SetTexture(0, 0, 0, 0.6)
        b.texte = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        b.texte:SetPoint("BOTTOMLEFT", b, "TOPLEFT", 0, 2)
        b.valeur = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        b.valeur:SetPoint("LEFT", b, "RIGHT", 6, 0)
        l.barres[a] = b
    end

    l.action = CreateFrame("Button", nil, l, "UIPanelButtonTemplate")
    l.action:SetSize(110, 22)
    l.action:SetPoint("RIGHT", -8, 0)

    l.renommer = CreateFrame("Button", nil, l, "UIPanelButtonTemplate")
    l.renommer:SetSize(60, 22)
    l.renommer:SetPoint("RIGHT", l.action, "LEFT", -4, 0)
    l.renommer:SetText("Nom")
    l.renommer:SetScript("OnClick", function()
        local popup = StaticPopup_Show("SOLAZEROTH_SPE_NOM", i)
        if popup then popup.data = i end
    end)
    lignes[i] = l
end

-- Taille et place d'une carte : la grande en haut, les petites deux par deux.
local function Disposer(l, grande, rang)
    l:ClearAllPoints()
    if grande then
        l:SetSize(GRANDE_L, GRANDE_H)
        l:SetPoint("TOP", 0, -34)
    else
        l:SetSize(PETITE_L, PETITE_H)
        l:SetPoint("TOPLEFT", 20 + ((rang - 1) % 2) * (PETITE_L + 8), -164 - math.floor((rang - 1) / 2) * (PETITE_H + 8))
    end
    local taille = grande and 44 or 30
    l.icone:SetSize(taille, taille)
    -- Petite carte : boutons en bas à droite, pour laisser la largeur au nom.
    l.action:ClearAllPoints()
    if grande then l.action:SetPoint("RIGHT", -8, 0) else l.action:SetPoint("BOTTOMRIGHT", -8, 8) end
    l.nom:SetWidth(grande and 170 or 230)
    l.resume:SetWidth(grande and 200 or 230)
    for _, b in ipairs(l.barres) do
        if grande then b:Show() else b:Hide() end
    end
end

local function Rafraichir()
    local rang = 0
    for i = 1, EMPLACEMENTS do
        local l, spe = lignes[i], etat.spes[i] or {}
        local texte, icone, points = Resume(spe.repartition)
        if i == etat.actif then
            Disposer(l, true)
        else
            rang = rang + 1
            Disposer(l, false, rang)
        end
        l.icone:SetTexture(i <= etat.possedes and icone or "Interface\\PaperDoll\\UI-Backpack-EmptySlot")
        for a, b in ipairs(l.barres) do
            b.texte:SetText(GetTalentTabInfo(a) or "")
            b:SetValue(points[a])
            b.valeur:SetText(points[a])
        end
        l.nom:SetText(spe.nom or ("Spécialisation " .. i))
        l.action:SetScript("OnClick", nil)
        l.action:Enable()
        l.renommer:Show()
        if i == etat.actif then
            l:SetBackdropColor(0.18, 0.14, 0.05, 0.95)
            l:SetBackdropBorderColor(1, 0.82, 0)
            l.resume:SetText(texte)
            l.action:SetText("Active")
            l.action:Disable()
        elseif i <= etat.possedes then
            l:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
            l:SetBackdropBorderColor(0.6, 0.5, 0.3)
            l.resume:SetText(texte)
            l.action:SetText("Activer")
            l.action:SetScript("OnClick", function() Commande(".solspe activer " .. i) end)
        elseif i == etat.possedes + 1 then
            l:SetBackdropColor(0.1, 0.1, 0.1, 0.6)
            l:SetBackdropBorderColor(0.6, 0.6, 0.6)
            l.resume:SetText("|cff999999Emplacement à acheter|r")
            l.action:SetText(etat.prix .. " po")
            l.action:SetScript("OnClick", function() Commande(".solspe acheter") end)
            if GetMoney() < etat.prix * 10000 then l.action:Disable() end
            l.renommer:Hide()
        else
            l:SetBackdropColor(0.05, 0.05, 0.05, 0.5)
            l:SetBackdropBorderColor(0.4, 0.4, 0.4)
            l.resume:SetText("|cff666666Achetez d'abord l'emplacement précédent|r")
            l.action:SetText("Verrouillé")
            l.action:Disable()
            l.renommer:Hide()
        end
    end
end

------------------------------------------------------------------------
-- Échanges avec le serveur
------------------------------------------------------------------------
local evenements = CreateFrame("Frame")
evenements:RegisterEvent("CHAT_MSG_ADDON")
evenements:SetScript("OnEvent", function(self, event, prefixe, message)
    if prefixe ~= PREFIXE then return end
    local champs = { strsplit(";", message) }
    if champs[1] ~= "SPE" then return end
    etat.actif = tonumber(champs[2]) or 1
    etat.possedes = tonumber(champs[3]) or 1
    etat.prix = tonumber(champs[4]) or 0
    for i = 1, EMPLACEMENTS do
        local nom, repartition = strsplit("|", champs[4 + i] or "")
        etat.spes[i] = { nom = nom, repartition = repartition }
    end
    Rafraichir()
end)

local function Basculer()
    if cadre:IsShown() then
        cadre:Hide()
    else
        cadre:Show()
        Rafraichir()
        Commande(".solspe etat")
    end
end

SLASH_SOLAZEROTHSPES1 = "/spe"
SlashCmdList["SOLAZEROTHSPES"] = Basculer

------------------------------------------------------------------------
-- Bouton de la minicarte, déplaçable autour du bord (position mémorisée)
------------------------------------------------------------------------
local RAYON = 80

local bouton = CreateFrame("Button", "SolAzerothSpesBoutonMinicarte", Minimap)
bouton:SetSize(31, 31)
bouton:SetFrameStrata("MEDIUM")
bouton:SetFrameLevel(8)
bouton:RegisterForClicks("LeftButtonUp")
bouton:RegisterForDrag("LeftButton")
bouton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
local iconeBouton = bouton:CreateTexture(nil, "BACKGROUND")
iconeBouton:SetSize(20, 20)
iconeBouton:SetPoint("TOPLEFT", 7, -5)
iconeBouton:SetTexture("Interface\\Icons\\Ability_Marksmanship")
iconeBouton:SetTexCoord(0.08, 0.92, 0.08, 0.92)
local bordure = bouton:CreateTexture(nil, "OVERLAY")
bordure:SetSize(53, 53)
bordure:SetPoint("TOPLEFT")
bordure:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

local function Placer(angle)
    bouton:ClearAllPoints()
    bouton:SetPoint("CENTER", Minimap, "CENTER", RAYON * cos(angle), RAYON * sin(angle))
end

local function SuivreCurseur()
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local echelle = Minimap:GetEffectiveScale()
    local angle = math.deg(math.atan2(cy / echelle - my, cx / echelle - mx))
    SolAzerothSpesDB.angle = angle
    Placer(angle)
end

bouton:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", SuivreCurseur) end)
bouton:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
bouton:SetScript("OnClick", Basculer)
bouton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Spécialisations", 1, 0.82, 0)
    GameTooltip:AddLine("Clic : ouvrir ou fermer", 1, 1, 1)
    GameTooltip:AddLine("Glisser : déplacer le bouton", 1, 1, 1)
    GameTooltip:Show()
end)
bouton:SetScript("OnLeave", function() GameTooltip:Hide() end)

local chargement = CreateFrame("Frame")
chargement:RegisterEvent("ADDON_LOADED")
chargement:SetScript("OnEvent", function(self, event, nom)
    if nom ~= "SolAzerothSpes" then return end
    self:UnregisterEvent("ADDON_LOADED")
    SolAzerothSpesDB = SolAzerothSpesDB or { angle = 200 }
    Placer(SolAzerothSpesDB.angle)
end)
