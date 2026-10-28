-- Écart d'équipement (section 5, V5). Le serveur (ecart.cpp, préfixe SOLECART) envoie, chaque fois que la valeur change :
-- "ECART;écart;effet_infligé;effet_subis;ilvl_joueur;ilvl_attendu" face au monstre ciblé ou combattu (en %),
-- ou "ECART" seul quand il n'y a pas de monstre. Le cadre n'apparaît qu'en dehors de la zone neutre.
-- Déplaçable à la souris ; position mémorisée par personnage.

local PREFIXE = "SOLECART"

local cadre = CreateFrame("Frame", "SolAzerothEcartCadre", UIParent)
cadre:SetSize(170, 36)
cadre:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -200, -210)
cadre:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                    edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
cadre:SetBackdropColor(0, 0, 0, 0.7)
cadre:EnableMouse(true)
cadre:SetMovable(true)
cadre:RegisterForDrag("LeftButton")
cadre:Hide()

local icone = cadre:CreateTexture(nil, "ARTWORK")
icone:SetSize(26, 26)
icone:SetPoint("LEFT", 5, 0)

local texte = cadre:CreateFontString(nil, "OVERLAY", "GameFontNormal")
texte:SetPoint("LEFT", icone, "RIGHT", 6, 0)
texte:SetJustifyH("LEFT")

local valeurs

cadre:SetScript("OnDragStart", cadre.StartMoving)
cadre:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relatif, x, y = self:GetPoint()
    SolAzerothEcartDB = { point = point, relatif = relatif, x = x, y = y }
end)

cadre:SetScript("OnEnter", function(self)
    if not valeurs then return end
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
    GameTooltip:AddLine("Écart d'équipement")
    GameTooltip:AddLine(string.format("Ton niveau d'objet moyen : %d   Attendu face à ce monstre : %d", valeurs.ilvl, valeurs.attendu), 1, 1, 1)
    GameTooltip:AddLine(string.format("Écart : %+d %%", valeurs.ecart), 1, 1, 1)
    if valeurs.inflige < 0 then
        GameTooltip:AddLine(string.format("Tes dégâts et soins : %d %%", valeurs.inflige), 1, 0.3, 0.3)
        GameTooltip:AddLine(string.format("Dégâts que tu subis : +%d %%", valeurs.subis), 1, 0.3, 0.3)
        GameTooltip:AddLine("Améliore ton équipement pour faire disparaître ce malus.", 0.8, 0.8, 0.8, true)
    else
        GameTooltip:AddLine(string.format("Tes dégâts et soins : +%d %%", valeurs.inflige), 0.3, 1, 0.3)
    end
    GameTooltip:AddLine("Les objets de rang de menace comptent plus. En donjon, l'attendu monte avec le rang.", 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
end)
cadre:SetScript("OnLeave", function() GameTooltip:Hide() end)

local evenements = CreateFrame("Frame")
evenements:RegisterEvent("CHAT_MSG_ADDON")
evenements:RegisterEvent("PLAYER_LOGIN")
evenements:SetScript("OnEvent", function(self, event, prefixe, message)
    if event == "PLAYER_LOGIN" then
        local p = SolAzerothEcartDB
        if p and p.point then
            cadre:ClearAllPoints()
            cadre:SetPoint(p.point, UIParent, p.relatif or p.point, p.x, p.y)
        end
        return
    end
    if prefixe ~= PREFIXE then return end
    local champs = { strsplit(";", message) }
    local inflige = tonumber(champs[3]) or 0
    if champs[1] ~= "ECART" or inflige == 0 then
        valeurs = nil
        cadre:Hide()
        if GameTooltip:IsOwned(cadre) then GameTooltip:Hide() end
        return
    end
    valeurs = { ecart = tonumber(champs[2]) or 0, inflige = inflige, subis = tonumber(champs[4]) or 0,
                ilvl = tonumber(champs[5]) or 0, attendu = tonumber(champs[6]) or 0 }
    if inflige < 0 then
        icone:SetTexture("Interface\\Icons\\Ability_Warrior_Sunder")
        texte:SetText(string.format("|cffff4040Sous-équipé %d %%|r", inflige))
        cadre:SetBackdropBorderColor(1, 0.25, 0.25)
    else
        icone:SetTexture("Interface\\Icons\\Ability_Warrior_BattleShout")
        texte:SetText(string.format("|cff40ff40Bien équipé +%d %%|r", inflige))
        cadre:SetBackdropBorderColor(0.25, 1, 0.25)
    end
    cadre:Show()
end)
