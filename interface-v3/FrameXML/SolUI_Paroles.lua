-- Sol'Azeroth v3, audit du jeu, lot 6a (02/11/2026, C9 ; choix de l'utilisateur : « répliques des PNJ », dans « une
-- fenêtre dédiée […] comme sur retail quand un PNJ parle […] un bouton pour passer à la réplique suivante et pour
-- fermer quand on n'est pas intéressé ») : la vallée enseigne en jouant.
-- - Fenêtre de paroles : portrait du PNJ, son nom, une réplique ; « Suivant » (« Terminer » à la dernière) et
--   « Fermer ». Hors combat, une leçon à la fois, les suivantes attendent.
-- - Leçons : elles prennent la place des fenêtres « À savoir » (SolUI_Lexique.lua) des moments clés qu'elles couvrent.
--   S.Expliquer(clé) joue la leçon de cette clé si elle n'a pas été vue, et marque vues toutes ses clés ; fermée ou
--   finie, une leçon ne revient pas (S.VUS, « parole_… », une fois par compte). Les pages restent dans le Lexique.
-- - Lot 6b (02/11/2026, C8) : scènes au rendu des quêtes clés (« SCENE;quête », préfixe SOLPAROLE, v3_paroles.cpp).
--   Une réplique peut changer d'orateur : { PNJ, nom, texte }. Accord au genre du joueur : « {masculin|féminin} ».
-- - Lot D5 (02/11/2026) : une réplique propre à la classe s'écrit { WARRIOR = texte, WARLOCK = texte } (le guerrier
--   par défaut). Lot V5 : ROGUE aussi.

local S = SolUI

