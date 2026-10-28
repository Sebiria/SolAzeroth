-- Tableau de contrats. Le serveur (mod-solazeroth, contrats.cpp) envoie
-- "ETAT;charges;max;secondes_avant_recharge;marques;cuivre", puis "THEME;nom;famille;métier;description;bonus_%",
-- puis les choix "CH;zone;famille;nom_zone;monstres;thème" et
-- "DJ;donjon;nom;rang_min;thème" et "PR;entrée;nom;classement;niveau;nom_zone;x:y,…;thème", puis les contrats en cours
-- "C;slot;type;cible;nom;détail;objectif;progression;cible_tuée;nom_cible;x:y,…;largeur;hauteur;thème" (zone en mètres), puis "FIN" ;
-- et "P;slot;progression;objectif;cible_tuée" quand un contrat avance.
-- Commande d'artisan : "AR;sort;objet;nombre;métier;thème" (choix) ; dans "C", cible = objet et détail = sort.
-- thème = 1 si le contrat colle au thème de la semaine : étoile devant le nom, en tête de liste, Marques en plus.
-- Commandes : ".solcontrat etat|chasse <zone> <famille>|donjon <id>|prime <entrée>|artisan <sort>|livrer N|abandonner N".
-- Les cibles de prime en cours sont aussi marquées sur la carte du monde et sur la minicarte.

local PREFIXE = "SOLCONTRAT"
local EMPLACEMENTS = 3
local LIGNES, HAUTEUR = 7, 38

local FAMILLES = { [1] = "Bêtes", [2] = "Draconiens", [3] = "Démons", [4] = "Élémentaires", [5] = "Géants",
                   [6] = "Morts-vivants", [7] = "Humanoïdes", [9] = "Mécaniques" }
local ICONES = { [1] = "Interface\\Icons\\Ability_Hunter_SniperShot", [2] = "Interface\\Icons\\INV_Misc_Key_10",
                 [3] = "Interface\\Icons\\Ability_Hunter_MarkedForDeath", [4] = "Interface\\Icons\\Trade_BlackSmithing" }
local CLASSEMENTS = { [1] = "Élite", [2] = "Élite rare", [4] = "Rare" }
local METIERS = { [171] = "Alchimie", [164] = "Forge", [333] = "Enchantement", [202] = "Ingénierie", [755] = "Joaillerie",
                  [165] = "Travail du cuir", [197] = "Couture", [773] = "Calligraphie", [185] = "Cuisine", [129] = "Secourisme" }

local etat = { charges = 0, max = 9, recharge = 0, recu = 0, marques = 0, cuivre = 0, contrats = {} }
local ETOILE = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:14|t "

local function Etoile(e) return e.theme and ETOILE or "" end
local choix = { chasse = {}, donjon = {}, prime = {}, artisan = {} }
local enCours = { chasse = {}, donjon = {}, prime = {}, artisan = {}, contrats = {} }

local function NomObjet(objet)
    return GetItemInfo(objet) or ("Objet " .. objet)
end

