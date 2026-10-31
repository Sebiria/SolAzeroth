-- Sol'Azeroth v3, F4 : interface paramétrable (demande de l'utilisateur, 31/10/2026).
-- Mode édition : chaque bloc se couvre d'un calque ambre ; on le déplace à la souris, la molette change son échelle
-- (Maj + molette : la largeur du cadre de la cible). Hors combat seulement : il se ferme à l'entrée en combat.
-- La page Réglages > Interface de /sol (addon SolAzeroth) ouvre ce mode, propose les mêmes réglages en curseurs et
-- garde la disposition entre deux sessions (SolAzerothDB.interface) : elle est prévenue par S.surChangement.

local S = SolUI

local NOMS = { perso = "Personnage", techniques = "Techniques", cible = "Cible", zone = "Zone", quetes = "Quêtes" }
S.NOMS_BLOCS = NOMS
S.LIMITES = { echelle = { 0.6, 1.6 }, largeur = { 420, 1100 }, carte = { 70, 220 }, reperes = { 0.5, 2.5 } }

local function Copier(table)
    local copie = {}
    for cle, valeur in pairs(table) do copie[cle] = type(valeur) == "table" and Copier(valeur) or valeur end
    return copie
end

S.DEFAUTS = Copier(S.DISPOSITION)
S.DEFAUTS_OPTIONS = Copier(S.OPTIONS)

local function Borner(valeur, limites)
    return math.max(limites[1], math.min(limites[2], valeur))
end

local function Prevenir()
    if S.surChangement then
        local d = Copier(S.DISPOSITION)
        d.options = Copier(S.OPTIONS)
        S.surChangement(d)
    end
end

-- Change un réglage qui n'est pas un bloc (S.OPTIONS) ; les cadres concernés sont prévenus par S.Abonner("options").
function S.ModifierOption(nom, valeur)
    if InCombatLockdown() or S.OPTIONS[nom] == nil or type(valeur) ~= "number" then return end
    if S.LIMITES[nom] then valeur = Borner(valeur, S.LIMITES[nom]) end
    S.OPTIONS[nom] = valeur
    S.Prevenir("options")
    Prevenir()
end

-- Change un réglage d'un bloc (« echelle », « largeur ») et le replace.
function S.Modifier(nom, champ, valeur)
    if InCombatLockdown() or not S.DISPOSITION[nom] then return end
    if S.LIMITES[champ] then valeur = Borner(valeur, S.LIMITES[champ]) end
    S.DISPOSITION[nom][champ] = valeur
    S.Placer(S.blocs[nom], nom)
    Prevenir()
end

-- Reprend une disposition enregistrée (champs connus seulement, valeurs bornées).
function S.Appliquer(sauvegarde)
    if InCombatLockdown() or type(sauvegarde) ~= "table" then return end
    for nom, d in pairs(sauvegarde) do
        local actuel = S.DISPOSITION[nom]
        if actuel and type(d) == "table" and S.blocs[nom] then
            if type(d.point) == "string" then actuel.point = d.point end
            if type(d.x) == "number" then actuel.x = d.x end
            if type(d.y) == "number" then actuel.y = d.y end
            if type(d.echelle) == "number" then actuel.echelle = Borner(d.echelle, S.LIMITES.echelle) end
            if actuel.largeur and type(d.largeur) == "number" then actuel.largeur = Borner(d.largeur, S.LIMITES.largeur) end
            actuel.sous = type(d.sous) == "string" and d.sous or nil
            S.Placer(S.blocs[nom], nom)
        end
    end
    if type(sauvegarde.options) == "table" then
        for nom, valeur in pairs(sauvegarde.options) do
            if S.OPTIONS[nom] ~= nil and type(valeur) == "number" then
                S.OPTIONS[nom] = S.LIMITES[nom] and Borner(valeur, S.LIMITES[nom]) or valeur
            end
        end
        S.Prevenir("options")
    end
end

-- Remet un bloc (ou tous, sans nom) à sa place d'origine.
function S.Reinitialiser(nom)
    if InCombatLockdown() then return end
    for cle, defaut in pairs(S.DEFAUTS) do
        if not nom or nom == cle then
            S.DISPOSITION[cle] = Copier(defaut)
            S.Placer(S.blocs[cle], cle)
        end
    end
    if not nom then
        S.OPTIONS = Copier(S.DEFAUTS_OPTIONS)
        S.Prevenir("options")
    end
    -- Les blocs rangés sous un autre bloc suivent celui-ci.
    for cle, d in pairs(S.DISPOSITION) do
        if d.sous == nom and S.blocs[cle] then S.Placer(S.blocs[cle], cle) end
    end
    Prevenir()
end

------------------------------------------------------------------------
-- Calques du mode édition
------------------------------------------------------------------------
-- Coordonnées d'un point d'ancrage (« TOPRIGHT »…) d'un cadre, en pixels d'écran.
local function Coordonnees(cadre, point)
    local echelle = cadre:GetEffectiveScale()
    local x = (point:find("LEFT") and cadre:GetLeft()) or (point:find("RIGHT") and cadre:GetRight())
        or (cadre:GetLeft() + cadre:GetRight()) / 2
    local y = (point:find("TOP") and cadre:GetTop()) or (point:find("BOTTOM") and cadre:GetBottom())
        or (cadre:GetTop() + cadre:GetBottom()) / 2
    return x * echelle, y * echelle
