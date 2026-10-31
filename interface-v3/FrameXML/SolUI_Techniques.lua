-- Sol'Azeroth v3, F4 : deux petites barres de 4 techniques, translucides, en bas au centre, et le losange du passif.
-- Barre du bas : emplacements 1 à 4 de la barre d'action 1 ; barre du haut : 5 à 8. Chaque bouton clique le bouton
-- de Blizzard correspondant (ActionButton1 à 8, rangé mais chargé) : les touches restent celles du menu Raccourcis
-- (« Barre d'action 1 »), que chaque joueur attribue comme il veut, et le bouton affiche la touche choisie.

local S = SolUI

local TAILLE, ECART = 46, 8
local RIPOSTE = 100014   -- Riposte du rempart : mise en avant quand le Rempart est bien rempli
local SEUIL_RIPOSTE = 0.5
local PASSIF = 100009

local groupe = CreateFrame("Frame", "SolUITechniques", S.racine)
groupe:SetSize(26 + 18 + 4 * TAILLE + 3 * ECART + 18 + 26, 2 * TAILLE + ECART)
S.Placer(groupe, "techniques")

------------------------------------------------------------------------
-- Losange du passif
------------------------------------------------------------------------
local passif = CreateFrame("Frame", nil, groupe)
passif:SetSize(38, 38)
passif:SetPoint("BOTTOMLEFT", groupe, "BOTTOMLEFT", -6, 30 + 2)
passif:EnableMouse(true)
local losange = S.Texture(passif, "ARTWORK", "Losange", S.Couleur("ambre"))
losange:SetAllPoints()
local fondLosange = S.Texture(passif, "BACKGROUND", "Losange", 0.04, 0.04, 0.047, 0.4)
fondLosange:SetAllPoints()
local bouclier = S.Texture(passif, "OVERLAY", "Bouclier", S.Couleur("ambre"))
bouclier:SetSize(14, 14)
bouclier:SetPoint("CENTER")
local textePassif = S.Texte(passif, "Regular", 10, "ambre")
textePassif:SetPoint("TOP", passif, "BOTTOM", 0, -1)
textePassif:SetText("P A S S I F")
passif:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetHyperlink("spell:" .. PASSIF)
end)
passif:SetScript("OnLeave", function() GameTooltip:Hide() end)

------------------------------------------------------------------------
-- Boutons
------------------------------------------------------------------------
local boutons = {}

local function Blizzard(id) return _G["ActionButton" .. id] end

-- Emplacement d'action réellement utilisé par la touche (page de la barre comprise).
local function Emplacement(id)
    local bouton = Blizzard(id)
    if not bouton then return id end
    return bouton.action or ActionButton_CalculateAction(bouton) or id
end

-- Nom et identifiant du sort posé sur un emplacement (nil pour un objet ou une macro).
local function SortDe(emplacement)
    local genre, id, _, sortGlobal = GetActionInfo(emplacement)
    if genre ~= "spell" then return nil end
    if sortGlobal then return GetSpellInfo(sortGlobal), sortGlobal end
    local nom = id and GetSpellName(id, BOOKTYPE_SPELL)
    return nom, nil
end

local function Touche(id)
    local touche = GetBindingKey("ACTIONBUTTON" .. id)
    if not touche then return "" end
    return GetBindingText(touche, "KEY_", 1)
end

local function NouveauBouton(id)
    local b = CreateFrame("Button", "SolUITechnique" .. id, groupe, "SecureActionButtonTemplate")
    b:SetSize(TAILLE, TAILLE)
    b.id = id
    b:SetAttribute("type", "click")
    b:SetAttribute("clickbutton", Blizzard(id))
    b:RegisterForClicks("AnyUp")
    b:RegisterForDrag("LeftButton", "RightButton")

    b.halo = S.Texture(b, "BACKGROUND", "Halo", S.Couleur("ambre"))
    b.halo:SetSize(TAILLE + 34, TAILLE + 34)
    b.halo:SetPoint("CENTER")
    b.halo:Hide()
    b.anneauActif = S.Texture(b, "BACKGROUND", "BoutonBord", S.Couleur("texte", 0.55))
    b.anneauActif:SetSize(TAILLE + 8, TAILLE + 8)
    b.anneauActif:SetPoint("CENTER")
    b.anneauActif:Hide()
    b.fond = S.Texture(b, "BORDER", "Bouton")
    b.fond:SetAllPoints()
    b.icone = b:CreateTexture(nil, "ARTWORK")
    b.icone:SetSize(TAILLE - 12, TAILLE - 12)
    b.icone:SetPoint("CENTER")
    b.icone:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.voile = S.Texture(b, "OVERLAY", "Bouton", 0.031, 0.031, 0.039, 0.66)
    b.voile:SetAllPoints()
    b.bord = S.Texture(b, "OVERLAY", "BoutonBord")
    b.bord:SetAllPoints()

    -- Les textes vont sur un cadre au-dessus des textures du bouton.
    local dessus = CreateFrame("Frame", nil, b)
    dessus:SetAllPoints()
    dessus:SetFrameLevel(b:GetFrameLevel() + 2)
    b.recharge = S.Texte(dessus, "Regular", 17, "clair")
    b.recharge:SetPoint("CENTER")
    b.touche = S.Texte(dessus, "Regular", 10, "texte", 0.8)
    b.touche:SetPoint("TOPLEFT", b, "TOPLEFT", 4, -2)
    b.point = S.Texture(dessus, "OVERLAY", "Rond", S.Couleur("texte"))
    b.point:SetSize(5, 5)
    b.point:SetPoint("TOPRIGHT", b, "TOPRIGHT", -4, -5)
    b.point:Hide()
    b.nombre = S.Texte(dessus, "SemiBold", 11, "clair")
    b.nombre:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 3)

    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        if HasAction(Emplacement(self.id)) then GameTooltip:SetAction(Emplacement(self.id)) end
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- Glisser-déposer : comme les barres de Blizzard (Maj enfoncée si les barres sont verrouillées).
    b:SetScript("OnDragStart", function(self)
        if LOCK_ACTIONBAR ~= "1" or IsModifiedClick("PICKUPACTION") then
            PickupAction(Emplacement(self.id))
        end
    end)
    b:SetScript("OnReceiveDrag", function(self)
        PlaceAction(Emplacement(self.id))
    end)
    b:SetScript("OnMouseDown", function(self) self.enfonce = true end)
    b:SetScript("OnMouseUp", function(self) self.enfonce = false end)
    return b
