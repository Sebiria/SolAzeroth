-- Sol'Azeroth v3, F4 : le personnage (maquette Immersif, reprise dans Synthèse).
-- Vie et Rempart en deux arcs fins autour du guerrier, leurs chiffres de chaque côté, puissance sous le Rempart et
-- buffs en pastilles sous la vie.

local S = SolUI

-- Cadre de 300 x 300 centré sur le personnage (maquette : centre en 738, 568 ; le jeu centre le personnage).
local perso = CreateFrame("Frame", "SolUIPerso", S.racine)
perso:SetSize(300, 300)
S.Placer(perso, "perso")
S.perso = perso

------------------------------------------------------------------------
-- Arcs (textures Arc et ArcLarge : 64 x 256 unités, centre du cercle en 128, 128, rayon 125)
------------------------------------------------------------------------
local ARC_X, ARC_Y, ARC_L, ARC_H = 22, 22, 64, 256

local function NouvelArc(droite, r, g, b)
    local arc = {}
    local function Couche(nom, couche, cr, cg, cb, ca)
        local t = S.Texture(perso, couche, nom, cr, cg, cb, ca)
        t:SetSize(ARC_L, ARC_H)
        if droite then
            t:SetPoint("TOPRIGHT", perso, "TOPRIGHT", -ARC_X, -ARC_Y)
            t:SetTexCoord(1, 0, 0, 1)
        else
            t:SetPoint("TOPLEFT", perso, "TOPLEFT", ARC_X, -ARC_Y)
        end
        return t
    end
    arc.ombre = Couche("ArcLarge", "BACKGROUND", 0.04, 0.04, 0.047, 0.5)
    arc.piste = Couche("Arc", "BORDER", r, g, b, droite and 0.18 or 0.14)
    arc.plein = Couche("Arc", "ARTWORK", r, g, b, 1)
    arc.plein:ClearAllPoints()
    arc.plein:SetPoint(droite and "BOTTOMRIGHT" or "BOTTOMLEFT", perso, droite and "BOTTOMRIGHT" or "BOTTOMLEFT",
        droite and -ARC_X or ARC_X, ARC_Y)
    arc.droite = droite

    -- Remplit l'arc de bas en haut : l'arc va de 35° à 145° depuis le bas ; on recadre la texture à la hauteur du
    -- point atteint (cos est monotone sur cet intervalle).
    function arc:Remplir(part)
        part = math.max(0, math.min(1, part or 0))
        if part <= 0 then
            self.plein:Hide()
            return
        end
        local haut = 0
        if part < 0.999 then
            local angle = math.rad(35 + 110 * part)
            haut = 128 + 125 * math.cos(angle) - 2
        end
        local hauteur = ARC_H - haut
        self.plein:SetHeight(hauteur)
        local gauche, droite = 0, 1
        if self.droite then gauche, droite = 1, 0 end
        self.plein:SetTexCoord(gauche, droite, haut / ARC_H, 1)
        self.plein:Show()
    end

    function arc:Montrer(visible)
        S.Montrer(self.ombre, visible)
        S.Montrer(self.piste, visible)
        if not visible then self.plein:Hide() end
    end
    return arc
end

local arcVie = NouvelArc(false, S.Couleur("texte"))
local arcRempart = NouvelArc(true, S.Couleur("ambre"))

------------------------------------------------------------------------
-- Libellés
------------------------------------------------------------------------
local function Libelle(gaucheAligne, titre, couleurTitre, couleurValeur)
    local cadre = CreateFrame("Frame", nil, perso)
    cadre:SetSize(120, 60)
    local justif = gaucheAligne and "LEFT" or "RIGHT"
    local ancre = gaucheAligne and "TOPLEFT" or "TOPRIGHT"
    cadre.titre = S.Texte(cadre, "Regular", 11, couleurTitre, couleurTitre == "texte" and 0.72 or 1)
    cadre.titre:SetPoint(ancre, cadre, ancre, 0, 0)
    cadre.titre:SetJustifyH(justif)
    cadre.titre:SetText(titre)
    cadre.valeur = S.Texte(cadre, "Light", 22, couleurValeur)
    cadre.valeur:SetPoint(ancre, cadre.titre, gaucheAligne and "BOTTOMLEFT" or "BOTTOMRIGHT", 0, -2)
    cadre.valeur:SetJustifyH(justif)
    cadre.max = S.Texte(cadre, "Regular", 12, "texte", 0.72)
    cadre.max:SetPoint(ancre, cadre.valeur, gaucheAligne and "BOTTOMLEFT" or "BOTTOMRIGHT", 0, -1)
    cadre.max:SetJustifyH(justif)
    return cadre
