-- Sol'Azeroth v3 (01/11/2026, proposition validée : « Réputation des donjons — proposition.md ») : passifs et
-- difficultés de donjon (v3_passifs.cpp, préfixe SOLPASSIF ; v3_donjons.cpp, préfixe SOLDONJON ; listes :
-- SolUI_PassifsDonnees.lua, généré par outils\passifs_v3.py).
-- - Fenêtre des passifs : réputation des donjons, puis deux pages. Donjon : 6 emplacements ouverts par la réputation,
--   21 passifs. Extérieur : 6 emplacements ouverts par le rang d'aventurier et achetés en Marques, 21 passifs en arbre
--   (combat, survie, récolte et voyage), sans prérequis. Clic sur un emplacement : il est choisi (clic droit : vidé) ;
--   clic sur un passif : il va dans l'emplacement choisi, ou en sort s'il y est déjà.
-- - Fenêtre d'entrée de donjon : au premier pas dans un donjon, tant que le premier combat n'est pas livré, choix de
--   la difficulté (1 à 5, celles qu'ouvre le rang d'aventurier) et techniques des monstres tirées pour le donjon.

local S = SolUI

local MARQUE = 37711
local GENRES = { "donjon", "exterieur" }
local COLONNES = { 270, 468, 666 }
local f = S.Fenetre("SolUIPassifs", 880, 640, "Passifs et réputation des donjons")

local etat = { points = 0, rang = 0, donjon = 0, ouverts = 0, achetes = 0, modDonjon = false, modExt = false,
    choix = { {}, {} } }
local page = 1
local choisi = { 1, 1 }
local Maj

function S.BasculerPassifs(genre)
    if genre then
        page = genre == "exterieur" and 2 or 1
        f:Show()
        Maj()
    elseif f:IsShown() then f:Hide() else f:Show() end
end

local resume = S.Texte(f, "SemiBold", 14, "clair")
resume:SetPoint("TOPLEFT", f, "TOPLEFT", 28, -66)
local suivant = S.Texte(f, "Regular", 12, "gris")
suivant:SetPoint("TOPLEFT", resume, "BOTTOMLEFT", 0, -6)
local fond = S.Texture(f, "ARTWORK", nil, S.Couleur("creux"))
fond:SetPoint("TOPLEFT", suivant, "BOTTOMLEFT", 0, -8)
fond:SetSize(824, 8)
local barre = S.Texture(f, "OVERLAY", nil, S.Couleur("ambre"))
barre:SetPoint("TOPLEFT", fond, "TOPLEFT")
barre:SetHeight(8)
local marques = S.Texte(f, "SemiBold", 13, "ambreClair")
marques:SetPoint("TOPRIGHT", f, "TOPRIGHT", -28, -66)

local onglets = {}
for n, nom in ipairs({ "Donjon", "Extérieur" }) do
    local b = S.BoutonPlat(f, nom, 140, 30, 12)
    b:SetPoint("TOPLEFT", f, "TOPLEFT", 28 + (n - 1) * 148, -130)
    b:SetScript("OnClick", function() page = n; Maj() end)
    b:Hide()   -- carnet Aventure (SolUI_Carnets.lua)
    onglets[n] = b
end

local titreEmplacements = S.Texte(f, "SemiBold", 12, "gris")
titreEmplacements:SetPoint("TOPLEFT", f, "TOPLEFT", 28, -136)
titreEmplacements:SetText("Emplacements")

local function Commande(texte) SendChatMessage(texte, "SAY") end

local function Passif(n)
    for _, p in ipairs(page == 1 and S.PASSIFS_DONJON or S.PASSIFS_EXTERIEUR) do
        if p[1] == n then return p end
    end
end

local function Nom(p) return page == 1 and p[2] or p[3] end
local function Effet(p) return page == 1 and p[3] or p[4] end

