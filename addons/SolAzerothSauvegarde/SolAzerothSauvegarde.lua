-- Bouton "Sauvegarder" sous "Retour au jeu" dans le menu Echap.
-- Il envoie la commande .sauvegarder, traitée par le script ALE sauvegarde.lua.

local HAUTEUR_AJOUTEE = 26

local bouton = CreateFrame("Button", "SolAzerothBoutonSauvegarder", GameMenuFrame, "GameMenuButtonTemplate")
bouton:SetText("Sauvegarder")
bouton:SetPoint("TOP", GameMenuButtonContinue, "BOTTOM", 0, -6)
bouton:SetScript("OnClick", function()
    PlaySound("igMainMenuOption")
    HideUIPanel(GameMenuFrame)
    SendChatMessage(".sauvegarder", "SAY")
end)

-- Agrandit le menu pour faire de la place au bouton, à chaque ouverture.
local hauteurAjustee
GameMenuFrame:HookScript("OnShow", function(self)
    if self:GetHeight() ~= hauteurAjustee then
        hauteurAjustee = self:GetHeight() + HAUTEUR_AJOUTEE
        self:SetHeight(hauteurAjustee)
    end
end)
