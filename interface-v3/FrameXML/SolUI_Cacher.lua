-- Sol'Azeroth v3, F4 : cadres de Blizzard remplacés par l'écran de combat, rangés sous un cadre caché.
-- Ils restent chargés : leurs raccourcis et leurs événements marchent toujours. En particulier, les touches de la barre
-- d'action 1 (ACTIONBUTTON1 à 8, menu Raccourcis du jeu) passent par ActionButton1 à 8, que nos techniques reflètent
-- (SolUI_Techniques.lua).

local S = SolUI

local cache = CreateFrame("Frame", "SolUICache", UIParent)
cache:Hide()
S.cache = cache

function S.Ranger(cadre)
    if cadre then cadre:SetParent(cache) end
end

local REMPLACES = {
    PlayerFrame,              -- vie et Rempart : arcs autour du personnage
    TargetFrame, ComboFrame,  -- cadre de la cible en haut au centre
    FocusFrame,
    MainMenuBar,              -- barres d'action, expérience, sacs et micro-menu : deux barres de 4 et bouton Menu
    MultiBarBottomLeft, MultiBarBottomRight, MultiBarLeft, MultiBarRight,
    ShapeshiftBarFrame, PossessBarFrame, PetActionBarFrame,
    BuffFrame, TemporaryEnchantFrame,  -- pastilles sous la vie
}

for _, cadre in ipairs(REMPLACES) do
    S.Ranger(cadre)
end

-- Ces cadres se replacent d'eux-mêmes (UIParent_ManageFramePositions) : rangés, ils restent invisibles.
