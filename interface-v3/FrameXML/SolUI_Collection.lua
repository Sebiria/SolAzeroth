-- Sol'Azeroth v3 (31/10/2026) : fenêtre « Collection », d'après la maquette « 8 » (document v3, § 2.8).
-- Tous les objets à collectionner du jeu (SolUI_Catalogue.lua, généré par outils\collection_v3.py), par catégorie :
-- en couleur avec le nombre possédé quand on en a, grisés sinon. Recherche, filtre Tout / Possédés / Manquants,
-- détail de l'objet choisi.
-- En attendant l'inventaire sans limite côté serveur (série 4), le nombre possédé est celui des sacs et de la banque.

local S = SolUI

local COLONNES, LIGNES = 5, 8
local TUILE_L, TUILE_H, ECART = 124, 52, 8

local f = S.Fenetre("SolUICollection", 1100, 680, "Collection")

local ouvrir = CreateFrame("Button", "SolUIOuvrirCollection", UIParent)
ouvrir:SetSize(1, 1)
ouvrir:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -10, 10)
ouvrir:SetAlpha(0)
ouvrir:EnableMouse(false)
function S.BasculerCollection()
    if f:IsShown() then f:Hide() else f:Show() end
end
ouvrir:SetScript("OnClick", S.BasculerCollection)

local categorie, filtre, recherche, choisi, decalage = 1, 1, "", nil, 0
local Maj

local function Nombre(id) return GetItemCount(id, true) or 0 end

------------------------------------------------------------------------
-- En-tête : progression, recherche, filtre
------------------------------------------------------------------------
local jauge = CreateFrame("Frame", nil, f.barre)
jauge:SetSize(160, 6)
jauge:SetPoint("LEFT", f.titre, "RIGHT", 20, 0)
jauge:SetBackdrop({ bgFile = S.BLANC })
jauge:SetBackdropColor(S.Couleur("creux"))
local plein = S.Texture(jauge, "ARTWORK", nil, S.Couleur("ambre"))
plein:SetPoint("TOPLEFT")
plein:SetPoint("BOTTOMLEFT")
local total = S.Texte(f.barre, "Regular", 12, "gris")
total:SetPoint("LEFT", jauge, "RIGHT", 10, 0)

