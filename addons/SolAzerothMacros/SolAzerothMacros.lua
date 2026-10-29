-- Macros (demande de l'utilisateur du 29/10/2026) : créer et modifier les macros du jeu, avec les icônes triées par
-- catégorie (d'après leur nom de fichier) et une recherche, et des modèles pour les commandes de Sol'Azeroth.
-- Les icônes sont celles de SpellIcon.dbc, enrichi par le patch client de toutes les icônes du jeu
-- (outils\icones_macros.py) : une icône de la liste des objets reste vide sur une macro. Création et modification
-- impossibles en combat.

local COLONNES, LIGNES = 12, 6
local PAR_PAGE = COLONNES * LIGNES
local MACROS_COMPTE = 36   -- MAX_ACCOUNT_MACROS : 1-36 compte, 37-54 personnage

-- Catégories : motifs cherchés dans le nom de fichier de l'icône (minuscules), dans l'ordre ; la première trouvée gagne.
local CATEGORIES = {
    { "Toutes" },
    { "Guerrier", "_warrior" }, { "Paladin", "_paladin" }, { "Chasseur", "_hunter" }, { "Voleur", "_rogue" },
    { "Prêtre", "_priest" }, { "Chevalier de la mort", "deathknight" }, { "Chaman", "_shaman" }, { "Mage", "_mage" },
    { "Démoniste", "_warlock" }, { "Druide", "_druid" },
    { "Montures", "_mount", "mount_" }, { "Familiers", "_pet_", "inv_pet", "inv_box_pet" },
    { "Hauts faits", "achievement_" },
    { "Feu", "spell_fire" }, { "Givre", "spell_frost", "spell_ice" }, { "Nature", "spell_nature" },
    { "Ombre", "spell_shadow" }, { "Sacré", "spell_holy" }, { "Arcanes", "spell_arcane" },
    { "Épées", "inv_sword" }, { "Haches", "inv_axe" }, { "Masses", "inv_mace", "inv_hammer" },
    { "Bâtons et lances", "inv_staff", "inv_spear", "inv_polearm" }, { "Dagues et poings", "inv_weapon_shortblade", "inv_knife", "inv_weapon_hand" },
    { "Armes à distance", "inv_weapon_bow", "inv_weapon_crossbow", "inv_weapon_rifle", "inv_wand", "inv_throwing", "inv_ammo" },
    { "Boucliers", "inv_shield" },
    { "Armures", "inv_helmet", "inv_chest", "inv_pants", "inv_boots", "inv_gauntlets", "inv_shoulder", "inv_belt",
      "inv_bracer", "inv_misc_cape", "inv_misc_desecrated" },
    { "Bijoux", "inv_jewelry", "inv_misc_gem", "inv_trinket" },
    { "Potions et nourriture", "inv_potion", "inv_drink", "inv_misc_food", "inv_misc_fish", "inv_alchemy" },
    { "Métiers", "trade_", "inv_ore", "inv_ingot", "inv_fabric", "inv_misc_herb", "inv_misc_leatherscrap",
      "inv_inscription", "inv_enchant", "inv_misc_pelt" },
    { "Compétences", "ability_" }, { "Sorts divers", "spell_" }, { "Objets divers", "inv_" },
    { "Autres" },
}

-- Modèles : macros prêtes pour les commandes de Sol'Azeroth (nom, icône, texte).
local MODELES = {
    { "Sol'Azeroth", "INV_Misc_Book_09", "/sol" },
    { "Rang", "Ability_Warrior_BattleShout", "/rang" },
    { "Exterieur", "Ability_Hunter_Pathfinding", "/exterieur" },
    { "Contrats", "INV_Misc_Note_01", "/contrats" },
    { "Ameliorer", "INV_Misc_Coin_17", "/ameliorer" },
    { "Butin", "INV_Misc_Bag_10", "/butin" },
    { "Apprendre", "INV_Misc_Book_11", "/apprendre" },
    { "Grimoire", "INV_Misc_Book_07", "/grimoire" },
    { "Arbre", "Ability_Marksmanship", "/arbre" },
    { "Spe", "Ability_DualWield", "/spe" },
    { "Defis", "Achievement_General", "/defis" },
    { "Codex", "INV_Misc_Book_06", "/codex" },
    { "Journal", "INV_Misc_Book_03", "/journal" },
    { "HautsFaits", "Achievement_Quests_Completed_08", "/hf" },
    { "Coffre", "INV_Box_02", ".coffre" },
    { "Reinit", "Spell_Holy_BorrowedTime", ".reinitialiser" },
    { "Sauver", "INV_Misc_PocketWatch_01", ".sauvegarder" },
}

local icones = {}        -- { indice, texture, nom (minuscules), categorie }
local filtrees = {}
local categorie, recherche, page = 1, "", 1
local selection = { macro = nil, icone = nil }   -- macro choisie (indice du jeu), icône choisie (indice du jeu)

local function Categorie(nom)
    for i = 2, #CATEGORIES - 1 do
        local c = CATEGORIES[i]
        for j = 2, #c do
            if nom:find(c[j], 1, true) then return i end
        end
    end
    return #CATEGORIES
end

local function ChargerIcones()
    if #icones > 0 then return end
    for i = 1, GetNumMacroIcons() do
        local texture = GetMacroIconInfo(i)
        if texture then
            local nom = texture:lower():match("([^\\/]+)$") or ""
            icones[#icones + 1] = { indice = i, texture = texture, nom = nom, categorie = Categorie(nom) }
        end
    end
end

local function IndiceIcone(texture)
    texture = (texture or ""):lower():match("([^\\/]+)$")
    for _, ic in ipairs(icones) do
        if ic.nom == texture then return ic.indice end
    end
    return nil
end

------------------------------------------------------------------------
-- Fenêtre
------------------------------------------------------------------------
local cadre = CreateFrame("Frame", "SolAzerothMacrosCadre", UIParent)
cadre:SetSize(760, 560)
cadre:SetPoint("CENTER", 0, 40)
cadre:SetFrameStrata("DIALOG")
cadre:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
    tile = true, tileSize = 32, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 },
})
cadre:EnableMouse(true)
cadre:SetMovable(true)
cadre:RegisterForDrag("LeftButton")
cadre:SetScript("OnDragStart", cadre.StartMoving)
cadre:SetScript("OnDragStop", cadre.StopMovingOrSizing)
cadre:Hide()
tinsert(UISpecialFrames, "SolAzerothMacrosCadre")

