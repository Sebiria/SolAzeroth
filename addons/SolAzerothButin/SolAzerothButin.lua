-- Fenêtre de choix du butin des boss de donjon. Le serveur (mod-solazeroth, butin.cpp) envoie
-- "CHOIX;jeton;boss;objet,objet,..." et attend ".solbutin choisir <jeton> <objet>".

-- Nom d'un objet, demandé au serveur par l'addon SolAzeroth s'il manque (chargé après cet addon).
local function NomSol(id)
    if SolAzerothNomObjet then return SolAzerothNomObjet(id) end
    return GetItemInfo(id)
end

local PREFIXE = "SOLBUTIN"
local COLONNES, TAILLE, ECART = 4, 40, 112

local file = {}          -- choix en attente, dans l'ordre d'arrivée
-- Nombre de choix en attente, pour la pastille de la fenêtre Sol'Azeroth.
function SolAzerothButinEnAttente() return #file end
local function Commande(texte) SendChatMessage(texte, "SAY") end

------------------------------------------------------------------------
-- Fenêtre
------------------------------------------------------------------------
local cadre = CreateFrame("Frame", "SolAzerothButinCadre", UIParent)
cadre:SetSize(500, 330)
cadre:SetPoint("CENTER", 0, 60)
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
tinsert(UISpecialFrames, "SolAzerothButinCadre")

local entete = cadre:CreateTexture(nil, "ARTWORK")
entete:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
entete:SetSize(360, 64)
entete:SetPoint("TOP", 0, 12)
local titre = cadre:CreateFontString(nil, "OVERLAY", "GameFontNormal")
titre:SetPoint("TOP", entete, "TOP", 0, -14)

local fermer = CreateFrame("Button", nil, cadre, "UIPanelCloseButton")
fermer:SetPoint("TOPRIGHT", -6, -6)

local consigne = cadre:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
consigne:SetPoint("TOP", 0, -36)
consigne:SetText("Choisis un objet. Survole pour voir ses caractéristiques.")

local compteur = cadre:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
compteur:SetPoint("BOTTOM", 0, 20)

-- Infobulle cachée qui sert à demander au serveur les objets encore inconnus du client.
local scan = CreateFrame("GameTooltip", "SolAzerothButinScan", UIParent, "GameTooltipTemplate")
scan:SetOwner(WorldFrame, "ANCHOR_NONE")

local boutons = {}
for i = 1, 16 do
    local b = CreateFrame("Button", nil, cadre)
    b:SetSize(TAILLE, TAILLE)
    local ligne, colonne = math.floor((i - 1) / COLONNES), (i - 1) % COLONNES
    b:SetPoint("TOPLEFT", 40 + colonne * ECART, -64 - ligne * 62)
    b.icone = b:CreateTexture(nil, "ARTWORK")
    b.icone:SetAllPoints()
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b.nom = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.nom:SetPoint("TOP", b, "BOTTOM", 0, -2)
    b.nom:SetWidth(ECART - 6)
    b.nom:SetHeight(20)
    -- Comparaison avec l'équipement porté affichée d'office au survol, sans Maj, et retirée en partant.
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink("item:" .. self.objet .. ":0:0:0:0:0:0:0")
        GameTooltip:Show()
        GameTooltip_ShowCompareItem(GameTooltip)
    end)
    b:SetScript("OnLeave", function()
        GameTooltip:Hide()
        ShoppingTooltip1:Hide()
        ShoppingTooltip2:Hide()
    end)
    b:SetScript("OnClick", function(self)
        local nom = NomSol(self.objet) or "cet objet"
        StaticPopup_Show("SOLAZEROTH_BUTIN_CONFIRMER", nom, nil, { jeton = file[1].jeton, objet = self.objet })
    end)
    boutons[i] = b
end

