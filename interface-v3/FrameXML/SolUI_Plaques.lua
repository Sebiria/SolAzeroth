-- Sol'Azeroth v3 (01/11/2026, signalement de l'utilisateur) : plaques de nom des monstres. Le niveau (80 pour tous,
-- niveau caché) disparaît ; à sa place, la puissance du monstre, colorée comme le cadre de la cible.
-- Une plaque du jeu ne dit pas de quel monstre elle est : la puissance se retrouve par le nom, parmi les monstres à
-- moins de 60 m (SOLPUISSANCE « PROCHES », SolUI_Base.lua). Des monstres du même nom à des puissances différentes
-- montrent l'écart (« 5–6 »), sauf la cible : sa plaque, la seule pleinement opaque, prend la puissance de la cible.

local S = SolUI

local plaques = {}
local enfants = 0
local parNom, nomsAJour = {}, false

local function EstPlaque(f)
    if f:GetName() or plaques[f] then return false end
    local _, bord = f:GetRegions()
    return bord and bord.GetTexture and bord:GetTexture() == "Interface\\Tooltips\\Nameplate-Border"
end

local function Prendre(f)
    local regions = { f:GetRegions() }
    local nom, niveau = regions[7], regions[8]
    if not nom or not niveau then return end
    local texte = S.Texte(f, "Bold", 11, "texte")
    texte:SetPoint("CENTER", niveau, "CENTER")
    plaques[f] = { nom = nom, niveau = niveau, texte = texte }
end

-- Nom -> puissances basse et haute des monstres proches.
local function Noms()
    wipe(parNom)
    for guid, nom in pairs(S.nomsProches) do
        local p = S.puissancesProches[guid]
        local e = parNom[nom]
        if p then
            if not e then parNom[nom] = { p, p } else e[1], e[2] = math.min(e[1], p), math.max(e[2], p) end
        end
    end
    nomsAJour = true
end
S.Abonner("proches", function() nomsAJour = false end)

local function Habiller(f, p)
    p.niveau:SetAlpha(0)
    local nom = p.nom:GetText()
    local bas, haut
    if UnitExists("target") and f:GetAlpha() > 0.99 and nom == UnitName("target") and S.etat.ciblePuissance then
        bas = S.etat.ciblePuissance
        haut = bas
    elseif nom and parNom[nom] then
        bas, haut = parNom[nom][1], parNom[nom][2]
    end
    if not bas then
        p.texte:SetText("")
        return
    end
    p.texte:SetText(bas == haut and tostring(bas) or (bas .. "–" .. haut))
    p.texte:SetTextColor(S.CouleurDifficulte((bas + haut) / 2 - (S.etat.puissance or 0)))
end

local attente = 0
local veille = CreateFrame("Frame")
veille:SetScript("OnUpdate", function(_, ecoule)
    attente = attente - ecoule
    if attente > 0 then return end
    attente = 0.1
    local n = WorldFrame:GetNumChildren()
    if n ~= enfants then
        enfants = n
        for _, f in ipairs({ WorldFrame:GetChildren() }) do
            if EstPlaque(f) then Prendre(f) end
        end
    end
    if not nomsAJour then Noms() end
    for f, p in pairs(plaques) do
        if f:IsShown() then Habiller(f, p) end
    end
end)
