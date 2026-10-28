-- Sacs unifiés (écrit pour Sol'Azeroth, inspiré du principe de Bagnon) :
-- - une fenêtre pour le sac à dos et les 4 sacs, une fenêtre pour la banque et ses 7 sacs ;
-- - recherche par nom (les objets qui ne correspondent pas sont assombris) ;
-- - l'infobulle d'un objet indique combien en ont tes autres personnages (sacs et banque).
-- Les boutons d'objet reprennent le modèle du jeu (ContainerFrameItemButtonTemplate) : clic droit,
-- glisser, vendre, utiliser fonctionnent comme d'habitude.

local COLONNES_DEFAUT, COLONNES_MIN, COLONNES_MAX, ECART = 10, 4, 24, 39

-- Nombre de colonnes réglable (boutons - et + des fenêtres, ou /sacs colonnes N), mémorisé pour le compte.
local function Colonnes()
    return SolAzerothSacsDB and SolAzerothSacsDB.colonnes or COLONNES_DEFAUT
end
local SACS = { 0, 1, 2, 3, 4 }
local BANQUE = { -1, 5, 6, 7, 8, 9, 10, 11 }

local royaume, nomPerso = GetRealmName(), UnitName("player")

------------------------------------------------------------------------
-- Une fenêtre (sacs ou banque)
------------------------------------------------------------------------
local function CreerFenetre(nom, titreTexte, idsSacs)
    local f = CreateFrame("Frame", nom, UIParent)
    f:SetFrameStrata("HIGH")
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
        edgeSize = 24, insets = { left = 6, right = 6, top = 6, bottom = 6 },
    })
    f:EnableMouse(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:Hide()
    tinsert(UISpecialFrames, nom)

    f.titre = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.titre:SetPoint("TOPLEFT", 14, -12)
    f.titre:SetText(titreTexte)

    local fermer = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    fermer:SetPoint("TOPRIGHT", -2, -2)

    f.recherche = CreateFrame("EditBox", nom .. "Recherche", f, "InputBoxTemplate")
    f.recherche:SetSize(150, 18)
    f.recherche:SetPoint("TOPRIGHT", -36, -9)
    f.recherche:SetAutoFocus(false)
    f.recherche:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    f.moins = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.moins:SetSize(22, 18)
    f.moins:SetPoint("BOTTOMLEFT", 10, 8)
    f.moins:SetText("-")
    f.plus = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.plus:SetSize(22, 18)
    f.plus:SetPoint("LEFT", f.moins, "RIGHT", 2, 0)
    f.plus:SetText("+")

    f.pied = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.pied:SetPoint("LEFT", f.plus, "RIGHT", 8, 0)
    f.argent = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.argent:SetPoint("BOTTOMRIGHT", -14, 12)

    -- Un cadre caché par sac : le modèle de bouton lit le numéro du sac sur son parent.
    f.sacs = {}
    for _, id in ipairs(idsSacs) do
        local sac = CreateFrame("Frame", nom .. "Sac" .. (id + 2), f)
        sac:SetID(id)
        sac.boutons = {}
        f.sacs[#f.sacs + 1] = sac
    end
    f.idsSacs = idsSacs
    return f
end

local sacs = CreerFenetre("SolAzerothSacsCadre", "Sacs", SACS)
sacs:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -60, 100)
local banque = CreerFenetre("SolAzerothBanqueCadre", "Banque", BANQUE)
banque:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 60, -120)

local function Bouton(sac, emplacement)
    local b = sac.boutons[emplacement]
    if b then return b end
    b = CreateFrame("Button", sac:GetName() .. "Objet" .. emplacement, sac, "ContainerFrameItemButtonTemplate")
    b:SetID(emplacement)
    b.bordure = b:CreateTexture(nil, "OVERLAY")
    b.bordure:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    b.bordure:SetBlendMode("ADD")
    b.bordure:SetSize(66, 66)
    b.bordure:SetPoint("CENTER")
    sac.boutons[emplacement] = b
    return b
end

