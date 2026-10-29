-- Journal de collection (section 7.3, V4 étape 5), façon OSRS : une case par objet de chaque boss, pour tout le compte.
-- Le serveur (journal_collection.cpp, préfixe SOLJOURNAL) envoie :
--   ".soljournal instances" -> "I;carte;raid;extension;nom;obtenus;total" …, "RESUME;obtenus;total", "FIN"
--   ".soljournal instance <carte>" -> "B;boss;nom;obtenus;total", "O;boss;objet:0|1,…" …, "FINI;carte"
--   "NOUVEAU;objet" à chaque nouvel objet collectionné.
-- Ouverture : menu Sol'Azeroth, ou /journal.

local PREFIXE = "SOLJOURNAL"
local LIGNES_INSTANCES, HAUTEUR_INSTANCE = 18, 22
local COLONNES, TAILLE = 10, 34

local instances, instancesEnCours = {}, {}
local resume = { obtenus = 0, total = 0 }
local raids = false                -- onglet : donjons ou raids
local choisie                      -- carte de l'instance affichée
local boss, bossEnCours = {}, {}   -- boss de l'instance affichée : { entree, nom, obtenus, total, objets = { {id, obtenu} } }
local masquerObtenus = false

local function Commande(texte) SendChatMessage(texte, "SAY") end

------------------------------------------------------------------------
-- Fenêtre
------------------------------------------------------------------------
local cadre = CreateFrame("Frame", "SolAzerothJournalCadre", UIParent)
cadre:SetSize(780, 540)
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
tinsert(UISpecialFrames, "SolAzerothJournalCadre")

local entete = cadre:CreateTexture(nil, "ARTWORK")
entete:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
entete:SetSize(320, 64)
entete:SetPoint("TOP", 0, 12)
local titre = cadre:CreateFontString(nil, "OVERLAY", "GameFontNormal")
titre:SetPoint("TOP", entete, "TOP", 0, -14)
titre:SetText("Journal de collection")

local fermer = CreateFrame("Button", nil, cadre, "UIPanelCloseButton")
fermer:SetPoint("TOPRIGHT", -6, -6)

local resumeTexte = cadre:CreateFontString(nil, "OVERLAY", "GameFontNormal")
resumeTexte:SetTextColor(0.3, 0.18, 0.07)
resumeTexte:SetPoint("TOPLEFT", 26, -38)

local caseObtenus = CreateFrame("CheckButton", "SolAzerothJournalMasquer", cadre, "UICheckButtonTemplate")
caseObtenus:SetPoint("TOPRIGHT", -170, -32)
_G["SolAzerothJournalMasquerText"]:SetText("Masquer les obtenus")

-- Onglets Donjons / Raids
local boutonDonjons = CreateFrame("Button", nil, cadre, "UIPanelButtonTemplate")
boutonDonjons:SetSize(108, 22)
boutonDonjons:SetPoint("TOPLEFT", 22, -60)
boutonDonjons:SetText("Donjons")
local boutonRaids = CreateFrame("Button", nil, cadre, "UIPanelButtonTemplate")
boutonRaids:SetSize(108, 22)
boutonRaids:SetPoint("LEFT", boutonDonjons, "RIGHT", 4, 0)
boutonRaids:SetText("Raids")

-- Liste des instances (colonne de gauche)
local listeInstances = CreateFrame("ScrollFrame", "SolAzerothJournalInstances", cadre, "FauxScrollFrameTemplate")
listeInstances:SetPoint("TOPLEFT", 22, -88)
listeInstances:SetSize(200, LIGNES_INSTANCES * HAUTEUR_INSTANCE)
local lignesInstances = {}
for i = 1, LIGNES_INSTANCES do
    local b = CreateFrame("Button", nil, cadre)
    b:SetSize(200, HAUTEUR_INSTANCE - 2)
    b:SetPoint("TOPLEFT", 22, -88 - (i - 1) * HAUTEUR_INSTANCE)
    b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    b.fond = b:CreateTexture(nil, "BACKGROUND")
    b.fond:SetAllPoints()
    b.fond:SetTexture(0, 0, 0, 0.6)
    b.nom = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    b.nom:SetPoint("LEFT", 4, 0)
    b.nom:SetWidth(140)
    b.nom:SetJustifyH("LEFT")
    b.compte = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.compte:SetPoint("RIGHT", -4, 0)
    b:Hide()
    lignesInstances[i] = b
