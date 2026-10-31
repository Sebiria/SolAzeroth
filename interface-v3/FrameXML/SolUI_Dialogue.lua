-- Sol'Azeroth v3, F5d (31/10/2026) : dialogue avec les PNJ, à la place des fenêtres de Blizzard (GossipFrame et
-- QuestFrame, demande de l'utilisateur). Une seule fenêtre, qui change de page :
-- - discussion : texte du PNJ, quêtes à rendre, quêtes proposées, options (marchand, maître de vol…) ;
-- - accueil : la liste des quêtes d'un PNJ qui n'a que des quêtes ;
-- - quête proposée : récit, objectifs, récompenses, Accepter ou Refuser ;
-- - quête en cours : ce qu'il reste à apporter, Continuer quand elle est terminée ;
-- - récompense : texte de fin, choix de l'objet s'il y en a un, Terminer.
-- Les fenêtres de Blizzard restent chargées mais ne reçoivent plus leurs événements.

local S = SolUI

local LARGEUR, LARGEUR_PAGE = 520, 456

local d = CreateFrame("Frame", "SolUIDialogue", S.racine)
d:SetSize(LARGEUR, 600)
d:SetPoint("LEFT", S.racine, "LEFT", 70, 30)
d:SetFrameStrata("HIGH")
d:SetToplevel(true)
d:EnableMouse(true)
d:SetMovable(true)
d:SetClampedToScreen(true)
S.Panneau(d, 0.96)
d:Hide()
tinsert(UISpecialFrames, "SolUIDialogue")

local barre = CreateFrame("Frame", nil, d)
barre:SetPoint("TOPLEFT")
barre:SetPoint("TOPRIGHT")
barre:SetHeight(48)
barre:EnableMouse(true)
barre:RegisterForDrag("LeftButton")
barre:SetScript("OnDragStart", function() d:StartMoving() end)
barre:SetScript("OnDragStop", function() d:StopMovingOrSizing(); d:SetUserPlaced(false) end)

local pnj = S.Texte(barre, "Bold", 16, "clair")
pnj:SetPoint("LEFT", 20, -2)
pnj:SetPoint("RIGHT", -40, 0)
pnj:SetJustifyH("LEFT")
local fermer = CreateFrame("Button", nil, barre, "UIPanelCloseButton")
fermer:SetPoint("RIGHT", -6, 0)
fermer:SetScript("OnClick", function() d:Hide() end)
local filet = S.Texture(d, "ARTWORK", nil, S.Couleur("bord"))
filet:SetPoint("TOPLEFT", 1, -48)
filet:SetPoint("TOPRIGHT", -1, -48)
filet:SetHeight(1)

local defile = CreateFrame("ScrollFrame", "SolUIDialogueDefile", d)
defile:SetPoint("TOPLEFT", 32, -68)
defile:SetPoint("BOTTOMRIGHT", -32, 64)
defile:EnableMouseWheel(true)
local page = CreateFrame("Frame", nil, defile)
page:SetSize(LARGEUR_PAGE, 10)
defile:SetScrollChild(page)
defile:SetScript("OnMouseWheel", function(self, sens)
    local maxi = math.max(0, page:GetHeight() - self:GetHeight())
    self:SetVerticalScroll(math.max(0, math.min(maxi, self:GetVerticalScroll() - sens * 40)))
end)

------------------------------------------------------------------------
-- Éléments de page, réutilisés d'une page à l'autre
------------------------------------------------------------------------
local textes, lignes, objets, utilises = {}, {}, {}, {}
local y = 0

local function Vider()
    for _, liste in ipairs({ textes, lignes, objets }) do
        for _, element in ipairs(liste) do element:Hide() end
    end
    utilises = { textes = 0, lignes = 0, objets = 0 }
    y = 0
    defile:SetVerticalScroll(0)
end

local STYLES = {
    titre = { "Bold", 20, "clair" }, texte = { "Regular", 13, "texte" }, rubrique = { "SemiBold", 11, "ambreClair" },
    discret = { "Regular", 13, "gris" }, alerte = { "SemiBold", 12, "rougeClair" },
}

