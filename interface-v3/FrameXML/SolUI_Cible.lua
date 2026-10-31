-- Sol'Azeroth v3, F4 : la cible (maquette Tactique, reprise dans Synthèse), en haut au centre.
-- Élite, nom, puissance et malus, vie en chiffres et en %, incantation très visible, débuffs grands et chronométrés.

local S = SolUI

-- Tout suit la largeur du cadre (réglable : S.DISPOSITION.cible) ; les débuffs affichés sont ceux qui y tiennent.
local MARGE = 18
local LARGEUR_DEBUFF, ECART_DEBUFF = 214, 12
local MAX_DEBUFFS = 6

local cible = CreateFrame("Frame", "SolUICible", S.racine)
S.Placer(cible, "cible")
S.Panneau(cible, 0.92)
cible:Hide()

------------------------------------------------------------------------
-- En-tête : [ÉLITE] Nom  puissance             vie / max   62 %
------------------------------------------------------------------------
local etiquette = CreateFrame("Frame", nil, cible)
etiquette:SetSize(48, 19)
etiquette:SetPoint("TOPLEFT", cible, "TOPLEFT", MARGE, -18)
etiquette:SetBackdrop({ edgeFile = S.BLANC, edgeSize = 1 })
etiquette:SetBackdropBorderColor(0.416, 0.435, 0.471)
etiquette.texte = S.Texte(etiquette, "Bold", 11, "texte")
etiquette.texte:SetPoint("CENTER", 0, 0)

local nom = S.Texte(cible, "Bold", 22, "clair")
nom:SetJustifyH("LEFT")
local puissance = S.Texte(cible, "Regular", 13, "gris")
puissance:SetPoint("BOTTOMLEFT", nom, "BOTTOMRIGHT", 12, 2)

