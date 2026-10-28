-- Talents d'une autre classe (section 3.10, V3c). La fenêtre de talents du jeu n'affiche que les arbres de sa classe :
-- celle-ci affiche un arbre de n'importe quelle autre classe, d'après le serveur (talents_etrangers.cpp, préfixe SOLTAL).
--   ".soltalent onglets <classe>" -> "O;classe;onglet1;onglet2;onglet3;onglet_étranger"
--   ".soltalent arbre <onglet>"   -> "T;talent;rangée;colonne;sorts;prérequis;rang_prérequis;rang" …, puis "ETAT;…"
--   ".soltalent apprendre <talent>" place un point.
--   ".soltalent prix" -> "PRIX;prix_po;prix_suivant_po;n" ; ".soltalent reinitialiser" -> "REINIT" (bouton « Réinitialiser »).
-- Un seul arbre d'une autre classe par personnage (et par spécialisation) ; on en change en réinitialisant ses talents.
-- Ouverture : bouton « Autre classe » de la fenêtre des talents, ou /arbre.

local PREFIXE = "SOLTAL"
local COLONNES, RANGEES = 4, 11

local CLASSES = {
    { id = 1, jeton = "WARRIOR", nom = "Guerrier", arbres = { "Armes", "Fureur", "Protection" } },
    { id = 2, jeton = "PALADIN", nom = "Paladin", arbres = { "Sacré", "Protection", "Vindicte" } },
    { id = 3, jeton = "HUNTER", nom = "Chasseur", arbres = { "Maîtrise des bêtes", "Précision", "Survie" } },
    { id = 4, jeton = "ROGUE", nom = "Voleur", arbres = { "Assassinat", "Combat", "Finesse" } },
    { id = 5, jeton = "PRIEST", nom = "Prêtre", arbres = { "Discipline", "Sacré", "Ombre" } },
    { id = 6, jeton = "DEATHKNIGHT", nom = "Chev. de la mort", arbres = { "Sang", "Givre", "Impie" } },
    { id = 7, jeton = "SHAMAN", nom = "Chaman", arbres = { "Élémentaire", "Amélioration", "Restauration" } },
    { id = 8, jeton = "MAGE", nom = "Mage", arbres = { "Arcanes", "Feu", "Givre" } },
    { id = 9, jeton = "WARLOCK", nom = "Démoniste", arbres = { "Affliction", "Démonologie", "Destruction" } },
    { id = 11, jeton = "DRUID", nom = "Druide", arbres = { "Équilibre", "Combat farouche", "Restauration" } },
}

local classe, page, onglets = nil, 1, {}
local etat = { onglet = 0, etranger = 0, libres = 0, points = 0 }
local talents, enCours = {}, {}
local nomsOnglets = {}   -- onglet -> "Classe : arbre"

local function Commande(texte) SendChatMessage(texte, "SAY") end

------------------------------------------------------------------------
-- Fenêtre
------------------------------------------------------------------------
local cadre = CreateFrame("Frame", "SolAzerothTalentsCadre", UIParent)
cadre:SetSize(430, 670)
cadre:SetPoint("CENTER", 0, 20)
cadre:SetFrameStrata("HIGH")
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
tinsert(UISpecialFrames, "SolAzerothTalentsCadre")

local entete = cadre:CreateTexture(nil, "ARTWORK")
entete:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
entete:SetSize(300, 64)
entete:SetPoint("TOP", 0, 12)
local titre = cadre:CreateFontString(nil, "OVERLAY", "GameFontNormal")
titre:SetPoint("TOP", entete, "TOP", 0, -14)
titre:SetText("Talents d'une autre classe")

local fermer = CreateFrame("Button", nil, cadre, "UIPanelCloseButton")
fermer:SetPoint("TOPRIGHT", -6, -6)

