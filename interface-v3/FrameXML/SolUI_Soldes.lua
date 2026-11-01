-- Sol'Azeroth v3 (01/11/2026, demande de l'utilisateur) : Marques du voyageur, Éclats cadavériques et or dans le HUD.
-- Petit bloc au-dessus de la barre d'icônes (mode édition : déplacer, molette pour la taille). Marques : dans les
-- sacs ; éclats : Collection du serveur et sacs (S.NombreCollection, SolUI_Collection.lua) ; or : pièces du jeu.

local S = SolUI

local MARQUE, ECLAT = 37711, 910120
local function Or()
    local cuivre = GetMoney()
    return cuivre > 0 and S.Argent(cuivre) or "0 |TInterface\\MoneyFrame\\UI-CopperIcon:0:0:0:-1|t"
end
local SOLDES = {
    { id = MARQUE, nom = "Marques du voyageur", fichier = "Interface\\Icons\\INV_Misc_Token_ArgentDawn3",
        valeur = function() return S.Nombre(GetItemCount(MARQUE, true) or 0) end },
    { id = ECLAT, nom = "Éclats cadavériques", fichier = "Interface\\Icons\\INV_Misc_Bone_HumanSkull_01",
        valeur = function() return S.Nombre(S.NombreCollection(ECLAT)) end },
    { nom = "Or", valeur = Or },   -- les icônes des pièces sont dans le texte
}

local bloc = CreateFrame("Frame", "SolUISoldes", S.racine)
bloc:SetHeight(30)
S.Panneau(bloc, 0.85)
bloc:EnableMouse(true)

for _, s in ipairs(SOLDES) do
    if s.id then
        s.icone = bloc:CreateTexture(nil, "ARTWORK")
        s.icone:SetSize(18, 18)
        s.icone:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    s.texte = S.Texte(bloc, "SemiBold", 13, "clair")
end

local function Maj()
    local x = 8
    for _, s in ipairs(SOLDES) do
        s.texte:ClearAllPoints()
        if s.icone then
            s.icone:SetTexture(GetItemIcon(s.id) or s.fichier)
            s.icone:SetPoint("LEFT", bloc, "LEFT", x, 0)
            x = x + 18 + 6
        end
        s.texte:SetPoint("LEFT", bloc, "LEFT", x, 0)
        s.texte:SetText(s.valeur())
        x = x + s.texte:GetStringWidth() + 14
    end
    bloc:SetWidth(x - 6)
end

bloc:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    for _, s in ipairs(SOLDES) do
        GameTooltip:AddDoubleLine(s.nom, s.valeur(), 0.91, 0.914, 0.922, 0.965, 0.761, 0.478)
    end
    GameTooltip:Show()
end)
bloc:SetScript("OnLeave", function() GameTooltip:Hide() end)

S.Message("SOLCOL", Maj)
for _, e in ipairs({ "BAG_UPDATE", "PLAYER_MONEY", "PLAYER_ENTERING_WORLD" }) do S.Ecouter(e, Maj) end
Maj()

S.Placer(bloc, "soldes")
