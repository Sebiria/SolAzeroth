-- Sol'Azeroth v3 (01/11/2026, demande de l'utilisateur) : rang d'aventurier et boutique des montures
-- (v3_aventurier.cpp, préfixe SOLAVENT ; paliers et montures : SolUI_AventurierDonnees.lua, généré par
-- outils\montures_v3.py). Deux pages : les 40 paliers et leurs récompenses ; la boutique, ouverte au palier 10, où
-- chaque vitesse s'ouvre avec son palier et s'achète en Marques du voyageur.

local S = SolUI

local MARQUE = 37711
local LIGNES, HAUTEUR = 13, 36

local f = S.Fenetre("SolUIAventurier", 820, 640, "Rang d'aventurier")
function S.BasculerAventurier()
    if f:IsShown() then f:Hide() else f:Show() end
end

local etat = { points = 0, palier = 0, possede = {} }
local page, decalage = 1, 0
local Maj

local resume = S.Texte(f, "SemiBold", 14, "clair")
resume:SetPoint("TOPLEFT", f, "TOPLEFT", 28, -66)
local suivant = S.Texte(f, "Regular", 12, "gris")
suivant:SetPoint("TOPLEFT", resume, "BOTTOMLEFT", 0, -6)
local fond = S.Texture(f, "ARTWORK", nil, S.Couleur("creux"))
fond:SetPoint("TOPLEFT", suivant, "BOTTOMLEFT", 0, -8)
fond:SetSize(764, 8)
local barre = S.Texture(f, "OVERLAY", nil, S.Couleur("ambre"))
barre:SetPoint("TOPLEFT", fond, "TOPLEFT")
barre:SetHeight(8)
local marques = S.Texte(f, "SemiBold", 13, "ambreClair")
marques:SetPoint("TOPRIGHT", f, "TOPRIGHT", -28, -66)

local onglets = {}
for n, nom in ipairs({ "Paliers", "Montures" }) do
    local b = S.BoutonPlat(f, nom, 140, 30, 12)
    b:SetPoint("TOPLEFT", f, "TOPLEFT", 28 + (n - 1) * 148, -130)
    b:SetScript("OnClick", function() page, decalage = n, 0; Maj() end)
    b:Hide()   -- carnet Aventure (SolUI_Carnets.lua)
    onglets[n] = b
end

-- Lignes : icône, nom, détail, et (boutique) bouton d'achat.
local lignes = {}
for i = 1, LIGNES do
    local l = CreateFrame("Frame", nil, f)
    l:SetSize(764, HAUTEUR - 4)
    l:SetPoint("TOPLEFT", f, "TOPLEFT", 28, -130 - (i - 1) * HAUTEUR)
    l:EnableMouseWheel(true)
    l:SetScript("OnMouseWheel", function(_, sens) decalage = math.max(0, decalage - sens); Maj() end)
    l.icone = l:CreateTexture(nil, "ARTWORK")
    l.icone:SetSize(28, 28)
    l.icone:SetPoint("LEFT", 2, 0)
    l.icone:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    l.nom = S.Texte(l, "SemiBold", 13, "texte")
    l.nom:SetPoint("LEFT", 40, 0)
    l.detail = S.Texte(l, "Regular", 12, "gris")
    l.detail:SetPoint("RIGHT", -130, 0)
    l.bouton = S.BoutonPlat(l, "Acheter", 110, 26, 11)
    l.bouton:SetPoint("RIGHT", 0, 0)
    lignes[i] = l
end

local function MajPaliers()
    local total = #S.PALIERS
    decalage = math.min(decalage, math.max(0, total - LIGNES))
    for i, l in ipairs(lignes) do
        local n = decalage + i
        local p = S.PALIERS[n]
        S.Montrer(l, p ~= nil)
        if p then
            local atteint = n <= etat.palier
            l.icone:SetTexture("Interface\\Icons\\" .. (atteint and "Achievement_General" or "INV_Misc_QuestionMark"))
            l.icone:SetDesaturated(not atteint)
            l.nom:SetText("Palier " .. n .. (p[2] ~= "" and ("  —  " .. p[2]) or ""))
            l.nom:SetTextColor(S.Couleur(atteint and "vertClair" or n == etat.palier + 1 and "ambreClair" or "gris"))
            l.detail:SetText(S.Nombre(p[1]) .. " points")
            S.Montrer(l.bouton, false)
        end
    end
