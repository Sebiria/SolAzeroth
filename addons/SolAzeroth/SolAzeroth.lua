-- Fenêtre unique de Sol'Azeroth (V7, section 10.2 du document de conception).
-- Style natif Blizzard : cadre doré, portrait rond, onglets de section en bas, sous-onglets en haut, boutons rouges.
-- Emprunts : pastille rouge de notification (butin en attente) et pages de la section Collection sur parchemin.
-- Chaque sous-onglet accueille la fenêtre d'un addon du projet, sans son cadre ni son titre : la logique ne change pas,
-- et les commandes (/codex, /contrats…) ouvrent désormais cette fenêtre sur le bon sous-onglet.

local LARGEUR, HAUTEUR = 820, 660
local MARGE_HAUT, MARGE = 92, 18
local ENTETE_PARCHEMIN = 46

-- page : cadre accueilli (nom global) et commande qui le remplit, ou fonction de construction (pages simples).
local SECTIONS = {
    { nom = "Personnage", icone = "Interface\\Icons\\Achievement_Character_Human_Male", pages = {
        { nom = "Apprentissage", cadre = "SolAzerothFormationCadre", commande = "SOLAZEROTHFORMATION" },
        { nom = "Grimoire", cadre = "SolAzerothGrimoireCadre", commande = "SOLAZEROTHGRIMOIRE" },
        { nom = "Talents d'une autre classe", cadre = "SolAzerothTalentsCadre", commande = "SOLAZEROTHTALENTS" },
        { nom = "Spécialisations", cadre = "SolAzerothSpesCadre", commande = "SOLAZEROTHSPES" },
        { nom = "Défis", cadre = "SolAzerothDefisCadre", commande = "SOLAZEROTHDEFIS" },
    } },
    { nom = "Aventure", icone = "Interface\\Icons\\INV_Misc_Map_01", pages = {
        { nom = "Rang de menace", cadre = "SolAzerothMenaceCadre", commande = "SOLAZEROTHMENACE" },
        { nom = "Défi extérieur", cadre = "SolAzerothExterieurCadre", commande = "SOLAZEROTHEXTERIEUR" },
        { nom = "Contrats", cadre = "SolAzerothContratsCadre", commande = "SOLAZEROTHCONTRATS" },
        { nom = "Butin", cadre = "SolAzerothButinCadre", commande = "SOLAZEROTHBUTIN", vide = "Aucun butin en attente.", pastille = true },
    } },
    { nom = "Collection", icone = "Interface\\Icons\\INV_Misc_Book_09", parchemin = true, pages = {
        { nom = "Codex et Renom", cadre = "SolAzerothCodexCadre", commande = "SOLAZEROTHCODEX",
          sousTitre = "Ce que le voyageur a vu, vaincu et consigné." },
        { nom = "Journal de collection", cadre = "SolAzerothJournalCadre", commande = "SOLAZEROTHJOURNAL",
          sousTitre = "Le butin de chaque donjon et de chaque raid, boss par boss." },
        { nom = "Hauts faits du compte", cadre = "SolAzerothHautsFaitsCadre", commande = "SOLAZEROTHHAUTSFAITS",
          sousTitre = "Ils valent pour tout le compte, et figurent aussi dans la fenêtre Hauts faits du jeu.", hautsFaits = true },
    } },
    { nom = "Réglages", icone = "Interface\\Icons\\INV_Misc_Gear_01", pages = {
        { nom = "Plaques de nom", cadre = "SolAzerothPlaquesCadre", commande = "SOLAZEROTHPLAQUES" },
        { nom = "Barres et sacs", construire = "BarresEtSacs" },
        { nom = "Sauvegarde", construire = "Sauvegarde" },
    } },
}

local MARQUE = 37711

-- SetShown n'existe pas encore dans le jeu 3.3.5.
local function Montrer(objet, visible)
    if visible then objet:Show() else objet:Hide() end
end
local courante = { section = 1, page = 1 }
local enSelection = false

