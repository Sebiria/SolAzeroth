-- Sol'Azeroth v3 (01/11/2026, proposition validée : « Accès aux fonctionnalités — proposition.md », maquette du même
-- jour) : les carnets. Six carnets à onglets (et le Lexique, ajouté le même jour) rangent toutes les fenêtres ; la barre, le menu de la mini-carte et les
-- touches lisent cette seule liste (S.CARNETS).
-- - Un onglet montre une fenêtre existante (et sa page) ; une colonne à gauche de la fenêtre donne le nom du carnet et
--   ses onglets. Un seul carnet est ouvert à la fois ; chacun se souvient de son dernier onglet.
-- - Touches : C, K, N, P, B et L, posées à la première connexion à la place de celles du jeu (personnage, talents,
--   grimoire, sacs, journal), sauf si le joueur les a déjà changées. Elles se changent dans Techniques › Raccourcis.
--   Les sacs du jeu sont remplacés par Collection › Inventaire (SolUI_Inventaire.lua).
-- - S.Annonce(texte, action) : bandeau cliquable en haut de l'écran (modes de zone ouverts, zone de repos).

local S = SolUI

local function Fenetre(nom) return function() return _G[nom] end end

S.CARNETS = {
    { id = "personnage", nom = "Personnage", touche = "C", icone = "INV_Helmet_04", onglets = {
        { nom = "Fiche", cadre = Fenetre("CharacterFrame"), ouvrir = function()
            if not CharacterFrame:IsShown() then ToggleCharacter("PaperDollFrame") end
        end, place = false },
        { nom = "Âme", cadre = Fenetre("SolUIAme") },
        { nom = "Spécialisation", cadre = Fenetre("SolAzerothKitCadre") },
    } },
    { id = "techniques", nom = "Techniques", touche = "K", icone = "Ability_Warrior_DefensiveStance", onglets = {
        { nom = "Raccourcis", cadre = Fenetre("SolUIRaccourcis"), page = function() S.PageRaccourcis(1) end },
        { nom = "Techniques équipées", cadre = Fenetre("SolUIRaccourcis"), page = function() S.PageRaccourcis(2) end },
    } },
    { id = "camp", nom = "Camp", touche = "N", icone = "Spell_Fire_Fire", onglets = {
        { nom = "Feu, potion et arbre", cadre = Fenetre("SolUIRaccourcis"), page = function() S.PageRaccourcis(3) end },
        { nom = "Cuisine", cadre = Fenetre("SolUIEquipement"), page = function() S.PageEquipement(1, "Cuisine") end },
    } },
    { id = "artisanat", nom = "Artisanat", touche = "P", icone = "Trade_BlackSmithing", onglets = {
        { nom = "Fabrication", cadre = Fenetre("SolUIEquipement"), page = function() S.PageEquipement(1) end },
        { nom = "Amélioration", cadre = Fenetre("SolUIEquipement"), page = function() S.PageEquipement(2) end },
        { nom = "Désenchantement", cadre = Fenetre("SolUIEquipement"), page = function() S.PageEquipement(3) end },
        { nom = "Enchantement", cadre = Fenetre("SolUIEquipement"), page = function() S.PageEquipement(4) end },
        { nom = "Joaillerie", cadre = Fenetre("SolUIEquipement"), page = function() S.PageEquipement(5) end },
    } },
    { id = "collection", nom = "Collection", touche = "B", icone = "INV_Crate_04", onglets = {
        { nom = "Inventaire", cadre = Fenetre("SolUIInventaire") },
        { nom = "Composants", cadre = Fenetre("SolUICollection") },
    } },
    { id = "aventure", nom = "Aventure", touche = "L", icone = "INV_Misc_Map_01", onglets = {
        { nom = "Quêtes", cadre = Fenetre("SolUIJournal"), ouvrir = function() S.OuvrirJournal() end },
        { nom = "Zone", cadre = Fenetre("SolUIObjectifs") },
        { nom = "Rang d'aventurier", cadre = Fenetre("SolUIAventurier"), page = function() S.PageAventurier(1) end },
        { nom = "Montures", cadre = Fenetre("SolUIAventurier"), page = function() S.PageAventurier(2) end },
        -- Lot 5 : registre de complétion (SolUI_Aventurier.lua).
        { nom = "Registre", cadre = Fenetre("SolUIAventurier"), page = function() S.PageAventurier(3) end },
        { nom = "Passifs extérieurs", cadre = Fenetre("SolUIPassifs"), page = function() S.PagePassifs(2) end },
        { nom = "Donjons", cadre = Fenetre("SolUIPassifs"), page = function() S.PagePassifs(1) end },
        -- 02/11/2026 : retour dans un donjon terminé, remis à zéro (SolUI_Passifs.lua).
        { nom = "Téléportation", cadre = Fenetre("SolUITeleportation") },
    } },
    -- 01/11/2026 : le lexique, un onglet par thème (SolUI_Lexique.lua).
    { id = "lexique", nom = "Lexique", touche = "J", icone = "INV_Misc_Book_09", onglets = S.OngletsLexique() },
}
S.CARNET = {}
for _, c in ipairs(S.CARNETS) do S.CARNET[c.id] = c end

