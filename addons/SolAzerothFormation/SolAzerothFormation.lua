-- Apprentissage à distance. Le serveur (mod-solazeroth, formation.cpp) envoie le catalogue :
-- "DEBUT", puis des paquets "S|id:niveau:prix:état;..." (M et R ajoutent :métier:rang), puis "FIN".
-- États : 0 disponible, 1 pas encore disponible, 2 déjà appris. Achat : ".solform acheter <catégorie> <id>".
-- Intendant (I) : "I|objet:niveau:marques:cuivre:emplacement:classe:sous-classe;..." ; l'objet est donné au
-- rang de menace 3. Filtres par emplacement et par matière, tri par niveau, prix ou nom.
-- Éclats de raid (E) : "E|objet:boss:éclats:prix:nom_boss;..." ; l'objet s'échange contre les Éclats de ce boss.
-- Autres classes (X, section 3.9) : ".solform classe <id>" renvoie "XDEBUT|classe", des paquets "X|…" comme S, "XFIN".
-- Un élément X a un 5e champ : sort de posture, de forme ou de camouflage exigé (0 si aucun), affiché dans la condition.

-- Nom d'un objet, demandé au serveur par l'addon SolAzeroth s'il manque (chargé après cet addon).
local function NomSol(id)
    if SolAzerothNomObjet then return SolAzerothNomObjet(id) end
    return GetItemInfo(id)
end

local PREFIXE = "SOLFORM"
local LIGNES, HAUTEUR = 10, 36

local METIERS = {
    [171] = "Alchimie", [164] = "Forge", [333] = "Enchantement", [202] = "Ingénierie", [182] = "Herboristerie",
    [773] = "Calligraphie", [755] = "Joaillerie", [165] = "Travail du cuir", [186] = "Minage", [393] = "Dépeçage",
    [197] = "Couture", [185] = "Cuisine", [129] = "Secourisme", [356] = "Pêche",
}
local ORDRE_METIERS = { 171, 164, 333, 202, 182, 773, 755, 165, 186, 393, 197, 185, 129, 356 }

-- Intendant : emplacements (InventoryType du serveur), matières d'armure (sous-classe), tris.
local EMPLACEMENTS = {
    { nom = "Tous" },
    { nom = "Tête", inv = { 1 } }, { nom = "Cou", inv = { 2 } }, { nom = "Épaules", inv = { 3 } },
    { nom = "Dos", inv = { 16 } }, { nom = "Torse", inv = { 5, 20 } }, { nom = "Poignets", inv = { 9 } },
    { nom = "Mains", inv = { 10 } }, { nom = "Taille", inv = { 6 } }, { nom = "Jambes", inv = { 7 } },
    { nom = "Pieds", inv = { 8 } }, { nom = "Doigt", inv = { 11 } }, { nom = "Bijou", inv = { 12 } },
    { nom = "Arme à une main", inv = { 13, 21, 22 } }, { nom = "Arme à deux mains", inv = { 17 } },
    { nom = "Main gauche", inv = { 14, 23 } }, { nom = "Distance", inv = { 15, 25, 26, 28 } },
}
local MATIERES = { { nom = "toutes" }, { nom = "tissu", sc = 1 }, { nom = "cuir", sc = 2 }, { nom = "mailles", sc = 3 }, { nom = "plaques", sc = 4 } }
local TRIS = {
    { nom = "niveau (haut)", f = function(a, b) if a.niveau ~= b.niveau then return a.niveau > b.niveau end return a.id < b.id end },
    { nom = "niveau (bas)", f = function(a, b) if a.niveau ~= b.niveau then return a.niveau < b.niveau end return a.id < b.id end },
    { nom = "prix", f = function(a, b) if a.prix ~= b.prix then return a.prix < b.prix end return a.id < b.id end },
    { nom = "nom", f = function(a, b) return (NomSol(a.id) or "") < (NomSol(b.id) or "") end },
}
local emplacementChoisi, matiere, tri = 1, 1, 1

