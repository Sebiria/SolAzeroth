-- Fenêtre des défis du personnage. Le serveur (lua_scripts/defis.lua) fait foi :
-- l'addon demande l'état avec ".soldefi etat" et envoie le choix avec ".soldefi valider 0,4".
-- Les points et les incompatibilités sont repris ici seulement pour l'affichage.
-- Ligue Destin (indice 100) : « .soldefi destin tirer|abandonner » ; l'état ajoute « ;race;classe;correspond;attente »
-- (race et classe tirées, 0 si aucune ; correspond = ce personnage a cette race et cette classe ; attente = secondes
-- avant le prochain tirage). Le défi Destin ne se coche que sur le personnage qui correspond au tirage.
-- Ligues Remix (101) et Chaos (102) : cochées comme les autres. Chaos actif : « .solchaos etat » renvoie
-- « CHAOS;nom;règle », la mutation du jour, affichée sur sa ligne.

local PREFIXE = "SOLDEFI"

local DEFIS = {
    { index = 0, nom = "Hardcore",                desc = "Mort définitive : le personnage ne peut plus jouer.", points = 5, icone = "INV_Misc_Bone_HumanSkull_01" },
    { index = 1, nom = "Semi-Hardcore",           desc = "À la mort, perte de l'équipement porté et de l'or.",  points = 3, icone = "INV_Misc_Coin_02" },
    { index = 2, nom = "Artisan",                 desc = "Seul l'équipement fabriqué soi-même peut être porté.", points = 3, icone = "Trade_BlackSmithing" },
    { index = 3, nom = "Équipement modeste",      desc = "Équipement de qualité commune ou médiocre uniquement.", points = 2, icone = "INV_Shirt_White_01" },
    { index = 4, nom = "XP lente",                desc = "Expérience gagnée ×0,5.",                              points = 1, icone = "INV_Misc_PocketWatch_01" },
    { index = 5, nom = "XP très lente",           desc = "Expérience gagnée ×0,25.",                             points = 2, icone = "INV_Misc_PocketWatch_02" },
    { index = 6, nom = "XP de quêtes uniquement", desc = "Aucune expérience en tuant des monstres.",              points = 2, icone = "INV_Misc_Note_01" },
    { index = 100, nom = "Destin",                desc = "",                                                      points = 4, icone = "INV_Misc_Dice_01" },
    { index = 101, nom = "Ligue Remix",           desc = "Monstres toujours à ton niveau. XP ×2 et +1 % de dégâts et de vie par niveau.", points = 1, icone = "Spell_Nature_TimeStop" },
    { index = 102, nom = "Ligue Chaos",           desc = "Chaque jour, une mutation tirée au sort change les règles : dégâts, soins, XP, or...", points = 2, icone = "Spell_Shadow_Charm" },
}
local CHAOS = 102
local mutation
local DESTIN = 100
local RACES = { [1] = "Humain", [2] = "Orc", [3] = "Nain", [4] = "Elfe de la nuit", [5] = "Mort-vivant", [6] = "Tauren",
                [7] = "Gnome", [8] = "Troll", [10] = "Elfe de sang", [11] = "Draeneï" }
local CLASSES = { [1] = "Guerrier", [2] = "Paladin", [3] = "Chasseur", [4] = "Voleur", [5] = "Prêtre", [7] = "Chaman",
                  [8] = "Mage", [9] = "Démoniste", [11] = "Druide" }
local INCOMPATIBLES = { [0] = 1, [1] = 0, [4] = 5, [5] = 4 }
local PALIERS = {
    { nom = "Légende", note = 15, couleur = "ff8000", multiplicateur = 5, titre = "« l'infaillible vainqueur »" },
    { nom = "Or",     note = 10, couleur = "ffd100", multiplicateur = 3, titre = "« l'immortel »" },
    { nom = "Argent", note = 6,  couleur = "c0c0c0", multiplicateur = 2, titre = "« l'increvable »" },
    { nom = "Bronze", note = 3,  couleur = "cd7f32", multiplicateur = 1 },
}
local OR_PAR_NIVEAU = { 20, 100, 400, 1000 }
local NIVEAUX = { 20, 40, 60, 80 }