-- Emplacements : 6 boutons ; achat du prochain emplacement extérieur.
local emplacements = {}
for i = 1, 6 do
    local b = S.BoutonPlat(f, "", 220, 40, 12)
    b:SetPoint("TOPLEFT", f, "TOPLEFT", 28, -156 - (i - 1) * 48)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:HookScript("OnEnter", function(self)
        if not self.passif then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(Nom(self.passif), 1, 0.82, 0)
        GameTooltip:AddLine(Effet(self.passif), 1, 1, 1, true)
        GameTooltip:AddLine("Clic droit : vider l'emplacement.", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    b:HookScript("OnLeave", function() GameTooltip:Hide() end)
    emplacements[i] = b
end

-- Passifs : trois colonnes ; en extérieur, une branche par colonne (récolte et voyage ensemble).
local entetes = {}
for c, x in ipairs(COLONNES) do
    local t = S.Texte(f, "SemiBold", 12, "gris")
    t:SetPoint("TOPLEFT", f, "TOPLEFT", x, -136)
    entetes[c] = t
end
local boutons = {}
for i = 1, 24 do
    local b = S.BoutonPlat(f, "", 186, 30, 11)
    b:HookScript("OnEnter", function(self)
        if not self.passif then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(Nom(self.passif), 1, 0.82, 0)
        GameTooltip:AddLine(Effet(self.passif), 1, 1, 1, true)
        GameTooltip:Show()
    end)
    b:HookScript("OnLeave", function() GameTooltip:Hide() end)
    boutons[i] = b
end

local aide = S.Texte(f, "Regular", 12, "gris")
aide:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 28, 24)
aide:SetWidth(824)
aide:SetJustifyH("LEFT")

local function Ouverts()
    if page == 1 then return etat.donjon end
    return math.min(etat.achetes, etat.ouverts)
end

local function Placer(n)
    local choix = etat.choix[page]
    for i = 1, 6 do
        if choix[i] == n then
            Commande(".passif " .. GENRES[page] .. " " .. i .. " 0")
            return
        end
    end
    local cible = choisi[page]
    if cible > Ouverts() or (choix[cible] or 0) ~= 0 then
        cible = nil
        for i = 1, Ouverts() do
            if (choix[i] or 0) == 0 then cible = i; break end
        end
        cible = cible or choisi[page]
    end
    if cible <= Ouverts() then
        Commande(".passif " .. GENRES[page] .. " " .. cible .. " " .. n)
    end
end

local function MajEmplacements()
    local choix, ouverts = etat.choix[page], Ouverts()
    for i, b in ipairs(emplacements) do
        local n = choix[i] or 0
        b.passif = false
        b:SetAlpha(1)
        if i <= ouverts then
            b.passif = n ~= 0 and Passif(n) or false
            b.texte:SetText(i .. ".  " .. (b.passif and Nom(b.passif) or "|cffb4b8bflibre|r"))
            b:Choisir(i == choisi[page])
            b:SetScript("OnClick", function(_, bouton)
                if bouton == "RightButton" then
                    if n ~= 0 then Commande(".passif " .. GENRES[page] .. " " .. i .. " 0") end
                else
                    choisi[page] = i
                    Maj()
                end
            end)
        else
            b:Choisir(false)
            b:SetAlpha(0.6)
            b:SetScript("OnClick", nil)
            if page == 1 then
                b.texte:SetText(i .. ".  Rang " .. S.EMPLACEMENTS_DONJON[i] .. " de réputation")
            else
                local palier, prix = S.EMPLACEMENTS_EXTERIEUR[i][1], S.EMPLACEMENTS_EXTERIEUR[i][2]
                if i == etat.achetes + 1 and i <= etat.ouverts then
                    b:SetAlpha(1)
                    b.texte:SetText(i .. ".  Acheter  ·  " .. prix .. " Marques")
                    b:SetScript("OnClick", function() Commande(".passif acheter") end)
                else
                    b.texte:SetText(i .. ".  Palier " .. palier .. "  ·  " .. prix .. " Marques")
                end
            end
        end
    end
end

local function MajPassifs()
    local liste, places = {}, {}
    for _, n in pairs(etat.choix[page]) do places[n] = true end
    if page == 1 then
        for c = 1, 3 do entetes[c]:SetText("") end
        for i, p in ipairs(S.PASSIFS_DONJON) do
            table.insert(liste, { p, math.floor((i - 1) / 7) + 1, (i - 1) % 7 })
        end
    else
        local colonne = { Combat = 1, ["Survie"] = 2, ["Récolte"] = 3, Voyage = 3 }
        local lignes = { 0, 0, 0 }
        entetes[1]:SetText("Combat")
        entetes[2]:SetText("Survie")
        entetes[3]:SetText("Récolte et voyage")
        for _, p in ipairs(S.PASSIFS_EXTERIEUR) do
            local c = colonne[p[2]] or 3
            table.insert(liste, { p, c, lignes[c] })
            lignes[c] = lignes[c] + 1
        end
    end
    for i, b in ipairs(boutons) do
        local e = liste[i]
        S.Montrer(b, e ~= nil)
        if e then
            local p = e[1]
            b.passif = p
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", f, "TOPLEFT", COLONNES[e[2]], -156 - e[3] * 36)
            b.texte:SetText(Nom(p))
            b:Choisir(places[p[1]] == true)
            b:SetScript("OnClick", function() Placer(p[1]) end)
        end
    end
end

function Maj()
    local rang = etat.rang
    local suivantSeuil = S.RANGS_REPUTATION[rang + 1]
    local bas = S.RANGS_REPUTATION[rang] or 0
    resume:SetText("Réputation des donjons : rang " .. rang .. " / " .. #S.RANGS_REPUTATION .. "   ·   "
        .. S.Nombre(etat.points) .. " points")
    if suivantSeuil then
        suivant:SetText("Rang suivant à " .. S.Nombre(suivantSeuil) .. " points  ·  1 par monstre, 10 par boss, 100 au "
            .. "dernier boss, × la difficulté")
        barre:SetWidth(math.max(1, 824 * (etat.points - bas) / math.max(1, suivantSeuil - bas)))
    else
        suivant:SetText("Dernier rang atteint.")
        barre:SetWidth(824)
    end
    marques:SetText(GetItemCount(MARQUE, true) .. " Marques du voyageur")
    for n, b in ipairs(onglets) do b:Choisir(n == page) end
    choisi[page] = math.max(1, math.min(choisi[page], math.max(1, Ouverts())))
    MajEmplacements()
    MajPassifs()
    if page == 1 then
        aide:SetText((etat.modDonjon and "|cff9fd99f" or "|cfff0918a")
            .. (etat.modDonjon and "Modifiable maintenant." or "Non modifiable ici.") .. "|r  Les passifs de donjon valent "
            .. "dans les instances ; ils se changent hors combat, hors d'une instance ou dans un donjon avant le premier combat.")
    else
        aide:SetText((etat.modExt and "|cff9fd99f" or "|cfff0918a")
            .. (etat.modExt and "Modifiable maintenant." or "Non modifiable ici.") .. "|r  Les passifs extérieurs valent "
            .. "hors des instances ; ils se changent dans une zone de repos (auberge, ville), hors combat.")
    end
end

f:SetScript("OnShow", function() Maj() end)

function S.PagePassifs(n)
    page = n
    if f:IsShown() then Maj() end
end
S.Ecouter("BAG_UPDATE", function() if f:IsShown() then Maj() end end)

local recu
S.Message("SOLPASSIF", function(champs)
    if champs[1] == "ETAT" then
        recu = { points = tonumber(champs[2]) or 0, rang = tonumber(champs[3]) or 0, donjon = tonumber(champs[4]) or 0,
            ouverts = tonumber(champs[5]) or 0, achetes = tonumber(champs[6]) or 0, modDonjon = champs[7] == "1",
            modExt = champs[8] == "1", choix = { {}, {} } }
    elseif recu and (champs[1] == "DONJON" or champs[1] == "EXT") then
        local c = recu.choix[champs[1] == "DONJON" and 1 or 2]
        for i = 1, 6 do c[i] = tonumber(champs[i + 1]) or 0 end
    elseif recu and champs[1] == "FIN" then
        etat = recu
        recu = nil
        if f:IsShown() then Maj() end
    end
end)

------------------------------------------------------------------------
-- Entrée de donjon : difficulté, avant le premier combat
------------------------------------------------------------------------
local d = S.Fenetre("SolUIDonjon", 560, 330, "Difficulté du donjon")
local donjon = { difficulte = 1, ouvertes = 1, verrouille = true, techniques = 0 }

local consigne = S.Texte(d, "Regular", 12, "gris")
consigne:SetPoint("TOPLEFT", d, "TOPLEFT", 28, -66)
consigne:SetWidth(504)
consigne:SetJustifyH("LEFT")
consigne:SetText("Choisissez la difficulté avant le premier combat ; elle reste ensuite jusqu'à la remise à zéro du donjon.")

local niveaux = {}
for n = 1, 5 do
    local b = S.BoutonPlat(d, tostring(n), 92, 40, 16)
    b:SetPoint("TOPLEFT", d, "TOPLEFT", 28 + (n - 1) * 103, -104)
    b:SetScript("OnClick", function()
        if n <= donjon.ouvertes and not donjon.verrouille then Commande(".donjon " .. n) end
    end)
    b:HookScript("OnEnter", function(self)
        local r = S.DIFFICULTES[n]
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine("Difficulté " .. n, 1, 0.82, 0)
        if n == 1 then
            GameTooltip:AddLine("Le donjon tel qu'il est.", 1, 1, 1, true)
        else
            GameTooltip:AddLine("Monstres à votre puissance de base" .. (r[1] > 0 and (" + " .. r[1]) or "") .. ", vie et dégâts × "
                .. r[2] .. ", " .. r[3] .. " technique(s), éclats × " .. r[4] .. ".", 1, 1, 1, true)
            GameTooltip:AddLine("Dernier boss : + " .. 2 * (n - 1) .. " Marques" .. (n >= 3 and (", " .. 25 * (n - 2)
                .. " % de chances d'une pierre taillée") or "") .. ".", 0.62, 0.85, 0.62, true)
        end
        if n > donjon.ouvertes then
            GameTooltip:AddLine("S'ouvre au palier " .. r[5] .. " du rang d'aventurier.", 0.94, 0.57, 0.54, true)
        end
        GameTooltip:Show()
    end)
    b:HookScript("OnLeave", function() GameTooltip:Hide() end)
    niveaux[n] = b
end

local techniques = S.Texte(d, "Regular", 12, "texte")
techniques:SetPoint("TOPLEFT", d, "TOPLEFT", 28, -164)
techniques:SetWidth(504)
techniques:SetJustifyH("LEFT")

local versPassifs = S.BoutonPlat(d, "Passifs de donjon", 200, 32, 12)
versPassifs:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", 28, 24)
versPassifs:SetScript("OnClick", function() S.OuvrirCarnet("aventure", 6) end)
local fermer = S.BoutonPlat(d, "Entrer", 140, 32, 12)
fermer:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", -28, 24)
fermer:SetScript("OnClick", function() d:Hide() end)

local function MajDonjon()
    for n, b in ipairs(niveaux) do
        b:Choisir(n == donjon.difficulte)
        b:SetAlpha(n <= donjon.ouvertes and 1 or 0.4)
    end
    local lignes = {}
    for k = 1, 4 do
        if math.floor(donjon.techniques / 2 ^ (k - 1)) % 2 == 1 then
            table.insert(lignes, "·  " .. S.TECHNIQUES_DONJON[k])
        end
    end
    techniques:SetText(#lignes > 0 and ("Techniques des monstres :\n" .. table.concat(lignes, "\n"))
        or "Aucune technique : les monstres sont ceux du donjon.")
end

d:SetScript("OnShow", MajDonjon)

local dedans = false
S.Message("SOLDONJON", function(champs)
    if champs[1] ~= "DONJON" then
        dedans = false
        d:Hide()
        return
    end
    donjon = { difficulte = tonumber(champs[2]) or 1, ouvertes = tonumber(champs[3]) or 1, verrouille = champs[4] == "1",
        techniques = tonumber(champs[5]) or 0 }
    if donjon.verrouille then
        d:Hide()
    elseif not dedans then
        d:Show()
    end
    dedans = true
    if d:IsShown() then MajDonjon() end
end)

-- Réponse du serveur « Emplacement 2 : passif 47. » : le nom du passif à la place de son numéro (signalement du
-- 01/11/2026 ; le serveur ne connaît que les numéros).
local NOMS_PASSIFS = {}
for _, p in ipairs(S.PASSIFS_DONJON) do NOMS_PASSIFS[p[1]] = p[2] end
for _, p in ipairs(S.PASSIFS_EXTERIEUR) do NOMS_PASSIFS[p[1]] = p[3] end
ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", function(_, _, message, ...)
    local debut, numero = (message or ""):match("^(Emplacement %d+ : )passif (%d+)%.$")
    local nom = numero and NOMS_PASSIFS[tonumber(numero)]
    if nom then return false, debut .. nom .. ".", ... end
end)