end

-- Après un déplacement, le bloc garde son point d'ancrage : on recalcule son décalage par rapport à la racine.
local function Retenir(nom)
    local cadre, d = S.blocs[nom], S.DISPOSITION[nom]
    local bx, by = Coordonnees(cadre, d.point)
    local rx, ry = Coordonnees(S.racine, d.point)
    d.sous = nil
    local echelleRacine = S.racine:GetEffectiveScale()
    d.x = math.floor((bx - rx) / echelleRacine + 0.5)
    d.y = math.floor((by - ry) / echelleRacine + 0.5)
    S.Placer(cadre, nom)
    Prevenir()
end

local calques = {}
local enEdition = false

local function Calque(nom)
    local cadre = S.blocs[nom]
    local c = CreateFrame("Frame", nil, cadre)
    c:SetAllPoints()
    c:SetFrameStrata("DIALOG")
    c:EnableMouse(true)
    c:EnableMouseWheel(true)
    c:RegisterForDrag("LeftButton")
    c:SetBackdrop({ bgFile = S.BLANC, edgeFile = S.BLANC, edgeSize = 2, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    c:SetBackdropColor(S.Couleur("ambre", 0.16))
    c:SetBackdropBorderColor(S.Couleur("ambre", 0.9))
    c.titre = S.Texte(c, "SemiBold", 14, "ambreClair")
    c.titre:SetPoint("CENTER", 0, 8)
    c.aide = S.Texte(c, "Regular", 11, "texte", 0.85)
    c.aide:SetPoint("TOP", c.titre, "BOTTOM", 0, -3)
    local function Titre()
        local d = S.DISPOSITION[nom]
        local texte = NOMS[nom] .. "  " .. math.floor(d.echelle * 100 + 0.5) .. " %"
        if d.largeur then texte = texte .. "  ·  " .. d.largeur end
        c.titre:SetText(texte)
    end
    c.aide:SetText(S.DISPOSITION[nom].largeur and "Glisser · molette : taille · Maj + molette : largeur"
        or "Glisser · molette : taille")
    c:SetScript("OnShow", Titre)
    c:SetScript("OnDragStart", function()
        cadre:SetMovable(true)
        cadre:StartMoving()
    end)
    c:SetScript("OnDragStop", function()
        cadre:StopMovingOrSizing()
        -- Sinon le jeu retiendrait lui-même la position (layout-local.txt) et la reprendrait à la place de la nôtre.
        cadre:SetUserPlaced(false)
        Retenir(nom)
    end)
    c:SetScript("OnMouseWheel", function(self, sens)
        local d = S.DISPOSITION[nom]
        if d.largeur and IsShiftKeyDown() then
            S.Modifier(nom, "largeur", d.largeur + 20 * sens)
        else
            S.Modifier(nom, "echelle", math.floor((d.echelle + 0.05 * sens) * 100 + 0.5) / 100)
        end
        Titre()
    end)
    c:Hide()
    return c
end

-- Bandeau du mode édition : rappelle comment faire et le ferme (bouton ou Échap).
local bandeau = CreateFrame("Frame", "SolUIEdition", S.racine)
bandeau:SetSize(420, 64)
bandeau:SetPoint("CENTER", S.racine, "CENTER", 0, 150)
bandeau:SetFrameStrata("DIALOG")
bandeau:SetFrameLevel(20)
S.Panneau(bandeau, 0.95, "bord")
bandeau:SetBackdropBorderColor(S.Couleur("ambre"))
local texteBandeau = S.Texte(bandeau, "SemiBold", 14, "ambreClair")
texteBandeau:SetPoint("TOPLEFT", 16, -14)
texteBandeau:SetText("Mode édition de l'interface")
local aideBandeau = S.Texte(bandeau, "Regular", 11, "texte", 0.85)
aideBandeau:SetPoint("TOPLEFT", texteBandeau, "BOTTOMLEFT", 0, -4)
aideBandeau:SetText("Déplace les blocs ambre. Échap pour terminer.")
local terminer = CreateFrame("Button", nil, bandeau, "UIPanelButtonTemplate")
terminer:SetSize(100, 24)
terminer:SetPoint("RIGHT", -14, 0)
terminer:SetText("Terminer")
terminer:SetScript("OnClick", function() bandeau:Hide() end)
bandeau:Hide()
tinsert(UISpecialFrames, "SolUIEdition")

function S.EnEdition() return enEdition end

function S.ModeEdition(actif)
    if actif and InCombatLockdown() then return end
    enEdition = actif and true or false
    for nom in pairs(NOMS) do
        calques[nom] = calques[nom] or Calque(nom)
        S.Montrer(calques[nom], enEdition)
    end
    S.Montrer(bandeau, enEdition)
    -- La cible n'existe qu'avec une cible : en édition, elle se montre quand même.
    if S.RafraichirCible then S.RafraichirCible() end
    if S.MajQuetes then S.MajQuetes() end
    if S.surEdition then S.surEdition(enEdition) end
end

bandeau:SetScript("OnHide", function() if enEdition then S.ModeEdition(false) end end)
S.Ecouter("PLAYER_REGEN_DISABLED", function() if enEdition then S.ModeEdition(false) end end)
