-- Rang de menace. Le serveur (mod-solazeroth, menace.cpp) envoie
-- "MECA;bit;nom;points;description" pour chaque affixe de mécanique, puis
-- "ETAT;débloqué;prochain;dans_donjon;rang_instance;verrouillé;plafond;affixe;rang_affixe;pv;dégâts;or;affixes;palier"
-- et "OUVRIR" à l'entrée d'un donjon pas encore verrouillé. Choix : ".solmenace choisir <rang>" et
-- ".solmenace affixes <somme des bits>" (affixes de mécanique à cocher, section 4.4).

local PREFIXE = "SOLMENACE"
local RANG_MAX = 10

local etat = { debloque = 0, prochain = 0, donjon = false, rang = 0, verrouille = false, plafond = 10,
               affixe = "", rangAffixe = 2, pv = 0.12, degats = 0.08, gainOr = 0.10, affixes = 0, palier = 0 }
local mecaniques = {}   -- bit -> { nom, points, description }

local function Commande(texte) SendChatMessage(texte, "SAY") end

------------------------------------------------------------------------
-- Fenêtre
------------------------------------------------------------------------
local cadre = CreateFrame("Frame", "SolAzerothMenaceCadre", UIParent)
cadre:SetSize(430, 460)
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
tinsert(UISpecialFrames, "SolAzerothMenaceCadre")

local entete = cadre:CreateTexture(nil, "ARTWORK")
entete:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
entete:SetSize(300, 64)
entete:SetPoint("TOP", 0, 12)
local titre = cadre:CreateFontString(nil, "OVERLAY", "GameFontNormal")
titre:SetPoint("TOP", entete, "TOP", 0, -14)
titre:SetText("Rang de menace")

local fermer = CreateFrame("Button", nil, cadre, "UIPanelCloseButton")
fermer:SetPoint("TOPRIGHT", -6, -6)

local function Texte(gabarit, y)
    local t = cadre:CreateFontString(nil, "OVERLAY", gabarit)
    t:SetPoint("TOP", 0, y)
    t:SetWidth(390)
    return t
end

local situation = Texte("GameFontHighlight", -38)
local debloque = Texte("GameFontNormal", -62)
local affixe = Texte("GameFontHighlightSmall", -82)

local boutons = {}
for rang = 0, RANG_MAX do
    local b = CreateFrame("Button", nil, cadre, "UIPanelButtonTemplate")
    b:SetSize(56, 30)
    local ligne, colonne = math.floor(rang / 6), rang % 6
    b:SetPoint("TOPLEFT", 30 + colonne * 62, -108 - ligne * 38)
    b:SetText(tostring(rang))
    b.rang = rang
    b:SetScript("OnClick", function(self) Commande(".solmenace choisir " .. self.rang) end)
    boutons[rang] = b
end

local effet = Texte("GameFontHighlight", -196)
effet:SetHeight(60)
effet:SetJustifyV("TOP")

