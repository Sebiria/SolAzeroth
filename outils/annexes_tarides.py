"""Lot T4 des Tarides (03/11/2026) : les données des annexes A11 à A46 des Tarides (brouillon des Tarides, §4.1.2 à
4.1.6). Le générateur est annexes_durotar.py, paramétré par zone : « py annexes_durotar.py tarides » écrit la migration
144 et SolUI_Annexes.lua (Durotar et les Tarides).

Numéros : quêtes 910230 + n (A11 = 910241) ; palier 2 : + 100 ; palier 3 : + 200 ; répétition journalière : + 300.
Pièces 910801 à 910812, versions par classe 910821 et suivantes (rangs 928xxx) ; reliques 910880 à 910895 ; objets du
monde 910012 et 910013 (tableaux), 910040 à 910055 (reliques) ; crédits des vagues 910067 et 910068.
Barème (décision 4 du comparatif) : 20 Marques par point de part ; or et éclats par point selon la puissance de
l'annexe (14-16 : 1 po 20 pa et 15 éclats ; 17-22 : 1 po 85 pa et 23 ; 23-29 : 2 po 85 pa et 36 ; 30-31 : 4 po 40 pa
et 55). Les montants ci-dessous sont ceux du brouillon, déjà arrondis sur ce barème.
"""
ZONE, NOM, PREFIXE = 17, "Les Tarides", "T4"
CARTE = 11                               # WorldMapArea des Tarides
QUETE = 910230                           # A11 = 910241
HISTOIRE = 910040                        # T01 = 910041
MIGRATION_NUMERO = "144_v3_annexes_tarides"

TABLEAU_CROISEE, TABLEAU_TAURAJO = 910012, 910013
CROISEE, TAURAJO = ("go", TABLEAU_CROISEE), ("go", TABLEAU_TAURAJO)
CREDIT_VAGUE5, CREDIT_VAGUE10 = 910067, 910068
GO_RELIQUE, RELIQUE = 910040, 910880
GUID_GO = 9100100
EPREUVE = 2                              # deuxième épreuve de vagues (la première : Zun'jala)
REGTHAR = 3389

# Composants des Tarides (§4.7.8)
LIN, LAINE, CUIR_LEGER, CUIR_MOYEN = 2589, 2592, 2318, 2319
MAGE_ROYAL, EGLANTINE, DOULOURANTE, ETOUFFANTE, SANG_ROYAL, ACIERITE = 785, 2450, 2453, 3820, 3356, 3355
ETAIN, ARGENT, MALACHITE, OEIL_TIGRE, OEIL_TENEBREUX, AGATE, LUNE = 2771, 2775, 774, 818, 1210, 1206, 1705

# Chefs renforcés (copies du lot T3, migration 140).
KREENIG, SARILUS, HEZRUL, BEAUMONT, GUKKROK, DOUBLENATTES, LOK = range(910060, 910067)

# Pièces : (entrée, nom, objet d'origine pour l'apparence et le type, puissance). Maille, boucliers et épée pour le
# monde ; un seul nom, neutre, pour toutes les versions.
PIECES = [
    (910801, "Cape de Brume-funeste", 4447, 17),
    (910802, "Mantelet de plumes de l'orage", 4705, 23),
    (910803, "Garde de Rochelance", 3656, 22),
    (910804, "Lame de Plaie-des-taurens", 3850, 31),
    (910805, "Couvre-chef de Martèlorteil", 7130, 31),
    (910806, "Ceinture à outils de la KapitalRisk", 9814, 19),
    (910807, "Brassards de la grande chasse", 6591, 31),
    (910808, "Bottes de la garnison", 6590, 23),
    (910809, "Jambières de la contre-attaque", 6596, 28),
    (910810, "Cotte de Bael'dun", 6592, 31),
    (910811, "Garde du rêve", 4065, 31),
    (910812, "Bottes d'épine-de-sang", 15534, 30),
]
# Genre de chaque pièce (Item.dbc sans lire la base) : emplacement de la maille, ou arme, main gauche, cape.
GENRES = {910801: "cape", 910802: 3, 910803: "main gauche", 910804: "arme", 910805: 1, 910806: 6, 910807: 9,
          910808: 8, 910809: 7, 910810: 5, 910811: "main gauche", 910812: 8}
JEU = dict(recompenses=[(e, p, nom, source) for e, nom, source, p in PIECES],
           premieres=(910821, 910841, 910851, 910871), genres=GENRES)


def q(n, palier=1, jour=False):
    return QUETE + n + (300 if jour else 100 * (palier - 1))


