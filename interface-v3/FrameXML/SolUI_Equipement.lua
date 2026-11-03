-- Sol'Azeroth v3, E1 (31/10/2026) : fenêtre « Équipement » (demande de l'utilisateur : pouvoir fabriquer, acheter et
-- améliorer l'équipement pour tester). Deux onglets :
-- - Fabrication : nos recettes (SolUI_Recettes.lua, généré par outils\equipement_v3.py), payées en composants de la
--   Collection et en or. Maille, bouclier et armes se fabriquent près d'une enclume ou d'une forge.
-- - Amélioration : les pièces portées et celles des sacs, rangs 1 à 5, payées en éclats cadavériques et en or.
-- Le serveur (v3_equipement.cpp, messages SOLEQUIP) dit si l'on est près d'une forge et liste les pièces améliorables
-- avec leur coût ; il vérifie tout avant de fabriquer ou d'améliorer. L'achat se fait chez les marchands de Razor Hill.
-- Une pièce se fabrique en 10 s (31/10/2026) : barre de progression dans la fiche de la recette, au-dessus du bouton
-- Fabriquer (demande de l'utilisateur, elle était au-dessus des barres d'action) ; bouger annule.
-- Catégorie Cuisine (SolUI_Cuisine.lua, généré par outils\cuisine_v3.py) : les plats de la zone, près d'un feu, en 5 s.
-- Désenchantement et Enchantement (31/10/2026, SolUI_Enchantements.lua, généré par outils\enchantement_v3.py) :
-- désenchanter une pièce du sac (second clic pour confirmer) range poussières et essences dans la Collection ;
-- enchanter une pièce portée ou du sac les dépense. Le serveur envoie « PIECE;… » pour chaque armure et arme.
-- Joaillerie (01/11/2026, SolUI_Joaillerie.lua, généré par outils\joaillerie_v3.py) : prospecter le Minerai de cuivre
-- et tailler les gemmes ; les rangs 4 et 5 demandent des pierres taillées. Survoler une pièce de l'onglet Amélioration
-- montre la liste de courses jusqu'aux rangs 4 et 5 (éclats, or, pierres, gemmes brutes et minerai à prospecter).

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

