-- Nouveau grimoire (section 3.9, V3b) : les sorts achetés aux autres classes, rangés par classe.
-- Le client ne sait pas à quelle classe appartient un sort : le serveur (formation.cpp) l'envoie sur demande
-- (".solform grimoire" -> "GDEBUT", "G|classe:sort;...", "GFIN", préfixe SOLFORM).
-- Le grimoire d'origine garde ces sorts dans son onglet Général (un addon ne peut pas les en retirer) ; ici ils sont
-- rangés dans un onglet par classe, au plus haut rang connu. Clic : lancer le sort. Glisser : le poser sur une barre.
-- Ouverture : bouton « Autres classes » sur le grimoire d'origine, ou /grimoire.

local PREFIXE = "SOLFORM"
local PAR_PAGE = 14

local CLASSES = {
    [1] = "Guerrier", [2] = "Paladin", [3] = "Chasseur", [4] = "Voleur", [5] = "Prêtre",
    [6] = "Chevalier de la mort", [7] = "Chaman", [8] = "Mage", [9] = "Démoniste", [11] = "Druide",
}
local ORDRE = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 11 }

local sortsParClasse, enCours = {}, {}
local classeChoisie, page = nil, 1
local aRafraichir = false

local function Commande(texte) SendChatMessage(texte, "SAY") end

------------------------------------------------------------------------
-- Fenêtre
------------------------------------------------------------------------
local cadre = CreateFrame("Frame", "SolAzerothGrimoireCadre", UIParent)
cadre:SetSize(420, 470)
cadre:SetPoint("LEFT", 40, 40)
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
tinsert(UISpecialFrames, "SolAzerothGrimoireCadre")

local entete = cadre:CreateTexture(nil, "ARTWORK")
entete:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
entete:SetSize(300, 64)
entete:SetPoint("TOP", 0, 12)
local titre = cadre:CreateFontString(nil, "OVERLAY", "GameFontNormal")
titre:SetPoint("TOP", entete, "TOP", 0, -14)
titre:SetText("Grimoire des autres classes")

local fermer = CreateFrame("Button", nil, cadre, "UIPanelCloseButton")
fermer:SetPoint("TOPRIGHT", -6, -6)

local vide = cadre:CreateFontString(nil, "OVERLAY", "GameFontDisable")
vide:SetPoint("CENTER")
vide:SetWidth(360)
vide:SetText("Aucun sort d'une autre classe. Achète-en dans l'onglet Classes de l'apprentissage (/apprendre).")

-- Onglets de classe (2 rangées de 5)
local onglets = {}
for i = 1, #ORDRE do
    local b = CreateFrame("Button", nil, cadre, "UIPanelButtonTemplate")
    b:SetSize(74, 20)
    b:Hide()
    onglets[i] = b
end