# Quêtes, au format d'annexes_durotar.A. item_drop : (objet, nombre), objet de quête qui tombe pendant la quête
# (ItemDrop, comme la quête 905 d'origine : les plumes des nids).
A = [
    dict(q=q(11), cle="A11", famille="Primes", titre="Le garde du Refuge", de=3521, a=3521, prev=HISTOIRE + 8, p=17,
         part=75, tuer=[(3470, 1, (318, -2236), None)], argent=14000, insignes=15, eclats=17, equip=910801,
         resume="Tue Rathorian, à la porte du Refuge de Brume-funeste.",
         intro="Sarilus avait un garde du corps, qui n'était pas de la Lame. Il garde encore la porte du Refuge. Sa "
               "Frappe mortelle coupe les soins. Frappe vite, avant que ta potion ne manque.",
         prog="Rathorian garde toujours la porte ?", fin="Le garde est tombé. Prends cette cape : elle était à lui."),
    dict(q=q(12), cle="A12", famille="Primes", titre="L'ancienne mystique", de=CROISEE, a=CROISEE, p=18, part=75,
         tuer=[(3270, 1, (-35, -3381), None)], argent=14000, insignes=15, eclats=17,
         composants={EGLANTINE: 2, MALACHITE: 1},
         resume="Tue l'Ancienne mystique Tranchegroin, sur le versant est de la Colline des épines.",
         intro="AVIS DE RECHERCHE. L'Ancienne mystique Tranchegroin soigne les Tranchecrins de la colline. Elle plante "
               "un totem guérisseur : brisez-le. Sa vague de soins se coupe, mais rien n'oblige à la couper.",
         prog="La mystique soigne toujours les siens.", fin="La mystique est morte. Voici la prime."),
    dict(q=q(13), cle="A13", famille="Primes", titre="Le chef des Kolkar", de=REGTHAR, a=REGTHAR, prev=HISTOIRE + 13,
         p=19, part=100, tuer=[(3394, 1, (23, -1715), None)], argent=18500, insignes=20, eclats=23,
         composants={CUIR_MOYEN: 4, AGATE: 1},
         resume="Tue Barak Plaie-des-kodos, au nord des Bassins oubliés.",
         intro="Barak Plaie-des-kodos mène les Kolkar du nord. Il jette son filet, puis tire de loin. Colle-le dès que "
               "le filet tombe. Quand il faiblit, ses Légions-tempête accourent.",
         prog="Barak vit encore ?", fin="Barak est mort. Les Kolkar du nord n'ont plus de chef."),
    dict(q=q(14), cle="A14", famille="Primes", titre="Les sœurs du ciel", de=3449, a=3449, p=23, part=125,
         tuer=[(5830, 1, (587, -1433), None), (3452, 1, (790, -1346), None)], argent=35500, insignes=25, eclats=45,
         equip=910802,
         resume="Tue Sœur Rathtalon et Serena Plumesang, dans les Collines arides.",
         intro="Deux harpies règnent sur les aires des Ensorçaile. Leur vent repousse au bord des aires, et leurs "
               "tueuses viennent quand elles faiblissent. Garde le dos au rocher.",
         prog="Les sœurs volent encore.", fin="Les deux sœurs sont tombées. Ce mantelet est fait de leurs plumes."),
    dict(q=q(15), cle="A15", famille="Primes", titre="Le Peau-piquante", de=TAURAJO, a=TAURAJO, p=27, part=125,
         tuer=[(5864, 1, (-1439, -1507), None)], argent=35500, insignes=25, eclats=45,
         composants={SANG_ROYAL: 3, OEIL_TENEBREUX: 1},
         resume="Tue Peau-piquante Pourcegart, au nord d'Agama'gor.",
         intro="AVIS DE RECHERCHE. Pourcegart a la peau couverte de piquants : chaque coup porté au contact blesse "
               "celui qui frappe. Quand il faiblit, il fonce et assomme.",
         prog="Pourcegart rôde encore.", fin="Pourcegart est mort. Voici la prime."),
    dict(q=q(16), cle="A16", famille="Primes", titre="Les frères de l'oasis stagnante", de=CROISEE, a=CROISEE, p=22,
         part=75, tuer=[(5841, 1, (-1199, -3100), None), (5838, 1, (-1169, -3165), None)], argent=14000,
         insignes=15, eclats=17, equip=910803,
         resume="Tue Rochelance et Brise-épieu, au sud de l'Oasis stagnante.",
         intro="AVIS DE RECHERCHE. Rochelance et Brise-épieu se battent en frères d'armes : côte à côte, ils "
               "encaissent moitié moins. Séparez-les. Tirez l'un loin de l'autre.",
         prog="Les frères tiennent toujours l'oasis.", fin="Les deux frères sont morts. Prends cette garde."),
    dict(q=q(17), cle="A17", famille="Primes", titre="Humar le Fier", de=3338, a=3338, prev=HISTOIRE + 3, p=28,
         part=125, tuer=[(5828, 1, (-611, -3615), None)], argent=35500, insignes=25, eclats=45,
         composants={CUIR_MOYEN: 4, LUNE: 1},
         resume="Tue Humar le Fier, dans la savane à l'est de la Croisée.",
         intro="Le roi des lions des savanes. Ses femelles chassent pour lui. Sa morsure saigne, et le sang coule de "
               "plus en plus. Il est trop fort pour toi aujourd'hui : reviens du sud.",
         prog="Humar règne toujours.", fin="Le roi est mort. La savane respire."),
    dict(q=q(18), cle="A18", famille="Primes", titre="Plaie-des-taurens", de=TAURAJO, a=TAURAJO, p=31, part=150,
         tuer=[(5859, 1, (-4006, -1753), None)], argent=66000, insignes=30, eclats=83, equip=910804,
         resume="Tue Hagg Plaie-des-taurens, sur la Crête de Noirépine.",
         intro="AVIS DE RECHERCHE. Hagg a tué plus de taurens que la sécheresse. Il appelle ses frénétiques quand il "
               "faiblit, puis il enrage.",
         prog="Hagg vit encore.", fin="Hagg est mort. Prends sa lame."),
    dict(q=q(19), cle="A19", famille="Primes", titre="Le capitaine de Bael'dun", de=TAURAJO, a=TAURAJO, p=31,
         part=150, tuer=[(5851, 1, (-4041, -2383), None)], argent=66000, insignes=30, eclats=83, equip=910805,
         resume="Tue le Capitaine Gerogg Martèlorteil, au Donjon de Bael'dun.",
         intro="AVIS DE RECHERCHE. Le Capitaine Gerogg lève son mur toutes les trente secondes. Gardez vos gros coups "
               "pour les fenêtres sans mur.",
         prog="Le capitaine tient toujours le donjon.", fin="Gerogg est tombé. Son couvre-chef est à toi."),

    dict(q=q(20), cle="A20", famille="Contrats", titre="Le tonneau de Chen", de=3292, a=3292, p=16, part=50,
         objets=[(4893, 5, (-560, -2560)), (4894, 5, (-380, -2350))], argent=6000, insignes=10, eclats=8,
         composants={CUIR_LEGER: 3},
         resume="Rapporte 5 Canines de lion des savanes et 5 Rognons de trotteur au Brasseur Drohn.",
         intro="Je brasse une bière que Chen lui-même m'envierait. Il me faut des canines de lion et des rognons de "
               "trotteur, autour de la Croisée. Les lions chassent en meute : un lion blessé appelle les autres.",
         prog="Mon tonneau attend.", fin="Parfait. Le brassin peut commencer."),
    dict(q=q(20, 2), cle="A20", famille="Contrats", titre="Le tonneau de Chen (2)", de=3292, a=3292, prev=q(20), p=25,
         part=50, objets=[(4895, 1, (-1800, -2500)), (4898, 5, (-1900, -2400)), (4897, 1, (-2200, -1900)),
                          (4896, 1, (-2100, -2200))],
         argent=14500, insignes=10, eclats=18, composants={SANG_ROYAL: 2},
         resume="Rapporte une corne de lézard-tonnerre, 5 glandes d'éclair, une glande de faucon-tonnerre et un "
                "foie de kodo au Brasseur Drohn.",
         intro="Pour la vraie recette, il faut les bêtes du sud : lézards-tonnerre, faucons-tonnerre, kodos. Plus "
               "dures, mais la bière n'en sera que meilleure.", prog="Et le reste de la recette ?",
         fin="Tout y est ! Chen n'a qu'à bien se tenir."),
    dict(q=q(20, jour=True), cle="A20", famille="Contrats", titre="Le tonneau de Chen (jour)", de=3292, a=3292,
         prev=q(20, 2), p=25, part=0, journaliere=True,
         objets=[(4893, 5, (-560, -2560)), (4896, 1, (-2100, -2200))], argent=5500, insignes=5, eclats=0,
         composants={CUIR_MOYEN: 2}, resume="Rapporte 5 Canines de lion et un foie de kodo au Brasseur Drohn.",
         intro="Le tonneau se vide tous les jours. Cinq canines, un foie.", prog="Le tonneau attend.",
         fin="Merci. À demain !"),

    dict(q=q(21), cle="A21", famille="Contrats", titre="Les petites pièces de la KapitalRisk", de=9316, a=9316, p=18,
         part=50, objets=[(11143, 10, (1037, -3092))], argent=9500, insignes=10, eclats=12, composants={ETAIN: 2},
         resume="Rapporte 10 Rondelles de métal, prises dans les Seaux d'outils de la Videfange, à Wenikee.",
         intro="La KapitalRisk jette ses rondelles dans des seaux, à la Videfange. Il m'en faut dix. Attention : "
               "chaque seau ouvert fait accourir deux manouvriers.",
         prog="Mes rondelles ?", fin="Dix rondelles ! Ma machine va enfin tourner."),
    dict(q=q(21, 2), cle="A21", famille="Contrats", titre="Les petites pièces de la KapitalRisk (2)", de=9316,
         a=9316, prev=q(21), p=19, part=50,
         go=[(4072, 1, (836, -2680), "Première valve fermée"), (61935, 1, (836, -2680), "Deuxième valve fermée"),
             (61936, 1, (836, -2680), "Troisième valve fermée")],
         objets=[(5089, 1, (910, -2732))], argent=9500, insignes=10, eclats=12, equip=910806,
         resume="Ferme les trois valves du Centre de recherches, puis prends la Clé de la console sur le Bricoleur "
                "Brokarde.",
         intro="Le Centre de recherches pompe l'eau des Tarides. Ferme ses trois valves, puis prends la clé de la "
               "console au Bricoleur Brokarde. Chaque valve fermée fait venir des manouvriers.",
         prog="Les valves tournent encore ?", fin="Le centre est à sec. Prends cette ceinture, elle me vient d'eux."),
    dict(q=q(21, jour=True), cle="A21", famille="Contrats", titre="Les petites pièces de la KapitalRisk (jour)",
         de=9316, a=9316, prev=q(21, 2), p=19, part=0, journaliere=True, objets=[(11143, 10, (1037, -3092))],
         argent=4500, insignes=5, eclats=0, composants={ETAIN: 2}, resume="Rapporte 10 Rondelles de métal à Wenikee.",
         intro="La machine en mange tous les jours. Dix rondelles.", prog="Alors ?", fin="Merci !"),

    dict(q=q(22), cle="A22", famille="Contrats", titre="Les nids de solécaille", de=3338, a=3338, p=22, part=100,
         go=[(6906, 1, (-1520, -2680), "Premier nid"), (6907, 1, (-1520, -2680), "Deuxième nid"),
             (6908, 1, (-1520, -2680), "Troisième nid")], item_drop=(5165, 3), argent=18500, insignes=20, eclats=23,
         composants={CUIR_MOYEN: 4},
         resume="Dépose une plume de solécaille dans chacun des trois nids, entre l'Oasis stagnante et Ronceplaie.",
         intro="Les faucheurs solécaille couvent trois nids au sud. Prends leurs plumes et pose-en une dans chaque nid : "
               "les petits ne reconnaîtront plus leur mère. Chaque plume posée fait venir deux faucheurs.",
         prog="Les nids ?", fin="Trois nids, trois plumes. Les faucheurs vont s'entre-déchirer."),
    dict(q=q(22, jour=True), cle="A22", famille="Contrats", titre="Les nids de solécaille (jour)", de=3338, a=3338,
         prev=q(22), p=22, part=0, journaliere=True,
         go=[(6906, 1, (-1520, -2680), "Premier nid"), (6907, 1, (-1520, -2680), "Deuxième nid"),
             (6908, 1, (-1520, -2680), "Troisième nid")], item_drop=(5165, 3), argent=4500, insignes=5, eclats=0,
         composants={CUIR_MOYEN: 2}, resume="Dépose une plume dans chacun des trois nids.",
         intro="Les faucheurs ont repondu. Trois plumes encore.", prog="Alors ?", fin="Merci."),

    dict(q=q(23), cle="A23", famille="Contrats", titre="La grande chasse de Jorn", de=3387, a=3387, p=27, part=50,
         tuer=[(3474, 1, (-1837, -2188), None), (3473, 1, (-2510, -2377), None)], argent=14500, insignes=10,
         eclats=18, composants={CUIR_MOYEN: 2},
         resume="Tue Lakota'mani et Owatanka.",
         intro="Six bêtes que la savane craint. Chacune seule, chacune loin des autres. Commence par Lakota'mani et "
               "Owatanka. Blessées, elles entrent en fureur.",
         prog="Les deux premières vivent encore ?", fin="Deux de six. Le sud t'attend."),
    dict(q=q(23, 2), cle="A23", famille="Contrats", titre="La grande chasse de Jorn (2)", de=3387, a=3387,
         prev=q(23), p=28, part=50, tuer=[(5834, 1, (-2685, -1941), None), (5832, 1, (-3672, -2146), None)],
         argent=14500, insignes=10, eclats=18, composants={LUNE: 1},
         resume="Tue Azzere la lame céleste et Grondeterre.",
         intro="Azzere crache le feu, Grondeterre appelle la foudre. Plus au sud.", prog="Et ces deux-là ?",
         fin="Quatre de six. Il reste les plus terribles."),
    dict(q=q(23, 3), cle="A23", famille="Contrats", titre="La grande chasse de Jorn (3)", de=3387, a=3387,
         prev=q(23, 2), p=31, part=100, tuer=[(3472, 1, (-3855, -1753), None), (5827, 1, (-3815, -1846), None)],
         argent=44000, insignes=20, eclats=55, equip=910807,
         resume="Tue Washte Pawne et Brontus, à l'extrême sud.",
         intro="Washte Pawne et Brontus, tout au sud. Les plus vieux, les plus forts.", prog="La chasse n'est pas finie.",
         fin="Les six sont tombées. Porte ces brassards : tu as gagné la grande chasse."),
    dict(q=q(23, jour=True), cle="A23", famille="Contrats", titre="La grande chasse de Jorn (jour)", de=3387,
         a=3387, prev=q(23, 3), p=28, part=0, journaliere=True,
         tuer=[(3473, 1, (-2510, -2377), None), (5832, 1, (-3672, -2146), None)], argent=11500, insignes=5,
         eclats=0, composants={LUNE: 1}, resume="Tue Owatanka et Grondeterre.",
         intro="Les bêtes reviennent toujours. Deux encore.", prog="Alors ?", fin="Merci."),

    dict(q=q(24), cle="A24", famille="Contrats", titre="La chasse aux œufs", de=3428, a=3428, p=29, part=100,
         objets=[(5058, 12, (-3171, -1940))], argent=28500, insignes=20, eclats=36,
         composants={ACIERITE: 2, LUNE: 1},
         resume="Rapporte 12 Œufs de silithide, pris dans les Antres du Champ des Géants, à Korran.",
         intro="Les silithides pondent au Champ des Géants. Fouille leurs antres et rapporte douze œufs. Chaque "
               "antre fouillé réveille deux grouillants.",
         prog="Les œufs ?", fin="Douze œufs. Ils n'écloront pas."),
    dict(q=q(24, jour=True), cle="A24", famille="Contrats", titre="La chasse aux œufs (jour)", de=3428, a=3428,
         prev=q(24), p=29, part=0, journaliere=True, objets=[(5058, 6, (-3171, -1940))], argent=8000, insignes=5,
         eclats=0, composants={ACIERITE: 1}, resume="Rapporte 6 Œufs de silithide à Korran.",
         intro="Elles pondent encore. Six œufs.", prog="Alors ?", fin="Merci."),

    dict(q=q(25), cle="A25", famille="Défis", titre="Le Pic en six minutes", de=3521, a=3521, prev=HISTOIRE + 8, p=16,
         part=50, tuer=[(3379, 10, (345, -2215), None), (3380, 10, (345, -2215), None), (3986, 1, (319, -2264), None)],
         argent=6000, insignes=10, eclats=8, composants={LIN: 3}, chrono=([3379, 3380], 360, 300, 240),
         resume="Contre la montre : 20 sectateurs du Pic puis Sarilus. Bronze 6 min, argent 5 min, or 4 min.",
         intro="Tu as chassé la Lame du Pic. Mais vite ? Le chrono part au premier sectateur : vingt sectateurs, puis "
               "Sarilus, en moins de six minutes. Tire-les par paquets de quatre ou cinq.",
         prog="Le temps file.", fin="Rapide. Reviens battre ton temps quand tu veux."),
    dict(q=q(26), cle="A26", famille="Défis", titre="L'assaut du Fort du Nord", de=3339, a=3339, prev=HISTOIRE + 15,
         p=23, part=75, tuer=[(3393, 1, (-2080, -3644), None)], argent=21500, insignes=15, eclats=27,
         equip_or=910808, chrono=([3385, 3386], 420, 330, 270),
         resume="Contre la montre : tue le Capitaine Beaumont moins de 7 min après le premier soldat tué au fort "
                "(argent 5 min 30, or 4 min 30).",
         intro="Un assaut se mène vite. Le chrono part au premier soldat tué au fort : traverse la cour et tue "
               "Beaumont en moins de sept minutes. En moins de quatre minutes trente, mes bottes sont à toi.",
         prog="Plus vite !", fin="Un vrai assaut. Reviens quand tu veux faire mieux."),
    dict(q=q(27), cle="A27", famille="Défis", titre="La contre-attaque", de=REGTHAR, a=REGTHAR, prev=HISTOIRE + 13,
         p=21, part=75, tuer=[(CREDIT_VAGUE5, 1, (-307, -1972), "Vague 5 de la contre-attaque tenue")], argent=14000,
         insignes=15, eclats=17,
         resume="Parle à Regthar pour lancer la contre-attaque, et tiens jusqu'à la vague 5.",
         intro="Les Kolkar reviennent, et pas seuls. Dix vagues, de plus en plus dures, vingt secondes de répit entre "
               "deux. Tiens cinq vagues pour commencer. Dis-moi quand tu es $Gprêt:prête;.",
         prog="Les Kolkar approchent.", fin="Cinq vagues. Le poste tient."),
    dict(q=q(27, 2), cle="A27", famille="Défis", titre="La contre-attaque (2)", de=REGTHAR, a=REGTHAR, prev=q(27),
         p=28, part=100, tuer=[(CREDIT_VAGUE10, 1, (-307, -1972), "Vague 10 de la contre-attaque tenue")],
         argent=28500, insignes=20, eclats=36, equip=910809,
         resume="Tiens les 10 vagues de la contre-attaque de Regthar.",
         intro="Maintenant, les dix vagues. La dernière porte Krom'zar lui-même.", prog="Les Kolkar approchent.",
         fin="Dix vagues ! Krom'zar est tombé. Porte ces jambières."),
    dict(q=q(28), cle="A28", famille="Défis", titre="Sans potion : la géoprêtresse", de=3418, a=3418,
         prev=HISTOIRE + 23, p=28, part=50, tuer=[(GUKKROK, 1, (-1907, -1753), None)], argent=14500, insignes=10,
         eclats=18, composants={OEIL_TENEBREUX: 1}, potion=GUKKROK,
         resume="Tue Gukk'rok renforcée sans utiliser ta potion pendant le combat.",
         intro="Gukk'rok revient chaque fois qu'Agama'gor est vidé, plus forte. Tue-la sans boire une goutte de "
               "potion. Son bouclier, ses soins, son totem : sans filet.",
         prog="Alors, sans potion ?", fin="Sans filet. Respect."),
    dict(q=q(29), cle="A29", famille="Défis", titre="Le sable qui grouille", de=3428, a=3428, prev=q(24), p=30,
         part=50, tuer=[(3253, 1, (-3122, -1742), None)], argent=22000, insignes=10, eclats=28,
         composants={ACIERITE: 2}, potion=3253,
         resume="Tue le Moissonneur silithide sans potion, pendant que le sable grouille.",
         intro="Le Moissonneur garde la ruche. Pendant le combat, une larve sort du sable sous tes pieds toutes les "
               "dix secondes : tue-la dès qu'elle sort. Et pas de potion.",
         prog="Le sable grouille encore.", fin="La ruche a perdu son gardien."),
    dict(q=q(30), cle="A30", famille="Défis", titre="Bael'dun en douze minutes", de=3341, a=3341, prev=HISTOIRE + 27,
         p=31, part=100, tuer=[(DOUBLENATTES, 1, (-4077, -2362), None)], argent=44000, insignes=20, eclats=55,
         equip_or=910810, chrono=([3376, 3377, 3378], 720, 600, 480),
         resume="Contre la montre : les 43 nains de Bael'dun puis Doublenattes renforcé. Bronze 12 min, argent 10 min, "
                "or 8 min.",
         intro="Le donjon le plus dense des Tarides. Le chrono part au premier nain tué : vide Bael'dun et tue "
               "Doublenattes renforcé en moins de douze minutes. En moins de huit, cette cotte est à toi.",
         prog="Bael'dun tient encore.", fin="Bael'dun est vidé. Reviens battre ton temps."),
]

