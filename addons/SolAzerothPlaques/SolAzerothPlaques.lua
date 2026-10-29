-- Plaques de nom (demande de l'utilisateur du 28/10/2026, dans l'esprit de Plater). Le jeu 3.3.5 ne donne pas d'accès
-- direct aux plaques : ce sont des cadres sans nom, enfants de WorldFrame, qu'on reconnaît à leur bordure. On réutilise
-- leur barre de vie et leur barre d'incantation (le jeu continue de les remplir et de les colorer), on cache le reste et
-- on ajoute nom, texte de vie et affaiblissements. Réglages : « /plaques » (gardés pour le compte).
-- Les affaiblissements d'un monstre ne sont lisibles que quand il est cible, focalisation ou sous la souris. On les
-- garde donc par GUID, et le journal de combat tient à jour ceux qu'on pose soi-même quand il n'est plus ciblé.
-- Monstres de quête (demande de l'utilisateur du 29/10/2026) : un point d'exclamation devant le nom des monstres encore
-- utiles à une quête du journal. Le serveur en donne la liste (« .solcibles ») à chaque changement du journal ; la marque
-- disparaît quand l'objectif est rempli, même si la quête n'est pas encore rendue.

local BORDURE = "Interface\\Tooltips\\Nameplate-Border"
local TEXTURES = {
    { nom = "Classique", chemin = "Interface\\TargetingFrame\\UI-StatusBar" },
    { nom = "Plate", chemin = "Interface\\Buttons\\WHITE8X8" },
    { nom = "Métier", chemin = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar" },
}
local TEXTES_VIE = { "Aucun", "Pourcentage", "Valeur", "Valeur et pourcentage" }
local DEFAUTS = {
    largeur = 120, hauteur = 10, texture = 1, texteVie = 2, police = 9, icone = 20, maxIcones = 6,
    mesSeuls = true, niveau = true, ennemisAuto = true, quetes = true,
}

local db
local plaques = {}   -- cadre de plaque -> true
local auras = {}     -- GUID -> { [sort] = { icone, nb, duree, fin, mien } }
local noms = {}      -- GUID -> nom (pour retrouver une plaque au nom unique)
local durees = {}    -- sort -> durée vue sur une cible (le journal de combat ne la donne pas)
local cibles = {}    -- nom de monstre -> true s'il sert encore à une quête
local recues         -- liste en cours de réception

------------------------------------------------------------------------
-- Affaiblissements
------------------------------------------------------------------------
local function Scanner(unite)
    local guid = UnitGUID(unite)
    if not guid or not UnitCanAttack("player", unite) then return end
    local liste = {}
    for i = 1, 40 do
        local nom, _, icone, nb, _, duree, fin, lanceur, _, _, sort = UnitDebuff(unite, i)
        if not nom then break end
        local mien = lanceur == "player" or lanceur == "pet" or lanceur == "vehicle"
        liste[sort or nom] = { icone = icone, nb = nb or 0, duree = duree or 0, fin = fin or 0, mien = mien }
        if sort and duree and duree > 0 then durees[sort] = duree end
    end
    auras[guid] = liste
    noms[guid] = UnitName(unite)
end

local function JournalDeCombat(sousEvenement, srcFlags, dstGUID, dstName, dstFlags, sort, typeAura, nb)
    if sousEvenement == "UNIT_DIED" or sousEvenement == "UNIT_DESTROYED" then
        auras[dstGUID], noms[dstGUID] = nil, nil
        return
    end
    -- 0x60 : cible hostile ou neutre (les affaiblissements des alliés ne nous intéressent pas)
    if typeAura ~= "DEBUFF" or not sort or bit.band(dstFlags or 0, 0x60) == 0 then return end
    local liste = auras[dstGUID]
    if sousEvenement == "SPELL_AURA_REMOVED" then
        if liste then liste[sort] = nil end
        return
    end
    if not liste then
        liste = {}
        auras[dstGUID] = liste
    end
    noms[dstGUID] = dstName
    local a = liste[sort]
    if not a then
        local _, _, icone = GetSpellInfo(sort)
        a = { icone = icone, nb = 0, duree = 0, fin = 0, mien = bit.band(srcFlags or 0, 0x1) ~= 0 }
        liste[sort] = a
    end
    if sousEvenement == "SPELL_AURA_APPLIED_DOSE" or sousEvenement == "SPELL_AURA_REMOVED_DOSE" then
        a.nb = nb or a.nb
    else
        local d = durees[sort]
        if d then a.duree, a.fin = d, GetTime() + d end
    end
end

------------------------------------------------------------------------
-- Habillage d'une plaque
------------------------------------------------------------------------
local function CourtNombre(v)
    if v >= 1000000 then return format("%.1fM", v / 1000000) end
    if v >= 1000 then return format("%.0fk", v / 1000) end
    return tostring(v)
end

local function Habiller(p)
    local s = p.sa
    local tex = TEXTURES[db.texture].chemin
    local police = "Fonts\\FRIZQT__.TTF"
    s.vie:ClearAllPoints()
    s.vie:SetPoint("CENTER", p, "CENTER", 0, -6)
    s.vie:SetSize(db.largeur, db.hauteur)
    s.vie:SetStatusBarTexture(tex)
    s.fond:SetTexture(tex)
    s.nom:SetFont(police, db.police + 1, "OUTLINE")
    s.texteVie:SetFont(police, db.police, "OUTLINE")
    s.niveau:SetFont(police, db.police, "OUTLINE")
    s.niveau:SetAlpha(db.niveau and 1 or 0)
    s.quete:SetSize(db.police + 6, db.police + 6)
    s.incant:SetStatusBarTexture(tex)
    for _, ic in ipairs(s.icones) do ic:SetSize(db.icone, db.icone) end
    s.largeur, s.hauteur = db.largeur, db.hauteur
end

local function PlacerIncantation(p)
    local s = p.sa
    s.incant:ClearAllPoints()
    s.incant:SetPoint("TOP", s.vie, "BOTTOM", 0, -3)
    s.incant:SetSize(db.largeur, math.max(db.hauteur - 2, 5))
    s.icIncant:ClearAllPoints()
    s.icIncant:SetPoint("RIGHT", s.incant, "LEFT", -2, 0)
    s.icIncant:SetSize(db.hauteur + 4, db.hauteur + 4)
end

local function Adopter(p)
    local menace, bordVie, bouclier, bordIncant, icIncant, surbrillance, nom, niveau, iconeBoss, iconeRaid, elite =
        p:GetRegions()
    local vie, incant = p:GetChildren()
    local s = { vie = vie, incant = incant, nomOrig = nom, niveau = niveau, surbrillance = surbrillance, iconeBoss = iconeBoss,
                icIncant = icIncant, iconeRaid = iconeRaid, icones = {} }
    p.sa = s
    plaques[p] = true

    for _, r in ipairs({ menace, bordVie, bouclier, bordIncant, elite }) do r:SetTexture(nil) end
    surbrillance:SetTexture(nil)    -- reste affichée/cachée : sert à savoir si la souris est dessus
    nom:SetAlpha(0)

    s.fond = vie:CreateTexture(nil, "BACKGROUND")
    s.fond:SetAllPoints(vie)
    s.fond:SetVertexColor(0.1, 0.1, 0.1, 0.8)

    s.cadre = CreateFrame("Frame", nil, vie)
    s.cadre:SetPoint("TOPLEFT", vie, -1, 1)
    s.cadre:SetPoint("BOTTOMRIGHT", vie, 1, -1)
    s.cadre:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    s.cadre:SetBackdropBorderColor(0, 0, 0)

    s.nom = vie:CreateFontString(nil, "OVERLAY")
    s.nom:SetPoint("BOTTOM", vie, "TOP", 0, 2)
    s.quete = vie:CreateTexture(nil, "OVERLAY")
    s.quete:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")
    s.quete:SetPoint("RIGHT", s.nom, "LEFT", -1, 0)
    s.quete:Hide()
    s.texteVie = vie:CreateFontString(nil, "OVERLAY")
    s.texteVie:SetPoint("CENTER", vie, "CENTER", 0, 0)
    niveau:ClearAllPoints()
    niveau:SetPoint("LEFT", vie, "RIGHT", 3, 0)
    iconeBoss:ClearAllPoints()
    iconeBoss:SetPoint("LEFT", vie, "RIGHT", 2, 0)
    iconeRaid:ClearAllPoints()
    iconeRaid:SetPoint("RIGHT", vie, "LEFT", -4, 0)

    for i = 1, 12 do
        local ic = CreateFrame("Frame", nil, p)
        ic.tex = ic:CreateTexture(nil, "ARTWORK")
        ic.tex:SetAllPoints()
        ic.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        ic.bord = ic:CreateTexture(nil, "BACKGROUND")
        ic.bord:SetPoint("TOPLEFT", -1, 1)
        ic.bord:SetPoint("BOTTOMRIGHT", 1, -1)
        ic.bord:SetTexture(0, 0, 0)
        ic.temps = ic:CreateFontString(nil, "OVERLAY")
        ic.temps:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
        ic.temps:SetPoint("CENTER", 0, 0)
        ic.nb = ic:CreateFontString(nil, "OVERLAY")
        ic.nb:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
        ic.nb:SetPoint("BOTTOMRIGHT", 2, -1)
        ic:Hide()
        s.icones[i] = ic
    end

    p:HookScript("OnShow", function(self) self.sa.guid = nil Habiller(self) end)
    p:HookScript("OnHide", function(self) self.sa.guid = nil end)
    incant:HookScript("OnShow", function() PlacerIncantation(p) end)
    Habiller(p)
    PlacerIncantation(p)
end

local function EstPlaque(f)
    if f:GetName() then return false end
    local _, bord = f:GetRegions()
    return bord and bord:GetObjectType() == "Texture" and bord:GetTexture() == BORDURE
end

local nbEnfants = 0
local function ChercherPlaques()
    local n = WorldFrame:GetNumChildren()
    if n == nbEnfants then return end
    local enfants = { WorldFrame:GetChildren() }
    for i = nbEnfants + 1, n do
        local f = enfants[i]
        if f and not plaques[f] and EstPlaque(f) then Adopter(f) end
    end
    nbEnfants = n
end

------------------------------------------------------------------------
-- Mise à jour
------------------------------------------------------------------------
local tri = {}
local function TrierAuras(a, b)
    if a.mien ~= b.mien then return a.mien end
    return (a.fin > 0 and a.fin or 1e9) < (b.fin > 0 and b.fin or 1e9)
end

local function AfficherAuras(s, maintenant)
    local liste = s.guid and auras[s.guid]
    wipe(tri)
    if liste then
        for sort, a in pairs(liste) do
            if a.fin > 0 and a.fin < maintenant then
                liste[sort] = nil
            elseif a.mien or not db.mesSeuls then
                tri[#tri + 1] = a
            end
        end
        table.sort(tri, TrierAuras)
    end
    local nb = math.min(#tri, db.maxIcones)
    local largeurTotale = nb * (db.icone + 3) - 3
    for i, ic in ipairs(s.icones) do
        local a = i <= nb and tri[i]
        if a then
            ic:ClearAllPoints()
            ic:SetPoint("BOTTOMLEFT", s.vie, "TOP", -largeurTotale / 2 + (i - 1) * (db.icone + 3), db.police + 6)
            ic.tex:SetTexture(a.icone)
            if a.fin > 0 then
                local reste = a.fin - maintenant
                ic.temps:SetText(reste >= 60 and format("%dm", reste / 60) or format("%d", reste))
            else
                ic.temps:SetText("")
            end
            ic.nb:SetText(a.nb > 1 and a.nb or "")
            ic:Show()
        else
            ic:Hide()
        end
    end
end

local function MettreAJour(p, maintenant, cible, nomsVisibles)
    local s = p.sa
    if s.largeur ~= db.largeur or math.abs(s.vie:GetWidth() - db.largeur) > 0.5 then Habiller(p) end
    if s.incant:IsShown() and math.abs(s.incant:GetWidth() - db.largeur) > 0.5 then PlacerIncantation(p) end

    local nom = s.nomOrig:GetText()
    s.nom:SetText(nom)
    if db.quetes and nom and cibles[nom] then s.quete:Show() else s.quete:Hide() end
    -- Le jeu peut réafficher le nom d'origine quand il recycle une plaque : on le recache à chaque passage.
    s.nomOrig:SetAlpha(0)
    s.nomOrig:Hide()

    -- Qui est ce monstre ? Cible (seule plaque opaque), souris (surbrillance), sinon nom unique déjà vu.
    if cible and p:GetAlpha() > 0.99 and nom == UnitName("target") then
        s.guid = UnitGUID("target")
    elseif s.surbrillance:IsShown() and UnitExists("mouseover") and nom == UnitName("mouseover") then
        s.guid = UnitGUID("mouseover")
    elseif not s.guid and nomsVisibles[nom] == 1 then
        local trouve
        for guid, n in pairs(noms) do
            if n == nom then
                if trouve then trouve = nil break end
                trouve = guid
            end
        end
        s.guid = trouve
    end

    local min, max = s.vie:GetMinMaxValues()
    local v = s.vie:GetValue()
    local pct = max > 0 and v / max * 100 or 0
    local mode = db.texteVie
    if mode == 2 then s.texteVie:SetText(format("%d%%", pct))
    elseif mode == 3 then s.texteVie:SetText(CourtNombre(v))
    elseif mode == 4 then s.texteVie:SetText(format("%s - %d%%", CourtNombre(v), pct))
    else s.texteVie:SetText("") end

    if cible and p:GetAlpha() > 0.99 then s.cadre:SetBackdropBorderColor(1, 1, 1)
    else s.cadre:SetBackdropBorderColor(0, 0, 0) end

    AfficherAuras(s, maintenant)
end

local moteur = CreateFrame("Frame")
local attente = 0
local nomsVisibles = {}
moteur:SetScript("OnUpdate", function(_, ecoule)
    attente = attente - ecoule
    if attente > 0 or not db then return end
    attente = 0.1
    ChercherPlaques()
    wipe(nomsVisibles)
    for p in pairs(plaques) do
        if p:IsShown() then
            local n = p.sa.nomOrig:GetText()
            if n then nomsVisibles[n] = (nomsVisibles[n] or 0) + 1 end
        end
    end
    local maintenant, cible = GetTime(), UnitExists("target")
    for p in pairs(plaques) do
        if p:IsShown() then MettreAJour(p, maintenant, cible, nomsVisibles) end
    end
end)

------------------------------------------------------------------------
-- Fenêtre de réglages
------------------------------------------------------------------------
local fen = CreateFrame("Frame", "SolAzerothPlaquesCadre", UIParent)
fen:SetSize(320, 486)
fen:SetPoint("CENTER", 0, 60)
fen:SetFrameStrata("DIALOG")
fen:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
    edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 },
})
fen:EnableMouse(true)
fen:SetMovable(true)
fen:RegisterForDrag("LeftButton")
fen:SetScript("OnDragStart", fen.StartMoving)
fen:SetScript("OnDragStop", fen.StopMovingOrSizing)
fen:Hide()
tinsert(UISpecialFrames, "SolAzerothPlaquesCadre")

local titre = fen:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
titre:SetPoint("TOP", 0, -18)
titre:SetText("Plaques de nom")
local fermer = CreateFrame("Button", nil, fen, "UIPanelCloseButton")
fermer:SetPoint("TOPRIGHT", -6, -6)

local rafraichir = {}
local y = -50

local function Curseur(cle, texte, mini, maxi, pas)
    local nom = "SolAzerothPlaquesCurseur" .. cle
    local c = CreateFrame("Slider", nom, fen, "OptionsSliderTemplate")
    c:SetPoint("TOP", 0, y)
    c:SetWidth(240)
    c:SetMinMaxValues(mini, maxi)
    c:SetValueStep(pas)
    _G[nom .. "Low"]:SetText(mini)
    _G[nom .. "High"]:SetText(maxi)
    c:SetScript("OnValueChanged", function(self, v)
        v = math.floor(v / pas + 0.5) * pas
        db[cle] = v
        _G[nom .. "Text"]:SetText(texte .. " : " .. v)
        for p in pairs(plaques) do Habiller(p) PlacerIncantation(p) end
    end)
    rafraichir[#rafraichir + 1] = function() c:SetValue(db[cle]) end
    y = y - 42
end

local function Case(cle, texte)
    local nom = "SolAzerothPlaquesCase" .. cle
    local c = CreateFrame("CheckButton", nom, fen, "UICheckButtonTemplate")
    c:SetPoint("TOPLEFT", 36, y)
    _G[nom .. "Text"]:SetText(texte)
    c:SetScript("OnClick", function(self)
        db[cle] = self:GetChecked() and true or false
        for p in pairs(plaques) do Habiller(p) end
        if cle == "ennemisAuto" and db.ennemisAuto then SetCVar("nameplateShowEnemies", 1) end
    end)
    rafraichir[#rafraichir + 1] = function() c:SetChecked(db[cle]) end
    y = y - 26
end

local function Choix(cle, texte, liste, libelle)
    local b = CreateFrame("Button", nil, fen, "UIPanelButtonTemplate")
    b:SetPoint("TOP", 0, y)
    b:SetSize(240, 22)
    local function Texte() b:SetText(texte .. " : " .. libelle(liste[db[cle]])) end
    b:SetScript("OnClick", function()
        db[cle] = db[cle] % #liste + 1
        Texte()
        for p in pairs(plaques) do Habiller(p) end
    end)
    rafraichir[#rafraichir + 1] = Texte
    y = y - 28
end

Curseur("largeur", "Largeur", 60, 200, 5)
Curseur("hauteur", "Hauteur", 4, 24, 1)
Curseur("police", "Taille du texte", 6, 16, 1)
Curseur("icone", "Taille des affaiblissements", 12, 36, 1)
Curseur("maxIcones", "Affaiblissements au plus", 1, 12, 1)
Choix("texture", "Texture", TEXTURES, function(t) return t.nom end)
Choix("texteVie", "Texte de vie", TEXTES_VIE, function(t) return t end)
Case("mesSeuls", "Seulement mes affaiblissements")
Case("niveau", "Afficher le niveau")
Case("ennemisAuto", "Toujours afficher les plaques ennemies")
Case("quetes", "Marquer les monstres de quête")

local defaut = CreateFrame("Button", nil, fen, "UIPanelButtonTemplate")
defaut:SetPoint("TOP", 0, y - 12)  -- sous la dernière case, pour ne pas la chevaucher
defaut:SetSize(160, 22)
defaut:SetText("Réglages d'origine")
defaut:SetScript("OnClick", function()
    for k, v in pairs(DEFAUTS) do db[k] = v end
    for _, f in ipairs(rafraichir) do f() end
end)

fen:SetScript("OnShow", function() for _, f in ipairs(rafraichir) do f() end end)

SLASH_SOLAZEROTHPLAQUES1 = "/plaques"
SlashCmdList["SOLAZEROTHPLAQUES"] = function() if fen:IsShown() then fen:Hide() else fen:Show() end end

------------------------------------------------------------------------
-- Événements
------------------------------------------------------------------------
-- Demande de la liste des monstres de quête, regroupée : le journal change souvent plusieurs fois de suite.
local demande = CreateFrame("Frame")
demande:Hide()
demande:SetScript("OnUpdate", function(self, ecoule)
    self.reste = self.reste - ecoule
    if self.reste > 0 then return end
    self:Hide()
    SendChatMessage(".solcibles", "SAY")
end)
local function Demander(delai)
    demande.reste = math.max(demande:IsShown() and demande.reste or 0, delai)
    demande:Show()
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("QUEST_LOG_UPDATE")
ev:RegisterEvent("CHAT_MSG_ADDON")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_TARGET_CHANGED")
ev:RegisterEvent("PLAYER_FOCUS_CHANGED")
ev:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
ev:RegisterEvent("UNIT_AURA")
ev:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
ev:SetScript("OnEvent", function(_, evenement, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13)
    if evenement == "COMBAT_LOG_EVENT_UNFILTERED" then
        -- a1 horodatage, a2 sous-événement, a3-a5 source, a6-a8 cible, a9 sort, a12 type d'aura, a13 cumul
        JournalDeCombat(a2, a5, a6, a7, a8, a9, a12, a13)
    elseif evenement == "UNIT_AURA" then
        if a1 == "target" or a1 == "focus" or a1 == "mouseover" then Scanner(a1) end
    elseif evenement == "PLAYER_TARGET_CHANGED" then
        Scanner("target")
    elseif evenement == "PLAYER_FOCUS_CHANGED" then
        Scanner("focus")
    elseif evenement == "UPDATE_MOUSEOVER_UNIT" then
        Scanner("mouseover")
    elseif evenement == "ADDON_LOADED" and a1 == "SolAzerothPlaques" then
        SolAzerothPlaquesDB = SolAzerothPlaquesDB or {}
        db = SolAzerothPlaquesDB
        for k, v in pairs(DEFAUTS) do if db[k] == nil then db[k] = v end end
    elseif evenement == "QUEST_LOG_UPDATE" then
        Demander(0.5)
    elseif evenement == "CHAT_MSG_ADDON" then
        if a1 ~= "SolAzerothCibles" or a4 ~= UnitName("player") then return end
        if a2 == "DEBUT" then
            recues = {}
        elseif a2 == "FIN" then
            if recues then cibles, recues = recues, nil end
        elseif recues then
            for nom in a2:gmatch("[^;]+") do recues[nom] = true end
        end
    elseif evenement == "PLAYER_ENTERING_WORLD" then
        if db and db.ennemisAuto then SetCVar("nameplateShowEnemies", 1) end
        Demander(3)
    end
end)
