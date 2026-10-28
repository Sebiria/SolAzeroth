-- Ressources des autres classes (section 3.9, V3b). Le client n'affiche que la ressource principale de la classe.
-- Dès que le grimoire contient un sort qui coûte de la rage, de l'énergie ou de la puissance runique (autre que la
-- ressource principale), une barre apparaît sous le cadre du joueur. Les points de combo s'affichent aussi quand
-- le cadre d'origine ne les montre pas. Le cadre se déplace à la souris (position mémorisée).
-- Runes : le client ne les affiche qu'au chevalier de la mort. Pour les autres classes qui connaissent un sort à runes,
-- le serveur (ressources.cpp) envoie "RUNES;type:recharge_ms,…" (préfixe SOLRES) et l'addon affiche les 6 runes.

local TYPES = {
    { type = 1, cle = "RAGE",        nom = "Rage" },
    { type = 3, cle = "ENERGY",      nom = "Énergie" },
    { type = 6, cle = "RUNIC_POWER", nom = "Puissance runique" },
}

local cadre = CreateFrame("Frame", "SolAzerothRessourcesCadre", UIParent)
cadre:SetSize(150, 10)
cadre:SetPoint("TOPLEFT", PlayerFrame, "BOTTOMLEFT", 106, 22)
cadre:SetMovable(true)
cadre:EnableMouse(true)
cadre:RegisterForDrag("LeftButton")
cadre:SetScript("OnDragStart", cadre.StartMoving)
cadre:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relatif, x, y = self:GetPoint()
    SolAzerothRessourcesDB.position = { point, relatif, x, y }
end)

local barres = {}
for i, t in ipairs(TYPES) do
    local b = CreateFrame("StatusBar", nil, cadre)
    b:SetSize(120, 11)
    b:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    local couleur = PowerBarColor[t.cle] or { r = 1, g = 1, b = 1 }
    b:SetStatusBarColor(couleur.r, couleur.g, couleur.b)
    b.fond = b:CreateTexture(nil, "BACKGROUND")
    b.fond:SetAllPoints()
    b.fond:SetTexture(0, 0, 0, 0.6)
    b.texte = b:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
    b.texte:SetPoint("CENTER", 0, 0)
    b:Hide()
    b.info = t
    barres[i] = b
end

-- Points de combo (5 pastilles)
local combo = CreateFrame("Frame", nil, cadre)
combo:SetSize(120, 10)
combo.pastilles = {}
for i = 1, 5 do
    local p = combo:CreateTexture(nil, "OVERLAY")
    p:SetSize(12, 12)
    p:SetPoint("LEFT", (i - 1) * 16, 0)
    p:SetTexture("Interface\\ComboFrame\\ComboPoint")
    p:SetTexCoord(0, 0.375, 0, 1)
    combo.pastilles[i] = p
end
combo:Hide()

-- Runes (6 icônes ; types du serveur : 0 sang, 1 impie, 2 givre, 3 mort)
local TEXTURES_RUNES = {
    [0] = "Interface\\PlayerFrame\\UI-PlayerFrame-Deathknight-Blood",
    [1] = "Interface\\PlayerFrame\\UI-PlayerFrame-Deathknight-Unholy",
    [2] = "Interface\\PlayerFrame\\UI-PlayerFrame-Deathknight-Frost",
    [3] = "Interface\\PlayerFrame\\UI-PlayerFrame-Deathknight-Death",
}
local runes = CreateFrame("Frame", nil, cadre)
runes:SetSize(120, 18)
runes.icones = {}
for i = 1, 6 do
    local r = CreateFrame("Frame", nil, runes)
    r:SetSize(18, 18)
    r:SetPoint("LEFT", (i - 1) * 20, 0)
    r.texture = r:CreateTexture(nil, "ARTWORK")
    r.texture:SetAllPoints()
    r.recharge = CreateFrame("Cooldown", nil, r, "CooldownFrameTemplate")
    r.recharge:SetAllPoints()
    runes.icones[i] = r
end
runes:Hide()
local runesRecues = false

