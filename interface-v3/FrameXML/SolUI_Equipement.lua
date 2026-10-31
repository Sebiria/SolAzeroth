-- Sol'Azeroth v3, E1 (31/10/2026) : fenêtre « Équipement » (demande de l'utilisateur : pouvoir fabriquer, acheter et
-- améliorer l'équipement pour tester). Deux onglets :
-- - Fabrication : nos recettes (SolUI_Recettes.lua, généré par outils\equipement_v3.py), payées en composants de la
--   Collection et en or. Maille, bouclier et armes se fabriquent près d'une enclume ou d'une forge.
-- - Amélioration : les pièces portées et celles des sacs, rangs 1 à 5, payées en éclats cadavériques et en or.
-- Le serveur (v3_equipement.cpp, messages SOLEQUIP) dit si l'on est près d'une forge et liste les pièces améliorables
-- avec leur coût ; il vérifie tout avant de fabriquer ou d'améliorer. L'achat se fait chez les marchands de Razor Hill.
-- Une pièce se fabrique en 10 s (31/10/2026) : barre de progression au-dessus des barres d'action ; bouger annule.
-- Catégorie Cuisine (SolUI_Cuisine.lua, généré par outils\cuisine_v3.py) : les plats de la zone, près d'un feu, en 5 s.
-- Désenchantement et Enchantement (31/10/2026, SolUI_Enchantements.lua, généré par outils\enchantement_v3.py) :
-- désenchanter une pièce du sac (second clic pour confirmer) range poussières et essences dans la Collection ;
-- enchanter une pièce portée ou du sac les dépense. Le serveur envoie « PIECE;… » pour chaque armure et arme.

local S = SolUI

local ECLAT = 910120
local LIGNES = 8

local f = S.Fenetre("SolUIEquipement", 1000, 640, "Équipement")

local ouvrir = CreateFrame("Button", "SolUIOuvrirEquipement", UIParent)
ouvrir:SetSize(1, 1)
ouvrir:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -10, 10)
ouvrir:SetAlpha(0)
ouvrir:EnableMouse(false)
function S.BasculerEquipement()
    if f:IsShown() then f:Hide() else f:Show() end
end
ouvrir:SetScript("OnClick", S.BasculerEquipement)

local Maj
local forge, feu, pieces, recues = false, false, {}, {}
local armures, armuresRecues = {}, {}

local function Demander() SendChatMessage(".equipement", "SAY") end

-- Barre de fabrication : « FABRIQUE;objet;secondes », puis « FINI » ou « ANNULE ».
local progression = CreateFrame("StatusBar", nil, S.racine)
progression:SetSize(360, 30)
progression:SetPoint("BOTTOM", S.racine, "BOTTOM", 0, 230)
progression:SetStatusBarTexture(S.BLANC)
progression:SetStatusBarColor(S.Couleur("ambre"))
progression:SetBackdrop({ bgFile = S.BLANC, edgeFile = S.BLANC, edgeSize = 2,
    insets = { left = 2, right = 2, top = 2, bottom = 2 } })
progression:SetBackdropColor(S.Couleur("creux"))
progression:SetBackdropBorderColor(S.Couleur("ambre"))
progression:SetMinMaxValues(0, 1)
progression:Hide()
local objetProgression = S.Texte(progression, "Bold", 14, "clair")
objetProgression:SetPoint("LEFT", 12, 0)
local resteProgression = S.Texte(progression, "Bold", 14, "clair")
local debut, duree = 0, 10
resteProgression:SetPoint("RIGHT", -12, 0)
progression:SetScript("OnUpdate", function(self)
    local part = math.min(1, (GetTime() - debut) / duree)
    self:SetValue(part)
    resteProgression:SetText(S.Nombre(math.max(0, duree * (1 - part)), 1) .. " s")
end)