StaticPopupDialogs["SOLAZEROTH_BUTIN_CONFIRMER"] = {
    text = "Prendre %s ?",
    button1 = YES,
    button2 = NO,
    OnAccept = function(self, donnees)
        Commande(".solbutin choisir " .. donnees.jeton .. " " .. donnees.objet)
    end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

local function NomObjet(objet)
    local _, _, qualite = GetItemInfo(objet)
    local nom = NomSol(objet)
    if not nom then return "|cff808080...|r" end
    local couleur = ITEM_QUALITY_COLORS[qualite]
    return (couleur and couleur.hex or "|cffffffff") .. nom .. "|r"
end

local function Afficher()
    local choix = file[1]
    if not choix then cadre:Hide() return end
    if choix.rang > 0 then
        titre:SetText("Butin : " .. choix.boss .. " (rang " .. choix.rang .. ")")
        consigne:SetText("L'objet choisi recevra un bonus de caractéristique lié au rang " .. choix.rang .. ".")
    else
        titre:SetText("Butin : " .. choix.boss)
        consigne:SetText("Choisis un objet. Survole pour voir ses caractéristiques.")
    end
    compteur:SetText(#file > 1 and string.format("Encore %d choix en attente après celui-ci", #file - 1) or "")
    for i, b in ipairs(boutons) do
        local objet = choix.objets[i]
        if objet then
            b.objet = objet
            b.icone:SetTexture(GetItemIcon(objet) or "Interface\\Icons\\INV_Misc_QuestionMark")
            b.nom:SetText(NomObjet(objet))
            b:Show()
        else
            b:Hide()
        end
    end
    local lignes = math.ceil(#choix.objets / COLONNES)
    cadre:SetHeight(110 + lignes * 62)
    cadre:Show()
end

-- Rafraîchit les noms pendant quelques secondes, le temps que le serveur réponde.
local attente = 0
cadre:SetScript("OnUpdate", function(self, ecoule)
    attente = attente + ecoule
    if attente > 0.5 then
        attente = 0
        for _, b in ipairs(boutons) do
            if b:IsShown() then b.nom:SetText(NomObjet(b.objet)) end
        end
    end
end)

local function Ajouter(jeton, boss, liste, rang)
    for _, c in ipairs(file) do
        if c.jeton == jeton then return end
    end
    local objets = {}
    for objet in string.gmatch(liste, "%d+") do
        objet = tonumber(objet)
        table.insert(objets, objet)
        if not GetItemInfo(objet) then
            scan:SetHyperlink("item:" .. objet .. ":0:0:0:0:0:0:0")
        end
    end
    table.insert(file, { jeton = jeton, boss = boss, objets = objets, rang = rang or 0 })
    PlaySound("LEVELUPSOUND")
    Afficher()
end

local function Retirer(jeton)
    for i, c in ipairs(file) do
        if c.jeton == jeton then
            table.remove(file, i)
            break
        end
    end
    Afficher()
end

------------------------------------------------------------------------
-- Échanges avec le serveur
------------------------------------------------------------------------
local evenements = CreateFrame("Frame")
evenements:RegisterEvent("CHAT_MSG_ADDON")
evenements:RegisterEvent("PLAYER_ENTERING_WORLD")

-- Partout ailleurs (sacs, butin, marchands) : comparaison automatique au survol, sans Maj.
pcall(SetCVar, "alwaysCompareItems", "1")

local delai = 0
local function DemanderListe(self, ecoule)
    delai = delai + ecoule
    if delai >= 3 then
        self:SetScript("OnUpdate", nil)
        Commande(".solbutin liste")
    end
end

evenements:SetScript("OnEvent", function(self, event, prefixe, message)
    if event == "PLAYER_ENTERING_WORLD" then
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        delai = 0
        self:SetScript("OnUpdate", DemanderListe)
        return
    end
    if prefixe ~= PREFIXE then return end
    local type, jeton, boss, liste, rang = strsplit(";", message)
    if type == "CHOIX" then
        Ajouter(tonumber(jeton), boss, liste or "", tonumber(rang))
    elseif type == "FAIT" then
        Retirer(tonumber(jeton))
    end
end)

SLASH_SOLAZEROTHBUTIN1 = "/butin"
SlashCmdList["SOLAZEROTHBUTIN"] = function()
    if #file > 0 then Afficher() else DEFAULT_CHAT_FRAME:AddMessage("Aucun butin en attente.") end
end