-- Panoplie du Gouffre (lot 4c, v3_equipement.cpp ; 03/11/2026, demande de l'utilisateur : un bonus par ligne, dans la
-- fabrication et dans l'infobulle de chaque pièce). Les pièces bleues se reconnaissent à leur nom, rangs compris
-- (« Heaume du Gouffre +3 ») ; une arme à deux mains compte double, comme sur le serveur.
local PANOPLIE = { { 2, "+ 3 % de dégâts" }, { 4, "− 5 % de dégâts subis" }, { 6, "3 % de vol de vie" } }
local function DuGouffre(lien)
    local nom, _, _, _, _, _, _, _, emplacement = GetItemInfo(lien)
    return nom ~= nil and emplacement ~= "" and nom:find(" du Gouffre") ~= nil, emplacement
end
local function PiecesGouffre()
    local n = 0
    for slot = 1, 19 do
        local lien = GetInventoryItemLink("player", slot)
        if lien then
            local gouffre, emplacement = DuGouffre(lien)
            if gouffre then n = n + (emplacement == "INVTYPE_2HWEAPON" and 2 or 1) end
        end
    end
    return n
end
-- Titre puis un palier par ligne : vert si atteint, gris sinon.
local function LignesPanoplie()
    local portees = PiecesGouffre()
    local lignes = { { "Panoplie du Gouffre (" .. portees .. "/6)", 1, 0.82, 0 } }
    for _, p in ipairs(PANOPLIE) do
        local r, g, b = 0.5, 0.5, 0.5
        if portees >= p[1] then r, g, b = 0.55, 0.77, 0.65 end
        table.insert(lignes, { "(" .. p[1] .. ") Panoplie : " .. p[2], r, g, b })
    end
    return lignes
end
local function InfobullePanoplie(self)
    local _, lien = self:GetItem()
    if not lien or not DuGouffre(lien) then return end
    self:AddLine(" ")
    for _, l in ipairs(LignesPanoplie()) do self:AddLine(l[1], l[2], l[3], l[4]) end
    self:Show()
end
for _, bulle in ipairs({ GameTooltip, ItemRefTooltip, ShoppingTooltip1, ShoppingTooltip2 }) do
    bulle:HookScript("OnTooltipSetItem", InfobullePanoplie)
end

-- Barre de fabrication : « FABRIQUE;objet;secondes », puis « FINI » ou « ANNULE ». Placée dans la fiche plus bas.
local progression = CreateFrame("StatusBar", nil, f)
progression:SetHeight(30)
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
objetProgression:SetPoint("RIGHT", -60, 0)
objetProgression:SetJustifyH("LEFT")
local resteProgression = S.Texte(progression, "Bold", 14, "clair")
local debut, duree = 0, 10
resteProgression:SetPoint("RIGHT", -12, 0)
progression:SetScript("OnUpdate", function(self)
    local part = math.min(1, (GetTime() - debut) / duree)
    self:SetValue(part)
    resteProgression:SetText(S.Nombre(math.max(0, duree * (1 - part)), 1) .. " s")
end)

-- « FORGE;forge 0|1;feu 0|1 », « DEBUT », « OBJ;sac;case;entrée;rang;éclats;or;éclats et or jusqu'au rang 4;
-- éclats et or jusqu'au rang 5 »,
-- « PIECE;sac;case;entrée;InventoryType;enchantement;table de désenchantement », « FIN ».
-- Lot 4b (02/11/2026) : « HAUTE;objet;composant;nombre;prix du plan;plan possédé » après « DEBUT » (recettes hautes), et
-- l'emplacement de la pièce en 12e champ de « OBJ » (transfert de rang).
-- Lot 4c : la variante (0 aucune, 1 Critique, 2 Hâte, 3 Vol de vie) en 13e champ de « OBJ ».
local NOMS_VARIANTES = { "Critique", "Hâte", "Vol de vie" }
local EFFETS_VARIANTES = { "+ 1 % de critique", "+ 2 % de hâte", "0,5 % de vol de vie" }
S.HAUTES = {}
-- Lot 4a (02/11/2026) : prix de Mogra, fournisseuse de matériaux de Razor Hill (v3_fournisseur.cpp) :
-- « PRIX;objet:prix:reste aujourd'hui,… ». Affichés dans les listes de courses.
S.FOURNISSEUR = {}
S.Message("SOLFOURN", function(champs)
    if champs[1] ~= "PRIX" then return end
    wipe(S.FOURNISSEUR)
    for objet, prix, reste in (champs[2] or ""):gmatch("(%d+):(%d+):(%d+)") do
        S.FOURNISSEUR[tonumber(objet)] = { prix = tonumber(prix), reste = tonumber(reste) }
    end
end)

-- « (Mogra : 8 pa) » pour un matériau qu'elle vend, s'il en manque ; vide sinon.
local function ChezMogra(objet, manque)
    local f = S.FOURNISSEUR[objet]
    if not f or manque <= 0 then return "" end
    return "  |cffb4b8bf(Mogra : " .. S.Argent(f.prix) .. ")|r"   -- l'unité ; Mogra est à Razor Hill
end
S.ChezMogra = ChezMogra

S.Message("SOLEQUIP", function(champs)
    if champs[1] == "FABRIQUE" then
        local id = tonumber(champs[2])
        debut, duree = GetTime(), math.max(1, tonumber(champs[3]) or 10)
        objetProgression:SetText("Fabrication : " .. (GetItemInfo(id or 0) or ("objet " .. (id or "?"))))
        progression:SetValue(0)
        progression:Show()
        Maj()
        return
    elseif champs[1] == "FINI" or champs[1] == "ANNULE" then
        progression:Hide()
        Maj()
        return
    end
    if champs[1] == "FORGE" then
        forge = champs[2] == "1"
        feu = champs[3] == "1"
    elseif champs[1] == "DEBUT" then
        recues, armuresRecues = {}, {}
        wipe(S.HAUTES)
    elseif champs[1] == "HAUTE" then
        S.HAUTES[tonumber(champs[2])] = { composant = tonumber(champs[3]), nombre = tonumber(champs[4]) or 1,
            plan = tonumber(champs[5]) or 0, possede = champs[6] == "1" }
    elseif champs[1] == "PIECE" then
        table.insert(armuresRecues, { sac = tonumber(champs[2]), case = tonumber(champs[3]), id = tonumber(champs[4]),
            type = tonumber(champs[5]) or 0, enchantement = tonumber(champs[6]) or 0, table = tonumber(champs[7]) or 0 })
    elseif champs[1] == "OBJ" then
        table.insert(recues, { sac = tonumber(champs[2]), case = tonumber(champs[3]), id = tonumber(champs[4]),
            rang = tonumber(champs[5]) or 0, eclats = tonumber(champs[6]) or 0, prix = tonumber(champs[7]) or 0,
            jusqua = { [4] = { tonumber(champs[8]) or 0, tonumber(champs[9]) or 0 },
                [5] = { tonumber(champs[10]) or 0, tonumber(champs[11]) or 0 } }, emplacement = tonumber(champs[12]) or 0,
            variante = tonumber(champs[13]) or 0 })
    elseif champs[1] == "FIN" then
        pieces, armures = recues, armuresRecues
    end
    if champs[1] ~= "OBJ" and champs[1] ~= "PIECE" and champs[1] ~= "DEBUT" and champs[1] ~= "HAUTE" then Maj() end
end)

-- qualiteDefaut : tant que le jeu n'a pas l'objet en cache (03/11/2026 : les pièces du Gouffre s'affichaient en vert,
-- puis en bleu après un survol).
local function NomObjet(id, defaut, qualiteDefaut)
    local nom, _, qualite = GetItemInfo(id)
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[qualite or qualiteDefaut or 2]
    return nom or defaut or ("objet " .. id), c and c.r or 1, c and c.g or 1, c and c.b or 1
end

local function Infobulle(cadre)
    cadre:SetScript("OnEnter", function(self)
        if not self.id then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink("item:" .. self.id)
        self.compare = nil
    end)
    cadre:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- Comparaison avec la pièce portée en tenant Maj, comme dans les sacs (signalement du 01/11/2026).
    cadre:SetScript("OnUpdate", function(self)
        if not self.id or not GameTooltip:IsOwned(self) then return end
        local compare = IsModifiedClick("COMPAREITEMS") and true or false
        if compare == self.compare then return end
        self.compare = compare
        if compare then
            GameTooltip_ShowCompareItem(GameTooltip)
        else
            ShoppingTooltip1:Hide()
            ShoppingTooltip2:Hide()
            ShoppingTooltip3:Hide()
        end
    end)
end

local function Icone(parent, taille)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(taille, taille)
    b.icone = b:CreateTexture(nil, "ARTWORK")
    b.icone:SetAllPoints()
    b.icone:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.contour = S.ContourRarete(b)
    Infobulle(b)
    return b
end

-- Objet d'une icône : image, infobulle et cadre de rareté.
local function Poser(b, id, icone, qualiteDefaut)
    b.id = id
    b.icone:SetTexture(icone or GetItemIcon(id))
    S.Rarete(b.contour, S.QualiteObjet(id, qualiteDefaut))
end

------------------------------------------------------------------------
-- Onglets
------------------------------------------------------------------------
local pages, onglets, onglet = {}, {}, 1
for i, titre in ipairs({ "Fabrication", "Amélioration", "Désenchantement", "Enchantement", "Joaillerie" }) do
    local o = S.BoutonPlat(f, titre, 130, 36, 13)
    o:SetPoint("TOPLEFT", 24 + (i - 1) * 138, -60)
    o:SetScript("OnClick", function() onglet = i; Maj() end)
    o:Hide()   -- carnets Artisanat et Camp (SolUI_Carnets.lua)
    onglets[i] = o
    local page = CreateFrame("Frame", nil, f)
    page:SetPoint("TOPLEFT", 1, -64)
    page:SetPoint("BOTTOMRIGHT", -1, 1)
    pages[i] = page
end
local filet = S.Texture(f, "ARTWORK", nil, S.Couleur("bord"))
filet:SetPoint("TOPLEFT", 1, -60)
filet:SetPoint("TOPRIGHT", -1, -60)
filet:SetHeight(1)
local etatForge = S.Texte(f, "Regular", 13, "gris")
etatForge:SetPoint("TOPRIGHT", -56, -22)

------------------------------------------------------------------------
-- Page 1 : fabrication
------------------------------------------------------------------------
-- Menu à deux niveaux (01/11/2026, demande de l'utilisateur : la liste allait trop s'allonger) : Rudimentaire (zones
-- de départ), Inhabituel (les vertes), Gouffre (les bleues), puis Cuisine ; dans chacune, sous-catégories tissu, cuir,
-- maille, plaque, armes et boucliers (genre de la recette, 7e champ), les vides cachées. Seul le niveau choisi s'ouvre.
local p1 = pages[1]
local LIGNES_RECETTES = 9   -- lignes visibles ; la liste défile au-delà
local GENRES = { "Tissu", "Cuir", "Maille", "Plaque", "Armes et boucliers" }
local niveaux, categorieDe = {}, {}   -- { nom, sous = { { nom, recettes } } } ; recette -> sa catégorie de S.RECETTES
do
    local index = {}
    for _, c in ipairs(S.RECETTES) do
        local nom = (c.feu or c.surplus) and c.nom or c.gouffre and "Gouffre" or c.nom == "Rudimentaire" and c.nom
            or "Inhabituel"
        local niveau = index[nom]
        if not niveau then
            niveau = { nom = nom, sous = {}, parGenre = {} }
            index[nom] = niveau
            table.insert(niveaux, niveau)
        end
        for _, r in ipairs(c.recettes) do
            categorieDe[r] = c
            local genre = c.feu and c.nom or r[7]
            local sous = niveau.parGenre[genre]
            if not sous then
                sous = { nom = genre, recettes = {} }
                niveau.parGenre[genre] = sous
                table.insert(niveau.sous, sous)
            end
            table.insert(sous.recettes, r)
        end
    end
    local rang = {}
    for i, g in ipairs(GENRES) do rang[g] = i end
    for _, niveau in ipairs(niveaux) do
        table.sort(niveau.sous, function(a, b) return (rang[a.nom] or 0) < (rang[b.nom] or 0) end)
    end
end
local niveauChoisi, sousChoisie, choisie = 1, 1, nil

local boutonsNiveaux, boutonsSous = {}, {}
for i, niveau in ipairs(niveaux) do
    local b = S.BoutonPlat(p1, niveau.nom, 180, 40)
    b:SetScript("OnClick", function() niveauChoisi, sousChoisie, choisie = i, 1, nil; Maj() end)
    boutonsNiveaux[i] = b
end
for n = 1, #GENRES do
    local b = S.BoutonPlat(p1, "", 164, 32, 12)
    b:SetScript("OnClick", function() sousChoisie, choisie = n, nil; Maj() end)
    boutonsSous[n] = b
end

local lignesRecettes = {}
for n = 1, LIGNES_RECETTES do
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
local defilRecettes = S.Liste(p1, lignesRecettes, function() Maj() end)   -- lot 6c
local listeAffichee

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
-- Survol d'un composant (03/11/2026, demande de l'utilisateur) : son infobulle, et où le trouver quand ce n'est pas
-- évident.
local PROVENANCES = {
    [910190] = "Se trouve sur les boss du Gouffre de Ragefeu : 15 % de chances par boss, et une de plus sur le "
        .. "dernier boss tué.",
}
local composants = {}
for n = 1, 4 do
    local c = S.Texte(detail, "Regular", 13, "texte")
    c:SetPoint("TOPLEFT", titreComposants, "BOTTOMLEFT", 0, -8 - (n - 1) * 22)
    c:SetWidth(370)
    c:SetJustifyH("LEFT")
    c.survol = CreateFrame("Frame", nil, detail)
    c.survol:SetPoint("TOPLEFT", c, "TOPLEFT")
    c.survol:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT")
    c.survol:EnableMouse(true)
    c.survol:SetScript("OnEnter", function(self)
        if not self.id then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink("item:" .. self.id)
        if PROVENANCES[self.id] then
            GameTooltip:AddLine(PROVENANCES[self.id], 0.71, 0.72, 0.75, true)
            GameTooltip:Show()
        end
    end)
    c.survol:SetScript("OnLeave", function() GameTooltip:Hide() end)
    composants[n] = c
