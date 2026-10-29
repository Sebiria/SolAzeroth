-- Codex (sections 1.3 et 7.1, V4) : pourcentage de chaque ligne et des trois fins, pour tout le compte.
-- Le serveur (codex.cpp, préfixe SOLCODEX) envoie, sur ".solcodex" :
-- "L;fin;nom;heures;pourcent;détail" pour chaque ligne, puis "FINS;histoire;maître;cent".
-- Ouverture : menu Sol'Azeroth, ou /codex.

local PREFIXE = "SOLCODEX"
local FINS = {
    { nom = "Histoire", heures = 250, couleur = { 0.3, 0.7, 1 } },
    { nom = "Maître",   heures = 820, couleur = { 1, 0.6, 0.1 } },
    { nom = "100 %",    heures = 2550, couleur = { 0.7, 0.4, 1 } },
}
local LIGNES, HAUTEUR = 13, 34

local lignes, enCours = {}, {}
local fins = { 0, 0, 0 }

local function Commande(texte) SendChatMessage(texte, "SAY") end

------------------------------------------------------------------------
-- Fenêtre
------------------------------------------------------------------------
local cadre = CreateFrame("Frame", "SolAzerothCodexCadre", UIParent)
cadre:SetSize(660, 600)
cadre:SetPoint("CENTER", 0, 20)
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
tinsert(UISpecialFrames, "SolAzerothCodexCadre")

local entete = cadre:CreateTexture(nil, "ARTWORK")
entete:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
entete:SetSize(300, 64)
entete:SetPoint("TOP", 0, 12)
local titre = cadre:CreateFontString(nil, "OVERLAY", "GameFontNormal")
titre:SetPoint("TOP", entete, "TOP", 0, -14)
titre:SetText("Codex du compte")

local fermer = CreateFrame("Button", nil, cadre, "UIPanelCloseButton")
fermer:SetPoint("TOPRIGHT", -6, -6)

local function Barre(parent, largeur, hauteur)
    local b = CreateFrame("StatusBar", nil, parent)
    b:SetSize(largeur, hauteur)
    b:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    b:SetMinMaxValues(0, 100)
    b.fond = b:CreateTexture(nil, "BACKGROUND")
    b.fond:SetAllPoints()
    b.fond:SetTexture(0, 0, 0, 0.5)
    b.texte = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.texte:SetPoint("CENTER")
    return b
end

-- Deux pages : Codex et Renom (onglets sous la fenêtre)
local pageCodex = CreateFrame("Frame", nil, cadre)
pageCodex:SetAllPoints()
local pageRenom = CreateFrame("Frame", nil, cadre)
pageRenom:SetAllPoints()
pageRenom:Hide()

-- Les trois fins, en haut
local barresFins = {}
for i, f in ipairs(FINS) do
    local nom = pageCodex:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nom:SetTextColor(0.32, 0.08, 0.03)
    nom:SetPoint("TOPLEFT", 26, -40 - (i - 1) * 24)
    nom:SetWidth(170)
    nom:SetJustifyH("LEFT")
    nom:SetText(string.format("Fin « %s » (%d h)", f.nom, f.heures))
    local b = Barre(pageCodex, 400, 16)
    b:SetPoint("TOPLEFT", 200, -40 - (i - 1) * 24)
    b:SetStatusBarColor(unpack(f.couleur))
    barresFins[i] = b
end

local aide = pageCodex:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
aide:SetTextColor(0.3, 0.18, 0.07)
aide:SetPoint("TOPLEFT", 26, -112)
aide:SetWidth(600)
aide:SetJustifyH("LEFT")
aide:SetText("Chaque fin inclut les précédentes. Ce qui n'existe pas encore dans le jeu n'est pas compté.")

