-- Sol'Azeroth v3 (31/10/2026) : potion et feu de camp, deux boutons à droite des barres de techniques, dans le même
-- style (demande de l'utilisateur). Ils lancent directement les sorts du module (v3_bivouac.cpp) : la Potion de soins
-- montre ses charges, le Feu de camp sa recharge.

local S = SolUI

local TAILLE, ECART = 46, 8
local POTION, FEU = 100029, 100030

S.etat.charges, S.etat.chargesMax = nil, 0

-- SOLBIV (v3_bivouac.cpp) : « ETAT;charges;charges max ».
S.Message("SOLBIV", function(champs)
    if champs[1] ~= "ETAT" then return end
    S.etat.charges = tonumber(champs[2])
    S.etat.chargesMax = tonumber(champs[3]) or 0
    -- Secondes avant le Repos au coin du feu (0 : pas assis près de son feu).
    local restant = tonumber(champs[4]) or 0
    S.etat.reposFin = restant > 0 and (GetTime() + restant) or nil
end)

-- Compte à rebours au-dessus des techniques, tant qu'on est assis près de son feu (demande de l'utilisateur).
local DUREE_AVANT_REPOS = 60
local rebours = CreateFrame("Frame", "SolUIReboursFeu", SolUITechniques)
rebours:SetSize(300, 40)
rebours:SetPoint("BOTTOM", SolUITechniques, "TOP", 0, 14)
S.Panneau(rebours, 0.88)
rebours:Hide()
local reboursTexte = S.Texte(rebours, "SemiBold", 13, "clair")
reboursTexte:SetPoint("TOP", 0, -7)
local reboursFond = S.Texture(rebours, "ARTWORK", nil, S.Couleur("creux"))
reboursFond:SetPoint("BOTTOMLEFT", 10, 7)
reboursFond:SetPoint("BOTTOMRIGHT", -10, 7)
reboursFond:SetHeight(4)
local reboursBarre = S.Texture(rebours, "OVERLAY", nil, S.Couleur("ambre"))
reboursBarre:SetPoint("TOPLEFT", reboursFond, "TOPLEFT")
reboursBarre:SetPoint("BOTTOMLEFT", reboursFond, "BOTTOMLEFT")

local function MajRebours()
    local reste = S.etat.reposFin and (S.etat.reposFin - GetTime()) or 0
    if reste <= 0 then rebours:Hide(); return end
    rebours:Show()
    reboursTexte:SetText("Repos au coin du feu et potions dans " .. math.ceil(reste) .. " s")
    reboursBarre:SetWidth(math.max(1, 280 * (1 - math.min(reste, DUREE_AVANT_REPOS) / DUREE_AVANT_REPOS)))
end

local function NouveauBouton(sort, ligne)
    local nom = GetSpellInfo(sort)
    local b = CreateFrame("Button", "SolUIBivouac" .. sort, SolUITechniques, "SecureActionButtonTemplate")
    b:SetSize(TAILLE, TAILLE)
    -- À droite de la barre de techniques : même rangées, une colonne de plus.
    b:SetPoint("BOTTOMLEFT", SolUITechniques, "BOTTOMLEFT", 26 + 18 + 4 * (TAILLE + ECART) + 10, ligne * (TAILLE + ECART))
    b.nom = nom
    b:SetAttribute("type", "spell")
    b:SetAttribute("spell", nom)
    b:RegisterForClicks("AnyUp")

    b.fond = S.Texture(b, "BORDER", "Bouton")
    b.fond:SetAllPoints()
    b.icone = b:CreateTexture(nil, "ARTWORK")
    b.icone:SetSize(TAILLE - 12, TAILLE - 12)
    b.icone:SetPoint("CENTER")
    b.icone:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.icone:SetTexture(select(3, GetSpellInfo(sort)))
    b.voile = S.Texture(b, "OVERLAY", "Bouton", 0.031, 0.031, 0.039, 0.66)
    b.voile:SetAllPoints()
    b.bord = S.Texture(b, "OVERLAY", "BoutonBord")
    b.bord:SetAllPoints()

    local dessus = CreateFrame("Frame", nil, b)
    dessus:SetAllPoints()
    dessus:SetFrameLevel(b:GetFrameLevel() + 2)
    b.recharge = S.Texte(dessus, "Regular", 17, "clair")
    b.recharge:SetPoint("CENTER")
    b.nombre = S.Texte(dessus, "SemiBold", 11, "clair")
    b.nombre:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 3)
    b.touche = S.Texte(dessus, "Regular", 10, "texte", 0.8)
    b.touche:SetPoint("TOPLEFT", b, "TOPLEFT", 4, -2)
    b.commande = "CLICK SolUIBivouac" .. sort .. ":LeftButton"

    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetHyperlink("spell:" .. sort)
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnMouseDown", function(self) self.enfonce = true end)
    b:SetScript("OnMouseUp", function(self) self.enfonce = false end)
    return b
end

local potion = NouveauBouton(POTION, 0)
local feu = NouveauBouton(FEU, 1)

-- Touches réglées dans la fenêtre « Techniques et raccourcis ».
local function MajTouches()
    for _, b in ipairs({ potion, feu }) do
        local touche = GetBindingKey(b.commande)
        b.touche:SetText(touche and GetBindingText(touche, "KEY_", 1) or "")
    end
end
S.Ecouter("UPDATE_BINDINGS", MajTouches)
S.Ecouter("PLAYER_ENTERING_WORLD", MajTouches)

local function Etat(b, vide)
    local debut, duree, active = GetSpellCooldown(b.nom)
    local reste = (active == 1 and duree and duree > 1.5) and (debut + duree - GetTime()) or 0
    local enRecharge = reste > 0
    S.Montrer(b.voile, enRecharge)
    b.recharge:SetText(enRecharge and (reste >= 60 and S.Duree(reste) or math.ceil(reste)) or "")
    if enRecharge then
        b.fond:SetVertexColor(0.04, 0.04, 0.047, 0.38)
        b.bord:SetVertexColor(S.Couleur("texte", 0.22))
    else
        b.fond:SetVertexColor(S.Couleur("texte", b.enfonce and 0.22 or 0.08))
        b.bord:SetVertexColor(S.Couleur("texte", b.enfonce and 0.9 or 0.6))
    end
    local utilisable = IsUsableSpell(b.nom)
    local eteint = vide or not utilisable
    b.icone:SetVertexColor(eteint and 0.45 or 1, eteint and 0.45 or 1, eteint and 0.45 or 1)
    b.icone:SetAlpha(enRecharge and 0.6 or 0.9)
end

local attente = 0
potion:SetScript("OnUpdate", function(self, ecoule)
    attente = attente - ecoule
    if attente > 0 then return end
    attente = 0.1
    local charges = S.etat.charges
    potion.nombre:SetText(charges or "")
    Etat(potion, charges == 0)
    Etat(feu, false)
    MajRebours()
end)