-- "45:62,50:70" -> { {45, 62}, {50, 70} }
local function LirePositions(texte)
    local positions = {}
    for x, y in string.gmatch(texte or "", "(%d+):(%d+)") do positions[#positions + 1] = { tonumber(x), tonumber(y) } end
    return positions
end

local function TextePositions(positions)
    local morceaux = {}
    for _, p in ipairs(positions) do morceaux[#morceaux + 1] = p[1] .. ", " .. p[2] end
    return table.concat(morceaux, " ou ")
end
local onglet = "chasse"

local function Commande(texte) SendChatMessage(texte, "SAY") end

local function Duree(s)
    return string.format("%d h %02d", math.floor(s / 3600), math.floor((s % 3600) / 60))
end

local function TexteRang(rang)
    return rang > 0 and string.format("rang de menace %d ou plus", rang) or "n'importe quel rang"
end

------------------------------------------------------------------------
-- Fenêtre
------------------------------------------------------------------------
local cadre = CreateFrame("Frame", "SolAzerothContratsCadre", UIParent)
cadre:SetSize(560, 440)
cadre:SetPoint("CENTER", 0, 60)
cadre:SetFrameStrata("DIALOG")
cadre:SetBackdrop({
    bgFile = "Interface\\AchievementFrame\\UI-Achievement-Parchment-Horizontal",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
    edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 },
})
cadre:EnableMouse(true)
cadre:SetMovable(true)
cadre:RegisterForDrag("LeftButton")
cadre:SetScript("OnDragStart", cadre.StartMoving)
cadre:SetScript("OnDragStop", cadre.StopMovingOrSizing)
cadre:Hide()
tinsert(UISpecialFrames, "SolAzerothContratsCadre")

local entete = cadre:CreateTexture(nil, "ARTWORK")
entete:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
entete:SetSize(300, 64)
entete:SetPoint("TOP", 0, 12)
local titre = cadre:CreateFontString(nil, "OVERLAY", "GameFontNormal")
titre:SetPoint("TOP", entete, "TOP", 0, -14)
titre:SetText("Contrats")

local fermer = CreateFrame("Button", nil, cadre, "UIPanelCloseButton")
fermer:SetPoint("TOPRIGHT", -6, -6)

local reserve = cadre:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
reserve:SetPoint("TOPLEFT", 26, -36)
local recompense = cadre:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
recompense:SetPoint("TOPLEFT", 26, -54)
recompense:SetWidth(500)
recompense:SetJustifyH("LEFT")

local themeTexte = cadre:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
themeTexte:SetPoint("TOPLEFT", 26, -84 - LIGNES * HAUTEUR - 6)
themeTexte:SetWidth(500)
themeTexte:SetJustifyH("LEFT")

local vide = cadre:CreateFontString(nil, "OVERLAY", "GameFontDisable")
vide:SetPoint("TOP", 0, -140)
vide:SetWidth(400)

-- Liste des choix (onglets Chasse et Donjon)
local liste = CreateFrame("ScrollFrame", "SolAzerothContratsListe", cadre, "FauxScrollFrameTemplate")
liste:SetPoint("TOPLEFT", 24, -84)
liste:SetSize(490, LIGNES * HAUTEUR)
local lignes = {}
local affiches = {}

for i = 1, LIGNES do
    local l = CreateFrame("Frame", nil, cadre)
    l:SetSize(490, HAUTEUR - 2)
    l:SetPoint("TOPLEFT", 24, -84 - (i - 1) * HAUTEUR)
    l.icone = l:CreateTexture(nil, "ARTWORK")
    l.icone:SetSize(26, 26)
    l.icone:SetPoint("LEFT", 2, 0)
    l.nom = l:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    l.nom:SetPoint("TOPLEFT", l.icone, "TOPRIGHT", 8, 0)
    l.nom:SetWidth(360)
    l.nom:SetJustifyH("LEFT")
    l.info = l:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    l.info:SetPoint("TOPLEFT", l.nom, "BOTTOMLEFT", 0, -2)
    l.info:SetWidth(360)
    l.info:SetJustifyH("LEFT")
    l.bouton = CreateFrame("Button", nil, l, "UIPanelButtonTemplate")
    l.bouton:SetSize(80, 22)
    l.bouton:SetPoint("RIGHT", -4, 0)
    l.bouton:SetText("Accepter")
    lignes[i] = l
end

-- Contrats en cours (onglet En cours)
local cartes = {}
for i = 1, EMPLACEMENTS do
    local c = CreateFrame("Frame", nil, cadre)
    c:SetSize(420, 78)
    c:SetPoint("TOP", 0, -78 - (i - 1) * 84)
    c:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                    edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    c:SetBackdropBorderColor(0.3, 1, 0.3)
    c.icone = c:CreateTexture(nil, "ARTWORK")
    c.icone:SetSize(36, 36)
    c.icone:SetPoint("TOPLEFT", 10, -10)
    c.titre = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    c.titre:SetPoint("TOPLEFT", c.icone, "TOPRIGHT", 10, 0)
    c.titre:SetWidth(250)
    c.titre:SetJustifyH("LEFT")
    c.objectif = c:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    c.objectif:SetPoint("TOPLEFT", c.titre, "BOTTOMLEFT", 0, -4)
    c.objectif:SetWidth(250)
    c.objectif:SetJustifyH("LEFT")
    c.etat = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    c.etat:SetPoint("TOPRIGHT", -12, -14)
    c.bouton = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
    c.bouton:SetSize(100, 22)
    c.bouton:SetPoint("BOTTOMRIGHT", -10, 10)
    c.bouton:SetText("Abandonner")
    c.bouton:SetScript("OnClick", function() Commande(".solcontrat abandonner " .. i) end)
    c.livrer = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
    c.livrer:SetSize(80, 22)
    c.livrer:SetPoint("RIGHT", c.bouton, "LEFT", -6, 0)
    c.livrer:SetText("Livrer")
    c.livrer:SetScript("OnClick", function() Commande(".solcontrat livrer " .. i) end)
    cartes[i] = c
end

local function NombreEnCours()
    local n = 0
    for i = 1, EMPLACEMENTS do if etat.contrats[i] then n = n + 1 end end
    return n
end

local function RafraichirListe()
    local offset = FauxScrollFrame_GetOffset(liste)
    local plein = NombreEnCours() >= EMPLACEMENTS or etat.charges == 0
    for i = 1, LIGNES do
        local l, e = lignes[i], affiches[i + offset]
        if e then
            if onglet == "chasse" then
                l.icone:SetTexture(ICONES[1])
                l.nom:SetText(Etoile(e) .. (FAMILLES[e.famille] or "Monstres") .. " : " .. e.nom)
                l.info:SetText(string.format("Tuer 15 à 25 %s (%d dans la zone à ton niveau)", strlower(FAMILLES[e.famille] or "monstres"), e.nombre))
                l.bouton:SetScript("OnClick", function() Commande(".solcontrat chasse " .. e.zone .. " " .. e.famille) end)
            elseif onglet == "donjon" then
                l.icone:SetTexture(ICONES[2])
                l.nom:SetText(Etoile(e) .. e.nom)
                l.info:SetText("Finir le donjon au " .. TexteRang(e.rang))
                l.bouton:SetScript("OnClick", function() Commande(".solcontrat donjon " .. e.id) end)
            elseif onglet == "prime" then
                l.icone:SetTexture(ICONES[3])
                l.nom:SetText(Etoile(e) .. e.nom .. "  |cffa0a0a0" .. (CLASSEMENTS[e.classement] or "") .. ", niveau " .. e.niveau .. "|r")
                l.info:SetText(e.zone .. " - position " .. TextePositions(e.positions))
                l.bouton:SetScript("OnClick", function() Commande(".solcontrat prime " .. e.id) end)
            else
                l.icone:SetTexture(GetItemIcon(e.objet) or ICONES[4])
                l.nom:SetText(Etoile(e) .. NomObjet(e.objet))
                l.info:SetText(string.format("%s - fabriquer et livrer %d", METIERS[e.metier] or "Métier", e.nombre))
                l.bouton:SetScript("OnClick", function() Commande(".solcontrat artisan " .. e.sort) end)
            end
            if plein then l.bouton:Disable() else l.bouton:Enable() end
            l:Show()
        else
            l:Hide()
        end
    end
    FauxScrollFrame_Update(liste, #affiches, LIGNES, HAUTEUR)
end

liste:SetScript("OnVerticalScroll", function(self, valeur)
    FauxScrollFrame_OnVerticalScroll(self, valeur, HAUTEUR, RafraichirListe)
end)

local function Rafraichir()
    local reste = math.max(0, etat.recharge - (GetTime() - etat.recu))
    reserve:SetText(string.format("Réserve du compte : |cffffd100%d / %d|r   (+%d dans %s)   En cours : %d / %d",
        etat.charges, etat.max, etat.parJour or 3, Duree(reste), NombreEnCours(), EMPLACEMENTS))
    recompense:SetText(string.format("Récompense : %d Marques, %s, 25 %% de chance d'un objet de donjon au rang 3",
        etat.marques, GetCoinTextureString(etat.cuivre)))
    local t = etat.theme
    if t then
        themeTexte:SetText(string.format("%sThème de la semaine : |cffffd100%s|r (%s, %s) : +%d %% de Marques.\n|cffa0a0a0%s|r",
            ETOILE, t.nom, strlower(FAMILLES[t.famille] or "monstres"), strlower(METIERS[t.metier] or "métier"), t.bonus, t.description))
    else
        themeTexte:SetText("")
    end

    vide:SetText("")
    if onglet == "encours" then
        liste:Hide()
        for _, l in ipairs(lignes) do l:Hide() end
        for i = 1, EMPLACEMENTS do
            local c, k = cartes[i], etat.contrats[i]
            if k then
                c.icone:SetTexture(ICONES[k.type] or "Interface\\Icons\\INV_Misc_QuestionMark")
                c.livrer:Hide()
                if k.type == 4 then
                    local enSac = GetItemCount(k.cible)
                    c.icone:SetTexture(GetItemIcon(k.cible) or ICONES[4])
                    c.titre:SetText(Etoile(k) .. "Commande : " .. NomObjet(k.cible))
                    c.objectif:SetText(string.format("Fabriquer et livrer %d %s", k.objectif, NomObjet(k.cible)))
                    c.etat:SetText(string.format("%s%d / %d en sac|r", enSac >= k.objectif and "|cff60ff60" or "|cffffffff", math.min(enSac, k.objectif), k.objectif))
                    c.livrer:Show()
                    if enSac >= k.objectif then c.livrer:Enable() else c.livrer:Disable() end
                elseif k.type == 1 then
                    c.titre:SetText(Etoile(k) .. "Chasse : " .. (FAMILLES[k.detail] or "monstres"))
                    c.objectif:SetText(string.format("Tuer %d %s dans |cffffffff%s|r", k.objectif, strlower(FAMILLES[k.detail] or "monstres"), k.nom))
                    c.etat:SetText(string.format("|cff60ff60%d / %d|r", k.progression, k.objectif))
                elseif k.type == 3 then
                    c.titre:SetText(Etoile(k) .. "Prime : " .. k.nomCible)
                    c.objectif:SetText(string.format("Abattre %s (%s) et tuer %d monstres de |cffffffff%s|r",
                        k.nomCible, TextePositions(k.positions), k.objectif, k.nom))
                    c.etat:SetText(string.format("%s  |cff60ff60%d / %d|r", k.cibleTuee and "|cff60ff60Cible abattue|r" or "|cffff8040Cible en vie|r",
                        k.progression, k.objectif))
                else
                    c.titre:SetText(Etoile(k) .. "Donjon : " .. k.nom)
                    c.objectif:SetText("Finir le donjon au " .. TexteRang(k.detail))
                    c.etat:SetText("|cff60ff60En cours|r")
                end
                c:Show()
            else
                c:Hide()
            end
        end
        if NombreEnCours() == 0 then vide:SetText("Aucun contrat en cours. Choisis-en un dans les onglets Chasse ou Donjon.") end
    else
        for _, c in ipairs(cartes) do c:Hide() end
        affiches = choix[onglet]
        liste:Show()
        RafraichirListe()
        if #affiches == 0 then
            vide:SetText(onglet == "chasse" and "Aucune chasse à ton niveau." or onglet == "donjon" and "Aucun donjon à ton niveau."
                         or onglet == "prime" and "Aucune prime à ton niveau."
                         or string.format("Aucune commande à ton niveau : il faut une recette de maître de métier demandant au moins %d de compétence, et pas encore grise. Monte un métier.", math.max(0, (UnitLevel("player") - 5) * 5)))
        elseif etat.charges == 0 then
            vide:SetText("")
        end
    end
end

-- Onglets
local ONGLETS = { { cle = "chasse", nom = "Chasse" }, { cle = "donjon", nom = "Donjon" }, { cle = "prime", nom = "Prime" },
                  { cle = "artisan", nom = "Artisan" }, { cle = "encours", nom = "En cours" } }
local boutonsOnglet = {}
for i, o in ipairs(ONGLETS) do
    local b = CreateFrame("Button", nil, cadre, "UIPanelButtonTemplate")
    b:SetSize(84, 24)
    b:SetPoint("BOTTOMLEFT", 24 + (i - 1) * 86, 18)
    b:SetText(o.nom)
    b:SetScript("OnClick", function()
        onglet = o.cle
        for _, autre in ipairs(boutonsOnglet) do autre:UnlockHighlight() end
        b:LockHighlight()
        FauxScrollFrame_SetOffset(liste, 0)
        liste:SetVerticalScroll(0)
        Rafraichir()
    end)
    boutonsOnglet[i] = b
end
boutonsOnglet[1]:LockHighlight()

cadre:SetScript("OnUpdate", function(self, ecoule)
    self.minuterie = (self.minuterie or 0) + ecoule
    if self.minuterie >= 30 then self.minuterie = 0 Rafraichir() end
end)

------------------------------------------------------------------------
-- Suivi : petit cadre déplaçable, visible tant qu'un contrat est en cours (comme le suivi des quêtes)
------------------------------------------------------------------------
local suivi = CreateFrame("Frame", "SolAzerothContratsSuivi", UIParent)
suivi:SetSize(230, 20)
suivi:SetPoint("TOPRIGHT", -80, -230)
suivi:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                    edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
suivi:SetBackdropColor(0, 0, 0, 0.6)
suivi:SetBackdropBorderColor(1, 0.82, 0, 0.8)
suivi:EnableMouse(true)
suivi:SetMovable(true)
suivi:RegisterForDrag("LeftButton")
suivi:SetScript("OnDragStart", suivi.StartMoving)
suivi:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relatif, x, y = self:GetPoint()
    SolAzerothContratsDB.suivi = { point, relatif, x, y }
end)
suivi:SetScript("OnMouseUp", function(self, clic)
    if clic == "RightButton" then
        onglet = "encours"
        for i, b in ipairs(boutonsOnglet) do if i == #ONGLETS then b:LockHighlight() else b:UnlockHighlight() end end
        cadre:Show()
        Rafraichir()
    end
end)
suivi:Hide()

local suiviTitre = suivi:CreateFontString(nil, "OVERLAY", "GameFontNormal")
suiviTitre:SetPoint("TOPLEFT", 8, -6)
suiviTitre:SetText("Contrats")

local suiviLignes = {}
for i = 1, EMPLACEMENTS do
    local l = suivi:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    l:SetWidth(214)
    l:SetJustifyH("LEFT")
    suiviLignes[i] = l
end

local function RafraichirSuivi()
    local y, montres = -22, 0
    for i = 1, EMPLACEMENTS do
        local l, k = suiviLignes[i], etat.contrats[i]
        if k then
            if k.type == 1 then
                local fini = k.progression >= k.objectif
                l:SetText(string.format("%s|cffffd100%s|r (%s)\n  %s%d / %d|r", Etoile(k), FAMILLES[k.detail] or "Monstres", k.nom,
                    fini and "|cff60ff60" or "|cffffffff", k.progression, k.objectif))
            elseif k.type == 4 then
                local enSac = GetItemCount(k.cible)
                l:SetText(string.format("%s|cffffd100Commande : %s|r\n  %s%d / %d fabriqués dans les sacs|r%s", Etoile(k), NomObjet(k.cible),
                    enSac >= k.objectif and "|cff60ff60" or "|cffffffff", math.min(enSac, k.objectif), k.objectif,
                    enSac >= k.objectif and "  - à livrer" or ""))
            elseif k.type == 3 then
                local fini = k.progression >= k.objectif
                l:SetText(string.format("%s|cffffd100Prime : %s|r (%s)\n  %s  -  %smonstres %d / %d|r", Etoile(k), k.nomCible, k.nom,
                    k.cibleTuee and "|cff60ff60cible abattue|r" or ("|cffff8040cible en " .. TextePositions(k.positions) .. "|r"),
                    fini and "|cff60ff60" or "|cffffffff", k.progression, k.objectif))
            else
                l:SetText(string.format("%s|cffffd100Donjon : %s|r\n  au %s", Etoile(k), k.nom, TexteRang(k.detail)))
            end
            l:ClearAllPoints()
            l:SetPoint("TOPLEFT", 8, y)
            l:Show()
            y = y - l:GetHeight() - 6
            montres = montres + 1
        else
            l:Hide()
        end
    end
    if montres > 0 then
        suivi:SetHeight(-y + 4)
        suivi:Show()
    else
        suivi:Hide()
    end
end

------------------------------------------------------------------------
-- Carte du monde : un crâne sur chaque position des cibles de prime en cours, quand la carte affiche leur zone
------------------------------------------------------------------------
local marqueurs = {}

local function ZoneAffichee()
    local zones = { GetMapZones(GetCurrentMapContinent()) }
    return zones[GetCurrentMapZone()]
end

local function RafraichirCarte()
    for _, m in ipairs(marqueurs) do m:Hide() end
    if not WorldMapFrame:IsShown() then return end
    local zone, n = ZoneAffichee(), 0
    local largeur, hauteur = WorldMapDetailFrame:GetWidth(), WorldMapDetailFrame:GetHeight()
    for i = 1, EMPLACEMENTS do
        local k = etat.contrats[i]
        if k and k.type == 3 and not k.cibleTuee and k.nom == zone then
            for _, p in ipairs(k.positions) do
                n = n + 1
                local m = marqueurs[n]
                if not m then
                    m = CreateFrame("Frame", nil, WorldMapButton)
                    m:SetSize(20, 20)
                    m:SetFrameLevel(WorldMapButton:GetFrameLevel() + 5)
                    m.texture = m:CreateTexture(nil, "OVERLAY")
                    m.texture:SetAllPoints()
                    m.texture:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_8")
                    m:EnableMouse(true)
                    m:SetScript("OnEnter", function(self)
                        WorldMapTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        WorldMapTooltip:SetText("Prime : " .. self.nom, 1, 0.82, 0)
                        WorldMapTooltip:Show()
                    end)
                    m:SetScript("OnLeave", function() WorldMapTooltip:Hide() end)
                    marqueurs[n] = m
                end
                m.nom = k.nomCible
                m:ClearAllPoints()
                m:SetPoint("CENTER", WorldMapDetailFrame, "TOPLEFT", largeur * p[1] / 100, -hauteur * p[2] / 100)
                m:Show()
            end
        end
    end
end

local carte = CreateFrame("Frame")
carte:RegisterEvent("WORLD_MAP_UPDATE")
carte:SetScript("OnEvent", RafraichirCarte)
WorldMapFrame:HookScript("OnShow", RafraichirCarte)

------------------------------------------------------------------------
-- Minicarte : le même crâne, placé d'après la position du joueur sur la carte de sa zone et la taille de la zone
-- en mètres (envoyée par le serveur). Hors de portée, le crâne reste au bord, à demi transparent, dans la bonne direction.
------------------------------------------------------------------------
local DIAMETRES_EXTERIEUR = { [0] = 466 + 2 / 3, 400, 333 + 1 / 3, 266 + 2 / 3, 200, 133 + 1 / 3 }   -- mètres visibles selon le zoom
local DIAMETRES_INTERIEUR = { [0] = 300, 240, 180, 120, 80, 50 }
local miniMarqueurs = {}

local function MiniMarqueur(n)
    local m = miniMarqueurs[n]
    if not m then
        m = CreateFrame("Frame", nil, Minimap)
        m:SetSize(14, 14)
        m:SetFrameLevel(Minimap:GetFrameLevel() + 5)
        m.texture = m:CreateTexture(nil, "OVERLAY")
        m.texture:SetAllPoints()
        m.texture:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_8")
        m:EnableMouse(true)
        m:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Prime : " .. self.nom, 1, 0.82, 0)
            GameTooltip:Show()
        end)
        m:SetScript("OnLeave", function() GameTooltip:Hide() end)
        miniMarqueurs[n] = m
    end
    return m