# Vagues de la contre-attaque (A27) : (puissance, [(créature, nombre)]). Puissance fixée à l'invocation.
VAGUES = [
    (19, [(3272, 4)]), (19, [(3273, 3), (4316, 2)]), (20, [(3274, 4)]), (20, [(3275, 3), (3397, 2)]),
    (21, [(9524, 4), (9523, 1)]), (23, [(3266, 3), (3269, 2)]), (24, [(3258, 4), (3263, 1)]),
    (25, [(3385, 3), (3386, 2)]), (27, [(3278, 3), (3280, 2)]), (28, [(9456, 1), (9523, 2), (9524, 2)]),
]
EPREUVE_NOM, EPREUVE_CONSIGNE = "Contre-attaque", "Ne t'éloigne pas du poste."

# Reliques : (clé, nom, famille, objet copié pour l'icône, (x, y), indice, puissance, composant du secteur). Familles
# numérotées après celles de Durotar (0 à 2).
FAMILLES = [(3, "Rêve de Naralex"), (4, "Agammagan"), (5, "Les étrangers")]
SECTEURS = {"Croisée": LIN, "Oasis et côte": EGLANTINE, "Sud": SANG_ROYAL, "Extrême sud": LUNE}
RELIQUES = [
    ("A31", "Graine de rêve desséchée", 3, 5068, (90, -1943), "L'eau la plus pure s'est retirée. Elle a laissé une graine.", 16, "Croisée"),
    ("A32", "Lettre de Sarilus", 3, 889, (318, -2236), "Le garde du Refuge dort sur le courrier de son maître.", 17, "Croisée"),
    ("A33", "Fiole d'eau noire", 3, 1130, (-1276, -3012), "Là où les graines ont noirci.", 19, "Oasis et côte"),
    ("A34", "Écaille de croc druidique", 3, 537, (-1053, -2091), "Un serpent a mué près de la bête de l'oasis.", 22, "Oasis et côte"),
    ("A35", "Plume du disciple", 3, 555, (-760, -2120), "Le disciple a perdu une plume en montant à la grotte.", 21, "Oasis et côte"),
    ("A36", "Croc de serpent sculpté", 3, 893, (-243, -1307), "Un druide du Croc est venu chercher des disciples là où les taurens s'éprouvent.", 19, "Oasis et côte"),
    ("A37", "Défense d'Agammagan", 4, 771, (-214, -3308), "Kreenig gardait plus qu'une colline.", 16, "Croisée"),
    ("A38", "Épine de sang pétrifiée", 4, 5339, (-1907, -1753), "Là où la géoprêtresse vendait le sang du dieu.", 27, "Sud"),
    ("A39", "Totem Dos-hirsute renié", 4, 4451, (-2102, -2643), "Les ronces de l'ouest cachent un totem que la tribu a renié.", 25, "Sud"),
    ("A40", "Os du dieu-sanglier", 4, 2843, (-3186, -1970), "Les géants ne sont pas tous tombés debout.", 29, "Extrême sud"),
    ("A41", "Corne de guerre de Noirépine", 4, 1041, (-3829, -1446), "Lok n'a jamais soufflé dans la corne qu'il garde.", 30, "Extrême sud"),
    ("A42", "Journal du canonnier Smythe", 5, 916, (-2210, -3778), "Un canonnier note chaque navire qu'il a coulé.", 23, "Oasis et côte"),
    ("A43", "Médaille de Theramore ternie", 5, 734, (-1398, -4039), "La marée garde ce que la mer a rendu.", 21, "Oasis et côte"),
    ("A44", "Dague de flibustier", 5, 2946, (-1681, -4322), "Sur l'île, les flibustiers parient, et perdent parfois plus que de l'or.", 19, "Oasis et côte"),
    ("A45", "Pioche gravée de Bael'dun", 5, 2901, (-4142, -2196), "Une pioche de nain a creusé trop près de la gemme.", 29, "Extrême sud"),
    ("A46", "Carte de Khazgorm", 5, 1357, (-4080, -2355), "Le général garde la carte de ce qu'il a volé.", 31, "Extrême sud"),
]
# Bonus de famille : (famille, texte, objet par classe, cuivre, composant, nombre).
BONUS_FAMILLE = [
    (3, "une main gauche selon ta classe (Garde du rêve)", 910811, 0, 0, 0),
    (4, "des bottes (Bottes d'épine-de-sang)", 910812, 0, 0, 0),
    (5, "7 po et 2 Pierre de lune inférieure", 0, 70000, LUNE, 2),
]
# Carte des reliques (8.8 du comparatif) : celle de Durotar (30 Marques et 2 po), Marques × 1,5 (taille de la zone),
# or × facteur de puissance moyen de la zone (1 + (22 − 12) / 12 = 1,83, arrondi à 3 po 65 pa) ; même seuil de 8.
CARTE_MARQUES, CARTE_CUIVRE, CARTE_SEUIL = 45, 36500, 8

