-- Sol'Azeroth v3 : barre d'icônes (demande de l'utilisateur du 01/11/2026 : « à la manière du HUD de base, une barre
-- d'icônes qui mène aux différentes fonctions, petite mais explicite »). Elle remplace le micro-menu de Blizzard, en
-- bas à droite ; c'est un bloc comme les autres (mode édition : déplacer, molette pour la taille). Survol : le nom.
-- Le bouton Menu de la mini-carte reste (SolUI_Zone.lua).

local S = SolUI

local TAILLE, ECART = 26, 3

local function Slash(commande)
    for nom, fonction in pairs(SlashCmdList) do
        for i = 1, 5 do
            local alias = _G["SLASH_" .. nom .. i]
            if not alias then break end
            if alias == commande then return fonction("") end
        end
    end
end

-- { nom, icône du client, action }
local ENTREES = {
    { "Personnage", "INV_Helmet_04", function() ToggleCharacter("PaperDollFrame") end },
    { "Sacs", "INV_Misc_Bag_08", function() ToggleBackpack() end },
    { "Équipement : fabriquer, améliorer, joaillerie", "Trade_BlackSmithing", function() S.BasculerEquipement() end },
    { "Collection", "INV_Crate_04", function() S.BasculerCollection() end },
    { "Techniques et raccourcis", "Ability_Warrior_DefensiveStance", function() S.BasculerRaccourcis() end },
    { "Sorts", "INV_Misc_Book_09", function() ToggleSpellBook(BOOKTYPE_SPELL) end },
    { "Quêtes", "INV_Scroll_03", function() S.BasculerJournal() end },
    { "Objectifs de la zone", "INV_Misc_Map_01", function() S.BasculerObjectifs() end },
    { "Carte du monde", "INV_Misc_Map02", function() ToggleFrame(WorldMapFrame) end },
    { "Hauts faits", "Achievement_General", function() ToggleAchievementFrame() end },
    { "Rang d'aventurier et montures", "Ability_Mount_RidingHorse", function() S.BasculerAventurier() end },
    { "Social", "INV_Misc_GroupNeedMore", function() ToggleFriendsFrame() end },
    { "Sol'Azeroth", "INV_Enchant_ShardBrilliantLarge", function() Slash("/sol") end },
    { "Menu du jeu", "INV_Misc_Gear_01", function()
        if GameMenuFrame:IsShown() then HideUIPanel(GameMenuFrame) else ShowUIPanel(GameMenuFrame) end
    end },
}

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
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

S.Placer(barre, "barre")