-- « FORGE;forge 0|1;feu 0|1 », « DEBUT », « OBJ;sac;case;entrée;rang;éclats;or »,
-- « PIECE;sac;case;entrée;InventoryType;enchantement;table de désenchantement », « FIN ».
S.Message("SOLEQUIP", function(champs)
    if champs[1] == "FABRIQUE" then
        local id = tonumber(champs[2])
        debut, duree = GetTime(), math.max(1, tonumber(champs[3]) or 10)
        objetProgression:SetText("Fabrication : " .. (GetItemInfo(id or 0) or ("objet " .. (id or "?"))))
        progression:SetValue(0)
        progression:Show()
        return
    elseif champs[1] == "FINI" or champs[1] == "ANNULE" then
        progression:Hide()
        return
    end
    if champs[1] == "FORGE" then
        forge = champs[2] == "1"
        feu = champs[3] == "1"
    elseif champs[1] == "DEBUT" then
        recues, armuresRecues = {}, {}
    elseif champs[1] == "PIECE" then
        table.insert(armuresRecues, { sac = tonumber(champs[2]), case = tonumber(champs[3]), id = tonumber(champs[4]),
            type = tonumber(champs[5]) or 0, enchantement = tonumber(champs[6]) or 0, table = tonumber(champs[7]) or 0 })
    elseif champs[1] == "OBJ" then
        table.insert(recues, { sac = tonumber(champs[2]), case = tonumber(champs[3]), id = tonumber(champs[4]),
            rang = tonumber(champs[5]) or 0, eclats = tonumber(champs[6]) or 0, prix = tonumber(champs[7]) or 0 })
    elseif champs[1] == "FIN" then
        pieces, armures = recues, armuresRecues
    end
    if champs[1] ~= "OBJ" and champs[1] ~= "PIECE" and champs[1] ~= "DEBUT" then Maj() end
end)

local function NomObjet(id, defaut)
    local nom, _, qualite = GetItemInfo(id)
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[qualite or 2]
    return nom or defaut or ("objet " .. id), c and c.r or 1, c and c.g or 1, c and c.b or 1
end

local function Infobulle(cadre)
    cadre:SetScript("OnEnter", function(self)
        if not self.id then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink("item:" .. self.id)
    end)
    cadre:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function Icone(parent, taille)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(taille, taille)
    b.icone = b:CreateTexture(nil, "ARTWORK")
    b.icone:SetAllPoints()
    b.icone:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    Infobulle(b)
    return b
end

------------------------------------------------------------------------
-- Onglets
------------------------------------------------------------------------
local pages, onglets, onglet = {}, {}, 1
for i, titre in ipairs({ "Fabrication", "Amélioration", "Désenchantement", "Enchantement" }) do
    local o = S.BoutonPlat(f, titre, 150, 36, 14)
    o:SetPoint("TOPLEFT", 24 + (i - 1) * 158, -60)
    o:SetScript("OnClick", function() onglet = i; Maj() end)
    onglets[i] = o
    local page = CreateFrame("Frame", nil, f)
    page:SetPoint("TOPLEFT", 1, -108)
    page:SetPoint("BOTTOMRIGHT", -1, 1)
    pages[i] = page
end
local filet = S.Texture(f, "ARTWORK", nil, S.Couleur("bord"))
filet:SetPoint("TOPLEFT", 1, -104)
filet:SetPoint("TOPRIGHT", -1, -104)
filet:SetHeight(1)
local etatForge = S.Texte(f, "Regular", 13, "gris")
etatForge:SetPoint("TOPRIGHT", -24, -72)

------------------------------------------------------------------------
-- Page 1 : fabrication
------------------------------------------------------------------------
local p1 = pages[1]
local categorie, choisie = 1, nil

local categories = {}
for i, c in ipairs(S.RECETTES) do
    local b = S.BoutonPlat(p1, c.nom, 180, 40)
    b:SetPoint("TOPLEFT", 16, -16 - (i - 1) * 46)
    b:SetScript("OnClick", function() categorie = i; choisie = nil; Maj() end)
    categories[i] = b
end