end
local prixFabrication = S.Texte(detail, "Regular", 13, "texte")
prixFabrication:SetPoint("TOPLEFT", titreComposants, "BOTTOMLEFT", 0, -8 - 4 * 22 - 8)
local fabriquer = S.BoutonPlat(detail, "Fabriquer", 180, 40, 14)
fabriquer:SetPoint("BOTTOMLEFT")
local varianteChoisie = 1
local function AvecVariante(c) return not c.feu and not c.surplus end
fabriquer:SetScript("OnClick", function()
    if not choisie then return end
    local c = categorieDe[choisie]
    SendChatMessage(".equipement fabriquer " .. choisie[1] .. (AvecVariante(c) and (" " .. varianteChoisie) or ""), "SAY")
end)
-- Lot 4c : variante choisie à la fabrication, par pièce portée.
local boutonsVariantes = {}
for v = 1, 3 do
    local bv = S.BoutonPlat(detail, NOMS_VARIANTES[v], 118, 30, 12)
    bv:SetPoint("BOTTOMLEFT", fabriquer, "TOPLEFT", (v - 1) * 126, 44)
    bv:SetScript("OnClick", function() varianteChoisie = v; Maj() end)
    boutonsVariantes[v] = bv
end
local effetVariante = S.Texte(detail, "Regular", 12, "gris")
effetVariante:SetPoint("BOTTOMLEFT", boutonsVariantes[1], "TOPLEFT", 0, 6)
local plan = S.BoutonPlat(detail, "Acheter le plan", 180, 40, 14)
plan:SetPoint("LEFT", fabriquer, "RIGHT", 10, 0)
plan:SetScript("OnClick", function()
    if choisie then SendChatMessage(".equipement plan " .. choisie[1], "SAY") end
end)
local achat = S.Texte(detail, "Regular", 12, "gris")
achat:SetPoint("BOTTOMLEFT", fabriquer, "TOPLEFT", 0, 14)
achat:SetWidth(370)
achat:SetJustifyH("LEFT")
achat:SetText("Ces pièces s'achètent aussi, plus cher, chez les marchands de Razor Hill.")
progression:SetParent(detail)
progression:SetPoint("BOTTOMLEFT", fabriquer, "TOPLEFT", 0, 10)
progression:SetPoint("RIGHT", detail, "RIGHT")