end

local miniAttente = 0
local mini = CreateFrame("Frame")
mini:SetScript("OnUpdate", function(self, ecoule)
    miniAttente = miniAttente + ecoule
    if miniAttente < 0.1 then return end
    miniAttente = 0
    -- Carte du monde ouverte : la position du joueur suivrait la carte affichée, on garde les crânes tels quels.
    if WorldMapFrame:IsShown() then return end
    for _, m in ipairs(miniMarqueurs) do m:Hide() end
    local zone, n, px, py = GetRealZoneText(), 0, nil, nil
    for i = 1, EMPLACEMENTS do
        local k = etat.contrats[i]
        if k and k.type == 3 and not k.cibleTuee and k.nom == zone and k.largeur > 0 and k.hauteur > 0 then
            if not px then
                SetMapToCurrentZone()
                px, py = GetPlayerMapPosition("player")
                if px == 0 and py == 0 then return end
            end
            local diametres = IsIndoors() and DIAMETRES_INTERIEUR or DIAMETRES_EXTERIEUR
            local parMetre = Minimap:GetWidth() / (diametres[Minimap:GetZoom()] or 400)
            local rayon = Minimap:GetWidth() / 2 - 6
            local angle = GetCVar("rotateMinimap") == "1" and GetPlayerFacing() or 0
            for _, p in ipairs(k.positions) do
                local dx = (p[1] / 100 - px) * k.largeur * parMetre   -- vers l'est
                local dy = (p[2] / 100 - py) * k.hauteur * parMetre   -- vers le sud
                if angle ~= 0 then
                    local c, s = math.cos(angle), math.sin(angle)
                    dx, dy = dx * c - dy * s, dx * s + dy * c
                end
                local distance = math.sqrt(dx * dx + dy * dy)
                local auBord = distance > rayon
                if auBord then dx, dy = dx * rayon / distance, dy * rayon / distance end
                n = n + 1
                local m = MiniMarqueur(n)
                m.nom = k.nomCible
                m:ClearAllPoints()
                m:SetPoint("CENTER", Minimap, "CENTER", dx, -dy)
                m:SetAlpha(auBord and 0.5 or 1)
                m:Show()
            end
        end
    end
end)