local etat = { eligible = false, verrouille = false, actifs = {}, note = 0,
                destin = { race = 0, classe = 0, correspond = false, attente = 0, recu = 0 } }
local choix = {}
local ouvertureAuto = false

local function Palier(note)
    for _, p in ipairs(PALIERS) do
        if note >= p.note then return p end
    end
end

local function Commande(texte)
    SendChatMessage(texte, "SAY")
end

------------------------------------------------------------------------
-- Fenêtre
------------------------------------------------------------------------
local cadre = CreateFrame("Frame", "SolAzerothDefisCadre", UIParent)
cadre:SetSize(600, 770)
cadre:SetPoint("CENTER")
cadre:SetFrameStrata("DIALOG")
cadre:SetBackdrop({
    bgFile = "Interface\\AchievementFrame\\UI-Achievement-Parchment-Horizontal",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
    tile = false, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
})
cadre:EnableMouse(true)
cadre:SetMovable(true)
cadre:RegisterForDrag("LeftButton")
cadre:SetScript("OnDragStart", cadre.StartMoving)
cadre:SetScript("OnDragStop", cadre.StopMovingOrSizing)
cadre:Hide()
tinsert(UISpecialFrames, "SolAzerothDefisCadre")   -- Échap ferme la fenêtre

local entete = cadre:CreateTexture(nil, "ARTWORK")
entete:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
entete:SetSize(320, 64)
entete:SetPoint("TOP", 0, 12)
local titre = cadre:CreateFontString(nil, "OVERLAY", "GameFontNormal")
titre:SetPoint("TOP", entete, "TOP", 0, -14)
titre:SetText("Défis du personnage")

local fermer = CreateFrame("Button", nil, cadre, "UIPanelCloseButton")
fermer:SetPoint("TOPRIGHT", -6, -6)

local sousTitre = cadre:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
sousTitre:SetPoint("TOP", 0, -34)
sousTitre:SetWidth(540)

-- Lignes des défis
local lignes = {}
for i, defi in ipairs(DEFIS) do
    local ligne = CreateFrame("Button", nil, cadre)
    ligne:SetSize(556, 50)
    ligne:SetPoint("TOP", 0, -56 - (i - 1) * 54)
    ligne:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    ligne:SetBackdropColor(0.15, 0.1, 0.05, 0.75)
    ligne:SetBackdropBorderColor(0.6, 0.45, 0.2)
    ligne:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

    local icone = ligne:CreateTexture(nil, "ARTWORK")
    icone:SetSize(38, 38)
    icone:SetPoint("LEFT", 8, 0)
    icone:SetTexture("Interface\\Icons\\" .. defi.icone)

    local nom = ligne:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    nom:SetPoint("TOPLEFT", icone, "TOPRIGHT", 10, -2)
    nom:SetText(defi.nom)

    local desc = ligne:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", nom, "BOTTOMLEFT", 0, -4)
    desc:SetWidth(defi.index == DESTIN and 290 or 400)
    desc:SetJustifyH("LEFT")
    desc:SetText(defi.desc)

    local points = ligne:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    points:SetPoint("RIGHT", -48, 0)
    points:SetText(string.format("|cffffd100%d|r %s", defi.points, defi.points > 1 and "points" or "point"))

    local case = CreateFrame("CheckButton", nil, ligne, "UICheckButtonTemplate")
    case:SetPoint("RIGHT", -8, 0)
    case:EnableMouse(false)   -- c'est la ligne entière qui se clique

    ligne.defi, ligne.case, ligne.nom, ligne.desc = defi, case, nom, desc
    if defi.index == DESTIN then
        ligne.bouton = CreateFrame("Button", nil, ligne, "UIPanelButtonTemplate")
        ligne.bouton:SetSize(120, 22)
        ligne.bouton:SetPoint("RIGHT", -110, 0)
    end
    lignes[i] = ligne
end

-- Récompenses : un médaillon rond par niveau récompensé
local bandeau = cadre:CreateFontString(nil, "OVERLAY", "GameFontNormal")
bandeau:SetPoint("TOPLEFT", 26, -622)
bandeau:SetText("Récompenses du palier")