local ONGLETS = {
    { cle = "S", nom = "Sorts" },
    { cle = "M", nom = "Métiers" },
    { cle = "R", nom = "Recettes" },
    { cle = "C", nom = "Compétences" },
    { cle = "O", nom = "Outils" },
    { cle = "B", nom = "Marques" },
    { cle = "I", nom = "Intendant" },
    { cle = "E", nom = "Éclats" },
    { cle = "X", nom = "Classes" },
}

-- Onglet Classes : les autres classes (identifiants du jeu).
local CLASSES = {
    { id = 1, jeton = "WARRIOR", nom = "Guerrier" }, { id = 2, jeton = "PALADIN", nom = "Paladin" },
    { id = 3, jeton = "HUNTER", nom = "Chasseur" }, { id = 4, jeton = "ROGUE", nom = "Voleur" },
    { id = 5, jeton = "PRIEST", nom = "Prêtre" }, { id = 6, jeton = "DEATHKNIGHT", nom = "Chevalier de la mort" },
    { id = 7, jeton = "SHAMAN", nom = "Chaman" }, { id = 8, jeton = "MAGE", nom = "Mage" },
    { id = 9, jeton = "WARLOCK", nom = "Démoniste" }, { id = 11, jeton = "DRUID", nom = "Druide" },
}
local classeChoisie = nil

local catalogue = { S = {}, M = {}, R = {}, C = {}, O = {}, B = {}, I = {}, E = {}, X = {} }
local enCours = { S = {}, M = {}, R = {}, C = {}, O = {}, B = {}, I = {}, E = {}, X = {} }
local enCoursX = {}
local marques = 0
local onglet, metierChoisi, affiches = "S", nil, {}

local function Commande(texte) SendChatMessage(texte, "SAY") end

------------------------------------------------------------------------
-- Noms et icônes (données du client)
------------------------------------------------------------------------
local function EstObjet(element)
    return element.categorie == "O" or element.categorie == "B" or element.categorie == "I" or element.categorie == "E"
end

local function Infos(element)
    if EstObjet(element) then
        local nom = NomSol(element.id)
        return nom or "Chargement...", "", GetItemIcon(element.id) or "Interface\\Icons\\INV_Misc_QuestionMark"
    end
    local nom, rang, icone = GetSpellInfo(element.id)
    return nom or ("Sort " .. element.id), rang or "", icone or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function Prix(element)
    if element.prix == 0 then return "Gratuit" end
    if element.categorie == "B" then return element.prix .. " Marques" end
    if element.categorie == "I" then return element.prix .. " Marques\n" .. GetCoinTextureString(element.cuivre) end
    if element.categorie == "E" then return element.prix .. " Éclats\n(" .. element.eclats .. " en réserve)" end
    return GetCoinTextureString(element.prix)
end

local function TexteRessources()
    return "Ton or : " .. GetCoinTextureString(GetMoney()) .. "   Marques : " .. marques
end

------------------------------------------------------------------------
-- Fenêtre
------------------------------------------------------------------------
local cadre = CreateFrame("Frame", "SolAzerothFormationCadre", UIParent)
cadre:SetSize(660, 500)
cadre:SetPoint("CENTER")
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
tinsert(UISpecialFrames, "SolAzerothFormationCadre")

local entete = cadre:CreateTexture(nil, "ARTWORK")
entete:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
entete:SetSize(300, 64)
entete:SetPoint("TOP", 0, 12)
local titre = cadre:CreateFontString(nil, "OVERLAY", "GameFontNormal")
titre:SetPoint("TOP", entete, "TOP", 0, -14)
titre:SetText("Apprentissage")

local fermer = CreateFrame("Button", nil, cadre, "UIPanelCloseButton")
fermer:SetPoint("TOPRIGHT", -6, -6)