local function Correspond(lien, texte)
    if texte == "" then return true end
    if not lien then return false end
    local nom = GetItemInfo(lien)
    return nom and strfind(strlower(nom), texte, 1, true) ~= nil
end

local function Afficher(f)
    if not f:IsShown() then return end
    local texte = strlower(f.recherche:GetText() or "")
    local COLONNES = Colonnes()
    local n, libres, total = 0, 0, 0
    local incomplet = false   -- un objet pas encore connu du jeu : son icône arrive un peu plus tard
    for _, sac in ipairs(f.sacs) do
        local id = sac:GetID()
        local places = GetContainerNumSlots(id)
        for emplacement = 1, places do
            local b = Bouton(sac, emplacement)
            local ligne, colonne = math.floor(n / COLONNES), n % COLONNES
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", f, "TOPLEFT", 12 + colonne * ECART, -34 - ligne * ECART)
            local icone, nombre, verrouille, qualite, _, _, lien = GetContainerItemInfo(id, emplacement)
            if lien and (not icone or not GetItemInfo(lien)) then
                incomplet = true
                icone = icone or GetItemIcon(lien)
            end
            SetItemButtonTexture(b, icone)
            SetItemButtonCount(b, nombre or 0)
            SetItemButtonDesaturated(b, verrouille)
            if icone then
                ContainerFrame_UpdateCooldown(id, b)
            else
                libres = libres + 1
                _G[b:GetName() .. "Cooldown"]:Hide()
            end
            if qualite and qualite > 1 then
                local r, v, bl = GetItemQualityColor(qualite)
                b.bordure:SetVertexColor(r, v, bl)
                b.bordure:Show()
            else
                b.bordure:Hide()
            end
            b:SetAlpha(Correspond(lien, texte) and 1 or 0.25)
            b:Show()
            n = n + 1
        end
        for emplacement = places + 1, #sac.boutons do
            sac.boutons[emplacement]:Hide()
        end
        total = total + places
    end
    f.incomplet = incomplet
    local lignes = math.max(1, math.ceil(n / COLONNES))
    f:SetSize(math.max(24 + COLONNES * ECART, 330), 64 + lignes * ECART)
    f.pied:SetText(string.format("%d / %d places libres", libres, total))
    f.argent:SetText(GetCoinTextureString(GetMoney()))
end

local function ReglerColonnes(nombre)
    SolAzerothSacsDB = SolAzerothSacsDB or {}
    SolAzerothSacsDB.colonnes = math.max(COLONNES_MIN, math.min(COLONNES_MAX, nombre))
    Afficher(sacs)
    Afficher(banque)
end

-- Tant qu'un objet n'est pas encore connu du jeu, on redessine la fenêtre toutes les secondes.
local function Relancer(self, ecoule)
    self.attente = (self.attente or 0) + ecoule
    if self.attente >= 1 then
        self.attente = 0
        if self.incomplet then Afficher(self) end
    end
end

for _, f in ipairs({ sacs, banque }) do
    f:SetScript("OnUpdate", Relancer)
    f.recherche:SetScript("OnTextChanged", function() Afficher(sacs) Afficher(banque) end)
    f:SetScript("OnShow", function(self) Afficher(self) end)
    f.moins:SetScript("OnClick", function() ReglerColonnes(Colonnes() - 1) end)
    f.plus:SetScript("OnClick", function() ReglerColonnes(Colonnes() + 1) end)
end

------------------------------------------------------------------------
-- Mémoire des inventaires, pour les autres personnages
------------------------------------------------------------------------
local function Memoriser(ids, cle)
    SolAzerothSacsDB = SolAzerothSacsDB or {}
    SolAzerothSacsDB[royaume] = SolAzerothSacsDB[royaume] or {}
    local perso = SolAzerothSacsDB[royaume][nomPerso] or {}
    SolAzerothSacsDB[royaume][nomPerso] = perso
    local contenu = {}
    for _, id in ipairs(ids) do
        for emplacement = 1, GetContainerNumSlots(id) do
            local lien = GetContainerItemLink(id, emplacement)
            if lien then
                local objet = tonumber(strmatch(lien, "item:(%d+)"))
                local _, nombre = GetContainerItemInfo(id, emplacement)
                contenu[objet] = (contenu[objet] or 0) + (nombre or 1)
            end
        end
    end
    perso[cle] = contenu