local medaillons = {}
for i, niveau in ipairs(NIVEAUX) do
    local m = CreateFrame("Frame", nil, cadre)
    m:SetSize(44, 44)
    m:SetPoint("TOPLEFT", 200 + (i - 1) * 90, -608)
    local fond = m:CreateTexture(nil, "ARTWORK")
    fond:SetAllPoints()
    SetPortraitToTexture(fond, "Interface\\Icons\\INV_Misc_Coin_01")
    local anneau = m:CreateTexture(nil, "OVERLAY")
    anneau:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    anneau:SetSize(76, 76)
    anneau:SetPoint("TOPLEFT", -7, 6)
    local texte = m:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    texte:SetPoint("TOP", m, "BOTTOM", 0, -2)
    m.fond, m.texte, m.niveau, m.rang = fond, texte, niveau, i
    m:EnableMouse(true)
    m:SetScript("OnEnter", function(self)
        if not self.infobulle then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Niveau " .. self.niveau, 1, 0.82, 0)
        GameTooltip:AddLine(self.infobulle, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    m:SetScript("OnLeave", function() GameTooltip:Hide() end)
    medaillons[i] = m
end

local total = cadre:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
total:SetPoint("BOTTOMLEFT", 26, 24)

local valider = CreateFrame("Button", nil, cadre, "UIPanelButtonTemplate")
valider:SetSize(190, 26)
valider:SetPoint("BOTTOMRIGHT", -22, 20)

local plusTard = CreateFrame("Button", nil, cadre, "UIPanelButtonTemplate")
plusTard:SetSize(110, 26)
plusTard:SetPoint("RIGHT", valider, "LEFT", -8, 0)
plusTard:SetText("Plus tard")
plusTard:SetScript("OnClick", function() cadre:Hide() end)

------------------------------------------------------------------------
-- Mise à jour de l'affichage
------------------------------------------------------------------------
local function Note()
    if etat.verrouille then return etat.note end
    local note = 0
    for _, defi in ipairs(DEFIS) do
        if choix[defi.index] then note = note + defi.points end
    end
    return note
end

local function AttenteDestin()
    local d = etat.destin
    return math.max(0, d.attente - (GetTime() - d.recu))
end

-- Texte et bouton de la ligne Destin. Renvoie vrai si le défi peut être coché sur ce personnage.
local function RafraichirDestin(ligne, modifiable)
    local d = etat.destin
    local actif = etat.verrouille and etat.actifs[DESTIN]
    local tire = d.race > 0
    local nomTire = tire and ((RACES[d.race] or "?") .. " " .. (CLASSES[d.classe] or "?")) or ""
    if actif then
        ligne.desc:SetText("Ce personnage suit son destin : ni sorts ni talents d'autres classes.")
    elseif tire and d.correspond then
        ligne.desc:SetText("Ton destin : |cffffffff" .. nomTire .. "|r. Ce personnage y correspond !")
    elseif tire then
        ligne.desc:SetText("Ton destin : |cffffffff" .. nomTire .. "|r. Crée ce personnage, puis choisis ce défi.")
    else
        local attente = AttenteDestin()
        ligne.desc:SetText("Race et classe tirées au sort. Ni sorts ni talents d'autres classes." ..
            (attente > 0 and string.format(" Prochain tirage dans %d h %02d.", math.floor(attente / 3600), math.floor(attente % 3600 / 60)) or ""))
    end

    local b = ligne.bouton
    if actif or (tire and d.correspond and modifiable) then
        b:Hide()
    elseif tire then
        b:SetText("Abandonner")
        b:SetScript("OnClick", function() StaticPopup_Show("SOLAZEROTH_DESTIN_ABANDON", nomTire) end)
        b:Enable()
        b:Show()
    else
        b:SetText("Tirer mon destin")
        b:SetScript("OnClick", function() Commande(".soldefi destin tirer") end)
        if AttenteDestin() > 0 then b:Disable() else b:Enable() end
        b:Show()
    end
    return tire and d.correspond
end

StaticPopupDialogs["SOLAZEROTH_DESTIN_ABANDON"] = {
    text = "Abandonner ton destin (%s) ? Un nouveau tirage ne sera possible que 24 h après le précédent.",
    button1 = "Abandonner", button2 = "Annuler",
    OnAccept = function() Commande(".soldefi destin abandonner") end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

local function Rafraichir()
    local modifiable = etat.eligible and not etat.verrouille
    for _, ligne in ipairs(lignes) do
        local index = ligne.defi.index
        local permis = modifiable
        if index == DESTIN then
            permis = RafraichirDestin(ligne, modifiable) and modifiable
            if not permis then choix[DESTIN] = nil end
        elseif index == CHAOS then
            ligne.desc:SetText((etat.verrouille and etat.actifs[CHAOS] and mutation) and
                ("Mutation du jour : |cffffffff" .. mutation.nom .. "|r. " .. mutation.regle) or ligne.defi.desc)
        end
        local coche = (etat.verrouille and etat.actifs[index]) or (not etat.verrouille and choix[index])
        ligne.case:SetChecked(coche)
        if coche then
            ligne:SetBackdropBorderColor(1, 0.82, 0)
        else
            ligne:SetBackdropBorderColor(0.6, 0.45, 0.2)
        end
        ligne:SetAlpha((permis or coche or index == DESTIN) and 1 or 0.5)
        ligne:EnableMouse(permis)
    end

    local note = Note()
    local palier = Palier(note)
    if palier then
        total:SetText(string.format("Difficulté %d  —  |cff%sPalier %s|r", note, palier.couleur, palier.nom))
    else
        total:SetText(string.format("Difficulté %d  —  |cff808080aucun palier (3 minimum)|r", note))
    end

    for i, m in ipairs(medaillons) do
        if palier then
            local orGagne = OR_PAR_NIVEAU[i] * palier.multiplicateur
            m.texte:SetText(m.niveau .. " : " .. orGagne .. " po")
            m.infobulle = string.format("%d po et %d Marques du voyageur.", orGagne, note * 10)
            if m.niveau == 80 and palier.titre then
                m.infobulle = m.infobulle .. "\nTitre " .. palier.titre .. "."
                SetPortraitToTexture(m.fond, "Interface\\Icons\\INV_Scroll_11")
            else
                SetPortraitToTexture(m.fond, "Interface\\Icons\\INV_Misc_Coin_01")
            end
            m.fond:SetVertexColor(1, 1, 1)
        else
            m.texte:SetText("Niveau " .. m.niveau)
            m.infobulle = "Atteins une difficulté de 3 pour débloquer les récompenses."
            m.fond:SetVertexColor(0.4, 0.4, 0.4)
        end
    end

    if etat.verrouille then
        sousTitre:SetText("Tes défis sont fixés pour toute la vie de ce personnage.")
        valider:SetText("Fermer")
        plusTard:Hide()
    elseif etat.eligible then
        sousTitre:SetText("Choisis tes défis avant de gagner ton premier niveau. Le choix est définitif.")
        valider:SetText(note > 0 and "Commencer l'aventure" or "Commencer sans défi")
        plusTard:Show()
    else
        sousTitre:SetText("Les défis se choisissent au niveau 1, à la création du personnage.")
        valider:SetText("Fermer")
        plusTard:Hide()
    end
end

for _, ligne in ipairs(lignes) do
    ligne:SetScript("OnClick", function(self)
        local index = self.defi.index
        choix[index] = not choix[index]
        if choix[index] and INCOMPATIBLES[index] then
            choix[INCOMPATIBLES[index]] = false
        end
        PlaySound("igMainMenuOptionCheckBoxOn")
        Rafraichir()
    end)
end

valider:SetScript("OnClick", function()
    if etat.eligible and not etat.verrouille then
        local liste = {}
        for _, defi in ipairs(DEFIS) do
            if choix[defi.index] then table.insert(liste, defi.index) end
        end
        Commande(".soldefi valider " .. table.concat(liste, ","))
    end
    cadre:Hide()
end)

------------------------------------------------------------------------
-- Échanges avec le serveur
------------------------------------------------------------------------
local evenements = CreateFrame("Frame")
evenements:RegisterEvent("CHAT_MSG_ADDON")
evenements:RegisterEvent("PLAYER_ENTERING_WORLD")

local attente = 0
local function DemanderEtatPlusTard(self, ecoule)
    attente = attente + ecoule
    if attente >= 2 then
        self:SetScript("OnUpdate", nil)
        ouvertureAuto = true
        Commande(".soldefi etat")
    end
end

evenements:SetScript("OnEvent", function(self, event, prefixe, message)
    if event == "PLAYER_ENTERING_WORLD" then
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        attente = 0
        self:SetScript("OnUpdate", DemanderEtatPlusTard)
        return
    end
    if prefixe ~= PREFIXE then return end

    local champs = { strsplit(";", message) }
    if champs[1] == "ETAT" then
        etat.eligible = champs[2] == "1"
        etat.verrouille = champs[3] == "1"
        etat.actifs = {}
        for index in string.gmatch(champs[4] or "", "%d+") do
            etat.actifs[tonumber(index)] = true
        end
        etat.note = tonumber(champs[5]) or 0
        etat.destin = { race = tonumber(champs[7]) or 0, classe = tonumber(champs[8]) or 0, correspond = champs[9] == "1",
                        attente = tonumber(champs[10]) or 0, recu = GetTime() }
        if etat.verrouille and etat.actifs[CHAOS] and not mutation then Commande(".solchaos etat") end
        Rafraichir()
        if ouvertureAuto then
            ouvertureAuto = false
            if etat.eligible then cadre:Show() end
        end
    elseif champs[1] == "CHAOS" then
        mutation = { nom = champs[2] or "", regle = champs[3] or "" }
        Rafraichir()
    elseif champs[1] == "OK" then
        if choix[CHAOS] then Commande(".solchaos") end
    elseif champs[1] == "ERREUR" then
        UIErrorsFrame:AddMessage(champs[2] or "Erreur", 1, 0.2, 0.2)
    end
end)

local function Basculer()
    if cadre:IsShown() then
        cadre:Hide()
    else
        Commande(".soldefi etat")
        cadre:Show()
    end
end

SLASH_SOLAZEROTHDEFIS1 = "/defis"
SlashCmdList["SOLAZEROTHDEFIS"] = Basculer

------------------------------------------------------------------------
-- Bouton de la minicarte, déplaçable autour du bord (position mémorisée)
------------------------------------------------------------------------
local RAYON = 80

local bouton = CreateFrame("Button", "SolAzerothDefisBoutonMinicarte", Minimap)
bouton:SetSize(31, 31)
bouton:SetFrameStrata("MEDIUM")
bouton:SetFrameLevel(8)
bouton:RegisterForClicks("LeftButtonUp")
bouton:RegisterForDrag("LeftButton")
bouton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local iconeBouton = bouton:CreateTexture(nil, "BACKGROUND")
iconeBouton:SetSize(20, 20)
iconeBouton:SetPoint("TOPLEFT", 7, -5)
iconeBouton:SetTexture("Interface\\Icons\\INV_Misc_Bone_HumanSkull_01")
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
    SolAzerothDefisDB.angle = angle
    Placer(angle)
end

bouton:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", SuivreCurseur) end)
bouton:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
bouton:SetScript("OnClick", Basculer)
bouton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Défis du personnage", 1, 0.82, 0)
    GameTooltip:AddLine("Clic : ouvrir ou fermer", 1, 1, 1)
    GameTooltip:AddLine("Glisser : déplacer le bouton", 1, 1, 1)
    GameTooltip:Show()
end)
bouton:SetScript("OnLeave", function() GameTooltip:Hide() end)

local chargement = CreateFrame("Frame")
chargement:RegisterEvent("ADDON_LOADED")
chargement:SetScript("OnEvent", function(self, event, nom)
    if nom ~= "SolAzerothDefis" then return end
    self:UnregisterEvent("ADDON_LOADED")
    SolAzerothDefisDB = SolAzerothDefisDB or { angle = 200 }
    Placer(SolAzerothDefisDB.angle)
end)