# Renforts des objets du monde : (objet du monde, créature, nombre, quêtes, puissance).
RENFORTS = [
    (161752, 3284, 2, [q(21), q(21, jour=True)], 18),                      # M18, seaux d'outils
    (4072, 3284, 2, [q(21, 2)], 19), (61935, 3284, 2, [q(21, 2)], 19), (61936, 3284, 2, [q(21, 2)], 19),   # valves
    (6906, 3256, 2, [q(22), q(22, jour=True)], 22), (6907, 3256, 2, [q(22), q(22, jour=True)], 22),
    (6908, 3256, 2, [q(22), q(22, jour=True)], 22),                        # M20, nids
    (3685, 3252, 2, [q(24), q(24, jour=True)], 29),                        # M19, antres
]
NIDS = (6906, 6907, 6908)                # goobers liés à la quête 905 d'origine (Data1) : libérés pour A22

# Cibles des primes et bêtes de Jorn : puissance fixe à leur annexe (brouillon §4.1.2 et 4.1.3) et réapparition en
# 15 min. (entrée, puissance, secteur)
FIXES = [
    (3470, 17, 1), (3270, 18, 1), (3394, 19, 2), (5830, 23, 2), (3452, 23, 2), (5864, 27, 3), (5841, 22, 2),
    (5838, 22, 2), (5828, 28, 3), (5859, 31, 4), (5851, 31, 4), (3253, 29, 4), (3474, 27, 3), (3473, 27, 3),
    (5834, 28, 3), (5832, 28, 3), (3472, 31, 4), (5827, 31, 4),
]
REAPPARITION = [e for e, _, _ in FIXES]

