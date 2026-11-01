-- Sol'Azeroth v3 (01/11/2026, demande de l'utilisateur) : l'inventaire dans le carnet Collection.
-- Ce qu'il y a vraiment dans les sacs, sur 50 places : le sac à dos (16) et la Besace d'aventurier (34), posée d'office
-- par le serveur (v3_inventaire.cpp). Les cases reprennent le modèle du jeu (ContainerFrameItemButtonTemplate) :
-- utiliser, vendre, glisser et l'infobulle marchent comme d'habitude.
-- Les fenêtres de sacs du jeu ne s'ouvrent plus : leurs touches et appels (marchand, courrier) ouvrent cet onglet.

local S = SolUI

local COLONNES, TAILLE, ECART = 10, 46, 6
local PLACES = 50

local f = S.Fenetre("SolUIInventaire", 2 * 28 + COLONNES * TAILLE + (COLONNES - 1) * ECART, 64 + 5 * (TAILLE + ECART) + 64,
    "Inventaire")

-- Une case par place de sac (sacs 0 à 4) ; le cadre parent porte le numéro du sac (GetID), comme dans le jeu.
local supports, cases = {}, {}
for sac = 0, NUM_BAG_SLOTS or 4 do
    local support = CreateFrame("Frame", "SolUIInventaireSac" .. sac, f)
    support:SetID(sac)
    support:SetAllPoints(f)
    supports[sac] = support
    cases[sac] = {}
end

local function Case(sac, place)
    local c = cases[sac][place]
    if c then return c end
    c = CreateFrame("Button", "SolUIInventaireSac" .. sac .. "Place" .. place, supports[sac],
        "ContainerFrameItemButtonTemplate")
    c:SetID(place)
    c:SetSize(TAILLE, TAILLE)
    local fond = S.Texture(c, "BACKGROUND", nil, S.Couleur("creux"))
    fond:SetAllPoints()
    cases[sac][place] = c
    return c
end

local libres = S.Texte(f, "Regular", 13, "gris")
libres:SetPoint("BOTTOMLEFT", 28, 24)
local argent = S.Texte(f, "SemiBold", 14, "clair")
argent:SetPoint("BOTTOMRIGHT", -28, 24)

local function Maj()
    if not f:IsShown() then return end
    local n, vides = 0, 0
    for sac = 0, NUM_BAG_SLOTS or 4 do
        local total = GetContainerNumSlots(sac) or 0
        for place = 1, math.max(total, #cases[sac]) do
            local c = place <= total and Case(sac, place) or cases[sac][place]
            if place <= total then
                local x, y = n % COLONNES, math.floor(n / COLONNES)
                c:ClearAllPoints()
                c:SetPoint("TOPLEFT", f, "TOPLEFT", 28 + x * (TAILLE + ECART), -64 - y * (TAILLE + ECART))
                local texture, nombre, verrou = GetContainerItemInfo(sac, place)
                SetItemButtonTexture(c, texture)
                SetItemButtonCount(c, nombre)
                SetItemButtonDesaturated(c, verrou)
                ContainerFrame_UpdateCooldown(sac, c)
                if not texture then vides = vides + 1 end
                c:Show()
                n = n + 1
            else
                c:Hide()
            end
        end
    end
    libres:SetText("Places libres : " .. vides .. " / " .. n .. (n < PLACES and "  (besace en attente)" or ""))
    argent:SetText(S.Argent(GetMoney()))
end
f:SetScript("OnShow", Maj)
for _, e in ipairs({ "BAG_UPDATE", "ITEM_LOCK_CHANGED", "BAG_UPDATE_COOLDOWN", "PLAYER_MONEY", "UNIT_INVENTORY_CHANGED" }) do
    S.Ecouter(e, Maj)
end

-- Sacs du jeu : leurs fenêtres restent rangées, leurs points d'entrée mènent ici.
for i = 1, NUM_CONTAINER_FRAMES or 13 do S.Ranger(_G["ContainerFrame" .. i]) end
local parMarchand = false
local function Basculer() S.BasculerCarnet("collection", 1) end
ToggleBackpack, ToggleBag = Basculer, Basculer
OpenAllBags = Basculer
function OpenBackpack()
    if not f:IsShown() then
        S.OuvrirCarnet("collection", 1)
        parMarchand = true
    end
end
function CloseBackpack()
    if parMarchand and f:IsShown() then f:Hide() end
    parMarchand = false
end
f:HookScript("OnHide", function() parMarchand = false end)