local lignesRecettes = {}
for n = 1, LIGNES do
    local l = S.BoutonPlat(p1, "", 360, 52)
    l:SetPoint("TOPLEFT", 212, -16 - (n - 1) * 58)
    l.icone = Icone(l, 36)
    l.icone:SetPoint("LEFT", 8, 0)
    l.texte:ClearAllPoints()
    l.texte:SetPoint("TOPLEFT", l.icone, "TOPRIGHT", 10, 0)
    l.texte:SetWidth(300)
    l.texte:SetJustifyH("LEFT")
    l.info = S.Texte(l, "Regular", 11, "gris")
    l.info:SetPoint("BOTTOMLEFT", l.icone, "BOTTOMRIGHT", 10, 0)
    l:SetScript("OnClick", function(self) choisie = self.recette; Maj() end)
    lignesRecettes[n] = l
end

local detail = CreateFrame("Frame", nil, p1)
detail:SetPoint("TOPLEFT", 596, -16)
detail:SetPoint("BOTTOMRIGHT", -24, 24)
local grande = Icone(detail, 56)
grande:SetPoint("TOPLEFT")
local detailNom = S.Texte(detail, "Bold", 16, "clair")
detailNom:SetPoint("LEFT", grande, "RIGHT", 12, 8)
detailNom:SetWidth(300)
detailNom:SetJustifyH("LEFT")
local detailPuissance = S.Texte(detail, "Regular", 12, "gris")
detailPuissance:SetPoint("TOPLEFT", detailNom, "BOTTOMLEFT", 0, -4)
local conditions = S.Texte(detail, "Regular", 13, "texte")
conditions:SetPoint("TOPLEFT", grande, "BOTTOMLEFT", 0, -18)
conditions:SetWidth(370)
conditions:SetJustifyH("LEFT")
local titreComposants = S.Texte(detail, "Bold", 11, "gris")
titreComposants:SetPoint("TOPLEFT", conditions, "BOTTOMLEFT", 0, -18)
titreComposants:SetText("COMPOSANTS")
local composants = {}
for n = 1, 4 do
    local c = S.Texte(detail, "Regular", 13, "texte")
    c:SetPoint("TOPLEFT", titreComposants, "BOTTOMLEFT", 0, -8 - (n - 1) * 22)
    c:SetWidth(370)
    c:SetJustifyH("LEFT")
    composants[n] = c
end
local prixFabrication = S.Texte(detail, "Regular", 13, "texte")
prixFabrication:SetPoint("TOPLEFT", titreComposants, "BOTTOMLEFT", 0, -8 - 4 * 22 - 8)
local fabriquer = S.BoutonPlat(detail, "Fabriquer", 180, 40, 14)
fabriquer:SetPoint("BOTTOMLEFT")
fabriquer:SetScript("OnClick", function()
    if choisie then SendChatMessage(".equipement fabriquer " .. choisie[1], "SAY") end
end)
local achat = S.Texte(detail, "Regular", 12, "gris")
achat:SetPoint("BOTTOMLEFT", fabriquer, "TOPLEFT", 0, 14)
achat:SetWidth(370)
achat:SetJustifyH("LEFT")
achat:SetText("Ces pièces s'achètent aussi, plus cher, chez les marchands de Razor Hill.")