-- Sorts : boutons sécurisés (lancer au clic), 2 colonnes de 7
local boutons = {}
for i = 1, PAR_PAGE do
    local b = CreateFrame("Button", "SolAzerothGrimoireSort" .. i, cadre, "SecureActionButtonTemplate")
    b:SetSize(36, 36)
    local colonne, ligne = (i - 1) % 2, math.floor((i - 1) / 2)
    b:SetPoint("TOPLEFT", 28 + colonne * 190, -92 - ligne * 46)
    b:RegisterForClicks("AnyUp")
    b:RegisterForDrag("LeftButton")
    b.icone = b:CreateTexture(nil, "ARTWORK")
    b.icone:SetAllPoints()
    b.recharge = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
    b.recharge:SetAllPoints()
    b.nom = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    b.nom:SetPoint("TOPLEFT", b, "TOPRIGHT", 6, -2)
    b.nom:SetWidth(140)
    b.nom:SetJustifyH("LEFT")
    b.rang = b:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    b.rang:SetPoint("TOPLEFT", b.nom, "BOTTOMLEFT", 0, -2)
    b:SetScript("OnDragStart", function(self)
        if self.index then PickupSpell(self.index, BOOKTYPE_SPELL) end
    end)
    b:SetScript("OnEnter", function(self)
        if not self.index then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetSpell(self.index, BOOKTYPE_SPELL)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:Hide()
    boutons[i] = b
end

local pageTexte = cadre:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
pageTexte:SetPoint("BOTTOM", 0, 26)
local precedent = CreateFrame("Button", nil, cadre, "UIPanelButtonTemplate")
precedent:SetSize(90, 22)
precedent:SetPoint("BOTTOMLEFT", 24, 20)
precedent:SetText("Précédente")
local suivant = CreateFrame("Button", nil, cadre, "UIPanelButtonTemplate")
suivant:SetSize(90, 22)
suivant:SetPoint("BOTTOMRIGHT", -24, 20)
suivant:SetText("Suivante")

------------------------------------------------------------------------
-- Contenu
------------------------------------------------------------------------
-- Emplacement de chaque sort dans le grimoire du client (identifiant -> index).
local function IndexDuGrimoire()
    local index = {}
    local total = 0
    for onglet = 1, GetNumSpellTabs() do
        local _, _, debut, nombre = GetSpellTabInfo(onglet)
        total = math.max(total, debut + nombre)
    end
    for i = 1, total do
        local lien = GetSpellLink(i, BOOKTYPE_SPELL)
        local id = lien and tonumber(strmatch(lien, "spell:(%d+)"))
        if id then index[id] = i end
    end
    return index
end

-- Sorts d'une classe présents dans le grimoire, au plus haut rang (le dernier dans le grimoire), par ordre du grimoire.
local function SortsDe(classe, index)
    local parNom = {}
    for _, id in ipairs(sortsParClasse[classe] or {}) do
        local i = index[id]
        if i then
            local nom = GetSpellName(i, BOOKTYPE_SPELL)
            if nom and (not parNom[nom] or parNom[nom] < i) then parNom[nom] = i end
        end
    end
    local liste = {}
    for _, i in pairs(parNom) do liste[#liste + 1] = i end
    table.sort(liste)
    return liste
end

local function Rafraichir()
    if InCombatLockdown() then
        aRafraichir = true
        return
    end
    aRafraichir = false
    local index = IndexDuGrimoire()

    -- Onglets : classes dont au moins un sort est connu.
    local presentes = {}
    for _, c in ipairs(ORDRE) do
        if #SortsDe(c, index) > 0 then presentes[#presentes + 1] = c end
    end
    local trouvee = false
    for _, c in ipairs(presentes) do if c == classeChoisie then trouvee = true end end
    if not trouvee then classeChoisie = nil end
    classeChoisie = classeChoisie or presentes[1]
    for i, b in ipairs(onglets) do
        local c = presentes[i]
        if c then
            b:SetText(CLASSES[c] == "Chevalier de la mort" and "Chev. mort" or CLASSES[c])
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", 24 + ((i - 1) % 5) * 76, -36 - math.floor((i - 1) / 5) * 22)
            b:SetScript("OnClick", function() classeChoisie, page = c, 1 Rafraichir() end)
            if c == classeChoisie then b:LockHighlight() else b:UnlockHighlight() end
            b:Show()
        else
            b:Hide()
        end
    end

    local liste = classeChoisie and SortsDe(classeChoisie, index) or {}
    local pages = math.max(1, math.ceil(#liste / PAR_PAGE))
    page = math.min(page, pages)
    for n, b in ipairs(boutons) do
        local i = liste[(page - 1) * PAR_PAGE + n]
        if i then
            local nom, rang = GetSpellName(i, BOOKTYPE_SPELL)
            b.index = i
            b.icone:SetTexture(GetSpellTexture(i, BOOKTYPE_SPELL))
            b.nom:SetText(nom)
            b.rang:SetText(IsPassiveSpell(i, BOOKTYPE_SPELL) and "Passif" or (rang or ""))
            b:SetAttribute("type", "spell")
            b:SetAttribute("spell", nom)
            local debut, duree, actif = GetSpellCooldown(i, BOOKTYPE_SPELL)
            if debut and duree and duree > 1.5 then CooldownFrame_SetTimer(b.recharge, debut, duree, actif) else b.recharge:Hide() end
            b:Show()
        else
            b.index = nil
            b:SetAttribute("type", nil)
            b:Hide()
        end
    end
    pageTexte:SetText(#liste > 0 and ("Page " .. page .. " / " .. pages) or "")
    if page > 1 then precedent:Enable() else precedent:Disable() end
    if page < pages then suivant:Enable() else suivant:Disable() end
    if #presentes == 0 then vide:Show() else vide:Hide() end
end

precedent:SetScript("OnClick", function() page = page - 1 Rafraichir() end)
suivant:SetScript("OnClick", function() page = page + 1 Rafraichir() end)

------------------------------------------------------------------------
-- Échanges avec le serveur
------------------------------------------------------------------------
local demande = 0
local function Demander()
    -- Une demande au plus toutes les 2 secondes (les apprentissages arrivent parfois en rafale).
    if GetTime() - demande < 2 then return end
    demande = GetTime()
    Commande(".solform grimoire")
end

local evenements = CreateFrame("Frame")
evenements:RegisterEvent("CHAT_MSG_ADDON")
evenements:RegisterEvent("PLAYER_ENTERING_WORLD")
evenements:RegisterEvent("LEARNED_SPELL_IN_TAB")
evenements:RegisterEvent("SPELL_UPDATE_COOLDOWN")
evenements:RegisterEvent("PLAYER_REGEN_ENABLED")
evenements:SetScript("OnEvent", function(self, event, prefixe, message)
    if event == "CHAT_MSG_ADDON" then
        if prefixe ~= PREFIXE then return end
        if message == "GDEBUT" then
            enCours = {}
        elseif strsub(message, 1, 2) == "G|" then
            for classe, sort in string.gmatch(strsub(message, 3), "(%d+):(%d+)") do
                classe, sort = tonumber(classe), tonumber(sort)
                enCours[classe] = enCours[classe] or {}
                table.insert(enCours[classe], sort)
            end
        elseif message == "GFIN" then
            sortsParClasse = enCours
            if cadre:IsShown() then Rafraichir() end
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        local attente = 0
        self:SetScript("OnUpdate", function(f, ecoule)
            attente = attente + ecoule
            if attente >= 3 then
                f:SetScript("OnUpdate", nil)
                Demander()
            end
        end)
    elseif event == "LEARNED_SPELL_IN_TAB" then
        Demander()
    elseif event == "SPELL_UPDATE_COOLDOWN" then
        if cadre:IsShown() then Rafraichir() end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if aRafraichir and cadre:IsShown() then Rafraichir() end
    end
end)

local function Basculer()
    if InCombatLockdown() then return end
    if cadre:IsShown() then
        cadre:Hide()
    else
        cadre:Show()
        Rafraichir()
        Demander()
    end
end

SLASH_SOLAZEROTHGRIMOIRE1 = "/grimoire"
SlashCmdList["SOLAZEROTHGRIMOIRE"] = Basculer

-- Bouton sur le grimoire d'origine
local ouvrir = CreateFrame("Button", nil, SpellBookFrame, "UIPanelButtonTemplate")
ouvrir:SetSize(110, 22)
ouvrir:SetPoint("TOPRIGHT", SpellBookFrame, "TOPRIGHT", -44, -40)
ouvrir:SetText("Autres classes")
ouvrir:SetScript("OnClick", Basculer)