end

-- Maquette : libellé de vie en 483..595 (aligné à droite), Rempart en 881, tous deux à 542 de haut.
local libelleVie = Libelle(false, "V I E", "texte", "texte")
libelleVie:SetPoint("TOPRIGHT", perso, "TOPLEFT", 7, -124)
local libelleRempart = Libelle(true, "R E M P A R T", "ambre", "ambreClair")
libelleRempart:SetPoint("TOPLEFT", perso, "TOPLEFT", 293, -124)

local puissance = S.Texte(perso, "Regular", 12, "texte", 0.8)
puissance:SetPoint("TOPLEFT", perso, "TOPLEFT", 293, -200)

-- F10 (01/11/2026) : jauge d'âme sous la puissance (v3_ame.cpp, messages SOLAME). Violette, rouge sous 25 %. En
-- auberge ou en ville, un clic propose de régénérer avec les éclats cadavériques de la Collection.
local ECLAT = 910120
local VIOLET, VIOLET_CLAIR = { 0.62, 0.45, 0.85 }, { 0.706, 0.549, 0.902 }
local ame = CreateFrame("Button", nil, perso)
ame:SetSize(130, 24)
ame:SetPoint("TOPLEFT", puissance, "BOTTOMLEFT", 0, -6)
ame.texte = S.Texte(ame, "Regular", 12, "texte", 0.8)
ame.texte:SetPoint("TOPLEFT")
ame.piste = S.Texture(ame, "BORDER", nil, VIOLET[1], VIOLET[2], VIOLET[3], 0.18)
ame.piste:SetSize(120, 3)
ame.piste:SetPoint("TOPLEFT", ame.texte, "BOTTOMLEFT", 0, -4)
ame.plein = S.Texture(ame, "ARTWORK", nil, VIOLET[1], VIOLET[2], VIOLET[3], 1)
ame.plein:SetHeight(3)
ame.plein:SetPoint("TOPLEFT", ame.piste, "TOPLEFT")
ame:Hide()

------------------------------------------------------------------------
-- Mise à jour
------------------------------------------------------------------------
local function MajVie()
    local vie, max = UnitHealth("player"), UnitHealthMax("player")
    arcVie:Remplir(max > 0 and vie / max or 0)
    libelleVie.valeur:SetText(S.Nombre(vie))
    libelleVie.max:SetText("/ " .. S.Nombre(max))
end

-- Le Rempart n'existe que pour le guerrier tank (le serveur l'envoie toutes les 2 s au plus tard).
local function MajRempart()
    local montant, plafond = S.etat.rempart, S.etat.plafond
    local visible = S.etat.spe == 1 and montant ~= nil
    arcRempart:Montrer(visible)
    S.Montrer(libelleRempart, visible)
    if visible then
        arcRempart:Remplir(plafond > 0 and montant / plafond or 0)
        libelleRempart.valeur:SetText(S.Nombre(montant))
        libelleRempart.max:SetText("/ " .. S.Nombre(plafond))
    end
    -- Sans Rempart, la puissance prend sa place.
    puissance:ClearAllPoints()
    puissance:SetPoint("TOPLEFT", perso, "TOPLEFT", 293, visible and -200 or -124)
end

local function MajPuissance()
    local valeur = S.etat.puissance
    if not valeur then
        puissance:SetText("")
        return
    end
    local texte = "Puissance |cffe8e9eb" .. S.Nombre(valeur, valeur < 10 and 1 or 0) .. "|r"
    local conseillee = S.PuissanceConseillee()
    if conseillee then texte = texte .. "  |cffb4b8bf/ " .. conseillee .. "|r" end
    puissance:SetText(texte)
end

-- SOLAME : « AME;âme;maximum;perte à la prochaine mort;éclats par point;repos » et « ETEINTE ».
local etatAme = nil

