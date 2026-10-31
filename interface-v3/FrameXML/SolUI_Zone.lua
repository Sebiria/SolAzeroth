-- Sol'Azeroth v3, F4 : la zone (maquette Arène, reprise dans Synthèse), en haut à droite.
-- Nom de la zone, puissance conseillée (calculée par le serveur d'après ses monstres), sous-zone et, depuis F5e,
-- pourcentage de la zone (les reliques viendront ensuite). Puis la mini-carte ronde et le bouton Menu, qui remplace
-- le micro-menu de Blizzard.

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
sousZone:SetPoint("RIGHT", suivi, "RIGHT", -64, 0)
sousZone:SetJustifyH("LEFT")

-- F5e (31/10/2026) : pourcentage de la zone (v3_zone.cpp), une jauge au pied du cadre ; survol : le détail.
local pourcent = S.Texte(suivi, "Bold", 13, "ambreClair")
pourcent:SetPoint("BOTTOMRIGHT", suivi, "BOTTOMRIGHT", -14, 12)
local jauge = S.Texture(suivi, "ARTWORK", nil, S.Couleur("creux"))
jauge:SetPoint("BOTTOMLEFT", suivi, "BOTTOMLEFT", 14, 6)
jauge:SetPoint("BOTTOMRIGHT", suivi, "BOTTOMRIGHT", -14, 6)
jauge:SetHeight(2)
local plein = S.Texture(suivi, "OVERLAY", nil, S.Couleur("ambre"))
plein:SetPoint("TOPLEFT", jauge)
plein:SetPoint("BOTTOMLEFT", jauge)

local progres, recu = nil, nil
local function Pour(c) return (string.format("%.2f", c / 100):gsub("%.?0+$", ""):gsub("%.", ",")) .. " %" end

local function MajPourcent()
    S.Montrer(pourcent, progres)
    S.Montrer(jauge, progres)
    S.Montrer(plein, progres and progres.total > 0)
    if not progres then return end
    pourcent:SetText(Pour(progres.total))
    plein:SetWidth(math.max(1, jauge:GetWidth() * math.min(1, progres.total / 10000)))
end

S.Message("SOLZONE", function(champs)
    local genre = champs[1]
    -- Chef renforcé apparu (v3_zone.cpp) : alerte de raid avec son bruit, comme une annonce de raid.
    if genre == "ALERTE" then
        RaidNotice_AddMessage(RaidWarningFrame, champs[2] or "", ChatTypeInfo["RAID_WARNING"])
        PlaySound("RaidWarning")
        return
    end
    if genre == "POURCENT" then
        if tonumber(champs[2]) < 0 then progres, recu = nil, nil; MajPourcent(); return end
        recu = { total = tonumber(champs[2]), histoire = tonumber(champs[3]), exploration = tonumber(champs[4]),
            annexes = tonumber(champs[5]), lieux = {} }
    elseif not recu then
        return
    elseif genre == "EXPLO" then
        recu.explorees, recu.sousZones = tonumber(champs[2]), tonumber(champs[3])
    elseif genre == "LIEU" then
        table.insert(recu.lieux, { nom = champs[3], tues = tonumber(champs[4]), requis = tonumber(champs[5]),
            part = tonumber(champs[6]), fait = champs[7] == "1" })
    elseif genre == "FINZONE" then
        progres = recu
        MajPourcent()
    end
end)

suivi:EnableMouse(true)
suivi:SetScript("OnEnter", function(self)
    if not progres then return end
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
    GameTooltip:AddDoubleLine(GetZoneText() or "", Pour(progres.total), 1, 0.82, 0, 1, 0.82, 0)
    GameTooltip:AddDoubleLine("Histoire", Pour(progres.histoire) .. " / 50 %", 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine(string.format("Exploration (%d / %d)", progres.explorees or 0, progres.sousZones or 0),
        Pour(progres.exploration) .. " / 6 %", 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("Annexes", Pour(progres.annexes) .. " / 44 %", 1, 1, 1, 1, 1, 1)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Lieux à nettoyer", 1, 0.82, 0)
    for _, l in ipairs(progres.lieux) do
        local fait = l.fait
        local r, g, b = 0.75, 0.75, 0.75
        if fait then r, g, b = 0.4, 1, 0.4 end
        GameTooltip:AddDoubleLine(l.nom, fait and ("nettoyé, " .. Pour(l.part)) or string.format("%d / %d", l.tues, l.requis),
            r, g, b, r, g, b)
    end
    GameTooltip:Show()
end)
suivi:SetScript("OnLeave", function() GameTooltip:Hide() end)
MajPourcent()

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
