-- Bouton unique Sol'Azeroth autour de la minicarte (demande de l'utilisateur, en attendant l'unification de
-- l'interface, section 10.2). Il remplace les boutons des autres addons du projet, qui sont cachés, et ouvre un menu
-- vers toutes les fenêtres. Le menu appelle les commandes des addons (SlashCmdList) : les fenêtres ne changent pas.

local ENTREES = {
    { texte = "Apprentissage",               commande = "SOLAZEROTHFORMATION" },
    { texte = "Grimoire des autres classes", commande = "SOLAZEROTHGRIMOIRE" },
    { texte = "Talents d'une autre classe",  commande = "SOLAZEROTHTALENTS" },
    { texte = "Spécialisations",             commande = "SOLAZEROTHSPES" },
    { texte = "Contrats",                    commande = "SOLAZEROTHCONTRATS" },
    { texte = "Amélioration des objets",     commande = "SOLAZEROTHAMELIORER" },
    { texte = "Codex et Renom",              commande = "SOLAZEROTHCODEX" },
    { texte = "Journal de collection",       commande = "SOLAZEROTHJOURNAL" },
    { texte = "Hauts faits du compte",       commande = "SOLAZEROTHHAUTSFAITS" },
    { texte = "Rang de menace",              commande = "SOLAZEROTHMENACE" },
    { texte = "Défi en extérieur",           commande = "SOLAZEROTHEXTERIEUR" },
    { texte = "Défis du personnage",         commande = "SOLAZEROTHDEFIS" },
    { texte = "Sacs",                        commande = "SOLAZEROTHSACS" },
    { texte = "Choix de butin en attente",   commande = "SOLAZEROTHBUTIN" },
    { texte = "Plaques de nom",              commande = "SOLAZEROTHPLAQUES" },
}

-- Boutons de minicarte remplacés par celui-ci.
local ANCIENS = {
    "SolAzerothFormationBoutonMinicarte", "SolAzerothMenaceBoutonMinicarte", "SolAzerothDefisBoutonMinicarte",
    "SolAzerothSpesBoutonMinicarte", "SolAzerothContratsBoutonMinicarte",
}

local menu = CreateFrame("Frame", "SolAzerothMenuDeroulant", UIParent, "UIDropDownMenuTemplate")

local function Ouvrir(bouton)
    local liste = { { text = "Sol'Azeroth", isTitle = true, notCheckable = true } }
    for _, e in ipairs(ENTREES) do
        local fonction = SlashCmdList[e.commande]
        if fonction then
            liste[#liste + 1] = { text = e.texte, notCheckable = true, func = function() fonction("") end }
        end
    end
    liste[#liste + 1] = { text = "Fermer", notCheckable = true, func = function() CloseDropDownMenus() end }
    EasyMenu(liste, menu, bouton, 0, 0, "MENU")
end

------------------------------------------------------------------------
-- Bouton de la minicarte, déplaçable autour du bord (position mémorisée)
------------------------------------------------------------------------
local RAYON = 80

local bouton = CreateFrame("Button", "SolAzerothMenuBoutonMinicarte", Minimap)
bouton:SetSize(31, 31)
bouton:SetFrameStrata("MEDIUM")
bouton:SetFrameLevel(8)
bouton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
bouton:RegisterForDrag("LeftButton")
bouton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
local icone = bouton:CreateTexture(nil, "BACKGROUND")
icone:SetSize(20, 20)
icone:SetPoint("TOPLEFT", 7, -5)
icone:SetTexture("Interface\\Icons\\INV_Misc_Book_11")
icone:SetTexCoord(0.08, 0.92, 0.08, 0.92)
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
    SolAzerothMenuDB.angle = angle
    Placer(angle)
end

bouton:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", SuivreCurseur) end)
bouton:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
-- Clic gauche : fenêtre Sol'Azeroth (V7) ; clic droit : l'ancien menu, pour aller vite.
bouton:SetScript("OnClick", function(self, clic)
    if clic == "RightButton" or not SlashCmdList.SOLAZEROTH then Ouvrir(self) else SlashCmdList.SOLAZEROTH("") end
end)
bouton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Sol'Azeroth", 1, 0.82, 0)
    GameTooltip:AddLine("Clic : fenêtre Sol'Azeroth (/sol)", 1, 1, 1)
    GameTooltip:AddLine("Clic droit : menu de toutes les fenêtres", 1, 1, 1)
    GameTooltip:AddLine("Glisser : déplacer le bouton", 1, 1, 1)
    GameTooltip:Show()
end)
bouton:SetScript("OnLeave", function() GameTooltip:Hide() end)

local evenements = CreateFrame("Frame")
evenements:RegisterEvent("ADDON_LOADED")
evenements:RegisterEvent("PLAYER_LOGIN")
evenements:SetScript("OnEvent", function(self, event, nom)
    if event == "ADDON_LOADED" then
        if nom ~= "SolAzerothMenu" then return end
        SolAzerothMenuDB = SolAzerothMenuDB or { angle = 135 }
        Placer(SolAzerothMenuDB.angle)
        return
    end
    -- Tous les addons sont chargés : on cache les anciens boutons, pour de bon.
    for _, nomBouton in ipairs(ANCIENS) do
        local ancien = _G[nomBouton]
        if ancien then
            ancien:Hide()
            ancien:SetScript("OnShow", ancien.Hide)
        end
    end
end)