-- Recherche et filtre
local recherche = CreateFrame("EditBox", "SolAzerothFormationRecherche", cadre, "InputBoxTemplate")
recherche:SetSize(180, 20)
recherche:SetPoint("TOPLEFT", 30, -40)
recherche:SetAutoFocus(false)
local rechercheTexte = cadre:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
rechercheTexte:SetPoint("BOTTOMLEFT", recherche, "TOPLEFT", -4, 2)
rechercheTexte:SetText("Rechercher")

local caseConnus = CreateFrame("CheckButton", "SolAzerothFormationConnus", cadre, "UICheckButtonTemplate")
caseConnus:SetPoint("LEFT", recherche, "RIGHT", 20, 0)
_G["SolAzerothFormationConnusText"]:SetText("Déjà appris")

local orTexte = cadre:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
orTexte:SetPoint("TOPRIGHT", -40, -46)

-- Liste des métiers (onglet Recettes)
local boutonsMetier = {}
for i, competence in ipairs(ORDRE_METIERS) do
    local b = CreateFrame("Button", nil, cadre, "UIPanelButtonTemplate")
    b:SetSize(120, 21)
    b:SetPoint("TOPLEFT", 24, -72 - (i - 1) * 24)
    b:SetText(METIERS[competence])
    b.competence = competence
    boutonsMetier[i] = b
end