local entete = cadre:CreateTexture(nil, "ARTWORK")
entete:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
entete:SetSize(360, 64)
entete:SetPoint("TOP", 0, 12)
local titre = cadre:CreateFontString(nil, "OVERLAY", "GameFontNormal")
titre:SetPoint("TOP", entete, "TOP", 0, -14)
titre:SetText("Macros")
local fermer = CreateFrame("Button", nil, cadre, "UIPanelCloseButton")
fermer:SetPoint("TOPRIGHT", -6, -6)

local function Texte(modele, texte, x, y)
    local t = cadre:CreateFontString(nil, "OVERLAY", modele)
    t:SetPoint("TOPLEFT", x, y)
    t:SetText(texte)
    return t
end

local function Bouton(texte, largeur, x, y, action)
    local b = CreateFrame("Button", nil, cadre, "UIPanelButtonTemplate")
    b:SetSize(largeur, 22)
    b:SetPoint("TOPLEFT", x, y)
    b:SetText(texte)
    b:SetScript("OnClick", action)
    return b
end

local function Champ(largeur, hauteur, x, y, multiligne)
    local fond = CreateFrame("Frame", nil, cadre)
    fond:SetPoint("TOPLEFT", x, y)
    fond:SetSize(largeur, hauteur)
    fond:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                       tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    fond:SetBackdropColor(0, 0, 0, 0.8)
    local e = CreateFrame("EditBox", nil, fond)
    e:SetPoint("TOPLEFT", 8, -6)
    e:SetPoint("BOTTOMRIGHT", -8, 6)
    e:SetFontObject(ChatFontNormal)
    e:SetAutoFocus(false)
    e:SetMultiLine(multiligne or false)
    e:SetScript("OnEscapePressed", e.ClearFocus)
    fond:EnableMouse(true)
    fond:SetScript("OnMouseDown", function() e:SetFocus() end)
    return e
end

-- Liste des macros existantes (colonne de gauche)
Texte("GameFontNormal", "Tes macros", 24, -36)
Texte("GameFontDisableSmall", "à glisser sur tes barres", 104, -38)
local listeMacros = {}
local pageMacros = 1
local LIGNES_MACROS = 14
for i = 1, LIGNES_MACROS do
    local b = CreateFrame("Button", nil, cadre)
    b:SetSize(190, 24)
    b:SetPoint("TOPLEFT", 22, -56 - (i - 1) * 26)
    b.icone = b:CreateTexture(nil, "ARTWORK")
    b.icone:SetSize(22, 22)
    b.icone:SetPoint("LEFT")
    b.nom = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.nom:SetPoint("LEFT", b.icone, "RIGHT", 6, 0)
    b.nom:SetWidth(160)
    b.nom:SetJustifyH("LEFT")
    b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    b.choisi = b:CreateTexture(nil, "BACKGROUND")
    b.choisi:SetAllPoints()
    b.choisi:SetTexture(1, 0.82, 0, 0.25)
    -- Glisser la macro vers une barre d'action (hors combat).
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnDragStart", function(self)
        if self.indice and not InCombatLockdown() then PickupMacro(self.indice) end
    end)
    listeMacros[i] = b