end

GameTooltip:HookScript("OnTooltipSetItem", function(self)
    local _, lien = self:GetItem()
    local objet = lien and tonumber(strmatch(lien, "item:(%d+)"))
    if not objet or not SolAzerothSacsDB or not SolAzerothSacsDB[royaume] then return end
    for nom, perso in pairs(SolAzerothSacsDB[royaume]) do
        local s = perso.sacs and perso.sacs[objet] or 0
        local b = perso.banque and perso.banque[objet] or 0
        if s + b > 0 then
            local detail = {}
            if s > 0 then table.insert(detail, s .. " dans les sacs") end
            if b > 0 then table.insert(detail, b .. " à la banque") end
            self:AddDoubleLine(nom, table.concat(detail, ", "), 0.6, 0.8, 1, 1, 1, 1)
        end
    end
    self:Show()
end)

------------------------------------------------------------------------
-- Remplacement des sacs et de la banque du jeu
------------------------------------------------------------------------
local function BasculerSacs()
    if sacs:IsShown() then sacs:Hide() else sacs:Show() end
end
ToggleBackpack = BasculerSacs
ToggleBag = function() BasculerSacs() end
OpenAllBags = function() sacs:Show() end
CloseAllBags = function() sacs:Hide() end
OpenBackpack = function() sacs:Show() end
CloseBackpack = function() sacs:Hide() end
OpenBag = function() sacs:Show() end
CloseBag = function() end
ToggleAllBags = BasculerSacs

local evenements = CreateFrame("Frame")
for _, e in ipairs({ "BAG_UPDATE", "ITEM_LOCK_CHANGED", "BAG_UPDATE_COOLDOWN", "PLAYERBANKSLOTS_CHANGED",
                     "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "PLAYER_MONEY", "PLAYER_LOGIN", "MERCHANT_SHOW",
                     "MAIL_SHOW", "AUCTION_HOUSE_SHOW", "TRADE_SHOW", "GUILDBANKFRAME_OPENED" }) do
    evenements:RegisterEvent(e)
end
local banqueOuverte = false
evenements:SetScript("OnEvent", function(self, event)
    if event == "BANKFRAME_OPENED" then
        banqueOuverte = true
        -- La fenêtre de banque du jeu doit rester « ouverte » pour le serveur : on la cache hors de l'écran.
        BankFrame:SetAlpha(0)
        BankFrame:EnableMouse(false)
        BankFrame:ClearAllPoints()
        BankFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMRIGHT", 100, -100)
        banque:Show()
        sacs:Show()
        Memoriser(BANQUE, "banque")
    elseif event == "BANKFRAME_CLOSED" then
        banqueOuverte = false
        banque:Hide()
    elseif event == "MERCHANT_SHOW" or event == "MAIL_SHOW" or event == "AUCTION_HOUSE_SHOW"
        or event == "TRADE_SHOW" or event == "GUILDBANKFRAME_OPENED" then
        sacs:Show()
    else
        if event == "PLAYERBANKSLOTS_CHANGED" or (banqueOuverte and event == "BAG_UPDATE") then
            Memoriser(BANQUE, "banque")
        end
        Memoriser(SACS, "sacs")
        Afficher(sacs)
        Afficher(banque)
    end
end)
banque:SetScript("OnHide", function()
    if banqueOuverte then CloseBankFrame() end
end)

SLASH_SOLAZEROTHSACS1 = "/sacs"
SlashCmdList["SOLAZEROTHSACS"] = function(texte)
    local nombre = tonumber(strmatch(texte or "", "colonnes%s+(%d+)"))
    if nombre then ReglerColonnes(nombre) else BasculerSacs() end
end