local function PointsRegenerables()
    local e = etatAme
    return math.min(e.max - e.valeur, math.floor(S.NombreCollection(ECLAT) / math.max(1, e.prix)))
end

local function MajAme()
    local e = etatAme
    if not e then ame:Hide(); return end
    local part = e.max > 0 and e.valeur / e.max or 0
    local r, g, b = unpack(part < 0.25 and { S.Couleur("rouge") } or VIOLET)
    ame.texte:SetText("Âme |cffe8e9eb" .. e.valeur .. "|r  |cffb4b8bf/ " .. e.max .. "|r")
    ame.plein:SetVertexColor(r, g, b, 1)
    ame.plein:SetWidth(math.max(0.01, 120 * part))
    S.Montrer(ame.plein, part > 0)
    ame:Show()
end

S.Message("SOLAME", function(champs)
    if champs[1] == "AME" then
        etatAme = { valeur = tonumber(champs[2]) or 0, max = tonumber(champs[3]) or 100, perte = tonumber(champs[4]) or 1,
                    prix = tonumber(champs[5]) or 1, repos = champs[6] == "1" }
        MajAme()
    elseif champs[1] == "ETEINTE" then
        RaidNotice_AddMessage(RaidWarningFrame, "Âme éteinte : ce personnage ne peut plus jouer.",
            ChatTypeInfo["RAID_WARNING"])
    end
end)

StaticPopupDialogs["SOLUI_AME_REGENERER"] = {
    text = "Régénérer %s points d'âme pour %s éclats cadavériques ?",
    button1 = "Régénérer",
    button2 = "Annuler",
    OnAccept = function() SendChatMessage(".ame regenerer", "SAY") end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

ame:SetScript("OnEnter", function(self)
    local e = etatAme
    if not e then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Âme", VIOLET_CLAIR[1], VIOLET_CLAIR[2], VIOLET_CLAIR[3])
    GameTooltip:AddLine("Chaque mort en coûte. À zéro, le personnage est perdu.", 0.91, 0.914, 0.922, true)
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Prochaine mort", "-" .. e.perte, 0.706, 0.722, 0.749, 0.941, 0.569, 0.541)
    GameTooltip:AddDoubleLine("Régénération", e.prix .. " éclats par point", 0.706, 0.722, 0.749, 0.91, 0.914, 0.922)
    GameTooltip:AddDoubleLine("Éclats en Collection", S.Nombre(S.NombreCollection(ECLAT)), 0.706, 0.722, 0.749,
        0.91, 0.914, 0.922)
    GameTooltip:AddLine(" ")
    if e.valeur >= e.max then
        GameTooltip:AddLine("Ton âme est entière.", 0.549, 0.769, 0.651)
    elseif e.repos then
        GameTooltip:AddLine("Clic : régénérer.", 0.965, 0.761, 0.478)
    else
        GameTooltip:AddLine("Régénération en auberge ou en ville.", 0.706, 0.722, 0.749)
    end
    GameTooltip:Show()
end)
ame:SetScript("OnLeave", function() GameTooltip:Hide() end)
ame:SetScript("OnClick", function()
    local e = etatAme
    if not e or e.valeur >= e.max then return end
    if not e.repos then
        UIErrorsFrame:AddMessage("L'âme se régénère en auberge ou en ville.", 1, 0.3, 0.3)
        return
    end
    local points = PointsRegenerables()
    if points <= 0 then
        UIErrorsFrame:AddMessage("Il faut " .. e.prix .. " éclats cadavériques par point d'âme.", 1, 0.3, 0.3)
        return
    end
    StaticPopup_Show("SOLUI_AME_REGENERER", points, S.Nombre(points * e.prix))
end)

S.Ecouter("UNIT_HEALTH", function(_, unite) if unite == "player" then MajVie() end end)
S.Ecouter("UNIT_MAXHEALTH", function(_, unite) if unite == "player" then MajVie() end end)
S.Ecouter("PLAYER_ENTERING_WORLD", function() MajVie(); MajRempart(); MajPuissance() end)
S.Abonner("kit", MajRempart)
S.Abonner("puissance", MajPuissance)
S.Abonner("zone", MajPuissance)

------------------------------------------------------------------------
-- Buffs et débuffs du joueur : pastilles sous le libellé de vie, alignées à droite
------------------------------------------------------------------------
local MAX_PASTILLES = 7
-- Auras représentées ailleurs : le passif et le bouclier du Rempart (arc de droite).
local CACHEES = { [100009] = true, [100010] = true }

local pastilles = {}
local liste = CreateFrame("Frame", nil, perso)
liste:SetSize(150, MAX_PASTILLES * 26)
liste:SetPoint("TOPRIGHT", perso, "TOPLEFT", 7, -200)

for i = 1, MAX_PASTILLES do
    local p = CreateFrame("Button", nil, liste)
    p:SetSize(150, 20)
    p:SetPoint("TOPRIGHT", liste, "TOPRIGHT", 0, -(i - 1) * 26)
    p:RegisterForClicks("RightButtonUp")
    p.rond = S.Texture(p, "BACKGROUND", "Rond", 0.04, 0.04, 0.047, 0.45)
    p.rond:SetSize(20, 20)
    p.rond:SetPoint("RIGHT")
    p.icone = p:CreateTexture(nil, "ARTWORK")
    p.icone:SetSize(16, 16)
    p.icone:SetPoint("CENTER", p.rond, "CENTER")
    p.anneau = S.Texture(p, "OVERLAY", "Anneau", 1, 1, 1, 1)
    p.anneau:SetSize(20, 20)
    p.anneau:SetPoint("CENTER", p.rond, "CENTER")
    p.temps = S.Texte(p, "Regular", 12, "texte", 0.75)
    p.temps:SetPoint("RIGHT", p.rond, "LEFT", -7, 0)
    p.nom = S.Texte(p, "Regular", 12, "texte")
    p.nom:SetPoint("RIGHT", p.temps, "LEFT", -7, 0)
    p:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetUnitAura("player", self.index, self.filtre)
    end)
    p:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- Clic droit : retire un buff (comme sur le cadre de Blizzard).
    p:SetScript("OnClick", function(self)
        if self.filtre == "HELPFUL" then CancelUnitBuff("player", self.index) end
    end)
    p:Hide()
    pastilles[i] = p