-- { clé, PNJ (entrée), nom, { clés couvertes }, { répliques } }
local LECONS = {
    { "arrivee", 10176, "Kaltunk", { "puissance", "zone" }, {
        "Bienvenue dans la Vallée des épreuves, recrue. Ici, pas de niveau : ta force, c'est ta puissance, la moyenne de ce que tu portes.",
        "Chaque monstre a la sienne. Plus fort que toi, il encaisse mieux : regarde sa puissance avant de charger.",
        "Ton équipement, tu le fabriqueras toi-même avec ce que tu récoltes. Tout est dans tes carnets : Personnage (C), Techniques (K), Artisanat (P), Collection (B), Aventure (L), Camp (N).",
        "La vallée se complète : l'histoire, l'exploration, les annexes. Le suivi de zone te dit où tu en es ; un clic dessus, et tu vois ce qu'il reste à faire.",
        "Va voir Gornek dans l'Antre. Et si tu oublies quelque chose, le Lexique (J) garde tout.",
    } },
    { "marques", 10176, "Kaltunk", { "marques", "or" }, {
        "Une Marque du voyageur ! C'est la monnaie de l'effort : primes, contrats, défis et reliques en donnent.",
        "Elle paie ton camp, les passifs et, plus tard, tes montures. Elle va dans le sac : garde-lui de la place.",
        "L'or, lui, vient des quêtes. Il paie la fabrication, les rangs et les réparations.",
    } },
    { "regles", 3143, "Gornek", { "regles", "rempart" }, {
        "Pas mal, pour un premier combat. Écoute bien, je ne le répéterai pas.",
        { WARRIOR = "Ni rage ni mana : tes techniques n'ont qu'un temps de recharge. Et elles exigent ton bouclier, garde-le au bras.",
          WARLOCK = "Ni rage ni mana : tes sorts n'ont qu'un temps de recharge. Incante à l'arrêt ; les sorts instantanés, eux, se lancent en courant.",
          ROGUE = "Ni énergie ni points de combo : tes techniques n'ont qu'un temps de recharge. Et elles exigent tes deux dagues, une dans chaque main." },
        "Ici, tout coup porte : ni raté, ni esquive, ni parade. L'armure retire un montant fixe à chaque coup, alors les petits coups ne passent presque plus.",
        { WARRIOR = "Ton Rempart verse une part de chaque coup encaissé dans un bouclier qui absorbe les suivants. Riposte du rempart et Second souffle le dépensent.",
          WARLOCK = "Ta Moisson te rend en vie une part des dégâts de tes maléfices. Et ton arme ne frappe pas : ses dégâts nourrissent la puissance de tes sorts.",
          ROGUE = "Tes Toxines empoisonnent la cible coup après coup ; chaque cumul l'affaiblit. Envenimer les consomme d'un coup : attends-en cinq." },
        "À droite de tes techniques : ta potion, ton feu de camp et ta pierre de foyer. La potion, c'est en combat qu'elle sert, n'attends pas d'être à terre.",
    } },
    { "survie", 3145, "Zureetha Mireloin", { "regeneration", "camp", "potion" }, {
        { WARRIOR = "Tu saignes, {jeune guerrier|jeune guerrière}. Hors combat, ta vie remonte seule : 2 % par seconde. Ni nourriture, ni bandages.",
          WARLOCK = "Tu saignes, jeune démoniste. Hors combat, ta vie remonte seule : 2 % par seconde. Ni nourriture, ni bandages.",
          ROGUE = "Tu saignes, {jeune voleur|jeune voleuse}. Hors combat, ta vie remonte seule : 2 % par seconde. Ni nourriture, ni bandages." },
        "En combat, ta potion rend 30 % de ta vie. Une seule charge au départ : elle revient au Repos au coin du feu, en auberge ou en ville.",
        "Après une rude bataille, pose ton feu de camp et assieds-toi. Une minute assis, et tu repars avec le Repos au coin du feu : plus de vie, et toutes tes charges.",
    } },
    { "eclats", 3143, "Gornek", { "eclats", "rangs" }, {
        "Ces éclats cadavériques, garde-les. Ce ne sont pas ceux des enchanteurs : ceux-là sont à toi.",
        "Ils montent tes pièces de rang : +10 % par rang, jusqu'au rang 5. Artisanat, onglet Amélioration, hors combat.",
        "Ils rachètent aussi ton âme et améliorent ton camp. Les monstres plus puissants en lâchent davantage.",
    } },
    { "recolte", 11378, "Contremaître Thazz'ril", { "recolte", "collection" }, {
        "Pas besoin de pioche, ni de métier : herbes, filons et cuir se récoltent d'office.",
        "Tout part dans ta Collection, même sac plein, sans limite. Ouvre-la avec B.",
        "Avec ça, tu forges ton équipement. Il y a une forge et une enclume ici même, dans la vallée.",
    } },
    { "fabrication", 11378, "Contremaître Thazz'ril", { "fabrication" }, {
        "Une forge ! Maille, boucliers et armes se fabriquent près d'une forge ou d'une enclume. Le reste, n'importe où.",
        "Artisanat (P), onglet Fabrication : les composants viennent de ta Collection, plus un peu d'or. Reste immobile le temps du travail.",
        "Chaque pièce prend une variante à la fabrication : Critique, Hâte ou Vol de vie. Choisis avant de frapper l'enclume.",
    } },
    { "cuisine", 9796, "Galgar", { "cuisine" }, {
        "Ça sent bon, ce feu ! Près d'un feu, le tien compris, on cuisine : Artisanat, onglet Fabrication, catégorie Cuisine.",
        "Un plat te donne ta caractéristique pendant 30 minutes, plus un petit bonus à lui. Un seul repas à la fois.",
        "Les ingrédients viennent des bêtes de la zone, d'une herbe et d'un assaisonnement de marchand. Plus l'ingrédient est rare, meilleur est le plat.",
    } },
    { "mort", 3287, "Hana'zua", { "mort" }, {
        "Toi aussi, tu es {tombé|tombée}… Ici, la mort ne prend ni objet ni usure. Libère ton esprit : tu reviens à ta pierre de foyer, vie pleine.",
        "Mais chaque mort coûte de l'âme. Une âme à zéro, et c'en est fini du personnage.",
        "L'âme se rachète en auberge ou en ville, avec des éclats : Personnage, onglet Âme.",
    } },
}
-- Scènes, par quête rendue : { clé, PNJ, nom, {}, { répliques } }.
local GORNEK, ZUREETHA, GARTHOK, ORGNIL, RUGA = { 3143, "Gornek" }, { 3145, "Zureetha Mireloin" }, { 3139, "Gar'Thok" },
    { 3142, "Orgnil Marque-l'âme" }, { 910001, "Ruga Brise-cendre" }