------------------------------------------------------------------------
-- Cadre principal
------------------------------------------------------------------------
local fenetre = CreateFrame("Frame", "SolAzerothFenetre", UIParent)
fenetre:SetSize(LARGEUR, HAUTEUR)
fenetre:SetPoint("CENTER", 0, 10)
fenetre:SetFrameStrata("DIALOG")
fenetre:SetToplevel(true)
fenetre:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
    tile = true, tileSize = 32, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 },
})
fenetre:EnableMouse(true)
fenetre:SetMovable(true)
fenetre:SetClampedToScreen(true)
fenetre:RegisterForDrag("LeftButton")
fenetre:SetScript("OnDragStart", fenetre.StartMoving)
fenetre:SetScript("OnDragStop", fenetre.StopMovingOrSizing)
fenetre:Hide()
tinsert(UISpecialFrames, "SolAzerothFenetre")

-- Bandeau de titre
local bandeau = fenetre:CreateTexture(nil, "ARTWORK")
bandeau:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
bandeau:SetSize(420, 64)
bandeau:SetPoint("TOP", 0, 12)
local titre = fenetre:CreateFontString(nil, "OVERLAY", "GameFontNormal")
titre:SetPoint("TOP", bandeau, "TOP", 0, -14)

-- Portrait rond, à cheval sur le coin comme la fiche de personnage
local portrait = fenetre:CreateTexture(nil, "OVERLAY")
portrait:SetSize(64, 64)
portrait:SetPoint("TOPLEFT", -14, 14)
local anneau = fenetre:CreateTexture(nil, "OVERLAY", nil, 1)
anneau:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
anneau:SetSize(170, 170)
anneau:SetPoint("TOPLEFT", portrait, "TOPLEFT", -22, 16)

local identite = fenetre:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
identite:SetPoint("TOPLEFT", 62, -20)

local fermer = CreateFrame("Button", nil, fenetre, "UIPanelCloseButton")
fermer:SetPoint("TOPRIGHT", -4, -4)

-- Monnaie du projet, en bas à droite
local monnaie = fenetre:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
monnaie:SetPoint("BOTTOMRIGHT", -22, 18)

-- Zone de contenu : fond sombre bordé d'or, ou parchemin pour la Collection
local contenu = CreateFrame("Frame", nil, fenetre)
contenu:SetPoint("TOPLEFT", MARGE, -MARGE_HAUT)
contenu:SetPoint("BOTTOMRIGHT", -MARGE, MARGE + 22)
contenu:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
contenu:SetBackdropColor(0.08, 0.06, 0.04, 0.9)
contenu:SetBackdropBorderColor(0.8, 0.65, 0.3)

local parchemin = contenu:CreateTexture(nil, "BACKGROUND", nil, 1)
parchemin:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Parchment-Horizontal")
parchemin:SetPoint("TOPLEFT", 4, -4)
parchemin:SetPoint("BOTTOMRIGHT", -4, 4)

-- En-tête des pages sur parchemin : lettrine et titre
local lettrine = contenu:CreateFontString(nil, "OVERLAY")
lettrine:SetFont("Fonts\\MORPHEUS.TTF", 38)
lettrine:SetTextColor(0.48, 0.18, 0.1)
lettrine:SetPoint("TOPLEFT", 16, -6)
local titrePage = contenu:CreateFontString(nil, "OVERLAY")
titrePage:SetFont("Fonts\\MORPHEUS.TTF", 20)
titrePage:SetTextColor(0.23, 0.11, 0.04)
titrePage:SetPoint("BOTTOMLEFT", lettrine, "BOTTOMRIGHT", 0, 6)
local sousTitre = contenu:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
sousTitre:SetTextColor(0.42, 0.29, 0.15)
sousTitre:SetPoint("TOPLEFT", titrePage, "BOTTOMLEFT", 0, -2)
local filet = contenu:CreateTexture(nil, "ARTWORK")
filet:SetTexture(0.55, 0.42, 0.24, 0.8)
filet:SetHeight(1)
filet:SetPoint("TOPLEFT", 14, -ENTETE_PARCHEMIN)
filet:SetPoint("TOPRIGHT", -14, -ENTETE_PARCHEMIN)

local boutonNatif = CreateFrame("Button", nil, contenu, "UIPanelButtonTemplate")
boutonNatif:SetSize(220, 22)
boutonNatif:SetPoint("TOPRIGHT", -14, -12)
boutonNatif:SetText("Fenêtre Hauts faits du jeu")
boutonNatif:SetScript("OnClick", function() ToggleAchievementFrame() end)

-- Texte affiché quand la page n'a rien à montrer (sa fenêtre s'est fermée)
local vide = contenu:CreateFontString(nil, "ARTWORK", "GameFontDisable")
vide:SetPoint("CENTER")

