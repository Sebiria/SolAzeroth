-- Sol'Azeroth v3 (01/11/2026, demande de l'utilisateur) : rang d'aventurier et boutique des montures
-- (v3_aventurier.cpp, préfixe SOLAVENT ; paliers et montures : SolUI_AventurierDonnees.lua, généré par
-- outils\montures_v3.py). Deux pages : les 40 paliers et leurs récompenses ; la boutique, ouverte au palier 10, où
-- chaque vitesse s'ouvre avec son palier et s'achète en Marques du voyageur.
-- Audit du jeu, lot 5 (02/11/2026) : compteur et filtre des montures ; troisième page, le registre : points et
-- objectifs par source (« SOURCES »), difficulté réussie par donjon (« DONJONS »), maîtrise des modes de zone
-- (« MAITRISE »).

local S = SolUI

local MARQUE = 37711
local LIGNES, HAUTEUR = 13, 36

local f = S.Fenetre("SolUIAventurier", 820, 640, "Rang d'aventurier")
function S.BasculerAventurier()
    if f:IsShown() then f:Hide() else f:Show() end
end

local etat = { points = 0, palier = 0, possede = {}, sources = {}, donjons = {}, maitrise = {} }
local page = 1
local defil   -- lot 6c : S.Liste sur les lignes
local filtre = 1
local FILTRES = { "Toutes", "Ouvertes", "Possédées", "À acheter" }
-- Sources de points (genres de v3_aventurier.cpp).
local SOURCES = { [1] = "Quêtes d'histoire", [2] = "Sous-zones explorées", [3] = "Lieux nettoyés", [4] = "Quêtes annexes",
    [5] = "Reliques", [6] = "Médailles d'or", [7] = "Donjons terminés", [8] = "Zones à 60 %", [9] = "Zones à 100 %",
    [11] = "Difficultés de donjon réussies", [12] = "Objectifs de la semaine", [13] = "Zones maîtrisées en difficile",
    [14] = "Zones maîtrisées en cauchemar", [15] = "Objectifs d'artisan" }
-- Lot T10 des Tarides : registre des zones et des donjons lu dans SolUI_Zones.lua (outils\zones_interface.py).
local NOMS_ZONES = {}
for _, z in ipairs(S.ZONES) do NOMS_ZONES[z.id] = z.nom end
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
    b:SetScript("OnClick", function() page = n; defil:Remonter(); Maj() end)
    b:Hide()   -- carnet Aventure (SolUI_Carnets.lua)
    onglets[n] = b
end

-- Lignes : icône, nom, détail, et (boutique) bouton d'achat.
local lignes = {}
for i = 1, LIGNES do
    local l = CreateFrame("Frame", nil, f)
    l:SetSize(764, HAUTEUR - 4)
    l:SetPoint("TOPLEFT", f, "TOPLEFT", 28, -130 - (i - 1) * HAUTEUR)
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
defil = S.Liste(f, lignes, function() Maj() end)

