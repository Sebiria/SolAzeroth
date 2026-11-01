-- Sol'Azeroth v3, F4 : la zone (maquette Arène, reprise dans Synthèse), en haut à droite.
-- Nom de la zone, puissance conseillée (calculée par le serveur d'après ses monstres), sous-zone et, depuis F5e,
-- pourcentage de la zone. Puis la mini-carte ronde et le bouton Menu, qui remplace le micro-menu de Blizzard.
-- Objectifs de zone (31/10/2026) : un clic sur le suivi ouvre la fenêtre des objectifs (lieux, primes, contrats, défis,
-- reliques et leurs indices ; données dans SolUI_Annexes.lua, état envoyé par v3_zone.cpp). Le chrono d'un défi
-- (v3_annexes.cpp) s'affiche sous le suivi.

local S = SolUI

local zone = CreateFrame("Frame", "SolUIZone", S.racine)
zone:SetSize(248 + 12 + 92, 160)
S.Placer(zone, "zone")

------------------------------------------------------------------------
-- Suivi de zone
------------------------------------------------------------------------
local suivi = CreateFrame("Frame", nil, zone)
suivi:SetSize(248, 58)
suivi:SetPoint("TOPLEFT")
S.Panneau(suivi, 0.85)

local nom = S.Texte(suivi, "Bold", 15, "clair")
nom:SetPoint("TOPLEFT", suivi, "TOPLEFT", 14, -11)
nom:SetPoint("RIGHT", suivi, "RIGHT", -96, 0)
nom:SetJustifyH("LEFT")
local conseillee = S.Texte(suivi, "Regular", 12, "gris")
conseillee:SetPoint("TOPRIGHT", suivi, "TOPRIGHT", -14, -13)
local sousZone = S.Texte(suivi, "Regular", 12, "gris")
sousZone:SetPoint("TOPLEFT", nom, "BOTTOMLEFT", 0, -6)
sousZone:SetPoint("RIGHT", suivi, "RIGHT", -64, 0)
sousZone:SetJustifyH("LEFT")

-- F5e (31/10/2026) : pourcentage de la zone (v3_zone.cpp), une jauge au pied du cadre ; survol : le détail.
local pourcent = S.Texte(suivi, "Bold", 13, "ambreClair")
pourcent:SetPoint("BOTTOMRIGHT", suivi, "BOTTOMRIGHT", -14, 12)
local jauge = S.Texture(suivi, "ARTWORK", nil, S.Couleur("creux"))
jauge:SetPoint("BOTTOMLEFT", suivi, "BOTTOMLEFT", 14, 6)
jauge:SetPoint("BOTTOMRIGHT", suivi, "BOTTOMRIGHT", -14, 6)
jauge:SetHeight(2)
local plein = S.Texture(suivi, "OVERLAY", nil, S.Couleur("ambre"))
plein:SetPoint("TOPLEFT", jauge)
plein:SetPoint("BOTTOMLEFT", jauge)

local progres, recu = nil, nil
local MajObjectifs, MajChrono
local function Pour(c) return (string.format("%.2f", c / 100):gsub("%.?0+$", ""):gsub("%.", ",")) .. " %" end

local function MajPourcent()
    S.Montrer(pourcent, progres)
    S.Montrer(jauge, progres)
    S.Montrer(plein, progres and progres.total > 0)
    if not progres then return end
    pourcent:SetText(Pour(progres.total))
    plein:SetWidth(math.max(1, jauge:GetWidth() * math.min(1, progres.total / 10000)))
end

S.Message("SOLZONE", function(champs)
    local genre = champs[1]
    -- Chef renforcé apparu (v3_zone.cpp) : alerte de raid avec son bruit, comme une annonce de raid.
    if genre == "ALERTE" then
        RaidNotice_AddMessage(RaidWarningFrame, champs[2] or "", ChatTypeInfo["RAID_WARNING"])
        PlaySound("RaidWarning")
        return
    end
    if genre == "CHRONO" then
        MajChrono(champs)
        return
    end
    if genre == "POURCENT" then
        if tonumber(champs[2]) < 0 then progres, recu, S.progresZone = nil, nil, nil; MajPourcent(); return end
        recu = { total = tonumber(champs[2]), histoire = tonumber(champs[3]), exploration = tonumber(champs[4]),
            annexes = tonumber(champs[5]), lieux = {}, quetes = {}, reliques = {} }
    elseif not recu then
        return
    elseif genre == "EXPLO" then
        recu.explorees, recu.sousZones = tonumber(champs[2]), tonumber(champs[3])
    elseif genre == "LIEU" then
        table.insert(recu.lieux, { nom = champs[3], tues = tonumber(champs[4]), requis = tonumber(champs[5]),
            part = tonumber(champs[6]), fait = champs[7] == "1", attente = champs[8] ~= "" and champs[8] or nil })
    elseif genre == "ANNEXE" then
        recu.quetes[tonumber(champs[2])] = { etat = tonumber(champs[3]), medaille = tonumber(champs[4]) }
    elseif genre == "RELIQUE" then
        recu.reliques[tonumber(champs[2])] = champs[3] == "1"
    elseif genre == "CARTE" then
        recu.carte = champs[2] == "1"
    elseif genre == "FINZONE" then
        progres = recu
        S.progresZone = progres   -- reliques sur les cartes (SolUI_Quetes.lua)
        S.Prevenir("zone")
        MajPourcent()
        MajObjectifs()
    end
end)

suivi:EnableMouse(true)
suivi:SetScript("OnEnter", function(self)
    if not progres then return end
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
    GameTooltip:AddDoubleLine(GetZoneText() or "", Pour(progres.total), 1, 0.82, 0, 1, 0.82, 0)
    GameTooltip:AddDoubleLine("Histoire", Pour(progres.histoire) .. " / 50 %", 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine(string.format("Exploration (%d / %d)", progres.explorees or 0, progres.sousZones or 0),
        Pour(progres.exploration) .. " / 6 %", 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("Annexes", Pour(progres.annexes) .. " / 44 %", 1, 1, 1, 1, 1, 1)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Lieux à nettoyer", 1, 0.82, 0)
    for _, l in ipairs(progres.lieux) do
        local fait = l.fait
        local r, g, b = 0.75, 0.75, 0.75
        if fait then r, g, b = 0.4, 1, 0.4 end
        GameTooltip:AddDoubleLine(l.nom, fait and ("nettoyé, " .. Pour(l.part)) or string.format("%d / %d", l.tues, l.requis),
            r, g, b, r, g, b)
        if l.attente then
            GameTooltip:AddLine("  Chef retenu tant que « " .. l.attente .. " » n'est pas remplie", 1, 0.6, 0.3)
        end
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Clic : objectifs de la zone", 0.7, 0.7, 0.7)
    GameTooltip:Show()
end)
suivi:SetScript("OnLeave", function() GameTooltip:Hide() end)
MajPourcent()

------------------------------------------------------------------------
-- Fenêtre des objectifs de zone
------------------------------------------------------------------------
local objectifs = S.Fenetre("SolUIObjectifs", 760, 700, "Objectifs de la zone")
function S.BasculerObjectifs()
    if objectifs:IsShown() then objectifs:Hide() else objectifs:Show() end
end
suivi:SetScript("OnMouseUp", function() S.BasculerObjectifs() end)

local defile = CreateFrame("ScrollFrame", "SolUIObjectifsDefile", objectifs)
defile:SetPoint("TOPLEFT", objectifs, "TOPLEFT", 28, -64)
-- Le bas de la liste s'arrête au-dessus du filet, de la consigne des modes et des boutons (01/11/2026 : la dernière
-- ligne visible passait sous la consigne).
defile:SetPoint("BOTTOMRIGHT", objectifs, "BOTTOMRIGHT", -28, 92)
local filetBas = S.Texture(objectifs, "ARTWORK", nil, S.Couleur("bord"))
filetBas:SetPoint("BOTTOMLEFT", objectifs, "BOTTOMLEFT", 1, 82)
filetBas:SetPoint("BOTTOMRIGHT", objectifs, "BOTTOMRIGHT", -1, 82)
filetBas:SetHeight(1)
defile:EnableMouseWheel(true)
local page = CreateFrame("Frame", nil, defile)
page:SetSize(700, 10)
defile:SetScrollChild(page)
defile:SetScript("OnMouseWheel", function(self, sens)
    local maxi = math.max(0, page:GetHeight() - self:GetHeight())
    self:SetVerticalScroll(math.max(0, math.min(maxi, self:GetVerticalScroll() - sens * 40)))
end)

-- 300 de large : les quatre boutons de mode commencent à 346 du bord gauche (01/11/2026 : « Aucun » le chevauchait).
local acheterCarte = S.BoutonPlat(objectifs, "Carte des reliques (30 Marques, 2 po)", 300, 32, 12)
acheterCarte:SetPoint("BOTTOMLEFT", objectifs, "BOTTOMLEFT", 28, 18)
acheterCarte:SetScript("OnClick", function() SendChatMessage(".annexes carte", "SAY") end)

-- Lignes réutilisées : un titre à gauche, une valeur à droite, une note grise dessous (facultative).
local lignes = {}
local function Ligne(n)
    local l = lignes[n]
    if not l then
        l = {}
        l.titre = S.Texte(page, "SemiBold", 13, "texte")
        l.titre:SetJustifyH("LEFT")
        l.titre:SetWidth(470)
        l.valeur = S.Texte(page, "Regular", 12, "gris")
        l.valeur:SetJustifyH("RIGHT")
        l.valeur:SetWidth(230)
        l.note = S.Texte(page, "Regular", 11, "gris")
        l.note:SetJustifyH("LEFT")
        l.note:SetWidth(680)
        lignes[n] = l
    end
    return l
end

local ETATS = { [0] = "à prendre", "en cours", "à rendre", "rendue" }
local MEDAILLES = { "bronze", "argent", "or" }
local FAMILLES = { "Primes", "Contrats", "Défis" }

function MajObjectifs()
    if not objectifs:IsShown() then return end
    local n, y = 0, 0
    local function Ecrire(titre, valeur, note, couleur, rubrique)
        n = n + 1
        local l = Ligne(n)
        l.titre:SetTextColor(S.Couleur(couleur or "texte"))
        l.titre:SetText(titre)
        l.valeur:SetText(valeur or "")
        l.note:SetText(note or "")
        l.titre:ClearAllPoints()
        l.titre:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -y)
        l.valeur:ClearAllPoints()
        l.valeur:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, -y)
        l.titre:Show()
        l.valeur:Show()
        y = y + (rubrique and 24 or 20)
        if note and note ~= "" then
            l.note:ClearAllPoints()
            l.note:SetPoint("TOPLEFT", page, "TOPLEFT", 12, -y)
            l.note:Show()
            y = y + 18
        else
            l.note:Hide()
        end
    end
    if not progres then
        Ecrire("Cette zone n'a pas d'objectifs.", nil, nil, "gris")
    else
        Ecrire("Lieux à nettoyer", nil, nil, "ambreClair", true)
        for _, l in ipairs(progres.lieux) do
            Ecrire(l.nom, l.fait and ("nettoyé · " .. Pour(l.part))
                or string.format("%d / %d · %s", l.tues, l.requis, Pour(l.part)),
                l.attente and ("Chef retenu tant que « " .. l.attente .. " » n'est pas remplie"), l.fait and "vertClair" or "texte")
        end
        for _, famille in ipairs(FAMILLES) do
            y = y + 10
            Ecrire(famille, nil, nil, "ambreClair", true)
            local liste = {}
            for quete, a in pairs(S.ANNEXES or {}) do
                if a.famille == famille and progres.quetes[quete] then table.insert(liste, quete) end
            end
            table.sort(liste)
            for _, quete in ipairs(liste) do
                local a, e = S.ANNEXES[quete], progres.quetes[quete]
                local valeur = string.format("puissance %d · %s · %s", a.puissance, Pour(a.part), ETATS[e.etat] or "")
                if e.medaille and e.medaille > 0 then valeur = valeur .. " · " .. MEDAILLES[e.medaille] end
                Ecrire(a.cle .. " — " .. a.titre, valeur, a.resume, e.etat == 3 and "vertClair" or "texte")
            end
        end
        y = y + 10
        Ecrire("Reliques cachées", nil, nil, "ambreClair", true)
        for f, famille in ipairs(S.FAMILLES_RELIQUES or {}) do
            local trouvees, total = 0, 0
            for _, r in ipairs(S.RELIQUES) do
                if r.famille == f then
                    total = total + 1
                    if progres.reliques[r.objet] then trouvees = trouvees + 1 end
                end
            end
            Ecrire(famille.nom .. string.format(" (%d / %d)", trouvees, total), "complète : " .. famille.bonus, nil, "gris")
            for _, r in ipairs(S.RELIQUES) do
                if r.famille == f then
                    local trouvee = progres.reliques[r.objet]
                    local note = "« " .. r.indice .. " »"
                    if progres.carte and not trouvee then note = note .. string.format("  ·  vers (%d, %d)", r.x, r.y) end
                    Ecrire(r.cle .. " — " .. (trouvee and r.nom or "relique inconnue"),
                        (trouvee and "trouvée · " or string.format("puissance %d · ", r.puissance)) .. Pour(25), note,
                        trouvee and "vertClair" or "texte")
                end
            end
        end
    end
    for i = n + 1, #lignes do
        lignes[i].titre:Hide()
        lignes[i].valeur:Hide()
        lignes[i].note:Hide()
    end
    page:SetHeight(math.max(10, y))
    S.Montrer(acheterCarte, progres and not progres.carte)
