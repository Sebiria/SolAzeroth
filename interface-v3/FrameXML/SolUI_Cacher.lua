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
    MultiCastActionBarFrame,  -- totems du chaman (01/11/2026, demande de l'utilisateur, avec les postures)
    BuffFrame, TemporaryEnchantFrame,  -- pastilles sous la vie
}

for _, cadre in ipairs(REMPLACES) do
    S.Ranger(cadre)
end

-- Grimoire et macros du jeu : inaccessibles à la demande de l'utilisateur (01/11/2026) ; les techniques et leurs
-- raccourcis les remplacent. Grimoire rangé et refermé s'il s'ouvre (touche, commandes) ; macros : la fenêtre ne se
-- charge plus (/macro, menu du jeu) et le bouton Macros du menu du jeu disparaît.
-- Comparaison d'équipement : seulement en tenant Maj, elle disparaît au relâchement (01/11/2026, demande de
-- l'utilisateur). Les cases d'objet du jeu la réévaluent à chaque image tant que l'infobulle est la leur.
SetCVar("alwaysCompareItems", "0")
S.Ecouter("VARIABLES_LOADED", function() SetCVar("alwaysCompareItems", "0") end)
S.Ranger(SpellBookFrame)
SpellBookFrame:HookScript("OnShow", function(self) HideUIPanel(self) end)
function ShowMacroFrame() end
if GameMenuButtonMacros then
    -- Le bouton suivant prend sa place, et le menu raccourcit d'autant.
    local _, relatif, pointRelatif, _, y = GameMenuButtonMacros:GetPoint(1)
    for _, bouton in ipairs({ GameMenuFrame:GetChildren() }) do
        local p, r, _, bx, by = bouton:GetPoint(1)
        if r == GameMenuButtonMacros then
            bouton:ClearAllPoints()
            bouton:SetPoint(p, relatif, pointRelatif, bx, by)
        end
    end
    GameMenuButtonMacros:Hide()
    GameMenuFrame:SetHeight(GameMenuFrame:GetHeight() - GameMenuButtonMacros:GetHeight() + (y or 0))
end

-- Social (amis, qui, raid) : inaccessible à la demande de l'utilisateur (01/11/2026, « le social ne sert à rien »).
-- Rangé, et refermé aussitôt s'il s'ouvre (touche O, commandes) pour ne pas réserver de place aux fenêtres.
S.Ranger(FriendsFrame)
FriendsFrame:HookScript("OnShow", function(self) HideUIPanel(self) end)

-- Ces cadres se replacent d'eux-mêmes (UIParent_ManageFramePositions) : rangés, ils restent invisibles.

-- Messages d'erreur rouges au centre de l'écran (« pas encore disponible », « hors de portée »…) : coupés à la
-- demande de l'utilisateur. Les messages jaunes (quêtes, captures d'écran) restent.
UIErrorsFrame:UnregisterEvent("UI_ERROR_MESSAGE")