------------------------------------------------------------------------
-- Pastille rouge (notifications)
------------------------------------------------------------------------
local function Pastille(parent)
    local p = CreateFrame("Frame", nil, parent)
    p:SetSize(18, 18)
    p:SetPoint("TOPRIGHT", 4, 4)
    p:SetFrameLevel(parent:GetFrameLevel() + 5)
    local fond = p:CreateTexture(nil, "ARTWORK")
    fond:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
    fond:SetAllPoints()
    fond:SetVertexColor(0.8, 0.08, 0.05)
    p.texte = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    p.texte:SetPoint("CENTER", 0, 1)
    p:Hide()
    return p
end

local function NombreButins()
    return SolAzerothButinEnAttente and SolAzerothButinEnAttente() or 0
end

------------------------------------------------------------------------
-- Onglets de section (en bas) et sous-onglets (en haut)
------------------------------------------------------------------------
local ongletsSection, sousOnglets = {}, {}
local Selectionner

for i, section in ipairs(SECTIONS) do
    local o = CreateFrame("Button", "SolAzerothFenetreTab" .. i, fenetre, "CharacterFrameTabButtonTemplate")
    o:SetID(i)
    o:SetText(section.nom)
    if i == 1 then
        o:SetPoint("TOPLEFT", fenetre, "BOTTOMLEFT", 22, 8)
    else
        o:SetPoint("LEFT", ongletsSection[i - 1], "RIGHT", -16, 0)
    end
    o:SetScript("OnClick", function(self)
        PlaySound("igCharacterInfoTab")
        Selectionner(self:GetID(), SolAzerothDB.pages[self:GetID()] or 1)
    end)
    o.pastille = Pastille(o)
    ongletsSection[i] = o
