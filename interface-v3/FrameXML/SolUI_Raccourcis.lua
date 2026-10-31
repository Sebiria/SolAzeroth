-- Sol'Azeroth v3 (31/10/2026) : fenêtre « Techniques et raccourcis », d'après la maquette « 7 » (demande de
-- l'utilisateur : régler les touches des boutons dans une fenêtre à part).
-- - Raccourcis : les 10 boutons disposés comme à l'écran. On en clique un, puis on appuie sur la touche voulue (Maj,
--   Ctrl et Alt se combinent ; souris : bouton du milieu, 4, 5 et molette ; Échap annule, Suppr retire). Une touche
--   déjà prise est retirée de son ancien usage, et la fenêtre le dit. Les touches sont celles du jeu (SetBinding), enregistrées à la fermeture.
-- - Techniques équipées : 8 au plus parmi les techniques débloquées, hors combat (.kit equiper, v3_kit.cpp).
-- - Feu de camp et potion : leurs effets au rang de départ (v3_bivouac.cpp) ; les rangs viendront avec F7.

local S = SolUI

local TAILLE = 64
local POTION, FEU, PIERRE = 100029, 100030, 6948
local MODIFICATEURS = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true,
    UNKNOWN = true }

local f = S.Fenetre("SolUIRaccourcis", 1000, 660, "Techniques et raccourcis")

-- Bouton invisible : une touche peut ouvrir la fenêtre (« CLICK SolUIOuvrirRaccourcis:LeftButton »).
local ouvrir = CreateFrame("Button", "SolUIOuvrirRaccourcis", UIParent)
ouvrir:SetSize(1, 1)
ouvrir:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -10, 10)
ouvrir:SetAlpha(0)
ouvrir:EnableMouse(false)
function S.BasculerRaccourcis()
    if f:IsShown() then f:Hide() else f:Show() end
end
ouvrir:SetScript("OnClick", S.BasculerRaccourcis)

------------------------------------------------------------------------
-- Ce qu'on peut régler
------------------------------------------------------------------------
local function NomAction(i)
    local genre, id = GetActionInfo(i)
    if genre == "spell" and id then return GetSpellName(id, BOOKTYPE_SPELL) or ("Bouton " .. i) end
    return "Bouton " .. i .. " (vide)"
end

local ENTREES = {}
for i = 1, 8 do
    table.insert(ENTREES, { place = tostring(i), commande = "ACTIONBUTTON" .. i, defaut = i <= 4 and tostring(i) or ("SHIFT-" .. (i - 4)),
        nom = function() return NomAction(i) end, icone = function() return GetActionTexture(i) end })
end
for _, sort in ipairs({ POTION, FEU }) do
    table.insert(ENTREES, { place = sort == POTION and "P" or "F", commande = "CLICK SolUIBivouac" .. sort .. ":LeftButton",
        nom = function() return (GetSpellInfo(sort)) end, icone = function() return select(3, GetSpellInfo(sort)) end })
end
table.insert(ENTREES, { place = "PF", commande = "CLICK SolUIBivouac" .. PIERRE .. ":LeftButton",
    nom = function() return GetItemInfo(PIERRE) or "Pierre de foyer" end, icone = function() return GetItemIcon(PIERRE) end })
local FENETRES = {
    { nom = function() return "Techniques et raccourcis" end, commande = "CLICK SolUIOuvrirRaccourcis:LeftButton" },
    { nom = function() return "Collection" end, commande = "CLICK SolUIOuvrirCollection:LeftButton" },
    { nom = function() return "Carte" end, commande = "TOGGLEWORLDMAP" },
}

local function Touche(commande)
    local touche = GetBindingKey(commande)
    return touche and S.ToucheCourte(touche) or nil
end

local function NomCommande(commande)
    for _, liste in ipairs({ ENTREES, FENETRES }) do
        for _, e in ipairs(liste) do
            if e.commande == commande then return e.nom() end
        end
    end
    return _G["BINDING_NAME_" .. commande] or commande