end

local function Remplir(p, index, filtre, nom, icone, nombre, fin, nuisible)
    p.index, p.filtre, p.fin = index, filtre, fin
    if nombre and nombre > 1 then nom = nom .. " ×" .. nombre end
    p.nom:SetText(nom)
    SetPortraitToTexture(p.icone, icone)
    if nuisible then
        p.anneau:SetVertexColor(S.Couleur("rouge"))
        p.nom:SetTextColor(S.Couleur("rougeClair"))
    else
        p.anneau:SetVertexColor(S.Couleur("texte", 0.6))
        p.nom:SetTextColor(S.Couleur("texte"))
    end
    p:Show()
end

local function MajPastilles()
    local n = 0
    -- Débuffs d'abord : ce sont eux qu'il faut voir.
    for _, filtre in ipairs({ "HARMFUL", "HELPFUL" }) do
        for index = 1, 40 do
            if n >= MAX_PASTILLES then break end
            local nom, _, icone, nombre, _, _, fin, _, _, _, sort = UnitAura("player", index, filtre)
            if not nom then break end
            if not CACHEES[sort] then
                n = n + 1
                Remplir(pastilles[n], index, filtre, nom, icone, nombre, fin, filtre == "HARMFUL")
            end
        end
    end
    for i = n + 1, MAX_PASTILLES do pastilles[i]:Hide() end
end

S.Ecouter("UNIT_AURA", function(_, unite) if unite == "player" then MajPastilles() end end)
S.Ecouter("PLAYER_ENTERING_WORLD", MajPastilles)

-- Temps restants, deux fois par seconde.
local attente = 0
liste:SetScript("OnUpdate", function(self, ecoule)
    attente = attente - ecoule
    if attente > 0 then return end
    attente = 0.5
    local maintenant = GetTime()
    for _, p in ipairs(pastilles) do
        if p:IsShown() then
            p.temps:SetText(p.fin and p.fin > 0 and S.Duree(math.max(0, p.fin - maintenant)) or "")
        end
    end
end)
