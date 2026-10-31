-- Fenêtre unique de Sol'Azeroth (V7, section 10.2 du document de conception).
-- Style natif Blizzard : cadre doré, portrait rond, onglets de section en bas, sous-onglets en haut, boutons rouges.
-- Emprunts : pastille rouge de notification (butin en attente) et pages de la section Collection sur parchemin.
-- Chaque sous-onglet accueille la fenêtre d'un addon du projet, sans son cadre ni son titre : la logique ne change pas,
-- et les commandes (/codex, /contrats…) ouvrent désormais cette fenêtre sur le bon sous-onglet.

local LARGEUR, HAUTEUR = 820, 660
local MARGE_HAUT, MARGE = 92, 18
local ENTETE_PARCHEMIN = 58

-- page : cadre accueilli (nom global) et commande qui le remplit, ou fonction de construction (pages simples).
local SECTIONS = {
    -- v3 (31/10/2026) : la section Personnage (apprentissage, grimoire, talents, spécialisations, défis) et les pages
    -- Rang de menace et Défi extérieur sont retirées avec leurs addons.
    -- v3, F3 : la section Personnage revient avec la page Techniques (spécialisation et kit).
    { nom = "Personnage", icone = "Interface\\Icons\\INV_Shield_06", pages = {
        { nom = "Techniques", cadre = "SolAzerothKitCadre", commande = "SOLAZEROTHKIT" },
    } },
    { nom = "Aventure", icone = "Interface\\Icons\\INV_Misc_Map_01", pages = {
        { nom = "Contrats", cadre = "SolAzerothContratsCadre", commande = "SOLAZEROTHCONTRATS" },
        { nom = "Amélioration", cadre = "SolAzerothAmeliorationCadre", commande = "SOLAZEROTHAMELIORER" },
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
        { nom = "Macros", cadre = "SolAzerothMacrosCadre", commande = "SOLAZEROTHMACROS" },
        { nom = "Barres et sacs", construire = "BarresEtSacs" },
        { nom = "Sauvegarde", construire = "Sauvegarde" },
        { nom = "Monde", construire = "Monde" },
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

-- En-tête des pages sur parchemin : titre complet, sur un cadre à part au-dessus des pages (leur fond le recouvrait).
-- Pas de lettrine : dans ce client, la grande lettre isolée ne s'affichait pas (titre lu « odex », retour du 29/10/2026).
local entetePage = CreateFrame("Frame", nil, contenu)
entetePage:SetAllPoints()
entetePage:SetFrameLevel(contenu:GetFrameLevel() + 30)
local titrePage = entetePage:CreateFontString(nil, "OVERLAY")
-- Friz Quadrata plutôt que Morpheus : trop fine, elle se lisait mal sur le parchemin.
titrePage:SetFont("Fonts\\FRIZQT__.TTF", 20)
titrePage:SetTextColor(0.32, 0.08, 0.03)
titrePage:SetPoint("TOPLEFT", 18, -12)
local sousTitre = entetePage:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
sousTitre:SetTextColor(0.3, 0.18, 0.07)
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
-- Habillage des pages : les lignes, barres, icônes et textes des addons accueillis prennent le style des maquettes
-- (lignes brunes bordées d'or sur fond sombre, lignes claires et encre brune sur parchemin). La logique des addons
-- ne change pas : leurs couleurs d'état (vert = obtenu, or = actif…) sont gardées, seuls les gris neutres sont teintés.
------------------------------------------------------------------------
local BARRE = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill"
local habilles = setmetatable({}, { __mode = "k" })

local function Neutre(r, g, b)
    return math.max(r, g, b) - math.min(r, g, b) < 0.08
end

-- Fond d'une ligne : sombre → brun chaud ; sur parchemin → clair et translucide (couleurs d'état adoucies).
local function TeinteFond(r, g, b, a, surParchemin)
    if surParchemin then
        if Neutre(r, g, b) then
            if r < 0.07 then return 0.55, 0.45, 0.3, 0.12 end
            return 1, 0.97, 0.88, 0.3
        end
        return 0.55 + r * 0.45, 0.55 + g * 0.45, 0.45 + b * 0.45, 0.4
    end
    if Neutre(r, g, b) then
        if r < 0.07 then return 0.12, 0.085, 0.05, 0.95 end
        return 0.21, 0.15, 0.08, 0.95
    end
    return r, g, b, math.max(a or 1, 0.9)
end

local function TeinteBord(r, g, b, surParchemin)
    if Neutre(r, g, b) then
        if surParchemin then return 0.6, 0.46, 0.26 end
        if r < 0.5 then return 0.3, 0.23, 0.11 end
        return 0.42, 0.33, 0.15
    end
    return r, g, b
end

local function HabillerLigne(f, surParchemin)
    local fond, bord = f.SetBackdropColor, f.SetBackdropBorderColor
    local r, g, b, a = f:GetBackdropColor()
    local br, bg, bb = f:GetBackdropBorderColor()
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    f.SetBackdropColor = function(self, r, g, b, a) fond(self, TeinteFond(r, g, b, a, surParchemin)) end
    f.SetBackdropBorderColor = function(self, r, g, b) bord(self, TeinteBord(r, g, b, surParchemin)) end
    f:SetBackdropColor(r or 0.1, g or 0.1, b or 0.1, a)
    f:SetBackdropBorderColor(br or 0.6, bg or 0.6, bb or 0.6)
    if not surParchemin then
        -- Dégradé gauche → droite et reflet en haut, comme les lignes de la maquette « natif ».
        local degrade = f:CreateTexture(nil, "BORDER")
        degrade:SetTexture(0, 0, 0)
        degrade:SetPoint("TOPLEFT", 1, -1)
        degrade:SetPoint("BOTTOMRIGHT", -1, 1)
        degrade:SetGradientAlpha("HORIZONTAL", 0, 0, 0, 0, 0, 0, 0, 0.45)
        local reflet = f:CreateTexture(nil, "BORDER")
        reflet:SetTexture(1, 0.85, 0.5, 0.08)
        reflet:SetHeight(1)
        reflet:SetPoint("TOPLEFT", 1, -1)
        reflet:SetPoint("TOPRIGHT", -1, -1)
    end
end

local function HabillerBarre(b)
    b:SetStatusBarTexture(BARRE)
    local fond = b:CreateTexture(nil, "BACKGROUND")
    fond:SetTexture(0.05, 0.035, 0.02, 0.9)
    fond:SetAllPoints()
    local cadre = CreateFrame("Frame", nil, b)
    cadre:SetPoint("TOPLEFT", -1, 1)
    cadre:SetPoint("BOTTOMRIGHT", 1, -1)
    cadre:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    cadre:SetBackdropBorderColor(0.35, 0.27, 0.12)
end

-- Icône de sort ou d'objet posée sur un cadre : bords rognés et liseré doré.
local function HabillerIcone(t)
    t:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    local parent = t:GetParent()
    local lisere = parent:CreateTexture(nil, "BACKGROUND", nil, 7)
    lisere:SetTexture(0.55, 0.45, 0.25)
    lisere:SetPoint("TOPLEFT", t, -2, 2)
    lisere:SetPoint("BOTTOMRIGHT", t, 2, -2)
    local creux = parent:CreateTexture(nil, "BORDER")
    creux:SetTexture(0.08, 0.06, 0.04)
    creux:SetPoint("TOPLEFT", t, -1, 1)
    creux:SetPoint("BOTTOMRIGHT", t, 1, -1)
end

-- Encre du parchemin : chaque police du jeu a sa version brune.
local ENCRES = {
    GameFontNormal = { 0.45, 0.14, 0.07 }, GameFontNormalSmall = { 0.45, 0.14, 0.07 },
    GameFontNormalLarge = { 0.4, 0.12, 0.05 }, GameFontNormalHuge = { 0.4, 0.12, 0.05 },
    GameFontHighlight = { 0.2, 0.12, 0.05 }, GameFontHighlightSmall = { 0.24, 0.15, 0.07 },
    GameFontHighlightLarge = { 0.2, 0.12, 0.05 },
    GameFontDisable = { 0.45, 0.34, 0.2 }, GameFontDisableSmall = { 0.45, 0.34, 0.2 },
    GameFontGreen = { 0.15, 0.4, 0.1 }, GameFontGreenSmall = { 0.15, 0.4, 0.1 },
    GameFontRed = { 0.6, 0.1, 0.05 }, GameFontRedSmall = { 0.6, 0.1, 0.05 },
}
local encresCreees = {}
local function Encre(nom)
    if not encresCreees[nom] then
        local police = CreateFont("SolAzerothEncre" .. nom)
        police:SetFontObject(_G[nom])
        police:SetTextColor(unpack(ENCRES[nom]))
        police:SetShadowColor(0, 0, 0, 0)
        encresCreees[nom] = police
    end
    return encresCreees[nom]
end

-- Une couleur claire (jaune, vert pâle…) est illisible sur le parchemin : on garde sa teinte en l'assombrissant.
local function Assombrir(r, g, b)
    local clarte = 0.3 * r + 0.59 * g + 0.11 * b
    if clarte < 0.45 then return r, g, b end
    local f = 0.4 / clarte
    return r * f, g * f, b * f
end

local function AssombrirCode(a, rr, gg, bb)
    local r, g, b = Assombrir(tonumber(rr, 16) / 255, tonumber(gg, 16) / 255, tonumber(bb, 16) / 255)
    return string.format("|c%s%02x%02x%02x", a, r * 255, g * 255, b * 255)
end

local function EncrerTexte(t)
    local couleur, texte = t.SetTextColor, t.SetText
    t.SetTextColor = function(self, r, g, b, a) couleur(self, Assombrir(r, g, b)) end
    t.SetText = function(self, s)
        if type(s) == "string" then s = s:gsub("|c(%x%x)(%x%x)(%x%x)(%x%x)", AssombrirCode) end
        texte(self, s)
    end
    local r, g, b = t:GetTextColor()
    t:SetTextColor(r, g, b)
    t:SetText(t:GetText())
end

local function HabillerTexte(t, parent, surParchemin)
    local objet = t:GetFontObject()
    local nom = objet and objet:GetName()
    if surParchemin then
        -- Les textes des boutons et des barres restent clairs : ils sont posés sur du sombre.
        local typeParent = parent:GetObjectType()
        if typeParent ~= "Button" and typeParent ~= "StatusBar" then
            if nom and ENCRES[nom] then t:SetFontObject(Encre(nom)) end
            EncrerTexte(t)
        end
    elseif nom == "GameFontNormalLarge" or nom == "GameFontNormalHuge" then
        t:SetShadowOffset(1, -1)
        t:SetShadowColor(0, 0, 0, 1)
    end
end

local function Habiller(f, surParchemin)
    local typeObjet = f:GetObjectType()
    if not habilles[f] then
        habilles[f] = true
        local fond = f.GetBackdrop and f:GetBackdrop()
        if fond and fond.bgFile and fond.bgFile:find("UI%-Tooltip%-Background") then
            HabillerLigne(f, surParchemin)
        elseif typeObjet == "StatusBar" and not fond then
            HabillerBarre(f)
        end
    end
    -- Régions et enfants sont revus à chaque passage : les addons créent leurs lignes et posent leurs icônes
    -- au fil des données reçues.
    for _, r in ipairs({ f:GetRegions() }) do
        if not habilles[r] then
            if r:GetObjectType() == "FontString" then
                habilles[r] = true
                HabillerTexte(r, f, surParchemin)
            elseif r:GetObjectType() == "Texture" and typeObjet ~= "Button" and typeObjet ~= "CheckButton" then
                local chemin = (r:GetTexture() or ""):lower()
                if chemin:find("^interface\\icons\\") and r:GetWidth() >= 18 then
                    habilles[r] = true
                    HabillerIcone(r)
                end
            end
        end
    end
    for _, enfant in ipairs({ f:GetChildren() }) do Habiller(enfant, surParchemin) end
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

-- Une page sécurisée (boutons de sort du Grimoire) rend protégée la fenêtre qui la contient : en combat, plus moyen
-- de l'ouvrir, la fermer ni la déplacer (« Échec d'une action d'interface »). Elle n'y entre donc que hors combat,
-- et en sort à l'entrée en combat (Detacher).
local function Adopter(page)
    local f = page.cadre and _G[page.cadre]
    if not f or (page.securise and InCombatLockdown()) then return nil end
    if f:GetParent() ~= contenu then
        f:Hide()
        f:SetParent(contenu)
        f:SetFrameStrata("DIALOG")
    end
    if page.adopte then return f end
    page.adopte = true
    EnleverHabillage(f)
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

-- Entrée en combat : la page sécurisée quitte la fenêtre (encore permis pendant cet événement).
local function Detacher()
    for _, section in ipairs(SECTIONS) do
        for _, page in ipairs(section.pages) do
            local f = page.securise and _G[page.cadre]
            if f and f:GetParent() == contenu then
                f:Hide()
                f:SetParent(UIParent)
                f:ClearAllPoints()
                f:SetPoint("LEFT", 40, 40)
            end
        end
    end
end

local function Placer(page, f)
    local haut = SECTIONS[courante.section].parchemin and ENTETE_PARCHEMIN + 4 or 6
    local largeur, hauteur = contenu:GetWidth() - 12, contenu:GetHeight() - haut - 6
    -- Les petites fenêtres sont agrandies (jusqu'à 1,3) pour remplir la page au lieu de flotter au milieu.
    local echelle = math.min(1.3, largeur / f:GetWidth(), hauteur / f:GetHeight())
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

-- Carte de réglage : icône dorée, titre, explication ; les boutons se posent dessous (y relatif à la carte).
local function Carte(parent, y, hauteur, icone, titreCarte, texte)
    local c = CreateFrame("Frame", nil, parent)
    c:SetPoint("TOPLEFT", 20, y)
    c:SetPoint("RIGHT", -20, 0)
    c:SetHeight(hauteur)
    c:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                    tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    c:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    c:SetBackdropBorderColor(0.6, 0.6, 0.6)
    local ic = c:CreateTexture(nil, "ARTWORK")
    ic:SetTexture(icone)
    ic:SetSize(36, 36)
    ic:SetPoint("TOPLEFT", 12, -12)
    local t = Texte(c, "GameFontNormalLarge", titreCarte, 60, -12)
    t:SetWidth(600)
    local d = Texte(c, "GameFontHighlightSmall", texte, 60, -34)
    d:SetWidth(600)
    return c
end

local CONSTRUCTEURS = {
    BarresEtSacs = function(p)
        local barres = Carte(p, -20, 110, "Interface\\Icons\\Ability_Warrior_DefensiveStance", "Barres de postures et de totems",
            "Déplace les deux barres à la souris, puis valide (commande /barres).")
        Bouton(barres, "Déplacer les barres", 180, 60, -66, function() SlashCmdList.SOLAZEROTHBARRES("") end)
        local sacs = Carte(p, -146, 110, "Interface\\Icons\\INV_Misc_Bag_08", "Sacs",
            "Une seule fenêtre pour tous les sacs et la banque, recherche par nom (touche B ou /sacs).")
        Bouton(sacs, "Ouvrir les sacs", 180, 60, -66, function() SlashCmdList.SOLAZEROTHSACS("") end)
    end,
    Sauvegarde = function(p)
        local maintenant = Carte(p, -20, 110, "Interface\\Icons\\INV_Misc_Note_01", "Sauvegarde de la partie",
            "Copie de la base de données, comme le bouton « Sauvegarder » du menu Échap.")
        Bouton(maintenant, "Sauvegarder maintenant", 200, 60, -66, function() SendChatMessage(".sauvegarder", "SAY") end)
        local auto = Carte(p, -146, 146, "Interface\\Icons\\INV_Misc_PocketWatch_01", "Sauvegarde automatique",
            "Intervalle entre deux sauvegardes pendant le jeu :")
        for i, minutes in ipairs({ 5, 10, 15, 30, 60 }) do
            Bouton(auto, minutes .. " min", 80, 60 + (i - 1) * 88, -66, function() SendChatMessage(".sauvegarder " .. minutes, "SAY") end)
        end
        Bouton(auto, "Intervalle actuel", 160, 60, -102, function() SendChatMessage(".sauvegarder ?", "SAY") end)
    end,
    -- Mise à l'échelle du monde avec retard (section 9.1), propre à chaque personnage.
    Monde = function(p)
        local echelle = Carte(p, -20, 150, "Interface\\Icons\\Ability_Hunter_Pathfinding", "Monstres à ton niveau",
            "Hors donjons, les monstres plus faibles que toi remontent à ton niveau moins 2 ou 3 : aucune zone ne devient "
            .. "triviale. Les quêtes trop basses rapportent l'XP d'une quête de ce niveau. Les PNJ de service, les gardes "
            .. "et les boss de monde ne changent pas. Propre à ce personnage, désactivé par défaut.")
        local etat = Texte(echelle, "GameFontNormal", "État : ...", 60, -86)
        Bouton(echelle, "Activer", 140, 60, -110, function() SendChatMessage(".solechelle on", "SAY") end)
        Bouton(echelle, "Désactiver", 140, 210, -110, function() SendChatMessage(".solechelle off", "SAY") end)
        local ecoute = CreateFrame("Frame", nil, p)
        ecoute:RegisterEvent("CHAT_MSG_ADDON")
        ecoute:SetScript("OnEvent", function(self, event, prefixe, message)
            if prefixe ~= "SolAzerothEchelle" then return end
            etat:SetText(message == "1" and "État : |cff40c040activé|r" or "État : |cffc04040désactivé|r")
        end)
        p:SetScript("OnShow", function() SendChatMessage(".solechelle etat", "SAY") end)
        SendChatMessage(".solechelle etat", "SAY")
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
local differee   -- page sécurisée demandée en combat, ouverte à la fin du combat

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
    if page.securise and InCombatLockdown() then
        differee = { numSection, numPage }
        UIErrorsFrame:AddMessage("Le grimoire s'ouvrira à la fin du combat.", 1, 0.82, 0)
        return
    end
    courante.section, courante.page = numSection, numPage
    SolAzerothDB.section, SolAzerothDB.pages[numSection] = numSection, numPage

    enSelection = true
    if affichee and affichee ~= page then
        if affichee.cadre and _G[affichee.cadre] and _G[affichee.cadre]:IsShown() then _G[affichee.cadre]:Hide() end
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
    for _, r in ipairs({ titrePage, sousTitre, filet }) do Montrer(r, surParchemin) end
    Montrer(boutonNatif, page.hautsFaits or false)
    if surParchemin then
        titrePage:SetText(page.nom)
        sousTitre:SetText(page.sousTitre or "")
    end
    vide:SetText(page.vide or "")

    if page.construire then
        local p = PageSimple(page)
        p:Show()
        Habiller(p, false)
    else
        local f = Adopter(page)
        if f then
            Placer(page, f)
            if not f:IsShown() and not depuisAddon and SlashCmdList[page.commande] then
                SlashCmdList[page.commande]("")
            end
            Habiller(f, surParchemin)
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
    if affichee and affichee.cadre and _G[affichee.cadre] and _G[affichee.cadre]:IsShown() then
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
-- Noms des objets, pour tous les addons Sol'Azeroth. Le jeu ne connaît le nom d'un objet qu'après l'avoir demandé
-- au serveur, un par un et lentement : les fenêtres affichaient « Objet 862 ». Les noms manquants sont demandés
-- par paquets (commande .solnoms) et gardés d'une session à l'autre.
------------------------------------------------------------------------
local nomsDemandes, aDemander = {}, {}

function SolAzerothNomObjet(id)
    id = tonumber(id)
    if not id then return nil end
    local nom = GetItemInfo(id)
    if nom then return nom end
    local memoire = SolAzerothDB and SolAzerothDB.noms
    if memoire and memoire[id] then return memoire[id] end
    if not nomsDemandes[id] then
        nomsDemandes[id] = true
        aDemander[#aDemander + 1] = id
    end
    return nil
end

local demandeNoms = CreateFrame("Frame")
local attenteNoms = 0
demandeNoms:SetScript("OnUpdate", function(self, ecoule)
    attenteNoms = attenteNoms + ecoule
    if attenteNoms < 0.3 or #aDemander == 0 then return end
    attenteNoms = 0
    local paquet = {}
    while #aDemander > 0 and #paquet < 30 do paquet[#paquet + 1] = table.remove(aDemander) end
    SendChatMessage(".solnoms " .. table.concat(paquet, ","), "SAY")
end)
demandeNoms:RegisterEvent("CHAT_MSG_ADDON")
demandeNoms:SetScript("OnEvent", function(self, event, prefixe, message)
    if prefixe ~= "SolAzerothNoms" or not SolAzerothDB then return end
    SolAzerothDB.noms = SolAzerothDB.noms or {}
    for element in string.gmatch(message, "[^;]+") do
        local id, nom = element:match("^(%d+):(.*)$")
        if id then SolAzerothDB.noms[tonumber(id)] = nom end
    end
end)

------------------------------------------------------------------------
-- Démarrage
------------------------------------------------------------------------
local evenements = CreateFrame("Frame")
evenements:RegisterEvent("ADDON_LOADED")
evenements:RegisterEvent("PLAYER_LOGIN")
evenements:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
evenements:RegisterEvent("PLAYER_REGEN_DISABLED")
evenements:RegisterEvent("PLAYER_REGEN_ENABLED")
evenements:RegisterEvent("ADDON_ACTION_BLOCKED")
evenements:RegisterEvent("ADDON_ACTION_FORBIDDEN")
evenements:SetScript("OnEvent", function(self, event, nom, fonction)
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
    elseif event == "PLAYER_REGEN_DISABLED" then
        Detacher()
        if fenetre:IsShown() and affichee and affichee.securise then vide:SetText("Le grimoire revient à la fin du combat.") end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if differee then
            local s, p = differee[1], differee[2]
            differee = nil
            Selectionner(s, p)
        elseif fenetre:IsShown() and affichee and affichee.securise then
            Selectionner(courante.section, courante.page)
        end
    elseif event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
        -- Mouchard : si l'erreur d'interface revient, le chat dit quel addon et quelle fonction l'ont causée.
        if nom and nom:find("^SolAzeroth") then
            print(string.format("|cffff6060Sol'Azeroth :|r action bloquée en combat (%s, %s). Signale-le.", nom, tostring(fonction)))
        end
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
        local f = affichee and affichee.cadre and _G[affichee.cadre]
        if f and f:IsShown() then Habiller(f, SECTIONS[courante.section].parchemin) end
    end
end)