local function R(qui, texte) return { qui[1], qui[2], texte } end
local SCENES = {
    [910007] = { "scene_yarrog", ZUREETHA[1], ZUREETHA[2], {}, {
        R(ZUREETHA, "Gornek doit savoir. Gornek ! Viens voir ce que la recrue a trouvé sur Yarrog."),
        R(GORNEK, "La Lame ardente… si près de nos recrues. J'aurais dû le sentir venir."),
        R(GORNEK, "Tu as fait ton travail, recrue. Porte ce médaillon à Orgnil, à Tranchecolline : il traque ce culte depuis des années."),
        R(ZUREETHA, "Mais avant de partir, finis ce qu'il reste à faire ici. Ce qu'on laisse derrière soi finit toujours par nous rattraper."),
    } },
    [910012] = { "scene_benedict", GARTHOK[1], GARTHOK[2], {}, {
        R(GARTHOK, "Des sorciers qui paient des humains pour nous frapper… Ce n'est plus une rumeur. C'est une guerre cachée."),
        R(ORGNIL, "Laisse-moi lire. Les souterrains d'Orgrimmar… Ils veulent nous frapper par en dessous, là où personne ne regarde."),
        R(GARTHOK, "Alors on frappe d'abord. Équipe-toi, recrue : Tiragarde n'était qu'un avant-goût."),
    } },
    [910030] = { "scene_taragaman", ORGNIL[1], ORGNIL[2], {}, {
        R(ORGNIL, "Le Gouffre est purgé. Mais une lame brisée se reforge : ceux-là n'étaient qu'une branche."),
        R(RUGA, "La faille est calme, pour la première fois depuis des lunes. Je garderai l'entrée. Toi, tu as mieux à faire."),
        R(ORGNIL, "Durotar te doit beaucoup. Quand tu seras {prêt|prête}, d'autres terres auront besoin de toi."),
    } },
}

local PAR_CLE = {}
for _, l in ipairs(LECONS) do
    for _, cle in ipairs(l[4]) do PAR_CLE[cle] = PAR_CLE[cle] or l end
end

------------------------------------------------------------------------
-- Fenêtre de paroles
------------------------------------------------------------------------
local h = CreateFrame("Frame", "SolUIParoles", S.racine)
h:SetSize(600, 150)
h:SetPoint("BOTTOM", S.racine, "BOTTOM", 0, 210)
h:SetFrameStrata("HIGH")
h:EnableMouse(true)
S.Panneau(h, 0.96, "ambre")
h:Hide()

local cadre = CreateFrame("Frame", nil, h)
cadre:SetSize(118, 118)
cadre:SetPoint("LEFT", 16, 0)
S.Panneau(cadre, 1)
local repli = cadre:CreateTexture(nil, "ARTWORK")
repli:SetPoint("TOPLEFT", 1, -1)
repli:SetPoint("BOTTOMRIGHT", -1, 1)
repli:SetTexture("Interface\\Icons\\INV_Misc_GroupNeedMore")
repli:SetTexCoord(0.08, 0.92, 0.08, 0.92)
repli:SetAlpha(0.35)
local portrait = CreateFrame("PlayerModel", nil, cadre)
portrait:SetPoint("TOPLEFT", 1, -1)
portrait:SetPoint("BOTTOMRIGHT", -1, 1)

