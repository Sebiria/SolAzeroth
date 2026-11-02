-- Sol'Azeroth v3, F5d (31/10/2026) : les quêtes passent par notre interface (décision de l'utilisateur).
-- - Suivi, sous la zone : les quêtes suivies et leurs objectifs. Clic : ouvre le journal sur la quête ; clic droit :
--   ne plus la suivre. Une quête acceptée est suivie d'office (règle du journal de Blizzard, toujours chargé).
-- - Journal (touche du journal des quêtes, menu Quêtes) : la liste à gauche, la quête choisie à droite (objectifs,
--   récit, récompenses), avec Suivre, Carte et Abandonner.
-- - Mini-carte : la zone d'objectif de chaque quête suivie (le PNJ à qui la rendre, une fois terminée), au bord de la
--   carte quand elle est trop loin. Les positions viennent du serveur (quest_poi), par l'API QuestPOI du client.
-- - Carte du monde : celle de Blizzard, objectifs de quête toujours affichés, et un « ! » sur chaque PNJ qui a une
--   quête à prendre (31/10/2026, liste envoyée par le serveur).
-- Le journal et le suivi de Blizzard restent chargés (événements, raccourcis), mais rangés.

local S = SolUI

-- Rangé sous la zone (et la mini-carte) tant que le joueur ne le déplace pas.
S.DISPOSITION.quetes = { point = "TOPRIGHT", x = -20, y = -192, echelle = 1, sous = "zone" }

local LARGEUR_SUIVI = 260

-- Lot D3 : une récompense que la classe ne porte pas (maille, bouclier pour le démoniste) se montre dans la version que
-- le serveur donne à la place (SolUI_Versions.lua, v3_armures.cpp). Renvoie l'entrée, le nom et l'icône, ou rien.
function S.VersionObjet(lien)
    local id = lien and tonumber(lien:match("item:(%d+)"))
    local v = id and (S.VERSIONS[select(2, UnitClass("player"))] or {})[id]
    if v then return v[1], v[2], GetItemIcon(v[1]) end
end

-- Infobulle d'une récompense : celle de sa version s'il y en a une.
function S.InfobulleObjet(lien, sinon)
    local version = S.VersionObjet(lien)
    if version then GameTooltip:SetHyperlink("item:" .. version) else sinon() end