end

local function Effacer(commande)
    for _, touche in ipairs({ GetBindingKey(commande) }) do SetBinding(touche) end
end

------------------------------------------------------------------------
-- Onglets
------------------------------------------------------------------------
local pages, onglets = {}, {}
local function Onglet(n)
    for i, page in ipairs(pages) do
        S.Montrer(page, i == n)
        onglets[i]:Choisir(i == n)
    end
end
for i, titre in ipairs({ "Raccourcis", "Techniques équipées", "Feu de camp et potion" }) do
    local o = S.BoutonPlat(f, titre, 190, 36, 14)
    o:SetPoint("TOPLEFT", 24 + (i - 1) * 198, -60)
    o:SetScript("OnClick", function() Onglet(i) end)
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

------------------------------------------------------------------------
-- Page 1 : raccourcis
------------------------------------------------------------------------
local p1 = pages[1]
local capture, message, modifie = nil, "", false
local Maj

-- Pendant la saisie, un voile sur tout l'écran prend aussi la souris : bouton du milieu, boutons 4 et 5, molette.
-- Un clic gauche ou droit annule.
local voile = CreateFrame("Frame", "SolUIRaccourcisVoile", UIParent)
voile:SetAllPoints(UIParent)
voile:SetFrameStrata("FULLSCREEN_DIALOG")
voile:EnableMouse(true)
voile:EnableMouseWheel(true)
voile:Hide()

local function Choisir(e)
    capture = e
    message = ""
    f:EnableKeyboard(e ~= nil)
    S.Montrer(voile, e ~= nil)
    Maj()
end

local aide = S.Texte(p1, "Regular", 13, "gris")
aide:SetPoint("TOPLEFT", 24, -14)
aide:SetText("Clique un bouton, puis appuie sur la touche voulue. Les boutons sont disposés comme à l'écran.")

