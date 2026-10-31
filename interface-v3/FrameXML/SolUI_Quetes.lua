-- Sol'Azeroth v3, F5d (31/10/2026) : les quêtes passent par notre interface (décision de l'utilisateur).
-- - Suivi, sous la zone : les quêtes suivies et leurs objectifs. Clic : ouvre le journal sur la quête ; clic droit :
--   ne plus la suivre. Une quête acceptée est suivie d'office (règle du journal de Blizzard, toujours chargé).
-- - Journal (touche du journal des quêtes, menu Quêtes) : la liste à gauche, la quête choisie à droite (objectifs,
--   récit, récompenses), avec Suivre, Carte et Abandonner.
-- - Mini-carte : la zone d'objectif de chaque quête suivie (le PNJ à qui la rendre, une fois terminée), au bord de la
--   carte quand elle est trop loin. Les positions viennent du serveur (quest_poi), par l'API QuestPOI du client.
-- - Carte du monde : celle de Blizzard, objectifs de quête toujours affichés.
-- Le journal et le suivi de Blizzard restent chargés (événements, raccourcis), mais rangés.

local S = SolUI

-- Rangé sous la zone (et la mini-carte) tant que le joueur ne le déplace pas.
S.DISPOSITION.quetes = { point = "TOPRIGHT", x = -20, y = -192, echelle = 1, sous = "zone" }

local LARGEUR_SUIVI = 260

------------------------------------------------------------------------
-- Données du journal
------------------------------------------------------------------------
-- Toutes les quêtes du journal, en-têtes compris (dépliés), dans l'ordre du jeu.
local function Lire()
    -- Déplier seulement s'il le faut : chaque dépliage relance QUEST_LOG_UPDATE.
    for i = 1, GetNumQuestLogEntries() do
        local _, _, _, _, enTete, replie = GetQuestLogTitle(i)
        if enTete and replie then ExpandQuestHeader(0); break end
    end
    local liste = {}
    for i = 1, GetNumQuestLogEntries() do
        local titre, _, _, _, enTete, _, complete, _, id = GetQuestLogTitle(i)
        if titre then
            local objectifs = enTete and 0 or GetNumQuestLeaderBoards(i)
            table.insert(liste, {
                index = i, titre = titre, enTete = enTete, id = id,
                -- 1 : terminée ; -1 : échouée ; une quête sans objectif (aller parler à quelqu'un) est prête d'office.
                complete = complete == 1 or (not enTete and complete ~= -1 and objectifs == 0),
                echouee = complete == -1, suivie = not enTete and IsQuestWatched(i),
            })
        end
    end
    return liste
end

-- « Sanglier tacheté tué : 3/10 » -> « 3/10 », « Sanglier tacheté tué ».
local function Objectifs(index)
    local lignes = {}
    for j = 1, GetNumQuestLeaderBoards(index) do
        local texte, _, fini = GetQuestLogLeaderBoard(j, index)
        if texte then
            local quoi, compte = texte:match("^(.-)%s*:%s*(%d+%s*/%s*%d+)$")
            table.insert(lignes, { compte = compte, texte = quoi or texte, fini = fini })
        end
    end
    return lignes
end

------------------------------------------------------------------------
-- Suivi
------------------------------------------------------------------------
local suivi = CreateFrame("Frame", "SolUISuiviQuetes", S.racine)
suivi:SetSize(LARGEUR_SUIVI, 40)
S.Placer(suivi, "quetes")

local entete = S.Texte(suivi, "SemiBold", 11, "gris")
entete:SetPoint("TOPLEFT", 2, 0)

local rangees, lignes = {}, {}

local function Rangee(n)
    if rangees[n] then return rangees[n] end
    local r = CreateFrame("Button", nil, suivi)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r.titre = S.Texte(r, "SemiBold", 13, "clair")
    r.titre:SetPoint("TOPLEFT")
    r.titre:SetPoint("RIGHT")
    r.titre:SetJustifyH("LEFT")
    r:SetScript("OnEnter", function(self) self.titre:SetTextColor(S.Couleur("ambreClair")) end)
    r:SetScript("OnLeave", function(self) self.titre:SetTextColor(S.Couleur(self.couleur)) end)
    r:SetScript("OnClick", function(self, bouton)
        if bouton == "RightButton" then
            RemoveQuestWatch(self.index)
            S.MajQuetes()
        else
            S.OuvrirJournal(self.index)
        end
    end)
    -- Objet de quête utilisable (matraque, fiole…) : à gauche du titre, comme dans le suivi de Blizzard.
    local o = CreateFrame("Button", nil, r)
    o:SetSize(26, 26)
    o:SetPoint("TOPRIGHT", r, "TOPLEFT", -6, 3)
    o:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    o.fond = S.Texture(o, "BACKGROUND", nil, S.Couleur("bord"))
    o.fond:SetAllPoints()
    o.icone = o:CreateTexture(nil, "ARTWORK")
    o.icone:SetPoint("TOPLEFT", 1, -1)
    o.icone:SetPoint("BOTTOMRIGHT", -1, 1)
    o.icone:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    o.nombre = S.Texte(o, "SemiBold", 10, "clair")
    o.nombre:SetPoint("BOTTOMRIGHT", -1, 1)
    o.recharge = CreateFrame("Cooldown", nil, o, "CooldownFrameTemplate")
    o.recharge:SetAllPoints(o.icone)
    o:SetScript("OnClick", function(self)
        if IsModifiedClick("CHATLINK") and ChatFrameEditBox:IsVisible() then
            ChatFrameEditBox:Insert((GetQuestLogSpecialItemInfo(self.index)))
        else
            UseQuestLogSpecialItem(self.index)
        end
    end)
    o:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetQuestLogSpecialItem(self.index)
    end)
    o:SetScript("OnLeave", function() GameTooltip:Hide() end)
    o:SetScript("OnUpdate", function(self)
        local portee = IsQuestLogSpecialItemInRange(self.index)
        if portee == 0 then self.icone:SetVertexColor(0.85, 0.35, 0.32) else self.icone:SetVertexColor(1, 1, 1) end
    end)
    r.objet = o
    rangees[n] = r
    return r