# Techniques sans SmartAI (solazeroth_v3_techniques) : (créature, genre, quête, a, b, c, sort, creature2).
TECHNIQUES_TABLE = [
    (BEAUMONT, 3, 0, 10000, 3000, 1500, 0, 28330),      # M4 feu des canons : zone marquée, 15 % de la vie
    (5841, 4, 0, 10, 50, 0, 0, 5838),                    # M12 frères d'armes : − 50 % à moins de 10 m
    (5838, 4, 0, 10, 50, 0, 0, 5841),
    (5864, 5, 0, 5, 0, 0, 0, 0),                         # M13 peau de piquants : 5 % des coups de mêlée renvoyés
    (LOK, 6, 0, 20, 10, 5, 0, 0),                        # M8 rage : + 10 % par Tranchecrin mort à 20 m, 5 fois
    (5851, 7, 0, 30000, 6000, 0, 15062, 0),              # M16 Mur protecteur toutes les 30 s, 6 s
    (3253, 8, q(29), 10000, 30, 0, 0, 3251),             # M22 sable grouillant : une larve (30) toutes les 10 s
]


# Techniques SmartAI (lignes 50 et suivantes), au format d'annexes_durotar.TECHNIQUES.
def invoquer(creature, entree, decalages, seuil, nom):
    return [(creature, 2, (0, seuil, 0, 0), 1, 12, (entree, 4, 15000, 1), 2, d, nom) for d in decalages]