end
PanelTemplates_SetNumTabs(fenetre, #SECTIONS)

local MAX_PAGES = 5
for j = 1, MAX_PAGES do
    local o = CreateFrame("Button", "SolAzerothFenetreSousOnglet" .. j, fenetre, "TabButtonTemplate")
    o:SetID(j)
    if j == 1 then
        o:SetPoint("BOTTOMLEFT", contenu, "TOPLEFT", 54, -2)
    else
        o:SetPoint("LEFT", sousOnglets[j - 1], "RIGHT", 0, 0)
    end
    o:SetScript("OnClick", function(self)
        PlaySound("igMainMenuOptionCheckBoxOn")
        Selectionner(courante.section, self:GetID())
    end)
    o.pastille = Pastille(o)
    sousOnglets[j] = o
end

------------------------------------------------------------------------
-- Accueil des fenêtres des autres addons
------------------------------------------------------------------------
local function EnleverHabillage(f)
    f:SetBackdrop(nil)
    f:SetMovable(false)
    f:SetScript("OnDragStart", nil)
    f:SetScript("OnDragStop", nil)
    local entete
    for _, r in ipairs({ f:GetRegions() }) do
        if r:GetObjectType() == "Texture" and (r:GetTexture() or ""):lower():find("ui%-dialogbox%-header") then
            entete = r
            r:Hide()
        end
    end
    for _, r in ipairs({ f:GetRegions() }) do
        if r:GetObjectType() == "FontString" and entete and select(2, r:GetPoint()) == entete then
            r:Hide()
        end
    end
    for _, enfant in ipairs({ f:GetChildren() }) do
        local t = enfant.GetNormalTexture and enfant:GetNormalTexture()
        if t and (t:GetTexture() or ""):lower():find("minimizebutton") then
            enfant:Hide()
            enfant:SetScript("OnShow", enfant.Hide)
        end
    end
end

local function Adopter(page)
    local f = page.cadre and _G[page.cadre]
    if not f or page.adopte then return f end
    page.adopte = true
    EnleverHabillage(f)
    f:Hide()
    f:SetParent(contenu)
    f:SetFrameStrata("DIALOG")
    -- Les commandes de l'addon (/codex…) montrent son cadre : on ouvre alors cette fenêtre sur la bonne page.
    hooksecurefunc(f, "Show", function()
        if enSelection then return end
        for i, s in ipairs(SECTIONS) do
            for j, p in ipairs(s.pages) do
                if p == page then Selectionner(i, j, true) end
            end
        end
    end)
    return f
end

local function Placer(page, f)
    local haut = SECTIONS[courante.section].parchemin and ENTETE_PARCHEMIN + 4 or 6
    local largeur, hauteur = contenu:GetWidth() - 12, contenu:GetHeight() - haut - 6
    local echelle = math.min(1, largeur / f:GetWidth(), hauteur / f:GetHeight())
    f:SetScale(echelle)
    f:ClearAllPoints()
    f:SetPoint("TOP", contenu, "TOP", 0, -haut / echelle)
    f:SetFrameLevel(contenu:GetFrameLevel() + 2)
end

------------------------------------------------------------------------
-- Pages simples (Réglages)
------------------------------------------------------------------------
local construites = {}

local function Bouton(parent, texte, largeur, x, y, action)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(largeur, 24)
    b:SetPoint("TOPLEFT", x, y)
    b:SetText(texte)
    b:SetScript("OnClick", action)
    return b
end

local function Texte(parent, modele, texte, x, y)
    local t = parent:CreateFontString(nil, "OVERLAY", modele)
    t:SetPoint("TOPLEFT", x, y)
    t:SetWidth(700)
    t:SetJustifyH("LEFT")
    t:SetText(texte)
    return t
end

local CONSTRUCTEURS = {
    BarresEtSacs = function(p)
        Texte(p, "GameFontNormalLarge", "Barres de postures et de totems", 24, -24)
        Texte(p, "GameFontHighlight", "Déplace les deux barres à la souris, puis valide (commande /barres).", 24, -48)
        Bouton(p, "Déplacer les barres", 180, 24, -72, function() SlashCmdList.SOLAZEROTHBARRES("") end)
        Texte(p, "GameFontNormalLarge", "Sacs", 24, -128)
        Texte(p, "GameFontHighlight", "Une seule fenêtre pour tous les sacs, recherche par nom (touche B ou /sacs).", 24, -152)
        Bouton(p, "Ouvrir les sacs", 180, 24, -176, function() SlashCmdList.SOLAZEROTHSACS("") end)
    end,
    Sauvegarde = function(p)
        Texte(p, "GameFontNormalLarge", "Sauvegarde de la partie", 24, -24)
        Texte(p, "GameFontHighlight", "Copie de la base de données, comme le bouton « Sauvegarder » du menu Échap.", 24, -48)
        Bouton(p, "Sauvegarder maintenant", 200, 24, -72, function() SendChatMessage(".sauvegarder", "SAY") end)
        Texte(p, "GameFontNormalLarge", "Sauvegarde automatique", 24, -128)
        Texte(p, "GameFontHighlight", "Intervalle entre deux sauvegardes pendant le jeu :", 24, -152)
        for i, minutes in ipairs({ 5, 10, 15, 30, 60 }) do
            Bouton(p, minutes .. " min", 80, 24 + (i - 1) * 88, -176, function() SendChatMessage(".sauvegarder " .. minutes, "SAY") end)
        end
        Bouton(p, "Intervalle actuel", 160, 24, -212, function() SendChatMessage(".sauvegarder ?", "SAY") end)
    end,
}

local function PageSimple(page)
    if not construites[page] then
        local p = CreateFrame("Frame", nil, contenu)
        p:SetAllPoints()
        CONSTRUCTEURS[page.construire](p)
        construites[page] = p
    end
    return construites[page]
end

------------------------------------------------------------------------
-- Sélection
------------------------------------------------------------------------
local affichee

local function Rafraichir()
    local butins = NombreButins()
    for i, section in ipairs(SECTIONS) do
        local n = 0
        for _, p in ipairs(section.pages) do
            if p.pastille then n = n + butins end
        end
        ongletsSection[i].pastille.texte:SetText(n)
        Montrer(ongletsSection[i].pastille, n > 0)
    end
    for j, o in ipairs(sousOnglets) do
        local p = SECTIONS[courante.section].pages[j]
        o.pastille.texte:SetText(butins)
        Montrer(o.pastille, p and p.pastille and butins > 0 or false)
    end

    for i = 1, GetCurrencyListSize() do
        local nom, entete, _, _, _, nombre, _, _, objet = GetCurrencyListInfo(i)
        if not entete and objet == MARQUE then
            monnaie:SetText(string.format("%s : |cffffffff%d|r |TInterface\\Icons\\INV_Misc_Coin_17:14|t", nom, nombre))
            return
        end
    end
    monnaie:SetText("")
end

Selectionner = function(numSection, numPage, depuisAddon)
    local section = SECTIONS[numSection]
    numPage = math.min(numPage, #section.pages)
    local page = section.pages[numPage]
    courante.section, courante.page = numSection, numPage
    SolAzerothDB.section, SolAzerothDB.pages[numSection] = numSection, numPage

    enSelection = true
    if affichee and affichee ~= page then
        if affichee.cadre and _G[affichee.cadre] then _G[affichee.cadre]:Hide() end
        if construites[affichee] then construites[affichee]:Hide() end
    end
    affichee = page
    if not fenetre:IsShown() then fenetre:Show() end

    PanelTemplates_SetTab(fenetre, numSection)
    for j, o in ipairs(sousOnglets) do
        local p = section.pages[j]
        if p then
            o:SetText(p.nom)
            PanelTemplates_TabResize(o, 0)
            o:Show()
            if j == numPage then PanelTemplates_SelectTab(o) else PanelTemplates_DeselectTab(o) end
        else
            o:Hide()
        end
    end

    titre:SetText("Sol'Azeroth — " .. section.nom)
    local surParchemin = section.parchemin
    Montrer(parchemin, surParchemin)
    contenu:SetBackdropColor(0.08, 0.06, 0.04, surParchemin and 1 or 0.9)
    for _, r in ipairs({ lettrine, titrePage, sousTitre, filet }) do Montrer(r, surParchemin) end
    Montrer(boutonNatif, page.hautsFaits or false)
    if surParchemin then
        lettrine:SetText(page.nom:sub(1, 1))
        titrePage:SetText(page.nom:sub(2))
        sousTitre:SetText(page.sousTitre or "")
    end
    vide:SetText(page.vide or "")

    if page.construire then
        PageSimple(page):Show()
    else
        local f = Adopter(page)
        if f then
            Placer(page, f)
            if not f:IsShown() and not depuisAddon and SlashCmdList[page.commande] then
                SlashCmdList[page.commande]("")
            end
        end
    end
    enSelection = false
    Rafraichir()
end

fenetre:SetScript("OnShow", function()
    SetPortraitTexture(portrait, "player")
    local _, classe = UnitClass("player")
    local couleur = RAID_CLASS_COLORS[classe] or NORMAL_FONT_COLOR
    identite:SetText(string.format("|cff%02x%02x%02x%s|r, %s niveau %d", couleur.r * 255, couleur.g * 255, couleur.b * 255,
        UnitName("player"), UnitClass("player"), UnitLevel("player")))
    PlaySound("igCharacterInfoOpen")
end)

-- Fermer la fenêtre ferme la page affichée : sinon l'addon la croirait encore ouverte.
fenetre:SetScript("OnHide", function()
    PlaySound("igCharacterInfoClose")
    if affichee and affichee.cadre and _G[affichee.cadre] then
        enSelection = true
        _G[affichee.cadre]:Hide()
        enSelection = false
    end
end)

local function Basculer()
    if fenetre:IsShown() then
        fenetre:Hide()
    else
        Selectionner(SolAzerothDB.section or 1, SolAzerothDB.pages[SolAzerothDB.section or 1] or 1)
    end
end

SLASH_SOLAZEROTH1 = "/sol"
SLASH_SOLAZEROTH2 = "/solazeroth"
SlashCmdList["SOLAZEROTH"] = Basculer

------------------------------------------------------------------------
-- Démarrage
------------------------------------------------------------------------
local evenements = CreateFrame("Frame")
evenements:RegisterEvent("ADDON_LOADED")
evenements:RegisterEvent("PLAYER_LOGIN")
evenements:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
evenements:SetScript("OnEvent", function(self, event, nom)
    if event == "ADDON_LOADED" then
        if nom ~= "SolAzeroth" then return end
        SolAzerothDB = SolAzerothDB or {}
        SolAzerothDB.pages = SolAzerothDB.pages or {}
    elseif event == "PLAYER_LOGIN" then
        -- Tous les addons sont chargés : leurs fenêtres rejoignent celle-ci.
        for _, section in ipairs(SECTIONS) do
            for _, page in ipairs(section.pages) do Adopter(page) end
        end
        Rafraichir()
    elseif fenetre:IsShown() then
        Rafraichir()
    end
end)

-- Pastilles : le nombre de butins en attente change sans événement du jeu.
local attente = 0
fenetre:SetScript("OnUpdate", function(self, ecoule)
    attente = attente + ecoule
    if attente > 1 then
        attente = 0
        Rafraichir()
    end
end)
