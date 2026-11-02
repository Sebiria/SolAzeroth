-- Sol'Azeroth v3 (01/11/2026, demande de l'utilisateur : « beaucoup d'information qu'on ne peut pas deviner […] une
-- fenêtre qui pop et qui explique […] de façon très concise, avec la possibilité de regarder une sorte de lexique […]
-- un concept égale une page/onglet ») : le lexique et les fenêtres d'explication.
-- - Lexique : le carnet du même nom (SolUI_Carnets.lua), un onglet par thème, une page par concept. Les chiffres
--   viennent du serveur (relevé du 01/11/2026 dans mod-solazeroth) : à tenir à jour avec lui.
-- - Explications : au premier passage d'un moment clé (premier éclat, première prime prise, première mort…), une
--   petite fenêtre résume le concept et mène à sa page. Hors combat seulement, une à la fois, une seule fois par
--   compte (S.VUS, gardé avec la disposition par l'addon SolAzeroth : SolUI_Reglages.lua).
-- - Lot 6a (02/11/2026, C9) : pages Règles du combat, Rempart, Cuisine, Pierre de foyer, Montures et Mots du jeu ;
--   les leçons des PNJ (SolUI_Paroles.lua) remplacent les explications des moments qu'elles couvrent ; vie à 80 %.

local S = SolUI

local A, G, F = "|cfff6c27a", "|cffb4b8bf", "|r"
local function T(titre) return A .. titre .. F .. "\n" end

-- { nom du thème, { { clé, nom, résumé de la fenêtre d'explication, texte de la page }, … } }
S.LEXIQUE = {
    { "Monnaies", {
        { "eclats", "Éclats cadavériques",
          "Le matériau de progression, rangé dans la Collection. Il sert aux rangs d'objet, à l'âme et au camp.",
          T("Obtenir")
          .. "• Sur les monstres : 0 à 3 par monstre, ×3 sur une élite, ×5 sur un rare ou un chef ; davantage sur les monstres puissants.\n"
          .. "• Mode difficile ×2, cauchemar ×3 ; en donjon, ×1,5 à ×3 selon la difficulté.\n"
          .. "• Récompenses des primes, contrats et défis.\n\n"
          .. T("Dépenser")
          .. "• Rangs d'objet : 15, 30, 60, 105 puis 180 éclats (plus pour les pièces puissantes).\n"
          .. "• Âme : 4 éclats par point, en auberge ou en ville.\n"
          .. "• Améliorations du camp, pièces bleues du Gouffre (40, 80 pour une arme)." },
        { "marques", "Marques du voyageur",
          "La monnaie de l'effort, à côté de l'or et des éclats : un objet du sac. Elle paie le camp, la carte des reliques, les passifs et les montures.",
          T("Obtenir")
          .. "• Primes, contrats et défis : 5 à 30 (médaille d'argent ×1,5, d'or ×2).\n"
          .. "• Chaque relique : 5.\n"
          .. "• Épreuve du jour : 1 par vague tenue, une fois par jour.\n"
          .. "• Dernier boss d'un donjon : 2 par difficulté au-dessus de 1.\n"
          .. "• Paliers 12, 20, 30 et 38 du rang d'aventurier : 50 à 200.\n\n"
          .. T("Dépenser")
          .. "• Améliorations du feu et de la potion (Camp).\n"
          .. "• Carte des reliques : 30 Marques et 2 po.\n"
          .. "• Emplacements de passifs extérieurs : 25 à 400. Montures.\n\n"
          .. G .. "Les Marques vont dans le sac : sac plein, Marques perdues." .. F },
        { "or", "Or",
          "L'or vient des quêtes et des annexes ; il paie la fabrication, les rangs, le camp et les réparations.",
          T("Obtenir")
          .. "• Quêtes, primes, contrats et défis (médaille d'argent +50 %, d'or +100 %).\n"
          .. "• Certaines familles de reliques complètes.\n\n"
          .. T("Dépenser")
          .. "• Fabrication, enchantement et rangs d'objet.\n"
          .. "• Potion et feu (Camp), carte des reliques (2 po).\n"
          .. "• Réparations (×1,5). La mort n'use pas l'équipement." },
    } },
    { "Équipement", {
        { "puissance", "Puissance",
          "Pas de niveau ici : ta force est ta puissance, la moyenne des niveaux d'objet de ce que tu portes.",
          T("Calcul")
          .. "• Moyenne des niveaux d'objet des pièces portées (chemise et tabard exceptés), +10 % par rang d'amélioration.\n"
          .. "• Chaque monstre a la sienne (survol de la cible).\n\n"
          .. T("Face à plus fort")
          .. "• −2 % de dégâts par point de puissance manquant, jusqu'à −75 %.\n\n"
          .. T("Combat")
          .. "• Tout coup porte : ni raté, ni esquive, ni parade. L'armure retire un montant fixe à chaque coup." },
        { "fabrication", "Fabrication",
          "Ton équipement se fabrique avec ce que tu récoltes : carnet Artisanat (touche P).",
          T("Fabriquer")
          .. "• Composants pris dans la Collection puis dans le sac, plus un peu d'or.\n"
          .. "• Puissance requise : celle de la pièce moins 2.\n"
          .. "• Maille, boucliers et armes : près d'une enclume ou d'une forge.\n"
          .. "• 10 s immobile : bouger annule.\n\n"
          .. T("Paliers")
          .. "• Rudimentaire : zones de départ, sans forge.\n"
          .. "• Inhabituel : les pièces vertes.\n"
          .. "• Gouffre : les pièces bleues, avec la Braise du Gouffre." },
        { "rangs", "Rangs d'objet",
          "Chaque pièce monte du rang 1 au rang 5 : +10 % de caractéristiques et de puissance par rang.",
          T("Améliorer")
          .. "• Artisanat › Amélioration, hors combat.\n"
          .. "• Coût : 15, 30, 60, 105 puis 180 éclats, et de l'or ; plus pour les pièces puissantes.\n"
          .. "• Rangs 4 et 5 : une pierre taillée en plus (Joaillerie).\n"
          .. "• L'enchantement est gardé." },
        { "enchantement", "Désenchantement et enchantement",
          "Une pièce dont tu n'as plus besoin se désenchante en composants d'enchantement.",
          T("Désenchanter")
          .. "• Une pièce verte, bleue ou épique du sac ; les composants vont dans la Collection.\n\n"
          .. T("Enchanter")
          .. "• Remplace l'enchantement de la pièce, payé en composants et en or." },
        { "joaillerie", "Joaillerie",
          "Les pierres taillées servent aux rangs 4 et 5 et aux pièces du Gouffre.",
          T("Pierres")
          .. "• Prospecter : 5 Minerais de cuivre donnent une gemme brute au hasard.\n"
          .. "• Tailler : 2 gemmes brutes donnent une pierre taillée.\n"
          .. "• En donjon, dès la difficulté 3, le dernier boss peut en donner une." },
        { "recolte", "Récolte",
          "Aucun métier à apprendre : plantes, filons et cuir se récoltent d'office et vont dans la Collection.",
          T("Récolter")
          .. "• Herboristerie, minage et pêche sont acquis, sans outil.\n"
          .. "• Plus de dépeçage : le cuir est dans le butin.\n"
          .. "• Chaque zone a ses plantes et ses filons.\n\n"
          .. T("Usage")
          .. "• Fabrication, cuisine, listes de courses du camp, joaillerie." },
        { "collection", "Collection et sac",
          "La Collection range sans limite tous les composants, même sac plein : carnet Collection (touche B).",
          T("Collection")
          .. "• Composants, éclats et reliques, sans limite de nombre.\n"
          .. "• Un objet demandé par une quête en cours reste dans le sac.\n\n"
          .. T("Sac")
          .. "• 50 places : le sac à dos et la Besace d'aventurier. Aucun autre sac." },
    } },
    { "Zone", {
        { "zone", "Pourcentage de zone",
          "Chaque zone se complète : histoire, exploration et annexes. À 60 %, son donjon s'ouvre.",
          T("Ce qui compte")
          .. "• Histoire 50 %, exploration 6 %, annexes 44 % (primes, contrats, défis, lieux, reliques).\n"
          .. "• Survol du suivi de zone : le détail. Clic : les objectifs.\n\n"
          .. T("Paliers")
          .. "• 60 % : le donjon et les modes de zone.\n"
          .. "• 100 % : l'équipement pour entrer serein dans le donjon." },
        { "primes", "Primes",
          "Une prime désigne un monstre rare ou un chef : sa tête de mort est sur la carte tant qu'elle est à faire.",
          T("Prendre")
          .. "• Tableaux des primes de Tranchecolline et de Sen'jin.\n\n"
          .. T("Récompense")
          .. "• Marques, éclats, or, une pièce d'équipement et une part de zone.\n\n"
          .. G .. "Les primes sont dures : viens avec la puissance annoncée, le Repos et la potion." .. F },
        { "contrats", "Contrats",
          "Les contrats se font en paliers, puis reviennent chaque jour (épingle bleue).",
          T("Fonctionnement")
          .. "• Donnés par les PNJ des pôles : 1 à 3 paliers.\n"
          .. "• Ensuite, une version journalière : 5 Marques et de l'or, sans part de zone." },
        { "defis", "Défis et épreuve",
          "Un défi se joue contre la montre ou sans potion ; sa médaille multiplie la récompense.",
          T("Contre la montre")
          .. "• Le chrono part au premier monstre du défi.\n"
          .. "• Au-delà du temps de bronze, échec : abandonner la quête et la reprendre.\n"
          .. "• Argent ×1,5, or ×2, et une pièce au premier or.\n\n"
          .. T("Sans potion")
          .. "• Boire en combat contre la cible fait échouer.\n\n"
          .. T("Épreuve de Zun'jala")
          .. "• 10 vagues. Mourir ou s'éloigner (60 m) l'arrête.\n"
          .. "• Épreuve du jour : 1 Marque par vague tenue." },
        { "lieux", "Lieux à nettoyer",
          "Un lieu se nettoie en tuant toute sa troupe ; il compte dans le pourcentage de zone.",
          T("Nettoyer")
          .. "• Les monstres tués pour une quête comptent aussi.\n"
          .. "• Certains lieux ont un chef renforcé : il paraît quand la troupe est tombée (alerte), et sa mort clôt le lieu." },
        { "reliques", "Reliques",
          "16 reliques sont cachées à Durotar. On les ramasse en passant ou d'un clic.",
          T("Récompense")
          .. "• 5 Marques, un composant et une part de zone.\n"
          .. "• Une famille complète : un bonus (pièce, or).\n\n"
          .. T("Carte des reliques")
          .. "• Dès 8 reliques trouvées, 30 Marques et 2 po (Aventure › Zone) : un coffre sur chaque relique manquante, son indice au survol." },
        { "modes", "Modes de zone",
          "Dès 60 % d'une zone, elle peut se jouer plus dure, pour plus d'éclats.",
          T("Choisir")
          .. "• En auberge ou en ville, dans les objectifs de la zone (Aventure › Zone, ou un clic sur le suivi de zone).\n\n"
          .. T("Modes")
          .. "• Difficile : vie et dégâts ×1,25, une technique de monstre, éclats ×2.\n"
          .. "• Cauchemar : ×1,5, deux techniques, éclats ×3, des événements.\n"
          .. "• Ils s'ouvrent avec le rang d'aventurier (paliers 5 et 9)." },
    } },
    { "Combat", {
        { "regles", "Règles du combat",
          "Tout coup porte : ni raté, ni esquive, ni parade. L'armure et la puissance font la différence.",
          T("Les coups")
          .. "• Ni raté, ni esquive, ni parade, dans les deux sens.\n"
          .. "• L'armure retire un montant fixe à chaque coup : les petits coups passent mal.\n\n"
          .. T("La puissance")
          .. "• Face à plus puissant : −2 % de dégâts par point manquant, jusqu'à −75 %.\n"
          .. "• La puissance de chaque monstre se lit au survol de la cible.\n\n"
          .. T("Les monstres")
          .. "• Pas de menace : ils n'ont que toi à frapper.\n"
          .. "• Rares et chefs sont plus durs ; certains lieux ont un chef renforcé, qui paraît quand sa troupe est tombée." },
        { "rempart", "Rempart",
          "Le passif du guerrier tank : une part de chaque coup encaissé devient un bouclier.",
          T("Remplir")
          .. "• Chaque coup encaissé, après l'armure, verse 40 % de ses dégâts dans le Rempart.\n"
          .. "• Plafond : 30 % de la vie maximale. Il se vide doucement hors combat.\n\n"
          .. T("Dépenser")
          .. "• Il absorbe les coups suivants.\n"
          .. "• Riposte du rempart et Second souffle le consomment." },
        { "techniques", "Techniques",
          "Ni rage ni mana : deux techniques à recharge au départ, d'autres apprises au fil du récit, et le passif de ta spécialisation.",
          T("Techniques")
          .. "• Les maîtres les enseignent à des étapes du récit (Gornek, Gar'Thok, Gadrin en Durotar).\n"
          .. "• 3 emplacements au départ, 5 à la fin de Durotar, 8 plus tard ; changées hors combat (touche K).\n"
          .. "• Un bouclier est exigé ; temps de recharge global de 0,75 s.\n\n"
          .. T("Combat")
          .. "• Pas de menace : les monstres n'ont que toi à frapper.\n"
          .. "• Guerrier tank : Rempart, une part des coups reçus devient un bouclier." },
    } },
    { "Survie", {
        { "regeneration", "Vie et régénération",
          "Ni nourriture, ni bandages : la vie remonte hors combat, au feu de camp et par ta potion.",
          T("Sources")
          .. "• Hors combat : 2 % de la vie par seconde.\n"
          .. "• Repos au coin du feu : 1 % de plus par seconde, 30 min.\n"
          .. "• La potion unique, en combat." },
        { "camp", "Feu de camp",
          "Pose un feu hors combat et assieds-toi : vie rendue, puis le Repos et tes charges de potion.",
          T("Le feu")
          .. "• Hors combat, toutes les 2 min. Se lever ou combattre l'éteint.\n"
          .. "• Assis : 6 % de la vie toutes les 2 s.\n\n"
          .. T("Après 60 s assis")
          .. "• Repos au coin du feu, 30 min : vie maximale +5 %, +1 %/s hors combat.\n"
          .. "• Toutes les charges de potion reviennent.\n\n"
          .. T("Améliorer")
          .. "• Carnet Camp (touche N) : listes de courses en Marques, éclats, or et composants." },
        { "potion", "Potion",
          "Une seule potion, qui s'améliore : 1 charge de 30 % de la vie au départ.",
          T("Usage")
          .. "• Recharge 30 s. Les charges reviennent au Repos, ou en auberge et en ville.\n\n"
          .. T("Améliorer")
          .. "• Carnet Camp : 2 charges à 35 %, puis un soin sur la durée." },
        { "cuisine", "Cuisine",
          "Près d'un feu, ton Feu de camp compris, les ingrédients de la zone deviennent des repas de 30 minutes.",
          T("Cuisiner")
          .. "• Artisanat › Fabrication, catégorie Cuisine, près d'un feu ; 5 s.\n"
          .. "• Un ingrédient des bêtes de la zone, une herbe et un assaisonnement de marchand.\n\n"
          .. T("Le repas")
          .. "• 30 min : ta caractéristique principale, et le bonus propre du plat (vie, armure, critique, dégâts, hâte).\n"
          .. "• Un seul repas à la fois ; il s'ajoute au Repos et aux consommables." },
        { "foyer", "Pierre de foyer",
          "Elle ramène à ton auberge, et c'est là que tu reviens après la mort.",
          T("Usage")
          .. "• Bouton à droite des techniques. Recharge de 30 min au départ.\n"
          .. "• Le rang d'aventurier la ramène à 25, 20, 15 puis 10 min ; un passif extérieur retire encore 5 min.\n\n"
          .. T("Après la mort")
          .. "• Libérer l'esprit ramène à la pierre de foyer, vie pleine." },
        { "mort", "Mort et âme",
          "La mort ne coûte ni objet ni usure, mais de l'âme. Une âme à zéro met fin au personnage.",
          T("Mourir")
          .. "• Libérer l'esprit ramène à la pierre de foyer, vie pleine.\n"
          .. "• Chaque mort coûte 1 point d'âme, plus 1 par 15 points de puissance (10 au plus), sur 100.\n\n"
          .. T("Regagner de l'âme")
          .. "• En auberge ou en ville, 4 éclats par point (Personnage › Âme)." },
    } },
    { "Progression", {
        { "aventurier", "Rang d'aventurier",
          "Le rang du compte : tout ce que tu accomplis le nourrit, une fois par compte.",
          T("Points")
          .. "• Quête d'histoire 10, lieu 20, annexe 25, relique 10, zone à 60 % 50, à 100 % 300, donjon 150.\n"
          .. "• Zone maîtrisée (150 monstres) en difficile 150, en cauchemar 300 ; objectifs d'artisan 15.\n"
          .. "• Le détail : Aventure › Registre.\n\n"
          .. T("Paliers")
          .. "• Titres, pierre de foyer plus rapide, montures (palier 10), modes de zone (5 et 9), Marques, emplacements de passifs extérieurs.\n"
          .. "• Il ne donne pas de puissance." },
        { "montures", "Montures",
          "On ne monte pas tout de suite : la monte s'ouvre au palier 10 du rang d'aventurier, vers la fin de Durotar.",
          T("La monte")
          .. "• Palier 10 (1 950 points) : la monte et une monture à 60 % offerte.\n"
          .. "• Chaque vitesse, de 65 à 150 %, s'ouvre avec un palier.\n\n"
          .. T("La boutique")
          .. "• Aventure › Montures, en Marques du voyageur ; les montures sont au compte.\n"
          .. "• Les montures volantes ne se lancent pas." },
        { "donjons", "Donjons",
          "La difficulté du donjon (1 à 5) se choisit avant le premier combat, puis se verrouille.",
          T("Difficulté")
          .. "• Plus haute : des techniques de monstre et plus de butin.\n"
          .. "• Dernier boss : des Marques, et dès la difficulté 3 une chance de pierre taillée.\n"
          .. "• Les boss donnent la Braise du Gouffre, pour les pièces bleues.\n"
          .. "• Terminer le donjon (son dernier boss) dans une difficulté ouvre la suivante, pour le compte." },
        { "passifs", "Réputation et passifs",
          "Chaque donjon nourrit une réputation commune ; elle ouvre des passifs à choisir avant d'entrer.",
          T("Donjons")
          .. "• Réputation du compte : monstres, boss et dernier boss, × la difficulté. 10 rangs.\n"
          .. "• 6 emplacements de passifs de donjon.\n\n"
          .. T("Monde extérieur")
          .. "• Emplacements achetés en Marques, passifs changés en auberge ou en ville." },
        { "mots", "Mots du jeu",
          "Quelques mots qui se ressemblent mais ne disent pas la même chose.",
          T("Puissance")
          .. "• Ta puissance : ta force, la moyenne de ton équipement. La « puissance d'attaque » d'un objet n'est qu'une caractéristique.\n\n"
          .. T("Rang et palier")
          .. "• Rang : celui d'une pièce (1 à 5), de la réputation des donjons, de la potion, du feu.\n"
          .. "• Palier : une étape du rang d'aventurier, ou d'un contrat.\n\n"
          .. T("Défi et épreuve")
          .. "• Défi : une quête annexe contre la montre ou sans potion, avec médaille.\n"
          .. "• Épreuve : les vagues de Zun'jala, et l'épreuve du jour.\n\n"
          .. T("Éclats et Repos")
          .. "• Éclats cadavériques : ta monnaie de progression ; les éclats d'enchantement sont des composants.\n"
          .. "• Repos au coin du feu : un bonus de vie, pas d'expérience." },
    } },
}

S.VUS = S.VUS or {}
local PLACE = {}   -- clé -> thème, concept
for t, theme in ipairs(S.LEXIQUE) do
    for c, concept in ipairs(theme[2]) do PLACE[concept[1]] = { t, c } end
end

------------------------------------------------------------------------
-- Fenêtre du lexique
------------------------------------------------------------------------
local LIGNES = 7
local themeOuvert
local f = S.Fenetre("SolUILexique", 820, 560, "Lexique")
local separation = S.Texture(f, "ARTWORK", nil, S.Couleur("bord"))
separation:SetPoint("TOPLEFT", 252, -64)
separation:SetPoint("BOTTOMLEFT", 252, 20)
separation:SetWidth(1)
local boutons = {}
for i = 1, LIGNES do
    local b = S.BoutonPlat(f, "", 216, 36, 12)
    b:SetPoint("TOPLEFT", 20, -68 - (i - 1) * 42)
    boutons[i] = b
end
local defil = S.Liste(f, boutons, function() S.PageLexique(themeOuvert) end)   -- lot 6c
local nom = S.Texte(f, "Bold", 20, "ambreClair")
nom:SetPoint("TOPLEFT", 276, -72)
local resume = S.Texte(f, "SemiBold", 14, "clair")
resume:SetPoint("TOPLEFT", 276, -106)
resume:SetWidth(516)
resume:SetJustifyH("LEFT")
local texte = S.Texte(f, "Regular", 13, "texte")
texte:SetPoint("TOPLEFT", resume, "BOTTOMLEFT", 0, -16)
texte:SetWidth(516)
texte:SetJustifyH("LEFT")
texte:SetSpacing(3)

local choix = {}   -- thème -> dernier concept vu
themeOuvert = 1
function S.PageLexique(t, c)
    local theme = S.LEXIQUE[t]
    if not theme then return end
    local change = t ~= themeOuvert or c ~= nil   -- la molette redessine sans ramener au concept choisi
    themeOuvert = t
    c = math.max(1, math.min(c or choix[t] or 1, #theme[2]))
    choix[t] = c
    defil:Regler(#theme[2])
    if change then defil:Voir(c) end
    local d = defil:Regler(#theme[2])
    for i, b in ipairs(boutons) do
        local k = i + d
        local concept = theme[2][k]
        S.Montrer(b, concept ~= nil)
        if concept then
            b.texte:SetText(concept[2])
            b:Choisir(k == c)
            b:SetScript("OnClick", function() S.PageLexique(t, k) end)
        end
    end
    local concept = theme[2][c]
    nom:SetText(concept[2])
    resume:SetText(concept[3])
    texte:SetText(concept[4])
end

-- Onglets du carnet Lexique : un par thème.
function S.OngletsLexique()
    local onglets = {}
    for t, theme in ipairs(S.LEXIQUE) do
        table.insert(onglets, { nom = theme[1], cadre = function() return SolUILexique end,
            page = function() S.PageLexique(t) end })
    end
    return onglets
end

function S.OuvrirLexique(cle)
    local p = PLACE[cle]
    if not p then return end
    choix[p[1]] = p[2]
    S.OuvrirCarnet("lexique", p[1])
end

------------------------------------------------------------------------
-- Fenêtre d'explication
------------------------------------------------------------------------
local e = CreateFrame("Frame", "SolUIExplication", S.racine)
e:SetSize(420, 168)
e:SetPoint("TOP", S.racine, "TOP", 0, -120)
e:SetFrameStrata("HIGH")
e:EnableMouse(true)
S.Panneau(e, 0.96, "ambre")
e:Hide()
local etiquette = S.Texte(e, "SemiBold", 11, "gris")
etiquette:SetPoint("TOPLEFT", 20, -16)
etiquette:SetText("À SAVOIR")
local eNom = S.Texte(e, "Bold", 17, "ambreClair")
eNom:SetPoint("TOPLEFT", etiquette, "BOTTOMLEFT", 0, -6)
local eTexte = S.Texte(e, "Regular", 13, "texte")
eTexte:SetPoint("TOPLEFT", eNom, "BOTTOMLEFT", 0, -8)
eTexte:SetWidth(380)
eTexte:SetJustifyH("LEFT")
local lire = S.BoutonPlat(e, "Lire la page", 150, 30, 12)
lire:SetPoint("BOTTOMRIGHT", -20, 16)
local compris = S.BoutonPlat(e, "Compris", 110, 30, 12)
compris:SetPoint("RIGHT", lire, "LEFT", -10, 0)

local file = {}
local enCours
local function Suivante()
    if e:IsShown() or #file == 0 or InCombatLockdown() or UnitIsDeadOrGhost("player") then return end
    enCours = table.remove(file, 1)
    local p = PLACE[enCours]
    local concept = S.LEXIQUE[p[1]][2][p[2]]
    eNom:SetText(concept[2])
    eTexte:SetText(concept[3])
    e:Show()
    PlaySound("igQuestListOpen")
end
compris:SetScript("OnClick", function() e:Hide(); Suivante() end)
lire:SetScript("OnClick", function() e:Hide(); S.OuvrirLexique(enCours) end)

-- Moment clé : l'explication du concept, une seule fois (même en combat, elle attend la fin du combat).
function S.Expliquer(cle)
    if S.VUS[cle] or not PLACE[cle] then return end
    S.VUS[cle] = true
    if S.Enregistrer then S.Enregistrer() end
    table.insert(file, cle)
    Suivante()
end
S.Ecouter("PLAYER_REGEN_ENABLED", Suivante)
S.Ecouter("PLAYER_UNGHOST", Suivante)
S.Ecouter("PLAYER_ALIVE", Suivante)

------------------------------------------------------------------------
-- Moments clés
------------------------------------------------------------------------
local ECLATS, MARQUES = 910120, 37711
S.Message("SOLPUISSANCE", function() S.Expliquer("puissance") end)
S.Message("SOLCOL", function(champs)
    if champs[1] ~= "MAJ" or (tonumber(champs[4]) or 0) <= 0 then return end
    local objet = tonumber(champs[2])
    if objet == ECLATS then S.Expliquer("eclats")
    elseif SolUI.RELIQUES and SolUI.RELIQUES[objet] then S.Expliquer("reliques")
    else S.Expliquer("recolte"); S.Expliquer("collection") end
end)
S.Ecouter("BAG_UPDATE", function()
    if GetItemCount(MARQUES) > 0 then S.Expliquer("marques") end
end)
local or0
S.Ecouter("PLAYER_MONEY", function()
    local m = GetMoney()
    if or0 and m > or0 then S.Expliquer("or") end
    or0 = m
end)
S.Ecouter("PLAYER_ENTERING_WORLD", function() or0 = GetMoney() end)
S.Message("SOLEQUIP", function(champs)
    if champs[1] == "FORGE" and champs[2] == "1" then S.Expliquer("fabrication"); S.Expliquer("rangs") end
end)
S.Ecouter("UNIT_HEALTH", function(_, unite)
    if unite == "player" and UnitHealth("player") > 0 and UnitHealth("player") < UnitHealthMax("player") * 0.8 then   -- lot 6a : plus tôt (était 50 %)
        S.Expliquer("regeneration"); S.Expliquer("camp"); S.Expliquer("potion")
    end
end)
S.Ecouter("PLAYER_DEAD", function() S.Expliquer("mort") end)
S.Message("SOLAVENT", function(champs) if champs[1] == "PALIER" then S.Expliquer("aventurier") end end)
S.Message("SOLDONJON", function(champs)
    if champs[1] == "DONJON" then S.Expliquer("donjons"); S.Expliquer("passifs") end
end)
-- Nouvelle technique débloquée (« ETAT;spé;puissance;seuil;sort:état,… », état 1 ou 2 : débloquée).
local debloquees
S.Message("SOLKIT", function(champs)
    if champs[1] ~= "ETAT" then return end
    local n = 0
    for etat in (champs[5] or ""):gmatch("%d+:(%d)") do if etat ~= "0" then n = n + 1 end end
    if debloquees and n > debloquees then S.Expliquer("techniques") end
    debloquees = n
end)

local FAMILLES = { Primes = "primes", Contrats = "contrats", ["Défis"] = "defis" }
S.Abonner("zone", function()
    local p = S.progresZone
    if not p then return end
    S.Expliquer("zone")
    for quete, q in pairs(p.quetes) do
        local annexe = SolUI.ANNEXES and SolUI.ANNEXES[quete]
        if annexe and q.etat == 1 and FAMILLES[annexe.famille] then S.Expliquer(FAMILLES[annexe.famille]) end
    end
    for _, l in ipairs(p.lieux) do
        if l.tues > 0 then S.Expliquer("lieux") end
    end
    for _, trouvee in pairs(p.reliques) do
        if trouvee then S.Expliquer("reliques") end
    end
    if p.total >= 6000 then S.Expliquer("modes") end
end)