local function AfficherRunes(texte)
    local i = 0
    for type, recharge in string.gmatch(texte or "", "(%d+):(%d+)") do
        i = i + 1
        local r = runes.icones[i]
        if not r then break end
        r.texture:SetTexture(TEXTURES_RUNES[tonumber(type)] or TEXTURES_RUNES[3])
        recharge = tonumber(recharge) or 0
        if recharge > 0 then
            CooldownFrame_SetTimer(r.recharge, GetTime(), recharge / 1000, 1)
            r.texture:SetAlpha(0.4)
            r.fin = GetTime() + recharge / 1000
        else
            r.recharge:Hide()
            r.texture:SetAlpha(1)
            r.fin = nil
        end
    end
    runesRecues = true
end

local actives = {}

-- Ressources consommées par les sorts du grimoire, autres que la ressource principale.
local function Analyser()
    actives = {}
    local principale = UnitPowerType("player")
    for onglet = 1, GetNumSpellTabs() do
        local _, _, debut, nombre = GetSpellTabInfo(onglet)
        for i = debut + 1, debut + nombre do
            local _, _, _, cout, _, typeRessource = GetSpellInfo(i, BOOKTYPE_SPELL)
            if typeRessource == 5 then
                -- Sort à runes : runes, et la puissance runique qu'elles génèrent.
                actives[5] = true
                actives[6] = true
            elseif cout and cout > 0 and typeRessource and typeRessource ~= principale then
                actives[typeRessource] = true
            end
        end
    end
end

local function Rafraichir()
    local y = 0
    for _, b in ipairs(barres) do
        local t = b.info.type
        if actives[t] and t ~= UnitPowerType("player") then
            local valeur, maximum = UnitPower("player", t), UnitPowerMax("player", t)
            b:SetMinMaxValues(0, math.max(1, maximum))
            b:SetValue(valeur)
            b.texte:SetText(b.info.nom .. " " .. valeur .. " / " .. maximum)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", 0, -y)
            b:Show()
            y = y + 13
        else
            b:Hide()
        end
    end
    local _, classe = UnitClass("player")
    if actives[5] and runesRecues and classe ~= "DEATHKNIGHT" then
        for _, r in ipairs(runes.icones) do
            if r.fin and GetTime() >= r.fin then
                r.fin = nil
                r.texture:SetAlpha(1)
            end
        end
        runes:ClearAllPoints()
        runes:SetPoint("TOPLEFT", 0, -y)
        runes:Show()
        y = y + 20
    else
        runes:Hide()
    end
    local points = GetComboPoints("player", "target")
    if points > 0 and not ComboFrame:IsShown() then
        for i = 1, 5 do combo.pastilles[i]:SetAlpha(i <= points and 1 or 0.15) end
        combo:ClearAllPoints()
        combo:SetPoint("TOPLEFT", 0, -y)
        combo:Show()
        y = y + 14
    else
        combo:Hide()
    end
    cadre:SetHeight(math.max(1, y))
end

cadre:SetScript("OnUpdate", function(self, ecoule)
    self.attente = (self.attente or 0) + ecoule
    if self.attente >= 0.1 then
        self.attente = 0
        Rafraichir()
    end
end)

local evenements = CreateFrame("Frame")
evenements:RegisterEvent("PLAYER_ENTERING_WORLD")
evenements:RegisterEvent("SPELLS_CHANGED")
evenements:RegisterEvent("LEARNED_SPELL_IN_TAB")
evenements:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
evenements:RegisterEvent("ADDON_LOADED")
evenements:RegisterEvent("CHAT_MSG_ADDON")
evenements:SetScript("OnEvent", function(self, event, nom, message)
    if event == "CHAT_MSG_ADDON" then
        if nom == "SOLRES" and strsub(message or "", 1, 6) == "RUNES;" then
            AfficherRunes(strsub(message, 7))
            Rafraichir()
        end
        return
    end
    if event == "ADDON_LOADED" then
        if nom ~= "SolAzerothRessources" then return end
        SolAzerothRessourcesDB = SolAzerothRessourcesDB or {}
        local p = SolAzerothRessourcesDB.position
        if p then
            cadre:ClearAllPoints()
            cadre:SetPoint(p[1], UIParent, p[2], p[3], p[4])
        end
        return
    end
    Analyser()
    Rafraichir()
end)