-- Touches du jeu que les carnets remplacent à la première connexion (celles de Blizzard par défaut, ou aucune).
local REMPLACABLES = { [""] = true, TOGGLECHARACTER0 = true, TOGGLETALENTS = true, TOGGLESPELLBOOK = true,
    OPENALLBAGS = true, TOGGLEBACKPACK = true, TOGGLEQUESTLOG = true, TOGGLESTATISTICS = true }

------------------------------------------------------------------------
-- Colonne d'onglets
------------------------------------------------------------------------
local LARGEUR, HAUT_ONGLET = 200, 40
local colonne = CreateFrame("Frame", "SolUICarnet", S.racine)
colonne:SetWidth(LARGEUR)
colonne:EnableMouse(true)
S.Panneau(colonne, 0.97)
colonne:Hide()
local titre = S.Texte(colonne, "Bold", 18, "clair")
titre:SetPoint("TOPLEFT", 16, -16)
local touche = S.Texte(colonne, "Regular", 11, "gris")
touche:SetPoint("TOPLEFT", titre, "BOTTOMLEFT", 0, -4)
local boutons = {}
for i = 1, 7 do
    local b = S.BoutonPlat(colonne, "", LARGEUR - 24, 34, 12)
    b:SetPoint("TOPLEFT", 12, -64 - (i - 1) * HAUT_ONGLET)
    boutons[i] = b
end

local ouvert, cadreOuvert, changement = nil, nil, false
local memoire = {}
local suivis = {}

local function CommandeTouche(c) return "CLICK SolUICarnet" .. c.id .. ":LeftButton" end
function S.ToucheCarnet(c)
    local t = GetBindingKey(CommandeTouche(c))
    return t and S.ToucheCourte(t) or nil
end

local function Fermer()
    colonne:Hide()
    if cadreOuvert and cadreOuvert:IsShown() then
        if cadreOuvert == CharacterFrame then HideUIPanel(CharacterFrame) else cadreOuvert:Hide() end
    end
    ouvert, cadreOuvert = nil, nil
end

local function Suivre(cadre)
    if suivis[cadre] then return end
    suivis[cadre] = true
    cadre:HookScript("OnHide", function(self)
        if self == cadreOuvert and not changement then
            colonne:Hide()
            ouvert, cadreOuvert = nil, nil
        end
    end)
end

local function Placer(cadre)
    -- La colonne à gauche de la fenêtre, à droite si la place manque (fiche du personnage, collée au bord).
    colonne:ClearAllPoints()
    local gauche = (cadre:GetLeft() or 0) * cadre:GetEffectiveScale()
    if gauche < (LARGEUR + 12) * colonne:GetEffectiveScale() then
        colonne:SetPoint("TOPLEFT", cadre, "TOPRIGHT", 6, 0)
    else
        colonne:SetPoint("TOPRIGHT", cadre, "TOPLEFT", -6, 0)
    end
    colonne:SetFrameStrata(cadre:GetFrameStrata())
    colonne:SetFrameLevel(cadre:GetFrameLevel() + 10)