local function Texte(contenu, style, ecart)
    utilises.textes = utilises.textes + 1
    local t = textes[utilises.textes]
    if not t then
        t = S.Texte(page, "Regular", 13, "texte")
        t:SetWidth(LARGEUR_PAGE)
        t:SetJustifyH("LEFT")
        t:SetJustifyV("TOP")
        t:SetSpacing(3)
        textes[utilises.textes] = t
    end
    local s = STYLES[style or "texte"]
    S.Police(t, s[1], s[2])
    t:SetTextColor(S.Couleur(s[3]))
    t:SetText(contenu or "")
    y = y - (ecart or 0)
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", page, "TOPLEFT", 0, y)
    t:Show()
    y = y - t:GetHeight()
    return t
end

-- Ligne cliquable (quête ou option de discussion).
local function Ligne(contenu, couleur, fonction)
    utilises.lignes = utilises.lignes + 1
    local l = lignes[utilises.lignes]
    if not l then
        l = CreateFrame("Button", nil, page)
        l:SetSize(LARGEUR_PAGE, 28)
        l.fond = S.Texture(l, "BACKGROUND", nil, S.Couleur("ambre", 0.12))
        l.fond:SetAllPoints()
        l.fond:Hide()
        l.puce = S.Texture(l, "ARTWORK", "Rond", 1, 1, 1)
        l.puce:SetSize(7, 7)
        l.puce:SetPoint("LEFT", 8, 0)
        l.texte = S.Texte(l, "Regular", 14, "texte")
        l.texte:SetPoint("LEFT", 24, 0)
        l.texte:SetPoint("RIGHT", -8, 0)
        l.texte:SetJustifyH("LEFT")
        l:SetScript("OnEnter", function(self) self.fond:Show() end)
        l:SetScript("OnLeave", function(self) self.fond:Hide() end)
        lignes[utilises.lignes] = l
    end
    l.texte:SetText(contenu)
    l.puce:SetVertexColor(S.Couleur(couleur))
    l:SetScript("OnClick", fonction)
    l:ClearAllPoints()
    l:SetPoint("TOPLEFT", page, "TOPLEFT", 0, y - 2)
    l:Show()
    y = y - 30
    return l
end

-- Objet (récompense, choix, objet demandé) : icône, nombre, nom ; infobulle du jeu.
local choix = 0
local function Objet(genre, numero, colonne)
    local nom, icone, nombre, qualite = GetQuestItemInfo(genre, numero)
    utilises.objets = utilises.objets + 1
    local b = objets[utilises.objets]
    if not b then
        b = CreateFrame("Button", nil, page)
        b:SetSize(220, 42)
        b.fond = S.Texture(b, "BACKGROUND", nil, S.Couleur("ambre", 0.16))
        b.fond:SetAllPoints()
        b.icone = b:CreateTexture(nil, "ARTWORK")
        b.icone:SetSize(36, 36)
        b.icone:SetPoint("LEFT", 3, 0)
        b.cadre = S.Texture(b, "BORDER", nil, S.Couleur("bord"))
        b.cadre:SetPoint("TOPLEFT", b.icone, -1, 1)
        b.cadre:SetPoint("BOTTOMRIGHT", b.icone, 1, -1)
        b.nombre = S.Texte(b, "Bold", 12, "clair")
        b.nombre:SetPoint("BOTTOMRIGHT", b.icone, "BOTTOMRIGHT", -2, 2)
        b.nom = S.Texte(b, "Regular", 12, "texte")
        b.nom:SetPoint("LEFT", b.icone, "RIGHT", 10, 0)
        b.nom:SetPoint("RIGHT", -4, 0)
        b.nom:SetJustifyH("LEFT")
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetQuestItem(self.genre, self.numero)
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        objets[utilises.objets] = b
    end
    b.genre, b.numero = genre, numero
    b.icone:SetTexture(icone)
    b.nombre:SetText(nombre and nombre > 1 and nombre or "")
    b.nom:SetText(nom or "")
    if qualite and ITEM_QUALITY_COLORS[qualite] and qualite > 1 then
        local c = ITEM_QUALITY_COLORS[qualite]
        b.nom:SetTextColor(c.r, c.g, c.b)
    else
        b.nom:SetTextColor(S.Couleur("texte"))
    end
    S.Montrer(b.fond, genre == "choice" and choix == numero)
    b:SetScript("OnClick", nil)
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", page, "TOPLEFT", colonne * 232, y)
    b:Show()
    return b