local plateau = CreateFrame("Frame", nil, p1)
plateau:SetPoint("TOPLEFT", 24, -40)
plateau:SetSize(576, 220)
plateau:SetBackdrop({ bgFile = S.BLANC, edgeFile = S.BLANC, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
plateau:SetBackdropColor(S.Couleur("creux", 0.9))
plateau:SetBackdropBorderColor(S.Couleur("bordCreux"))

local function Touchette(parent)
    local t = CreateFrame("Frame", nil, parent)
    t:SetSize(52, 24)
    t:SetBackdrop({ bgFile = S.BLANC, edgeFile = S.BLANC, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
    t.texte = S.Texte(t, "SemiBold", 12, "texte")
    t.texte:SetPoint("CENTER")
    function t:Afficher(texte, attente)
        self.texte:SetText(attente and "…" or (texte or "—"))
        if attente then
            self:SetBackdropColor(S.Couleur("ambre"))
            self:SetBackdropBorderColor(S.Couleur("ambre"))
            self.texte:SetTextColor(S.Couleur("fond"))
        else
            self:SetBackdropColor(0.11, 0.118, 0.133, texte and 1 or 0)
            self:SetBackdropBorderColor(S.Couleur(texte and "gris" or "bord", texte and 0.5 or 1))
            self.texte:SetTextColor(S.Couleur(texte and "clair" or "gris"))
        end
    end
    return t
end

-- Disposition de l'écran : en haut 5 à 8, le feu et la pierre de foyer, en bas 1 à 4 puis la potion.
local PLACES = { [5] = { 0, 0 }, [6] = { 1, 0 }, [7] = { 2, 0 }, [8] = { 3, 0 }, [10] = { 4, 0 }, [11] = { 5, 0 },
    [1] = { 0, 1 }, [2] = { 1, 1 }, [3] = { 2, 1 }, [4] = { 3, 1 }, [9] = { 4, 1 } }
local cases = {}
for n, e in ipairs(ENTREES) do
    local colonne, ligne = PLACES[n][1], PLACES[n][2]
    local b = CreateFrame("Button", nil, plateau)
    b:SetSize(TAILLE, TAILLE)
    b:SetPoint("TOPLEFT", 40 + colonne * 84 + (colonne >= 4 and 24 or 0), -22 - ligne * 104)
    b:SetBackdrop({ bgFile = S.BLANC, edgeFile = S.BLANC, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
    b.icone = b:CreateTexture(nil, "ARTWORK")
    b.icone:SetPoint("TOPLEFT", 6, -6)
    b.icone:SetPoint("BOTTOMRIGHT", -6, 6)
    b.icone:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.touche = Touchette(b)
    b.touche:SetPoint("TOP", b, "BOTTOM", 0, -6)
    b:SetScript("OnClick", function() Choisir(e) end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(e.nom())
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    cases[n] = b
end

-- Saisie de la touche
local saisie = CreateFrame("Frame", nil, p1)
saisie:SetPoint("TOPLEFT", plateau, "BOTTOMLEFT", 0, -16)
saisie:SetSize(560, 128)
saisie:SetBackdrop({ bgFile = S.BLANC, edgeFile = S.BLANC, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
local saisieTitre = S.Texte(saisie, "Bold", 11, "ambreClair")
saisieTitre:SetPoint("TOPLEFT", 18, -16)
local saisieNom = S.Texte(saisie, "SemiBold", 17, "clair")
saisieNom:SetPoint("TOPLEFT", saisieTitre, "BOTTOMLEFT", 0, -6)
local saisieAide = S.Texte(saisie, "Regular", 13, "texte")
saisieAide:SetPoint("TOPLEFT", saisieNom, "BOTTOMLEFT", 0, -10)
saisieAide:SetWidth(524)
saisieAide:SetJustifyH("LEFT")
local saisieMessage = S.Texte(saisie, "Regular", 13, "ambreClair")
saisieMessage:SetPoint("TOPLEFT", saisieAide, "BOTTOMLEFT", 0, -10)
saisieMessage:SetWidth(524)
saisieMessage:SetJustifyH("LEFT")

local defaut = S.BoutonPlat(p1, "Touches des techniques par défaut", 250, 36)
defaut:SetPoint("BOTTOMLEFT", 24, 22)
defaut:SetScript("OnClick", function()
    for n = 1, 8 do
        local e = ENTREES[n]
        local ancien = GetBindingAction(e.defaut)
        if ancien ~= "" and ancien ~= e.commande then Effacer(ancien) end
        Effacer(e.commande)
        SetBinding(e.defaut, e.commande)
    end
    modifie, capture = true, nil
    message = "Techniques : 1 à 4, puis Maj 1 à Maj 4."
    f:EnableKeyboard(false)
    Maj()
end)
local annuler = S.BoutonPlat(p1, "Annuler les changements", 210, 36)
annuler:SetPoint("LEFT", defaut, "RIGHT", 12, 0)
annuler:SetScript("OnClick", function()
    LoadBindings(GetCurrentBindingSet())
    modifie, capture = false, nil
    message = "Changements annulés."
    f:EnableKeyboard(false)
    Maj()
end)

-- Liste de droite
local lignes = {}
local function Titre(texte, y)
    local t = S.Texte(p1, "Bold", 11, "gris")
    t:SetPoint("TOPLEFT", 612, y)
    t:SetText(texte)
end
local function Ligne(e, y)
    local l = S.BoutonPlat(p1, "", 364, 32)
    l:SetPoint("TOPLEFT", 612, y)
    l.texte:ClearAllPoints()
    l.texte:SetPoint("LEFT", 36, 0)
    l.texte:SetWidth(250)
    l.texte:SetJustifyH("LEFT")
    l.place = S.Texte(l, "Regular", 11, "gris")
    l.place:SetPoint("LEFT", 12, 0)
    l.place:SetText(e.place or "")
    l.touche = Touchette(l)
    l.touche:SetPoint("RIGHT", -6, 0)
    l:SetScript("OnClick", function() Choisir(e) end)
    l.entree = e
    table.insert(lignes, l)
end
Titre("BOUTONS DE COMBAT", -14)
for n, e in ipairs(ENTREES) do Ligne(e, -32 - (n - 1) * 34) end
Titre("FENÊTRES", -32 - #ENTREES * 34 - 8)
for n, e in ipairs(FENETRES) do Ligne(e, -32 - #ENTREES * 34 - 26 - (n - 1) * 34) end

function Maj()
    for n, e in ipairs(ENTREES) do
        local b, actif = cases[n], capture == e
        b.icone:SetTexture(e.icone())
        S.Montrer(b.icone, e.icone() ~= nil)
        b:SetBackdropColor(0.11, 0.118, 0.133, 1)
        b:SetBackdropBorderColor(S.Couleur(actif and "ambre" or "gris", actif and 1 or 0.45))
        b.touche:Afficher(Touche(e.commande), actif)
    end
    for _, l in ipairs(lignes) do
        l.texte:SetText(l.entree.nom())
        l:Choisir(capture == l.entree)
        l.touche:Afficher(Touche(l.entree.commande), capture == l.entree)
    end
    if capture then
        saisie:SetBackdropColor(0.122, 0.102, 0.071, 1)
        saisie:SetBackdropBorderColor(S.Couleur("ambre"))
        saisieTitre:SetText("EN ATTENTE D'UNE TOUCHE")
        saisieNom:SetText(capture.nom() .. "  ·  actuelle : " .. (Touche(capture.commande) or "aucune"))
        saisieAide:SetText("Touche, bouton du milieu, boutons 4 et 5 ou molette ; Maj, Ctrl et Alt se combinent. Échap ou clic annule, Suppr retire.")
    else
        saisie:SetBackdropColor(S.Couleur("creux", 0.6))
        saisie:SetBackdropBorderColor(S.Couleur("bordCreux"))
        saisieTitre:SetText("AUCUN BOUTON CHOISI")
        saisieNom:SetText("Choisis un bouton ou une ligne de la liste.")
        saisieAide:SetText("Les touches sont enregistrées en fermant la fenêtre.")
    end
    saisieMessage:SetText(message)
end

f:EnableKeyboard(false)
local function Poser(self, touche)
    if not capture or MODIFICATEURS[touche] then return end
    local e = capture
    if touche == "ESCAPE" then
        Choisir(nil)
        return
    end
    if touche == "DELETE" then
        Effacer(e.commande)
        modifie = true
        Choisir(nil)
        message = e.nom() .. " n'a plus de raccourci."
        Maj()
        return
    end
    local combinaison = (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "")
        .. (IsShiftKeyDown() and "SHIFT-" or "") .. touche
    local ancien = GetBindingAction(combinaison)
    Effacer(e.commande)
    SetBinding(combinaison, e.commande)
    modifie = true
    Choisir(nil)
    local texte = GetBindingText(combinaison, "KEY_", 1)
    if ancien ~= "" and ancien ~= e.commande then
        message = "« " .. texte .. " » était sur " .. NomCommande(ancien) .. " : retiré de là, posé sur " .. e.nom() .. "."
    else
        message = "« " .. texte .. " » est posé sur " .. e.nom() .. "."
    end
    Maj()
end
f:SetScript("OnKeyDown", Poser)

local SOURIS = { MiddleButton = "BUTTON3", Button4 = "BUTTON4", Button5 = "BUTTON5" }
voile:SetScript("OnMouseDown", function(_, bouton)
    if SOURIS[bouton] then Poser(f, SOURIS[bouton]) else Choisir(nil) end
end)
voile:SetScript("OnMouseWheel", function(_, sens)
    Poser(f, sens > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN")
end)

------------------------------------------------------------------------
-- Page 2 : techniques équipées
------------------------------------------------------------------------
local p2 = pages[2]
local EQUIPEES_MAX = 8
local choix, choixModifie = {}, false

local aide2 = S.Texte(p2, "Regular", 13, "gris")
aide2:SetPoint("TOPLEFT", 24, -14)
aide2:SetText("Choisis jusqu'à 8 techniques parmi celles débloquées, puis applique, hors combat.")
local compte = S.Texte(p2, "SemiBold", 14, "ambreClair")
compte:SetPoint("TOPRIGHT", -24, -14)
local sansSpe = S.Texte(p2, "Regular", 15, "texte")
sansSpe:SetPoint("CENTER", 0, 40)
sansSpe:SetText("Choisis d'abord ta spécialisation : /sol, page Techniques.")

local tuiles = {}
local MajTechniques
for n = 1, 16 do
    local t = S.BoutonPlat(p2, "", 466, 44)
    t:SetPoint("TOPLEFT", 24 + ((n - 1) % 2) * 482, -42 - math.floor((n - 1) / 2) * 50)
    t.icone = t:CreateTexture(nil, "ARTWORK")
    t.icone:SetSize(32, 32)
    t.icone:SetPoint("LEFT", 6, 0)
    t.icone:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    t.texte:ClearAllPoints()
    t.texte:SetPoint("LEFT", t.icone, "RIGHT", 12, 0)
    t.etat = S.Texte(t, "Regular", 12, "gris")
    t.etat:SetPoint("RIGHT", -14, 0)
    t:SetScript("OnClick", function(self)
        if not self.sort or self.verrouillee then return end
        local nombre = 0
        for _, oui in pairs(choix) do if oui then nombre = nombre + 1 end end
        if not choix[self.sort] and nombre >= EQUIPEES_MAX then return end
        choix[self.sort] = not choix[self.sort]
        choixModifie = true
        MajTechniques()
    end)
    t:SetScript("OnEnter", function(self)
        if not self.sort then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink("spell:" .. self.sort)
    end)
    t:SetScript("OnLeave", function() GameTooltip:Hide() end)
    tuiles[n] = t
end

local appliquer = S.BoutonPlat(p2, "Appliquer", 160, 36)
appliquer:SetPoint("BOTTOMRIGHT", -24, 22)
local retour = S.Texte(p2, "Regular", 13, "ambreClair")
retour:SetPoint("RIGHT", appliquer, "LEFT", -16, 0)
appliquer:SetScript("OnClick", function()
    if InCombatLockdown() then retour:SetText("Pas en combat."); return end
    local liste = {}
    for _, t in ipairs(S.etat.techniques or {}) do
        if choix[t.sort] then table.insert(liste, t.sort) end
    end
    SendChatMessage(".kit equiper " .. table.concat(liste, " "), "SAY")
    choixModifie = false
    retour:SetText("Techniques envoyées au serveur.")
end)

function MajTechniques()
    local techniques = S.etat.techniques or {}
    local avecSpe = S.etat.spe == 1 and #techniques > 0
    S.Montrer(sansSpe, not avecSpe)
    S.Montrer(appliquer, avecSpe)
    S.Montrer(compte, avecSpe)
    if not choixModifie then
        wipe(choix)
        for _, t in ipairs(techniques) do choix[t.sort] = t.etat == 2 end
    end
    local nombre = 0
    for n, tuile in ipairs(tuiles) do
        local t = avecSpe and techniques[n]
        S.Montrer(tuile, t)
        if t then
            local nom, _, icone = GetSpellInfo(t.sort)
            tuile.sort, tuile.verrouillee = t.sort, t.etat == 0
            tuile.texte:SetText(nom or ("Sort " .. t.sort))
            tuile.icone:SetTexture(icone)
            tuile.icone:SetDesaturated(t.etat == 0)
            tuile:Choisir(choix[t.sort] == true)
            if choix[t.sort] then nombre = nombre + 1 end
            tuile.etat:SetText(t.etat == 0 and "Verrouillée" or (choix[t.sort] and "Équipée" or "Disponible"))
            tuile.texte:SetTextColor(S.Couleur(t.etat == 0 and "gris" or (choix[t.sort] and "ambreClair" or "texte")))
        end
    end
    compte:SetText(nombre .. " / " .. EQUIPEES_MAX .. " équipées")
end
S.Abonner("kit", function() if f:IsShown() then MajTechniques() end end)

------------------------------------------------------------------------
-- Page 3 : feu de camp et potion
------------------------------------------------------------------------
local p3 = pages[3]
local fiches = {}
local TEXTES = {
    [POTION] = { "Rend 30 % de la vie maximale.", "1 charge au départ, 30 s de recharge.",
        "Les charges reviennent avec le Repos au coin du feu, et en zone de repos." },
    [FEU] = { "Pose un feu pour 2 minutes ; le personnage s'assoit à côté.", "Se lever, entrer en combat ou mourir l'éteint. Recharge : 2 minutes.",
        "Assis : 6 % de la vie toutes les 2 s. Au bout de 60 s : Repos au coin du feu (vie maximale +5 %, 30 minutes) et potions rendues." },
}
for n, sort in ipairs({ POTION, FEU }) do
    local c = CreateFrame("Frame", nil, p3)
    c:SetSize(466, 300)
    c:SetPoint("TOPLEFT", 24 + (n - 1) * 482, -20)
    S.Panneau(c, 0.6, "bordCreux")
    c.icone = c:CreateTexture(nil, "ARTWORK")
    c.icone:SetSize(56, 56)
    c.icone:SetPoint("TOPLEFT", 20, -20)
    c.icone:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    c.nom = S.Texte(c, "Bold", 18, "clair")
    c.nom:SetPoint("TOPLEFT", c.icone, "TOPRIGHT", 16, -4)
    c.rang = S.Texte(c, "Regular", 12, "gris")
    c.rang:SetPoint("TOPLEFT", c.nom, "BOTTOMLEFT", 0, -6)
    c.rang:SetText("Rang de départ · améliorations à venir")
    local y = -100
    for _, ligne in ipairs(TEXTES[sort]) do
        local t = S.Texte(c, "Regular", 14, "texte")
        t:SetPoint("TOPLEFT", 20, y)
        t:SetWidth(426)
        t:SetJustifyH("LEFT")
        t:SetText(ligne)
        y = y - t:GetStringHeight() - 12
    end
    c.etat = S.Texte(c, "SemiBold", 14, "ambreClair")
    c.etat:SetPoint("BOTTOMLEFT", 20, 20)
    c.sort = sort
    fiches[n] = c
end

local function MajFiches()
    for _, c in ipairs(fiches) do
        local nom, _, icone = GetSpellInfo(c.sort)
        c.nom:SetText(nom or "")
        c.icone:SetTexture(icone)
        if c.sort == POTION then
            c.etat:SetText(S.etat.charges and ("Charges : " .. S.etat.charges .. " / " .. S.etat.chargesMax) or "")
        else
            c.etat:SetText("Touche : " .. (Touche("CLICK SolUIBivouac" .. FEU .. ":LeftButton") or "aucune"))
        end
    end
end

------------------------------------------------------------------------
f:SetScript("OnShow", function()
    choixModifie = false
    retour:SetText("")
    message = ""
    Maj(); MajTechniques(); MajFiches()
end)
f:SetScript("OnHide", function()
    if modifie then SaveBindings(GetCurrentBindingSet()) end
    modifie, capture = false, nil
    f:EnableKeyboard(false)
    voile:Hide()
end)
S.Ecouter("UPDATE_BINDINGS", function() if f:IsShown() then Maj(); MajFiches() end end)
S.Ecouter("ACTIONBAR_SLOT_CHANGED", function() if f:IsShown() then Maj() end end)
Onglet(1)