-- Liste des autres classes (onglet Classes), sans la classe du personnage
local boutonsClasse = {}
do
    local _, maClasse = UnitClass("player")
    local rang = 0
    for _, c in ipairs(CLASSES) do
        if c.jeton ~= maClasse then
            rang = rang + 1
            local b = CreateFrame("Button", nil, cadre, "UIPanelButtonTemplate")
            b:SetSize(120, 22)
            b:SetPoint("TOPLEFT", 24, -72 - (rang - 1) * 25)
            b:SetText(c.nom)
            b.classe = c.id
            boutonsClasse[#boutonsClasse + 1] = b
        end
    end
end

-- Liste des emplacements (onglet Intendant)
local boutonsEmplacement = {}
for i, e in ipairs(EMPLACEMENTS) do
    local b = CreateFrame("Button", nil, cadre, "UIPanelButtonTemplate")
    b:SetSize(120, 20)
    b:SetPoint("TOPLEFT", 24, -72 - (i - 1) * 22)
    b:SetText(e.nom)
    b.index = i
    boutonsEmplacement[i] = b
end

-- Matière et tri (onglet Intendant), à la place de la case « déjà appris »
local boutonMatiere = CreateFrame("Button", nil, cadre, "UIPanelButtonTemplate")
boutonMatiere:SetSize(130, 22)
boutonMatiere:SetPoint("LEFT", recherche, "RIGHT", 16, 0)
local boutonTri = CreateFrame("Button", nil, cadre, "UIPanelButtonTemplate")
boutonTri:SetSize(150, 22)
boutonTri:SetPoint("LEFT", boutonMatiere, "RIGHT", 6, 0)

-- Liste défilante
local liste =CreateFrame("ScrollFrame", "SolAzerothFormationListe", cadre, "FauxScrollFrameTemplate")
local lignes = {}

local function Rafraichir()
    local offset = FauxScrollFrame_GetOffset(liste)
    for i = 1, LIGNES do
        local ligne = lignes[i]
        local element = affiches[i + offset]
        if element then
            local nom, rang, icone = Infos(element)
            ligne.element = element
            ligne.icone:SetTexture(icone)
            ligne.nom:SetText(nom .. (rang ~= "" and ("  |cff808080" .. rang .. "|r") or ""))
            local condition = ""
            if element.niveau > 1 then condition = "Niveau " .. element.niveau end
            if element.forme and element.forme > 0 then
                local forme = GetSpellInfo(element.forme)
                if forme then condition = condition .. (condition ~= "" and " - " or "") .. "Requiert : " .. forme end
            end
            if element.categorie == "I" then
                local _, _, _, _, _, _, sousType, _, emplacement = GetItemInfo(element.id)
                local place = emplacement and _G[emplacement] or ""
                condition = condition .. (place ~= "" and (" - " .. place) or "") .. (sousType and (" (" .. sousType .. ")") or "") .. " - rang 3"
            elseif element.categorie == "E" then
                condition = "Éclats de " .. element.nomBoss
            end
            if element.metier and element.metier > 0 and element.rangMetier and element.rangMetier > 0 then
                condition = condition .. (condition ~= "" and " - " or "") .. (METIERS[element.metier] or "Métier") .. " " .. element.rangMetier
            end
            ligne.condition:SetText(condition)
            ligne.prix:SetText(Prix(element))
            if element.etat == 2 then
                ligne.nom:SetTextColor(0.4, 1, 0.4)
                ligne.bouton:Hide()
                ligne.statut:SetText("|cff66ff66Appris|r")
            elseif element.etat == 1 then
                ligne.nom:SetTextColor(0.6, 0.6, 0.6)
                ligne.bouton:Hide()
                ligne.statut:SetText("|cff999999Pas encore|r")
            else
                ligne.nom:SetTextColor(1, 0.82, 0)
                ligne.bouton:SetText(EstObjet(element) and "Acheter" or "Apprendre")
                ligne.bouton:Show()
                ligne.statut:SetText("")
            end
            ligne:Show()
        else
            ligne:Hide()
        end
    end
    FauxScrollFrame_Update(liste, #affiches, LIGNES, HAUTEUR)
end

local function Filtrer()
    affiches = {}
    local texte = strlower(recherche:GetText() or "")
    local montrerConnus = caseConnus:GetChecked()
    local filtreInv, filtreMatiere = EMPLACEMENTS[emplacementChoisi].inv, MATIERES[matiere].sc
    for _, element in ipairs(catalogue[onglet]) do
        local garder = montrerConnus or element.etat ~= 2
        if garder and onglet == "R" and metierChoisi and element.metier ~= metierChoisi then garder = false end
        if garder and onglet == "I" then
            if filtreInv then
                local trouve = false
                for _, inv in ipairs(filtreInv) do if inv == element.inv then trouve = true end end
                if not trouve then garder = false end
            end
            -- La matière n'écarte que les armures d'une autre matière (bijoux, capes et armes restent).
            if filtreMatiere and element.classe == 4 and element.sousClasse >= 1 and element.sousClasse <= 4
               and element.sousClasse ~= filtreMatiere then garder = false end
        end
        if garder and texte ~= "" then
            local nom = Infos(element)
            garder = strfind(strlower(nom), texte, 1, true) ~= nil
        end
        if garder then table.insert(affiches, element) end
    end
    if onglet == "I" then
        table.sort(affiches, TRIS[tri].f)
        orTexte:SetText(TexteRessources())
        Rafraichir()
        return
    end
    table.sort(affiches, function(a, b)
        if a.etat ~= b.etat then return a.etat < b.etat end
        if (a.rangMetier or 0) ~= (b.rangMetier or 0) then return (a.rangMetier or 0) < (b.rangMetier or 0) end
        if a.niveau ~= b.niveau then return a.niveau < b.niveau end
        return a.id < b.id
    end)
    orTexte:SetText(TexteRessources())
    Rafraichir()
end

liste:SetScript("OnVerticalScroll", function(self, valeur)
    FauxScrollFrame_OnVerticalScroll(self, valeur, HAUTEUR, Rafraichir)
end)

for i = 1, LIGNES do
    local ligne = CreateFrame("Frame", nil, cadre)
    ligne:SetSize(440, HAUTEUR - 2)
    ligne.icone = ligne:CreateTexture(nil, "ARTWORK")
    ligne.icone:SetSize(30, 30)
    ligne.icone:SetPoint("LEFT", 2, 0)
    ligne.nom = ligne:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ligne.nom:SetPoint("TOPLEFT", ligne.icone, "TOPRIGHT", 8, -1)
    ligne.nom:SetWidth(230)
    ligne.nom:SetJustifyH("LEFT")
    ligne.condition = ligne:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ligne.condition:SetPoint("TOPLEFT", ligne.nom, "BOTTOMLEFT", 0, -2)
    ligne.prix = ligne:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ligne.prix:SetPoint("RIGHT", -100, 0)
    ligne.statut = ligne:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ligne.statut:SetPoint("RIGHT", -12, 0)
    ligne.bouton = CreateFrame("Button", nil, ligne, "UIPanelButtonTemplate")
    ligne.bouton:SetSize(88, 22)
    ligne.bouton:SetPoint("RIGHT", -4, 0)
    ligne.bouton:SetScript("OnClick", function()
        local e = ligne.element
        Commande(".solform acheter " .. e.categorie .. " " .. e.id)
    end)
    ligne:EnableMouse(true)
    ligne:SetScript("OnEnter", function(self)
        if not self.element then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if EstObjet(self.element) then
            GameTooltip:SetHyperlink("item:" .. self.element.id .. ":0:0:0:0:0:0:0")
        else
            GameTooltip:SetHyperlink("spell:" .. self.element.id)
        end
        GameTooltip:Show()
    end)
    ligne:SetScript("OnLeave", function() GameTooltip:Hide() end)
    lignes[i] = ligne
end

local function PlacerListe()
    local gauche = (onglet == "R" or onglet == "I" or onglet == "X") and 160 or 30
    for _, b in ipairs(boutonsClasse) do
        if onglet == "X" then b:Show() else b:Hide() end
        if b.classe == classeChoisie then b:LockHighlight() else b:UnlockHighlight() end
    end
    for _, b in ipairs(boutonsEmplacement) do
        if onglet == "I" then b:Show() else b:Hide() end
        if b.index == emplacementChoisi then b:LockHighlight() else b:UnlockHighlight() end
    end
    boutonMatiere:SetText("Matière : " .. MATIERES[matiere].nom)
    boutonTri:SetText("Tri : " .. TRIS[tri].nom)
    if onglet == "I" then
        boutonMatiere:Show() boutonTri:Show() caseConnus:Hide()
    else
        boutonMatiere:Hide() boutonTri:Hide() caseConnus:Show()
    end
    for i, ligne in ipairs(lignes) do
        ligne:ClearAllPoints()
        ligne:SetPoint("TOPLEFT", gauche, -72 - (i - 1) * HAUTEUR)
    end
    liste:ClearAllPoints()
    liste:SetPoint("TOPLEFT", lignes[1], "TOPLEFT", 0, 0)
    liste:SetPoint("BOTTOMRIGHT", lignes[LIGNES], "BOTTOMRIGHT", 0, 0)
    for _, b in ipairs(boutonsMetier) do
        if onglet == "R" then b:Show() else b:Hide() end
        if b.competence == metierChoisi then b:LockHighlight() else b:UnlockHighlight() end
    end
end

-- Onglets
local boutonsOnglet = {}
for i, o in ipairs(ONGLETS) do
    local b = CreateFrame("Button", nil, cadre, "UIPanelButtonTemplate")
    b:SetText(o.nom)
    -- Largeur selon le texte : « Compétences » ne tient pas dans un bouton de 68.
    b:SetSize(math.max(60, b:GetFontString():GetStringWidth() + 20), 24)
    if i == 1 then
        b:SetPoint("BOTTOMLEFT", 24, 18)
    else
        b:SetPoint("LEFT", boutonsOnglet[i - 1], "RIGHT", 2, 0)
    end
    b:SetScript("OnClick", function()
        onglet = o.cle
        for _, autre in ipairs(boutonsOnglet) do autre:UnlockHighlight() end
        b:LockHighlight()
        FauxScrollFrame_SetOffset(liste, 0)
        liste:SetVerticalScroll(0)
        PlacerListe()
        Filtrer()
    end)
    boutonsOnglet[i] = b
end
boutonsOnglet[1]:LockHighlight()

for _, b in ipairs(boutonsMetier) do
    b:SetScript("OnClick", function(self)
        metierChoisi = (metierChoisi ~= self.competence) and self.competence or nil
        FauxScrollFrame_SetOffset(liste, 0)
        liste:SetVerticalScroll(0)
        PlacerListe()
        Filtrer()
    end)
end

-- Objets de l'intendant pas encore connus du client : une infobulle cachée les demande au serveur,
-- puis la liste est redessinée chaque seconde tant qu'il en manque.
local cache = CreateFrame("GameTooltip", "SolAzerothFormationCache", UIParent, "GameTooltipTemplate")
local attente, manquait = 0, false
cadre:SetScript("OnUpdate", function(self, ecoule)
    attente = attente + ecoule
    if attente < 1 or (onglet ~= "I" and onglet ~= "E") then return end
    attente = 0
    local manque = false
    for _, element in ipairs(catalogue[onglet]) do
        if not NomSol(element.id) then
            manque = true
            cache:SetOwner(UIParent, "ANCHOR_NONE")
            cache:SetHyperlink("item:" .. element.id .. ":0:0:0:0:0:0:0")
        end
    end
    -- Un dernier dessin quand les derniers noms viennent d'arriver.
    if manque or manquait then Filtrer() end
    manquait = manque
end)

local function Relancer()
    FauxScrollFrame_SetOffset(liste, 0)
    liste:SetVerticalScroll(0)
    PlacerListe()
    Filtrer()
end
for _, b in ipairs(boutonsEmplacement) do
    b:SetScript("OnClick", function(self) emplacementChoisi = self.index Relancer() end)
end
for _, b in ipairs(boutonsClasse) do
    b:SetScript("OnClick", function(self)
        classeChoisie = self.classe
        catalogue.X = {}
        Relancer()
        Commande(".solform classe " .. self.classe)
    end)
end
boutonMatiere:SetScript("OnClick", function() matiere = matiere % #MATIERES + 1 Relancer() end)
boutonTri:SetScript("OnClick", function() tri = tri % #TRIS + 1 Relancer() end)

recherche:SetScript("OnTextChanged", Filtrer)
recherche:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
caseConnus:SetScript("OnClick", Filtrer)
PlacerListe()

------------------------------------------------------------------------
-- Échanges avec le serveur
------------------------------------------------------------------------
local function Lire(categorie, paquet)
    if categorie == "I" then
        for element in string.gmatch(paquet, "[^;]+") do
            local id, niveau, prix, cuivre, inv, classe, sousClasse = strsplit(":", element)
            table.insert(enCours.I, { categorie = "I", id = tonumber(id), niveau = tonumber(niveau) or 0,
                                      prix = tonumber(prix) or 0, cuivre = tonumber(cuivre) or 0, etat = 0,
                                      inv = tonumber(inv) or 0, classe = tonumber(classe) or 0, sousClasse = tonumber(sousClasse) or 0 })
        end
        return
    end
    if categorie == "E" then
        for element in string.gmatch(paquet, "[^;]+") do
            local id, boss, eclats, prix, nomBoss = strsplit(":", element)
            eclats, prix = tonumber(eclats) or 0, tonumber(prix) or 30
            table.insert(enCours.E, { categorie = "E", id = tonumber(id), niveau = 0, prix = prix, eclats = eclats,
                                      boss = tonumber(boss), nomBoss = nomBoss or "?", etat = eclats >= prix and 0 or 1 })
        end
        return
    end
    for element in string.gmatch(paquet, "[^;]+") do
        local id, niveau, prix, etat, metier, rangMetier = strsplit(":", element)
        table.insert(enCours[categorie], {
            categorie = categorie, id = tonumber(id), niveau = tonumber(niveau) or 0, prix = tonumber(prix) or 0,
            etat = tonumber(etat) or 1, metier = tonumber(metier), rangMetier = tonumber(rangMetier),
        })
    end
end

local evenements = CreateFrame("Frame")
evenements:RegisterEvent("CHAT_MSG_ADDON")
evenements:RegisterEvent("PLAYER_MONEY")
evenements:SetScript("OnEvent", function(self, event, prefixe, message)
    if event == "PLAYER_MONEY" then
        if cadre:IsShown() then orTexte:SetText(TexteRessources()) end
        return
    end
    if prefixe ~= PREFIXE then return end
    if strsub(message, 1, 7) == "XDEBUT|" then
        enCoursX = {}
    elseif strsub(message, 1, 2) == "X|" then
        for element in string.gmatch(strsub(message, 3), "[^;]+") do
            local id, niveau, prix, etat, forme = strsplit(":", element)
            table.insert(enCoursX, { categorie = "X", id = tonumber(id), niveau = tonumber(niveau) or 0,
                                     prix = tonumber(prix) or 0, etat = tonumber(etat) or 1, forme = tonumber(forme) or 0 })
        end
    elseif message == "XFIN" then
        catalogue.X = enCoursX
        if cadre:IsShown() then Filtrer() end
    elseif message == "DEBUT" then
        enCours = { S = {}, M = {}, R = {}, C = {}, O = {}, B = {}, I = {}, E = {}, X = {} }
    elseif strsub(message, 1, 2) == "N|" then
        marques = tonumber(strsub(message, 3)) or 0
    elseif message == "FIN" then
        enCours.X = catalogue.X
        catalogue = enCours
        if cadre:IsShown() then Filtrer() end
    else
        local categorie, paquet = strmatch(message, "^(%u)|(.*)$")
        if categorie and enCours[categorie] then Lire(categorie, paquet) end
    end
end)

local function Basculer()
    if cadre:IsShown() then
        cadre:Hide()
    else
        cadre:Show()
        Filtrer()
        Commande(".solform liste")
    end
end

SLASH_SOLAZEROTHFORMATION1 = "/apprendre"
SlashCmdList["SOLAZEROTHFORMATION"] = Basculer

------------------------------------------------------------------------
-- Bouton de la minicarte, déplaçable autour du bord (position mémorisée)
------------------------------------------------------------------------
local RAYON = 80

local bouton = CreateFrame("Button", "SolAzerothFormationBoutonMinicarte", Minimap)
bouton:SetSize(31, 31)
bouton:SetFrameStrata("MEDIUM")
bouton:SetFrameLevel(8)
bouton:RegisterForClicks("LeftButtonUp")
bouton:RegisterForDrag("LeftButton")
bouton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
local iconeBouton = bouton:CreateTexture(nil, "BACKGROUND")
iconeBouton:SetSize(20, 20)
iconeBouton:SetPoint("TOPLEFT", 7, -5)
iconeBouton:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
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
    SolAzerothFormationDB.angle = angle
    Placer(angle)
end

bouton:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", SuivreCurseur) end)
bouton:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
bouton:SetScript("OnClick", Basculer)
bouton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Apprentissage", 1, 0.82, 0)
    GameTooltip:AddLine("Sorts, métiers, recettes, maîtrises, outils", 1, 1, 1)
    GameTooltip:AddLine("Clic : ouvrir ou fermer", 1, 1, 1)
    GameTooltip:AddLine("Glisser : déplacer le bouton", 1, 1, 1)
    GameTooltip:Show()
end)
bouton:SetScript("OnLeave", function() GameTooltip:Hide() end)

local chargement = CreateFrame("Frame")
chargement:RegisterEvent("ADDON_LOADED")
chargement:SetScript("OnEvent", function(self, event, nom)
    if nom ~= "SolAzerothFormation" then return end
    self:UnregisterEvent("ADDON_LOADED")
    SolAzerothFormationDB = SolAzerothFormationDB or { angle = 160 }
    Placer(SolAzerothFormationDB.angle)
end)
