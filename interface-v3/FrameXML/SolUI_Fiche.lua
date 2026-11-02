-- Audit du jeu, lot 6c (02/11/2026, C10 du consensus ; choix de l'utilisateur : « notre propre fiche ») : Personnage ›
-- Fiche, en graphite, à la place de la fiche dorée de Blizzard (CharacterFrame). Elle ne montre pas le niveau (caché en
-- v3) mais ce qui compte ici : la puissance et son détail, le rang de chaque pièce, l'âme, et les pourcentages que le jeu
-- ne montrait nulle part (réduction de l'armure, critique, vol de vie des variantes).
-- Les pièces se posent et s'enlèvent comme dans la fiche du jeu : glisser-déposer, clic, Maj + clic pour un lien.

local S = SolUI

-- Réglages du serveur (modules\mod-solazeroth\conf\mod_solazeroth.conf.dist) repris pour les calculs affichés.
local PAR_RANG = 0.1             -- SolAzeroth.V3.PuissanceParRang
local ARMURE_K, ARMURE_C = 100, 3 -- SolAzeroth.V3.ArmureK et ArmureC
local VOL_DE_VIE = 0.5           -- variante Vol de vie (SolUI_Equipement.lua)

local GAUCHE = { "HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot", "ChestSlot", "ShirtSlot", "TabardSlot", "WristSlot" }
local DROITE = { "HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot", "Finger0Slot", "Finger1Slot", "Trinket0Slot",
    "Trinket1Slot" }
local ARMES = { "MainHandSlot", "SecondaryHandSlot", "RangedSlot" }
local HORS_PUISSANCE = { ShirtSlot = true, TabardSlot = true }   -- comme CalculerPuissance (v3_combat.cpp)

local f = S.Fenetre("SolUIFiche", 860, 580, "Fiche")
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

local function Ligne(texte, y)
    local l = S.Texte(f, "Regular", 13, "texte")
    l:SetPoint("TOPLEFT", X, y)
    l:SetText(texte)
    local v = S.Texte(f, "SemiBold", 13, "clair")
    v:SetPoint("TOPRIGHT", -24, y)
    return v
end

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
local vie = Ligne("Vie", -310)
local armure = Ligne("Armure", -330)
local reduction = Ligne("Coups d'un monstre de ta puissance", -350)
local attaque = Ligne("Puissance d'attaque", -370)
local degats = Ligne("Dégâts de l'arme", -390)
local critique = Ligne("Critique", -410)
local volDeVie = Ligne("Vol de vie", -430)

Rubrique("CARACTÉRISTIQUES", -466)
local stats = {}
for i, t in ipairs({ "Force", "Agilité", "Endurance", "Intelligence", "Esprit" }) do
    stats[i] = Ligne(t, -486 - (i - 1) * 18)
end

local function Pourcent(v) return S.Nombre(v, 1) .. " %" end

local function Maj()
    if not f:IsShown() then return end
    for _, c in pairs(cases) do MajCase(c) end
    nom:SetText(UnitName("player"))
    spe:SetText(S.etat.spe == 1 and "Guerrier — Tank" or (UnitClass("player")))

    -- Niveau d'objet moyen sans les rangs, et nombre de variantes Vol de vie portées.
    local somme, nombre, vols = 0, 0, 0
    for id, c in pairs(cases) do
        local lien = GetInventoryItemLink("player", id)
        local niveau = lien and select(4, GetItemInfo(lien))
        if niveau and not HORS_PUISSANCE[c.emplacement] then
            somme, nombre = somme + niveau, nombre + 1
        end
        local p = lien and portees[id]
        if p and p.variante == 3 then vols = vols + 1 end
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

f:SetScript("OnShow", function()
    modele:SetUnit("player")
    angle = 0
    modele:SetFacing(0)
    SendChatMessage(".equipement", "SAY")
    Maj()
end)
