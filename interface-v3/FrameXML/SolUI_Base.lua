-- Sol'Azeroth v3, F4 (31/10/2026) : écran de combat, d'après la maquette « 6 · Synthèse » (document v3, §2.1).
-- Ces fichiers sont ajoutés à FrameXML par le patch du client (outils\interface_v3.py) : ils gardent les droits de
-- Blizzard, même en combat.
-- Base commune : polices Inter, couleurs, racine à l'échelle de la maquette, messages du serveur.

SolUI = {}
local S = SolUI

S.MEDIA = "Interface\\SolAzeroth\\"
S.TEXTURES = S.MEDIA .. "Textures\\"
S.BLANC = "Interface\\Buttons\\WHITE8X8"

local POLICES = {
    Light = S.MEDIA .. "Polices\\Inter-Light.ttf",
    Regular = S.MEDIA .. "Polices\\Inter-Regular.ttf",
    SemiBold = S.MEDIA .. "Polices\\Inter-SemiBold.ttf",
    Bold = S.MEDIA .. "Polices\\Inter-Bold.ttf",
}

-- Couleurs de la maquette (r, g, b de 0 à 1).
S.C = {
    texte = { 0.91, 0.914, 0.922 },       -- #e8e9eb
    clair = { 0.945, 0.949, 0.957 },      -- #f1f2f4
    gris = { 0.706, 0.722, 0.749 },       -- #b4b8bf
    ambre = { 0.941, 0.635, 0.227 },      -- #f0a23a
    ambreClair = { 0.965, 0.761, 0.478 }, -- #f6c27a
    vert = { 0.373, 0.604, 0.494 },       -- #5f9a7e
    vertClair = { 0.549, 0.769, 0.651 },  -- #8cc4a6
    rouge = { 0.788, 0.282, 0.243 },      -- #c9483e
    rougeClair = { 0.941, 0.569, 0.541 }, -- #f0918a
    bleu = { 0.478, 0.702, 0.902 },       -- #7ab3e6
    fond = { 0.078, 0.082, 0.094 },       -- #141518
    bord = { 0.184, 0.196, 0.220 },       -- #2f3238
    creux = { 0.059, 0.063, 0.071 },      -- #0f1012
    bordCreux = { 0.165, 0.176, 0.196 },  -- #2a2d32
}

function S.Couleur(nom, alpha)
    local c = S.C[nom]
    return c[1], c[2], c[3], alpha or 1
end

------------------------------------------------------------------------
-- Racine : 1 unité = 1 pixel de la maquette (900 de haut), quelle que soit la résolution.
------------------------------------------------------------------------
local racine = CreateFrame("Frame", "SolUIRacine", UIParent)
racine:SetFrameStrata("BACKGROUND")
racine:SetFrameLevel(1)
S.racine = racine

local function Dimensionner()
    local hauteur = UIParent:GetHeight()
    if not hauteur or hauteur <= 0 then return end
    local echelle = hauteur / 900
    racine:SetScale(echelle)
    racine:ClearAllPoints()
    racine:SetPoint("CENTER", UIParent, "CENTER")
    racine:SetWidth(UIParent:GetWidth() / echelle)
    racine:SetHeight(900)
end
Dimensionner()

------------------------------------------------------------------------
-- Disposition des blocs : point d'ancrage sur la racine, décalage, échelle et largeur. Une seule table, pour que la
-- future page de réglages (interface paramétrable) n'ait qu'elle à changer, puis à rappeler S.Placer.
------------------------------------------------------------------------
S.DISPOSITION = {
    perso = { point = "CENTER", x = 0, y = -118, echelle = 1 },
    techniques = { point = "BOTTOM", x = 0, y = 30, echelle = 1 },
    cible = { point = "TOP", x = 0, y = -18, echelle = 1, largeur = 720 },
    zone = { point = "TOPRIGHT", x = -20, y = -20, echelle = 1 },
}
S.blocs = {}