-- Affixes de mécanique à cocher : leurs points s'ajoutent au rang pour le palier de butin.
local titreMeca = Texte("GameFontNormal", -262)
titreMeca:SetText("Affixes de mécanique (leurs points s'ajoutent au rang pour le butin)")
local BITS = { 1, 2, 4, 8 }
local cases = {}
for i, bit in ipairs(BITS) do
    local c = CreateFrame("CheckButton", "SolAzerothMenaceAffixe" .. bit, cadre, "UICheckButtonTemplate")
    c:SetSize(24, 24)
    c:SetPoint("TOPLEFT", 30 + ((i - 1) % 2) * 190, -282 - math.floor((i - 1) / 2) * 26)
    c.bit = bit
    c.texte = _G["SolAzerothMenaceAffixe" .. bit .. "Text"]
    c:SetScript("OnClick", function(self)
        local total = 0
        for _, autre in ipairs(cases) do
            if autre:GetChecked() then total = total + autre.bit end
        end
        Commande(".solmenace affixes " .. total)
    end)
    c:SetScript("OnEnter", function(self)
        local m = mecaniques[self.bit]
        if not m then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(string.format("%s (%d point%s)", m.nom, m.points, m.points > 1 and "s" or ""))
        GameTooltip:AddLine(m.description, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    c:SetScript("OnLeave", function() GameTooltip:Hide() end)
    cases[i] = c
end
local palier = Texte("GameFontHighlight", -340)

local aide = Texte("GameFontDisableSmall", -400)
aide:SetText("Le rang réglé s'applique à chaque donjon réinitialisé (.reinitialiser), puis se verrouille au premier combat.\nRéussir un rang dans 3 donjons différents débloque le suivant.")

local function Effet(rang)
    if rang == 0 then return "Rang 0 : difficulté de base." end
    local t = string.format("Rang %d : monstres |cffff8080+%d %% de résistance|r et |cffff8080+%d %% de dégâts|r, |cffffd100+%d %% d'or|r, +%d Marques par boss.",
        rang, math.floor(etat.pv * rang * 100 + 0.5), math.floor(etat.degats * rang * 100 + 0.5),
        math.floor(etat.gainOr * rang * 100 + 0.5), rang)
    if rang >= etat.rangAffixe then
        t = t .. "\nAffixe : |cffff8040" .. etat.affixe .. "|r"
    end
    return t
end

local function Rafraichir()
    if etat.donjon then
        if etat.verrouille then
            situation:SetText(string.format("Ce donjon : |cffff8040rang %d, verrouillé|r. Ton réglage vaudra pour le prochain.", etat.rang))
        else
            situation:SetText(string.format("Ce donjon : |cff00ff00rang %d|r, modifiable jusqu'au premier combat.", etat.rang))
        end
    else
        situation:SetText(string.format("Prochain donjon réinitialisé : |cff00ff00rang %d|r.", etat.prochain))
    end
    debloque:SetText(string.format("Rang débloqué sur le compte : %d", etat.debloque))
    affixe:SetText(string.format("Affixe de la semaine, dès le rang %d : %s", etat.rangAffixe, etat.affixe))

    local choisi = (etat.donjon and not etat.verrouille) and etat.rang or etat.prochain
    for rang, b in pairs(boutons) do
        local accessible = rang <= etat.debloque and (not etat.donjon or etat.verrouille or rang <= etat.plafond)
        if accessible then b:Enable() else b:Disable() end
        if rang == choisi then b:LockHighlight() else b:UnlockHighlight() end
    end
    effet:SetText(Effet(choisi))

    -- Dans un donjon verrouillé, les cases montrent les affixes de l'instance et ne se changent plus.
    local figees = etat.donjon and etat.verrouille
    for _, c in ipairs(cases) do
        local m = mecaniques[c.bit]
        c.texte:SetText(m and string.format("%s (%d pt%s)", m.nom, m.points, m.points > 1 and "s" or "") or "?")
        c:SetChecked(bit.band(etat.affixes, c.bit) ~= 0)
        if figees then c:Disable() else c:Enable() end
    end
    palier:SetText(string.format("Palier de butin : |cff00ff00%d|r (rang + points des affixes, plafonné au rang maximal du donjon)", etat.palier))
end

------------------------------------------------------------------------
-- Cadre du défi de boss en cours (messages DEFI, DEFI_ECHEC, DEFI_REUSSI, DEFI_ANNULE)
------------------------------------------------------------------------
local defi = CreateFrame("Frame", "SolAzerothDefiBossCadre", UIParent)
defi:SetSize(320, 74)
defi:SetPoint("TOP", 0, -140)
defi:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
defi:SetBackdropColor(0.1, 0.05, 0, 0.85)
defi:SetBackdropBorderColor(1, 0.82, 0)
defi:EnableMouse(true)
defi:SetMovable(true)
defi:RegisterForDrag("LeftButton")
defi:SetScript("OnDragStart", defi.StartMoving)
defi:SetScript("OnDragStop", defi.StopMovingOrSizing)
defi:Hide()

defi.titre = defi:CreateFontString(nil, "OVERLAY", "GameFontNormal")
defi.titre:SetPoint("TOP", 0, -8)
defi.texte = defi:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
defi.texte:SetPoint("TOP", defi.titre, "BOTTOM", 0, -4)
defi.texte:SetWidth(300)
defi.etat = defi:CreateFontString(nil, "OVERLAY", "GameFontNormal")
defi.etat:SetPoint("BOTTOM", 0, 8)

defi:SetScript("OnUpdate", function(self, ecoule)
    if self.fin then
        self.fin = self.fin - ecoule
        if self.fin <= 0 then self.fin = nil self:Hide() end
    elseif self.chrono then
        local reste = self.chrono - (GetTime() - self.debut)
        if reste > 0 then
            self.etat:SetText(string.format("|cffffd100%d s|r", math.ceil(reste)))
        else
            self.etat:SetText("|cffff4040Temps écoulé|r")
        end
    end
end)

local function FinDefi(texte, r, v, b)
    defi.etat:SetText(texte)
    defi:SetBackdropBorderColor(r, v, b)
    defi.chrono = nil
    defi.fin = 8
end

local function MessageDefi(champs)
    local type = champs[1]
    if type == "DEFI" then
        defi.titre:SetText("Défi de boss : " .. (champs[2] or ""))
        defi.texte:SetText((champs[3] or "") .. "  (+" .. (champs[5] or "?") .. " Marques)")
        local chrono = tonumber(champs[4]) or 0
        defi.chrono = chrono > 0 and chrono or nil
        defi.debut = GetTime()
        defi.fin = nil
        defi.etat:SetText(defi.chrono and "" or "|cff00ff00En cours|r")
        defi:SetBackdropBorderColor(1, 0.82, 0)
        defi:Show()
    elseif type == "DEFI_ECHEC" then
        FinDefi("|cffff4040Échoué : " .. (champs[2] or "") .. "|r", 1, 0.25, 0.25)
    elseif type == "DEFI_REUSSI" then
        FinDefi("|cff00ff00Réussi ! +" .. (champs[2] or "?") .. " Marques|r", 0.25, 1, 0.25)
        PlaySound("LEVELUPSOUND")
    elseif type == "DEFI_ANNULE" then
        FinDefi("|cff999999Annulé|r", 0.6, 0.6, 0.6)
    end
end

------------------------------------------------------------------------
-- Échanges avec le serveur
------------------------------------------------------------------------
-- Les messages envoyés pendant l'écran de chargement peuvent se perdre : à chaque arrivée dans une zone,
-- l'addon redemande l'état une seconde plus tard et ouvre la fenêtre dans un donjon pas encore verrouillé.
local ouvertureAuto, attente = false, 0
local function DemanderPlusTard(self, ecoule)
    attente = attente + ecoule
    if attente >= 1.5 then
        self:SetScript("OnUpdate", nil)
        Commande(".solmenace etat")
    end
end

local evenements = CreateFrame("Frame")
evenements:RegisterEvent("CHAT_MSG_ADDON")
evenements:RegisterEvent("PLAYER_ENTERING_WORLD")
evenements:SetScript("OnEvent", function(self, event, prefixe, message)
    if event == "PLAYER_ENTERING_WORLD" then
        ouvertureAuto, attente = true, 0
        self:SetScript("OnUpdate", DemanderPlusTard)
        return
    end
    if prefixe ~= PREFIXE then return end
    local champs = { strsplit(";", message) }
    if champs[1] == "ETAT" then
        etat.debloque = tonumber(champs[2]) or 0
        etat.prochain = tonumber(champs[3]) or 0
        etat.donjon = champs[4] == "1"
        etat.rang = tonumber(champs[5]) or 0
        etat.verrouille = champs[6] == "1"
        etat.plafond = tonumber(champs[7]) or RANG_MAX
        etat.affixe = champs[8] or ""
        etat.rangAffixe = tonumber(champs[9]) or 2
        etat.pv = tonumber(champs[10]) or etat.pv
        etat.degats = tonumber(champs[11]) or etat.degats
        etat.gainOr = tonumber(champs[12]) or etat.gainOr
        etat.affixes = tonumber(champs[13]) or 0
        etat.palier = tonumber(champs[14]) or etat.rang
        Rafraichir()
        if ouvertureAuto then
            ouvertureAuto = false
            if etat.donjon and not etat.verrouille then cadre:Show() end
        end
    elseif champs[1] == "MECA" then
        local b = tonumber(champs[2])
        if b then
            mecaniques[b] = { nom = champs[3] or "?", points = tonumber(champs[4]) or 0, description = champs[5] or "" }
        end
    elseif champs[1] == "OUVRIR" then
        cadre:Show()
        Rafraichir()
    elseif strsub(champs[1], 1, 4) == "DEFI" then
        MessageDefi(champs)
    end
end)

local function Basculer()
    if cadre:IsShown() then
        cadre:Hide()
    else
        cadre:Show()
        Rafraichir()
        Commande(".solmenace etat")
    end
end

SLASH_SOLAZEROTHMENACE1 = "/rang"
SlashCmdList["SOLAZEROTHMENACE"] = Basculer

------------------------------------------------------------------------
-- Bouton de la minicarte, déplaçable autour du bord (position mémorisée)
------------------------------------------------------------------------
local RAYON = 80

local bouton = CreateFrame("Button", "SolAzerothMenaceBoutonMinicarte", Minimap)
bouton:SetSize(31, 31)
bouton:SetFrameStrata("MEDIUM")
bouton:SetFrameLevel(8)
bouton:RegisterForClicks("LeftButtonUp")
bouton:RegisterForDrag("LeftButton")
bouton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
local iconeBouton = bouton:CreateTexture(nil, "BACKGROUND")
iconeBouton:SetSize(20, 20)
iconeBouton:SetPoint("TOPLEFT", 7, -5)
iconeBouton:SetTexture("Interface\\Icons\\Spell_Holy_SealOfMight")
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
    SolAzerothMenaceDB.angle = angle
    Placer(angle)
end

bouton:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", SuivreCurseur) end)
bouton:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
bouton:SetScript("OnClick", Basculer)
bouton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Rang de menace", 1, 0.82, 0)
    GameTooltip:AddLine("Clic : ouvrir ou fermer", 1, 1, 1)
    GameTooltip:AddLine("Glisser : déplacer le bouton", 1, 1, 1)
    GameTooltip:Show()
end)
bouton:SetScript("OnLeave", function() GameTooltip:Hide() end)

local chargement = CreateFrame("Frame")
chargement:RegisterEvent("ADDON_LOADED")
chargement:SetScript("OnEvent", function(self, event, nom)
    if nom ~= "SolAzerothMenace" then return end
    self:UnregisterEvent("ADDON_LOADED")
    SolAzerothMenaceDB = SolAzerothMenaceDB or { angle = 120 }
    Placer(SolAzerothMenaceDB.angle)
end)