-- Lignes du Codex
local rangees = {}
for i = 1, LIGNES do
    local l = CreateFrame("Frame", nil, pageCodex)
    l:SetSize(610, HAUTEUR - 3)
    l:SetPoint("TOPLEFT", 24, -130 - (i - 1) * HAUTEUR)
    l:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                    edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    l:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    l.nom = l:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    l.nom:SetPoint("TOPLEFT", 8, -4)
    l.nom:SetWidth(330)
    l.nom:SetJustifyH("LEFT")
    l.detail = l:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    l.detail:SetPoint("TOPLEFT", l.nom, "BOTTOMLEFT", 0, -1)
    l.detail:SetSize(590, 12)
    l.detail:SetJustifyH("LEFT")
    l.barre = Barre(l, 120, 12)
    l.barre:SetPoint("TOPRIGHT", -8, -5)
    l:EnableMouse(true)
    l:SetScript("OnEnter", function(self)
        if not self.donnees then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.donnees.nom, 1, 0.82, 0)
        GameTooltip:AddLine(self.donnees.detail, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    l:SetScript("OnLeave", function() GameTooltip:Hide() end)
    l:Hide()
    rangees[i] = l
end

local function Rafraichir()
    for i, b in ipairs(barresFins) do
        b:SetValue(fins[i])
        b.texte:SetText(string.format("%.1f %%", fins[i]))
    end
    for i = 1, LIGNES do
        local l, d = rangees[i], lignes[i]
        l.donnees = d
        if d then
            local f = FINS[d.fin] or FINS[3]
            l.nom:SetText(string.format("%s |cffc9b88f(%d h, fin « %s »)|r", d.nom, d.heures, f.nom))
            l.detail:SetText(d.detail)
            l.barre:SetValue(d.pourcent)
            l.barre:SetStatusBarColor(unpack(d.pourcent >= 100 and { 0.2, 0.8, 0.2 } or f.couleur))
            l.barre.texte:SetText(string.format("%.0f %%", d.pourcent))
            l:SetBackdropBorderColor(f.couleur[1], f.couleur[2], f.couleur[3])
            l:Show()
        else
            l:Hide()
        end
    end
end

------------------------------------------------------------------------
-- Page Renom (section 7.2, renom.cpp, préfixe SOLRENOM) :
-- "ETAT;rang;points;seuil_suivant;affixe", "R;rang;nom;seuil;récompense;état", "FIN" ; "RANG;n" à chaque nouveau rang.
-- État : 0 à venir, 1 acquis, 2 à réclamer, 3 réclamé, 4 plus tard.
------------------------------------------------------------------------
local renom = { rang = 0, points = 0, suivant = 100, affixe = 0, rangs = {} }
local renomEnCours = {}
local AFFIXES = { [0] = "celui de la semaine", [1] = "Fortifié (monstres hors boss plus résistants et plus forts)", [2] = "Tyrannique (boss plus résistants et plus forts)" }
local ETATS = { [0] = "|cffc9b88fÀ venir|r", [1] = "|cff40ff40Acquis|r", [3] = "|cff40ff40Réclamé|r", [4] = "|cffc9b88fPlus tard|r" }

local renomTitre = pageRenom:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
renomTitre:SetTextColor(0.32, 0.08, 0.03)
renomTitre:SetPoint("TOPLEFT", 26, -40)
local renomBarre = Barre(pageRenom, 600, 16)
renomBarre:SetPoint("TOPLEFT", 26, -66)
renomBarre:SetStatusBarColor(1, 0.82, 0)
local renomAide = pageRenom:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
renomAide:SetTextColor(0.3, 0.18, 0.07)
renomAide:SetPoint("TOPLEFT", 26, -90)
renomAide:SetWidth(600)
renomAide:SetJustifyH("LEFT")
renomAide:SetText("10 points par heure de Codex accomplie, 5 par contrat terminé. Le Renom vaut pour tout le compte et ne redescend jamais.")

local lignesRenom = {}
for i = 1, 10 do
    local l = CreateFrame("Frame", nil, pageRenom)
    l:SetSize(610, 40)
    l:SetPoint("TOPLEFT", 24, -110 - (i - 1) * 43)
    l:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                    edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    l.nom = l:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    l.nom:SetPoint("TOPLEFT", 8, -5)
    l.texte = l:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    l.texte:SetPoint("TOPLEFT", l.nom, "BOTTOMLEFT", 0, -3)
    l.texte:SetWidth(440)
    l.texte:SetJustifyH("LEFT")
    l.etat = l:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    l.etat:SetPoint("RIGHT", -12, 0)
    l.bouton = CreateFrame("Button", nil, l, "UIPanelButtonTemplate")
    l.bouton:SetSize(130, 22)
    l.bouton:SetPoint("RIGHT", -8, 0)
    l.bouton:Hide()
    lignesRenom[i] = l
end

local function RafraichirRenom()
    local seuilActuel = 0
    for _, r in ipairs(renom.rangs) do if r.rang == renom.rang then seuilActuel = r.seuil end end
    renomTitre:SetText(renom.rang > 0 and string.format("Renom : rang %d", renom.rang) or "Renom : aucun rang")
    for _, r in ipairs(renom.rangs) do
        if r.rang == renom.rang then renomTitre:SetText(string.format("Renom : rang %d, %s", r.rang, r.nom)) end
    end
    local etendue = math.max(1, renom.suivant - seuilActuel)
    renomBarre:SetValue(renom.rang >= 10 and 100 or math.min(100, 100 * (renom.points - seuilActuel) / etendue))
    renomBarre.texte:SetText(renom.rang >= 10 and (renom.points .. " points, rang maximal")
        or string.format("%d points (prochain rang à %d)", renom.points, renom.suivant))

    for i, l in ipairs(lignesRenom) do
        local r = renom.rangs[i]
        if r then
            l.nom:SetText(string.format("Rang %d : %s |cffc9b88f(%d points)|r", r.rang, r.nom, r.seuil))
            l.texte:SetText(r.texte)
            local acquis = r.etat == 1 or r.etat == 2 or r.etat == 3
            l:SetBackdropColor(acquis and 0.1 or 0.08, acquis and 0.25 or 0.08, acquis and 0.1 or 0.08, 0.85)
            l:SetBackdropBorderColor(acquis and 0.3 or 0.5, acquis and 1 or 0.5, acquis and 0.3 or 0.5)
            l.bouton:Hide()
            l.etat:SetText(ETATS[r.etat] or "")
            if r.etat == 2 then
                l.etat:SetText("")
                l.bouton:SetText("Réclamer")
                l.bouton:SetScript("OnClick", function() Commande(".solrenom reclamer " .. r.rang) end)
                l.bouton:SetScript("OnEnter", nil)
                l.bouton:Show()
            elseif r.rang == 5 and r.etat == 1 then
                -- Affixe au menu : chaque clic passe au suivant (semaine, Fortifié, Tyrannique).
                l.etat:SetText("")
                l.bouton:SetText("Affixe : " .. (renom.affixe == 0 and "semaine" or renom.affixe == 1 and "Fortifié" or "Tyrannique"))
                l.bouton:SetScript("OnClick", function() Commande(".solrenom affixe " .. ((renom.affixe + 1) % 3)) end)
                l.bouton:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText("Affixe : " .. AFFIXES[renom.affixe], 1, 0.82, 0, 1, true)
                    GameTooltip:AddLine("Clic : passer au suivant. S'applique aux instances ouvertes ensuite, dès le rang 2.", 1, 1, 1, true)
                    GameTooltip:Show()
                end)
                l.bouton:SetScript("OnLeave", function() GameTooltip:Hide() end)
                l.bouton:Show()
            end
            l:Show()
        else
            l:Hide()
        end
    end