end

-- Objets (à droite), dans une zone défilante
local zone = CreateFrame("ScrollFrame", "SolAzerothJournalZone", cadre, "UIPanelScrollFrameTemplate")
zone:SetPoint("TOPLEFT", 250, -64)
zone:SetSize(480, 450)
local contenu = CreateFrame("Frame", nil, zone)
contenu:SetSize(480, 450)
zone:SetScrollChild(contenu)

local vide = cadre:CreateFontString(nil, "OVERLAY", "GameFontNormal")
vide:SetTextColor(0.3, 0.18, 0.07)
vide:SetPoint("CENTER", zone, "CENTER")
vide:SetText("Choisis une instance à gauche.")

local titresBoss, cases = {}, {}
local function TitreBoss(i)
    if not titresBoss[i] then
        local t = contenu:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        t:SetTextColor(0.32, 0.08, 0.03)
        t:SetJustifyH("LEFT")
        t:SetWidth(460)
        titresBoss[i] = t
    end
    return titresBoss[i]
end
local function Case(i)
    if not cases[i] then
        local b = CreateFrame("Button", nil, contenu)
        b:SetSize(TAILLE, TAILLE)
        b.icone = b:CreateTexture(nil, "ARTWORK")
        b.icone:SetAllPoints()
        b.coche = b:CreateTexture(nil, "OVERLAY")
        b.coche:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        b.coche:SetSize(18, 18)
        b.coche:SetPoint("BOTTOMRIGHT", 4, -4)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink("item:" .. self.objet)
            GameTooltip:AddLine(self.obtenu and "|cff40ff40Dans ta collection|r" or "|cff999999Pas encore obtenu|r")
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        b:SetScript("OnClick", function(self)
            if IsModifiedClick("CHATLINK") then
                local _, lien = GetItemInfo(self.objet)
                if lien then ChatEdit_InsertLink(lien) end
            end
        end)
        cases[i] = b
    end
    return cases[i]
end

local function AfficherObjets()
    for _, t in pairs(titresBoss) do t:Hide() end
    for _, c in pairs(cases) do c:Hide() end
    if not choisie or #boss == 0 then
        vide:Show()
        return
    end
    vide:Hide()
    local y, n = 0, 0
    for i, b in ipairs(boss) do
        local t = TitreBoss(i)
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", 0, -y)
        local couleur = b.obtenus >= b.total and "40ff40" or "ffd100"
        t:SetText(string.format("%s  |cff%s%d / %d|r", b.nom, couleur, b.obtenus, b.total))
        t:Show()
        y = y + 18
        local col = 0
        for _, o in ipairs(b.objets) do
            if not (masquerObtenus and o.obtenu) then
                n = n + 1
                local c = Case(n)
                c.objet, c.obtenu = o.id, o.obtenu
                c.icone:SetTexture(GetItemIcon(o.id) or "Interface\\Icons\\INV_Misc_QuestionMark")
                c.icone:SetDesaturated(not o.obtenu)
                c.icone:SetAlpha(o.obtenu and 1 or 0.55)
                if o.obtenu then c.coche:Show() else c.coche:Hide() end
                c:ClearAllPoints()
                c:SetPoint("TOPLEFT", col * (TAILLE + 4), -y)
                c:Show()
                col = col + 1
                if col >= COLONNES then
                    col = 0
                    y = y + TAILLE + 4
                end
            end
        end
        if col > 0 then y = y + TAILLE + 4 end
        y = y + 8
    end
    contenu:SetHeight(math.max(450, y))
end