TECHNIQUES = [
    (KREENIG, 9, (8, 25, 10000, 12000), 0, 11, (51756, 2, 0, 0), 2, (0, 0), "Kreenig renforcé - M1 - Charge des ronces"),
    *invoquer(KREENIG, 3269, [(4, 4)], 50, "Kreenig renforcé - M1 - Géomancienne"),
    *invoquer(KREENIG, 3266, [(-4, 4)], 50, "Kreenig renforcé - M1 - Défenseur"),
    (SARILUS, 0, (6000, 8000, 15000, 15000), 0, 11, (11831, 0, 0, 0), 1, (0, 0), "Sarilus renforcé - M2 - Nova de givre"),
    (SARILUS, 0, (9000, 11000, 16000, 16000), 0, 11, (11990, 0, 0, 0), 2, (0, 0), "Sarilus renforcé - M2 - Flammes des cendres"),
    (HEZRUL, 2, (0, 40, 0, 0), 1, 11, (8599, 0, 0, 0), 1, (0, 0), "Hezrul renforcé - M3 - Folie de l'oasis"),
    *invoquer(HEZRUL, 3397, [(4, 4), (-4, 4)], 50, "Hezrul renforcé - M3 - Sanguinaires"),
    *invoquer(BEAUMONT, 3385, [(4, 4), (-4, 4)], 50, "Beaumont renforcé - M4 - Soldats de marine"),
    (GUKKROK, 0, (8000, 8000, 25000, 25000), 0, 11, (4971, 0, 0, 0), 1, (0, 0), "Gukk'rok renforcée - M5 - Totem d'épine de sang"),
    (3253, 0, (5000, 7000, 15000, 15000), 0, 11, (6253, 0, 0, 0), 2, (0, 0), "Moissonneur - M6 - Revers"),
    *invoquer(3253, 3251, [(4, 4), (-4, 4)], 50, "Moissonneur - M6 - Larves (50 %)"),
    *invoquer(3253, 3251, [(4, -4), (-4, -4)], 25, "Moissonneur - M6 - Larves (25 %)"),
    (DOUBLENATTES, 0, (7000, 9000, 15000, 15000), 0, 11, (11990, 0, 0, 0), 2, (0, 0), "Doublenattes renforcé - M7 - Poudre de Bael'dun"),
    *invoquer(DOUBLENATTES, 3377, [(4, 4), (-4, 4)], 50, "Doublenattes renforcé - M7 - Fusiliers"),
    (LOK, 2, (0, 30, 0, 0), 1, 11, (8599, 0, 0, 0), 1, (0, 0), "Lok renforcé - M8 - Enragement"),
    (3470, 0, (4000, 4000, 10000, 10000), 0, 11, (13737, 0, 0, 0), 2, (0, 0), "Rathorian - M9 - Frappe mortelle répétée"),
    (3470, 2, (0, 30, 0, 0), 1, 11, (8599, 0, 0, 0), 1, (0, 0), "Rathorian - M9 - Enragement"),
    (3270, 0, (6000, 6000, 25000, 25000), 0, 11, (4971, 0, 0, 0), 1, (0, 0), "Ancienne mystique - M10 - Totem guérisseur"),
    (3270, 2, (0, 50, 15000, 15000), 0, 11, (959, 0, 0, 0), 1, (0, 0), "Ancienne mystique - M10 - Vague de soins renforcée"),
    (5830, 0, (6000, 8000, 15000, 15000), 0, 11, (6982, 0, 0, 0), 2, (0, 0), "Soeur Rathtalon - M11 - Bourrasque"),
    *invoquer(5830, 3278, [(4, 4), (-4, 4)], 50, "Soeur Rathtalon - M11 - Tueuses"),
    (3452, 0, (6000, 8000, 15000, 15000), 0, 11, (6982, 0, 0, 0), 2, (0, 0), "Serena - M11 - Bourrasque"),
    *invoquer(3452, 3278, [(4, 4), (-4, 4)], 50, "Serena - M11 - Tueuses"),
    (5864, 2, (0, 50, 0, 0), 1, 11, (51756, 2, 0, 0), 2, (0, 0), "Pourcegart - M13 - Ruée"),
    (5828, 0, (3000, 4000, 6000, 6000), 0, 11, (14331, 0, 0, 0), 2, (0, 0), "Humar - M14 - Saignement cumulable"),
    *invoquer(5828, 3416, [(4, 4), (-4, 4)], 60, "Humar - M14 - Rugissement"),
    *invoquer(5859, 3459, [(4, 4), (-4, 4)], 50, "Hagg - M15 - Frénétiques"),
    (5859, 2, (0, 30, 0, 0), 1, 11, (8599, 0, 0, 0), 1, (0, 0), "Hagg - M15 - Enragement"),
    *[(b, 2, (0, 30, 0, 0), 1, 11, (28371, 0, 0, 0), 1, (0, 0), "Bête de Jorn - M17 - Fureur de la bête")
      for b in (3474, 3473, 5834, 5832, 3472, 5827)],
    (3415, 4, (0, 0, 0, 0), 0, 39, (15, 0, 0, 0), 1, (0, 0), "Chasseresse des savanes - M21 - Appel de la meute"),
    (3425, 4, (0, 0, 0, 0), 0, 39, (15, 0, 0, 0), 1, (0, 0), "Rôdeur des savanes - M21 - Appel de la meute"),
]
# Créatures sans SmartAI qui en reçoivent un (table de retour : solazeroth_v3_t4_origine_creatures).
SANS_IA = (KREENIG, 5864, 3474, 3472, 3415)

# Donneurs d'annexes sans point d'exclamation depuis le lot T2 (faux indicateurs) : le drapeau leur revient.
DONNEURS_SANS_DRAPEAU = (3292, 3449, 9316)

# Tableaux des primes : (objet du monde, nom, (x, y), orientation).
TABLEAUX = [(TABLEAU_CROISEE, "Tableau des primes de la Croisée", (-469, -2598), 1.6),
            (TABLEAU_TAURAJO, "Tableau des primes du Camp Taurajo", (-2343, -1929), 3.1)]
