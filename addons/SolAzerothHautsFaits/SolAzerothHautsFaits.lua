-- Hauts faits du compte (section 7.4, V4). Le serveur (hauts_faits.cpp, préfixe SOLHF) envoie, sur ".solhf liste" :
-- "HF;id;catégorie;nom;description;actuel;requis;obtenu;talent" pour chaque haut fait,
-- "RESUME;obtenus;total;points_talent;points_utilisables", "BONUS;texte" pour chaque bonus permanent (onglet Bonus),
-- puis "FIN" ; "OBTENU;id" à chaque nouveau haut fait.
-- Rangés par type (décision de l'utilisateur). Ouverture : menu Sol'Azeroth, ou /hf.

local PREFIXE = "SOLHF"
local LIGNES, HAUTEUR = 8, 46

local CATEGORIES = {
    { id = 0, nom = "Tous" },
    { id = 1, nom = "Donjons" },
    { id = 2, nom = "Défis de boss" },
    { id = 3, nom = "Défi extérieur" },
    { id = 4, nom = "Contrats" },
    { id = 5, nom = "Métiers" },
    { id = 6, nom = "Monde" },
    { id = 7, nom = "Exploits" },
    { id = 8, nom = "Bonus" },     -- pas une catégorie de hauts faits : les bonus permanents du compte
}
local BONUS = 8

local hautsFaits, enCours = {}, {}
local bonus, bonusEnCours = {}, {}
local resume = { obtenus = 0, total = 0, talents = 0, utilisables = 0 }
local categorie, masquerObtenus = 0, false
local affiches = {}

local function Commande(texte) SendChatMessage(texte, "SAY") end

------------------------------------------------------------------------
-- Fenêtre
------------------------------------------------------------------------
local cadre = CreateFrame("Frame", "SolAzerothHautsFaitsCadre", UIParent)
cadre:SetSize(620, 480)
cadre:SetPoint("CENTER", 0, 30)
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
tinsert(UISpecialFrames, "SolAzerothHautsFaitsCadre")

local entete = cadre:CreateTexture(nil, "ARTWORK")
entete:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
entete:SetSize(300, 64)
entete:SetPoint("TOP", 0, 12)
local titre = cadre:CreateFontString(nil, "OVERLAY", "GameFontNormal")
titre:SetPoint("TOP", entete, "TOP", 0, -14)
titre:SetText("Hauts faits du compte")

local fermer = CreateFrame("Button", nil, cadre, "UIPanelCloseButton")
fermer:SetPoint("TOPRIGHT", -6, -6)

local resumeTexte = cadre:CreateFontString(nil, "OVERLAY", "GameFontNormal")
resumeTexte:SetTextColor(0.3, 0.18, 0.07)
resumeTexte:SetPoint("TOPLEFT", 26, -38)
resumeTexte:SetWidth(560)
resumeTexte:SetJustifyH("LEFT")

local caseObtenus = CreateFrame("CheckButton", "SolAzerothHautsFaitsMasquer", cadre, "UICheckButtonTemplate")
caseObtenus:SetPoint("TOPRIGHT", -150, -54)
_G["SolAzerothHautsFaitsMasquerText"]:SetText("Masquer les obtenus")

-- Catégories (colonne de gauche)
local boutonsCategorie = {}
for i, c in ipairs(CATEGORIES) do
    local b = CreateFrame("Button", nil, cadre, "UIPanelButtonTemplate")
    b:SetSize(120, 24)
    b:SetPoint("TOPLEFT", 22, -84 - (i - 1) * 28)
    b:SetText(c.nom)
    b.categorie = c.id
    boutonsCategorie[i] = b
end

-- Liste
local liste = CreateFrame("ScrollFrame", "SolAzerothHautsFaitsListe", cadre, "FauxScrollFrameTemplate")
liste:SetPoint("TOPLEFT", 154, -84)
liste:SetSize(420, LIGNES * HAUTEUR)
local lignes = {}
for i = 1, LIGNES do
    local l = CreateFrame("Frame", nil, cadre)
    l:SetSize(420, HAUTEUR - 4)
    l:SetPoint("TOPLEFT", 154, -84 - (i - 1) * HAUTEUR)
    l:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                    edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    l.nom = l:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    l.nom:SetPoint("TOPLEFT", 8, -5)
    l.nom:SetWidth(300)
    l.nom:SetJustifyH("LEFT")
    l.description = l:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    l.description:SetPoint("TOPLEFT", l.nom, "BOTTOMLEFT", 0, -2)
    l.description:SetWidth(300)
    l.description:SetJustifyH("LEFT")
    l.barre = CreateFrame("StatusBar", nil, l)
    l.barre:SetSize(90, 12)
    l.barre:SetPoint("RIGHT", -10, -6)
    l.barre:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    l.barre:SetStatusBarColor(0.2, 0.6, 1)
    l.barre.fond = l.barre:CreateTexture(nil, "BACKGROUND")
    l.barre.fond:SetAllPoints()
    l.barre.fond:SetTexture(0, 0, 0, 0.5)
    l.barre.texte = l.barre:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    l.barre.texte:SetPoint("CENTER")
    l.talent = l:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    l.talent:SetPoint("TOPRIGHT", -10, -5)
    lignes[i] = l
end

-- Onglet Bonus : une ligne par bonus permanent, avec sa valeur actuelle.
local bonusTexte = cadre:CreateFontString(nil, "OVERLAY", "GameFontNormal")
bonusTexte:SetTextColor(0.3, 0.18, 0.07)
bonusTexte:SetPoint("TOPLEFT", 160, -90)
bonusTexte:SetWidth(420)
bonusTexte:SetJustifyH("LEFT")
bonusTexte:SetSpacing(8)

local function Rafraichir()
    resumeTexte:SetText(string.format("Obtenus : |cff7a2e1e%d / %d|r     Points de talent gagnés : |cff7a2e1e%d|r  (utilisables à ton niveau : %d)",
        resume.obtenus, resume.total, resume.talents, resume.utilisables))
    for _, b in ipairs(boutonsCategorie) do
        if b.categorie == categorie then b:LockHighlight() else b:UnlockHighlight() end
    end

    if categorie == BONUS then
        for i = 1, LIGNES do lignes[i]:Hide() end
        liste:Hide()
        local morceaux = {}
        for _, ligne in ipairs(bonus) do
            local nom, reste = ligne:match("^(.-) : (.*)$")
            morceaux[#morceaux + 1] = nom and ("|cff7a2e1e" .. nom .. " :|r " .. reste) or ligne
        end
        bonusTexte:SetText(#morceaux > 0 and table.concat(morceaux, "\n") or "Chargement...")
        bonusTexte:Show()
        return
    end
    bonusTexte:Hide()
    liste:Show()

    affiches = {}
    for _, hf in ipairs(hautsFaits) do
        if (categorie == 0 or hf.categorie == categorie) and not (masquerObtenus and hf.obtenu) then
            affiches[#affiches + 1] = hf
        end
    end

    local offset = FauxScrollFrame_GetOffset(liste)
    for i = 1, LIGNES do
        local l, hf = lignes[i], affiches[i + offset]
        if hf then
            l.nom:SetText(hf.nom)
            l.description:SetText(hf.description)
            l.barre:SetMinMaxValues(0, math.max(1, hf.requis))
            l.barre:SetValue(hf.actuel)
            l.barre.texte:SetText(hf.obtenu and "Obtenu" or (hf.actuel .. " / " .. hf.requis))
            l.talent:SetText(hf.talent and "+1 point de talent" or "")
            if hf.obtenu then
                l:SetBackdropColor(0.1, 0.3, 0.1, 0.9)
                l:SetBackdropBorderColor(0.3, 1, 0.3)
                l.nom:SetTextColor(0.4, 1, 0.4)
                l.barre:SetStatusBarColor(0.2, 0.8, 0.2)
            else
                l:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
                l:SetBackdropBorderColor(0.6, 0.6, 0.6)
                l.nom:SetTextColor(1, 0.82, 0)
                l.barre:SetStatusBarColor(0.2, 0.6, 1)
            end
            l:Show()
        else
            l:Hide()
        end
    end
    FauxScrollFrame_Update(liste, #affiches, LIGNES, HAUTEUR)
end

liste:SetScript("OnVerticalScroll", function(self, valeur)
    FauxScrollFrame_OnVerticalScroll(self, valeur, HAUTEUR, Rafraichir)
end)
for _, b in ipairs(boutonsCategorie) do
    b:SetScript("OnClick", function(self)
        categorie = self.categorie
        FauxScrollFrame_SetOffset(liste, 0)
        liste:SetVerticalScroll(0)
        Rafraichir()
    end)
end
caseObtenus:SetScript("OnClick", function(self)
    masquerObtenus = self:GetChecked() and true or false
    FauxScrollFrame_SetOffset(liste, 0)
    liste:SetVerticalScroll(0)
    Rafraichir()
end)

------------------------------------------------------------------------
-- Échanges avec le serveur
------------------------------------------------------------------------
local evenements = CreateFrame("Frame")
evenements:RegisterEvent("CHAT_MSG_ADDON")
evenements:SetScript("OnEvent", function(self, event, prefixe, message)
    if prefixe ~= PREFIXE then return end
    local champs = { strsplit(";", message) }
    if champs[1] == "HF" then
        table.insert(enCours, { id = tonumber(champs[2]), categorie = tonumber(champs[3]) or 0, nom = champs[4] or "?",
                                description = champs[5] or "", actuel = tonumber(champs[6]) or 0, requis = tonumber(champs[7]) or 1,
                                obtenu = champs[8] == "1", talent = champs[9] == "1" })
    elseif champs[1] == "RESUME" then
        resume.obtenus = tonumber(champs[2]) or 0
        resume.total = tonumber(champs[3]) or 0
        resume.talents = tonumber(champs[4]) or 0
        resume.utilisables = tonumber(champs[5]) or 0
    elseif champs[1] == "BONUS" then
        table.insert(bonusEnCours, champs[2] or "")
    elseif champs[1] == "FIN" then
        hautsFaits, enCours = enCours, {}
        bonus, bonusEnCours = bonusEnCours, {}
        if cadre:IsShown() then Rafraichir() end
    elseif champs[1] == "OBTENU" then
        PlaySound("LEVELUPSOUND")
        if cadre:IsShown() then Commande(".solhf liste") end
    end
end)

local function Basculer()
    if cadre:IsShown() then
        cadre:Hide()
    else
        cadre:Show()
        Rafraichir()
        Commande(".solhf liste")
    end
end

SLASH_SOLAZEROTHHAUTSFAITS1 = "/hf"
SlashCmdList["SOLAZEROTHHAUTSFAITS"] = Basculer