end

for id = 1, 8 do
    local b = NouveauBouton(id)
    -- Barre du bas : 1 à 4 ; barre du haut : 5 à 8.
    local colonne, ligne = (id - 1) % 4, id <= 4 and 0 or 1
    b:SetPoint("BOTTOMLEFT", groupe, "BOTTOMLEFT", 26 + 18 + colonne * (TAILLE + ECART), ligne * (TAILLE + ECART))
    boutons[id] = b
end

-- Touche enfoncée au clavier : l'enfoncement se voit aussi sur notre bouton.
hooksecurefunc("ActionButtonDown", function(id) if boutons[id] then boutons[id].enfonce = true end end)
hooksecurefunc("ActionButtonUp", function(id) if boutons[id] then boutons[id].enfonce = false end end)

------------------------------------------------------------------------
-- États : vide, prête, en recharge, active, hors de portée, mise en avant
------------------------------------------------------------------------
local function Etat(b)
    local emplacement = Emplacement(b.id)
    if not HasAction(emplacement) then
        b.icone:Hide()
        b.voile:Hide()
        b.recharge:SetText("")
        b.nombre:SetText("")
        b.halo:Hide()
        b.point:Hide()
        b.anneauActif:Hide()
        b.fond:SetVertexColor(0.04, 0.04, 0.047, 0.25)
        b.bord:SetVertexColor(S.Couleur("texte", 0.12))
        return
    end

    b.icone:SetTexture(GetActionTexture(emplacement))
    b.icone:Show()
    local nombre = GetActionCount(emplacement)
    b.nombre:SetText((IsConsumableAction(emplacement) or IsStackableAction(emplacement)) and nombre or "")

    -- Recharge : le temps global (1,5 s au plus) ne voile pas le bouton.
    local debut, duree, active = GetActionCooldown(emplacement)
    local reste = (active == 1 and duree and duree > 1.5) and (debut + duree - GetTime()) or 0
    local enRecharge = reste > 0
    S.Montrer(b.voile, enRecharge)
    b.recharge:SetText(enRecharge and (reste >= 60 and S.Duree(reste) or math.ceil(reste)) or "")

    local nom, sort = SortDe(emplacement)
    local actif = nom and UnitBuff("player", nom) ~= nil
    S.Montrer(b.point, actif)
    S.Montrer(b.anneauActif, actif)

    local enAvant = (sort == RIPOSTE or nom == GetSpellInfo(RIPOSTE)) and not enRecharge
        and S.etat.rempart and S.etat.plafond > 0 and S.etat.rempart >= SEUIL_RIPOSTE * S.etat.plafond
    if enAvant then
        b.halo:Show()
        b.halo:SetAlpha(0.45 + 0.35 * math.sin(GetTime() * math.pi / 1.2))
        b.fond:SetVertexColor(S.Couleur("ambre", 0.14))
        b.bord:SetVertexColor(S.Couleur("ambre"))
        b.touche:SetTextColor(S.Couleur("ambreClair"))
    else
        b.halo:Hide()
        if enRecharge then
            b.fond:SetVertexColor(0.04, 0.04, 0.047, 0.38)
            b.bord:SetVertexColor(S.Couleur("texte", 0.22))
        else
            b.fond:SetVertexColor(S.Couleur("texte", b.enfonce and 0.22 or 0.08))
            b.bord:SetVertexColor(S.Couleur("texte", b.enfonce and 0.9 or 0.6))
        end
        b.touche:SetTextColor(S.Couleur("texte", 0.8))
    end

    -- Hors de portée : icône rougie ; inutilisable : icône éteinte.
    local utilisable, manque = IsUsableAction(emplacement)
    if IsActionInRange(emplacement) == 0 then
        b.icone:SetVertexColor(0.85, 0.35, 0.32)
    elseif utilisable or manque then
        b.icone:SetVertexColor(1, 1, 1)
    else
        b.icone:SetVertexColor(0.45, 0.45, 0.45)
    end
    b.icone:SetAlpha(enRecharge and 0.6 or 0.9)
end

local function MajTouches()
    for id, b in ipairs(boutons) do b.touche:SetText(Touche(id)) end
end

local function MajPassif()
    S.Montrer(passif, S.etat.spe == 1)
end

S.Ecouter("UPDATE_BINDINGS", MajTouches)
S.Ecouter("PLAYER_ENTERING_WORLD", function() MajTouches(); MajPassif() end)
S.Abonner("kit", MajPassif)
MajPassif()

-- Dix fois par seconde : recharges, portée, halo.
local attente = 0
groupe:SetScript("OnUpdate", function(self, ecoule)
    attente = attente - ecoule
    if attente > 0 then return end
    attente = 0.1
    for _, b in ipairs(boutons) do Etat(b) end
end)
