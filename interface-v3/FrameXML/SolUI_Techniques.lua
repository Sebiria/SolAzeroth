-- Sol'Azeroth v3, F4 : deux petites barres de 4 techniques, translucides, en bas au centre, et le losange du passif.
-- Barre du bas : emplacements 1 à 4 de la barre d'action 1 ; barre du haut : 5 à 8. Chaque bouton clique le bouton
-- de Blizzard correspondant (ActionButton1 à 8, rangé mais chargé). Les touches restent celles du menu Raccourcis
-- (« Barre d'action 1 »), que chaque joueur attribue comme il veut, et le bouton affiche la touche choisie. Elles
-- visent nos boutons (voir MajTouches).

local S = SolUI

local TAILLE, ECART = 46, 8
local RIPOSTE = 100014   -- Riposte du rempart : mise en avant quand le Rempart est bien rempli
local SEUIL_RIPOSTE = 0.5
local HEURT = 100019     -- Heurt de bouclier : mis en avant quand la cible incante un sort qu'on peut interrompre (lot 3b)
local TRAIT, TRANSE = 100201, 100223   -- Trait de l'ombre : mis en avant sous la Transe de l'ombre (lot D4)
-- Lot V5 : Envenimer mis en avant quand la cible porte 5 cumuls de ton Poison mortel ; Coup de pied comme le Heurt.
local ENVENIMER, POISON, CUMULS_MAX, COUP_DE_PIED = 100304, 100301, 5, 100305
-- Lot V7 : en Camouflage, le bouton de l'Éventail montre Assommer (le serveur lance Assommer à sa place).
local EVENTAIL, ASSOMMER, CAMOUFLAGE = 100316, 100322, 100308

local function CibleInterruptible()
    if not UnitCanAttack("player", "target") then return false end
    local nom, _, _, _, _, _, _, _, protege = UnitCastingInfo("target")
    if not nom then nom, _, _, _, _, _, _, protege = UnitChannelInfo("target") end
    return nom ~= nil and not protege
end
-- Passif d'identité de chaque spécialisation (lot D2) : Rempart du guerrier tank, Moisson du démoniste Affliction,
-- Toxines du voleur Assassinat (lot V5).
-- Retour de l'utilisateur (02/11/2026) : la taille est bonne, mais le losange manquait de lisibilité. Symbole plus
-- grand et plus épais, fond sombre presque opaque, une couleur par passif.
local PASSIFS = { [1] = { sort = 100009, icone = "Bouclier", couleur = "ambreClair" },
    [2] = { sort = 100200, icone = "Moisson", couleur = "vertClair" },
    [3] = { sort = 100300, icone = "Toxines", couleur = "rougeClair" } }

local function CumulsDePoison()
    local _, _, _, nombre = UnitDebuff("target", GetSpellInfo(POISON) or "", nil, "PLAYER")
    return nombre or 0
end

local groupe = CreateFrame("Frame", "SolUITechniques", S.racine)
groupe:SetSize(26 + 18 + 4 * TAILLE + 3 * ECART + 18 + 26, 2 * TAILLE + ECART)
S.Placer(groupe, "techniques")

-- Barre d'incantation du jeu : au-dessus des techniques, et suit le bloc s'il est déplacé (signalement 26 : le jeu la
-- plaçait sur la deuxième rangée). Retirée des cadres que le jeu replace de lui-même.
UIPARENT_MANAGED_FRAME_POSITIONS["CastingBarFrame"] = nil
CastingBarFrame:ClearAllPoints()
CastingBarFrame:SetPoint("BOTTOM", groupe, "TOP", 0, 18)

------------------------------------------------------------------------
-- Losange du passif
------------------------------------------------------------------------
local passif = CreateFrame("Frame", nil, groupe)
passif:SetSize(38, 38)
passif:SetPoint("BOTTOMLEFT", groupe, "BOTTOMLEFT", -6, 30 + 2)
passif:EnableMouse(true)
local losange = S.Texture(passif, "ARTWORK", "Losange", S.Couleur("ambre"))
losange:SetAllPoints()
local fondLosange = S.Texture(passif, "BACKGROUND", "LosangePlein", 0.04, 0.04, 0.047, 0.88)
fondLosange:SetAllPoints()
local bouclier = S.Texture(passif, "OVERLAY", "Bouclier", S.Couleur("ambre"))   -- l'icône du passif
bouclier:SetSize(20, 20)
bouclier:SetPoint("CENTER")
local textePassif = S.Texte(passif, "Regular", 10, "ambre")
textePassif:SetPoint("TOP", passif, "BOTTOM", 0, -1)
textePassif:SetText("P A S S I F")
passif:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetHyperlink("spell:" .. PASSIFS[S.etat.spe].sort)
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
    return S.ToucheCourte(GetBindingKey("ACTIONBUTTON" .. id))
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
    local assommer = (sort == EVENTAIL or (nom and nom == GetSpellInfo(EVENTAIL)))
        and UnitBuff("player", GetSpellInfo(CAMOUFLAGE) or "") ~= nil
    if assommer then b.icone:SetTexture(select(3, GetSpellInfo(ASSOMMER))) end
    local actif = nom and UnitBuff("player", nom) ~= nil
    S.Montrer(b.point, actif)
    S.Montrer(b.anneauActif, actif)

    local enAvant = not enRecharge and (((sort == RIPOSTE or nom == GetSpellInfo(RIPOSTE))
        and S.etat.rempart and S.etat.plafond > 0 and S.etat.rempart >= SEUIL_RIPOSTE * S.etat.plafond)
        or ((sort == HEURT or nom == GetSpellInfo(HEURT)) and CibleInterruptible())
        or ((sort == COUP_DE_PIED or nom == GetSpellInfo(COUP_DE_PIED)) and CibleInterruptible())
        or ((sort == ENVENIMER or nom == GetSpellInfo(ENVENIMER)) and CumulsDePoison() >= CUMULS_MAX)
        or (assommer and UnitCanAttack("player", "target") and not UnitAffectingCombat("target"))
        or ((sort == TRAIT or nom == GetSpellInfo(TRAIT)) and UnitBuff("player", GetSpellInfo(TRANSE) or "") ~= nil))
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

-- Les touches de la barre d'action 1 visent nos boutons. Sans cela, le jeu les enverrait à la barre de posture du
-- guerrier (BonusActionButton) ou de véhicule dès qu'elle est active, et non aux emplacements 1 à 8. Hors combat
-- seulement : sinon, au premier retour hors combat.
local enAttente = false
local function MajTouches()
    for id, b in ipairs(boutons) do b.touche:SetText(Touche(id)) end
    if InCombatLockdown() then enAttente = true; return end
    enAttente = false
    ClearOverrideBindings(groupe)
    for id = 1, #boutons do
        for _, touche in ipairs({ GetBindingKey("ACTIONBUTTON" .. id) }) do
            SetOverrideBindingClick(groupe, true, touche, "SolUITechnique" .. id)
        end
    end
end
S.Ecouter("PLAYER_REGEN_ENABLED", function() if enAttente then MajTouches() end end)

local function MajPassif()
    local p = PASSIFS[S.etat.spe]
    S.Montrer(passif, p ~= nil)
    if p then
        bouclier:SetTexture(S.TEXTURES .. p.icone)
        bouclier:SetVertexColor(S.Couleur(p.couleur))
        losange:SetVertexColor(S.Couleur(p.couleur))
        textePassif:SetTextColor(S.Couleur(p.couleur))
    end
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
