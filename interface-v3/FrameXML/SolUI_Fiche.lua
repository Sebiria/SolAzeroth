-- Audit du jeu, lot 6c (02/11/2026, C10 du consensus ; choix de l'utilisateur : « notre propre fiche ») : Personnage ›
-- Fiche, en graphite, à la place de la fiche dorée de Blizzard (CharacterFrame). Elle ne montre pas le niveau (caché en
-- v3) mais ce qui compte ici : la puissance et son détail, le rang de chaque pièce, l'âme, et les pourcentages que le jeu
-- ne montrait nulle part (réduction de l'armure, critique, vol de vie des variantes).
-- Les pièces se posent et s'enlèvent comme dans la fiche du jeu : glisser-déposer, clic, Maj + clic pour un lien. Les
-- pièces des sacs sont à droite de la fiche (signalements 33 et 34).

local S = SolUI

-- Réglages du serveur (modules\mod-solazeroth\conf\mod_solazeroth.conf.dist) repris pour les calculs affichés.
local PAR_RANG = 0.1             -- SolAzeroth.V3.PuissanceParRang
local ARMURE_K, ARMURE_C = 100, 3 -- SolAzeroth.V3.ArmureK et ArmureC
local VOL_DE_VIE = 0.5           -- variante Vol de vie (SolUI_Equipement.lua)
local HATE = 2                   -- variante Hâte, en %

local GAUCHE = { "HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot", "ChestSlot", "ShirtSlot", "TabardSlot", "WristSlot" }
local DROITE = { "HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot", "Finger0Slot", "Finger1Slot", "Trinket0Slot",
    "Trinket1Slot" }
local ARMES = { "MainHandSlot", "SecondaryHandSlot", "RangedSlot" }
local HORS_PUISSANCE = { ShirtSlot = true, TabardSlot = true }   -- comme CalculerPuissance (v3_combat.cpp)

local f = S.Fenetre("SolUIFiche", 1124, 600, "Fiche")   -- 860 + les pièces des sacs
local cases = {}
local portees = {}   -- emplacement du jeu (1 à 19) -> { rang, variante }, d'après « .equipement » (SOLEQUIP)
local etatAme

------------------------------------------------------------------------
-- Modèle du personnage, tourné à la souris
------------------------------------------------------------------------
local modele = CreateFrame("PlayerModel", nil, f)
modele:SetPoint("TOPLEFT", 84, -72)
modele:SetSize(320, 420)
local fondModele = S.Texture(modele, "BACKGROUND", nil, S.Couleur("creux", 0.6))
fondModele:SetAllPoints()
local angle, departX = 0, nil
modele:EnableMouse(true)
modele:SetScript("OnMouseDown", function() departX = GetCursorPosition() end)
modele:SetScript("OnMouseUp", function() departX = nil end)
modele:SetScript("OnUpdate", function(self)
    if not departX then return end
    local x = GetCursorPosition()
    angle = angle + (x - departX) * 0.02
    departX = x
    self:SetFacing(angle)
end)
local aideModele = S.Texte(f, "Regular", 11, "gris")
aideModele:SetPoint("TOP", modele, "BOTTOM", 0, -6)
aideModele:SetText("Glisser pour tourner")

------------------------------------------------------------------------
-- Cases d'équipement
------------------------------------------------------------------------
local function Infobulle(c)
    GameTooltip:SetOwner(c, "ANCHOR_RIGHT")
    if not GameTooltip:SetInventoryItem("player", c.id) then
        GameTooltip:SetText(_G[string.upper(c.emplacement)] or c.emplacement)
    end
    local p = portees[c.id]
    if p then GameTooltip:AddLine("Rang d'amélioration " .. p.rang .. " / 5", S.Couleur("ambreClair")) end
    GameTooltip:Show()
end

local function Case(emplacement)
    local id, vide = GetInventorySlotInfo(emplacement)
    local c = CreateFrame("Button", nil, f)
    c:SetSize(40, 40)
    c.id, c.emplacement, c.vide = id, emplacement, vide
    c:SetBackdrop({ bgFile = S.BLANC, edgeFile = S.BLANC, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
    c:SetBackdropColor(S.Couleur("creux"))
    c.icone = c:CreateTexture(nil, "ARTWORK")
    c.icone:SetPoint("TOPLEFT", 2, -2)
    c.icone:SetPoint("BOTTOMRIGHT", -2, 2)
    c.icone:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    c.rang = S.Texte(c, "Bold", 11, "ambreClair")
    c.rang:SetPoint("BOTTOMRIGHT", -3, 3)
    c:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    c:RegisterForDrag("LeftButton")
    c:SetScript("OnClick", function(self)
        if IsModifiedClick() then
            HandleModifiedItemClick(GetInventoryItemLink("player", self.id))
        else
            PickupInventoryItem(self.id)
        end
    end)
    c:SetScript("OnDragStart", function(self) PickupInventoryItem(self.id) end)
    c:SetScript("OnReceiveDrag", function(self) PickupInventoryItem(self.id) end)
    c:SetScript("OnEnter", Infobulle)
    c:SetScript("OnLeave", function() GameTooltip:Hide() end)
    cases[id] = c
    return c
end

for i, e in ipairs(GAUCHE) do Case(e):SetPoint("TOPLEFT", 24, -72 - (i - 1) * 53) end
for i, e in ipairs(DROITE) do Case(e):SetPoint("TOPLEFT", 420, -72 - (i - 1) * 53) end
for i, e in ipairs(ARMES) do Case(e):SetPoint("TOP", modele, "BOTTOM", (i - 2) * 52, -28) end

local function MajCase(c)
    local texture = GetInventoryItemTexture("player", c.id)
    c.icone:SetTexture(texture or c.vide)
    c.icone:SetAlpha(texture and 1 or 0.35)
    local qualite = texture and GetInventoryItemQuality("player", c.id)
    if qualite then
        local r, g, b = GetItemQualityColor(qualite)
        c:SetBackdropBorderColor(r, g, b)
    else
        c:SetBackdropBorderColor(S.Couleur("bord"))
    end
    local p = texture and portees[c.id]
    c.rang:SetText(p and p.rang > 0 and ("R" .. p.rang) or "")
end

------------------------------------------------------------------------
-- Colonne de droite : puissance, âme, combat, caractéristiques
------------------------------------------------------------------------
local X = 492
local nom = S.Texte(f, "Bold", 18, "clair")
nom:SetPoint("TOPLEFT", X, -72)
local spe = S.Texte(f, "Regular", 13, "gris")
spe:SetPoint("TOPLEFT", X, -96)

local function Rubrique(texte, y)
    local t = S.Texte(f, "Bold", 11, "gris")
    t:SetPoint("TOPLEFT", X, y)
    t:SetText(texte)
end

-- Survol d'une ligne : son titre puis les lignes que rend Lignes() (signalements 40 et 46, 03/11/2026).
local function Survol(titre, y, Lignes)
    local survol = CreateFrame("Frame", nil, f)
    survol:SetPoint("TOPLEFT", X, y + 2)
    survol:SetSize(836 - X, 18)
    survol:EnableMouse(true)
    survol:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(titre)
        for _, l in ipairs(Lignes()) do
            if type(l) == "table" then
                GameTooltip:AddLine(l[1], S.Couleur(l[2]))
            else
                GameTooltip:AddLine(l, 1, 1, 1, true)
            end
        end
        GameTooltip:Show()
    end)
    survol:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function Ligne(texte, y, Lignes)
    local l = S.Texte(f, "Regular", 13, "texte")
    l:SetPoint("TOPLEFT", X, y)
    l:SetText(texte)
    local v = S.Texte(f, "SemiBold", 13, "clair")
    v:SetPoint("TOPRIGHT", f, "TOPLEFT", 836, y)
    if Lignes then Survol(texte, y, Lignes) end
    return v
end
local function Lanceur() return S.etat.spe == 2 end   -- sorts : Intelligence, l'arme ne frappe pas

Rubrique("PUISSANCE", -128)
local puissance = S.Texte(f, "Bold", 28, "ambreClair")
puissance:SetPoint("TOPLEFT", X, -144)
local explication = S.Texte(f, "Regular", 11, "gris")
explication:SetPoint("TOPLEFT", X, -180)
explication:SetWidth(344)
explication:SetJustifyH("LEFT")
explication:SetText("Moyenne des niveaux d'objet portés (chemise et tabard exceptés) ; chaque rang d'amélioration "
    .. "ajoute 10 % à sa pièce.")
local niveauMoyen = Ligne("Niveau d'objet moyen", -214)
local apportRangs = Ligne("Apport des rangs", -234)
local ameValeur = Ligne("Âme", -254)

Rubrique("COMBAT", -290)
local vie = Ligne("Vie", -310, function() return {
    "10 points par point d'Endurance.",
    "Elle remonte hors combat (2 % par seconde), au feu de camp et par ta potion." } end)
local armure = Ligne("Armure", -330, function() return {
    "Retire un montant fixe à chaque coup reçu : les petits coups passent mal." } end)
local reduction = Ligne("Coups d'un monstre de ta puissance", -350, function() return {
    "Part que ton armure retire au coup moyen d'un monstre de ta puissance.",
    "Face à un monstre plus puissant, elle baisse." } end)
local attaque = Ligne("Puissance d'attaque", -370, function() return {
    "Augmente les dégâts de tes " .. (Lanceur() and "sorts" or "techniques") .. ".",
    "2 par point de la caractéristique principale de ta spécialisation"
        .. (Lanceur() and ", plus les dégâts de ton arme (elle ne frappe pas)." or ".") } end)
local degats = Ligne("Dégâts de l'arme", -390, function() return {
    Lanceur() and "Ton arme ne frappe pas : ses dégâts par seconde s'ajoutent à ta puissance d'attaque."
        or "Tes techniques font un pourcentage de ces dégâts. Entre parenthèses : la vitesse de l'arme." } end)
local critique = Ligne("Critique", -410, function() return {
    "Chance qu'un coup soit critique.",
    "Variante Critique des pièces : + 1 % chacune. L'Agilité en donne un peu." } end)
local hate = Ligne("Hâte", -430, function() return {
    "Coups et incantations plus rapides.", "Variante Hâte des pièces : + 2 % chacune." } end)
local volDeVie = Ligne("Vol de vie", -450, function() return {
    "Part des dégâts infligés qui te revient en vie.", "Variante Vol de vie des pièces : 0,5 % chacune." } end)

Rubrique("CARACTÉRISTIQUES", -486)
local stats = {}
-- Survol : ce que fait la caractéristique ici (signalement 40, 03/11/2026). Règles du serveur : v3_niveau.cpp (puissance
-- d'attaque), le reste est celui du jeu (ni esquive ni parade en v3).
local EFFETS = {
    "Blocage avec un bouclier.",
    "Un peu de critique et d'armure.",
    "10 points de vie par point.",
    "Critique des sorts.",
    "Aucun effet : hors combat, la vie remonte d'elle-même.",
}
local PRINCIPALE = { [1] = 1, [2] = 4, [3] = 2 }   -- spécialisation -> caractéristique (tank, Affliction, Assassinat)
for i, t in ipairs({ "Force", "Agilité", "Endurance", "Intelligence", "Esprit" }) do
    stats[i] = Ligne(t, -506 - (i - 1) * 18, function()
        local l = {}
        if PRINCIPALE[S.etat.spe or 0] == i then
            table.insert(l, { "Caractéristique principale de ta spécialisation : 2 de puissance d'attaque par point.",
                "ambreClair" })
        end
        table.insert(l, EFFETS[i])
        return l
    end)
end

local function Pourcent(v) return S.Nombre(v, 1) .. " %" end

local function Maj()
    if not f:IsShown() then return end
    for _, c in pairs(cases) do MajCase(c) end
    nom:SetText(UnitName("player"))
    spe:SetText(S.etat.spe == 1 and "Guerrier — Tank" or S.etat.spe == 2 and "Démoniste — Affliction"
        or S.etat.spe == 3 and "Voleur — Assassinat"
        or (UnitClass("player")))

    -- Niveau d'objet moyen sans les rangs, et nombre de variantes Hâte et Vol de vie portées.
    local somme, nombre, vols, hates = 0, 0, 0, 0
    for id, c in pairs(cases) do
        local lien = GetInventoryItemLink("player", id)
        local niveau = lien and select(4, GetItemInfo(lien))
        if niveau and not HORS_PUISSANCE[c.emplacement] then
            somme, nombre = somme + niveau, nombre + 1
        end
        local p = lien and portees[id]
        if p and p.variante == 3 then vols = vols + 1 end
        if p and p.variante == 2 then hates = hates + 1 end
    end
    local moyen = nombre > 0 and somme / nombre or 0
    local P = S.etat.puissance
    puissance:SetText(P and S.Nombre(P, 1) or "…")
    niveauMoyen:SetText(S.Nombre(moyen, 1))
    apportRangs:SetText(P and ("+ " .. S.Nombre(math.max(0, P - moyen), 1)) or "…")
    ameValeur:SetText(not etatAme and "…" or etatAme.eteinte and "|cffc9483eÉteinte|r"
        or (etatAme.valeur .. " / " .. etatAme.max))

    vie:SetText(S.Nombre(UnitHealthMax("player")))
    local _, effective = UnitArmor("player")
    armure:SetText(S.Nombre(effective))
    reduction:SetText(P and ("− " .. Pourcent(100 * effective / (effective + ARMURE_K * (ARMURE_C + P)))) or "…")
    local base, plus, moins = UnitAttackPower("player")
    attaque:SetText(S.Nombre(base + plus + moins))
    local mini, maxi = UnitDamage("player")
    local vitesse = UnitAttackSpeed("player")
    degats:SetText(S.Nombre(mini) .. " – " .. S.Nombre(maxi) .. "  (" .. S.Nombre(vitesse, 1) .. " s)")
    critique:SetText(Pourcent(GetCritChance()))
    hate:SetText(Pourcent(hates * HATE))
    volDeVie:SetText(Pourcent(vols * VOL_DE_VIE))
    for i = 1, 5 do
        local _, valeur = UnitStat("player", i)
        stats[i]:SetText(S.Nombre(valeur))
    end
end

------------------------------------------------------------------------
-- Données : rangs des pièces (SOLEQUIP), âme (SOLAME), événements du jeu
------------------------------------------------------------------------
local recus
S.Message("SOLEQUIP", function(champs)
    if champs[1] == "DEBUT" then
        recus = {}
    elseif champs[1] == "OBJ" and recus and champs[2] == "-1" then
        -- « OBJ;-1;emplacement du serveur (0 à 18);entrée;rang;… ;variante » (v3_equipement.cpp)
        recus[(tonumber(champs[3]) or -1) + 1] = { rang = tonumber(champs[5]) or 0, variante = tonumber(champs[13]) or 0 }
    elseif champs[1] == "FIN" and recus then
        portees, recus = recus, nil
        Maj()
    end
end)

S.Message("SOLAME", function(champs)
    if champs[1] == "AME" then
        etatAme = { valeur = tonumber(champs[2]) or 0, max = tonumber(champs[3]) or 0 }
    elseif champs[1] == "ETEINTE" then
        etatAme = { valeur = 0, max = etatAme and etatAme.max or 0, eteinte = true }
    end
    Maj()
end)

S.Abonner("puissance", Maj)
S.Abonner("kit", Maj)
for _, e in ipairs({ "UNIT_INVENTORY_CHANGED", "UNIT_STATS", "UNIT_ATTACK_POWER", "UNIT_RESISTANCES", "UNIT_MAXHEALTH",
    "UNIT_DAMAGE", "UNIT_ATTACK_SPEED" }) do
    S.Ecouter(e, function(_, unite) if unite == "player" then Maj() end end)
end
-- Une pièce posée ou enlevée : les rangs sont redemandés au serveur (il ne les envoie que sur demande).
S.Ecouter("PLAYER_EQUIPMENT_CHANGED", function()
    if f:IsShown() then SendChatMessage(".equipement", "SAY") end
    Maj()
end)

------------------------------------------------------------------------
-- Équipement des sacs, dans la fiche, à droite (signalements 33 et 34, 03/11/2026 : le carnet n'ouvre qu'une fenêtre à
-- la fois, l'inventaire et la fiche ne se voyaient jamais ensemble). Les pièces portables seulement, sur des cases du
-- jeu (ContainerFrameItemButtonTemplate) : glisser sur la fiche, ou clic droit pour porter.
------------------------------------------------------------------------
local COL_SACS, T_SAC, E_SAC = 5, 40, 5
local sacs = CreateFrame("Frame", nil, f)
sacs:SetPoint("TOPLEFT", 860, -64)
sacs:SetPoint("BOTTOMRIGHT", -16, 16)
S.Panneau(sacs, 0.6)
local titreSacs = S.Texte(sacs, "Bold", 11, "gris")
titreSacs:SetPoint("TOPLEFT", 14, -14)
titreSacs:SetText("À PORTER, DANS LES SACS")
local aideSacs = S.Texte(sacs, "Regular", 11, "gris")
aideSacs:SetPoint("BOTTOMLEFT", 14, 14)
aideSacs:SetWidth(220)
aideSacs:SetJustifyH("LEFT")
aideSacs:SetText("Glisse une pièce sur sa case, ou clic droit pour la porter. Maj + clic droit : en main gauche.")
local videSacs = S.Texte(sacs, "Regular", 12, "gris")
videSacs:SetPoint("TOPLEFT", 14, -40)
videSacs:SetText("Aucune pièce à porter.")

local supportsSacs, casesSacs = {}, {}
for sac = 0, NUM_BAG_SLOTS or 4 do
    supportsSacs[sac] = CreateFrame("Frame", nil, sacs)
    supportsSacs[sac]:SetID(sac)
    supportsSacs[sac]:SetAllPoints(sacs)
    casesSacs[sac] = {}
end

local function CaseSac(sac, place)
    local c = casesSacs[sac][place]
    if c then return c end
    c = CreateFrame("Button", "SolUIFicheSac" .. sac .. "Place" .. place, supportsSacs[sac], "ContainerFrameItemButtonTemplate")
    c:SetID(place)
    c:SetSize(T_SAC, T_SAC)
    -- Maj + clic droit : en main gauche (signalement 41 : deux dagues, impossible de choisir la main).
    c:SetScript("OnClick", function(self, bouton)
        if bouton == "RightButton" and IsShiftKeyDown() then
            EquipItemByName(GetContainerItemLink(sac, place), GetInventorySlotInfo("SecondaryHandSlot"))
        elseif IsModifiedClick() then
            ContainerFrameItemButton_OnModifiedClick(self, bouton)
        else
            ContainerFrameItemButton_OnClick(self, bouton)
        end
    end)
    local fond = S.Texture(c, "BACKGROUND", nil, S.Couleur("creux"))
    fond:SetAllPoints()
    c.contour = CreateFrame("Frame", nil, c)
    c.contour:SetPoint("TOPLEFT", -1, 1)
    c.contour:SetPoint("BOTTOMRIGHT", 1, -1)
    c.contour:SetFrameLevel(c:GetFrameLevel() + 2)
    c.contour:SetBackdrop({ edgeFile = S.BLANC, edgeSize = 2 })
    casesSacs[sac][place] = c
    return c
end

local function MajSacs()
    if not f:IsShown() then return end
    local n = 0
    for sac = 0, NUM_BAG_SLOTS or 4 do
        local total = GetContainerNumSlots(sac) or 0
        for place = 1, math.max(total, #casesSacs[sac]) do
            local lien = place <= total and GetContainerItemLink(sac, place)
            if lien and IsEquippableItem(lien) then
                local c = CaseSac(sac, place)
                local x, y = n % COL_SACS, math.floor(n / COL_SACS)
                c:ClearAllPoints()
                c:SetPoint("TOPLEFT", sacs, "TOPLEFT", 14 + x * (T_SAC + E_SAC), -40 - y * (T_SAC + E_SAC))
                local texture, nombre, verrou, qualite = GetContainerItemInfo(sac, place)
                local teinte = ITEM_QUALITY_COLORS[qualite or -1]
                if teinte then
                    c.contour:SetBackdropBorderColor(teinte.r, teinte.g, teinte.b, 1)
                else
                    c.contour:SetBackdropBorderColor(S.Couleur("bord"))
                end
                SetItemButtonTexture(c, texture)
                SetItemButtonCount(c, nombre)
                SetItemButtonDesaturated(c, verrou)
                c:Show()
                n = n + 1
            elseif casesSacs[sac][place] then
                casesSacs[sac][place]:Hide()
            end
        end
    end
    S.Montrer(videSacs, n == 0)
end
for _, e in ipairs({ "BAG_UPDATE", "ITEM_LOCK_CHANGED", "UNIT_INVENTORY_CHANGED" }) do S.Ecouter(e, MajSacs) end

f:SetScript("OnShow", function()
    MajSacs()
    modele:SetUnit("player")
    angle = 0
    modele:SetFacing(0)
    SendChatMessage(".equipement", "SAY")
    Maj()
end)