-- Commandes d'artisan : le compte « en sac » suit les sacs ; les objets inconnus du client sont demandés au serveur
-- par une infobulle cachée, puis la fenêtre est redessinée.
local cache = CreateFrame("GameTooltip", "SolAzerothContratsCache", UIParent, "GameTooltipTemplate")
local sacs = CreateFrame("Frame")
sacs:RegisterEvent("BAG_UPDATE")
sacs:SetScript("OnEvent", function()
    if cadre:IsShown() then Rafraichir() end
    RafraichirSuivi()
end)
sacs:SetScript("OnUpdate", function(self, ecoule)
    self.attente = (self.attente or 0) + ecoule
    if self.attente < 1 then return end
    self.attente = 0
    local manque = false
    local function Verifier(objet)
        if objet and not GetItemInfo(objet) then
            manque = true
            cache:SetOwner(UIParent, "ANCHOR_NONE")
            cache:SetHyperlink("item:" .. objet .. ":0:0:0:0:0:0:0")
        end
    end
    for _, e in ipairs(choix.artisan) do Verifier(e.objet) end
    for i = 1, EMPLACEMENTS do
        local k = etat.contrats[i]
        if k and k.type == 4 then Verifier(k.cible) end
    end
    if manque then
        if cadre:IsShown() then Rafraichir() end
        RafraichirSuivi()
    end
end)

