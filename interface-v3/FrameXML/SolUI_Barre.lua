-- Sol'Azeroth v3 : barre d'icônes (demande de l'utilisateur du 01/11/2026 : « à la manière du HUD de base, une barre
-- d'icônes qui mène aux différentes fonctions, petite mais explicite »). Elle remplace le micro-menu de Blizzard, en
-- bas à droite ; c'est un bloc comme les autres (mode édition : déplacer, molette pour la taille). Survol : le nom.
-- Le bouton Menu de la mini-carte reste (SolUI_Zone.lua).

local S = SolUI

local TAILLE, ECART = 26, 3

-- { nom, icône du client, action, touche } : les six carnets (SolUI_Carnets.lua), la carte, puis le menu du jeu
-- (01/11/2026, « Accès aux fonctionnalités — proposition.md » : le Social est retiré à la demande de l'utilisateur).
local ENTREES = {}
for _, c in ipairs(S.CARNETS) do
    table.insert(ENTREES, { c.nom, c.icone, function() S.BasculerCarnet(c.id) end, function() return S.ToucheCarnet(c) end })
end
table.insert(ENTREES, { "Carte", "INV_Misc_Map02", function() ToggleFrame(WorldMapFrame) end,
    function() local t = GetBindingKey("TOGGLEWORLDMAP"); return t and S.ToucheCourte(t) end })
local deroulant = CreateFrame("Frame", "SolUIBarreMenu", UIParent, "UIDropDownMenuTemplate")
local menuJeu = {}
for _, e in ipairs(S.MENU_JEU) do table.insert(menuJeu, { text = e[1], func = e[2], notCheckable = true }) end
table.insert(ENTREES, { "Menu : sorts, hauts faits, réglages", "INV_Misc_Gear_01", function(self)
    EasyMenu(menuJeu, deroulant, self, 0, 0, "MENU")
end })

local barre = CreateFrame("Frame", "SolUIBarre", S.racine)
barre:SetSize(#ENTREES * (TAILLE + ECART) - ECART + 12, TAILLE + 12)
S.Panneau(barre, 0.85)

for n, entree in ipairs(ENTREES) do
    local b = CreateFrame("Button", nil, barre)
    b:SetSize(TAILLE, TAILLE)
    b:SetPoint("LEFT", barre, "LEFT", 6 + (n - 1) * (TAILLE + ECART), 0)
    local icone = b:CreateTexture(nil, "ARTWORK")
    icone:SetAllPoints()
    icone:SetTexture("Interface\\Icons\\" .. entree[2])
    icone:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local survol = b:CreateTexture(nil, "HIGHLIGHT")
    survol:SetAllPoints()
    survol:SetTexture(S.BLANC)
    survol:SetVertexColor(1, 1, 1, 0.18)
    b:SetScript("OnClick", entree[3])
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(entree[1])
        local touche = entree[4] and entree[4]()
        if touche then GameTooltip:AddLine("Touche " .. touche, 0.706, 0.722, 0.749) end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

S.Placer(barre, "barre")