-- Un bloc qui a « sous » (nom d'un autre bloc) se range sous lui tant que le joueur ne l'a pas déplacé.
function S.Placer(cadre, nom)
    local d = S.DISPOSITION[nom]
    S.blocs[nom] = cadre
    cadre:SetScale(d.echelle or 1)
    cadre:ClearAllPoints()
    if d.sous and S.blocs[d.sous] then
        cadre:SetPoint("TOPRIGHT", S.blocs[d.sous], "BOTTOMRIGHT", 0, -12 / (d.echelle or 1))
    else
        cadre:SetPoint(d.point, racine, d.point, d.x / (d.echelle or 1), d.y / (d.echelle or 1))
    end
    if d.largeur then cadre:SetWidth(d.largeur) end
end

-- Réglages qui ne sont pas des blocs : taille de la mini-carte (unités de la maquette), taille des repères de quête.
S.OPTIONS = { carte = 92, reperes = 1 }

------------------------------------------------------------------------
-- Fabriques
------------------------------------------------------------------------
-- Texte en Inter, avec une ombre pour rester lisible sur le décor.
function S.Texte(parent, graisse, taille, couleur, alpha, couche)
    local texte = parent:CreateFontString(nil, couche or "OVERLAY")
    texte:SetFont(POLICES[graisse] or POLICES.Regular, taille)
    texte:SetShadowColor(0, 0, 0, 0.85)
    texte:SetShadowOffset(1, -1)
    texte:SetTextColor(S.Couleur(couleur or "texte", alpha))
    return texte
end

function S.Police(texte, graisse, taille)
    texte:SetFont(POLICES[graisse] or POLICES.Regular, taille)
end

-- Texture de Interface\SolAzeroth\Textures (nom) ou unie (nil), teintée.
function S.Texture(parent, couche, nom, r, g, b, a)
    local texture = parent:CreateTexture(nil, couche or "ARTWORK")
    texture:SetTexture(nom and (S.TEXTURES .. nom) or S.BLANC)
    texture:SetVertexColor(r or 1, g or 1, b or 1, a or 1)
    return texture
end

-- Panneau de la maquette : fond graphite translucide et filet d'un pixel.
function S.Panneau(cadre, alpha, bord)
    cadre:SetBackdrop({ bgFile = S.BLANC, edgeFile = S.BLANC, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
    cadre:SetBackdropColor(S.Couleur("fond", alpha or 0.92))
    cadre:SetBackdropBorderColor(S.Couleur(bord or "bord"))
end

function S.Montrer(objet, visible)
    if visible then objet:Show() else objet:Hide() end
end

-- 1840 -> « 1 840 » ; 1.25 -> « 1,3 » (décimales voulues).
function S.Nombre(valeur, decimales)
    if decimales and decimales > 0 then
        return (string.format("%." .. decimales .. "f", valeur):gsub("%.", ","))
    end
    local texte = tostring(math.floor(valeur + 0.5))
    local signe, chiffres = texte:match("^(-?)(%d+)$")
    if not chiffres then return texte end
    chiffres = chiffres:reverse():gsub("(%d%d%d)", "%1 "):reverse():gsub("^ ", "")
    return signe .. chiffres
end

-- 12345 -> « 1 [or] 23 [argent] 45 [cuivre] », avec les icônes des pièces du jeu.
local PIECES = { "Interface\\MoneyFrame\\UI-GoldIcon", "Interface\\MoneyFrame\\UI-SilverIcon",
    "Interface\\MoneyFrame\\UI-CopperIcon" }
function S.Argent(cuivre)
    local valeurs = { math.floor(cuivre / 10000), math.floor(cuivre / 100) % 100, cuivre % 100 }
    local morceaux = {}
    for i, valeur in ipairs(valeurs) do
        if valeur > 0 then table.insert(morceaux, valeur .. " |T" .. PIECES[i] .. ":0:0:0:-1|t") end
    end
    return table.concat(morceaux, "  ")
end

-- Fenêtre des maquettes « 7 » et « 8 » : panneau déplaçable par sa barre de titre, fermée par Échap.
function S.Fenetre(nom, largeur, hauteur, titre)
    local f = CreateFrame("Frame", nom, S.racine)
    f:SetSize(largeur, hauteur)
    f:SetPoint("CENTER", S.racine, "CENTER", 0, 10)
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    S.Panneau(f, 0.97)
    f:Hide()
    tinsert(UISpecialFrames, nom)
    local barre = CreateFrame("Frame", nil, f)
    barre:SetPoint("TOPLEFT")
    barre:SetPoint("TOPRIGHT")
    barre:SetHeight(56)
    barre:EnableMouse(true)
    barre:RegisterForDrag("LeftButton")
    barre:SetScript("OnDragStart", function() f:StartMoving() end)
    barre:SetScript("OnDragStop", function() f:StopMovingOrSizing(); f:SetUserPlaced(false) end)
    f.titre = S.Texte(barre, "Bold", 20, "clair")
    f.titre:SetPoint("LEFT", 24, -2)
    f.titre:SetText(titre)
    f.barre = barre
    local fermer = CreateFrame("Button", nil, barre, "UIPanelCloseButton")
    fermer:SetPoint("RIGHT", -8, 0)
    fermer:SetScript("OnClick", function() f:Hide() end)
    return f
end

-- Bouton plat : filet gris, fond ambre quand il est choisi (b:Choisir(vrai)).
function S.BoutonPlat(parent, texte, largeur, hauteur, taille)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(largeur, hauteur or 36)
    b:SetBackdrop({ bgFile = S.BLANC, edgeFile = S.BLANC, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
    b.texte = S.Texte(b, "SemiBold", taille or 13, "texte")
    b.texte:SetPoint("CENTER")
    b.texte:SetText(texte or "")
    function b:Choisir(oui)
        self.choisi = oui
        self:SetBackdropColor(0.165, 0.129, 0.086, oui and 1 or 0)
        self:SetBackdropBorderColor(S.Couleur(oui and "ambre" or "bord"))
        self.texte:SetTextColor(S.Couleur(oui and "ambreClair" or "texte"))
    end
    b:SetScript("OnEnter", function(self) if not self.choisi then self:SetBackdropBorderColor(S.Couleur("gris", 0.8)) end end)
    b:SetScript("OnLeave", function(self) self:Choisir(self.choisi) end)
    b:Choisir(false)
    return b
end

-- Durée restante : « 7 s », « 28 min », « 2 h ».
function S.Duree(secondes)
    if secondes >= 3600 then return math.floor(secondes / 3600 + 0.5) .. " h" end
    if secondes >= 60 then return math.floor(secondes / 60 + 0.5) .. " min" end
    return math.ceil(secondes) .. " s"
end

-- Touche abrégée pour un bouton : « a-A », et pour la souris « S4 » (bouton 4), « MH » et « MB » (molette), car
-- « Bouton de souris 4 » débordait du bouton (capture du 31/10/2026).
local SOURIS = { MOUSEWHEELUP = "MH", MOUSEWHEELDOWN = "MB", BUTTON3 = "S3", BUTTON4 = "S4", BUTTON5 = "S5" }
function S.ToucheCourte(touche)
    if not touche then return "" end
    local modificateurs, base = touche:match("^(.-)([^-]+)$")
    if not base or not SOURIS[base] then return GetBindingText(touche, "KEY_", 1) end
    return modificateurs:gsub("ALT%-", "a-"):gsub("CTRL%-", "c-"):gsub("SHIFT%-", "s-") .. SOURIS[base]
end

------------------------------------------------------------------------
-- Événements et messages du serveur
------------------------------------------------------------------------
local ecoutes = {}
local messages = {}
local ecoute = CreateFrame("Frame")

function S.Ecouter(evenement, fonction)
    if not ecoutes[evenement] then
        ecoutes[evenement] = {}
        ecoute:RegisterEvent(evenement)
    end
    table.insert(ecoutes[evenement], fonction)
end

-- Messages d'addon du serveur (mod-solazeroth) : préfixe, puis champs séparés par « ; ».
function S.Message(prefixe, fonction)
    messages[prefixe] = messages[prefixe] or {}
    table.insert(messages[prefixe], fonction)
end

ecoute:SetScript("OnEvent", function(self, evenement, ...)
    if evenement == "CHAT_MSG_ADDON" then
        local prefixe, message = ...
        if messages[prefixe] and message then
            local champs = { strsplit(";", message) }
            for _, fonction in ipairs(messages[prefixe]) do fonction(champs) end
        end
    end
    if ecoutes[evenement] then
        for _, fonction in ipairs(ecoutes[evenement]) do fonction(evenement, ...) end
    end
end)
S.Ecouter("CHAT_MSG_ADDON", function() end)
S.Ecouter("DISPLAY_SIZE_CHANGED", Dimensionner)
S.Ecouter("UI_SCALE_CHANGED", Dimensionner)
S.Ecouter("PLAYER_ENTERING_WORLD", Dimensionner)

------------------------------------------------------------------------
-- État partagé, tenu à jour par les messages du serveur
------------------------------------------------------------------------
-- spe : 0 aucune, 1 guerrier tank (v3_kit.cpp) ; rempart : nil tant que le serveur n'en a rien dit.
S.etat = { spe = nil, rempart = nil, plafond = 0, puissance = nil, zoneMin = nil, zoneMax = nil,
           ciblePuissance = nil, cibleMalus = 0 }
local abonnes = {}

-- Prévient les cadres qu'une partie de l'état a changé (« kit », « puissance », « zone »).
function S.Abonner(sujet, fonction)
    abonnes[sujet] = abonnes[sujet] or {}
    table.insert(abonnes[sujet], fonction)
end

local function Prevenir(sujet)
    for _, fonction in ipairs(abonnes[sujet] or {}) do fonction() end
end
S.Prevenir = Prevenir

-- SOLKIT (v3_kit.cpp) : « ETAT;spe;… » et « REMPART;montant;plafond ».
S.Message("SOLKIT", function(champs)
    if champs[1] == "ETAT" then
        S.etat.spe = tonumber(champs[2])
        if S.etat.spe ~= 1 then S.etat.rempart = nil end
        -- « sort:état,… » dans l'ordre de déblocage ; état 0 verrouillée, 1 débloquée, 2 équipée.
        S.etat.techniques = {}
        for sort, etat in (champs[5] or ""):gmatch("(%d+):(%d)") do
            table.insert(S.etat.techniques, { sort = tonumber(sort), etat = tonumber(etat) })
        end
        Prevenir("kit")
    elseif champs[1] == "REMPART" then
        S.etat.rempart = tonumber(champs[2]) or 0
        S.etat.plafond = tonumber(champs[3]) or 0
        Prevenir("kit")
    end
end)

-- SOLPUISSANCE (v3_combat.cpp) : « PUISSANCE;joueur[;puissance de la cible;malus en %] », et « PROCHES;guid:puissance;… »
-- pour les monstres à moins de 60 m, gardés ici pour afficher la puissance d'une cible dès qu'on la choisit.
S.puissancesProches, S.nombreProches = {}, 0
S.Message("SOLPUISSANCE", function(champs)
    if champs[1] == "PROCHES" then
        if S.nombreProches > 2000 then S.puissancesProches, S.nombreProches = {}, 0 end
        for n = 2, #champs do
            local guid, valeur = champs[n]:match("^(%x+):(%d+)$")
            if guid then
                if not S.puissancesProches[guid] then S.nombreProches = S.nombreProches + 1 end
                S.puissancesProches[guid] = tonumber(valeur)
            end
        end
        return
    end
    if champs[1] ~= "PUISSANCE" then return end
    S.etat.puissance = tonumber(champs[2])
    S.etat.ciblePuissance = tonumber(champs[3])
    S.etat.cibleMalus = tonumber(champs[4]) or 0
    Prevenir("puissance")
end)

-- SOLZONE (v3_niveau.cpp) : « ZONE;puissance basse;puissance haute » de la zone du joueur, d'après ses monstres.
S.Message("SOLZONE", function(champs)
    if champs[1] ~= "ZONE" then return end
    S.etat.zoneMin = tonumber(champs[2])
    S.etat.zoneMax = tonumber(champs[3])
    Prevenir("zone")
end)

-- « 1–10 » : puissance conseillée de la zone.
function S.PuissanceConseillee()
    local bas, haut = S.etat.zoneMin, S.etat.zoneMax
    if not bas or not haut or haut <= 0 then return nil end
    if bas == haut then return tostring(bas) end
    return bas .. "–" .. haut
end