local nom = S.Texte(h, "Bold", 16, "ambreClair")
nom:SetPoint("TOPLEFT", cadre, "TOPRIGHT", 16, -4)
local page = S.Texte(h, "Regular", 11, "gris")
page:SetPoint("TOPRIGHT", h, "TOPRIGHT", -18, -18)
local replique = S.Texte(h, "Regular", 14, "texte")
replique:SetPoint("TOPLEFT", nom, "BOTTOMLEFT", 0, -8)
replique:SetWidth(430)
replique:SetJustifyH("LEFT")
replique:SetSpacing(2)
local suivant = S.BoutonPlat(h, "Suivant", 120, 28, 12)
suivant:SetPoint("BOTTOMRIGHT", -16, 14)
local fermer = S.BoutonPlat(h, "Fermer", 100, 28, 12)
fermer:SetPoint("RIGHT", suivant, "LEFT", -8, 0)

local file, lecon, n = {}, nil, 1
local orateur
local function Orateur(entree, texte)
    nom:SetText(texte)
    if entree ~= orateur and portrait.SetCreature then
        portrait:ClearModel()
        portrait:SetCreature(entree)
        portrait:SetCamera(0)
    end
    orateur = entree
end

local function Accorder(texte)
    local feminin = UnitSex("player") == 3
    return (texte:gsub("{([^|}]*)|([^}]*)}", function(m, f) return feminin and f or m end))
end

local function Afficher()
    local l = lecon[5][n]
    if type(l) == "table" and not l[1] then
        l = l[select(2, UnitClass("player"))] or l.WARRIOR
    end
    if type(l) == "table" then
        Orateur(l[1], l[2])
        replique:SetText(Accorder(l[3]))
    else
        Orateur(lecon[2], lecon[3])
        replique:SetText(Accorder(l))
    end
    page:SetText(n .. " / " .. #lecon[5])
    suivant.texte:SetText(n < #lecon[5] and "Suivant" or "Terminer")
end

local function Prochaine()
    if h:IsShown() or #file == 0 or InCombatLockdown() or UnitIsDeadOrGhost("player") then return end
    lecon, n, orateur = table.remove(file, 1), 1, nil
    Afficher()
    h:Show()
    PlaySound("igQuestListOpen")
end

suivant:SetScript("OnClick", function()
    if n < #lecon[5] then
        n = n + 1
        Afficher()
    else
        h:Hide()
        Prochaine()
    end
end)
fermer:SetScript("OnClick", function()
    h:Hide()
    PlaySound("igQuestListClose")
    Prochaine()
end)

-- Leçon d'une clé : jouée une fois ; ses clés ne donnent plus de fenêtre « À savoir ».
local function Lecon(l)
    if S.VUS["parole_" .. l[1]] then return false end
    S.VUS["parole_" .. l[1]] = true
    for _, cle in ipairs(l[4]) do S.VUS[cle] = true end
    if S.Enregistrer then S.Enregistrer() end
    table.insert(file, l)
    Prochaine()
    return true
end

local Expliquer = S.Expliquer
function S.Expliquer(cle)
    local l = PAR_CLE[cle]
    if l and not S.VUS[cle] and Lecon(l) then return end
    Expliquer(cle)
end

S.Ecouter("PLAYER_REGEN_ENABLED", function()
    S.Expliquer("regles")   -- fin du premier combat
    Prochaine()
end)
S.Ecouter("PLAYER_UNGHOST", Prochaine)
S.Ecouter("PLAYER_ALIVE", Prochaine)
-- Près d'un feu (« FORGE;forge;feu ») : la cuisine.
S.Message("SOLEQUIP", function(champs)
    if champs[1] == "FORGE" and champs[3] == "1" then S.Expliquer("cuisine") end
end)
-- Scène au rendu d'une quête clé (elle attend la fin du combat).
S.Message("SOLPAROLE", function(champs)
    local scene = champs[1] == "SCENE" and SCENES[tonumber(champs[2])]
    if scene then
        table.insert(file, scene)
        Prochaine()
    end
end)