------------------------------------------------------------------------
-- Échanges avec le serveur
------------------------------------------------------------------------
local evenements = CreateFrame("Frame")
evenements:RegisterEvent("CHAT_MSG_ADDON")
evenements:SetScript("OnEvent", function(self, event, prefixe, message)
    if prefixe ~= PREFIXE then return end
    local champs = { strsplit(";", message) }
    local type = champs[1]
    if type == "ETAT" then
        etat.charges = tonumber(champs[2]) or 0
        etat.max = tonumber(champs[3]) or 9
        etat.recharge = tonumber(champs[4]) or 0
        etat.marques = tonumber(champs[5]) or 0
        etat.cuivre = tonumber(champs[6]) or 0
        etat.parJour = tonumber(champs[7]) or 3
        etat.recu = GetTime()
        etat.theme = nil
        enCours = { chasse = {}, donjon = {}, prime = {}, artisan = {}, contrats = {} }
    elseif type == "THEME" then
        etat.theme = { nom = champs[2] or "?", famille = tonumber(champs[3]) or 0, metier = tonumber(champs[4]) or 0,
                       description = champs[5] or "", bonus = tonumber(champs[6]) or 0 }
    elseif type == "AR" then
        table.insert(enCours.artisan, { sort = tonumber(champs[2]), objet = tonumber(champs[3]), nombre = tonumber(champs[4]) or 1,
                                        metier = tonumber(champs[5]) or 0, theme = champs[6] == "1" })
    elseif type == "PR" then
        table.insert(enCours.prime, { id = tonumber(champs[2]), nom = champs[3] or "?", classement = tonumber(champs[4]) or 0,
                                      niveau = tonumber(champs[5]) or 0, zone = champs[6] or "?", positions = LirePositions(champs[7]),
                                      theme = champs[8] == "1" })
    elseif type == "CH" then
        table.insert(enCours.chasse, { zone = tonumber(champs[2]), famille = tonumber(champs[3]), nom = champs[4] or "?",
                                       nombre = tonumber(champs[5]) or 0, theme = champs[6] == "1" })
    elseif type == "DJ" then
        table.insert(enCours.donjon, { id = tonumber(champs[2]), nom = champs[3] or "?", rang = tonumber(champs[4]) or 0,
                                       theme = champs[5] == "1" })
    elseif type == "C" then
        local i = tonumber(champs[2])
        if i then
            enCours.contrats[i] = { type = tonumber(champs[3]) or 0, cible = tonumber(champs[4]), nom = champs[5] or "?",
                                    detail = tonumber(champs[6]) or 0, objectif = tonumber(champs[7]) or 0,
                                    progression = tonumber(champs[8]) or 0, cibleTuee = champs[9] == "1",
                                    nomCible = champs[10] or "", positions = LirePositions(champs[11]),
                                    largeur = tonumber(champs[12]) or 0, hauteur = tonumber(champs[13]) or 0,
                                    theme = champs[14] == "1" }
        end
    elseif type == "P" then
        local k = etat.contrats[tonumber(champs[2]) or 0]
        if k then
            k.progression = tonumber(champs[3]) or k.progression
            k.cibleTuee = champs[5] == "1"
        end
        if cadre:IsShown() then Rafraichir() end
        RafraichirSuivi()
    elseif type == "FIN" then
        table.sort(enCours.chasse, function(a, b)
            if a.theme ~= b.theme then return a.theme end
            if a.nom ~= b.nom then return a.nom < b.nom end
            return a.famille < b.famille
        end)
        table.sort(enCours.donjon, function(a, b)
            if a.theme ~= b.theme then return a.theme end
            return a.nom < b.nom
        end)
        table.sort(enCours.prime, function(a, b)
            if a.theme ~= b.theme then return a.theme end
            if a.zone ~= b.zone then return a.zone < b.zone end
            return a.nom < b.nom
        end)
        table.sort(enCours.artisan, function(a, b)
            if a.theme ~= b.theme then return a.theme end
            if a.metier ~= b.metier then return (METIERS[a.metier] or "") < (METIERS[b.metier] or "") end
            return NomObjet(a.objet) < NomObjet(b.objet)
        end)
        choix.chasse, choix.donjon, choix.prime, choix.artisan, etat.contrats =
            enCours.chasse, enCours.donjon, enCours.prime, enCours.artisan, enCours.contrats
        if cadre:IsShown() then Rafraichir() end
        RafraichirSuivi()
    end
end)