end

local function RecevoirRenom(message)
    local champs = { strsplit(";", message) }
    if champs[1] == "ETAT" then
        renom.rang = tonumber(champs[2]) or 0
        renom.points = tonumber(champs[3]) or 0
        renom.suivant = tonumber(champs[4]) or 100
        renom.affixe = tonumber(champs[5]) or 0
    elseif champs[1] == "R" then
        table.insert(renomEnCours, { rang = tonumber(champs[2]) or 0, nom = champs[3] or "?", seuil = tonumber(champs[4]) or 0,
                                     texte = champs[5] or "", etat = tonumber(champs[6]) or 0 })
    elseif champs[1] == "FIN" then
        renom.rangs, renomEnCours = renomEnCours, {}
        if cadre:IsShown() then RafraichirRenom() end
    elseif champs[1] == "RANG" then
        PlaySound("LEVELUPSOUND")
        if cadre:IsShown() then Commande(".solrenom liste") end
    end
end

-- Onglets sous la fenêtre
local function Onglet(texte, page, x)
    local b = CreateFrame("Button", nil, cadre, "UIPanelButtonTemplate")
    b:SetSize(110, 24)
    b:SetPoint("TOPLEFT", cadre, "BOTTOMLEFT", x, 4)
    b:SetText(texte)
    b.page = page
    return b
end
local onglets = { Onglet("Codex", pageCodex, 20), Onglet("Renom", pageRenom, 134) }
for _, o in ipairs(onglets) do
    o:SetScript("OnClick", function(self)
        for _, autre in ipairs(onglets) do
            autre.page:Hide()
            autre:UnlockHighlight()
        end
        self.page:Show()
        self:LockHighlight()
    end)
end
onglets[1]:LockHighlight()

------------------------------------------------------------------------
-- Échanges avec le serveur
------------------------------------------------------------------------
local evenements = CreateFrame("Frame")
evenements:RegisterEvent("CHAT_MSG_ADDON")
evenements:SetScript("OnEvent", function(self, event, prefixe, message)
    if prefixe == "SOLRENOM" then return RecevoirRenom(message) end
    if prefixe ~= PREFIXE then return end
    local champs = { strsplit(";", message) }
    if champs[1] == "L" then
        table.insert(enCours, { fin = tonumber(champs[2]) or 3, nom = champs[3] or "?", heures = tonumber(champs[4]) or 0,
                                pourcent = tonumber(champs[5]) or 0, detail = champs[6] or "" })
    elseif champs[1] == "FINS" then
        fins = { tonumber(champs[2]) or 0, tonumber(champs[3]) or 0, tonumber(champs[4]) or 0 }
        lignes, enCours = enCours, {}
        if cadre:IsShown() then Rafraichir() end
    end
end)

local function Basculer()
    if cadre:IsShown() then
        cadre:Hide()
    else
        cadre:Show()
        Rafraichir()
        RafraichirRenom()
        Commande(".solcodex")
        Commande(".solrenom liste")
    end
end

SLASH_SOLAZEROTHCODEX1 = "/codex"
SlashCmdList["SOLAZEROTHCODEX"] = Basculer