local function MajFabrication()
    local c = S.RECETTES[categorie]
    for i, b in ipairs(categories) do b:Choisir(i == categorie) end
    for n, l in ipairs(lignesRecettes) do
        local r = c.recettes[n]
        S.Montrer(l, r)
        if r then
            l.recette, l.icone.id = r, r[1]
            l.icone.icone:SetTexture(GetItemIcon(r[1]))
            l.texte:SetText(r[2])
            l.info:SetText("Puissance " .. r[3])
            l:Choisir(choisie == r)
        end
    end
    S.Montrer(detail, choisie)
    if not choisie then return end
    local r = choisie
    grande.id = r[1]
    grande.icone:SetTexture(GetItemIcon(r[1]))
    detailNom:SetText(r[2])
    detailNom:SetTextColor(select(2, NomObjet(r[1], r[2])))
    detailPuissance:SetText(c.feu and ("Repas de " .. (r[7] or "") .. " : +" .. r[3] .. " pendant 30 min")
        or ("Puissance " .. r[3]))
    local puissance = S.etat.puissance or 0
    local okPuissance = puissance + 0.05 >= r[4]
    local lignes = {}
    local hex = function(ok) return ok and "|cff8cc4a6" or "|cfff0918a" end
    if c.feu then
        table.insert(lignes, "|cffb4b8bfForce, Agilité ou Intelligence selon ta spécialisation. Un seul repas à la "
            .. "fois.|r")
        table.insert(lignes, hex(feu) .. (feu and "Près d'un feu" or "À cuisiner près d'un feu (ton Feu de camp compte)")
            .. "|r")
    else
        table.insert(lignes, hex(okPuissance) .. "Puissance requise : " .. r[4] .. "|r  |cffb4b8bf(la tienne : "
            .. S.Nombre(puissance, 1) .. ")|r")
        if c.forge then
            table.insert(lignes, hex(forge) .. (forge and "Près d'une enclume ou d'une forge" or
                "À fabriquer près d'une enclume ou d'une forge") .. "|r")
        else
            table.insert(lignes, "|cffb4b8bfSe fabrique partout.|r")
        end
    end
    conditions:SetText(table.concat(lignes, "\n"))
    local tout = okPuissance and (forge or not c.forge) and (feu or not c.feu)
    S.Montrer(achat, not c.feu)
    for n, ligne in ipairs(composants) do
        local comp = r[6][n]
        S.Montrer(ligne, comp)
        if comp then
            local a = S.NombreCollection(comp[1])
            tout = tout and a >= comp[2]
            ligne:SetText(S.NomCollection(comp[1]) .. "   " .. hex(a >= comp[2]) .. a .. " / " .. comp[2] .. "|r")
        end
    end
    local okOr = GetMoney() >= r[5]
    tout = tout and okOr
    prixFabrication:SetText(r[5] > 0 and ("Or : " .. hex(okOr) .. S.Argent(r[5]) .. "|r") or "")
    fabriquer:SetAlpha(tout and 1 or 0.5)
end

------------------------------------------------------------------------
-- Page 2 : amélioration
------------------------------------------------------------------------
local p2 = pages[2]
local decalage = 0
local intro = S.Texte(p2, "Regular", 13, "gris")
intro:SetPoint("TOPLEFT", 24, -16)
intro:SetWidth(950)
intro:SetJustifyH("LEFT")
intro:SetText("Chaque rang ajoute 10 % aux caractéristiques de la pièce (jusqu'au rang 5) et compte dans ta puissance. "
    .. "Les rangs 4 et 5 demanderont aussi un composant rare, avec la joaillerie.")
local soldes = S.Texte(p2, "SemiBold", 13, "ambreClair")
soldes:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", 0, -10)