-- Contour de 2 px à la couleur de la difficulté (31/10/2026, demande de l'utilisateur), d'après l'écart entre la
-- puissance du monstre et celle du personnage : gris (bien plus faible), vert, jaune (à sa mesure), orange, rouge.
local contour = CreateFrame("Frame", nil, cible)
contour:SetAllPoints()
contour:SetBackdrop({ edgeFile = S.BLANC, edgeSize = 2 })
contour:Hide()
local DIFFICULTES = {
    { 5, { 0.886, 0.243, 0.227 } },    -- rouge : 5 points de plus ou davantage
    { 3, { 1, 0.502, 0.251 } },        -- orange
    { -2, { 1, 0.82, 0 } },            -- jaune
    { -5, { 0.251, 0.749, 0.251 } },   -- vert
}
function S.CouleurDifficulte(ecart)
    for _, d in ipairs(DIFFICULTES) do
        if ecart >= d[1] then return d[2][1], d[2][2], d[2][3] end
    end
    return 0.5, 0.5, 0.5
end

local pourcent = S.Texte(cible, "Bold", 24, "vertClair")
pourcent:SetPoint("TOPRIGHT", cible, "TOPRIGHT", -MARGE, -14)

------------------------------------------------------------------------
-- Barre de vie, graduée aux quarts
------------------------------------------------------------------------
local barre = CreateFrame("StatusBar", nil, cible)
barre:SetHeight(18)
barre:SetPoint("TOPLEFT", cible, "TOPLEFT", MARGE, -50)
barre:SetPoint("TOPRIGHT", cible, "TOPRIGHT", -MARGE, -50)
barre:SetStatusBarTexture(S.BLANC)
barre:SetStatusBarColor(S.Couleur("vert"))
barre:SetBackdrop({ bgFile = S.BLANC, edgeFile = S.BLANC, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
barre:SetBackdropColor(S.Couleur("creux"))
barre:SetBackdropBorderColor(S.Couleur("bordCreux"))
-- Vie en chiffres dans la barre : à côté du nom, elle chevauchait le malus (capture du 31/10/2026).
local dessusBarre = CreateFrame("Frame", nil, barre)
dessusBarre:SetAllPoints()
dessusBarre:SetFrameLevel(barre:GetFrameLevel() + 2)
local vie = S.Texte(dessusBarre, "SemiBold", 12, "clair")
vie:SetPoint("CENTER", 0, 0)
local traits = {}
for i, alpha in ipairs({ 0.5, 0.5, 0.18 }) do
    local trait = barre:CreateTexture(nil, "OVERLAY")
    trait:SetTexture(i == 3 and 1 or 0, i == 3 and 1 or 0, i == 3 and 1 or 0, alpha)
    trait:SetSize(1, 18)
    traits[i] = trait
end

------------------------------------------------------------------------
-- Incantation
------------------------------------------------------------------------
local incantation = CreateFrame("Frame", nil, cible)
incantation:SetHeight(30)
incantation:SetPoint("TOPLEFT", barre, "BOTTOMLEFT", 0, -12)
incantation:SetPoint("TOPRIGHT", barre, "BOTTOMRIGHT", 0, -12)
incantation:Hide()
local motIncante = S.Texte(incantation, "Bold", 11, "rougeClair")
motIncante:SetPoint("LEFT")
local barreIncante = CreateFrame("StatusBar", nil, incantation)
barreIncante:SetPoint("TOPLEFT", incantation, "TOPLEFT", 76, 0)
barreIncante:SetPoint("BOTTOMRIGHT")
barreIncante:SetStatusBarTexture(S.BLANC)
barreIncante:SetStatusBarColor(S.Couleur("rouge"))
barreIncante:SetBackdrop({ bgFile = S.BLANC, edgeFile = S.BLANC, edgeSize = 2, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
barreIncante:SetBackdropColor(0.165, 0.094, 0.086)
barreIncante:SetBackdropBorderColor(S.Couleur("rouge"))
local sortIncante = S.Texte(barreIncante, "Bold", 16, "clair")
sortIncante:SetPoint("LEFT", 12, 0)
local pourcentIncante = S.Texte(barreIncante, "Bold", 15, "clair")
pourcentIncante:SetPoint("RIGHT", -12, 0)

------------------------------------------------------------------------
-- Débuffs
------------------------------------------------------------------------
local debuffs = {}
local rangee = CreateFrame("Frame", nil, cible)
rangee:SetHeight(58)

for i = 1, MAX_DEBUFFS do
    local d = CreateFrame("Frame", nil, rangee)
    d:SetSize(LARGEUR_DEBUFF, 58)
    d:SetPoint("TOPLEFT", rangee, "TOPLEFT", (i - 1) * (LARGEUR_DEBUFF + ECART_DEBUFF), 0)
    d:SetBackdrop({ bgFile = S.BLANC, edgeFile = S.BLANC, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
    d:SetBackdropColor(0.11, 0.118, 0.133)
    d:SetBackdropBorderColor(S.Couleur("bordCreux"))
    d:EnableMouse(true)

    local cadreIcone = CreateFrame("Frame", nil, d)
    cadreIcone:SetSize(46, 46)
    cadreIcone:SetPoint("LEFT", 6, 0)
    cadreIcone:SetBackdrop({ edgeFile = S.BLANC, edgeSize = 1 })
    cadreIcone:SetBackdropBorderColor(S.Couleur("bleu"))
    d.icone = cadreIcone:CreateTexture(nil, "ARTWORK")
    d.icone:SetPoint("TOPLEFT", 1, -1)
    d.icone:SetPoint("BOTTOMRIGHT", -1, 1)
    d.icone:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    d.cadreIcone = cadreIcone

    -- Pastille des cumuls, en bas à droite de l'icône.
    d.pile = CreateFrame("Frame", nil, cadreIcone)
    d.pile:SetSize(20, 20)
    d.pile:SetPoint("CENTER", cadreIcone, "BOTTOMRIGHT", -4, 4)
    d.pile:SetFrameLevel(cadreIcone:GetFrameLevel() + 2)
    local rond = S.Texture(d.pile, "ARTWORK", "Rond", S.Couleur("clair"))
    rond:SetAllPoints()
    d.pile.texte = S.Texte(d.pile, "Bold", 11, "fond")
    d.pile.texte:SetShadowOffset(0, 0)
    d.pile.texte:SetPoint("CENTER", 0, 0)

    d.nom = S.Texte(d, "SemiBold", 14, "clair")
    d.nom:SetPoint("TOPLEFT", cadreIcone, "TOPRIGHT", 10, -3)
    d.nom:SetWidth(110)
    d.nom:SetJustifyH("LEFT")
    d.detail = S.Texte(d, "Regular", 12, "gris")
    d.detail:SetPoint("TOPLEFT", d.nom, "BOTTOMLEFT", 0, -2)
    d.duree = CreateFrame("StatusBar", nil, d)
    d.duree:SetSize(110, 4)
    -- Sous le détail (« Par toi », cumuls) : ancrée en bas de l'icône, elle le chevauchait (essai du 31/10/2026).
    d.duree:SetPoint("TOPLEFT", d.detail, "BOTTOMLEFT", 0, -5)
    d.duree:SetStatusBarTexture(S.BLANC)
    d.duree:SetStatusBarColor(S.Couleur("bleu"))
    d.duree:SetBackdrop({ bgFile = S.BLANC })
    d.duree:SetBackdropColor(S.Couleur("creux"))
    d.temps = S.Texte(d, "Bold", 20, "clair")
    d.temps:SetPoint("RIGHT", d, "RIGHT", -10, 0)

    d:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetUnitDebuff("target", self.index)
    end)
    d:SetScript("OnLeave", function() GameTooltip:Hide() end)
    d:Hide()
    debuffs[i] = d
end

------------------------------------------------------------------------
-- Mise à jour
------------------------------------------------------------------------
-- Nombre de débuffs qui tiennent dans la largeur du cadre.
local function DebuffsVisibles()
    local place = (cible:GetWidth() or 0) - 2 * MARGE + ECART_DEBUFF
    return math.max(1, math.min(MAX_DEBUFFS, math.floor(place / (LARGEUR_DEBUFF + ECART_DEBUFF))))
end

local function Disposer()
    local hauteur = 50 + 18
    local dernier = barre
    if incantation:IsShown() then
        hauteur = hauteur + 12 + 30
        dernier = incantation
    end
    rangee:ClearAllPoints()
    rangee:SetPoint("TOPLEFT", dernier, "BOTTOMLEFT", 0, -12)
    rangee:SetPoint("TOPRIGHT", dernier, "BOTTOMRIGHT", 0, -12)
    if rangee:IsShown() then hauteur = hauteur + 12 + 58 end
    cible:SetHeight(hauteur + 16)
end

local function MajEntete()
    local classement = UnitClassification("target")
    local texte = (classement == "worldboss" and "BOSS") or ((classement == "elite" or classement == "rareelite") and "ÉLITE")
        or (classement == "rare" and "RARE") or nil
    -- Le nom se place depuis le cadre lui-même (une ancre sur l'étiquette cachée le faisait disparaître).
    local decalage = 0
    nom:ClearAllPoints()
    if texte then
        etiquette.texte:SetText(texte)
        etiquette:SetWidth(etiquette.texte:GetStringWidth() + 12)
        etiquette:Show()
        decalage = etiquette:GetWidth() + 10
    else
        etiquette:Hide()
    end
    nom:SetPoint("TOPLEFT", cible, "TOPLEFT", MARGE + decalage, -16)
    nom:SetText(UnitName("target") or "")
    nom:SetTextColor(S.Couleur(UnitIsEnemy("player", "target") and "clair" or "texte"))
end

-- Puissance de la cible et malus du joueur contre elle (v3_combat.cpp), seulement pour un monstre.
local function MajPuissance()
    local valeur = S.etat.ciblePuissance
    if not valeur or not UnitExists("target") or UnitIsPlayer("target") then
        puissance:SetText("")
        contour:Hide()
        return
    end
    contour:SetBackdropBorderColor(S.CouleurDifficulte(valeur - (S.etat.puissance or 0)))
    contour:Show()
    local texte = "Puissance " .. S.Nombre(valeur)
    if S.etat.cibleMalus and S.etat.cibleMalus > 0 then
        texte = texte .. "   |cfff0918a−" .. S.Nombre(S.etat.cibleMalus) .. " % de dégâts|r"
    end
    puissance:SetText(texte)
end

local function MajVie()
    local valeur, max = UnitHealth("target"), UnitHealthMax("target")
    barre:SetMinMaxValues(0, math.max(1, max))
    barre:SetValue(valeur)
    if UnitIsDead("target") then
        pourcent:SetText("Mort")
        pourcent:SetTextColor(S.Couleur("gris"))
    else
        pourcent:SetText(math.floor(100 * valeur / math.max(1, max) + 0.5) .. " %")
        pourcent:SetTextColor(S.Couleur("vertClair"))
    end
    vie:SetText(S.Nombre(valeur) .. " / " .. S.Nombre(max))
    -- Monstre déjà pris par un autre : barre grise.
    if UnitIsTapped("target") and not UnitIsTappedByPlayer("target") then
        barre:SetStatusBarColor(0.45, 0.45, 0.45)
    else
        barre:SetStatusBarColor(S.Couleur("vert"))
    end
end

local function MajDebuffs()
    local n = 0
    for index = 1, 40 do
        if n >= DebuffsVisibles() then break end
        local nomSort, _, icone, nombre, _, duree, fin, lanceur = UnitDebuff("target", index)
        if not nomSort then break end
        n = n + 1
        local d = debuffs[n]
        d.index, d.dureeTotale, d.fin = index, duree, fin
        d.icone:SetTexture(icone)
        d.nom:SetText(nomSort)
        S.Montrer(d.pile, nombre and nombre > 1)
        d.pile.texte:SetText(nombre and nombre > 1 and ("×" .. nombre) or "")
        local detail = (lanceur == "player" or lanceur == "pet") and "Par toi" or ""
        if nombre and nombre > 1 then detail = nombre .. " cumuls" end
        d.detail:SetText(detail)
        S.Montrer(d.duree, duree and duree > 0)
        d.duree:SetMinMaxValues(0, math.max(0.1, duree or 1))
        d:Show()
    end
    for i = n + 1, MAX_DEBUFFS do debuffs[i]:Hide() end
    S.Montrer(rangee, n > 0)
    Disposer()
end

local function MajIncantation()
    local sort, _, _, _, debut, fin, _, _, insensible = UnitCastingInfo("target")
    local mot = "INCANTE"
    if not sort then
        sort, _, _, _, debut, fin, _, insensible = UnitChannelInfo("target")
        mot = "CANALISE"
    end
    local avant = incantation:IsShown()
    if sort then
        incantation.debut, incantation.fin, incantation.canalise = debut / 1000, fin / 1000, mot == "CANALISE"
        motIncante:SetText(mot)
        sortIncante:SetText(sort)
        -- Incantation qu'on ne peut pas interrompre : bordure grise.
        barreIncante:SetBackdropBorderColor(S.Couleur(insensible and "gris" or "rouge"))
        incantation:Show()
    else
        incantation:Hide()
    end
    if avant ~= incantation:IsShown() then Disposer() end
end

incantation:SetScript("OnUpdate", function(self)
    local duree = math.max(0.001, self.fin - self.debut)
    local part = math.max(0, math.min(1, (GetTime() - self.debut) / duree))
    if self.canalise then part = 1 - part end
    barreIncante:SetMinMaxValues(0, 1)
    barreIncante:SetValue(part)
    pourcentIncante:SetText(math.floor(part * 100) .. " %")
end)

local attente = 0
rangee:SetScript("OnUpdate", function(self, ecoule)
    attente = attente - ecoule
    if attente > 0 then return end
    attente = 0.1
    local maintenant = GetTime()
    for _, d in ipairs(debuffs) do
        if d:IsShown() and d.fin and d.fin > 0 then
            local reste = math.max(0, d.fin - maintenant)
            d.duree:SetValue(reste)
            d.temps:SetText(S.Duree(reste))
        elseif d:IsShown() then
            d.temps:SetText("")
        end
    end
end)

local function MajTout()
    if not UnitExists("target") then
        -- Mode édition de l'interface : un aperçu vide, pour placer le cadre sans cible.
        if S.EnEdition and S.EnEdition() then
            etiquette:Hide()
            nom:ClearAllPoints()
            nom:SetPoint("TOPLEFT", cible, "TOPLEFT", MARGE, -16)
            nom:SetText("Cible")
            puissance:SetText("")
            vie:SetText("")
            pourcent:SetText("")
            barre:SetMinMaxValues(0, 1)
            barre:SetValue(1)
            incantation:Hide()
            rangee:Hide()
            Disposer()
            cible:Show()
        else
            cible:Hide()
        end
        return
    end
    MajEntete()
    MajVie()
    MajPuissance()
    MajIncantation()
    MajDebuffs()
    cible:Show()
end

-- Largeur changée (réglages) : graduations et débuffs suivent.
cible:SetScript("OnSizeChanged", function(self, largeur)
    for i, trait in ipairs(traits) do
        trait:ClearAllPoints()
        trait:SetPoint("TOPLEFT", barre, "TOPLEFT", (largeur - 2 * MARGE) * i / 4, 0)
    end
    if self:IsShown() then MajDebuffs() end
end)
cible:GetScript("OnSizeChanged")(cible, cible:GetWidth())

S.RafraichirCible = MajTout
-- La puissance reçue est celle de l'ancienne cible : on l'oublie jusqu'au message du serveur, qui part aussitôt.
S.Ecouter("PLAYER_TARGET_CHANGED", function() S.etat.ciblePuissance, S.etat.cibleMalus = nil, 0 end)
S.Ecouter("PLAYER_TARGET_CHANGED", MajTout)
S.Ecouter("PLAYER_ENTERING_WORLD", MajTout)
S.Ecouter("UNIT_HEALTH", function(_, unite) if unite == "target" then MajVie() end end)
S.Ecouter("UNIT_MAXHEALTH", function(_, unite) if unite == "target" then MajVie() end end)
S.Ecouter("UNIT_AURA", function(_, unite) if unite == "target" then MajDebuffs() end end)
S.Ecouter("UNIT_CLASSIFICATION_CHANGED", function(_, unite) if unite == "target" then MajEntete() end end)
S.Ecouter("UNIT_NAME_UPDATE", function(_, unite) if unite == "target" then MajEntete() end end)
for _, evenement in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED",
        "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START",
        "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_CHANNEL_STOP" }) do
    S.Ecouter(evenement, function(_, unite) if unite == "target" then MajIncantation() end end)
end
S.Abonner("puissance", MajPuissance)