end

local function MajMontures()
    local total = #S.MONTURES
    decalage = math.min(decalage, math.max(0, total - LIGNES))
    local avoir = GetItemCount(MARQUE, true)
    for i, l in ipairs(lignes) do
        local m = S.MONTURES[decalage + i]
        S.Montrer(l, m ~= nil)
        if m then
            local sort, nom, vitesse, prix = m[1], m[2], m[3], m[4]
            local _, _, icone = GetSpellInfo(sort)
            local ouvert = etat.palier >= (S.VITESSES_PALIER[vitesse] or 99)
            local possede = etat.possede[sort]
            l.icone:SetTexture(icone or "Interface\\Icons\\INV_Misc_QuestionMark")
            l.icone:SetDesaturated(not ouvert and not possede)
            l.nom:SetText(nom .. "  |cffb4b8bf" .. vitesse .. " %|r")
            l.nom:SetTextColor(S.Couleur(possede and "vertClair" or ouvert and "texte" or "gris"))
            if possede then
                l.detail:SetText("Possédée")
            elseif ouvert then
                l.detail:SetText((avoir >= prix and "" or "|cfff0918a") .. prix .. " Marques|r")
            else
                l.detail:SetText("Palier " .. S.VITESSES_PALIER[vitesse] .. "  ·  " .. prix .. " Marques")
            end
            S.Montrer(l.bouton, ouvert and not possede)
            l.bouton:SetAlpha(avoir >= prix and 1 or 0.5)
            l.bouton:SetScript("OnClick", function() SendChatMessage(".monture acheter " .. sort, "SAY") end)
        end
    end
end

function Maj()
    local p = S.PALIERS[etat.palier + 1]
    resume:SetText("Palier " .. etat.palier .. " / " .. #S.PALIERS .. "   ·   " .. S.Nombre(etat.points) .. " points")
    local bas = S.PALIERS[etat.palier] and S.PALIERS[etat.palier][1] or 0
    if p then
        suivant:SetText("Palier suivant à " .. S.Nombre(p[1]) .. " points : " .. p[2])
        barre:SetWidth(math.max(1, 764 * (etat.points - bas) / math.max(1, p[1] - bas)))
    else
        suivant:SetText("Dernier palier atteint.")
        barre:SetWidth(764)
    end
    marques:SetText(GetItemCount(MARQUE, true) .. " Marques du voyageur")
    for n, b in ipairs(onglets) do b:Choisir(n == page) end
    if page == 2 and etat.palier < (S.VITESSES_PALIER[60] or 10) then
        for _, l in ipairs(lignes) do S.Montrer(l, false) end
        suivant:SetText("La boutique des montures s'ouvre au palier " .. S.VITESSES_PALIER[60] .. ".")
        return
    end
    if page == 1 then MajPaliers() else MajMontures() end
end

f:SetScript("OnShow", function() Maj() end)

function S.PageAventurier(n)
    page, decalage = n, 0
    if f:IsShown() then Maj() end
end
S.Ecouter("BAG_UPDATE", function() if f:IsShown() then Maj() end end)

local recu = { points = 0, palier = 0, possede = {} }
S.Message("SOLAVENT", function(champs)
    if champs[1] == "RANG" then
        recu = { points = tonumber(champs[2]) or 0, palier = tonumber(champs[3]) or 0, possede = {} }
    elseif champs[1] == "POSSEDE" then
        for sort in string.gmatch(champs[2] or "", "%d+") do recu.possede[tonumber(sort)] = true end
    elseif champs[1] == "FIN" then
        etat = recu
        if f:IsShown() then Maj() end
    elseif champs[1] == "PALIER" then
        local n = tonumber(champs[2])
        local p = n and S.PALIERS[n]
        if p then
            RaidNotice_AddMessage(RaidWarningFrame, "Rang d'aventurier : palier " .. n
                .. (p[2] ~= "" and (" — " .. p[2]) or ""), ChatTypeInfo["RAID_WARNING"])
            PlaySound("LevelUp")
        end
    end
end)