local lignesPieces = {}
for n = 1, LIGNES do
    local l = CreateFrame("Frame", nil, p2)
    l:SetSize(950, 50)
    l:SetPoint("TOPLEFT", 24, -70 - (n - 1) * 56)
    l:SetBackdrop({ bgFile = S.BLANC, edgeFile = S.BLANC, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
    l:SetBackdropColor(0.11, 0.118, 0.133, 1)
    l:SetBackdropBorderColor(S.Couleur("bord"))
    l:EnableMouseWheel(true)
    l.icone = Icone(l, 36)
    l.icone:SetPoint("LEFT", 8, 0)
    l.nom = S.Texte(l, "SemiBold", 13, "clair")
    l.nom:SetPoint("TOPLEFT", l.icone, "TOPRIGHT", 10, 0)
    l.nom:SetWidth(330)
    l.nom:SetJustifyH("LEFT")
    l.place = S.Texte(l, "Regular", 11, "gris")
    l.place:SetPoint("BOTTOMLEFT", l.icone, "BOTTOMRIGHT", 10, 0)
    l.rang = S.Texte(l, "SemiBold", 13, "ambreClair")
    l.rang:SetPoint("LEFT", 400, 0)
    l.cout = S.Texte(l, "Regular", 13, "texte")
    l.cout:SetPoint("LEFT", 520, 0)
    l.bouton = S.BoutonPlat(l, "Améliorer", 130, 34, 13)
    l.bouton:SetPoint("RIGHT", -8, 0)
    l.bouton.ligne = l
    l.bouton:SetScript("OnClick", function(self)
        local p = self.ligne.piece
        if p then SendChatMessage(".equipement ameliorer " .. p.sac .. " " .. p.case, "SAY") end
    end)
    lignesPieces[n] = l
end
local vide = S.Texte(p2, "Regular", 14, "gris")
vide:SetPoint("TOP", 0, -140)
vide:SetText("Aucune pièce améliorable : seules nos pièces (quêtes, fabrication, marchands) ont des rangs.")

local function MajAmelioration()
    local eclats = S.NombreCollection(ECLAT)
    soldes:SetText("Éclats cadavériques : " .. eclats .. "     Or : " .. (GetMoney() > 0 and S.Argent(GetMoney()) or "0"))
    decalage = math.max(0, math.min(decalage, #pieces - LIGNES))
    S.Montrer(vide, #pieces == 0)
    for n, l in ipairs(lignesPieces) do
        local p = pieces[n + decalage]
        S.Montrer(l, p)
        if p then
            l.piece, l.icone.id = p, p.id
            l.icone.icone:SetTexture(GetItemIcon(p.id))
            local nom, r, g, b = NomObjet(p.id)
            l.nom:SetText(nom)
            l.nom:SetTextColor(r, g, b)
            l.place:SetText(p.sac == -1 and "Porté" or "Dans le sac")
            if p.rang >= 5 then
                l.rang:SetText("Rang 5 (maximum)")
                l.cout:SetText("")
                S.Montrer(l.bouton, false)
            else
                l.rang:SetText("Rang " .. p.rang .. "  →  " .. (p.rang + 1))
                local ok = eclats >= p.eclats and GetMoney() >= p.prix
                l.cout:SetText((eclats >= p.eclats and "" or "|cfff0918a") .. p.eclats .. " éclats|r   "
                    .. (GetMoney() >= p.prix and "" or "|cfff0918a") .. S.Argent(p.prix) .. "|r")
                S.Montrer(l.bouton, true)
                l.bouton:SetAlpha(ok and 1 or 0.5)
            end
        end
    end
end

for _, l in ipairs(lignesPieces) do
    l:SetScript("OnMouseWheel", function(_, sens) decalage = math.max(0, decalage - sens); Maj() end)
end

------------------------------------------------------------------------
-- Pages 3 et 4 : désenchantement et enchantement
------------------------------------------------------------------------
local hexOk = function(ok) return ok and "" or "|cfff0918a" end

-- Enchantement de SolUI.ENCHANTEMENTS qui va sur ce type de pièce, de numéro enchantement (ou tous si nil).
local function EnchantementsDe(type, enchantement)
    local liste = {}
    for _, e in ipairs(S.ENCHANTEMENTS) do
        for _, t in ipairs(e[5]) do
            if t == type and (not enchantement or e[4] == enchantement) then table.insert(liste, e) end
        end
    end
    return liste
end

local function Cout(e)
    local morceaux, ok = {}, GetMoney() >= e[7]
    for _, c in ipairs(e[6]) do
        local a = S.NombreCollection(c[1])
        ok = ok and a >= c[2]
        table.insert(morceaux, hexOk(a >= c[2]) .. c[2] .. " " .. S.NomCollection(c[1]) .. " (" .. a .. ")|r")
    end
    table.insert(morceaux, hexOk(GetMoney() >= e[7]) .. S.Argent(e[7]) .. "|r")
    return table.concat(morceaux, "  ·  "), ok
end

-- Une page de pièces : intro, lignes de LIGNES, molette, texte si vide.
local function PageDePieces(page, texteIntro, texteVide, boutons)
    local p = { decalage = 0, lignes = {} }
    p.intro = S.Texte(page, "Regular", 13, "gris")
    p.intro:SetPoint("TOPLEFT", 24, -16)
    p.intro:SetWidth(950)
    p.intro:SetJustifyH("LEFT")
    p.intro:SetText(texteIntro)
    for n = 1, LIGNES do
        local l = CreateFrame("Frame", nil, page)
        l:SetSize(950, 50)
        l:SetPoint("TOPLEFT", 24, -70 - (n - 1) * 56)
        l:SetBackdrop({ bgFile = S.BLANC, edgeFile = S.BLANC, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
        l:SetBackdropColor(0.11, 0.118, 0.133, 1)
        l:SetBackdropBorderColor(S.Couleur("bord"))
        l:EnableMouseWheel(true)
        l:SetScript("OnMouseWheel", function(_, sens) p.decalage = math.max(0, p.decalage - sens); Maj() end)
        l.icone = Icone(l, 36)
        l.icone:SetPoint("LEFT", 8, 0)
        l.nom = S.Texte(l, "SemiBold", 13, "clair")
        l.nom:SetPoint("TOPLEFT", l.icone, "TOPRIGHT", 10, 0)
        l.nom:SetWidth(330)
        l.nom:SetJustifyH("LEFT")
        l.place = S.Texte(l, "Regular", 11, "gris")
        l.place:SetPoint("BOTTOMLEFT", l.icone, "BOTTOMRIGHT", 10, 0)
        l.haut = S.Texte(l, "SemiBold", 12, "ambreClair")
        l.haut:SetPoint("TOPLEFT", 400, -8)
        l.haut:SetJustifyH("LEFT")
        l.bas = S.Texte(l, "Regular", 11, "texte")
        l.bas:SetPoint("BOTTOMLEFT", 400, 8)
        l.bas:SetJustifyH("LEFT")
        l.boutons = {}
        for b = 1, boutons do
            local bouton = S.BoutonPlat(l, "", 130, 34, 12)
            bouton:SetPoint("RIGHT", -8 - (b - 1) * 138, 0)
            bouton.ligne = l
            l.boutons[b] = bouton
        end
        p.lignes[n] = l
    end
    p.vide = S.Texte(page, "Regular", 14, "gris")
    p.vide:SetPoint("TOP", 0, -140)
    p.vide:SetText(texteVide)
    return p
end

local function Remplir(p, liste, Ligne)
    p.decalage = math.max(0, math.min(p.decalage, #liste - LIGNES))
    S.Montrer(p.vide, #liste == 0)
    for n, l in ipairs(p.lignes) do
        local piece = liste[n + p.decalage]
        S.Montrer(l, piece)
        if piece then
            l.piece, l.icone.id = piece, piece.id
            l.icone.icone:SetTexture(GetItemIcon(piece.id))
            local nom, r, g, b = NomObjet(piece.id)
            l.nom:SetText(nom)
            l.nom:SetTextColor(r, g, b)
            l.place:SetText(piece.sac == -1 and "Porté" or "Dans le sac")
            Ligne(l, piece)
        end
    end
end

local function Cle(piece) return piece.sac .. ":" .. piece.case .. ":" .. piece.id end

local p3 = PageDePieces(pages[3], "Désenchanter détruit une pièce verte ou mieux de tes sacs ; ses poussières et "
    .. "essences vont dans la Collection et servent à enchanter. Un second clic confirme.",
    "Aucune pièce à désenchanter dans tes sacs (armures et armes vertes ou mieux).", 1)
local aConfirmer
for _, l in ipairs(p3.lignes) do
    l.boutons[1]:SetScript("OnClick", function(self)
        local piece = self.ligne.piece
        if not piece then return end
        if aConfirmer ~= Cle(piece) then
            aConfirmer = Cle(piece)
        else
            aConfirmer = nil
            SendChatMessage(".equipement desenchanter " .. piece.sac .. " " .. piece.case, "SAY")
        end
        Maj()
    end)
end

local function MajDesenchantement()
    local liste, confirmee = {}, false
    for _, piece in ipairs(armures) do
        if piece.sac >= 0 and piece.table > 0 then
            table.insert(liste, piece)
            confirmee = confirmee or aConfirmer == Cle(piece)
        end
    end
    if not confirmee then aConfirmer = nil end
    Remplir(p3, liste, function(l, piece)
        l.haut:SetText("Donne")
        l.bas:SetText(S.DESENCHANTEMENT[piece.table] or "le butin de désenchantement de la pièce")
        local b = l.boutons[1]
        b.texte:SetText(aConfirmer == Cle(piece) and "Confirmer" or "Désenchanter")
        b:Choisir(aConfirmer == Cle(piece))
    end)
end

local p4 = PageDePieces(pages[4], "Un enchantement par pièce : le nouveau remplace l'ancien, et il reste quand la pièce "
    .. "change de rang. Composants de la Collection (entre parenthèses, ce que tu as) et or.",
    "Aucune pièce à enchanter : plastron, brassards, cape, bouclier ou arme.", 2)
for _, l in ipairs(p4.lignes) do
    for _, b in ipairs(l.boutons) do
        b:SetScript("OnClick", function(self)
            local piece = self.ligne.piece
            if piece and self.enchantement then
                SendChatMessage(".equipement enchanter " .. piece.sac .. " " .. piece.case .. " " .. self.enchantement[1],
                    "SAY")
            end
        end)
    end
end

local function MajEnchantement()
    local liste = {}
    for _, piece in ipairs(armures) do
        if #EnchantementsDe(piece.type) > 0 then table.insert(liste, piece) end
    end
    Remplir(p4, liste, function(l, piece)
        local actuel = piece.enchantement > 0 and EnchantementsDe(piece.type, piece.enchantement)[1]
        local possibles = EnchantementsDe(piece.type)
        l.haut:SetText(piece.enchantement == 0 and "|cffb4b8bfSans enchantement|r"
            or actuel and ("Enchantée : " .. actuel[2] .. " (" .. actuel[3] .. ")") or "Enchantée")
        local cout, ok = Cout(possibles[1])
        l.bas:SetText(cout)
        for n, b in ipairs(l.boutons) do
            local e = possibles[n]
            b.enchantement = e
            S.Montrer(b, e)
            if e then
                b.texte:SetText(e[3])
                b:Choisir(piece.enchantement == e[4])
                b:SetAlpha((ok and piece.enchantement ~= e[4]) and 1 or 0.5)
            end
        end
    end)
end

------------------------------------------------------------------------
-- Mise à jour
------------------------------------------------------------------------
function Maj()
    if not f:IsShown() then return end
    for i, page in ipairs(pages) do
        S.Montrer(page, i == onglet)
        onglets[i]:Choisir(i == onglet)
    end
    etatForge:SetText((forge and "|cff8cc4a6Près d'une forge|r" or "Loin d'une forge") .. "   ·   "
        .. (feu and "|cff8cc4a6Près d'un feu|r" or "Loin d'un feu"))
    if onglet == 1 then MajFabrication()
    elseif onglet == 2 then MajAmelioration()
    elseif onglet == 3 then MajDesenchantement()
    else MajEnchantement() end
end

-- Pendant que la fenêtre est ouverte : l'état du serveur toutes les 3 s (distance de la forge), et après chaque
-- changement de sac ou d'équipement.
local attente, demande = 0, false
f:SetScript("OnUpdate", function(_, ecoule)
    attente = attente - ecoule
    if attente <= 0 or (demande and attente <= 2.5) then
        attente, demande = 3, false
        Demander()
    end
end)
f:SetScript("OnShow", function() attente = 0; Maj() end)
local function Changement() if f:IsShown() then demande = true; Maj() end end
S.Ecouter("BAG_UPDATE", Changement)
S.Ecouter("PLAYER_EQUIPMENT_CHANGED", Changement)
S.Ecouter("PLAYER_MONEY", Changement)
S.Abonner("puissance", function() Maj() end)