end

local function Grille(genre, nombre, fonction)
    for i = 1, nombre do
        local b = Objet(genre, i, (i - 1) % 2)
        if fonction then b:SetScript("OnClick", function() fonction(i) end) end
        if i % 2 == 0 or i == nombre then y = y - 48 end
    end
end

local function Finir()
    page:SetHeight(-y + 10)
end

------------------------------------------------------------------------
-- Boutons du bas
------------------------------------------------------------------------
local function Bouton(ancre, x)
    local b = CreateFrame("Button", nil, d, "UIPanelButtonTemplate")
    b:SetSize(150, 28)
    b:SetPoint(ancre, x, 20)
    return b
end
-- Accepter (ou Continuer, Terminer) à gauche, Refuser à droite (demande de l'utilisateur).
local principal = Bouton("BOTTOMLEFT", 24)
local secondaire = Bouton("BOTTOMRIGHT", -24)

local function Boutons(texte1, fonction1, texte2, fonction2)
    principal:SetText(texte1 or "")
    principal:SetScript("OnClick", fonction1)
    S.Montrer(principal, texte1 ~= nil)
    principal:Enable()
    secondaire:SetText(texte2 or "")
    secondaire:SetScript("OnClick", fonction2)
    S.Montrer(secondaire, texte2 ~= nil)
end

------------------------------------------------------------------------
-- Pages
------------------------------------------------------------------------
local mode   -- « discussion » ou « quete » : ce que la fermeture doit refermer côté serveur

local function Ouvrir(nouveauMode)
    mode = nouveauMode
    pnj:SetText(UnitName("npc") or "")
    Vider()
    if not d:IsShown() then d:Show() end
end

local function Recompenses(avecChoix)
    local nRecompenses, nChoix, argent = GetNumQuestRewards(), GetNumQuestChoices(), GetRewardMoney()
    if nRecompenses == 0 and nChoix == 0 and argent == 0 then return end
    Texte("RÉCOMPENSES", "rubrique", 24)
    y = y - 10
    if nChoix > 0 then
        Texte(nChoix > 1 and (avecChoix and "Choisis ta récompense :" or "Tu pourras choisir une de ces récompenses :")
            or "Tu recevras :", "discret")
        y = y - 6
        Grille("choice", nChoix, avecChoix and nChoix > 1 and function(i)
            choix = i
            S.PageRecompense()
        end or nil)
    end
    if nRecompenses > 0 then
        if nChoix > 0 then Texte("Et aussi :", "discret", 4); y = y - 6 end
        Grille("reward", nRecompenses)
    end
    if argent > 0 then Texte(S.Argent(argent), "texte", 4) end
end

local function PageDiscussion()
    Ouvrir("discussion")
    Texte(GetGossipText(), "texte")
    local actives = { GetGossipActiveQuests() }
    local proposees = { GetGossipAvailableQuests() }
    local options = { GetGossipOptions() }
    if #actives + #proposees > 0 then Texte("QUÊTES", "rubrique", 24); y = y - 6 end
    for i = 1, #actives, 4 do
        local n = (i + 3) / 4
        Ligne(actives[i], actives[i + 3] and "vertClair" or "gris", function() SelectGossipActiveQuest(n) end)
    end
    for i = 1, #proposees, 5 do
        local n = (i + 4) / 5
        Ligne(proposees[i], "ambreClair", function() SelectGossipAvailableQuest(n) end)
    end
    if #options > 0 then Texte(" ", "texte", 8) end
    for i = 1, #options, 2 do
        local n = (i + 1) / 2
        Ligne(options[i], "bleu", function() SelectGossipOption(n) end)
    end
    Finir()
    Boutons(nil, nil, "Au revoir", function() d:Hide() end)
end

local function PageAccueil()
    Ouvrir("quete")
    Texte(GetGreetingText(), "texte")
    local actives, proposees = GetNumActiveQuests(), GetNumAvailableQuests()
    if actives + proposees > 0 then Texte("QUÊTES", "rubrique", 24); y = y - 6 end
    for i = 1, actives do
        local _, complete = GetActiveTitle(i)
        Ligne(GetActiveTitle(i), complete and "vertClair" or "gris", function() SelectActiveQuest(i) end)
    end
    for i = 1, proposees do
        Ligne(GetAvailableTitle(i), "ambreClair", function() SelectAvailableQuest(i) end)
    end
    Finir()
    Boutons(nil, nil, "Au revoir", function() d:Hide() end)
end

local function PageProposee()
    Ouvrir("quete")
    Texte(GetTitleText(), "titre")
    Texte(GetQuestText(), "texte", 14)
    Texte("OBJECTIFS", "rubrique", 24)
    Texte(GetObjectiveText(), "texte", 8)
    Recompenses(false)
    Finir()
    Boutons("Accepter", function() AcceptQuest() end, "Refuser", function() DeclineQuest() end)
end

local function PageEnCours()
    Ouvrir("quete")
    Texte(GetTitleText(), "titre")
    Texte(GetProgressText(), "texte", 14)
    local demandes, argent = GetNumQuestItems(), GetQuestMoneyToGet()
    if demandes > 0 or argent > 0 then
        Texte("À APPORTER", "rubrique", 24)
        y = y - 10
        Grille("required", demandes)
        if argent > 0 then Texte(S.Argent(argent), GetMoney() >= argent and "texte" or "alerte", 4) end
    end
    Finir()
    Boutons("Continuer", function() CompleteQuest() end, "Plus tard", function() d:Hide() end)
    if not IsQuestCompletable() then principal:Disable() end
end

function S.PageRecompense()
    Ouvrir("quete")
    Texte(GetTitleText(), "titre")
    Texte(GetRewardText(), "texte", 14)
    Recompenses(true)
    Finir()
    Boutons("Terminer la quête", function()
        if GetNumQuestChoices() > 1 and choix == 0 then
            UIErrorsFrame:AddMessage("Choisis d'abord ta récompense.", 1, 0.82, 0.3)
            return
        end
        GetQuestReward(math.max(choix, GetNumQuestChoices() == 1 and 1 or 0))
    end, "Plus tard", function() d:Hide() end)
end

------------------------------------------------------------------------
-- Événements
------------------------------------------------------------------------
GossipFrame:UnregisterAllEvents()
QuestFrame:UnregisterAllEvents()

local fermeParLeJeu = false
local function FermerSans()
    fermeParLeJeu = true
    d:Hide()
    fermeParLeJeu = false
end

d:SetScript("OnShow", function() PlaySound("igQuestListOpen") end)
d:SetScript("OnHide", function()
    PlaySound("igQuestListClose")
    if fermeParLeJeu then return end
    if mode == "discussion" then CloseGossip() else CloseQuest() end
end)

S.Ecouter("GOSSIP_SHOW", function()
    -- Une seule option qui n'est pas une discussion (marchand, maître de vol…) : on y va directement, comme le jeu.
    if GetNumGossipAvailableQuests() == 0 and GetNumGossipActiveQuests() == 0 and GetNumGossipOptions() == 1
            and not ForceGossip() then
        local _, genre = GetGossipOptions()
        if genre ~= "gossip" then SelectGossipOption(1); return end
    end
    PageDiscussion()
end)
S.Ecouter("GOSSIP_CLOSED", function() if mode == "discussion" then FermerSans() end end)
S.Ecouter("QUEST_GREETING", PageAccueil)
S.Ecouter("QUEST_DETAIL", function() choix = 0; PageProposee() end)
S.Ecouter("QUEST_PROGRESS", PageEnCours)
S.Ecouter("QUEST_COMPLETE", function() choix = 0; S.PageRecompense() end)
S.Ecouter("QUEST_FINISHED", function() if mode == "quete" then FermerSans() end end)
S.Ecouter("QUEST_ITEM_UPDATE", function()
    if not d:IsShown() or mode ~= "quete" then return end
    -- Les infos des objets arrivent après coup : on redessine la page ouverte.
    if principal:GetText() == "Accepter" then PageProposee()
    elseif principal:GetText() == "Continuer" then PageEnCours()
    elseif principal:GetText() == "Terminer la quête" then S.PageRecompense() end
end)