local champ = CreateFrame("EditBox", "SolUICollectionRecherche", f.barre)
champ:SetSize(260, 32)
champ:SetPoint("RIGHT", -300, 0)
champ:SetAutoFocus(false)
champ:SetTextInsets(12, 12, 0, 0)
S.Police(champ, "Regular", 13)
champ:SetTextColor(S.Couleur("clair"))
champ:SetBackdrop({ bgFile = S.BLANC, edgeFile = S.BLANC, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
champ:SetBackdropColor(S.Couleur("creux"))
champ:SetBackdropBorderColor(S.Couleur("bord"))
local indice = S.Texte(champ, "Regular", 13, "gris")
indice:SetPoint("LEFT", 12, 0)
indice:SetText("Chercher un objet")
champ:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
champ:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
champ:SetScript("OnTextChanged", function(self)
    recherche = (self:GetText() or ""):lower()
    S.Montrer(indice, recherche == "" and not self:HasFocus())
    decalage = 0
    Maj()
end)
champ:SetScript("OnEditFocusGained", function() indice:Hide() end)
champ:SetScript("OnEditFocusLost", function(self) S.Montrer(indice, (self:GetText() or "") == "") end)

local filtres = {}
for i, nom in ipairs({ "Tout", "Possédés", "Manquants" }) do
    local b = S.BoutonPlat(f.barre, nom, 86, 32)
    -- Entre la recherche et le bouton de fermeture.
    b:SetPoint("LEFT", champ, "RIGHT", 12 + (i - 1) * 90, 0)
    b:SetScript("OnClick", function() filtre = i; decalage = 0; Maj() end)
    filtres[i] = b
end

local filet = S.Texture(f, "ARTWORK", nil, S.Couleur("bord"))
filet:SetPoint("TOPLEFT", 1, -56)
filet:SetPoint("TOPRIGHT", -1, -56)
filet:SetHeight(1)

------------------------------------------------------------------------
-- Catégories
------------------------------------------------------------------------
local onglets = {}
for i, c in ipairs(S.CATALOGUE) do
    local b = S.BoutonPlat(f, c.nom, 214, 40)
    b:SetPoint("TOPLEFT", 16, -72 - (i - 1) * 46)
    b.texte:ClearAllPoints()
    b.texte:SetPoint("LEFT", 12, 0)
    b.compte = S.Texte(b, "Regular", 11, "gris")
    b.compte:SetPoint("RIGHT", -10, 0)
    b:SetScript("OnClick", function() categorie = i; decalage = 0; choisi = nil; Maj() end)
    onglets[i] = b
end
local separation = S.Texture(f, "ARTWORK", nil, S.Couleur("bord"))
separation:SetPoint("TOPLEFT", 246, -57)
separation:SetPoint("BOTTOMLEFT", 246, 1)
separation:SetWidth(1)

------------------------------------------------------------------------
-- Grille
------------------------------------------------------------------------
local grille = CreateFrame("Frame", nil, f)
grille:SetPoint("TOPLEFT", 266, -100)
grille:SetSize(COLONNES * (TUILE_L + ECART), LIGNES * (TUILE_H + ECART))
grille:EnableMouseWheel(true)
local titreGrille = S.Texte(f, "Bold", 11, "gris")
titreGrille:SetPoint("BOTTOMLEFT", grille, "TOPLEFT", 0, 12)

local tuiles = {}
for n = 1, COLONNES * LIGNES do
    local t = CreateFrame("Button", nil, grille)
    t:SetSize(TUILE_L, TUILE_H)
    t:SetPoint("TOPLEFT", ((n - 1) % COLONNES) * (TUILE_L + ECART), -math.floor((n - 1) / COLONNES) * (TUILE_H + ECART))
    t:SetBackdrop({ bgFile = S.BLANC, edgeFile = S.BLANC, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
    t.icone = t:CreateTexture(nil, "ARTWORK")
    t.icone:SetSize(36, 36)
    t.icone:SetPoint("LEFT", 8, 0)
    t.icone:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    t.nom = S.Texte(t, "Regular", 11, "texte")
    t.nom:SetPoint("TOPLEFT", t.icone, "TOPRIGHT", 8, 1)
    t.nom:SetWidth(TUILE_L - 60)
    t.nom:SetHeight(26)
    t.nom:SetJustifyH("LEFT")
    t.nom:SetJustifyV("TOP")
    t.nombre = S.Texte(t, "SemiBold", 11, "ambreClair")
    t.nombre:SetPoint("BOTTOMLEFT", t.icone, "BOTTOMRIGHT", 8, -1)
    t:SetScript("OnClick", function(self)
        if IsModifiedClick("CHATLINK") and ChatFrameEditBox:IsVisible() then
            local _, lien = GetItemInfo(self.id)
            if lien then ChatFrameEditBox:Insert(lien) end
            return
        end
        choisi = self.objet
        Maj()
    end)
    t:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink("item:" .. self.id)
    end)
    t:SetScript("OnLeave", function() GameTooltip:Hide() end)
    tuiles[n] = t
end

------------------------------------------------------------------------
-- Détail
------------------------------------------------------------------------
local detail = CreateFrame("Frame", nil, f)
detail:SetPoint("TOPLEFT", grille, "TOPRIGHT", 12, 0)
detail:SetPoint("BOTTOMRIGHT", -20, 20)
local grandeIcone = detail:CreateTexture(nil, "ARTWORK")
grandeIcone:SetSize(64, 64)
grandeIcone:SetPoint("TOPLEFT")
grandeIcone:SetTexCoord(0.08, 0.92, 0.08, 0.92)
local detailNom = S.Texte(detail, "Bold", 16, "clair")
detailNom:SetPoint("TOPLEFT", grandeIcone, "BOTTOMLEFT", 0, -12)
detailNom:SetWidth(140)
detailNom:SetJustifyH("LEFT")
local detailEtat = S.Texte(detail, "Regular", 13, "gris")
detailEtat:SetPoint("TOPLEFT", detailNom, "BOTTOMLEFT", 0, -8)

------------------------------------------------------------------------
-- Mise à jour
------------------------------------------------------------------------
local function Couleur(qualite)
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[qualite]
    if c then return c.r, c.g, c.b end
    return S.Couleur("texte")
end

local function Visibles()
    local liste = {}
    for _, o in ipairs(S.CATALOGUE[categorie].objets) do
        local nombre = Nombre(o[1])
        local garde = (filtre == 1) or (filtre == 2 and nombre > 0) or (filtre == 3 and nombre == 0)
        if garde and (recherche == "" or o[2]:lower():find(recherche, 1, true)) then table.insert(liste, o) end
    end
    return liste
end

function Maj()
    if not f:IsShown() then return end
    local trouves, tous = 0, 0
    for i, c in ipairs(S.CATALOGUE) do
        local possedes = 0
        for _, o in ipairs(c.objets) do
            if Nombre(o[1]) > 0 then possedes = possedes + 1 end
        end
        trouves, tous = trouves + possedes, tous + #c.objets
        onglets[i].compte:SetText(possedes .. " / " .. #c.objets)
        onglets[i]:Choisir(i == categorie)
    end
    total:SetText(trouves .. " / " .. tous .. " objets possédés")
    plein:SetWidth(math.max(1, 160 * trouves / math.max(1, tous)))
    for i, b in ipairs(filtres) do b:Choisir(i == filtre) end

    local liste = Visibles()
    local maxDecalage = math.max(0, math.ceil(#liste / COLONNES) - LIGNES)
    decalage = math.min(decalage, maxDecalage)
    titreGrille:SetText(S.CATALOGUE[categorie].nom:upper() .. "  ·  " .. #liste .. " objets")
    for n, t in ipairs(tuiles) do
        local o = liste[n + decalage * COLONNES]
        S.Montrer(t, o)
        if o then
            local nombre = Nombre(o[1])
            local a = nombre > 0
            t.id, t.objet = o[1], o
            t.icone:SetTexture(GetItemIcon(o[1]))
            t.icone:SetDesaturated(not a)
            t.icone:SetAlpha(a and 1 or 0.45)
            t.nom:SetText(o[2])
            if a then t.nom:SetTextColor(Couleur(o[3])) else t.nom:SetTextColor(S.Couleur("gris", 0.8)) end
            t.nombre:SetText(a and ("× " .. nombre) or "Pas encore trouvé")
            t.nombre:SetTextColor(S.Couleur(a and "ambreClair" or "gris", a and 1 or 0.7))
            t:SetBackdropColor(0.11, 0.118, 0.133, a and 1 or 0.4)
            t:SetBackdropBorderColor(S.Couleur(choisi == o and "ambre" or "bord"))
        end
    end
    S.Montrer(detail, choisi)
    if choisi then
        local nombre = Nombre(choisi[1])
        grandeIcone:SetTexture(GetItemIcon(choisi[1]))
        grandeIcone:SetDesaturated(nombre == 0)
        detailNom:SetText(choisi[2])
        if nombre > 0 then detailNom:SetTextColor(Couleur(choisi[3])) else detailNom:SetTextColor(S.Couleur("gris")) end
        detailEtat:SetText(nombre > 0 and ("Possédé : " .. nombre) or "Pas encore trouvé")
    end
end

grille:SetScript("OnMouseWheel", function(_, sens)
    decalage = math.max(0, decalage - sens)
    Maj()
end)
f:SetScript("OnShow", function() Maj() end)
f:SetScript("OnHide", function() champ:ClearFocus() end)
S.Ecouter("BAG_UPDATE", function() Maj() end)