end

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
        local titre, niveau, _, _, enTete, _, complete, _, id = GetQuestLogTitle(i)
        if titre then
            local objectifs = enTete and 0 or GetNumQuestLeaderBoards(i)
            table.insert(liste, {
                index = i, titre = titre, enTete = enTete, id = id, niveau = niveau,
                -- 1 : terminée ; -1 : échouée ; une quête sans objectif (aller parler à quelqu'un) est prête d'office.
                complete = complete == 1 or (not enTete and complete ~= -1 and objectifs == 0),
                echouee = complete == -1, suivie = not enTete and IsQuestWatched(i),
            })
        end
    end
    return liste
end

-- Titre précédé de la puissance de la quête (son niveau d'origine), comme sur la carte du monde.
-- Nos quêtes restent au niveau du joueur : leur puissance vient de SolUI_Puissances.lua.
function S.PuissanceQuete(id, niveau)
    return S.PUISSANCES_QUETES and S.PUISSANCES_QUETES[id or 0] or niveau
end

function S.TitreQuete(q)
    local puissance = S.PuissanceQuete(q.id, q.niveau)
    if puissance and puissance > 0 then return string.format("[%d] %s", puissance, q.titre) end
    return q.titre
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
        if IsModifiedClick("CHATLINK") and ChatFrame1EditBox:IsVisible() then
            ChatFrame1EditBox:Insert((GetQuestLogSpecialItemInfo(self:GetID())))
        else
            -- Index lu par GetID, jamais dans un champ : le suivi est aussi mis à jour par l'addon SolAzeroth (quêtes
            -- suivies), et une valeur écrite pendant cette mise à jour contamine le clic (« action bloquée », 01/11/2026).
            UseQuestLogSpecialItem(self:GetID())
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
-- Toutes les rangées naissent au chargement, en code de confiance : créées pendant une mise à jour lancée par l'addon
-- SolAzeroth, leur bouton d'objet de quête aurait un gestionnaire de clic contaminé (« action bloquée », 01/11/2026).
for n = 1, MAX_QUESTLOG_QUESTS or 25 do Rangee(n):Hide() end

local function MajObjet(r, index)
    local lien, icone, charges = GetQuestLogSpecialItemInfo(index)
    local o = r.objet
    S.Montrer(o, lien ~= nil)
    if not lien then return end
    o.index = index
    o:SetID(index)
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
            r.titre:SetText(S.TitreQuete(q))
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
        S.InfobulleObjet(GetQuestLogItemLink(self.genre, self.numero),
            function() GameTooltip:SetQuestLogItem(self.genre, self.numero) end)
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
    contenu.titre:SetText(S.TitreQuete(q))
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
        local _, nomVersion, iconeVersion = S.VersionObjet(GetQuestLogItemLink(genre, numero))
        nom, icone = nomVersion or nom, iconeVersion or icone
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

-- Journal trié par puissance croissante (01/11/2026, demande de l'utilisateur) : dans chaque zone, ses quêtes de la
-- plus faible à la plus forte (à égalité, par titre), et les zones dans l'ordre de leur quête la plus faible.
local function Trier(liste)
    local groupes, groupe = {}, nil
    for _, q in ipairs(liste) do
        if q.enTete or not groupe then
            groupe = { entete = q.enTete and q or nil, quetes = {} }
            table.insert(groupes, groupe)
        end
        if not q.enTete then
            q.puissance = S.PuissanceQuete(q.id, q.niveau) or 0
            table.insert(groupe.quetes, q)
        end
    end
    local function Avant(a, b)
        if a.puissance ~= b.puissance then return a.puissance < b.puissance end
        return a.titre < b.titre
    end
    for n, g in ipairs(groupes) do
        table.sort(g.quetes, Avant)
        g.min, g.rang = g.quetes[1] and g.quetes[1].puissance or math.huge, n
    end
    table.sort(groupes, function(a, b)
        if a.min ~= b.min then return a.min < b.min end
        return a.rang < b.rang
    end)
    local triee = {}
    for _, g in ipairs(groupes) do
        if g.entete then table.insert(triee, g.entete) end
        for _, q in ipairs(g.quetes) do table.insert(triee, q) end
    end
    return triee
end

local function MajJournal(liste)
    liste = Trier(liste)
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
            e.texte:SetText(q.enTete and q.titre:upper() or S.TitreQuete(q))
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
-- Mini-carte : zones d'objectif des quêtes du journal
------------------------------------------------------------------------
-- Diamètre de la mini-carte en mètres du jeu, selon le zoom (dehors, dedans).
local DIAMETRE = { dehors = { 466.67, 400, 333.33, 266.67, 200, 133.33 }, dedans = { 300, 240, 180, 120, 80, 50 } }
local RAYON_ZONE = 45   -- rayon des zones d'objectif (outils\quetes_durotar.py)

local reperes = {}
local positions = {}   -- quêtes suivies : { x, y (de 0 à 1 sur la carte de la zone), complete }
local primes = {}      -- primes du journal pas encore remplies (quête -> vrai) : tête de mort sur leur cible
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

-- Lit la position de chaque quête du journal sur la carte de la zone du joueur (sans toucher à la carte ouverte) :
-- les quêtes suivies, et les autres pas encore remplies (01/11/2026, demande de l'utilisateur : savoir où chercher).
local function LirePositions()
    if WorldMapFrame:IsShown() then return end
    SetMapToCurrentZone()
    SetCVar("questPOI", "1")   -- le temps de lire (voir « Épingles » plus bas)
    QuestPOIUpdateIcons()
    cartePositions = GetMapInfo()
    wipe(positions)
    wipe(primes)
    for _, q in ipairs(Lire()) do
        local annexe = q.id and S.ANNEXES and S.ANNEXES[q.id]
        if annexe and annexe.cible and not q.complete and not q.echouee then primes[q.id] = true end
        if q.id and not q.enTete and (q.suivie or not q.complete) then
            local _, x, y = QuestPOIGetIconInfo(q.id)
            if x and y then table.insert(positions, { x = x, y = y, complete = q.complete, suivie = q.suivie }) end
        end
    end
    SetCVar("questPOI", "0")
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
            local loin = distance + (p.complete and 0 or RAYON_ZONE * 0.3) > rayon
            -- Une quête non suivie ne montre sa zone que sur la mini-carte, jamais en point au bord.
            if p.suivie or not loin then
                n = n + 1
                local r = Repere(n)
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
    end
    for i = n + 1, #reperes do reperes[i]:Hide() end
end

local MajEpingles   -- plus bas (Épingles)

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
    MajEpingles(ecoule)
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

-- /solminicarte : ce qui est accroché à la mini-carte (nom, visibilité, texture), pour retirer un élément inconnu.
SLASH_SOLUIMINICARTE1 = "/solminicarte"
SlashCmdList.SOLUIMINICARTE = function()
    for _, parent in ipairs({ Minimap, MinimapCluster, MinimapBackdrop }) do
        for _, enfant in ipairs({ parent:GetChildren() }) do
            local texture
            for _, region in ipairs({ enfant:GetRegions() }) do
                if region:GetObjectType() == "Texture" and region:GetTexture() then texture = region:GetTexture(); break end
            end
            DEFAULT_CHAT_FRAME:AddMessage(string.format("%s > %s (%s, %s) %s", parent:GetName(), enfant:GetName() or "?",
                enfant:GetObjectType(), enfant:IsVisible() and "visible" or "caché", tostring(texture)))
        end
    end
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
-- Le jeu oublie les quêtes suivies à la déconnexion (constaté le 31/10/2026) : elles sont gardées par personnage dans
-- SolAzerothDB (l'addon SolAzeroth remplit S.QUETES_SUIVIES à la connexion), puis remises au premier relevé du journal.
local restaurees = false
local function Memoriser(liste)
    local suivies = S.QUETES_SUIVIES
    if not suivies or #liste == 0 then return end
    if not restaurees then
        restaurees = true
        local remises = false
        for _, q in ipairs(liste) do
            if not q.enTete and suivies[q.id] and not q.suivie and GetNumQuestWatches() < MAX_WATCHABLE_QUESTS then
                AddQuestWatch(q.index)
                remises = true
            end
        end
        if remises then S.MajQuetes(); return end
    end
    wipe(suivies)
    for _, q in ipairs(liste) do
        if q.suivie then suivies[q.id] = true end
    end
end

local enRetard = false
local relance = CreateFrame("Frame")
relance:Hide()
relance:SetScript("OnUpdate", function(self)
    self:Hide()
    enRetard = false
    local liste = Lire()
    Memoriser(liste)
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

------------------------------------------------------------------------
-- Quêtes à prendre, sur la carte du monde
------------------------------------------------------------------------
-- Le serveur (v3_carte.cpp) envoie les quêtes que le personnage peut accepter sur son continent, avec la position en
-- mètres du jeu de qui les donne, et qui reprend les quêtes du journal (« R »). Les deux sont dessinés en épingles
-- (plus bas), sur la carte du monde comme sur la mini-carte.
local disponibles, aRendre, recues = {}, {}, {}
local MajMarques, MajZonesMonde   -- plus bas (Épingles)

S.Message("SOLQDISPO", function(champs)
    if champs[1] == "DEBUT" then
        recues = { carte = tonumber(champs[2]), rendre = {} }
    elseif champs[1] == "R" then
        local id = tonumber(champs[2])
        table.insert(recues.rendre, { id = id, niveau = S.PuissanceQuete(id, tonumber(champs[3]) or 1),
            x = tonumber(champs[4]), y = tonumber(champs[5]), remplie = champs[6] == "1",
            titre = table.concat(champs, ";", 7) })
    elseif champs[1] == "Q" then
        local id = tonumber(champs[2])
        table.insert(recues, { id = id, niveau = S.PuissanceQuete(id, tonumber(champs[3]) or 1), x = tonumber(champs[4]),
            y = tonumber(champs[5]), titre = table.concat(champs, ";", 6) })
    elseif champs[1] == "FIN" then
        disponibles, aRendre = recues, recues.rendre
        if WorldMapFrame:IsShown() then MajMarques() end
    end
end)
S.Ecouter("WORLD_MAP_UPDATE", function() if WorldMapFrame:IsShown() then MajMarques() end end)

------------------------------------------------------------------------
-- Épingles : mini-carte et carte du monde (01/11/2026, demandes de l'utilisateur, maquette « Épingle »)
------------------------------------------------------------------------
-- Les marques du jeu sur la mini-carte disparaissent : « ! » et « ? » des donneurs (cases effacées de
-- Interface\Minimap\ObjectIcons.blp par outils\minicarte_v3.py), zones et flèche d'objectif (option questPOI coupée,
-- ici comme sur la carte du monde, qui a ses propres zones). À leur place, une épingle par donneur, dont la pointe
-- vise le PNJ, sur la mini-carte comme sur la carte du monde :
--   « ! » ambre : quête à prendre ; « ! » gris : facile (puissance de la quête 6 sous la tienne ou plus) ;
--   « ? » pleine ambre : objectifs remplis, à rendre ; « ? » grise : quête en cours, le donneur attend ;
--   « ? » bleu : défi contre la montre à prendre, comme les quêtes à refaire du jeu (signalement du 01/11/2026) ;
--   « ! » bleu : autre quête à refaire (journalière ou répétable, bleue dans le jeu) à prendre ; « ? » pleine bleue :
--   quête à refaire à rendre (signalement du 01/11/2026 : les fétiches de Zalazane, devenus journaliers).
-- Hors de la mini-carte : collée au bord, plus petite et un peu pâle, avec une flèche vers l'extérieur (quêtes à rendre
-- toujours ; quêtes à prendre jusqu'à PORTEE mètres). Survol : les quêtes à cet endroit et des épingles voisines.
-- Les zones d'objectif des quêtes suivies (plus haut) restent.
local PORTEE = 500
local GRIS = { 0.420, 0.439, 0.475 }   -- #6b7079
local ETATS = {   -- ordre de priorité quand un PNJ a plusieurs quêtes
    { genre = "rendre", signe = "?", bord = { S.Couleur("ambreClair") }, fond = { S.Couleur("ambre") },
        signeCouleur = { S.Couleur("fond") }, texte = "objectifs remplis · à rendre", couleur = "vertClair" },
    { genre = "rendreBleue", signe = "?", bord = { S.Couleur("bleu") }, fond = { S.Couleur("bleu") },
        signeCouleur = { S.Couleur("fond") }, texte = "à refaire · objectifs remplis · à rendre", couleur = "vertClair" },
    { genre = "dispo", signe = "!", bord = { S.Couleur("ambre") }, fond = { S.Couleur("fond") },
        signeCouleur = { S.Couleur("ambreClair") }, texte = "à prendre", couleur = "ambreClair" },
    { genre = "bleue", signe = "!", bord = { S.Couleur("bleu") }, fond = { S.Couleur("fond") },
        signeCouleur = { S.Couleur("bleu") }, texte = "à refaire · à prendre", couleur = "bleu" },
    { genre = "defi", signe = "?", bord = { S.Couleur("bleu") }, fond = { S.Couleur("fond") },
        signeCouleur = { S.Couleur("bleu") }, texte = "défi contre la montre · à prendre", couleur = "bleu" },
    { genre = "encours", signe = "?", bord = GRIS, fond = { S.Couleur("fond") },
        signeCouleur = { S.Couleur("gris") }, texte = "en cours", couleur = "gris" },
    { genre = "facile", signe = "!", bord = GRIS, fond = { S.Couleur("fond") },
        signeCouleur = { S.Couleur("gris") }, texte = "facile · à prendre", couleur = "gris" },
}
local RANG = {}
for n, e in ipairs(ETATS) do RANG[e.genre] = n end

local epingles, groupes = {}, {}   -- mini-carte
local marques = {}                  -- carte du monde
local carteGroupes, recuesGroupes

-- Tourne une texture d'un angle (radians, sens inverse des aiguilles) autour de son centre.
local function Tourner(t, a)
    local c, s = math.cos(a), math.sin(a)
    local function P(x, y) return 0.5 + (x - 0.5) * c - (y - 0.5) * s, 0.5 + (x - 0.5) * s + (y - 0.5) * c end
    local hgx, hgy = P(0, 0)
    local bgx, bgy = P(0, 1)
    local hdx, hdy = P(1, 0)
    local bdx, bdy = P(1, 1)
    t:SetTexCoord(hgx, hgy, bgx, bgy, hdx, hdy, bdx, bdy)
end

-- Infobulle : les quêtes de cette épingle et des épingles voisines de la même carte.
local function InfobulleEpingle(self)
    local bulle = self.bulle
    bulle:SetOwner(self, "ANCHOR_LEFT")
    local x, y = self:GetCenter()
    local premier = true
    for _, e in ipairs(self.liste) do
        local ex, ey = e:GetCenter()
        if e:IsShown() and ex and math.abs(ex - x) < 14 and math.abs(ey - y) < 14 then
            for _, q in ipairs(e.quetes) do
                local etat = ETATS[RANG[q.genre]]
                if not premier then bulle:AddLine(" ") end
                premier = false
                bulle:AddLine(q.titre, S.Couleur("texte"))
                local puissance = q.niveau and q.niveau > 0 and ("Puissance " .. q.niveau .. " · ") or ""
                bulle:AddLine(puissance .. etat.texte, S.Couleur(etat.couleur))
            end
        end
    end
    bulle:Show()
end

local function Epingle(liste, n, parent, bulle)
    if liste[n] then return liste[n] end
    local e = CreateFrame("Frame", nil, parent)
    e:SetFrameLevel(parent:GetFrameLevel() + 5)
    e:EnableMouse(true)
    e.ombre = S.Texture(e, "BACKGROUND", "EpingleOmbre", 0, 0, 0, 0.6)
    e.ombre:SetPoint("TOPLEFT", 0, -1)
    e.ombre:SetPoint("BOTTOMRIGHT", 0, -1)
    e.bord = S.Texture(e, "BORDER", "Epingle", 1, 1, 1)
    e.bord:SetAllPoints()
    e.fond = S.Texture(e, "ARTWORK", "EpingleCreux", 1, 1, 1)
    e.fond:SetAllPoints()
    e.signe = S.Texte(e, "Bold", 10, "texte")
    e.signe:SetShadowOffset(0, 0)
    e.fleche = S.Texture(e, "OVERLAY", "Fleche", S.Couleur("ambre"))
    e.fleche:SetSize(10, 10)
    e.fleche:Hide()
    e.liste, e.bulle = liste, bulle
    e:SetScript("OnEnter", InfobulleEpingle)
    e:SetScript("OnLeave", function() bulle:Hide() end)
    liste[n] = e
    return e
end

-- Dessin d'une épingle de « cote » de côté (texture carrée : l'épingle en occupe 80 % de large).
local function Habiller(e, g, cote)
    local etat = ETATS[RANG[g.genre]]
    e:SetSize(cote, cote)
    e.bord:SetVertexColor(unpack(etat.bord))
    e.fond:SetVertexColor(unpack(etat.fond))
    S.Police(e.signe, "Bold", math.floor(cote * 0.5 + 0.5))
    e.signe:SetText(etat.signe)
    e.signe:SetTextColor(unpack(etat.signeCouleur))
    e.signe:ClearAllPoints()
    e.signe:SetPoint("CENTER", e, "TOP", 0.5, -cote * 0.4)   -- centre du rond (25,6 / 64)
    e.quetes = g.quetes
    e:ClearAllPoints()
end

-- Donneurs et finisseurs regroupés par position, en coordonnées de la carte « nom » (de 0 à 1, parfois au-delà).
local function Grouper(nom, liste)
    wipe(liste)
    local carte = S.CARTES and S.CARTES[nom or ""]
    if not carte or carte[5] ~= disponibles.carte then return liste end
    local index = {}
    local function Ajouter(q, genre)
        local cle = q.x .. ":" .. q.y
        local g = index[cle]
        if not g then
            g = { x = (carte[3] - q.y) / carte[1], y = (carte[4] - q.x) / carte[2], quetes = {} }
            index[cle] = g
            table.insert(liste, g)
        end
        table.insert(g.quetes, { titre = q.titre, niveau = q.niveau, genre = genre })
        if not g.genre or RANG[genre] < RANG[g.genre] then g.genre = genre end
    end
    local puissance = S.etat and S.etat.puissance
    for _, q in ipairs(disponibles) do
        local annexe = S.ANNEXES and S.ANNEXES[q.id]
        Ajouter(q, annexe and annexe.chrono and "defi" or annexe and annexe.bleue and "bleue"
            or (puissance and q.niveau and q.niveau <= puissance - 6) and "facile" or "dispo")
    end
    for _, q in ipairs(aRendre) do
        local annexe = S.ANNEXES and S.ANNEXES[q.id]
        Ajouter(q, q.remplie and (annexe and annexe.bleue and "rendreBleue" or "rendre") or "encours")
    end
    for _, g in ipairs(liste) do
        table.sort(g.quetes, function(a, b) return RANG[a.genre] < RANG[b.genre] end)
    end
    return liste
end

-- Épingles qui se chevauchent (PNJ côte à côte, signalement du 01/11/2026) : seule la plus importante reste, son
-- infobulle reprend les quêtes des autres. « places » : { g, x, y (pointe, en pixels), cote, rang }.
local function Fusionner(places)
    table.sort(places, function(a, b)
        if RANG[a.g.genre] ~= RANG[b.g.genre] then return RANG[a.g.genre] < RANG[b.g.genre] end
        return a.rang < b.rang
    end)
    local gardees = {}
    for _, p in ipairs(places) do
        local hote
        for _, h in ipairs(gardees) do
            if math.abs(h.x - p.x) < h.cote * 0.7 and math.abs(h.y - p.y) < h.cote * 0.7 then hote = h; break end
        end
        if not hote then
            hote, p.quetes = p, {}
            table.insert(gardees, p)
        end
        for _, q in ipairs(p.g.quetes) do table.insert(hote.quetes, q) end
    end
    for _, h in ipairs(gardees) do
        table.sort(h.quetes, function(a, b) return RANG[a.genre] < RANG[b.genre] end)
    end
    return gardees
end

-- Reliques (01/11/2026, demande de l'utilisateur) : avec la carte des reliques achetée, un coffre marque chaque relique
-- pas encore trouvée, sur la mini-carte (à portée) et sur la carte du monde. Survol : son indice.
-- Primes (01/11/2026, demande de l'utilisateur) : une tête de mort marque la cible de chaque prime du journal pas
-- encore remplie, de la même façon. Survol : la prime et son résumé.
local COFFRE = "Interface\\WorldMap\\TreasureChest_64"
local CRANE = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8"
local signesMini, signesMonde = {}, {}
local function Signe(liste, n, parent, bulle)
    if liste[n] then return liste[n] end
    local c = CreateFrame("Frame", nil, parent)
    c:SetFrameLevel(parent:GetFrameLevel() + 4)
    c:EnableMouse(true)
    c.icone = c:CreateTexture(nil, "ARTWORK")
    c.icone:SetAllPoints()
    c:SetScript("OnEnter", function(self)
        bulle:SetOwner(self, "ANCHOR_LEFT")
        bulle:AddLine(self.signe.titre, S.Couleur(self.signe.couleur))
        local r, g, b = S.Couleur("texte")
        bulle:AddLine(self.signe.texte, r, g, b, true)
        bulle:Show()
    end)
    c:SetScript("OnLeave", function() bulle:Hide() end)
    liste[n] = c
    return c
end

-- Signes à poser sur la carte « nom » : { x, y (de 0 à 1), texture, titre, couleur, texte }.
local function SignesSur(nom)
    local progres, carte = S.progresZone, S.CARTES and S.CARTES[nom or ""]
    local liste = {}
    if not carte or carte[5] ~= disponibles.carte then return liste end
    local function Ajouter(x, y, texture, titre, couleur, texte)
        table.insert(liste, { x = (carte[3] - y) / carte[1], y = (carte[4] - x) / carte[2], texture = texture,
            titre = titre, couleur = couleur, texte = texte })
    end
    if progres and progres.carte then
        for _, r in ipairs(S.RELIQUES or {}) do
            if not progres.reliques[r.objet] then
                Ajouter(r.x, r.y, COFFRE, "Relique cachée (" .. r.cle .. ")", "ambreClair", "« " .. r.indice .. " »")
            end
        end
    end
    for id in pairs(primes) do
        local a = S.ANNEXES[id]
        Ajouter(a.cible[1], a.cible[2], CRANE, "Prime : " .. a.titre, "rougeClair", a.resume)
    end
    return liste
end

local attenteEpingles = 0
MajEpingles = function(ecoule)
    attenteEpingles = attenteEpingles - ecoule
    if attenteEpingles > 0 then return end
    attenteEpingles = 0.05
    if carteGroupes ~= cartePositions or recuesGroupes ~= disponibles then
        carteGroupes, recuesGroupes = cartePositions, disponibles
        Grouper(cartePositions, groupes)
    end
    local carte = S.CARTES and S.CARTES[cartePositions or ""]
    local px, py = GetPlayerMapPosition("player")
    local n, k = 0, 0
    if carte and px and not WorldMapFrame:IsShown() and GetMapInfo() == cartePositions and (px > 0 or py > 0) then
        local zoom = Minimap:GetZoom() + 1
        local rayon = (IsIndoors() and DIAMETRE.dedans or DIAMETRE.dehors)[zoom] / 2
        local pixels = Minimap:GetWidth() / 2
        local echelle = pixels / rayon
        local angle = GetCVar("rotateMinimap") == "1" and GetPlayerFacing() or 0
        local c, s = math.cos(angle), math.sin(angle)
        local m = S.OPTIONS.reperes
        local r = pixels - 6 * m
        local places = {}
        for rang, g in ipairs(groupes) do
            local dx, dy = (g.x - px) * carte[1], (g.y - py) * carte[2]
            dx, dy = dx * c - dy * s, dx * s + dy * c
            local distance = math.sqrt(dx * dx + dy * dy)
            local loin = distance * echelle > pixels - 10 * m
            if not loin or g.genre == "rendre" or g.genre == "rendreBleue"
                or ((g.genre == "dispo" or g.genre == "bleue" or g.genre == "defi") and distance <= PORTEE) then
                local p = { g = g, rang = rang, loin = loin, cote = (loin and 15 or 20) * m }
                if loin then
                    p.ox, p.oy = dx / distance, -dy / distance
                    p.x, p.y = p.ox * (r - 9 * m), p.oy * (r - 9 * m)
                else
                    p.x, p.y = dx * echelle, -dy * echelle
                end
                table.insert(places, p)
            end
        end
        for _, p in ipairs(Fusionner(places)) do
            n = n + 1
            local e = Epingle(epingles, n, Minimap, GameTooltip)
            Habiller(e, p.g, p.cote)
            e.quetes = p.quetes
            if p.loin then
                e:SetPoint("CENTER", Minimap, "CENTER", p.x, p.y)
                e.fleche:ClearAllPoints()
                e.fleche:SetPoint("CENTER", Minimap, "CENTER", p.ox * r, p.oy * r)
                Tourner(e.fleche, math.atan2(p.oy, p.ox))
                e.fleche:Show()
                e:SetAlpha(0.85)
            else
                -- La pointe (à 4 % du bas de la texture) vise le PNJ.
                e:SetPoint("BOTTOM", Minimap, "CENTER", p.x, p.y - p.cote * 0.04)
                e.fleche:Hide()
                e:SetAlpha(1)
            end
            e:Show()
        end
        for _, q in ipairs(SignesSur(cartePositions)) do
            local dx, dy = (q.x - px) * carte[1], (q.y - py) * carte[2]
            dx, dy = dx * c - dy * s, dx * s + dy * c
            if math.sqrt(dx * dx + dy * dy) * echelle <= pixels - 8 * m then
                k = k + 1
                local f = Signe(signesMini, k, Minimap, GameTooltip)
                f.signe = q
                f.icone:SetTexture(q.texture)
                f:SetSize(14 * m, 14 * m)
                f:ClearAllPoints()
                f:SetPoint("CENTER", Minimap, "CENTER", dx * echelle, -dy * echelle)
                f:Show()
            end
        end
    end
    for i = n + 1, #epingles do epingles[i]:Hide() end
    for i = k + 1, #signesMini do signesMini[i]:Hide() end
end
S.Abonner("puissance", function() carteGroupes = nil end)

-- Carte du monde : les mêmes épingles, sur la carte affichée (celle du continent du joueur), un peu plus grandes.
local groupesMonde = {}
MajMarques = function()
    local largeur, hauteur = WorldMapButton:GetWidth(), WorldMapButton:GetHeight()
    local n = 0
    local cote = 24 * S.OPTIONS.reperes
    local places = {}
    for rang, g in ipairs(Grouper(GetMapInfo(), groupesMonde)) do
        if g.x >= 0 and g.x <= 1 and g.y >= 0 and g.y <= 1 then
            table.insert(places, { g = g, rang = rang, cote = cote, x = g.x * largeur, y = -g.y * hauteur })
        end
    end
    for _, p in ipairs(Fusionner(places)) do
        n = n + 1
        local e = Epingle(marques, n, WorldMapButton, WorldMapTooltip)
        Habiller(e, p.g, cote)
        e.quetes = p.quetes
        e:SetPoint("BOTTOM", WorldMapButton, "TOPLEFT", p.x, p.y - cote * 0.04)
        e:Show()
    end
    for i = n + 1, #marques do marques[i]:Hide() end
    local k = 0
    for _, c in ipairs(SignesSur(GetMapInfo())) do
        if c.x >= 0 and c.x <= 1 and c.y >= 0 and c.y <= 1 then
            k = k + 1
            local f = Signe(signesMonde, k, WorldMapButton, WorldMapTooltip)
            f.signe = c
            f.icone:SetTexture(c.texture)
            f:SetSize(18 * S.OPTIONS.reperes, 18 * S.OPTIONS.reperes)
            f:ClearAllPoints()
            f:SetPoint("CENTER", WorldMapButton, "TOPLEFT", c.x * largeur, -c.y * hauteur)
            f:Show()
        end
    end
    for i = k + 1, #signesMonde do signesMonde[i]:Hide() end
    MajZonesMonde()
end

-- Zones d'objectif sur la carte du monde (01/11/2026, demande de l'utilisateur) : comme sur la mini-carte, un rond
-- ambre à l'échelle du terrain (RAYON_ZONE) et son point, pour chaque quête du journal pas encore remplie (une quête
-- remplie a son épingle « ? » chez qui la reprend). Survol : la quête et ses objectifs. Les marques du jeu (zones et
-- numéros) restent coupées : l'option questPOI n'est remise que le temps de lire les positions.
local zonesMonde = {}
local function ZoneMonde(n)
    if zonesMonde[n] then return zonesMonde[n] end
    local z = CreateFrame("Frame", nil, WorldMapButton)
    z:SetFrameLevel(WorldMapButton:GetFrameLevel() + 3)
    z:EnableMouse(true)
    z.zone = S.Texture(z, "ARTWORK", "Rond", S.Couleur("ambre", 0.22))
    z.zone:SetAllPoints()
    z.bord = S.Texture(z, "OVERLAY", "Anneau", S.Couleur("ambre", 0.9))
    z.bord:SetAllPoints()
    z.point = S.Texture(z, "OVERLAY", "Rond", S.Couleur("ambreClair"))
    z.point:SetSize(8, 8)
    z.point:SetPoint("CENTER")
    z:SetScript("OnEnter", function(self)
        WorldMapTooltip:SetOwner(self, "ANCHOR_RIGHT")
        WorldMapTooltip:AddLine(S.TitreQuete(self.quete), S.Couleur("ambreClair"))
        for _, o in ipairs(Objectifs(self.quete.index)) do
            WorldMapTooltip:AddLine((o.compte and (o.compte .. "  ") or "") .. o.texte,
                S.Couleur(o.fini and "vertClair" or "texte"))
        end
        WorldMapTooltip:Show()
    end)
    z:SetScript("OnLeave", function() WorldMapTooltip:Hide() end)
    zonesMonde[n] = z
    return z
end

local lectureMonde = false
MajZonesMonde = function()
    if lectureMonde then return end
    lectureMonde = true
    local carte = S.CARTES and S.CARTES[GetMapInfo() or ""]
    local largeur, hauteur = WorldMapButton:GetWidth(), WorldMapButton:GetHeight()
    local n = 0
    if carte then
        SetCVar("questPOI", "1")
        -- La carte du monde a ses propres données de quête, à mettre à jour avant de les lire (comme le fait le jeu).
        if QuestMapUpdateAllQuests then QuestMapUpdateAllQuests() end
        QuestPOIUpdateIcons()
        for _, q in ipairs(Lire()) do
            if not q.enTete and q.id and not q.complete then
                local _, x, y = QuestPOIGetIconInfo(q.id)
                if x and y and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
                    n = n + 1
                    local z = ZoneMonde(n)
                    z.quete = q
                    local taille = math.max(12, 2 * RAYON_ZONE / carte[1] * largeur)
                    z:SetSize(taille, taille)
                    z:ClearAllPoints()
                    z:SetPoint("CENTER", WorldMapButton, "TOPLEFT", x * largeur, -y * hauteur)
                    z:Show()
                end
            end
        end
        SetCVar("questPOI", "0")
    end
    for i = n + 1, #zonesMonde do zonesMonde[i]:Hide() end
    lectureMonde = false
end

-- Marques de quête du jeu coupées partout (mini-carte et carte du monde) : nos zones et nos épingles les remplacent.
if Minimap.SetPOIArrowTexture then Minimap:SetPOIArrowTexture(S.MEDIA .. "Textures\\Vide") end
local surMonde = WorldMapFrame:GetScript("OnShow")
WorldMapFrame:SetScript("OnShow", function(...)
    SetCVar("questPOI", "0")
    if surMonde then surMonde(...) end
    MajMarques()
end)
S.Ecouter("PLAYER_ENTERING_WORLD", function() SetCVar("questPOI", "0") end)