local function Basculer()
    if cadre:IsShown() then
        cadre:Hide()
    else
        cadre:Show()
        Rafraichir()
        Commande(".solcontrat etat")
    end
end

SLASH_SOLAZEROTHCONTRATS1 = "/contrats"
SlashCmdList["SOLAZEROTHCONTRATS"] = Basculer

-- À l'arrivée en jeu, on demande l'état pour afficher le suivi sans ouvrir la fenêtre.
local demarrage = CreateFrame("Frame")
demarrage:RegisterEvent("PLAYER_ENTERING_WORLD")
demarrage:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    local attente = 0
    self:SetScript("OnUpdate", function(f, ecoule)
        attente = attente + ecoule
        if attente >= 2 then
            f:SetScript("OnUpdate", nil)
            Commande(".solcontrat etat")
        end
    end)
end)

------------------------------------------------------------------------
-- Bouton de la minicarte, déplaçable autour du bord (position mémorisée)
------------------------------------------------------------------------
local RAYON = 80

local bouton = CreateFrame("Button", "SolAzerothContratsBoutonMinicarte", Minimap)
bouton:SetSize(31, 31)
bouton:SetFrameStrata("MEDIUM")
bouton:SetFrameLevel(8)
bouton:RegisterForClicks("LeftButtonUp")
bouton:RegisterForDrag("LeftButton")
bouton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
local iconeBouton = bouton:CreateTexture(nil, "BACKGROUND")
iconeBouton:SetSize(20, 20)
iconeBouton:SetPoint("TOPLEFT", 7, -5)
iconeBouton:SetTexture("Interface\\Icons\\INV_Scroll_03")
iconeBouton:SetTexCoord(0.08, 0.92, 0.08, 0.92)
local bordure = bouton:CreateTexture(nil, "OVERLAY")
bordure:SetSize(53, 53)
bordure:SetPoint("TOPLEFT")
bordure:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