end

function S.OuvrirCarnet(id, n)
    local c = S.CARNET[id]
    if not c then return end
    n = math.max(1, math.min(n or memoire[id] or 1, #c.onglets))
    local o = c.onglets[n]
    local cadre = o.cadre()
    if not cadre then
        UIErrorsFrame:AddMessage(c.nom .. " › " .. o.nom .. " : fenêtre absente.", 1, 0.3, 0.3)
        return
    end
    changement = true
    if cadreOuvert and cadreOuvert ~= cadre then
        if cadreOuvert == CharacterFrame then HideUIPanel(CharacterFrame) else cadreOuvert:Hide() end
    end
    memoire[id], ouvert, cadreOuvert = n, id, cadre
    Suivre(cadre)
    if o.place ~= false then
        cadre:ClearAllPoints()
        cadre:SetPoint("CENTER", S.racine, "CENTER", LARGEUR / 2, 10)
    end
    if o.page then o.page() end
    if o.ouvrir then o.ouvrir() else cadre:Show() end
    if o.page then o.page() end   -- après l'affichage : certaines fenêtres remettent leur page à l'ouverture
    local t0 = rawget(cadre, "titre")
    if t0 then t0:SetText(c.nom .. "  ·  " .. o.nom) end
    changement = false

    titre:SetText(c.nom)
    local t = S.ToucheCarnet(c)
    touche:SetText(t and ("Touche " .. t) or "")
    for i, b in ipairs(boutons) do
        local oi = c.onglets[i]
        S.Montrer(b, oi ~= nil)
        if oi then
            b.texte:SetText(oi.nom)
            b:Choisir(i == n)
            b:SetScript("OnClick", function() S.OuvrirCarnet(id, i) end)
        end
    end
    colonne:SetHeight(64 + #c.onglets * HAUT_ONGLET + 8)
    Placer(cadre)
    colonne:Show()
end

function S.BasculerCarnet(id, n)
    if ouvert == id and cadreOuvert and cadreOuvert:IsShown() and (not n or n == memoire[id]) then
        Fermer()
    else
        S.OuvrirCarnet(id, n)
    end
end

function S.CarnetOuvert() return ouvert end

-- Boutons invisibles des touches (« CLICK SolUICarnet<id>:LeftButton »).
for _, c in ipairs(S.CARNETS) do
    local b = CreateFrame("Button", "SolUICarnet" .. c.id, UIParent)
    b:SetSize(1, 1)
    b:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -10, 10)
    b:SetAlpha(0)
    b:EnableMouse(false)
    b:SetScript("OnClick", function() S.BasculerCarnet(c.id) end)
end

-- Les anciens points d'entrée mènent aux carnets.
S.BasculerEquipement = function() S.BasculerCarnet("artisanat") end
S.BasculerCollection = function() S.BasculerCarnet("collection") end
S.BasculerRaccourcis = function() S.BasculerCarnet("techniques") end
S.BasculerObjectifs = function() S.BasculerCarnet("aventure", 2) end
S.BasculerJournal = function() S.BasculerCarnet("aventure", 1) end
S.BasculerAventurier = function() S.BasculerCarnet("aventure", 3) end
S.BasculerPassifs = function(genre) S.OuvrirCarnet("aventure", genre == "exterieur" and 6 or 7) end
for nom, id in pairs({ SolUIOuvrirEquipement = "artisanat", SolUIOuvrirCollection = "collection",
    SolUIOuvrirRaccourcis = "techniques" }) do
    if _G[nom] then _G[nom]:SetScript("OnClick", function() S.BasculerCarnet(id) end) end
end

-- Première connexion : touches des carnets à la place de celles du jeu.
local fait = false
S.Ecouter("PLAYER_ENTERING_WORLD", function()
    if fait then return end
    fait = true
    local modifie = false
    for _, c in ipairs(S.CARNETS) do
        local commande = CommandeTouche(c)
        if not GetBindingKey(commande) and REMPLACABLES[GetBindingAction(c.touche) or ""] then
            SetBindingClick(c.touche, "SolUICarnet" .. c.id)
            modifie = true
        end
    end
    if modifie then SaveBindings(GetCurrentBindingSet()) end
end)

------------------------------------------------------------------------
-- Menu du jeu (barre et mini-carte) : ce qui n'est pas un carnet
------------------------------------------------------------------------
local function Slash(commande)
    for nom, fonction in pairs(SlashCmdList) do
        for i = 1, 5 do
            local alias = _G["SLASH_" .. nom .. i]
            if not alias then break end
            if alias == commande then return fonction("") end
        end
    end
end

-- Audit du jeu, lot 1 (02/11/2026) : plus d'entrée « Hauts faits », la fenêtre du jeu ne montre que ceux de la v2.
S.MENU_JEU = {
    { "Réglages Sol'Azeroth", function() Slash("/sol") end },
    { "Menu du jeu", function()
        if GameMenuFrame:IsShown() then HideUIPanel(GameMenuFrame) else ShowUIPanel(GameMenuFrame) end
    end },
}

-- Liste du menu de la mini-carte : les carnets, la carte, puis le menu du jeu.
function S.ListeMenu()
    local liste = {}
    for _, c in ipairs(S.CARNETS) do
        table.insert(liste, { text = c.nom, func = function() S.BasculerCarnet(c.id) end, notCheckable = true })
    end
    table.insert(liste, { text = "Carte", func = function() ToggleFrame(WorldMapFrame) end, notCheckable = true })
    for _, e in ipairs(S.MENU_JEU) do
        table.insert(liste, { text = e[1], func = e[2], notCheckable = true })
    end
    return liste
end

------------------------------------------------------------------------
-- Annonce cliquable
------------------------------------------------------------------------
local annonce = CreateFrame("Button", "SolUIAnnonce", S.racine)
annonce:SetHeight(44)
annonce:SetPoint("TOP", S.racine, "TOP", 0, -24)
annonce:SetFrameStrata("HIGH")
annonce:SetBackdrop({ bgFile = S.BLANC, edgeFile = S.BLANC, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
annonce:SetBackdropColor(S.Couleur("fond", 0.92))
annonce:SetBackdropBorderColor(S.Couleur("ambre"))
annonce:Hide()
annonce.texte = S.Texte(annonce, "SemiBold", 14, "ambreClair")
annonce.texte:SetPoint("LEFT", 20, 0)
annonce.lien = S.Texte(annonce, "Regular", 13, "gris")
annonce.lien:SetPoint("LEFT", annonce.texte, "RIGHT", 12, 0)
local finAnnonce = 0
annonce:SetScript("OnUpdate", function(self)
    if GetTime() >= finAnnonce then self:Hide() end
end)

function S.Annonce(texte, lien, action, duree)
    annonce.texte:SetText(texte)
    annonce.lien:SetText(lien or "")
    annonce:SetWidth(annonce.texte:GetStringWidth() + (lien and (annonce.lien:GetStringWidth() + 12) or 0) + 40)
    annonce:SetScript("OnClick", function(self)
        self:Hide()
        if action then action() end
    end)
    finAnnonce = GetTime() + (duree or 10)
    annonce:Show()
end

-- Zone de repos : le mode de zone et les passifs extérieurs se changent ici (au plus une fois toutes les 10 minutes).
local dernierRappel = -600
S.Ecouter("PLAYER_UPDATE_RESTING", function()
    if IsResting() and GetTime() - dernierRappel >= 600 then
        dernierRappel = GetTime()
        S.Annonce("Zone de repos : mode de zone et passifs extérieurs modifiables ici.", "Aventure › Passifs extérieurs",
            function() S.OuvrirCarnet("aventure", 6) end, 8)
    end
end)
