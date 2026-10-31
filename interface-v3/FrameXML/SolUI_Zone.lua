-- Sol'Azeroth v3, F4 : la zone (maquette Arène, reprise dans Synthèse), en haut à droite.
-- Cadre réduit en attendant F5 : nom de la zone, puissance conseillée (calculée par le serveur d'après ses monstres)
-- et sous-zone ; le pourcentage et les reliques viendront avec F5. Puis la mini-carte ronde et le bouton Menu, qui
-- remplace le micro-menu de Blizzard.

local S = SolUI

local zone = CreateFrame("Frame", "SolUIZone", S.racine)
zone:SetSize(248 + 12 + 92, 160)
S.Placer(zone, "zone")

------------------------------------------------------------------------
-- Suivi de zone
------------------------------------------------------------------------
local suivi = CreateFrame("Frame", nil, zone)
suivi:SetSize(248, 58)
suivi:SetPoint("TOPLEFT")
S.Panneau(suivi, 0.85)

local nom = S.Texte(suivi, "Bold", 15, "clair")
nom:SetPoint("TOPLEFT", suivi, "TOPLEFT", 14, -11)
nom:SetPoint("RIGHT", suivi, "RIGHT", -96, 0)
nom:SetJustifyH("LEFT")
local conseillee = S.Texte(suivi, "Regular", 12, "gris")
conseillee:SetPoint("TOPRIGHT", suivi, "TOPRIGHT", -14, -13)
local sousZone = S.Texte(suivi, "Regular", 12, "gris")
sousZone:SetPoint("TOPLEFT", nom, "BOTTOMLEFT", 0, -6)
sousZone:SetPoint("RIGHT", suivi, "RIGHT", -14, 0)
sousZone:SetJustifyH("LEFT")

local function MajZone()
    nom:SetText(GetZoneText() or "")
    local sous = GetSubZoneText()
    sousZone:SetText(sous ~= GetZoneText() and sous or "")
    local valeur = S.PuissanceConseillee()
    conseillee:SetText(valeur and ("Conseillée " .. valeur) or "")
end

for _, evenement in ipairs({ "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD" }) do
    S.Ecouter(evenement, MajZone)
end
S.Abonner("zone", MajZone)

------------------------------------------------------------------------
-- Mini-carte ronde : celle de Blizzard, sortie de son cadre et débarrassée de ses ornements
------------------------------------------------------------------------
local colonne = CreateFrame("Frame", nil, zone)
colonne:SetSize(92, 140)
colonne:SetPoint("TOPRIGHT")

Minimap:SetParent(colonne)
Minimap:ClearAllPoints()
Minimap:SetPoint("TOP", colonne, "TOP")
Minimap:SetSize(92, 92)
Minimap:EnableMouseWheel(true)
Minimap:SetScript("OnMouseWheel", function(self, sens)
    if sens > 0 then Minimap_ZoomIn() else Minimap_ZoomOut() end
end)

-- Taille réglable (Réglages > Interface) : la colonne et le bloc de la zone suivent.
local function TaillerCarte()
    local t = S.OPTIONS.carte
    Minimap:SetSize(t, t)
    colonne:SetSize(t, t + 48)
    zone:SetSize(248 + 12 + t, math.max(160, t + 68))
    -- La mini-carte ne redessine son contenu à la nouvelle taille qu'après un changement de zoom.
    local zoom = Minimap:GetZoom()
    Minimap:SetZoom(zoom > 0 and zoom - 1 or zoom + 1)
    Minimap:SetZoom(zoom)
end
S.Abonner("options", TaillerCarte)

local anneau = S.Texture(Minimap, "OVERLAY", "Anneau", 0.227, 0.239, 0.263)
anneau:SetPoint("TOPLEFT", -1, 1)
anneau:SetPoint("BOTTOMRIGHT", 1, -1)

for _, nomCadre in ipairs({ "MinimapCluster", "MinimapBorder", "MinimapBorderTop", "MinimapZoomIn", "MinimapZoomOut",
        "MinimapZoneTextButton", "MiniMapWorldMapButton", "GameTimeFrame", "MiniMapTracking", "MiniMapMailFrame",
        "MiniMapBattlefieldFrame", "MiniMapLFGFrame", "MiniMapVoiceChatFrame", "MinimapNorthTag",
        "MinimapCompassTexture", "MiniMapInstanceDifficulty", "MinimapBackdrop", "MiniMapRecordingButton" }) do
    local cadre = _G[nomCadre]
    if cadre then
        if cadre:GetObjectType() == "Texture" then cadre:Hide() else S.Ranger(cadre) end
    end
end

-- Boutons posés autour de la mini-carte par les addons (WeakAuras…) : rangés une fois tout chargé.
S.Ecouter("PLAYER_ENTERING_WORLD", function()
    for _, enfant in ipairs({ Minimap:GetChildren() }) do
        if enfant:GetObjectType() == "Button" then S.Ranger(enfant) end
    end
end)

-- L'horloge (Blizzard_TimeManager) arrive plus tard.
S.Ecouter("ADDON_LOADED", function(_, addon)
    if addon == "Blizzard_TimeManager" and TimeManagerClockButton then S.Ranger(TimeManagerClockButton) end
end)

------------------------------------------------------------------------
-- Bouton Menu : fenêtres du jeu, qui passaient par le micro-menu
------------------------------------------------------------------------
local menu = CreateFrame("Button", "SolUIMenu", colonne)
menu:SetSize(40, 40)
menu:SetPoint("TOP", Minimap, "BOTTOM", 0, -8)
menu:SetBackdrop({ bgFile = S.BLANC, edgeFile = S.BLANC, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
menu:SetBackdropColor(0.086, 0.09, 0.102, 0.88)
menu:SetBackdropBorderColor(0.2, 0.212, 0.235)
for i = -1, 1 do
    local trait = S.Texture(menu, "ARTWORK", nil, 0.843, 0.855, 0.871)
    trait:SetSize(16, 2)
    trait:SetPoint("CENTER", 0, i * 5)
end
menu:SetScript("OnEnter", function(self)
    self:SetBackdropBorderColor(S.Couleur("texte", 0.7))
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Menu")
end)
menu:SetScript("OnLeave", function(self)
    self:SetBackdropBorderColor(0.2, 0.212, 0.235)
    GameTooltip:Hide()
end)

local deroulant = CreateFrame("Frame", "SolUIMenuDeroulant", UIParent, "UIDropDownMenuTemplate")

local function Slash(commande)
    for nom, fonction in pairs(SlashCmdList) do
        for i = 1, 5 do
            local alias = _G["SLASH_" .. nom .. i]
            if not alias then break end
            if alias == commande then return fonction("") end
        end
    end
end

local ENTREES = {
    { "Personnage", function() ToggleCharacter("PaperDollFrame") end },
    { "Sacs", function() ToggleBackpack() end },
    { "Techniques et raccourcis", function() S.BasculerRaccourcis() end },
    { "Collection", function() S.BasculerCollection() end },
    { "Sorts", function() ToggleSpellBook(BOOKTYPE_SPELL) end },
    { "Quêtes", function() S.BasculerJournal() end },
    { "Carte", function() ToggleFrame(WorldMapFrame) end },
    { "Hauts faits", function() ToggleAchievementFrame() end },
    { "Social", function() ToggleFriendsFrame() end },
    { "Sol'Azeroth", function() Slash("/sol") end },
    { "Menu du jeu", function()
        if GameMenuFrame:IsShown() then HideUIPanel(GameMenuFrame) else ShowUIPanel(GameMenuFrame) end
    end },
}

local liste = {}
for _, entree in ipairs(ENTREES) do
    table.insert(liste, { text = entree[1], func = entree[2], notCheckable = true })
end

menu:SetScript("OnClick", function(self)
    EasyMenu(liste, deroulant, self, 0, 0, "MENU")
end)