local function Placer(angle)
    bouton:ClearAllPoints()
    bouton:SetPoint("CENTER", Minimap, "CENTER", RAYON * cos(angle), RAYON * sin(angle))
end

local function SuivreCurseur()
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local echelle = Minimap:GetEffectiveScale()
    local angle = math.deg(math.atan2(cy / echelle - my, cx / echelle - mx))
    SolAzerothContratsDB.angle = angle
    Placer(angle)
end

bouton:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", SuivreCurseur) end)
bouton:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
bouton:SetScript("OnClick", Basculer)
bouton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Contrats", 1, 0.82, 0)
    GameTooltip:AddLine("Clic : ouvrir ou fermer", 1, 1, 1)
    GameTooltip:AddLine("Glisser : déplacer le bouton", 1, 1, 1)
    GameTooltip:Show()
end)
bouton:SetScript("OnLeave", function() GameTooltip:Hide() end)

local chargement = CreateFrame("Frame")
chargement:RegisterEvent("ADDON_LOADED")
chargement:SetScript("OnEvent", function(self, event, nom)
    if nom ~= "SolAzerothContrats" then return end
    self:UnregisterEvent("ADDON_LOADED")
    SolAzerothContratsDB = SolAzerothContratsDB or { angle = 240 }
    Placer(SolAzerothContratsDB.angle)
    local p = SolAzerothContratsDB.suivi
    if p then
        suivi:ClearAllPoints()
        suivi:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    end
end)