end

local function MajObjet(r, index)
    local lien, icone, charges = GetQuestLogSpecialItemInfo(index)
    local o = r.objet
    S.Montrer(o, lien ~= nil)
    if not lien then return end
    o.index = index
    o.icone:SetTexture(icone)
    o.nombre:SetText(charges and charges > 1 and charges or "")
    local debut, duree, active = GetQuestLogSpecialItemCooldown(index)
    if debut then CooldownFrame_SetTimer(o.recharge, debut, duree, active) end
end

local function Ligne(n)
    if lignes[n] then return lignes[n] end
    local l = CreateFrame("Frame", nil, suivi)
    l:SetHeight(16)
    l.compte = S.Texte(l, "SemiBold", 12, "texte")
    l.compte:SetPoint("TOPLEFT", 10, 0)
    l.compte:SetWidth(40)
    l.compte:SetJustifyH("LEFT")
    l.texte = S.Texte(l, "Regular", 12, "gris")
    l.texte:SetPoint("TOPLEFT", 50, 0)
    l.texte:SetPoint("RIGHT")
    l.texte:SetJustifyH("LEFT")
    lignes[n] = l
    return l
end

local HAUTEUR_MAX = 440

local function MajSuivi(liste)
    local y, nr, nl, nombre = -18, 0, 0, 0
    for _, q in ipairs(liste) do
        if q.suivie then nombre = nombre + 1 end
    end
    entete:SetText(nombre > 0 and ("QUÊTES  " .. nombre) or (S.EnEdition() and "QUÊTES" or ""))
    for _, q in ipairs(liste) do
        if q.suivie and -y < HAUTEUR_MAX then
            nr = nr + 1
            local r = Rangee(nr)
            r.index = q.index
            r.couleur = q.complete and "vertClair" or (q.echouee and "rougeClair" or "clair")
            r.titre:SetText(q.titre)
            r.titre:SetTextColor(S.Couleur(r.couleur))
            MajObjet(r, q.index)
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 2, y)
            r:SetPoint("RIGHT", suivi, "RIGHT")
            r:SetHeight(17)
            r:Show()
            y = y - (r.objet:IsShown() and 23 or 19)
            local details = Objectifs(q.index)
            if q.complete then
                details = { { texte = (#details > 0) and "Prête à rendre" or "À rendre", fini = true } }
            end
            for _, d in ipairs(details) do
                nl = nl + 1
                local l = Ligne(nl)
                l.compte:SetText(d.compte or "")
                l.texte:ClearAllPoints()
                l.texte:SetPoint("TOPLEFT", d.compte and 50 or 10, 0)
                l.texte:SetPoint("RIGHT")
                l.texte:SetText(d.texte)
                local couleur = d.fini and "vert" or "gris"
                l.texte:SetTextColor(S.Couleur(couleur))
                l.compte:SetTextColor(S.Couleur(d.fini and "vert" or "texte"))
                l:ClearAllPoints()
                l:SetPoint("TOPLEFT", 2, y)
                l:SetPoint("RIGHT", suivi, "RIGHT")
                l:Show()
                y = y - 16
            end
            y = y - 8
        end
    end
    for i = nr + 1, #rangees do rangees[i]:Hide() end
    for i = nl + 1, #lignes do lignes[i]:Hide() end
    suivi:SetHeight(math.max(40, -y))
end

------------------------------------------------------------------------
-- Journal
------------------------------------------------------------------------
local journal = CreateFrame("Frame", "SolUIJournal", S.racine)
journal:SetSize(780, 540)
journal:SetPoint("CENTER", S.racine, "CENTER", 0, 20)
journal:SetFrameStrata("HIGH")
journal:SetToplevel(true)
journal:EnableMouse(true)
journal:SetMovable(true)
journal:SetClampedToScreen(true)
S.Panneau(journal, 0.96)
journal:Hide()
tinsert(UISpecialFrames, "SolUIJournal")

local barre = CreateFrame("Frame", nil, journal)
barre:SetPoint("TOPLEFT")
barre:SetPoint("TOPRIGHT")
barre:SetHeight(44)
barre:EnableMouse(true)
barre:RegisterForDrag("LeftButton")
barre:SetScript("OnDragStart", function() journal:StartMoving() end)
barre:SetScript("OnDragStop", function() journal:StopMovingOrSizing(); journal:SetUserPlaced(false) end)

local titreJournal = S.Texte(barre, "Bold", 16, "clair")
titreJournal:SetPoint("LEFT", 18, -2)
titreJournal:SetText("Journal des quêtes")
local compteJournal = S.Texte(barre, "Regular", 12, "gris")
compteJournal:SetPoint("LEFT", titreJournal, "RIGHT", 12, 0)

local fermer = CreateFrame("Button", nil, barre, "UIPanelCloseButton")
fermer:SetPoint("RIGHT", -6, 0)
fermer:SetScript("OnClick", function() journal:Hide() end)

local filet = S.Texture(journal, "ARTWORK", nil, S.Couleur("bord"))
filet:SetPoint("TOPLEFT", 1, -44)
filet:SetPoint("TOPRIGHT", -1, -44)
filet:SetHeight(1)

-- Liste à gauche
local LARGEUR_LISTE, HAUTEUR_LIGNE = 270, 26
local listeCadre = CreateFrame("Frame", nil, journal)
listeCadre:SetPoint("TOPLEFT", 1, -45)
listeCadre:SetPoint("BOTTOMLEFT", 1, 1)
listeCadre:SetWidth(LARGEUR_LISTE)
listeCadre:SetBackdrop({ bgFile = S.BLANC })
listeCadre:SetBackdropColor(S.Couleur("creux", 0.6))
listeCadre:EnableMouseWheel(true)
local separation = S.Texture(journal, "ARTWORK", nil, S.Couleur("bord"))
separation:SetPoint("TOPLEFT", listeCadre, "TOPRIGHT")
separation:SetPoint("BOTTOMLEFT", listeCadre, "BOTTOMRIGHT")
separation:SetWidth(1)

local entrees, decalage, choisie, contenu = {}, 0, nil, {}

local function Entree(n)
    if entrees[n] then return entrees[n] end
    local e = CreateFrame("Button", nil, listeCadre)
    e:SetHeight(HAUTEUR_LIGNE)
    e:SetPoint("TOPLEFT", 0, -8 - (n - 1) * HAUTEUR_LIGNE)
    e:SetPoint("RIGHT", listeCadre, "RIGHT")
    e.fond = S.Texture(e, "BACKGROUND", nil, S.Couleur("ambre", 0.14))
    e.fond:SetAllPoints()
    e.marque = S.Texture(e, "ARTWORK", nil, S.Couleur("ambre"))
    e.marque:SetPoint("TOPLEFT")
    e.marque:SetPoint("BOTTOMLEFT")
    e.marque:SetWidth(3)
    e.texte = S.Texte(e, "Regular", 13, "texte")
    e.texte:SetPoint("LEFT", 16, 0)
    e.texte:SetPoint("RIGHT", -56, 0)
    e.texte:SetJustifyH("LEFT")
    e.etat = S.Texte(e, "Regular", 11, "vertClair")
    e.etat:SetPoint("RIGHT", -12, 0)
    e.oeil = S.Texture(e, "ARTWORK", "Rond", S.Couleur("ambreClair"))
    e.oeil:SetSize(6, 6)
    e.oeil:SetPoint("LEFT", 6, 0)
    e:SetScript("OnEnter", function(self) if not self.enTete then self.texte:SetTextColor(S.Couleur("clair")) end end)
    e:SetScript("OnLeave", function(self) if not self.enTete then self.texte:SetTextColor(S.Couleur("texte")) end end)
    e:SetScript("OnClick", function(self)
        if self.enTete then return end
        choisie = self.id
        S.MajQuetes()
    end)
    entrees[n] = e
    return e
end

-- Détail à droite : un seul défilement pour les objectifs, le récit et les récompenses.
local detail = CreateFrame("ScrollFrame", "SolUIJournalDetail", journal)
detail:SetPoint("TOPLEFT", listeCadre, "TOPRIGHT", 28, -20)
detail:SetPoint("BOTTOMRIGHT", journal, "BOTTOMRIGHT", -28, 60)
detail:EnableMouseWheel(true)
local page = CreateFrame("Frame", nil, detail)
page:SetSize(450, 10)
detail:SetScrollChild(page)
detail:SetScript("OnMouseWheel", function(self, sens)
    local maxi = math.max(0, page:GetHeight() - self:GetHeight())
    self:SetVerticalScroll(math.max(0, math.min(maxi, self:GetVerticalScroll() - sens * 40)))
end)

local LARGEUR_PAGE = 450
local function TextePage(graisse, taille, couleur)
    local t = S.Texte(page, graisse, taille, couleur)
    t:SetWidth(LARGEUR_PAGE)
    t:SetJustifyH("LEFT")
    t:SetJustifyV("TOP")
    return t
end

contenu.titre = TextePage("Bold", 20, "clair")
contenu.etat = TextePage("SemiBold", 12, "vertClair")
contenu.rubriqueObjectifs = TextePage("SemiBold", 11, "ambreClair")
contenu.rubriqueObjectifs:SetText("OBJECTIFS")
contenu.resume = TextePage("Regular", 13, "texte")
contenu.rubriqueRecit = TextePage("SemiBold", 11, "ambreClair")
contenu.rubriqueRecit:SetText("RÉCIT")
contenu.recit = TextePage("Regular", 13, "gris")
contenu.recit:SetSpacing(3)
contenu.rubriqueRecompenses = TextePage("SemiBold", 11, "ambreClair")
contenu.rubriqueRecompenses:SetText("RÉCOMPENSES")
contenu.argent = TextePage("Regular", 13, "texte")
contenu.vide = TextePage("Regular", 13, "gris")
contenu.vide:SetText("Aucune quête dans ton journal.")
local objectifsLignes, recompenses = {}, {}

local function Recompense(n)
    if recompenses[n] then return recompenses[n] end
    local b = CreateFrame("Button", nil, page)
    b:SetSize(210, 40)
    b.icone = b:CreateTexture(nil, "ARTWORK")
    b.icone:SetSize(36, 36)
    b.icone:SetPoint("LEFT", 0, 0)
    b.cadre = S.Texture(b, "BORDER", nil, S.Couleur("bord"))
    b.cadre:SetPoint("TOPLEFT", b.icone, -1, 1)
    b.cadre:SetPoint("BOTTOMRIGHT", b.icone, 1, -1)
    b.nombre = S.Texte(b, "Bold", 12, "clair")
    b.nombre:SetPoint("BOTTOMRIGHT", b.icone, "BOTTOMRIGHT", -2, 2)
    b.nom = S.Texte(b, "Regular", 12, "texte")
    b.nom:SetPoint("LEFT", b.icone, "RIGHT", 10, 0)
    b.nom:SetPoint("RIGHT")
    b.nom:SetJustifyH("LEFT")
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetQuestLogItem(self.genre, self.numero)
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    recompenses[n] = b
    return b
end

-- Pose un texte sous le précédent et renvoie la nouvelle hauteur.
local function Poser(objet, y, ecart)
    objet:ClearAllPoints()
    objet:SetPoint("TOPLEFT", page, "TOPLEFT", 0, y - (ecart or 0))
    objet:Show()
    return y - (ecart or 0) - objet:GetHeight()
end

local boutons = {}

local function MajDetail(q)
    for _, objet in pairs(contenu) do objet:Hide() end
    for _, l in ipairs(objectifsLignes) do l:Hide() end
    for _, r in ipairs(recompenses) do r:Hide() end
    for _, b in pairs(boutons) do S.Montrer(b, q ~= nil) end
    if not q then
        Poser(contenu.vide, 0)
        page:SetHeight(40)
        return
    end
    SelectQuestLogEntry(q.index)
    local recit, resume = GetQuestLogQuestText()
    local y = 0
    contenu.titre:SetText(q.titre)
    y = Poser(contenu.titre, y)
    if q.complete or q.echouee then
        contenu.etat:SetText(q.echouee and "Échouée" or "Terminée : retourne la rendre")
        contenu.etat:SetTextColor(S.Couleur(q.echouee and "rougeClair" or "vertClair"))
        y = Poser(contenu.etat, y, 6)
    end
    y = Poser(contenu.rubriqueObjectifs, y, 22)
    contenu.resume:SetText(resume or "")
    y = Poser(contenu.resume, y, 8)
    for n, d in ipairs(Objectifs(q.index)) do
        local l = objectifsLignes[n]
        if not l then
            l = TextePage("Regular", 13, "texte")
            objectifsLignes[n] = l
        end
        l:SetText((d.compte and (d.compte .. "   ") or "• ") .. d.texte)
        l:SetTextColor(S.Couleur(d.fini and "vert" or "texte"))
        y = Poser(l, y, n == 1 and 10 or 4)
    end
    y = Poser(contenu.rubriqueRecit, y, 24)
    contenu.recit:SetText(recit or "")
    y = Poser(contenu.recit, y, 8)

    local n = 0
    local function Ajouter(genre, numero, nom, icone, nombre)
        n = n + 1
        local b = Recompense(n)
        b.genre, b.numero = genre, numero
        b.icone:SetTexture(icone)
        b.nombre:SetText(nombre and nombre > 1 and nombre or "")
        b.nom:SetText(nom or "")
        return b
    end
    for k = 1, GetNumQuestLogRewards() do
        local nom, icone, nombre = GetQuestLogRewardInfo(k)
        Ajouter("reward", k, nom, icone, nombre)
    end
    for k = 1, GetNumQuestLogChoices() do
        local nom, icone, nombre = GetQuestLogChoiceInfo(k)
        Ajouter("choice", k, nom, icone, nombre)
    end
    local argent = GetQuestLogRewardMoney()
    if n > 0 or argent > 0 then
        y = Poser(contenu.rubriqueRecompenses, y, 24)
        y = y - 10
        for k = 1, n do
            local b = recompenses[k]
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", page, "TOPLEFT", ((k - 1) % 2) * 225, y - math.floor((k - 1) / 2) * 46)
            b:Show()
        end
        y = y - math.ceil(n / 2) * 46
        if argent > 0 then
            contenu.argent:SetText(S.Argent(argent))
            y = Poser(contenu.argent, y, 4)
        end
    end
    page:SetHeight(-y + 10)
    boutons.suivre:SetText(q.suivie and "Ne plus suivre" or "Suivre")
end

local function Bouton(texte, largeur, fonction)
    local b = CreateFrame("Button", nil, journal, "UIPanelButtonTemplate")
    b:SetSize(largeur, 26)
    b:SetText(texte)
    b:SetScript("OnClick", fonction)
    return b
end

local function Choisie()
    for _, q in ipairs(Lire()) do
        if not q.enTete and q.id == choisie then return q end
    end
end

boutons.abandonner = Bouton("Abandonner", 120, function()
    local q = Choisie()
    if not q then return end
    SelectQuestLogEntry(q.index)
    SetAbandonQuest()
    StaticPopup_Show("ABANDON_QUEST", GetAbandonQuestName())
end)
boutons.abandonner:SetPoint("BOTTOMLEFT", listeCadre, "BOTTOMRIGHT", 28, 18)
boutons.carte = Bouton("Carte", 100, function()
    local q = Choisie()
    if q then journal:Hide(); WorldMap_OpenToQuest(q.id) end
end)
boutons.carte:SetPoint("BOTTOMRIGHT", -28, 18)
boutons.suivre = Bouton("Suivre", 130, function()
    local q = Choisie()
    if not q then return end
    if q.suivie then
        RemoveQuestWatch(q.index)
    elseif GetNumQuestWatches() < MAX_WATCHABLE_QUESTS then
        AddQuestWatch(q.index)
    end
    S.MajQuetes()
end)
boutons.suivre:SetPoint("RIGHT", boutons.carte, "LEFT", -8, 0)

local function MajJournal(liste)
    local quetes = 0
    local existe = false
    for _, q in ipairs(liste) do
        if not q.enTete then
            quetes = quetes + 1
            if q.id == choisie then existe = true end
        end
    end
    if not existe then
        choisie = nil
        for _, q in ipairs(liste) do
            if not q.enTete then choisie = q.id; break end
        end
    end
    compteJournal:SetText(quetes .. " / " .. MAX_QUESTLOG_QUESTS)

    local visibles = math.floor((listeCadre:GetHeight() - 16) / HAUTEUR_LIGNE)
    decalage = math.max(0, math.min(decalage, #liste - visibles))
    local q_choisie
    for n = 1, math.max(visibles, #entrees) do
        local q = n <= visibles and liste[n + decalage]
        if q then
            local e = Entree(n)
            e.enTete, e.id = q.enTete, q.id
            e.texte:SetText(q.enTete and q.titre:upper() or q.titre)
            S.Police(e.texte, q.enTete and "SemiBold" or "Regular", q.enTete and 11 or 13)
            e.texte:SetTextColor(S.Couleur(q.enTete and "gris" or "texte"))
            e.etat:SetText(q.complete and "Prête" or (q.echouee and "Échouée" or ""))
            e.etat:SetTextColor(S.Couleur(q.echouee and "rougeClair" or "vertClair"))
            local estChoisie = not q.enTete and q.id == choisie
            S.Montrer(e.fond, estChoisie)
            S.Montrer(e.marque, estChoisie)
            S.Montrer(e.oeil, q.suivie)
            e:Show()
        elseif entrees[n] then
            entrees[n]:Hide()
        end
    end
    for _, q in ipairs(liste) do
        if not q.enTete and q.id == choisie then q_choisie = q end
    end
    MajDetail(q_choisie)
end

listeCadre:SetScript("OnMouseWheel", function(_, sens)
    decalage = decalage - sens * 3
    S.MajQuetes()
end)

function S.OuvrirJournal(index)
    if index then
        local _, _, _, _, _, _, _, _, id = GetQuestLogTitle(index)
        choisie = id
    end
    journal:Show()
    S.MajQuetes()
end

function S.BasculerJournal()
    if journal:IsShown() then journal:Hide() else S.OuvrirJournal() end
end

journal:SetScript("OnShow", function() PlaySound("igQuestLogOpen") end)
journal:SetScript("OnHide", function() PlaySound("igQuestLogClose") end)

-- Le journal de Blizzard reste chargé (touche du journal, liens de quête) : il ouvre le nôtre à sa place.
S.Ranger(WatchFrame)
local ouvrirSeulement = false
local ouvrirOrigine = QuestLog_OpenToQuest
QuestLog_OpenToQuest = function(index, ...)
    ouvrirSeulement = index
    ouvrirOrigine(index, ...)
    ouvrirSeulement = false
end
QuestLogFrame:HookScript("OnShow", function()
    HideUIPanel(QuestLogFrame)
    if ouvrirSeulement then S.OuvrirJournal(ouvrirSeulement) else S.BasculerJournal() end
end)

------------------------------------------------------------------------
-- Mini-carte : zones d'objectif des quêtes suivies
------------------------------------------------------------------------
-- Diamètre de la mini-carte en mètres du jeu, selon le zoom (dehors, dedans).
local DIAMETRE = { dehors = { 466.67, 400, 333.33, 266.67, 200, 133.33 }, dedans = { 300, 240, 180, 120, 80, 50 } }
local RAYON_ZONE = 45   -- rayon des zones d'objectif (outils\quetes_durotar.py)

local reperes = {}
local positions = {}   -- quêtes suivies : { x, y (de 0 à 1 sur la carte de la zone), complete }
local cartePositions

local function Repere(n)
    if reperes[n] then return reperes[n] end
    local r = CreateFrame("Frame", nil, Minimap)
    r:SetFrameLevel(Minimap:GetFrameLevel() + 3)
    r.zone = S.Texture(r, "ARTWORK", "Rond", S.Couleur("ambre", 0.22))
    r.zone:SetAllPoints()
    r.bord = S.Texture(r, "OVERLAY", "Anneau", S.Couleur("ambre", 0.9))
    r.bord:SetAllPoints()
    r.point = S.Texture(r, "OVERLAY", "Rond", S.Couleur("ambreClair"))
    r.point:SetSize(7, 7)
    r.point:SetPoint("CENTER")
    reperes[n] = r
    return r
end

-- Lit la position de chaque quête suivie sur la carte de la zone du joueur (sans toucher à la carte ouverte).
local function LirePositions()
    if WorldMapFrame:IsShown() then return end
    SetMapToCurrentZone()
    QuestPOIUpdateIcons()
    cartePositions = GetMapInfo()
    wipe(positions)
    for _, q in ipairs(Lire()) do
        if q.suivie and q.id then
            local _, x, y = QuestPOIGetIconInfo(q.id)
            if x and y then table.insert(positions, { x = x, y = y, complete = q.complete }) end
        end
    end
end

local attente = 0
local function MajReperes(self, ecoule)
    attente = attente - ecoule
    if attente > 0 then return end
    attente = 0.05
    local carte = S.CARTES and S.CARTES[cartePositions]
    local px, py = GetPlayerMapPosition("player")
    local n = 0
    if carte and px and not WorldMapFrame:IsShown() and GetMapInfo() == cartePositions and (px > 0 or py > 0) then
        local zoom = Minimap:GetZoom() + 1
        local rayon = (IsIndoors() and DIAMETRE.dedans or DIAMETRE.dehors)[zoom] / 2
        local pixels = Minimap:GetWidth() / 2
        local angle = GetCVar("rotateMinimap") == "1" and GetPlayerFacing() or 0
        local c, s = math.cos(angle), math.sin(angle)
        for _, p in ipairs(positions) do
            -- Écart en mètres : x vers l'est, y vers le sud (sens de la carte).
            local dx, dy = (p.x - px) * carte[1], (p.y - py) * carte[2]
            dx, dy = dx * c - dy * s, dx * s + dy * c
            local distance = math.sqrt(dx * dx + dy * dy)
            n = n + 1
            local r = Repere(n)
            local loin = distance + (p.complete and 0 or RAYON_ZONE * 0.3) > rayon
            local echelle = pixels / rayon
            if loin then
                local bord = (pixels - 5) / math.max(distance, 0.01)
                dx, dy = dx * bord / echelle, dy * bord / echelle
            end
            local m = S.OPTIONS.reperes
            local taille = (loin or p.complete) and 9 * m or math.max(9 * m, 2 * RAYON_ZONE * echelle)
            r:SetSize(taille, taille)
            r.point:SetSize(7 * m, 7 * m)
            r:ClearAllPoints()
            r:SetPoint("CENTER", Minimap, "CENTER", dx * echelle, -dy * echelle)
            S.Montrer(r.zone, not loin and not p.complete)
            S.Montrer(r.bord, not loin and not p.complete)
            r.point:SetVertexColor(S.Couleur(p.complete and "vertClair" or "ambreClair"))
            r:Show()
        end
    end
    for i = n + 1, #reperes do reperes[i]:Hide() end
end

-- Les zones d'objectif arrivent du serveur après coup (et changent avec la progression) : relues toutes les 3 s.
local relecture = 0
local animation = CreateFrame("Frame", nil, Minimap)
animation:SetScript("OnUpdate", function(self, ecoule)
    relecture = relecture - ecoule
    if relecture <= 0 then
        relecture = 3
        LirePositions()
    end
    MajReperes(self, ecoule)
end)

-- /soltexte <mot> : quel cadre affiche ce texte (pour retirer un élément d'interface inconnu).
SLASH_SOLUITEXTE1 = "/soltexte"
SlashCmdList.SOLUITEXTE = function(mot)
    mot = (mot or ""):lower()
    if mot == "" then return end
    local function Chemin(cadre)
        local noms = {}
        while cadre do
            table.insert(noms, 1, cadre:GetName() or ("<" .. cadre:GetObjectType() .. ">"))
            cadre = cadre:GetParent()
        end
        return table.concat(noms, " > ")
    end
    local trouves = 0
    local cadre = EnumerateFrames()
    while cadre do
        for _, region in ipairs({ cadre:GetRegions() }) do
            local texte = region:GetObjectType() == "FontString" and region:GetText()
            if texte and texte:lower():find(mot, 1, true) then
                trouves = trouves + 1
                DEFAULT_CHAT_FRAME:AddMessage(string.format("%s (%s, %s) : %s", Chemin(cadre), region:GetName() or "texte",
                    cadre:IsVisible() and "visible" or "caché", texte))
            end
        end
        cadre = EnumerateFrames(cadre)
    end
    DEFAULT_CHAT_FRAME:AddMessage(trouves .. " texte(s) contenant « " .. mot .. " ».")
end

-- /solpoi : ce que lit la mini-carte (pour un rapport de bogue).
SLASH_SOLUIPOI1 = "/solpoi"
SlashCmdList.SOLUIPOI = function()
    LirePositions()
    local px, py = GetPlayerMapPosition("player")
    DEFAULT_CHAT_FRAME:AddMessage(string.format("Carte %s (%s), joueur %.3f %.3f, %d repère(s)", tostring(cartePositions),
        S.CARTES[cartePositions or ""] and "taille connue" or "taille inconnue", px or 0, py or 0, #positions))
    for _, q in ipairs(Lire()) do
        if q.suivie then
            local a, x, y = QuestPOIGetIconInfo(q.id)
            DEFAULT_CHAT_FRAME:AddMessage(string.format("  %s (%s) : %s %s %s", q.titre, tostring(q.id), tostring(a),
                tostring(x), tostring(y)))
        end
    end
end

------------------------------------------------------------------------
-- Mises à jour
------------------------------------------------------------------------
local enRetard = false
local relance = CreateFrame("Frame")
relance:Hide()
relance:SetScript("OnUpdate", function(self)
    self:Hide()
    enRetard = false
    local liste = Lire()
    MajSuivi(liste)
    if journal:IsShown() then MajJournal(liste) end
    LirePositions()
end)

-- Regroupe les mises à jour d'une même image (le jeu envoie plusieurs événements à la fois).
function S.MajQuetes()
    if not enRetard then
        enRetard = true
        relance:Show()
    end
end

for _, evenement in ipairs({ "QUEST_LOG_UPDATE", "QUEST_WATCH_UPDATE", "UNIT_QUEST_LOG_CHANGED", "PLAYER_ENTERING_WORLD",
        "ZONE_CHANGED_NEW_AREA" }) do
    S.Ecouter(evenement, S.MajQuetes)
end

-- Zones d'objectif reçues du serveur : relues au plus toutes les 2 s (la relecture elle-même peut relancer
-- l'événement).
local derniereLecture = 0
S.Ecouter("BAG_UPDATE_COOLDOWN", S.MajQuetes)
S.Ecouter("QUEST_POI_UPDATE", function()
    if GetTime() - derniereLecture < 2 then return end
    derniereLecture = GetTime()
    LirePositions()
end)
WorldMapFrame:HookScript("OnHide", S.MajQuetes)

-- La carte du monde montre toujours les objectifs de quête.
S.Ecouter("PLAYER_ENTERING_WORLD", function() SetCVar("questPOI", "1") end)