end
objectifs:SetScript("OnShow", function() MajObjectifs() end)

------------------------------------------------------------------------
-- F9 (01/11/2026) : mode de la zone (v3_modes.cpp, « MODE;zone;mode;débloqué;au repos;cauchemar actif;modes
-- ouverts » : difficile au palier 5 du rang d'aventurier, cauchemar au palier 9).
-- Choix dans la fenêtre des objectifs (à 60 % de la zone, dans une auberge ou une ville), rappel dans le suivi,
-- et un voile rouge sur le monde quand le cauchemar est actif.
------------------------------------------------------------------------
local MODES = { [0] = "Aucun", "Normal", "Difficile", "Cauchemar" }
local COMMANDES = { [0] = "aucun", "normal", "difficile", "cauchemar" }
local etatMode = { mode = 0 }

local texteMode = S.Texte(suivi, "SemiBold", 11, "gris")
texteMode:SetPoint("RIGHT", pourcent, "LEFT", -8, 0)

local consigne = S.Texte(objectifs, "Regular", 11, "gris")
consigne:SetPoint("BOTTOMRIGHT", objectifs, "BOTTOMRIGHT", -28, 56)
local boutonsMode = {}
for m = 3, 0, -1 do
    local b = S.BoutonPlat(objectifs, MODES[m], 92, 32, 12)
    b:SetPoint("BOTTOMRIGHT", objectifs, "BOTTOMRIGHT", -28 - (3 - m) * 98, 18)
    b:SetScript("OnClick", function() SendChatMessage(".mode " .. COMMANDES[m], "SAY") end)
    boutonsMode[m] = b
end

local voile = CreateFrame("Frame", nil, WorldFrame)
voile:SetAllPoints()
local rouge = S.Texture(voile, "BACKGROUND", nil, 0.55, 0.05, 0.05)
rouge:SetAllPoints()
rouge:SetAlpha(0.12)
voile:Hide()

local function MajMode()
    local m = etatMode.mode
    texteMode:SetText(m > 0 and MODES[m] or "")
    if m == 3 then texteMode:SetTextColor(S.Couleur("rouge")) else texteMode:SetTextColor(S.Couleur("gris")) end
    for n, b in pairs(boutonsMode) do
        b:Choisir(n == m)
        local ouvert = n < 2 or (etatMode.ouverts or 0) >= n - 1
        if etatMode.debloque and etatMode.repos and ouvert and n ~= m then b:Enable() else b:Disable() end
    end
    consigne:SetText(not etatMode.debloque and "Modes de zone : à 60 % de la zone."
        or not etatMode.repos and "Mode de zone : à choisir dans une auberge ou une ville."
        or (etatMode.ouverts or 0) < 2 and "Difficile au palier 5 du rang d'aventurier, cauchemar au palier 9."
        or "Mode de zone : difficile et cauchemar donnent plus d'éclats.")
    S.Montrer(voile, etatMode.cauchemar)
end

S.Message("SOLMODE", function(champs)
    if champs[1] ~= "MODE" then return end
    local avant = etatMode
    etatMode = { zone = tonumber(champs[2]), mode = tonumber(champs[3]) or 0, debloque = champs[4] == "1",
        repos = champs[5] == "1", cauchemar = champs[6] == "1", ouverts = tonumber(champs[7]) or 0 }
    -- 60 % atteint pendant la partie : annonce cliquable vers Aventure › Zone (SolUI_Carnets.lua).
    if etatMode.debloque and avant.zone == etatMode.zone and avant.debloque == false then
        S.Annonce("Les modes de zone sont ouverts", "Aventure › Zone", function() S.OuvrirCarnet("aventure", 2) end)
    end
    MajMode()
end)
MajMode()

------------------------------------------------------------------------
-- Chrono d'un défi : « CHRONO;quête;écoulé;bronze;argent;or;fini », ou « CHRONO;- »
------------------------------------------------------------------------
local chrono = CreateFrame("Frame", nil, zone)
chrono:SetSize(248, 30)
chrono:SetPoint("TOPLEFT", suivi, "BOTTOMLEFT", 0, -6)
S.Panneau(chrono, 0.85)
local texteChrono = S.Texte(chrono, "SemiBold", 13, "ambreClair")
texteChrono:SetPoint("LEFT", chrono, "LEFT", 14, 0)
chrono:Hide()

local function MinSec(s) return string.format("%d:%02d", math.floor(s / 60), s % 60) end

function MajChrono(champs)
    local quete = tonumber(champs[2])
    if not quete then chrono:Hide() return end
    local ecoule, bronze, argent, ors = tonumber(champs[3]), tonumber(champs[4]), tonumber(champs[5]), tonumber(champs[6])
    local a = S.ANNEXES and S.ANNEXES[quete]
    local visee, nom = bronze, "bronze"
    if ecoule <= ors then visee, nom = ors, "or" elseif ecoule <= argent then visee, nom = argent, "argent" end
    texteChrono:SetText(string.format("%s  %s  ·  %s avant %s%s", a and a.cle or "", MinSec(ecoule), nom, MinSec(visee),
        champs[7] == "1" and "  ·  à rendre" or ""))
    chrono:Show()
end

local function MajZone()
    nom:SetText(GetZoneText() or "")
    local sous = GetSubZoneText()
    sousZone:SetText(sous ~= GetZoneText() and sous or "")
    local valeur = S.PuissanceConseillee()
    conseillee:SetText(valeur and ("Conseillée " .. valeur) or "")
end

for _, evenement in ipairs({ "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD" }) do
    S.Ecouter(evenement, MajZone)
end
S.Abonner("zone", MajZone)

------------------------------------------------------------------------
-- Mini-carte ronde : celle de Blizzard, sortie de son cadre et débarrassée de ses ornements
------------------------------------------------------------------------
local colonne = CreateFrame("Frame", nil, zone)
colonne:SetSize(92, 140)
colonne:SetPoint("TOPRIGHT")

Minimap:SetParent(colonne)
Minimap:ClearAllPoints()
Minimap:SetPoint("TOP", colonne, "TOP")
Minimap:SetSize(92, 92)
Minimap:EnableMouseWheel(true)
Minimap:SetScript("OnMouseWheel", function(self, sens)
    if sens > 0 then Minimap_ZoomIn() else Minimap_ZoomOut() end
end)

-- Taille réglable (Réglages > Interface) : la colonne et le bloc de la zone suivent.
local function TaillerCarte()
    local t = S.OPTIONS.carte
    Minimap:SetSize(t, t)
    colonne:SetSize(t, t + 48)
    zone:SetSize(248 + 12 + t, math.max(160, t + 68))
    -- La mini-carte ne redessine son contenu à la nouvelle taille qu'après un changement de zoom.
    local zoom = Minimap:GetZoom()
    Minimap:SetZoom(zoom > 0 and zoom - 1 or zoom + 1)
    Minimap:SetZoom(zoom)
end
S.Abonner("options", TaillerCarte)

local anneau = S.Texture(Minimap, "OVERLAY", "Anneau", 0.227, 0.239, 0.263)
anneau:SetPoint("TOPLEFT", -1, 1)
anneau:SetPoint("BOTTOMRIGHT", 1, -1)

for _, nomCadre in ipairs({ "MinimapCluster", "MinimapBorder", "MinimapBorderTop", "MinimapZoomIn", "MinimapZoomOut",
        "MinimapZoneTextButton", "MiniMapWorldMapButton", "GameTimeFrame", "MiniMapTracking", "MiniMapMailFrame",
        "MiniMapBattlefieldFrame", "MiniMapLFGFrame", "MiniMapVoiceChatFrame", "MinimapNorthTag",
        "MinimapCompassTexture", "MiniMapInstanceDifficulty", "MinimapBackdrop", "MiniMapRecordingButton" }) do
    local cadre = _G[nomCadre]
    if cadre then
        if cadre:GetObjectType() == "Texture" then cadre:Hide() else S.Ranger(cadre) end
    end
end

-- Boutons posés autour de la mini-carte par les addons (WeakAuras…) : rangés une fois tout chargé.
S.Ecouter("PLAYER_ENTERING_WORLD", function()
    for _, enfant in ipairs({ Minimap:GetChildren() }) do
        if enfant:GetObjectType() == "Button" then S.Ranger(enfant) end
    end
end)

-- L'horloge (Blizzard_TimeManager) arrive plus tard.
S.Ecouter("ADDON_LOADED", function(_, addon)
    if addon == "Blizzard_TimeManager" and TimeManagerClockButton then S.Ranger(TimeManagerClockButton) end
end)

------------------------------------------------------------------------
-- Bouton Menu : fenêtres du jeu, qui passaient par le micro-menu
------------------------------------------------------------------------
local menu = CreateFrame("Button", "SolUIMenu", colonne)
menu:SetSize(40, 40)
menu:SetPoint("TOP", Minimap, "BOTTOM", 0, -8)
menu:SetBackdrop({ bgFile = S.BLANC, edgeFile = S.BLANC, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
menu:SetBackdropColor(0.086, 0.09, 0.102, 0.88)
menu:SetBackdropBorderColor(0.2, 0.212, 0.235)
for i = -1, 1 do
    local trait = S.Texture(menu, "ARTWORK", nil, 0.843, 0.855, 0.871)
    trait:SetSize(16, 2)
    trait:SetPoint("CENTER", 0, i * 5)
end
menu:SetScript("OnEnter", function(self)
    self:SetBackdropBorderColor(S.Couleur("texte", 0.7))
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Menu")
end)
menu:SetScript("OnLeave", function(self)
    self:SetBackdropBorderColor(0.2, 0.212, 0.235)
    GameTooltip:Hide()
end)

local deroulant = CreateFrame("Frame", "SolUIMenuDeroulant", UIParent, "UIDropDownMenuTemplate")

-- Les carnets, la carte et le menu du jeu (SolUI_Carnets.lua : une seule liste pour la barre et ce menu).
menu:SetScript("OnClick", function(self)
    EasyMenu(S.ListeMenu(), deroulant, self, 0, 0, "MENU")
end)