-- Lot 5 : en-tête de la boutique, à la place de la première ligne : compteur et filtre.
local entete = CreateFrame("Frame", nil, f)
entete:SetSize(764, HAUTEUR - 4)
entete:SetPoint("TOPLEFT", lignes[1], "TOPLEFT")
local compteur = S.Texte(entete, "SemiBold", 13, "texte")
compteur:SetPoint("LEFT", 2, 0)
local boutonsFiltre = {}
for n, nom in ipairs(FILTRES) do
    local b = S.BoutonPlat(entete, nom, 104, 26, 11)
    b:SetPoint("RIGHT", entete, "RIGHT", -(#FILTRES - n) * 110, 0)
    b:SetScript("OnClick", function() filtre = n; defil:Remonter(); Maj() end)
    boutonsFiltre[n] = b
end
entete:Hide()

local function MajPaliers()
    local total = #S.PALIERS
    defil:Capacite()
    local decalage = defil:Regler(total)
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
    local function Ouverte(m) return etat.palier >= (S.VITESSES_PALIER[m[3]] or 99) end
    local liste, possedees = {}, 0
    for _, m in ipairs(S.MONTURES) do
        local possede = etat.possede[m[1]]
        if possede then possedees = possedees + 1 end
        if filtre == 1 or filtre == 2 and Ouverte(m) or filtre == 3 and possede or filtre == 4 and Ouverte(m) and not possede then
            table.insert(liste, m)
        end
    end
    compteur:SetText(possedees .. " / " .. #S.MONTURES .. " montures possédées")
    for n, b in ipairs(boutonsFiltre) do b:Choisir(n == filtre) end
    entete:Show()
    S.Montrer(lignes[1], false)
    local total = #liste
    defil:Capacite(LIGNES - 1)   -- la première ligne porte l'en-tête
    local decalage = defil:Regler(total)
    local avoir = GetItemCount(MARQUE, true)
    for i = 2, LIGNES do
        local l = lignes[i]
        local m = liste[decalage + i - 1]
        S.Montrer(l, m ~= nil)
        if m then
            local sort, nom, vitesse, prix = m[1], m[2], m[3], m[4]
            local _, _, icone = GetSpellInfo(sort)
            local ouvert = Ouverte(m)
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

-- Lot 5 : le registre, une ligne par source, par donjon et par mode de zone.
local function MajRegistre()
    local entrees = {}
    for g = 1, 15 do
        local s = etat.sources[g]
        if s and SOURCES[g] then
            local fini = s.total > 0 and s.faits >= s.total
            table.insert(entrees, { "INV_Misc_Note_01", SOURCES[g], (s.total > 0 and (s.faits .. " / " .. s.total)
                or (s.faits .. " faits")) .. "  ·  " .. S.Nombre(s.points) .. " points", fini and "vertClair" or "texte" })
        end
    end
    for _, z in ipairs(S.ZONES) do
        local d = etat.donjons[z.donjon.carte] or 0
        table.insert(entrees, { "INV_Misc_Key_03", z.donjon.nom, d == 0 and "Pas encore terminé : difficulté 1"
            or ("Difficulté " .. d .. " réussie" .. (d < 5 and (", " .. (d + 1) .. " ouverte") or ", toutes réussies")),
            d >= 5 and "vertClair" or "texte" })
    end
    for _, m in ipairs(etat.maitrise) do
        local fini = m.tues >= m.seuil
        table.insert(entrees, { "Ability_Warrior_Rampage", (NOMS_ZONES[m.zone] or ("Zone " .. m.zone)) .. " en "
            .. (m.mode == 2 and "difficile" or "cauchemar"), fini and "Maîtrisée" or (m.tues .. " / " .. m.seuil
            .. " monstres tués"), fini and "vertClair" or "texte" })
    end
    defil:Capacite()
    local decalage = defil:Regler(#entrees)
    for i, l in ipairs(lignes) do
        local e = entrees[decalage + i]
        S.Montrer(l, e ~= nil)
        if e then
            l.icone:SetTexture("Interface\\Icons\\" .. e[1])
            l.icone:SetDesaturated(false)
            l.nom:SetText(e[2])
            l.nom:SetTextColor(S.Couleur(e[4]))
            l.detail:SetText(e[3])
            S.Montrer(l.bouton, false)
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
    entete:Hide()
    if page == 2 and etat.palier < (S.VITESSES_PALIER[60] or 10) then
        for _, l in ipairs(lignes) do S.Montrer(l, false) end
        suivant:SetText("La boutique des montures s'ouvre au palier " .. S.VITESSES_PALIER[60] .. ".")
        return
    end
    if page == 1 then MajPaliers() elseif page == 2 then MajMontures() else MajRegistre() end
end

f:SetScript("OnShow", function() Maj() end)

function S.PageAventurier(n)
    page = n
    defil:Remonter()
    if f:IsShown() then Maj() end
end
S.Ecouter("BAG_UPDATE", function() if f:IsShown() then Maj() end end)

local recu = etat
S.Message("SOLAVENT", function(champs)
    if champs[1] == "RANG" then
        recu = { points = tonumber(champs[2]) or 0, palier = tonumber(champs[3]) or 0, possede = {}, sources = {},
            donjons = {}, maitrise = {} }
    elseif champs[1] == "POSSEDE" then
        for sort in string.gmatch(champs[2] or "", "%d+") do recu.possede[tonumber(sort)] = true end
    elseif champs[1] == "SOURCES" then
        for g, p, n, t in string.gmatch(champs[2] or "", "(%d+):(%d+):(%d+):(%d+)") do
            recu.sources[tonumber(g)] = { points = tonumber(p), faits = tonumber(n), total = tonumber(t) }
        end
    elseif champs[1] == "DONJONS" then
        for c, d in string.gmatch(champs[2] or "", "(%d+):(%d+)") do recu.donjons[tonumber(c)] = tonumber(d) end
    elseif champs[1] == "MAITRISE" then
        for z, m, t, s in string.gmatch(champs[2] or "", "(%d+):(%d+):(%d+):(%d+)") do
            table.insert(recu.maitrise, { zone = tonumber(z), mode = tonumber(m), tues = tonumber(t), seuil = tonumber(s) })
        end
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
