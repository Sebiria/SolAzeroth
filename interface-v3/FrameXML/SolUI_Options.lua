-- Audit du jeu, lot 6c (02/11/2026, C10 du consensus ; choix de l'utilisateur : « fondre dans les carnets ») : un seul
-- style. Les fenêtres dorées de Blizzard deviennent des onglets graphite :
-- - Techniques › Spécialisation : le choix seul (l'équipement des techniques est dans Techniques équipées). Elle s'ouvre
--   d'elle-même tant qu'un guerrier n'a pas choisi. Remplace l'addon SolAzerothKit ; « /kit » mène ici.
-- - Réglages › Interface, Plaques de nom, Sauvegarde : les pages de l'ancienne fenêtre /sol (addon SolAzeroth, qui ne
--   garde que la sauvegarde des réglages) ; les plaques se règlent par SolAzerothPlaques (addon du même nom). La page
--   Monde de /sol (monstres à ton niveau, v2) est retirée. « /sol » et « /plaques » mènent ici.

local S = SolUI

------------------------------------------------------------------------
-- Contrôles graphite : curseur et case à cocher
------------------------------------------------------------------------
function S.Curseur(parent, largeur, mini, maxi, pas, format, change)
    local c = CreateFrame("Slider", nil, parent)
    c:SetOrientation("HORIZONTAL")
    c:SetSize(largeur, 16)
    c:SetMinMaxValues(mini, maxi)
    c:SetValueStep(pas)
    local rail = S.Texture(c, "BACKGROUND", nil, S.Couleur("creux"))
    rail:SetPoint("LEFT")
    rail:SetPoint("RIGHT")
    rail:SetHeight(4)
    local pouce = c:CreateTexture(nil, "OVERLAY")
    pouce:SetTexture(S.BLANC)
    pouce:SetVertexColor(S.Couleur("ambre"))
    pouce:SetSize(10, 16)
    c:SetThumbTexture(pouce)
    c.valeur = S.Texte(c, "SemiBold", 12, "ambreClair")
    c.valeur:SetPoint("LEFT", c, "RIGHT", 12, 0)
    c:SetScript("OnValueChanged", function(self, v)
        v = math.floor(v / pas + 0.5) * pas
        self.valeur:SetText(string.format(format, v))
        if not self.silence then change(v) end
    end)
    c:EnableMouseWheel(true)
    c:SetScript("OnMouseWheel", function(self, sens) self:SetValue(self:GetValue() + sens * pas) end)
    function c:Fixer(v)
        self.silence = true
        self:SetValue(v)
        self.valeur:SetText(string.format(format, v))
        self.silence = false
    end
    return c
end

function S.Case(parent, texte, change)
    local b = S.BoutonPlat(parent, "", 22, 22)
    b.coche = S.Texture(b, "OVERLAY", nil, S.Couleur("ambre"))
    b.coche:SetPoint("TOPLEFT", 5, -5)
    b.coche:SetPoint("BOTTOMRIGHT", -5, 5)
    b.libelle = S.Texte(parent, "Regular", 13, "texte")
    b.libelle:SetPoint("LEFT", b, "RIGHT", 10, 0)
    b.libelle:SetText(texte)
    function b:Cocher(oui)
        self.coche_ = oui and true or false
        S.Montrer(self.coche, self.coche_)
    end
    b:SetScript("OnClick", function(self)
        self:Cocher(not self.coche_)
        change(self.coche_)
    end)
    b:Cocher(false)
    return b
end

local function Rubrique(parent, texte, y)
    local t = S.Texte(parent, "Bold", 11, "gris")
    t:SetPoint("TOPLEFT", 24, y)
    t:SetText(texte)
    return t
end

local function Libelle(parent, texte, y, largeur)
    local t = S.Texte(parent, "Regular", 13, "texte")
    t:SetPoint("TOPLEFT", 24, y)
    t:SetWidth(largeur or 170)
    t:SetJustifyH("LEFT")
    t:SetText(texte)
    return t
end

------------------------------------------------------------------------
-- Techniques › Spécialisation
------------------------------------------------------------------------
local spe = S.Fenetre("SolUISpecialisation", 680, 330, "Spécialisation")
local carte = CreateFrame("Frame", nil, spe)
carte:SetPoint("TOPLEFT", 24, -72)
carte:SetPoint("TOPRIGHT", -24, -72)
carte:SetHeight(180)
S.Panneau(carte, 0.6)
local icone = carte:CreateTexture(nil, "ARTWORK")
icone:SetSize(56, 56)
icone:SetPoint("TOPLEFT", 16, -16)
icone:SetTexture("Interface\\Icons\\SolAzeroth_inv_shield_1h_artifactmagnar_d_01")
local nomSpe = S.Texte(carte, "Bold", 18, "ambreClair")
nomSpe:SetPoint("TOPLEFT", 88, -18)
nomSpe:SetText("Guerrier — Tank")
local texteSpe = S.Texte(carte, "Regular", 13, "texte")
texteSpe:SetPoint("TOPLEFT", 88, -46)
texteSpe:SetWidth(520)
texteSpe:SetJustifyH("LEFT")
texteSpe:SetSpacing(3)
texteSpe:SetText("Passif Rempart : chaque coup encaissé remplit un bouclier qui absorbe les coups suivants. Le garder "
    .. "pour tenir, ou le dépenser pour rendre les coups.\nTu commences avec 3 emplacements de techniques ; d'autres "
    .. "s'ouvrent avec ta puissance (Techniques équipées).")
local etatSpe = S.Texte(spe, "Regular", 13, "gris")
etatSpe:SetPoint("TOPLEFT", carte, "BOTTOMLEFT", 0, -16)
etatSpe:SetWidth(632)
etatSpe:SetJustifyH("LEFT")
local choisir = S.BoutonPlat(spe, "Choisir cette spécialisation", 260, 40, 14)
choisir:SetPoint("BOTTOMRIGHT", -24, 20)
choisir:SetScript("OnClick", function() SendChatMessage(".kit spe tank", "SAY") end)
local versTechniques = S.BoutonPlat(spe, "Techniques équipées", 220, 40, 14)
versTechniques:SetPoint("BOTTOMRIGHT", -24, 20)
versTechniques:SetScript("OnClick", function() S.OuvrirCarnet("techniques", 2) end)

local function MajSpe()
    local choisie = S.etat.spe == 1
    S.Montrer(choisir, S.etat.spe == 0)
    S.Montrer(versTechniques, choisie)
    choisir:Choisir(false)
    if choisie then
        etatSpe:SetText(string.format("Spécialisation choisie, définitive pour l'instant : les autres viendront plus "
            .. "tard.  ·  %d emplacements de techniques sur 8.", S.etat.emplacements or 3))
    elseif S.etat.spe == 0 then
        etatSpe:SetText("Le choix est définitif pour l'instant. Les autres spécialisations viendront plus tard.")
    else
        etatSpe:SetText("En attente du serveur…")
    end
end
spe:SetScript("OnShow", function() MajSpe(); SendChatMessage(".kit", "SAY") end)

-- Un guerrier sans spécialisation : la page s'ouvre d'elle-même à la première réponse du serveur, et revient après la
-- cinématique d'introduction (Échap, qui la passe, fermait aussi la page).
local vueSansSpe = false
local function SansSpe() return S.etat.spe == 0 and select(2, UnitClass("player")) == "WARRIOR" end
S.Abonner("kit", function()
    if spe:IsShown() then MajSpe() end
    if not vueSansSpe and SansSpe() then
        vueSansSpe = true
        S.OuvrirCarnet("techniques", 3)
    end
end)
S.Ecouter("CINEMATIC_STOP", function() if SansSpe() then S.OuvrirCarnet("techniques", 3) end end)
S.Ecouter("PLAYER_ENTERING_WORLD", function() SendChatMessage(".kit", "SAY") end)

------------------------------------------------------------------------
-- Réglages : Interface, Plaques de nom, Sauvegarde
------------------------------------------------------------------------
local f = S.Fenetre("SolUIOptions", 720, 600, "Réglages")
local pages = {}
for n = 1, 3 do
    local p = CreateFrame("Frame", nil, f)
    p:SetPoint("TOPLEFT", 0, -56)
    p:SetPoint("BOTTOMRIGHT")
    p:Hide()
    pages[n] = p
end
local pageOuverte = 1
local MajPages = {}
function S.PageOptions(n)
    pageOuverte = n
    for i, p in ipairs(pages) do S.Montrer(p, i == n) end
    if MajPages[n] then MajPages[n]() end
end
f:SetScript("OnShow", function() S.PageOptions(pageOuverte) end)

-- 1. Interface : disposition de l'écran de combat (SolUI_Reglages.lua).
do
    local p = pages[1]
    Rubrique(p, "DISPOSITION DE L'ÉCRAN", -16)
    local aide = S.Texte(p, "Regular", 12, "gris")
    aide:SetPoint("TOPLEFT", 24, -36)
    aide:SetWidth(670)
    aide:SetJustifyH("LEFT")
    aide:SetText("Déplace chaque bloc à la souris ; la molette change sa taille (Maj + molette : largeur de la cible). "
        .. "Hors combat seulement. La disposition est gardée d'une session à l'autre.")
    local basculer = S.BoutonPlat(p, "Déplacer les blocs", 200, 34, 13)
    basculer:SetPoint("TOPLEFT", 24, -64)
    basculer:SetScript("OnClick", function() S.ModeEdition(not S.EnEdition()) end)
    local tout = S.BoutonPlat(p, "Tout réinitialiser", 180, 34, 13)
    tout:SetPoint("LEFT", basculer, "RIGHT", 12, 0)
    tout:SetScript("OnClick", function() S.Reinitialiser() end)

    Rubrique(p, "TAILLE DES BLOCS", -122)
    local curseurs, y = {}, -146
    for _, nom in ipairs({ "perso", "techniques", "cible", "zone", "quetes" }) do
        Libelle(p, S.NOMS_BLOCS[nom], y)
        curseurs[nom] = S.Curseur(p, 260, 60, 160, 5, "%d %%", function(v) S.Modifier(nom, "echelle", v / 100) end)
        curseurs[nom]:SetPoint("TOPLEFT", 200, y)
        local r = S.BoutonPlat(p, "Réinitialiser", 120, 24, 11)
        r:SetPoint("TOPLEFT", 560, y + 4)
        r:SetScript("OnClick", function() S.Reinitialiser(nom) end)
        y = y - 36
    end
    Libelle(p, "Largeur de la cible", y)
    local largeur = S.Curseur(p, 260, S.LIMITES.largeur[1], S.LIMITES.largeur[2], 20, "%d", function(v)
        S.Modifier("cible", "largeur", v)
    end)
    largeur:SetPoint("TOPLEFT", 200, y)

    Rubrique(p, "MINI-CARTE", y - 50)
    Libelle(p, "Taille", y - 74)
    local taille = S.Curseur(p, 260, S.LIMITES.carte[1], S.LIMITES.carte[2], 2, "%d", function(v)
        S.ModifierOption("carte", v)
    end)
    taille:SetPoint("TOPLEFT", 200, y - 74)
    Libelle(p, "Repères de quête", y - 110)
    local reperes = S.Curseur(p, 260, 50, 250, 10, "%d %%", function(v) S.ModifierOption("reperes", v / 100) end)
    reperes:SetPoint("TOPLEFT", 200, y - 110)

    MajPages[1] = function()
        for nom, c in pairs(curseurs) do c:Fixer(math.floor(S.DISPOSITION[nom].echelle * 100 + 0.5)) end
        largeur:Fixer(S.DISPOSITION.cible.largeur)
        taille:Fixer(S.OPTIONS.carte)
        reperes:Fixer(math.floor(S.OPTIONS.reperes * 100 + 0.5))
        basculer.texte:SetText(S.EnEdition() and "Terminer" or "Déplacer les blocs")
        basculer:Choisir(S.EnEdition())
    end
    S.surEdition = function() if p:IsShown() then MajPages[1]() end end
    S.Abonner("disposition", function() if p:IsShown() then MajPages[1]() end end)
end

-- 2. Plaques de nom (addon SolAzerothPlaques), construite à la première ouverture : l'addon se charge après l'interface.
do
    local p = pages[2]
    local controles
    local manque = S.Texte(p, "Regular", 13, "gris")
    manque:SetPoint("TOP", 0, -120)
    manque:SetText("L'addon des plaques de nom (SolAzerothPlaques) n'est pas chargé.")

    local function Construire(P)
        controles = {}
        local y = -16
        Rubrique(p, "TAILLE", y)
        y = y - 26
        for _, r in ipairs({ { "largeur", "Largeur", 60, 200, 5 }, { "hauteur", "Hauteur", 4, 24, 1 },
            { "police", "Taille du texte", 6, 16, 1 }, { "icone", "Taille des affaiblissements", 12, 36, 1 },
            { "maxIcones", "Affaiblissements au plus", 1, 12, 1 } }) do
            Libelle(p, r[2], y)
            local c = S.Curseur(p, 260, r[3], r[4], r[5], "%d", function(v) P.Changer(r[1], v) end)
            c:SetPoint("TOPLEFT", 240, y)
            controles[r[1]] = function() c:Fixer(P.Lire(r[1])) end
            y = y - 34
        end
        Rubrique(p, "APPARENCE", y - 8)
        y = y - 34
        for _, r in ipairs({ { "texture", "Texture", P.TEXTURES, function(t) return t.nom end },
            { "texteVie", "Texte de vie", P.TEXTES_VIE, function(t) return t end } }) do
            Libelle(p, r[2], y + 6)
            local b = S.BoutonPlat(p, "", 260, 28, 12)
            b:SetPoint("TOPLEFT", 240, y + 10)
            local function Texte() b.texte:SetText(r[4](r[3][P.Lire(r[1])]) .. "   ›") end
            b:SetScript("OnClick", function()
                P.Changer(r[1], P.Lire(r[1]) % #r[3] + 1)
                Texte()
            end)
            controles[r[1]] = Texte
            y = y - 36
        end
        Rubrique(p, "AFFICHAGE", y - 8)
        y = y - 34
        for _, r in ipairs({ { "mesSeuls", "Seulement mes affaiblissements" },
            { "niveau", "Afficher la puissance du monstre" },
            { "ennemisAuto", "Toujours afficher les plaques ennemies" },
            { "quetes", "Marquer les monstres de quête" } }) do
            local c = S.Case(p, r[2], function(oui) P.Changer(r[1], oui) end)
            c:SetPoint("TOPLEFT", 24, y)
            controles[r[1]] = function() c:Cocher(P.Lire(r[1])) end
            y = y - 32
        end
        local defaut = S.BoutonPlat(p, "Réglages d'origine", 200, 34, 13)
        defaut:SetPoint("TOPLEFT", 24, y - 16)
        defaut:SetScript("OnClick", function()
            P.Reinitialiser()
            MajPages[2]()
        end)
    end

    MajPages[2] = function()
        local P = SolAzerothPlaques
        S.Montrer(manque, not P)
        if not P then return end
        if not controles then Construire(P) end
        for _, maj in pairs(controles) do maj() end
    end
end

-- 3. Sauvegarde de la partie (commande .sauvegarder, module).
do
    local p = pages[3]
    Rubrique(p, "SAUVEGARDE DE LA PARTIE", -16)
    local aide = S.Texte(p, "Regular", 12, "gris")
    aide:SetPoint("TOPLEFT", 24, -36)
    aide:SetText("Copie de la base de données, comme le bouton « Sauvegarder » du menu Échap.")
    local maintenant = S.BoutonPlat(p, "Sauvegarder maintenant", 240, 34, 13)
    maintenant:SetPoint("TOPLEFT", 24, -62)
    maintenant:SetScript("OnClick", function() SendChatMessage(".sauvegarder", "SAY") end)
    Rubrique(p, "SAUVEGARDE AUTOMATIQUE", -130)
    local aide2 = S.Texte(p, "Regular", 12, "gris")
    aide2:SetPoint("TOPLEFT", 24, -150)
    aide2:SetText("Intervalle entre deux sauvegardes pendant le jeu :")
    for i, minutes in ipairs({ 5, 10, 15, 30, 60 }) do
        local b = S.BoutonPlat(p, minutes .. " min", 90, 32, 12)
        b:SetPoint("TOPLEFT", 24 + (i - 1) * 98, -176)
        b:SetScript("OnClick", function() SendChatMessage(".sauvegarder " .. minutes, "SAY") end)
    end
    local actuel = S.BoutonPlat(p, "Intervalle actuel", 200, 32, 12)
    actuel:SetPoint("TOPLEFT", 24, -218)
    actuel:SetScript("OnClick", function() SendChatMessage(".sauvegarder ?", "SAY") end)
end

------------------------------------------------------------------------
-- Commandes : les anciennes fenêtres mènent aux onglets
------------------------------------------------------------------------
SLASH_SOLAZEROTH1 = "/sol"
SLASH_SOLAZEROTH2 = "/solazeroth"
SlashCmdList["SOLAZEROTH"] = function() S.BasculerCarnet("reglages") end
SLASH_SOLAZEROTHKIT1 = "/kit"
SlashCmdList["SOLAZEROTHKIT"] = function() S.BasculerCarnet("techniques", 3) end