end
local macrosPrec = Bouton("<", 30, 22, -424, function() pageMacros = pageMacros - 1 SolAzerothMacrosAfficher() end)
local macrosSuiv = Bouton(">", 30, 182, -424, function() pageMacros = pageMacros + 1 SolAzerothMacrosAfficher() end)
local macrosPage = Texte("GameFontNormalSmall", "", 70, -429)
local compteur = Texte("GameFontDisableSmall", "", 22, -452)

-- Éditeur (colonne de droite, en haut)
Texte("GameFontNormal", "Nom", 236, -36)
local champNom = Champ(200, 28, 232, -52)
champNom:SetMaxLetters(16)
local apercu = cadre:CreateTexture(nil, "ARTWORK")
apercu:SetSize(40, 40)
apercu:SetPoint("TOPLEFT", 446, -46)
apercu:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
local parPerso = CreateFrame("CheckButton", nil, cadre, "UICheckButtonTemplate")
parPerso:SetPoint("TOPLEFT", 494, -50)
local parPersoTexte = Texte("GameFontHighlightSmall", "Propre à ce personnage", 524, -58)
Texte("GameFontNormal", "Texte de la macro (255 caractères au plus)", 236, -88)
local champTexte = Champ(500, 80, 232, -104, true)
champTexte:SetMaxLetters(255)

local message = Texte("GameFontHighlightSmall", "", 236, -214)
message:SetWidth(500)
message:SetJustifyH("LEFT")

local function Dire(texte, rouge)
    message:SetText(texte)
    if rouge then message:SetTextColor(1, 0.4, 0.4) else message:SetTextColor(0.6, 1, 0.6) end
end

-- Grille d'icônes (colonne de droite, en bas)
Texte("GameFontNormal", "Icône", 236, -236)
local champRecherche = Champ(150, 24, 300, -230)
Texte("GameFontDisableSmall", "recherche (nom anglais : sword, fire…)", 456, -238)