local function MajFabrication()
    local niveau = niveaux[niveauChoisi]
    local y = -16
    for i, b in ipairs(boutonsNiveaux) do
        b:SetPoint("TOPLEFT", 16, y)
        b:Choisir(i == niveauChoisi)
        y = y - 46
        if i == niveauChoisi and #niveau.sous > 1 then
            for n, sb in ipairs(boutonsSous) do
                local sous = niveau.sous[n]
                S.Montrer(sb, sous)
                if sous then
                    sb.texte:SetText(sous.nom)
                    sb:SetPoint("TOPLEFT", 32, y)
                    sb:Choisir(n == sousChoisie)
                    y = y - 38
                end
            end
        end
    end
    if #niveau.sous <= 1 then
        for _, sb in ipairs(boutonsSous) do sb:Hide() end
    end
    local liste = niveau.sous[sousChoisie] and niveau.sous[sousChoisie].recettes or {}
    if liste ~= listeAffichee then defilRecettes:Remonter(); listeAffichee = liste end
    local d = defilRecettes:Regler(#liste)
    for n, l in ipairs(lignesRecettes) do
        local r = liste[n + d]
        S.Montrer(l, r)
        if r then
            l.recette = r
            Poser(l.icone, r[1], nil, (categorieDe[r].gouffre or r[2]:find("du Gouffre")) and 3 or 2)
            l.texte:SetText(r[2])
            l.info:SetText(categorieDe[r].surplus and "Consommable, 1 h" or ("Puissance " .. r[3]))
            l:Choisir(choisie == r)
        end
    end
    S.Montrer(detail, choisie)
    if not choisie then return end
    local r, c = choisie, categorieDe[choisie]
    local qualiteDefaut = (c.gouffre or r[2]:find("du Gouffre")) and 3 or 2
    Poser(grande, r[1], nil, qualiteDefaut)
    detailNom:SetText(r[2])
    detailNom:SetTextColor(select(2, NomObjet(r[1], r[2], qualiteDefaut)))
    detailPuissance:SetText(c.feu and ("Repas de " .. (r[7] or "") .. " : +" .. r[3] .. " pendant 30 min")
        or c.surplus and "Consommable : bonus pendant 1 h" or ("Puissance " .. r[3]))
    for v, bv in ipairs(boutonsVariantes) do
        S.Montrer(bv, AvecVariante(c) and not progression:IsShown())
        bv:Choisir(v == varianteChoisie)
    end
    S.Montrer(effetVariante, AvecVariante(c) and not progression:IsShown())
    effetVariante:SetText("Variante : " .. EFFETS_VARIANTES[varianteChoisie] .. " par pièce portée.")
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
    S.Montrer(achat, not c.feu and not c.gouffre and not c.surplus and not progression:IsShown())   -- les bleues ne se vendent pas
    -- Lot 4b : recette haute, un composant de plus sans son plan.
    local haute = not c.feu and S.HAUTES[r[1]]
    local liste = r[6]
    if haute and not haute.possede then
        liste = { unpack(r[6]) }
        table.insert(liste, { haute.composant, haute.nombre })
    end
    S.Montrer(plan, haute and not haute.possede)
    if haute and not haute.possede then
        plan.texte:SetText("Plan : " .. S.Argent(haute.plan))
        plan:SetAlpha(GetMoney() >= haute.plan and 1 or 0.5)
        table.insert(lignes, "|cffb4b8bfRecette haute : " .. haute.nombre .. " " .. S.NomCollection(haute.composant)
            .. " de plus, ou son plan, acheté une fois.|r")
    elseif haute then
        table.insert(lignes, "|cff8cc4a6Plan appris : pas de composant de plus.|r")
    end
    if c.gouffre then
        table.insert(lignes, " ")
        for _, l in ipairs(LignesPanoplie()) do
            table.insert(lignes, format("|cff%02x%02x%02x%s|r", l[2] * 255, l[3] * 255, l[4] * 255, l[1]))
        end
    end
    conditions:SetText(table.concat(lignes, "\n"))
    for n, ligne in ipairs(composants) do
        local comp = liste[n]
        S.Montrer(ligne, comp)
        S.Montrer(ligne.survol, comp)
        ligne.survol.id = comp and comp[1]
        if comp then
            local a = S.NombreCollection(comp[1])
            tout = tout and a >= comp[2]
            ligne:SetText(S.NomCollection(comp[1]) .. "   " .. hex(a >= comp[2]) .. a .. " / " .. comp[2] .. "|r"
                .. ChezMogra(comp[1], comp[2] - a))
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
local BRAISE, transfert = 910190, nil   -- lot 4b : transfert de rang en attente de confirmation
local intro = S.Texte(p2, "Regular", 13, "gris")
intro:SetPoint("TOPLEFT", 24, -16)
intro:SetWidth(950)
intro:SetJustifyH("LEFT")
intro:SetText("Chaque rang ajoute 10 % aux caractéristiques de la pièce (jusqu'au rang 5) et compte dans ta puissance. "
    .. "Les rangs 4 et 5 demandent aussi des pierres taillées (onglet Joaillerie). Survole une pièce : liste de courses.")
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
    l.transfert = S.BoutonPlat(l, "Transférer", 110, 34, 13)
    l.transfert:SetPoint("RIGHT", l.bouton, "LEFT", -8, 0)
    l.transfert.ligne = l
    l.transfert:SetScript("OnClick", function(self)
        local p, source = self.ligne.piece, self.ligne.source
        if not p or not source then return end
        local nomS, nomC = (NomObjet(source.id)), (NomObjet(p.id))
        transfert = { source = source, cible = p }
        StaticPopupDialogs["SOLUI_TRANSFERT_RANG"].text = "Transférer le rang de " .. nomS .. " (rang " .. source.rang
            .. ") sur " .. nomC .. " ?\n\n" .. nomC .. " passe au rang " .. (source.rang - 1) .. " ; " .. nomS
            .. " revient au rang 0.\nCoût : 1 Braise du Gouffre (tu en as " .. S.NombreCollection(BRAISE) .. ")."
        StaticPopup_Show("SOLUI_TRANSFERT_RANG")
    end)
    lignesPieces[n] = l
end
local defilPieces = S.Liste(p2, lignesPieces, function() Maj() end)   -- lot 6c
local vide = S.Texte(p2, "Regular", 14, "gris")
vide:SetPoint("TOP", 0, -140)
vide:SetText("Aucune pièce améliorable : seules nos pièces (quêtes, fabrication, marchands) ont des rangs.")

-- Lot 4b : transfert de rang (un rang de moins, une Braise du Gouffre), avec aperçu avant confirmation.
StaticPopupDialogs["SOLUI_TRANSFERT_RANG"] = {
    text = "",
    button1 = "Transférer",
    button2 = "Annuler",
    OnAccept = function()
        local d = transfert
        if d then
            SendChatMessage(".equipement transferer " .. d.source.sac .. " " .. d.source.case .. " " .. d.cible.sac .. " "
                .. d.cible.case, "SAY")
        end
    end,
    timeout = 0,
    whileDead = false,
    hideOnEscape = true,
}

-- La pièce de même emplacement dont le rang, moins un, dépasse celui de p (la plus haute), à 5 de puissance au plus
-- (03/11/2026 : le niveau d'objet est le même à tous les rangs ; le serveur vérifie aussi).
local ECART_TRANSFERT = 5
local function SourceDuTransfert(p)
    local meilleure
    local niveau = select(4, GetItemInfo(p.id)) or 0
    for _, q in ipairs(pieces) do
        if q ~= p and q.emplacement == p.emplacement and q.emplacement > 0 and q.rang >= 2 and q.rang - 1 > p.rang
            and math.abs((select(4, GetItemInfo(q.id)) or 0) - niveau) <= ECART_TRANSFERT
            and (not meilleure or q.rang > meilleure.rang) then
            meilleure = q
        end
    end
    return meilleure
end

local function MajAmelioration()
    local eclats = S.NombreCollection(ECLAT)
    soldes:SetText("Éclats cadavériques : " .. eclats .. "     Or : " .. (GetMoney() > 0 and S.Argent(GetMoney()) or "0"))
    local decalage = defilPieces:Regler(#pieces)
    S.Montrer(vide, #pieces == 0)
    for n, l in ipairs(lignesPieces) do
        local p = pieces[n + decalage]
        S.Montrer(l, p)
        if p then
            l.piece = p
            Poser(l.icone, p.id)
            local nom, r, g, b = NomObjet(p.id)
            l.nom:SetText(nom)
            l.nom:SetTextColor(r, g, b)
            l.place:SetText((p.sac == -1 and "Porté" or "Dans le sac")
                .. (NOMS_VARIANTES[p.variante] and ("  ·  " .. NOMS_VARIANTES[p.variante]) or ""))
            l.source = SourceDuTransfert(p)
            S.Montrer(l.transfert, l.source)
            if l.source then l.transfert:SetAlpha(S.NombreCollection(BRAISE) >= 1 and 1 or 0.5) end
            if p.rang >= 5 then
                l.rang:SetText("Rang 5 (maximum)")
                l.cout:SetText("")
                S.Montrer(l.bouton, false)
            else
                l.rang:SetText("Rang " .. p.rang .. "  →  " .. (p.rang + 1))
                local ok = eclats >= p.eclats and GetMoney() >= p.prix
                local texte = (eclats >= p.eclats and "" or "|cfff0918a") .. p.eclats .. " éclats|r   "
                    .. (GetMoney() >= p.prix and "" or "|cfff0918a") .. S.Argent(p.prix) .. "|r"
                for _, pn in ipairs(S.JOAILLERIE.rangs[p.rang + 1] or {}) do
                    local a = S.NombreCollection(pn[1])
                    ok = ok and a >= pn[2]
                    texte = texte .. "   " .. (a >= pn[2] and "" or "|cfff0918a") .. pn[2] .. " " .. S.NomCollection(pn[1]) .. "|r"
                end
                l.cout:SetText(texte)
                S.Montrer(l.bouton, true)
                l.bouton:SetAlpha(ok and 1 or 0.5)
            end
        end
    end
end


-- Liste de courses d'une pièce jusqu'au rang 4 et au rang 5 : éclats, or, pierres taillées, et ce qu'il faut encore
-- tailler (gemmes brutes) et prospecter (minerai) pour les pierres qui manquent. Les gemmes brutes déjà rangées
-- comptent d'abord.
local function Brute(pierre)
    for _, t in ipairs(S.JOAILLERIE.tailles) do
        if t[1] == pierre then return t[3], t[4] end
    end
end

local function Courses(p, cible)
    local lignes = {}
    local hex = function(ok) return ok and "|cff8cc4a6" or "|cfff0918a" end
    local eclats, prix = p.jusqua[cible][1], p.jusqua[cible][2]
    local a = S.NombreCollection(ECLAT)
    table.insert(lignes, hex(a >= eclats) .. eclats .. " éclats cadavériques (tu en as " .. a .. ")|r")
    table.insert(lignes, hex(GetMoney() >= prix) .. S.Argent(prix) .. "|r")
    local pierres, ordre = {}, {}
    for r = p.rang + 1, cible do
        for _, pn in ipairs(S.JOAILLERIE.rangs[r] or {}) do
            if not pierres[pn[1]] then table.insert(ordre, pn[1]) end
            pierres[pn[1]] = (pierres[pn[1]] or 0) + pn[2]
        end
    end
    local brutes, minerai = {}, 0
    for _, pierre in ipairs(ordre) do
        local voulu, possede = pierres[pierre], S.NombreCollection(pierre)
        table.insert(lignes, hex(possede >= voulu) .. voulu .. " " .. S.NomCollection(pierre) .. " (tu en as " .. possede .. ")|r")
        if possede < voulu then
            local brute, par = Brute(pierre)
            if brute then brutes[brute] = (brutes[brute] or 0) + (voulu - possede) * par end
        end
    end
    for brute, voulu in pairs(brutes) do
        local possede = S.NombreCollection(brute)
        local manque = math.max(0, voulu - possede)
        table.insert(lignes, "   à tailler : " .. voulu .. " " .. S.NomCollection(brute) .. " (tu en as " .. possede .. ")")
        -- Prospections à prévoir en moyenne : chaque prospection donne cette gemme avec sa chance.
        for _, gc in ipairs(S.JOAILLERIE.chances) do
            if gc[1] == brute and manque > 0 then
                minerai = minerai + math.ceil(manque * 100 / gc[2]) * S.JOAILLERIE.parProspection
            end
        end
    end
    if minerai > 0 then
        local possede = S.NombreCollection(S.JOAILLERIE.minerai)
        table.insert(lignes, "   à prospecter : environ " .. minerai .. " " .. S.NomCollection(S.JOAILLERIE.minerai)
            .. " (tu en as " .. possede .. ")" .. ChezMogra(S.JOAILLERIE.minerai, minerai - possede))
    end
    return lignes
end
S.CoursesEquipement = Courses

for _, l in ipairs(lignesPieces) do
    l:EnableMouse(true)
    l:SetScript("OnEnter", function(self)
        local p = self.piece
        if not p or p.rang >= 5 then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Liste de courses")
        for cible = math.max(4, p.rang + 1), 5 do
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Jusqu'au rang " .. cible, 1, 0.82, 0)
            for _, ligne in ipairs(Courses(p, cible)) do GameTooltip:AddLine(ligne, 1, 1, 1) end
        end
        GameTooltip:Show()
    end)
    l:SetScript("OnLeave", function() GameTooltip:Hide() end)
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

-- Une page de pièces : intro, lignes de LIGNES qui défilent (S.Liste), texte si vide.
local function PageDePieces(page, texteIntro, texteVide, boutons)
    local p = { lignes = {} }
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
    p.defil = S.Liste(page, p.lignes, function() Maj() end)   -- lot 6c
    p.vide = S.Texte(page, "Regular", 14, "gris")
    p.vide:SetPoint("TOP", 0, -140)
    p.vide:SetText(texteVide)
    return p
end

local function Remplir(p, liste, Ligne)
    local decalage = p.defil:Regler(#liste)
    S.Montrer(p.vide, #liste == 0)
    for n, l in ipairs(p.lignes) do
        local piece = liste[n + decalage]
        S.Montrer(l, piece)
        if piece then
            l.piece = piece
            Poser(l.icone, piece.id)
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
    "Aucune pièce à enchanter : plastron, brassards, cape, bouclier, orbe ou arme.", 1)
-- Une ligne par pièce, et au bout une liste déroulante de ses enchantements, avec leur coût (signalement du
-- 01/11/2026) ; en choisir un l'applique. Grisés : celui en place, et ceux dont il manque des composants ou de l'or.
local deroulantEnchantements = CreateFrame("Frame", "SolUIEnchantementsMenu", UIParent, "UIDropDownMenuTemplate")
for _, l in ipairs(p4.lignes) do
    l.boutons[1]:SetScript("OnClick", function(self)
        local piece = self.ligne.piece
        if not piece then return end
        local menu = { { text = NomObjet(piece.id), isTitle = true, notCheckable = true } }
        for _, e in ipairs(EnchantementsDe(piece.type)) do
            local enPlace = piece.enchantement == e[4]
            local cout, ok = Cout(e)
            table.insert(menu, { text = e[3] .. "  ·  " .. e[2] .. (enPlace and "  (en place)" or "  —  " .. cout),
                notCheckable = true, disabled = enPlace or not ok,
                func = function()
                    SendChatMessage(".equipement enchanter " .. piece.sac .. " " .. piece.case .. " " .. e[1], "SAY")
                end })
        end
        EasyMenu(menu, deroulantEnchantements, self, 0, 0, "MENU")
    end)
end

local function MajEnchantement()
    local liste = {}
    for _, piece in ipairs(armures) do
        if #EnchantementsDe(piece.type) > 0 then table.insert(liste, piece) end
    end
    Remplir(p4, liste, function(l, piece)
        local actuel = piece.enchantement > 0 and EnchantementsDe(piece.type, piece.enchantement)[1]
        l.haut:SetText(actuel and ("Enchantée : " .. actuel[3] .. "  ·  " .. actuel[2])
            or piece.enchantement > 0 and "Enchantée" or "Sans enchantement")
        local effets = {}
        for _, e in ipairs(EnchantementsDe(piece.type)) do table.insert(effets, e[3]) end
        l.bas:SetText("Au choix : " .. table.concat(effets, ", "))
        local b = l.boutons[1]
        b.texte:SetText("Enchanter")
        b:Choisir(false)
        b:SetAlpha(1)
    end)
end

------------------------------------------------------------------------
-- Page 5 : joaillerie (prospection et taille)
------------------------------------------------------------------------
local p5 = pages[5]
local J = S.JOAILLERIE
local introJ = S.Texte(p5, "Regular", 13, "gris")
introJ:SetPoint("TOPLEFT", 24, -16)
introJ:SetWidth(950)
introJ:SetJustifyH("LEFT")
introJ:SetText("Prospecte le minerai pour en tirer des gemmes brutes, puis taille-les. Les pierres taillées servent aux "
    .. "rangs 4 et 5 de l'équipement. Tout se fait partout et se range dans la Collection.")

local function LigneJ(n)
    local l = CreateFrame("Frame", nil, p5)
    l:SetSize(950, 56)
    l:SetPoint("TOPLEFT", 24, -60 - (n - 1) * 64)
    l:SetBackdrop({ bgFile = S.BLANC, edgeFile = S.BLANC, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
    l:SetBackdropColor(0.11, 0.118, 0.133, 1)
    l:SetBackdropBorderColor(S.Couleur("bord"))
    l.icone = Icone(l, 36)
    l.icone:SetPoint("LEFT", 8, 0)
    l.nom = S.Texte(l, "SemiBold", 13, "clair")
    l.nom:SetPoint("TOPLEFT", l.icone, "TOPRIGHT", 10, 0)
    l.nom:SetWidth(600)
    l.nom:SetJustifyH("LEFT")
    l.info = S.Texte(l, "Regular", 11, "gris")
    l.info:SetPoint("BOTTOMLEFT", l.icone, "BOTTOMRIGHT", 10, 0)
    l.info:SetWidth(600)
    l.info:SetJustifyH("LEFT")
    l.bouton = S.BoutonPlat(l, "", 130, 34, 13)
    l.bouton:SetPoint("RIGHT", -8, 0)
    return l
end

local prospecter = LigneJ(1)
prospecter.bouton.texte:SetText("Prospecter")
prospecter.bouton:SetScript("OnClick", function() SendChatMessage(".equipement prospecter", "SAY") end)
local lignesTaille = {}
for n, t in ipairs(J.tailles) do
    local l = LigneJ(n + 1)
    l.bouton.texte:SetText("Tailler")
    l.bouton:SetScript("OnClick", function() SendChatMessage(".equipement tailler " .. t[1], "SAY") end)
    l.taille = t
    lignesTaille[n] = l
end
local rangsJ = S.Texte(p5, "Regular", 13, "texte")
rangsJ:SetPoint("TOPLEFT", 24, -60 - (#J.tailles + 1) * 64 - 8)
rangsJ:SetWidth(950)
rangsJ:SetJustifyH("LEFT")

local function MajJoaillerie()
    local hex = function(ok) return ok and "|cff8cc4a6" or "|cfff0918a" end
    local minerai = S.NombreCollection(J.minerai)
    Poser(prospecter.icone, J.minerai)
    prospecter.nom:SetText("Prospection : " .. J.parProspection .. " " .. S.NomCollection(J.minerai) .. "   "
        .. hex(minerai >= J.parProspection) .. "(tu en as " .. minerai .. ")|r")
    local chances = {}
    for _, gc in ipairs(J.chances) do
        table.insert(chances, S.NomCollection(gc[1]) .. " " .. gc[2] .. " % (" .. S.NombreCollection(gc[1]) .. ")")
    end
    prospecter.info:SetText("Une gemme brute : " .. table.concat(chances, "  ·  "))
    prospecter.bouton:SetAlpha(minerai >= J.parProspection and 1 or 0.5)
    for _, l in ipairs(lignesTaille) do
        local t = l.taille
        local brutes = S.NombreCollection(t[3])
        Poser(l.icone, t[1], GetItemIcon(t[1]) or GetItemIcon(t[3]))
        l.nom:SetText(t[2] .. "   |cffb4b8bf(tu en as " .. S.NombreCollection(t[1]) .. ")|r")
        l.info:SetText("Demande " .. hex(brutes >= t[4]) .. t[4] .. " " .. S.NomCollection(t[3]) .. " (tu en as " .. brutes .. ")|r")
        l.bouton:SetAlpha(brutes >= t[4] and 1 or 0.5)
    end
    local morceaux = {}
    for _, r in ipairs({ 4, 5 }) do
        local liste = {}
        for _, pn in ipairs(J.rangs[r] or {}) do table.insert(liste, pn[2] .. " " .. S.NomCollection(pn[1])) end
        table.insert(morceaux, "Rang " .. r .. " : " .. table.concat(liste, " et "))
    end
    rangsJ:SetText("En plus des éclats et de l'or :  " .. table.concat(morceaux, "   ·   "))
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
    elseif onglet == 4 then MajEnchantement()
    else MajJoaillerie() end
end

-- Carnets (SolUI_Carnets.lua) : page, et catégorie de recettes (la Cuisine du carnet Camp).
function S.PageEquipement(n, nomCategorie)
    onglet = n
    for i, niveau in ipairs(niveaux) do
        if niveau.nom == nomCategorie then niveauChoisi, sousChoisie, choisie = i, 1, nil end
    end
    if f:IsShown() then Maj() end
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