-- Classes (2 rangées) puis arbres de la classe choisie
local boutonsClasse = {}
do
    local _, maClasse = UnitClass("player")
    local n = 0
    for _, c in ipairs(CLASSES) do
        if c.jeton ~= maClasse then
            n = n + 1
            local b = CreateFrame("Button", nil, cadre, "UIPanelButtonTemplate")
            b:SetSize(76, 20)
            b:SetPoint("TOPLEFT", 22 + ((n - 1) % 5) * 78, -36 - math.floor((n - 1) / 5) * 22)
            b:SetText(c.nom)
            b.classe = c
            boutonsClasse[#boutonsClasse + 1] = b
        end
    end
end

local boutonsArbre = {}
for i = 1, 3 do
    local b = CreateFrame("Button", nil, cadre, "UIPanelButtonTemplate")
    b:SetSize(126, 22)
    b:SetPoint("TOPLEFT", 22 + (i - 1) * 130, -84)
    b:Hide()
    boutonsArbre[i] = b
end

local info = cadre:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
info:SetPoint("TOPLEFT", 24, -112)
info:SetWidth(380)
info:SetJustifyH("LEFT")

local avertissement = cadre:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
avertissement:SetPoint("TOPLEFT", info, "BOTTOMLEFT", 0, -4)
avertissement:SetWidth(380)
avertissement:SetJustifyH("LEFT")

-- Grille des talents (4 colonnes, 11 rangées)
local grille = {}
for r = 0, RANGEES - 1 do
    for c = 0, COLONNES - 1 do
        local b = CreateFrame("Button", nil, cadre)
        b:SetSize(34, 34)
        b:SetPoint("TOPLEFT", 90 + c * 64, -150 - r * 42)
        b.icone = b:CreateTexture(nil, "ARTWORK")
        b.icone:SetAllPoints()
        b.bordure = b:CreateTexture(nil, "OVERLAY")
        b.bordure:SetTexture("Interface\\Buttons\\UI-Quickslot2")
        b.bordure:SetSize(60, 60)
        b.bordure:SetPoint("CENTER")
        b.rang = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        b.rang:SetPoint("BOTTOMRIGHT", 6, -4)
        b:SetScript("OnEnter", function(self)
            local t = self.talent
            if not t then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink("spell:" .. t.sorts[math.max(1, t.rang)])
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Rang " .. t.rang .. " / " .. #t.sorts, 1, 0.82, 0)
            if t.rang > 0 and t.rang < #t.sorts then
                GameTooltip:AddLine("Clic : passer au rang " .. (t.rang + 1), 1, 1, 1)
            elseif t.rang == 0 then
                GameTooltip:AddLine("Clic : apprendre le rang 1", 1, 1, 1)
            end
            if self.raison then GameTooltip:AddLine(self.raison, 1, 0.3, 0.3, true) end
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        b:SetScript("OnClick", function(self)
            if self.talent then Commande(".soltalent apprendre " .. self.talent.id) end
        end)
        b:Hide()
        grille[r * COLONNES + c] = b
    end
end

local vide = cadre:CreateFontString(nil, "OVERLAY", "GameFontDisable")
vide:SetPoint("CENTER", 0, -40)
vide:SetWidth(360)
vide:SetText("Choisis une classe, puis un de ses arbres.")

------------------------------------------------------------------------
-- Réinitialisation payante (prix croissant, donné par le serveur)
------------------------------------------------------------------------
local prix = { actuel = 0, suivant = 0 }
local confirmerApresPrix = false

StaticPopupDialogs["SOLAZEROTH_REINIT_TALENTS"] = {
    text = "Réinitialiser tous tes talents pour |cffffd100%d po|r ?\nLa suivante coûtera |cffffd100%d po|r.",
    button1 = YES, button2 = NO,
    OnAccept = function() Commande(".soltalent reinitialiser") end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

local function DemanderReinitialisation()
    confirmerApresPrix = true
    Commande(".soltalent prix")
end

local function InfoBulleReinit(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Réinitialiser les talents", 1, 0.82, 0)
    GameTooltip:AddLine("Retire tous les points (y compris l'arbre d'une autre classe).", 1, 1, 1, true)
    GameTooltip:AddLine("Le prix double à chaque fois, et baisse avec le temps.", 1, 1, 1, true)
    if prix.actuel > 0 then GameTooltip:AddLine("Prix actuel : " .. prix.actuel .. " po", 1, 0.82, 0) end
    GameTooltip:Show()
end

local reinitialiser = CreateFrame("Button", nil, cadre, "UIPanelButtonTemplate")
reinitialiser:SetSize(120, 22)
reinitialiser:SetPoint("BOTTOMRIGHT", -20, 16)
reinitialiser:SetText("Réinitialiser")
reinitialiser:SetScript("OnClick", DemanderReinitialisation)
reinitialiser:SetScript("OnEnter", InfoBulleReinit)
reinitialiser:SetScript("OnLeave", function() GameTooltip:Hide() end)

local function RangDe(id)
    for _, t in ipairs(talents) do if t.id == id then return t.rang end end
    return 0
end

local function Rafraichir()
    for _, b in ipairs(boutonsClasse) do
        if classe and b.classe.id == classe.id then b:LockHighlight() else b:UnlockHighlight() end
    end
    for i, b in ipairs(boutonsArbre) do
        if classe and onglets[i] and onglets[i] > 0 then
            b:SetText(classe.arbres[i])
            if i == page then b:LockHighlight() else b:UnlockHighlight() end
            b:Show()
        else
            b:Hide()
        end
    end

    for _, b in pairs(grille) do b:Hide() b.talent = nil end
    if not classe or #talents == 0 then
        vide:Show()
        info:SetText("")
        avertissement:SetText("")
        return
    end
    vide:Hide()

    local etranger = etat.etranger > 0 and (nomsOnglets[etat.etranger] or "un autre arbre") or "aucun"
    info:SetText(string.format("Arbre d'une autre classe choisi : |cffffffff%s|r\nPoints libres : |cffffd100%d|r   Points dans cet arbre : |cffffd100%d|r",
        etranger, etat.libres, etat.points))
    local bloque = etat.etranger > 0 and etat.etranger ~= etat.onglet
    avertissement:SetText(bloque and "|cffff6060Tu as déjà des points dans un autre arbre étranger : réinitialise tes talents pour changer.|r" or "")

    for _, t in ipairs(talents) do
        local b = grille[t.rangee * COLONNES + t.colonne]
        if b then
            local _, _, icone = GetSpellInfo(t.sorts[1])
            b.talent = t
            b.icone:SetTexture(icone)
            b.rang:SetText(t.rang .. "/" .. #t.sorts)
            local raison
            if bloque then
                raison = "Arbre étranger déjà choisi ailleurs."
            elseif etat.points < t.rangee * 5 then
                raison = "Il faut " .. (t.rangee * 5) .. " points dans cet arbre."
            elseif t.prerequis > 0 and RangDe(t.prerequis) < t.rangPrerequis + 1 then
                raison = "Il faut d'abord le talent prérequis."
            elseif etat.libres == 0 and t.rang < #t.sorts then
                raison = "Plus de point de talent libre."
            end
            b.raison = raison
            b.icone:SetDesaturated(raison ~= nil and t.rang == 0)
            if t.rang >= #t.sorts then
                b.rang:SetTextColor(1, 0.82, 0)
            elseif t.rang > 0 then
                b.rang:SetTextColor(0.25, 1, 0.25)
            else
                b.rang:SetTextColor(raison and 0.5 or 0.25, raison and 0.5 or 1, raison and 0.5 or 0.25)
            end
            b:Show()
        end
    end
end

local function ChoisirArbre(i)
    page = i
    talents = {}
    Rafraichir()
    if onglets[i] and onglets[i] > 0 then Commande(".soltalent arbre " .. onglets[i]) end
end

for _, b in ipairs(boutonsClasse) do
    b:SetScript("OnClick", function(self)
        classe, onglets, talents = self.classe, {}, {}
        Rafraichir()
        Commande(".soltalent onglets " .. self.classe.id)
    end)
end
for i, b in ipairs(boutonsArbre) do
    b:SetScript("OnClick", function() ChoisirArbre(i) end)
end

------------------------------------------------------------------------
-- Échanges avec le serveur
------------------------------------------------------------------------
local evenements = CreateFrame("Frame")
evenements:RegisterEvent("CHAT_MSG_ADDON")
evenements:SetScript("OnEvent", function(self, event, prefixe, message)
    if prefixe ~= PREFIXE then return end
    local champs = { strsplit(";", message) }
    if champs[1] == "O" then
        local id = tonumber(champs[2])
        for _, c in ipairs(CLASSES) do
            if c.id == id then
                for i = 1, 3 do nomsOnglets[tonumber(champs[2 + i]) or 0] = c.nom .. " : " .. c.arbres[i] end
            end
        end
        etat.etranger = tonumber(champs[6]) or 0
        if classe and classe.id == id then
            onglets = { tonumber(champs[3]), tonumber(champs[4]), tonumber(champs[5]) }
            -- Ouvre d'office l'arbre étranger déjà choisi s'il est de cette classe.
            local premier = 1
            for i = 1, 3 do if onglets[i] == etat.etranger then premier = i end end
            ChoisirArbre(premier)
        end
    elseif champs[1] == "T" then
        local sorts = {}
        for s in string.gmatch(champs[5] or "", "%d+") do sorts[#sorts + 1] = tonumber(s) end
        table.insert(enCours, { id = tonumber(champs[2]), rangee = tonumber(champs[3]) or 0, colonne = tonumber(champs[4]) or 0,
                                sorts = sorts, prerequis = tonumber(champs[6]) or 0, rangPrerequis = tonumber(champs[7]) or 0,
                                rang = tonumber(champs[8]) or 0 })
    elseif champs[1] == "ETAT" then
        etat.onglet = tonumber(champs[2]) or 0
        etat.etranger = tonumber(champs[3]) or 0
        etat.libres = tonumber(champs[4]) or 0
        etat.points = tonumber(champs[5]) or 0
        talents, enCours = enCours, {}
        Rafraichir()
    elseif champs[1] == "PRIX" then
        prix.actuel = tonumber(champs[2]) or 0
        prix.suivant = tonumber(champs[3]) or 0
        if confirmerApresPrix then
            confirmerApresPrix = false
            StaticPopup_Show("SOLAZEROTH_REINIT_TALENTS", prix.actuel, prix.suivant)
        end
    elseif champs[1] == "REINIT" then
        if cadre:IsShown() and onglets[page] and onglets[page] > 0 then Commande(".soltalent arbre " .. onglets[page]) end
    end
end)

local function Basculer()
    if cadre:IsShown() then
        cadre:Hide()
    else
        cadre:Show()
        Rafraichir()
    end
end

SLASH_SOLAZEROTHTALENTS1 = "/arbre"
SlashCmdList["SOLAZEROTHTALENTS"] = Basculer

-- Bouton sur la fenêtre des talents du jeu (chargée à la demande)
local chargement = CreateFrame("Frame")
chargement:RegisterEvent("ADDON_LOADED")
chargement:SetScript("OnEvent", function(self, event, nom)
    if nom ~= "Blizzard_TalentUI" then return end
    self:UnregisterEvent("ADDON_LOADED")
    local b = CreateFrame("Button", nil, PlayerTalentFrame, "UIPanelButtonTemplate")
    b:SetSize(100, 22)
    b:SetPoint("TOPRIGHT", PlayerTalentFrame, "TOPRIGHT", -60, -40)
    b:SetText("Autre classe")
    b:SetScript("OnClick", Basculer)
    local r = CreateFrame("Button", nil, PlayerTalentFrame, "UIPanelButtonTemplate")
    r:SetSize(100, 22)
    r:SetPoint("RIGHT", b, "LEFT", -4, 0)
    r:SetText("Réinitialiser")
    r:SetScript("OnClick", DemanderReinitialisation)
    r:SetScript("OnEnter", InfoBulleReinit)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
end)
if IsAddOnLoaded("Blizzard_TalentUI") then chargement:GetScript("OnEvent")(chargement, "ADDON_LOADED", "Blizzard_TalentUI") end