-- Catégories : un panneau de boutons sur trois colonnes, posé sur la grille (un menu déroulant sortait de l'écran).
local boutonCategorie = Bouton("Catégorie : Toutes", 220, 232, -260, function() end)
local panneau = CreateFrame("Frame", nil, cadre)
panneau:SetPoint("TOPLEFT", 232, -286)
panneau:SetSize(510, 276)
panneau:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                      tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
panneau:SetBackdropColor(0.05, 0.05, 0.05, 0.97)
panneau:EnableMouse(true)
panneau:Hide()

local grille = {}
for i = 1, PAR_PAGE do
    local b = CreateFrame("CheckButton", nil, cadre)
    b:SetSize(36, 36)
    local ligne, colonne = math.floor((i - 1) / COLONNES), (i - 1) % COLONNES
    b:SetPoint("TOPLEFT", 236 + colonne * 41, -290 - ligne * 38)
    b.icone = b:CreateTexture(nil, "ARTWORK")
    b.icone:SetAllPoints()
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b:SetCheckedTexture("Interface\\Buttons\\CheckButtonHilight", "ADD")
    b:SetScript("OnClick", function(self)
        selection.icone = self.ic.indice
        apercu:SetTexture(self.ic.texture)
        SolAzerothMacrosAfficher()
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.ic.nom)
        GameTooltip:AddLine(CATEGORIES[self.ic.categorie][1], 1, 1, 1)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    grille[i] = b
end
local iconesPage = Texte("GameFontNormalSmall", "", 236, -522)
local iconesPrec = Bouton("Précédent", 90, 560, -516, function() page = page - 1 SolAzerothMacrosAfficher() end)
local iconesSuiv = Bouton("Suivant", 90, 652, -516, function() page = page + 1 SolAzerothMacrosAfficher() end)

local function Filtrer()
    filtrees = {}
    for _, ic in ipairs(icones) do
        if (categorie == 1 or ic.categorie == categorie) and (recherche == "" or ic.nom:find(recherche, 1, true)) then
            filtrees[#filtrees + 1] = ic
        end
    end
    page = 1
end

-- Affichage par ordre alphabétique (accents ignorés), « Toutes » en tête, colonne par colonne. L'ordre de la table
-- CATEGORIES reste celui de la recherche des motifs.
local function CleTri(texte)
    local cle = texte:lower()
    for accent, lettre in pairs({ ["à"] = "a", ["â"] = "a", ["é"] = "e", ["è"] = "e", ["ê"] = "e", ["î"] = "i",
                                  ["ô"] = "o", ["û"] = "u", ["ç"] = "c", ["É"] = "e" }) do
        cle = cle:gsub(accent, lettre)
    end
    return cle
end
local ordre = {}
for i = 2, #CATEGORIES do ordre[#ordre + 1] = i end
table.sort(ordre, function(a, b) return CleTri(CATEGORIES[a][1]) < CleTri(CATEGORIES[b][1]) end)
table.insert(ordre, 1, 1)

local LIGNES_CATEGORIES = math.ceil(#CATEGORIES / 3)
for place, i in ipairs(ordre) do
    local c = CATEGORIES[i]
    local b = CreateFrame("Button", nil, panneau)
    b:SetSize(162, 20)
    b:SetPoint("TOPLEFT", 10 + math.floor((place - 1) / LIGNES_CATEGORIES) * 166, -10 - ((place - 1) % LIGNES_CATEGORIES) * 21)
    b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    local t = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    t:SetPoint("LEFT", 6, 0)
    t:SetText(c[1])
    b:SetScript("OnClick", function()
        categorie = i
        boutonCategorie:SetText("Catégorie : " .. c[1])
        panneau:Hide()
        Filtrer()
        SolAzerothMacrosAfficher()
    end)
end
boutonCategorie:SetScript("OnClick", function()
    if panneau:IsShown() then panneau:Hide() else panneau:Show() end
end)
panneau:SetFrameLevel(cadre:GetFrameLevel() + 10)

champRecherche:SetScript("OnTextChanged", function(self)
    recherche = strtrim(self:GetText() or ""):lower()
    Filtrer()
    SolAzerothMacrosAfficher()
end)

------------------------------------------------------------------------
-- Affichage et actions
------------------------------------------------------------------------
local function MacrosExistantes()
    local liste = {}
    local compte, perso = GetNumMacros()
    for i = 1, compte do liste[#liste + 1] = i end
    for i = 1, perso do liste[#liste + 1] = MACROS_COMPTE + i end
    return liste, compte, perso
end

local function Choisir(indice)
    local nom, texture, corps = GetMacroInfo(indice)
    if not nom then return end
    selection.macro = indice
    selection.icone = nil   -- icône inchangée tant qu'on n'en clique pas une autre
    champNom:SetText(nom)
    champTexte:SetText(corps or "")
    apercu:SetTexture(texture)
    parPerso:SetChecked(indice > MACROS_COMPTE)
    Dire("")
    SolAzerothMacrosAfficher()
end

function SolAzerothMacrosAfficher()
    local liste, compte, perso = MacrosExistantes()
    local pages = math.max(1, math.ceil(#liste / LIGNES_MACROS))
    pageMacros = math.max(1, math.min(pageMacros, pages))
    for i, b in ipairs(listeMacros) do
        local indice = liste[(pageMacros - 1) * LIGNES_MACROS + i]
        local nom, texture
        if indice then nom, texture = GetMacroInfo(indice) end
        if nom then
            b.icone:SetTexture(texture)
            b.nom:SetText(nom .. (indice > MACROS_COMPTE and " |cff8080ff(perso)|r" or ""))
            b.indice = indice
            b:SetScript("OnClick", function() Choisir(indice) end)
            if indice == selection.macro then b.choisi:Show() else b.choisi:Hide() end
            b:Show()
        else
            b:Hide()
        end
    end
    macrosPage:SetText(pages > 1 and string.format("%d / %d", pageMacros, pages) or "")
    if pageMacros > 1 then macrosPrec:Show() else macrosPrec:Hide() end
    if pageMacros < pages then macrosSuiv:Show() else macrosSuiv:Hide() end
    compteur:SetText(string.format("Compte : %d / %d   Personnage : %d / 18", compte, MACROS_COMPTE, perso))

    local pagesIcones = math.max(1, math.ceil(#filtrees / PAR_PAGE))
    page = math.max(1, math.min(page, pagesIcones))
    for i, b in ipairs(grille) do
        local ic = filtrees[(page - 1) * PAR_PAGE + i]
        if ic then
            b.ic = ic
            b.icone:SetTexture(ic.texture)
            b:SetChecked(ic.indice == selection.icone)
            b:Show()
        else
            b:Hide()
        end
    end
    iconesPage:SetText(string.format("%d icônes - page %d / %d", #filtrees, page, pagesIcones))
    if page > 1 then iconesPrec:Show() else iconesPrec:Hide() end
    if page < pagesIcones then iconesSuiv:Show() else iconesSuiv:Hide() end
end

local function Nouvelle()
    selection.macro, selection.icone = nil, nil
    champNom:SetText("")
    champTexte:SetText("")
    apercu:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    parPerso:SetChecked(false)
    Dire("Nouvelle macro : donne-lui un nom, un texte et une icône, puis Enregistrer.")
    SolAzerothMacrosAfficher()
end

local function Enregistrer()
    if InCombatLockdown() then return Dire("Impossible en combat.", true) end
    local nom = strtrim(champNom:GetText() or "")
    if nom == "" then return Dire("Il faut un nom.", true) end
    local corps = champTexte:GetText() or ""
    if selection.macro then
        -- Sans nouvelle icône choisie, on renvoie l'actuelle : une icône vide effaçait celle de la macro.
        local icone = selection.icone or IndiceIcone(select(2, GetMacroInfo(selection.macro)))
        local index
        if icone then
            index = EditMacro(selection.macro, nom, icone, corps)
        else
            index = EditMacro(selection.macro, nil, nil, corps)
        end
        selection.macro = index or selection.macro
        Dire("Macro enregistrée.")
    else
        if not selection.icone then return Dire("Choisis une icône dans la grille.", true) end
        local compte, perso = GetNumMacros()
        if (parPerso:GetChecked() and perso >= 18) or (not parPerso:GetChecked() and compte >= MACROS_COMPTE) then
            return Dire("Plus de place pour ce type de macro : supprimes-en une ou change la case « Propre à ce personnage ».", true)
        end
        selection.macro = CreateMacro(nom, selection.icone, corps, parPerso:GetChecked() and 1 or nil)
        Dire("Macro créée. « Sur la barre » pour la poser.")
    end
    selection.icone = nil
    SolAzerothMacrosAfficher()
end

local function Supprimer()
    if InCombatLockdown() then return Dire("Impossible en combat.", true) end
    if not selection.macro then return Dire("Choisis d'abord une macro à gauche.", true) end
    DeleteMacro(selection.macro)
    Nouvelle()
    Dire("Macro supprimée.")
end

local function SurLaBarre()
    if InCombatLockdown() then return Dire("Impossible en combat.", true) end
    if not selection.macro then return Dire("Enregistre d'abord la macro.", true) end
    PickupMacro(selection.macro)
    Dire("Clique sur une case de ta barre d'action pour y poser la macro.")
end

Bouton("Nouvelle", 110, 232, -190, Nouvelle)
Bouton("Enregistrer", 110, 346, -190, Enregistrer)
Bouton("Supprimer", 110, 460, -190, Supprimer)
Bouton("Sur la barre", 110, 574, -190, SurLaBarre)

-- Modèles Sol'Azeroth : remplissent le formulaire d'une nouvelle macro.
local menuModeles = CreateFrame("Frame", "SolAzerothMacrosModeles", cadre, "UIDropDownMenuTemplate")
menuModeles:SetPoint("TOPLEFT", 4, -474)
UIDropDownMenu_SetWidth(menuModeles, 170)
UIDropDownMenu_Initialize(menuModeles, function()
    for _, m in ipairs(MODELES) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = m[1] .. "  |cff808080" .. m[3] .. "|r"
        info.notCheckable = true
        info.func = function()
            Nouvelle()
            champNom:SetText(m[1])
            champTexte:SetText(m[3])
            selection.icone = IndiceIcone(m[2])
            apercu:SetTexture("Interface\\Icons\\" .. m[2])
            Dire("Modèle chargé : Enregistrer pour créer la macro.")
            SolAzerothMacrosAfficher()
        end
        UIDropDownMenu_AddButton(info)
    end
end)
UIDropDownMenu_SetText(menuModeles, "Modèles Sol'Azeroth")

cadre:SetScript("OnShow", function()
    ChargerIcones()
    if #filtrees == 0 then Filtrer() end
    SolAzerothMacrosAfficher()
end)

local evenements = CreateFrame("Frame")
evenements:RegisterEvent("UPDATE_MACROS")
evenements:SetScript("OnEvent", function()
    if cadre:IsShown() then SolAzerothMacrosAfficher() end
end)

SLASH_SOLAZEROTHMACROS1 = "/macros"
SlashCmdList["SOLAZEROTHMACROS"] = function()
    if cadre:IsShown() then cadre:Hide() else cadre:Show() end
end