local affichees = {}
local function RafraichirInstances()
    resumeTexte:SetText(string.format("Collection du compte : |cff7a2e1e%d / %d|r objets", resume.obtenus, resume.total))
    if raids then boutonRaids:LockHighlight() boutonDonjons:UnlockHighlight()
    else boutonDonjons:LockHighlight() boutonRaids:UnlockHighlight() end
    affichees = {}
    for _, inst in ipairs(instances) do
        if inst.raid == raids then affichees[#affichees + 1] = inst end
    end
    local decalage = FauxScrollFrame_GetOffset(listeInstances)
    for i = 1, LIGNES_INSTANCES do
        local b, inst = lignesInstances[i], affichees[i + decalage]
        if inst then
            b.carte = inst.carte
            b.nom:SetText(inst.nom)
            if inst.carte == choisie then b.nom:SetTextColor(1, 1, 1) else b.nom:SetTextColor(1, 0.82, 0) end
            local couleur = inst.obtenus >= inst.total and "40ff40" or "ffffff"
            b.compte:SetText(string.format("|cff%s%d/%d|r", couleur, inst.obtenus, inst.total))
            b.fond:SetTexture(inst.carte == choisie and 0.3 or 0, inst.carte == choisie and 0.25 or 0, 0, 0.45)
            b:Show()
        else
            b:Hide()
        end
    end
    FauxScrollFrame_Update(listeInstances, #affichees, LIGNES_INSTANCES, HAUTEUR_INSTANCE)
end

listeInstances:SetScript("OnVerticalScroll", function(self, valeur)
    FauxScrollFrame_OnVerticalScroll(self, valeur, HAUTEUR_INSTANCE, RafraichirInstances)
end)
for _, b in ipairs(lignesInstances) do
    b:SetScript("OnClick", function(self)
        choisie = self.carte
        boss, bossEnCours = {}, {}
        RafraichirInstances()
        AfficherObjets()
        zone:SetVerticalScroll(0)
        Commande(".soljournal instance " .. self.carte)
    end)
end
boutonDonjons:SetScript("OnClick", function()
    raids = false
    FauxScrollFrame_SetOffset(listeInstances, 0)
    listeInstances:SetVerticalScroll(0)
    RafraichirInstances()
end)
boutonRaids:SetScript("OnClick", function()
    raids = true
    FauxScrollFrame_SetOffset(listeInstances, 0)
    listeInstances:SetVerticalScroll(0)
    RafraichirInstances()
end)
caseObtenus:SetScript("OnClick", function(self)
    masquerObtenus = self:GetChecked() and true or false
    AfficherObjets()
end)

------------------------------------------------------------------------
-- Échanges avec le serveur
------------------------------------------------------------------------
local evenements = CreateFrame("Frame")
evenements:RegisterEvent("CHAT_MSG_ADDON")
evenements:SetScript("OnEvent", function(self, event, prefixe, message)
    if prefixe ~= PREFIXE then return end
    local champs = { strsplit(";", message) }
    local type = champs[1]
    if type == "I" then
        table.insert(instancesEnCours, { carte = tonumber(champs[2]), raid = champs[3] == "1", extension = tonumber(champs[4]) or 0,
                                         nom = champs[5] or "?", obtenus = tonumber(champs[6]) or 0, total = tonumber(champs[7]) or 0 })
    elseif type == "RESUME" then
        resume.obtenus = tonumber(champs[2]) or 0
        resume.total = tonumber(champs[3]) or 0
    elseif type == "FIN" then
        -- Par extension, puis par nom.
        table.sort(instancesEnCours, function(a, b)
            if a.extension ~= b.extension then return a.extension < b.extension end
            return a.nom < b.nom
        end)
        instances, instancesEnCours = instancesEnCours, {}
        if cadre:IsShown() then RafraichirInstances() end
    elseif type == "B" then
        table.insert(bossEnCours, { entree = tonumber(champs[2]), nom = champs[3] or "?", obtenus = tonumber(champs[4]) or 0,
                                    total = tonumber(champs[5]) or 0, objets = {} })
    elseif type == "O" then
        local b = bossEnCours[#bossEnCours]
        if b and b.entree == tonumber(champs[2]) then
            for id, obtenu in string.gmatch(champs[3] or "", "(%d+):(%d)") do
                table.insert(b.objets, { id = tonumber(id), obtenu = obtenu == "1" })
            end
        end
    elseif type == "FINI" then
        if tonumber(champs[2]) == choisie then
            boss, bossEnCours = bossEnCours, {}
            if cadre:IsShown() then AfficherObjets() end
        else
            bossEnCours = {}
        end
    elseif type == "NOUVEAU" then
        PlaySound("igQuestListComplete")
        if cadre:IsShown() then
            Commande(".soljournal instances")
            if choisie then Commande(".soljournal instance " .. choisie) end
        end
    end
end)

local function Basculer()
    if cadre:IsShown() then
        cadre:Hide()
    else
        cadre:Show()
        RafraichirInstances()
        AfficherObjets()
        Commande(".soljournal instances")
        if choisie then Commande(".soljournal instance " .. choisie) end
    end
end

SLASH_SOLAZEROTHJOURNAL1 = "/journal"
SlashCmdList["SOLAZEROTHJOURNAL"] = Basculer
