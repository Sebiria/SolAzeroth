"""v3, F5e (31/10/2026, demande de l'utilisateur : « finis totalement de programmer les objectifs de zone ») : les
annexes de Durotar qui restaient, A11 à A46 (document de Durotar, §4.1.2 à 4.1.6).

- Primes (A11-A19), contrats (A20-A24) et défis (A25-A30) sont de vraies quêtes (910211 et suivantes ; palier 2 :
  +100, palier 3 : +200, répétition journalière d'un contrat : +300). Leur part de zone (genre 4 de
  solazeroth_v3_zone_parts) est gagnée à la première fois qu'elles sont rendues. Les Insignes, les éclats et les
  composants vont dans la Collection, par le serveur (v3_annexes.cpp, table solazeroth_v3_annexes) ; l'or et
  l'équipement sont des récompenses de quête ordinaires.
- Reliques (A31-A46) : 16 objets du monde (script go_solazeroth_v3_relique) qui rangent leur relique dans la
  Collection ; part de zone (genre 5) dès qu'on l'a.
- Techniques des monstres (T6-T13, T16, T18) : lignes SmartAI 50 et suivantes. T14 (carapace), T15 (sang gangrené),
  T17 (orage), chrono et médailles, « sans potion », vagues de l'épreuve, raptors des œufs et trolls des monceaux :
  v3_annexes.cpp.

Écrit la migration 084, interface-v3\\FrameXML\\SolUI_Annexes.lua (annexes, reliques et leurs indices, catégorie
« Durotar » de la Collection) ; quetes_durotar.item_dbc() ajoute les nouveaux objets à l'Item.dbc du patch.
Lit la base (lecture seule) pour la hauteur des reliques et des PNJ.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from quetes_durotar import CARTE_DUROTAR, DUROTAR, ECLAT, octogone, s, sql

MIGRATION = r"C:\SolAzeroth\sql\migrations\084_v3_annexes_durotar"
LUA = r"C:\SolAzeroth\interface-v3\FrameXML\SolUI_Annexes.lua"

INSIGNE = 910140
COTE, VIANDE = 910141, 910142
MATRIARCHE, DENT, GUEULE, ZUNJALA, ECHO = 910020, 910021, 910022, 910023, 910024
CREDIT_BETES, CREDIT_VAGUE5, CREDIT_VAGUE10 = 910025, 910026, 910028
TABLEAU_TRANCHE, TABLEAU_SENJIN = 910010, 910011
LIN, CUIR, FEUILLARGENT, PACIFIQUE, TERRESTRINE, MAGE_ROYAL = 2589, 2318, 765, 2447, 2449, 785
CUIVRE, MALACHITE, OEIL_TIGRE, OEIL_TENEBREUX = 2770, 774, 818, 1210
GUID_CREATURE, GUID_GO = 9100010, 9100010
GO_RELIQUE = 910020
RELIQUE = 910150

# Pièces d'équipement des annexes : (entrée, nom, objet d'origine pour l'apparence et le type, puissance)
PIECES = [
    (910121, "Cape de chitine de la matriarche", 2310, 4),
    (910122, "Pavois de la garde de Tiragarde", 2376, 7),
    (910123, "Ceinture en peau de requin", 5328, 11),
    (910124, "Cape du gangretisseur", 4963, 11),
    (910125, "Masse du capitaine Plate-défense", 2844, 11),
    (910126, "Gantelets en chitine d'écorcheur", 3472, 10),
    (910127, "Brassards de Rhinag", 2853, 11),
    (910128, "Bottes des remparts", 3469, 7),
    (910129, "Jambières de l'épreuve", 2694, 11),
    (910130, "Cuirasse de la purge", 3471, 11),
    (910131, "Rempart de cendre", 5302, 11),
    (910132, "Sandales de Sen'jin", 5320, 10),
]

# Quêtes. de / a : PNJ (entier) ou objet du monde ("go", entrée). tuer : (créature, nombre, centre, texte ou None) ;
# go : (objet du monde, nombre, centre, texte) ; objets : (objet, nombre, centre). part : centièmes de % (0 pour une
# répétition). chrono : (créatures qui lancent le chrono, bronze, argent, or en secondes). potion : créature contre
# laquelle la potion est interdite. equip_or : pièce donnée à la première médaille d'or.
TRANCHE, SENJIN = ("go", TABLEAU_TRANCHE), ("go", TABLEAU_SENJIN)
A = [
    dict(q=910211, cle="A11", famille="Primes", titre="La matriarche des scorpides", de=3287, a=3287, prev=910006, p=5,
         part=75, tuer=[(MATRIARCHE, 1, (-432, -4217), None)], argent=4500, insignes=15, eclats=6, equip=910121,
         resume="Tue la Matriarche des scorpides, dans la crevasse à l'est du champ des scorpides ouvriers.",
         intro="Sarkoth avait une compagne, plus vieille et plus grosse. Elle niche dans la crevasse, à l'est du champ "
               "des ouvriers. Sa piqûre ronge l'armure, et quand elle souffre, ses ouvriers accourent. Reviens quand tu "
               "seras mieux $Géquipé:équipée;, si tu tiens à ta peau.",
         prog="La matriarche vit encore ?", fin="Elle est morte. La Vallée dormira mieux. Prends ceci, taillé dans sa chitine."),
    dict(q=910212, cle="A12", famille="Primes", titre="Le commandant de la garde", de=TRANCHE, a=TRANCHE, p=7, part=125,
         tuer=[(5809, 1, (-227, -5094), None)], argent=12500, insignes=25, eclats=15, equip=910122,
         resume="Tue le Commandant de la garde Zalaphil, au Donjon de Tiragarde.",
         intro="AVIS DE RECHERCHE. Le Commandant de la garde Zalaphil tient le Donjon de Tiragarde. Il lève son rempart "
               "toutes les trente secondes et appelle ses marins quand il faiblit. Frappez fort entre deux remparts.",
         prog="La prime attend toujours son chasseur.", fin="Zalaphil est tombé. L'équipement de la garde est à toi."),
    dict(q=910213, cle="A13", famille="Primes", titre="Dent-de-l'Écho", de=SENJIN, a=SENJIN, p=11, part=125,
         tuer=[(DENT, 1, (-1385, -5780), None)], argent=15000, insignes=25, eclats=19, equip=910123,
         resume="Tue Dent-de-l'Écho, en eau profonde au sud des Îles de l'Écho.",
         intro="AVIS DE RECHERCHE. Un requin du sable énorme rôde au sud des Îles de l'Écho. Il entraîne ses proies au "
               "fond et devient fou quand il saigne. Les pêcheurs l'appellent Dent-de-l'Écho.",
         prog="Le requin nage toujours.", fin="Dent-de-l'Écho ne mangera plus personne. Une ceinture dans sa peau, pour toi."),
    dict(q=910214, cle="A14", famille="Primes", titre="Le renégat de la grève", de=SENJIN, a=SENJIN, p=9, part=100,
         tuer=[(13157, 1, (-529, -5216), None)], argent=10000, insignes=20, eclats=12,
         composants={MAGE_ROYAL: 2, OEIL_TENEBREUX: 1},
         resume="Tue Makasgar, au bout de la Grève des Sombrelances.",
         intro="AVIS DE RECHERCHE. Makasgar, un troll chassé de Sen'jin, rançonne nos pêcheurs. Il maudit ceux qui "
               "l'approchent et plante un totem qui le soigne : brisez-le.",
         prog="Makasgar compte toujours ses prises.", fin="Le renégat ne volera plus personne. Voici la prime."),
    dict(q=910215, cle="A15", famille="Primes", titre="La géomaîtresse", de=TRANCHE, a=TRANCHE, p=10, part=100,
         tuer=[(5826, 1, (424, -4245), None)], argent=12000, insignes=20, eclats=15,
         composants={TERRESTRINE: 3, OEIL_TIGRE: 1},
         resume="Tue la Géomaîtresse Mouchette, au Kraal des Tranchecrins.",
         intro="AVIS DE RECHERCHE. La Géomaîtresse Mouchette commande le Kraal des Tranchecrins. Sa vague de soins doit "
               "être coupée, et son totem vous cloue au sol. Elle est au milieu de ses gardes de guerre.",
         prog="La géomaîtresse tient toujours le kraal.", fin="Mouchette est morte. Les Tranchecrins sont sans chef."),
    dict(q=910216, cle="A16", famille="Primes", titre="Le gangretisseur", de=TRANCHE, a=TRANCHE, p=11, part=150,
         tuer=[(5822, 1, (1492, -4753), None)], argent=18000, insignes=30, eclats=22, equip=910124,
         resume="Tue le Gangretisseur Arrogg, au Rocher du crâne.",
         intro="AVIS DE RECHERCHE. Le Gangretisseur Arrogg fait pleuvoir le feu sur le Rocher du crâne et appelle un "
               "traqueur gangrené quand il faiblit. Sortez du feu, et visez la tête.",
         prog="Arrogg vit encore.", fin="Le gangretisseur est mort. Sa cape ne lui servira plus."),
    dict(q=910217, cle="A17", famille="Primes", titre="Le capitaine Plate-défense", de=TRANCHE, a=TRANCHE, p=11, part=125,
         tuer=[(5824, 1, (-94, -4011), None)], argent=15000, insignes=25, eclats=19, equip=910125,
         resume="Tue le Capitaine Plate-défense, sur le plateau au nord de la Vallée.",
         intro="AVIS DE RECHERCHE. Le Capitaine Plate-défense charge et rameute tous ses gardes à trente pas. Videz son "
               "camp d'abord, ou tenez tout le monde.",
         prog="Le capitaine commande toujours son camp.", fin="Plate-défense est tombé. Sa masse est à toi."),
    dict(q=910218, cle="A18", famille="Primes", titre="L'écorcheur mortel", de=TRANCHE, a=TRANCHE, p=10, part=100,
         tuer=[(5823, 1, (7, -3980), None)], argent=12000, insignes=20, eclats=15, equip=910126,
         resume="Tue l'Écorcheur mortel, sur le plateau au nord de la Vallée.",
         intro="AVIS DE RECHERCHE. L'Écorcheur mortel est un scorpide géant. Son venin se cumule et ses coups sonnent. "
               "Un combat d'usure : gardez votre potion.",
         prog="L'écorcheur rôde encore.", fin="L'écorcheur est mort. Voici des gantelets taillés dans sa chitine."),
    dict(q=910219, cle="A19", famille="Primes", titre="Gueule-de-gangrène", de=TRANCHE, a=TRANCHE, p=10, part=100,
         tuer=[(GUEULE, 1, (-49, -3774), None)], argent=12000, insignes=20, eclats=15,
         composants={CUIR: 6, OEIL_TENEBREUX: 1},
         resume="Tue Gueule-de-gangrène, à l'extrémité ouest de la Furie-du-Sud.",
         intro="AVIS DE RECHERCHE. Un crocilisque corrompu chasse à l'ouest de la Furie-du-Sud. Sa morsure brûle et sa "
               "roulade assomme. La bête qui a pris Kron, peut-être.",
         prog="Gueule-de-gangrène vit toujours.", fin="La bête est morte. Kron est vengé, peut-être."),

    dict(q=910220, cle="A20", famille="Contrats", titre="La marmite de Tranchecolline", de=3191, a=3191, p=6, part=50,
         objets=[(VIANDE, 10, (135, -4601))], argent=3000, insignes=10, eclats=4, composants={CUIR: 4},
         resume="Rapporte 10 Morceaux de viande de sanglier redoutable au Cuisinier Torka.",
         intro="La caserne a faim. Les Sangliers tachetés redoutables autour de Tranchecolline font la meilleure viande, "
               "mais ils vivent en hardes : en frapper un, c'est les avoir tous sur le dos. Dix morceaux.",
         prog="Ma marmite est vide.", fin="Belle viande ! La caserne mangera ce soir."),
    dict(q=910320, cle="A20", famille="Contrats", titre="La marmite de Tranchecolline (2)", de=3191, a=3191, prev=910220,
         p=9, part=50, objets=[(COTE, 10, (846, -4374))], argent=5000, insignes=10, eclats=6, composants={CUIR: 4},
         resume="Rapporte 10 Côtes d'ancien sanglier au Cuisinier Torka.",
         intro="Pour un vrai festin, il me faut des côtes d'Anciens sangliers tachetés, au nord. Plus gros, plus "
               "têtus, et toujours en harde.", prog="Et ces côtes ?", fin="Voilà de quoi tenir un siège !"),
    dict(q=910520, cle="A20", famille="Contrats", titre="La marmite de Tranchecolline (jour)", de=3191, a=3191,
         prev=910320, p=9, part=0, journaliere=True, objets=[(VIANDE, 5, (135, -4601)), (COTE, 5, (846, -4374))],
         argent=2000, insignes=5, eclats=0, composants={CUIR: 2},
         resume="Rapporte 5 morceaux de viande redoutable et 5 côtes d'ancien sanglier au Cuisinier Torka.",
         intro="La marmite se vide tous les jours. Cinq morceaux, cinq côtes.", prog="La marmite attend.",
         fin="Merci. À demain !"),

    dict(q=910221, cle="A21", famille="Contrats", titre="Les anciens de la côte", de=3147, a=3147, p=8, part=50,
         tuer=[(3141, 2, (446, -5187), None)], argent=5000, insignes=10, eclats=6, composants={MALACHITE: 1},
         resume="Tue 2 Anciens makrura, à la Côte des naufrages et au Rivage d'Œil-mort.",
         intro="Quatre vieux makruras règnent sur la côte. Tant qu'ils vivent, les clampants y grouillent. Leur "
               "carapace arrête la moitié des coups : assomme-les pour la briser. Commence par les deux du sud.",
         prog="Les anciens vivent encore ?", fin="Deux de moins. La côte respire."),
    dict(q=910321, cle="A21", famille="Contrats", titre="Les anciens de la côte (2)", de=3147, a=3147, prev=910221, p=9,
         part=50, tuer=[(3141, 2, (1290, -5100), None)], argent=5000, insignes=10, eclats=6, composants={OEIL_TIGRE: 1},
         resume="Tue les 2 Anciens makrura de la Baie de Lamepoing.",
         intro="Les deux derniers sont dans la Baie de Lamepoing, tout à l'est.", prog="Et la baie ?",
         fin="Les quatre anciens sont morts. Bien joué."),
    dict(q=910521, cle="A21", famille="Contrats", titre="Les anciens de la côte (jour)", de=3147, a=3147, prev=910321,
         p=9, part=0, journaliere=True, tuer=[(3141, 2, (900, -5150), None)], argent=2500, insignes=5, eclats=0,
         composants={MALACHITE: 1}, resume="Tue 2 Anciens makrura sur la côte est.",
         intro="Les anciens repoussent comme la marée. Deux de plus.", prog="La marée monte.", fin="Merci."),

    dict(q=910222, cle="A22", famille="Contrats", titre="Des œufs pour la marmite", de=3191, a=3191, p=9, part=100,
         objets=[(4890, 6, (-1017, -5423))], argent=10000, insignes=20, eclats=12, composants={CUIR: 4},
         resume="Rapporte 6 Œufs de fouette-queue des Îles de l'Écho au Cuisinier Torka.",
         intro="Les œufs de fouette-queue des Îles de l'Écho font une omelette de chef. Mais les nids sont couvés : "
               "chaque œuf pris fait accourir deux raptors.", prog="Pas d'œufs, pas d'omelette.",
         fin="Six œufs entiers ! Tu as la main légère."),
    dict(q=910522, cle="A22", famille="Contrats", titre="Des œufs pour la marmite (jour)", de=3191, a=3191, prev=910222,
         p=9, part=0, journaliere=True, objets=[(4890, 6, (-1017, -5423))], argent=2500, insignes=5, eclats=0,
         composants={CUIR: 2}, resume="Rapporte 6 Œufs de fouette-queue au Cuisinier Torka.",
         intro="L'omelette a plu. Six œufs encore.", prog="Les œufs ?", fin="Merci !"),

    dict(q=910223, cle="A23", famille="Contrats", titre="La traque des corrompus", de=3190, a=3190, p=10, part=50,
         tuer=[(CREDIT_BETES, 4, (700, -4100), "Bêtes corrompues tuées")], argent=6000, insignes=10, eclats=8,
         resume="Tue 4 bêtes corrompues dans le nord de Durotar.",
         intro="Les bêtes à l'éclat vert. Sangliers, scorpides, raptors, clampants : il faut les abattre toutes, une "
               "par une. Leur sang brûle encore après leur mort : ne reste pas dedans.",
         prog="Combien en as-tu abattu ?", fin="Quatre. Il en reste."),
    dict(q=910323, cle="A23", famille="Contrats", titre="La traque des corrompus (2)", de=3190, a=3190, prev=910223,
         p=10, part=50, tuer=[(CREDIT_BETES, 4, (700, -4100), "Bêtes corrompues tuées")], argent=6000, insignes=10,
         eclats=8, resume="Tue 4 autres bêtes corrompues.", intro="Quatre de plus. Elles sont partout au nord.",
         prog="Continue.", fin="Huit. Encore un effort."),
    dict(q=910423, cle="A23", famille="Contrats", titre="La traque des corrompus (3)", de=3190, a=3190, prev=910323,
         p=11, part=100, tuer=[(CREDIT_BETES, 4, (700, -4100), "Bêtes corrompues tuées")], argent=12000, insignes=20,
         eclats=15, equip=910127, resume="Tue les 4 dernières bêtes corrompues.",
         intro="Les dernières sont les plus loin. Trouve-les.", prog="Il en reste quatre.",
         fin="Les douze sont tombées. Porte ces brassards : ils sont à toi."),
    dict(q=910523, cle="A23", famille="Contrats", titre="La traque des corrompus (jour)", de=3190, a=3190, prev=910423,
         p=11, part=0, journaliere=True, tuer=[(CREDIT_BETES, 4, (700, -4100), "Bêtes corrompues tuées")], argent=3000,
         insignes=5, eclats=0, composants={OEIL_TENEBREUX: 1}, resume="Tue 4 bêtes corrompues.",
         intro="La corruption revient. Quatre bêtes.", prog="Alors ?", fin="Merci."),

    dict(q=910224, cle="A24", famille="Contrats", titre="Les fétiches de Zalazane", de=11814, a=11814, p=10, part=100,
         go=[(102986, 7, (-1162, -5548), "Monceaux Ju-Ju détruits")], argent=12000, insignes=20, eclats=15,
         composants={PACIFIQUE: 2, MAGE_ROYAL: 2},
         resume="Détruis les 7 Monceaux Ju-Ju du fief de Zalazane.",
         intro="Les monceaux ju-ju de Zalazane tiennent ses trolls maléficiés sous son emprise. Détruis-les tous. "
               "Méfie-toi : chaque monceau brisé libère un troll fou de rage.",
         prog="Les fétiches tiennent toujours ?", fin="Les sept monceaux sont tombés. Zalazane a perdu des esclaves."),
    dict(q=910524, cle="A24", famille="Contrats", titre="Les fétiches de Zalazane (jour)", de=11814, a=11814,
         prev=910224, p=10, part=0, journaliere=True, go=[(102986, 7, (-1162, -5548), "Monceaux Ju-Ju détruits")],
         argent=3000, insignes=5, eclats=0, composants={MAGE_ROYAL: 1}, resume="Détruis les 7 Monceaux Ju-Ju.",
         intro="Zalazane rebâtit ses monceaux chaque nuit.", prog="Alors ?", fin="Merci."),

    dict(q=910225, cle="A25", famille="Défis", titre="Le Convent en cinq minutes", de=3145, a=3145, prev=910007, p=3,
         part=50, tuer=[(3101, 10, (-95, -4285), None), (3102, 10, (-95, -4285), None), (3183, 1, (-58, -4221), None)],
         argent=1500, insignes=10, eclats=3, composants={LIN: 2}, chrono=([3101, 3102], 300, 240, 180),
         resume="Contre la montre : 20 démons du Convent puis Yarrog. Bronze 5 min, argent 4 min, or 3 min.",
         intro="Tu sais tuer des démons. Mais vite ? Le chrono part au premier démon : vingt démons, puis Yarrog, en "
               "moins de cinq minutes. Regroupe-les par paquets.",
         prog="Le temps file.", fin="Voilà qui est rapide. Reviens battre ton temps quand tu veux."),
    dict(q=910226, cle="A26", famille="Défis", titre="L'assaut des remparts", de=3139, a=3139, prev=910012, p=7, part=75,
         tuer=[(3192, 1, (-246, -5120), None)], argent=4500, insignes=15, eclats=6, equip_or=910128,
         chrono=([3128, 3129], 360, 270, 210),
         resume="Contre la montre : tue le Lieutenant Benedict moins de 6 min après le premier humain tué au donjon "
                "(argent 4 min 30, or 3 min 30).",
         intro="Un assaut se mène vite. Le chrono part au premier humain tué dans le donjon : traverse la cour et la "
               "tour, et tue Benedict en moins de six minutes. En moins de trois minutes trente, je te donne mes bottes.",
         prog="Plus vite !", fin="Un vrai assaut. Reviens quand tu veux faire mieux."),
    dict(q=910227, cle="A27", famille="Défis", titre="L'épreuve des esprits", de=ZUNJALA, a=ZUNJALA, p=7, part=75,
         tuer=[(CREDIT_VAGUE5, 1, (-883, -4295), "Vague 5 de l'épreuve tenue")], argent=7500, insignes=15, eclats=9,
         resume="Parle à Zun'jala pour lancer l'épreuve, et tiens jusqu'à la vague 5.",
         intro="Les esprits de la terre rouge jugent les gardiens. Dix vagues, de plus en plus dures, vingt secondes de "
               "répit entre deux. Tiens cinq vagues pour commencer. Dis-moi quand tu es $Gprêt:prête;.",
         prog="Les esprits attendent.", fin="Cinq vagues. Les esprits t'ont vu."),
    dict(q=910327, cle="A27", famille="Défis", titre="L'épreuve des esprits (2)", de=ZUNJALA, a=ZUNJALA, prev=910227,
         p=11, part=100, tuer=[(CREDIT_VAGUE10, 1, (-883, -4295), "Vague 10 de l'épreuve tenue")], argent=12000,
         insignes=20, eclats=15, equip=910129, resume="Tiens les 10 vagues de l'épreuve de Zun'jala.",
         intro="Maintenant, les dix vagues. La dernière porte l'écho de Kolkanis.", prog="Les esprits attendent.",
         fin="Dix vagues ! Les esprits te reconnaissent. Porte ces jambières, gardien."),
    dict(q=910228, cle="A28", famille="Défis", titre="Sans potion : Zalazane", de=3188, a=3188, prev=910020, p=10,
         part=50, tuer=[(910013, 1, (-1287, -5534), None)], argent=6000, insignes=10, eclats=8,
         composants={OEIL_TENEBREUX: 1}, potion=910013,
         resume="Tue Zalazane renforcé sans utiliser ta potion pendant le combat.",
         intro="Zalazane revient chaque fois que son fief est vidé, plus fort. Tue-le sans boire une goutte de potion. "
               "Sinon, ce n'est pas un vrai combat.", prog="Alors, sans potion ?", fin="Sans filet. Respect."),
    dict(q=910229, cle="A29", famille="Défis", titre="L'orage sans abri", de=3208, a=3208, prev=910024, p=10, part=50,
         tuer=[(3203, 1, (869, -4190), None)], argent=6000, insignes=10, eclats=8, composants={TERRESTRINE: 2},
         potion=3203, resume="Tue Féplouf Sombrorage sans potion, sous l'orage : quitte les zones marquées.",
         intro="Féplouf appelle l'orage sur les Falaises du Tonnerre. Pendant le combat, la foudre frappe là où le sol "
               "s'illumine : bouge. Et pas de potion.", prog="L'orage gronde encore.", fin="Tu as dansé avec la foudre."),
    dict(q=910230, cle="A30", famille="Défis", titre="Le Rocher du crâne en douze minutes", de=3208, a=3208,
         prev=910025, p=11, part=100, tuer=[(910014, 1, (1469, -4705), None)], argent=12000, insignes=20, eclats=15,
         equip_or=910130, chrono=([3197, 3198], 720, 600, 480),
         resume="Contre la montre : 32 sectateurs puis Gazz'uz renforcé. Bronze 12 min, argent 10 min, or 8 min.",
         intro="Le cœur du culte. Le chrono part au premier sectateur tué : vide le Rocher du crâne et tue Gazz'uz "
               "renforcé en moins de douze minutes. En moins de huit, ma meilleure cuirasse est à toi.",
         prog="Le culte tient encore.", fin="Le Rocher est purgé. Reviens battre ton temps."),
]

# Vagues de l'épreuve (A27) : (créature, nombre)
VAGUES = [
    [(3119, 4)], [(3119, 3), (3120, 2)], [(3120, 4)], [(3112, 3), (3113, 2)], [(3114, 4)],
    [(3121, 3), (3122, 3)], [(3196, 5), (3199, 2)], [(3118, 4)], [(3227, 2), (3226, 2)], [(ECHO, 1), (3120, 4)],
]

# Reliques : (clé, nom, famille, objet copié, (x, y), indice, puissance, composant du secteur)
FAMILLES = ["Lame ardente", "Kul Tiras", "Sombrelances"]
RELIQUES = [
    ("A31", "Dague rituelle ébréchée", 0, 2092, (-58, -4221), "Là où Yarrog parlait à ses chiens, la roche garde une lame.", 3, LIN),
    ("A32", "Lettre de recrutement de la Lame", 0, 4881, (-547, -4104), "Le grand scorpide ne gardait pas que sa colline.", 3, LIN),
    ("A33", "Collier éteint", 0, 4859, (908, -4732), "Au plus profond du repaire, un collier ne brûle plus.", 10, OEIL_TIGRE),
    ("A34", "Bougie de suif noir", 0, 4986, (1010, -4010), "Là où l'orage frappe en premier.", 10, OEIL_TIGRE),
    ("A35", "Ordres scellés", 0, 1972, (1247, -4531), "Les pourceaux ne sont pas seuls à fouiller la ferme.", 9, OEIL_TIGRE),
    ("A36", "Masque de cendre", 0, 1532, (1492, -4753), "Le gangretisseur dort sur ce qu'il a volé.", 11, OEIL_TIGRE),
    ("A37", "Longue-vue de l'amiral", 1, 5054, (-246, -5120), "Le lieutenant guette la mer avec la longue-vue d'un mort.", 6, CUIR),
    ("A38", "Journal de bord détrempé", 1, 5520, (-35, -5284), "Les gnomes n'ont pas tout perdu dans le naufrage, les humains non plus.", 5, CUIR),
    ("A39", "Bouteille à la mer", 1, 5806, (916, -5133), "La marée rend ce que la mer refuse.", 9, OEIL_TIGRE),
    ("A40", "Insigne de déserteur", 1, 735, (1371, -5013), "Un soldat de marine a déserté jusqu'au bout de la terre, à l'est.", 10, OEIL_TIGRE),
    ("A41", "Lettre pour Theramore", 1, 3898, (717, -4469), "Un messager humain a voulu couper par le canyon. Les harpies l'ont trouvé avant nous.", 6, CUIR),
    ("A42", "Totem de Sen'jin volé", 2, 1533, (-1057, -4596), "Les centaures ont volé plus que des cartes.", 9, MAGE_ROYAL),
    ("A43", "Masque d'offrande", 2, 3317, (-733, -5600), "Un vieil autel, sur un îlot que Zalazane évite.", 9, MAGE_ROYAL),
    ("A44", "Défense de raptor sculptée", 2, 2799, (-893, -4285), "Les esprits de la terre rouge gardent un présent troll.", 8, MAGE_ROYAL),
    ("A45", "Collier de perles de la grève", 2, 5382, (-529, -5216), "Au bout de la grève, là où le renégat compte ses prises.", 9, MAGE_ROYAL),
    ("A46", "Fétiche de jade", 2, 5104, (-1385, -5780), "Le requin de l'Écho a avalé plus d'une offrande.", 11, MAGE_ROYAL),
]
BONUS_FAMILLE = {0: "une main gauche selon ta classe (Rempart, Orbe ou Dague de cendre)", 1: "3 po et 2 Œil ténébreux", 2: "des bottes (Sandales de Sen'jin)"}

# Techniques (lignes SmartAI 50 et suivantes) : (créature, événement, paramètres d'événement, drapeaux, action,
# paramètres d'action, cible, décalage (x, y), commentaire). Événements : 0 en combat (délai min/max, répétition
# min/max), 2 vie entre min et max % (puis répétition min/max), 4 entrée en combat. Actions : 11 sort, 12 invoquer
# (créature, 4 = disparaît hors combat, durée, attaquer), 39 appel à l'aide (rayon). Cibles : 1 soi, 2 sa cible.
def invoquer(creature, entree, decalages, seuil, nom):
    return [(creature, 2, (0, seuil, 0, 0), 1, 12, (entree, 4, 15000, 1), 2, d, nom) for d in decalages]


TECHNIQUES = [
    (3099, 4, (0, 0, 0, 0), 0, 39, (15, 0, 0, 0), 1, (0, 0), "Sanglier redoutable - T16 - Appel de la harde"),
    (3100, 4, (0, 0, 0, 0), 0, 39, (15, 0, 0, 0), 1, (0, 0), "Ancien sanglier - T16 - Appel de la harde"),
    (5809, 0, (5000, 5000, 30000, 30000), 0, 11, (871, 2, 0, 0), 1, (0, 0), "Zalaphil - T6 - Rempart de la garde"),
    *invoquer(5809, 3128, [(4, 4), (-4, 4)], 60, "Zalaphil - T6 - Cri de ralliement"),
    (5826, 2, (0, 50, 12000, 12000), 0, 11, (8004, 0, 0, 0), 1, (0, 0), "Mouchette - T7 - Vague de soins"),
    (5826, 0, (8000, 8000, 20000, 20000), 0, 11, (2484, 0, 0, 0), 1, (0, 0), "Mouchette - T7 - Totem ralentissant"),
    (5822, 0, (7000, 9000, 15000, 15000), 0, 11, (11990, 0, 0, 0), 2, (0, 0), "Arrogg - T8 - Pluie de feu"),
    *invoquer(5822, 3102, [(4, 4)], 50, "Arrogg - T8 - Traqueur"),
    (5824, 4, (0, 0, 0, 0), 0, 11, (51756, 2, 0, 0), 2, (0, 0), "Plate-défense - T9 - Charge (étourdit, sans les +75 de 22120)"),
    (5824, 4, (0, 0, 0, 0), 0, 39, (30, 0, 0, 0), 1, (0, 0), "Plate-défense - T9 - Cri de commandement"),
    (5823, 0, (6000, 8000, 18000, 18000), 0, 11, (6253, 0, 0, 0), 2, (0, 0), "Écorcheur - T10 - Ressort sous le joueur"),
    (5823, 0, (3000, 3000, 8000, 8000), 0, 11, (744, 0, 0, 0), 2, (0, 0), "Écorcheur - T10 - Venin"),
    (DENT, 0, (4000, 6000, 12000, 12000), 0, 11, (3604, 0, 0, 0), 2, (0, 0), "Dent-de-l'Écho - T11 - Entraîner au fond"),
    (DENT, 2, (0, 30, 0, 0), 1, 11, (8269, 0, 0, 0), 1, (0, 0), "Dent-de-l'Écho - T11 - Frénésie"),
    (GUEULE, 0, (3000, 5000, 10000, 10000), 0, 11, (13443, 0, 0, 0), 2, (0, 0), "Gueule-de-gangrène - T12 - Morsure"),
    (GUEULE, 0, (8000, 10000, 20000, 20000), 0, 11, (5164, 0, 0, 0), 2, (0, 0), "Gueule-de-gangrène - T12 - Roulade"),
    (13157, 0, (2000, 4000, 20000, 20000), 0, 11, (702, 0, 0, 0), 2, (0, 0), "Makasgar - T13 - Malédiction"),
    (13157, 0, (8000, 8000, 30000, 30000), 0, 11, (4971, 0, 0, 0), 1, (0, 0), "Makasgar - T13 - Totem guérisseur"),
    (MATRIARCHE, 0, (3000, 5000, 8000, 8000), 0, 11, (11971, 0, 0, 0), 2, (0, 0), "Matriarche - T18 - Piqûre affaiblissante"),
    *invoquer(MATRIARCHE, 3124, [(4, 4), (-4, 4), (0, -5)], 50, "Matriarche - T18 - Ouvriers"),
]


def hauteur(x, y, rayon=80):
    """Hauteur de l'apparition (créature ou objet du monde) la plus proche, sur Kalimdor."""
    lignes = sql("SELECT z FROM (SELECT position_x x, position_y y, position_z z FROM acore_world.creature WHERE map = 1 "
                 "UNION ALL SELECT position_x, position_y, position_z FROM acore_world.gameobject WHERE map = 1) t "
                 "WHERE ABS(x - %d) < %d AND ABS(y - %d) < %d ORDER BY POW(x - %d, 2) + POW(y - %d, 2) LIMIT 1"
                 % (x, rayon, y, rayon, x, y))
    if not lignes:
        raise SystemExit("Aucun repère de hauteur près de (%d, %d)" % (x, y))
    return float(lignes[0][0])


def lignes_dbc():
    """Lignes à ajouter à Item.dbc : (entrée, entrée copiée, (classe, sous-classe, emplacement) ou None)."""
    import equipement_v3
    lignes = [(INSIGNE, 37711, None), (COTE, 769, (12, 0, 0)), (VIANDE, 769, (12, 0, 0))]
    lignes += [(RELIQUE + i, r[3], (15, 0, 0)) for i, r in enumerate(RELIQUES)]
    for e, _, source, _ in PIECES:
        lignes.append((e, source, None))
        lignes += [(equipement_v3.entree_rang(e, r), e, None) for r in range(1, equipement_v3.RANGS + 1)]
    return lignes


def copie_creature(w, origine, entree, nom, titre, maj=""):
    w("CREATE TEMPORARY TABLE sol_t SELECT * FROM creature_template WHERE entry = %d;" % origine)
    w("UPDATE sol_t SET entry = %d, name = %s, subname = %s, KillCredit1 = 0, KillCredit2 = 0, pickpocketloot = 0%s;"
      % (entree, s(nom), s(titre), maj))
    w("INSERT INTO creature_template SELECT * FROM sol_t;")
    w("DROP TEMPORARY TABLE sol_t;")
    w("INSERT INTO creature_template_model (CreatureID, Idx, CreatureDisplayID, DisplayScale, Probability, VerifiedBuild) "
      "SELECT %d, Idx, CreatureDisplayID, DisplayScale, Probability, VerifiedBuild FROM creature_template_model "
      "WHERE CreatureID = %d;" % (entree, origine))
    w("INSERT INTO creature_template_locale (entry, locale, Name, Title, VerifiedBuild) VALUES (%d, 'frFR', %s, %s, 0);"
      % (entree, s(nom), s(titre)))


def copie_objet(w, source, entree, nom, maj):
    w("CREATE TEMPORARY TABLE sol_objet SELECT * FROM item_template WHERE entry = %d;" % source)
    w("UPDATE sol_objet SET entry = %d, name = %s, %s;" % (entree, s(nom), maj))
    w("INSERT INTO item_template SELECT * FROM sol_objet;")
    w("DROP TEMPORARY TABLE sol_objet;")
    w("INSERT INTO item_template_locale (ID, locale, Name, Description, VerifiedBuild) VALUES (%d, 'frFR', %s, '', 0);"
      % (entree, s(nom)))


def copie_go(w, source, entree, nom, maj):
    w("CREATE TEMPORARY TABLE sol_go SELECT * FROM gameobject_template WHERE entry = %d;" % source)
    w("UPDATE sol_go SET entry = %d, name = %s%s;" % (entree, s(nom), maj))
    w("INSERT INTO gameobject_template SELECT * FROM sol_go;")
    w("DROP TEMPORARY TABLE sol_go;")
    w("INSERT INTO gameobject_template_locale (entry, locale, name, castBarCaption, VerifiedBuild) "
      "VALUES (%d, 'frFR', %s, '', 0);" % (entree, s(nom)))


def recompense_texte(a):
    morceaux = []
    if a["eclats"]:
        morceaux.append("%d éclats cadavériques" % a["eclats"])
    if a.get("composants"):
        morceaux.append("des composants")
    texte = "Rangé dans ta Collection : " + ", ".join(morceaux) + "." if morceaux else ""
    if a["insignes"]:   # Marques du voyageur depuis le 01/11/2026 (champ insignes gardé)
        texte = ("%d Marques du voyageur. " % a["insignes"] + texte).strip()
    if a.get("chrono"):
        texte += " Médaille d'argent : récompenses ×1,5 ; d'or : ×2."
    return texte


def construire():
    import equipement_v3
    armures, armes = equipement_v3.baremes()
    sources = equipement_v3.objets({src for _, _, src, _ in PIECES})
    up, down = [], []
    w = up.append
    w("-- v3, F5e (31/10/2026) : annexes de Durotar A11 à A46 (primes, contrats, défis, reliques ; document de Durotar,")
    w("-- §4.1.2 à 4.1.6). Généré par outils\\annexes_durotar.py : ne pas modifier à la main. Scripts : v3_annexes.cpp.")
    w("USE acore_world;")
    w("")

    w("-- Origine des lignes modifiées en place, pour la migration de retour.")
    w("CREATE TABLE IF NOT EXISTS solazeroth_v3_annexes_origine_creatures SELECT entry, AIName, KillCredit1 "
      "FROM creature_template WHERE entry IN (13157, 5435, 3225, 3226, 3227, 3228);")
    w("CREATE TABLE IF NOT EXISTS solazeroth_v3_annexes_origine_apparitions SELECT guid, id, spawntimesecs FROM creature "
      "WHERE id IN (5809, 5822, 5823, 5824, 5826, 5808) OR guid IN (1976959, 7355);")
    w("")

    w("-- Objets : Insigne de Durotar (monnaie des annexes), viande et côtes du contrat A20, reliques.")
    copie_objet(w, 37711, INSIGNE, "Insigne de Durotar", "description = 'Monnaie des annexes de Durotar.', Quality = 2, "
                "stackable = 2147483647, BuyPrice = 0, SellPrice = 0")
    for e, nom in ((VIANDE, "Morceau de viande de sanglier redoutable"), (COTE, "Côte d'ancien sanglier")):
        copie_objet(w, 769, e, nom, "class = 12, subclass = 0, Quality = 1, bonding = 4, stackable = 20, BuyPrice = 0, "
                    "SellPrice = 0, spellid_1 = 0, spelltrigger_1 = 0")
    for i, (cle, nom, famille, source, *_r) in enumerate(RELIQUES):
        copie_objet(w, source, RELIQUE + i, nom, "class = 15, subclass = 0, InventoryType = 0, Quality = 3, bonding = 1, "
                    "stackable = 1, BuyPrice = 0, SellPrice = 0, armor = 0, dmg_min1 = 0, dmg_max1 = 0, delay = 0, "
                    "block = 0, startquest = 0, PageText = 0, PageMaterial = 0, spellid_1 = 0, spelltrigger_1 = 0, "
                    "description = %s" % s("Relique (%s), annexe %s de Durotar." % (FAMILLES[famille], cle)))
    w("INSERT IGNORE INTO solazeroth_v3_collectionnables VALUES %s;"
      % ", ".join("(%d)" % e for e in [INSIGNE] + [RELIQUE + i for i in range(len(RELIQUES))]))
    w("")

    w("-- Pièces d'équipement des annexes : barème commun et rangs 1 à 5 (outils\\equipement_v3.py).")
    for e, nom, source, p in PIECES:
        poids = equipement_v3.POIDS[int(sources[source]["InventoryType"])]
        c = equipement_v3.caracteristiques(sources[source], p, armures, armes)
        bloc = int(sources[source]["block"])
        copie_objet(w, source, e, nom, "description = '', Quality = 2, bonding = 1, ItemLevel = %d, RequiredLevel = 0, "
                    "RequiredSkill = 0, RequiredSkillRank = 0, AllowableClass = -1, AllowableRace = -1, BuyPrice = 0, "
                    "SellPrice = %d, RandomProperty = 0, RandomSuffix = 0, spellid_1 = 0, spelltrigger_1 = 0, %s"
                    % (p, round(p * poids * 25), equipement_v3.colonnes_sql(equipement_v3.au_rang(c, 0, bloc))))
        for r in range(1, equipement_v3.RANGS + 1):
            n = equipement_v3.entree_rang(e, r)
            w("CREATE TEMPORARY TABLE sol_objet SELECT * FROM item_template WHERE entry = %d;" % e)
            w("UPDATE sol_objet SET entry = %d, name = %s, %s;"
              % (n, s("%s +%d" % (nom, r)), equipement_v3.colonnes_sql(equipement_v3.au_rang(c, r, bloc))))
            w("INSERT INTO item_template SELECT * FROM sol_objet;")
            w("DROP TEMPORARY TABLE sol_objet;")
    w("REPLACE INTO solazeroth_v3_rangs VALUES %s;" % ", ".join(
        "(%d, %d, %d)" % (equipement_v3.entree_rang(e, r) if r else e, e, r)
        for e, *_ in PIECES for r in range(equipement_v3.RANGS + 1)))
    w("")

    w("-- Butin du contrat A20, seulement pendant la quête.")
    w("INSERT INTO creature_loot_template (Entry, Item, Reference, Chance, QuestRequired, LootMode, GroupId, MinCount, "
      "MaxCount, Comment) VALUES (3099, %d, 0, 60, 1, 1, 0, 1, 1, 'Sol''Azeroth v3 : A20'), "
      "(3100, %d, 0, 60, 1, 1, 0, 1, 1, 'Sol''Azeroth v3 : A20');" % (VIANDE, COTE))
    w("")

    w("-- Créatures : rares des primes, PNJ de l'épreuve, écho de Kolkanis, crédits de quête.")
    copie_creature(w, 3281, MATRIARCHE, "Matriarche des scorpides", "", ", `rank` = 4")
    copie_creature(w, 5435, DENT, "Dent-de-l'Écho", "", ", AIName = 'SmartAI'")
    copie_creature(w, 3231, GUEULE, "Gueule-de-gangrène", "", ", `rank` = 4")
    w("UPDATE creature_template_model SET DisplayScale = DisplayScale * 1.4 WHERE CreatureID IN (%d, %d, %d);"
      % (MATRIARCHE, DENT, GUEULE))
    copie_creature(w, 3188, ZUNJALA, "Zun'jala", "Gardienne de l'épreuve",
                   ", npcflag = 3, gossip_menu_id = 0, AIName = '', ScriptName = 'npc_solazeroth_v3_zunjala'")
    copie_creature(w, 910012, ECHO, "Écho de Kolkanis", "Écho de l'épreuve")
    w("INSERT INTO smart_scripts SELECT %d, source_type, id, link, event_type, event_phase_mask, event_chance, "
      "event_flags, event_param1, event_param2, event_param3, event_param4, event_param5, event_param6, action_type, "
      "action_param1, action_param2, action_param3, action_param4, action_param5, action_param6, target_type, "
      "target_param1, target_param2, target_param3, target_param4, target_x, target_y, target_z, target_o, comment "
      "FROM smart_scripts WHERE entryorguid = 910012 AND source_type = 0;" % ECHO)
    for e, nom in ((CREDIT_BETES, "Bête corrompue"), (CREDIT_VAGUE5, "Vague 5 de l'épreuve"),
                   (CREDIT_VAGUE10, "Vague 10 de l'épreuve")):
        copie_creature(w, 15214, e, nom, "")
    w("UPDATE creature_template SET KillCredit1 = %d WHERE entry IN (3225, 3226, 3227, 3228);" % CREDIT_BETES)
    w("UPDATE creature_template SET AIName = 'SmartAI' WHERE entry = 13157;")
    w("")
    w("-- Apparitions : la Matriarche et Zun'jala ; Dent-de-l'Écho et Gueule-de-gangrène prennent la place d'un requin")
    w("-- et d'un crocilisque d'origine ; les rares reviennent en 15 min, Kolkanis en 5 (épreuve et lieu A05).")
    for guid, entree, (x, y), o in ((GUID_CREATURE, MATRIARCHE, (-432, -4217), 3.1),
                                    (GUID_CREATURE + 1, ZUNJALA, (-880, -4290), 4.0)):
        w("INSERT INTO creature (guid, id, map, zoneId, areaId, spawnMask, phaseMask, equipment_id, position_x, "
          "position_y, position_z, orientation, spawntimesecs, wander_distance, MovementType) VALUES "
          "(%d, %d, 1, 14, 0, 1, 1, 0, %d, %d, %.1f, %.1f, %d, 0, 0);"
          % (guid, entree, x, y, hauteur(x, y), o, 900 if entree == MATRIARCHE else 300))
    w("UPDATE creature SET id = %d, spawntimesecs = 900 WHERE guid = 1976959;" % DENT)
    w("UPDATE creature SET id = %d, spawntimesecs = 900 WHERE guid = 7355;" % GUEULE)
    w("UPDATE creature SET spawntimesecs = 900 WHERE id IN (5809, 5822, 5823, 5824, 5826);")
    w("UPDATE creature SET spawntimesecs = 300 WHERE id = 5808;")
    w("")

    w("-- Techniques des monstres (T6 à T13, T16, T18).")
    lignes, ids = [], {}
    for creature, ev, ep, flags, action, ap, cible, (dx, dy), comment in TECHNIQUES:
        n = ids[creature] = ids.get(creature, 49) + 1
        lignes.append("(%d, 0, %d, 0, %d, 0, 100, %d, %d, %d, %d, %d, 0, 0, %d, %d, %d, %d, %d, 0, 0, %d, 0, 0, 0, 0, "
                      "%d, %d, 0, 0, %s)" % (creature, n, ev, flags, *ep, action, *ap, cible, dx, dy, s(comment)))
    w("INSERT INTO smart_scripts (entryorguid, source_type, id, link, event_type, event_phase_mask, event_chance, "
      "event_flags, event_param1, event_param2, event_param3, event_param4, event_param5, event_param6, action_type, "
      "action_param1, action_param2, action_param3, action_param4, action_param5, action_param6, target_type, "
      "target_param1, target_param2, target_param3, target_param4, target_x, target_y, target_z, target_o, comment) "
      "VALUES\n" + ",\n".join(lignes) + ";")
    w("")

    w("-- Objets du monde : tableaux des primes, reliques ; œufs (A22) et monceaux (A24) scriptés.")
    copie_go(w, 2713, TABLEAU_TRANCHE, "Tableau des primes de Tranchecolline", "")
    copie_go(w, 2713, TABLEAU_SENJIN, "Tableau des primes de Sen'jin", "")
    for i, (cle, nom, *_r) in enumerate(RELIQUES):
        copie_go(w, 106318, GO_RELIQUE + i, nom, ", type = 10, size = 0.6, Data0 = 0, Data1 = 0, Data2 = 0, Data3 = 0, "
                 "Data4 = 0, Data5 = 0, Data6 = 0, Data7 = 0, Data8 = 0, Data9 = 0, Data10 = 0, "
                 "ScriptName = 'go_solazeroth_v3_relique', AIName = ''")
    w("UPDATE gameobject_template SET Data1 = 0, ScriptName = 'go_solazeroth_v3_monceau' WHERE entry = 102986;")
    w("UPDATE gameobject_template SET ScriptName = 'go_solazeroth_v3_oeufs' WHERE entry = 3240;")
    places = [(TABLEAU_TRANCHE, (279, -4713), 2.5), (TABLEAU_SENJIN, (-821, -4925), 2.2)]
    places += [(GO_RELIQUE + i, r[4], 0.0) for i, r in enumerate(RELIQUES)]
    w("INSERT INTO gameobject (guid, id, map, zoneId, areaId, spawnMask, phaseMask, position_x, position_y, position_z, "
      "orientation, rotation0, rotation1, rotation2, rotation3, spawntimesecs, animprogress, state) VALUES\n" + ",\n".join(
        "(%d, %d, 1, 14, 0, 1, 1, %d, %d, %.1f, %.1f, 0, 0, 0, 1, 60, 100, 1)"
        % (GUID_GO + k, go, x, y, hauteur(x, y), o) for k, (go, (x, y), o) in enumerate(places)) + ";")
    w("")

    w("-- Quêtes des annexes.")
    for a in A:
        champs = {"ID": a["q"], "QuestType": 2, "QuestLevel": -1, "MinLevel": 0, "QuestSortID": DUROTAR,
                  "RewardMoney": a["argent"], "Flags": 4096 if a.get("journaliere") else 0,
                  "LogTitle": s(a["titre"]), "LogDescription": s(a["resume"]), "QuestDescription": s(a["intro"]),
                  "QuestCompletionLog": s("Retourne voir qui t'a confié cette tâche.")}
        recompenses = [(e, 1) for e in [a.get("equip")] if e]
        for i, (e, c) in enumerate(recompenses, 1):
            champs["RewardItem%d" % i], champs["RewardAmount%d" % i] = e, c
        tuer, go, objets = a.get("tuer", []), a.get("go", []), a.get("objets", [])
        for i, (e, c, _, texte) in enumerate(tuer, 1):
            champs["RequiredNpcOrGo%d" % i], champs["RequiredNpcOrGoCount%d" % i] = e, c
            if texte:
                champs["ObjectiveText%d" % i] = s(texte)
        for i, (e, c, _, texte) in enumerate(go, len(tuer) + 1):
            champs["RequiredNpcOrGo%d" % i], champs["RequiredNpcOrGoCount%d" % i] = -e, c
            champs["ObjectiveText%d" % i] = s(texte)
        for i, (e, c, _) in enumerate(objets, 1):
            champs["RequiredItemId%d" % i], champs["RequiredItemCount%d" % i] = e, c
        w("INSERT INTO quest_template (%s) VALUES (%s);" % (", ".join(champs), ", ".join(str(v) for v in champs.values())))
        repetable = 1 if a.get("chrono") or a.get("potion") or a["cle"] == "A27" else 0
        w("INSERT INTO quest_template_addon (ID, PrevQuestID, SpecialFlags) VALUES (%d, %d, %d);"
          % (a["q"], a.get("prev", 0), repetable))
        w("INSERT INTO quest_request_items (ID, EmoteOnComplete, EmoteOnIncomplete, CompletionText) VALUES (%d, 1, 1, %s);"
          % (a["q"], s(a["prog"])))
        w("INSERT INTO quest_offer_reward (ID, Emote1, RewardText) VALUES (%d, 1, %s);"
          % (a["q"], s((a["fin"] + " " + recompense_texte(a)).strip())))
        for table, qui in (("queststarter", a["de"]), ("questender", a["a"])):
            if isinstance(qui, tuple):
                w("INSERT INTO gameobject_%s (id, quest) VALUES (%d, %d);" % (table, qui[1], a["q"]))
            else:
                w("INSERT INTO creature_%s (id, quest) VALUES (%d, %d);" % (table, qui, a["q"]))
        zones = [(i, z) for i, (_, _, z, _) in enumerate(tuer)] + \
            [(len(tuer) + i, z) for i, (_, _, z, _) in enumerate(go)] + [(4 + i, z) for i, (_, _, z) in enumerate(objets)]
        for numero, (index, centre) in enumerate(zones):
            w("INSERT INTO quest_poi (QuestID, id, ObjectiveIndex, MapID, WorldMapAreaId, Floor, Priority, Flags) "
              "VALUES (%d, %d, %d, 1, %d, 0, 0, 1);" % (a["q"], numero, index, CARTE_DUROTAR))
            w("INSERT INTO quest_poi_points (QuestID, Idx1, Idx2, X, Y) VALUES %s;" % ", ".join(
                "(%d, %d, %d, %d, %d)" % (a["q"], numero, k, x, y) for k, (x, y) in enumerate(octogone(centre, 60))))
    w("")

    w("-- Récompenses rangées dans la Collection, chrono, médailles, sans potion (v3_annexes.cpp).")
    w("DROP TABLE IF EXISTS solazeroth_v3_annexes;")
    w("CREATE TABLE solazeroth_v3_annexes (quete INT UNSIGNED NOT NULL PRIMARY KEY, cle VARCHAR(8) NOT NULL, "
      "insignes INT UNSIGNED NOT NULL, eclats INT UNSIGNED NOT NULL, bronze INT UNSIGNED NOT NULL, "
      "argent INT UNSIGNED NOT NULL, `or` INT UNSIGNED NOT NULL, depart VARCHAR(64) NOT NULL, "
      "potion INT UNSIGNED NOT NULL, objet_or INT UNSIGNED NOT NULL);")
    valeurs = []
    for a in A:
        depart, b, ar, o = a.get("chrono", ([], 0, 0, 0))
        valeurs.append("(%d, '%s', %d, %d, %d, %d, %d, '%s', %d, %d)" % (
            a["q"], a["cle"], a["insignes"], a["eclats"], b, ar, o, ",".join(map(str, depart)), a.get("potion", 0),
            a.get("equip_or", 0)))
    w("INSERT INTO solazeroth_v3_annexes VALUES %s;" % ", ".join(valeurs))
    w("DROP TABLE IF EXISTS solazeroth_v3_annexes_composants;")
    w("CREATE TABLE solazeroth_v3_annexes_composants (quete INT UNSIGNED NOT NULL, objet INT UNSIGNED NOT NULL, "
      "nombre INT UNSIGNED NOT NULL, PRIMARY KEY (quete, objet));")
    w("INSERT INTO solazeroth_v3_annexes_composants VALUES %s;" % ", ".join(
        "(%d, %d, %d)" % (a["q"], o, n) for a in A for o, n in a.get("composants", {}).items()))
    w("DROP TABLE IF EXISTS solazeroth_v3_reliques;")
    w("CREATE TABLE solazeroth_v3_reliques (objet_monde INT UNSIGNED NOT NULL PRIMARY KEY, objet INT UNSIGNED NOT NULL, "
      "famille TINYINT UNSIGNED NOT NULL, composant INT UNSIGNED NOT NULL);")
    w("INSERT INTO solazeroth_v3_reliques VALUES %s;" % ", ".join(
        "(%d, %d, %d, %d)" % (GO_RELIQUE + i, RELIQUE + i, r[2], r[7]) for i, r in enumerate(RELIQUES)))
    w("DROP TABLE IF EXISTS solazeroth_v3_vagues;")
    w("CREATE TABLE solazeroth_v3_vagues (vague TINYINT UNSIGNED NOT NULL, creature INT UNSIGNED NOT NULL, "
      "nombre TINYINT UNSIGNED NOT NULL, PRIMARY KEY (vague, creature));")
    w("INSERT INTO solazeroth_v3_vagues VALUES %s;" % ", ".join(
        "(%d, %d, %d)" % (v, c, n) for v, vague in enumerate(VAGUES, 1) for c, n in vague))
    w("CREATE TABLE IF NOT EXISTS acore_characters.solazeroth_v3_annexes_medailles (guid INT UNSIGNED NOT NULL, "
      "quete INT UNSIGNED NOT NULL, medaille TINYINT UNSIGNED NOT NULL, temps INT UNSIGNED NOT NULL, "
      "PRIMARY KEY (guid, quete));")
    w("CREATE TABLE IF NOT EXISTS acore_characters.solazeroth_v3_annexes_joueur (guid INT UNSIGNED NOT NULL PRIMARY KEY, "
      "carte TINYINT UNSIGNED NOT NULL DEFAULT 0, vague TINYINT UNSIGNED NOT NULL DEFAULT 0, "
      "temps INT UNSIGNED NOT NULL DEFAULT 0, jour INT UNSIGNED NOT NULL DEFAULT 0);")
    w("")

    w("-- Parts de zone : genre 4, annexe rendue (la quête) ; genre 5, relique dans la Collection.")
    parts = ["(14, 4, %d, %d, %s)" % (a["q"], a["part"], s("%s — %s" % (a["cle"], a["titre"]))) for a in A if a["part"]]
    parts += ["(14, 5, %d, 25, %s)" % (RELIQUE + i, s("%s — %s" % (r[0], r[1]))) for i, r in enumerate(RELIQUES)]
    w("DELETE FROM solazeroth_v3_zone_parts WHERE genre IN (4, 5);")
    w("INSERT INTO solazeroth_v3_zone_parts (zone, genre, cle, part, nom) VALUES %s;" % ", ".join(parts))
    w("")
    total = sum(a["part"] for a in A) + 25 * len(RELIQUES)
    assert total == 2500, total

    q = ", ".join(str(a["q"]) for a in A)
    objets_crees = [INSIGNE, COTE, VIANDE] + [RELIQUE + i for i in range(len(RELIQUES))]
    for e, *_ in PIECES:
        objets_crees += [e] + [equipement_v3.entree_rang(e, r) for r in range(1, equipement_v3.RANGS + 1)]
    objets_crees = ", ".join(map(str, objets_crees))
    creatures = ", ".join(map(str, [MATRIARCHE, DENT, GUEULE, ZUNJALA, ECHO, CREDIT_BETES, CREDIT_VAGUE5, CREDIT_VAGUE10]))
    gos = ", ".join(map(str, [TABLEAU_TRANCHE, TABLEAU_SENJIN] + [GO_RELIQUE + i for i in range(len(RELIQUES))]))
    down += [
        "-- Annule 084 : retire les annexes A11 à A46. Les reliques et Insignes rangés restent en Collection, sans emploi.",
        "USE acore_world;",
        "DELETE FROM solazeroth_v3_zone_parts WHERE genre IN (4, 5);",
        "DROP TABLE solazeroth_v3_annexes, solazeroth_v3_annexes_composants, solazeroth_v3_reliques, solazeroth_v3_vagues;",
        "DROP TABLE acore_characters.solazeroth_v3_annexes_medailles, acore_characters.solazeroth_v3_annexes_joueur;",
        "DELETE FROM quest_template WHERE ID IN (%s);" % q,
        "DELETE FROM quest_template_addon WHERE ID IN (%s);" % q,
        "DELETE FROM quest_request_items WHERE ID IN (%s);" % q,
        "DELETE FROM quest_offer_reward WHERE ID IN (%s);" % q,
        "DELETE FROM quest_poi WHERE QuestID IN (%s);" % q,
        "DELETE FROM quest_poi_points WHERE QuestID IN (%s);" % q,
        "DELETE FROM creature_queststarter WHERE quest IN (%s);" % q,
        "DELETE FROM creature_questender WHERE quest IN (%s);" % q,
        "DELETE FROM gameobject_queststarter WHERE quest IN (%s);" % q,
        "DELETE FROM gameobject_questender WHERE quest IN (%s);" % q,
        "DELETE FROM gameobject WHERE guid BETWEEN %d AND %d;" % (GUID_GO, GUID_GO + len(places) - 1),
        "DELETE FROM gameobject_template WHERE entry IN (%s);" % gos,
        "DELETE FROM gameobject_template_locale WHERE entry IN (%s);" % gos,
        "UPDATE gameobject_template SET Data1 = 1884, ScriptName = '' WHERE entry = 102986;",
        "UPDATE gameobject_template SET ScriptName = '' WHERE entry = 3240;",
        "DELETE FROM smart_scripts WHERE source_type = 0 AND entryorguid IN (%s) AND id >= 50;"
        % ", ".join(map(str, sorted(ids))),
        "DELETE FROM smart_scripts WHERE source_type = 0 AND entryorguid = %d;" % ECHO,
        "DELETE FROM creature WHERE guid IN (%d, %d);" % (GUID_CREATURE, GUID_CREATURE + 1),
        "UPDATE creature c JOIN solazeroth_v3_annexes_origine_apparitions o ON o.guid = c.guid "
        "SET c.id = o.id, c.spawntimesecs = o.spawntimesecs;",
        "UPDATE creature_template t JOIN solazeroth_v3_annexes_origine_creatures o ON o.entry = t.entry "
        "SET t.AIName = o.AIName, t.KillCredit1 = o.KillCredit1;",
        "DROP TABLE solazeroth_v3_annexes_origine_apparitions, solazeroth_v3_annexes_origine_creatures;",
        "DELETE FROM creature_template WHERE entry IN (%s);" % creatures,
        "DELETE FROM creature_template_model WHERE CreatureID IN (%s);" % creatures,
        "DELETE FROM creature_template_locale WHERE entry IN (%s);" % creatures,
        "DELETE FROM creature_loot_template WHERE Entry IN (3099, 3100) AND Item IN (%d, %d);" % (VIANDE, COTE),
        "DELETE FROM solazeroth_v3_rangs WHERE base IN (%s);" % ", ".join(str(e) for e, *_ in PIECES),
        "DELETE FROM solazeroth_v3_collectionnables WHERE entry = %d OR entry BETWEEN %d AND %d;"
        % (INSIGNE, RELIQUE, RELIQUE + len(RELIQUES) - 1),
        "DELETE FROM item_template WHERE entry IN (%s);" % objets_crees,
        "DELETE FROM item_template_locale WHERE ID IN (%s);" % objets_crees,
        "",
    ]
    for suffixe, lignes in ((".up.sql", up), (".down.sql", down)):
        with open(MIGRATION + suffixe, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(lignes))
    interface()
    import quetes_durotar
    quetes_durotar.item_dbc()
    print("%d quêtes d'annexe, %d reliques, %d pièces, %d techniques : migration 084 et SolUI_Annexes.lua écrits."
          % (len(A), len(RELIQUES), len(PIECES), len(TECHNIQUES)))


def lua(t):
    return '"' + t.replace("\\", "\\\\").replace('"', '\\"') + '"'


def interface():
    # bleue : quête à refaire (journalière ou répétable), bleue dans le jeu ; épingle bleue sur les cartes.
    # cible : position de la cible d'une prime (x, y du jeu) ; tête de mort sur les cartes tant qu'elle est à faire.
    l = ["-- Généré par outils\\annexes_durotar.py : ne pas modifier à la main.",
         "-- Annexes de Durotar (quête -> clé, famille, titre, puissance, résumé), reliques (objet -> clé, nom, famille,",
         "-- indice, x, y) et catégorie « Durotar » de la Collection.",
         "SolUI.ANNEXES = {"]
    for a in A:
        l.append("    [%d] = { cle = %s, famille = %s, titre = %s, puissance = %d, resume = %s, part = %d%s }," % (
            a["q"], lua(a["cle"]), lua(a["famille"]), lua(a["titre"]), a["p"], lua(a["resume"]), a["part"],
            (", chrono = { %d, %d, %d }" % a["chrono"][1:] if a.get("chrono") else "")
            + (", bleue = true" if a.get("journaliere") or a.get("chrono") or a.get("potion") or a["cle"] == "A27"
               else "")
            + (", cible = { %d, %d }" % a["tuer"][0][2] if a["famille"] == "Primes" else "")))
    l.append("}")
    l.append("SolUI.FAMILLES_RELIQUES = { %s }" % ", ".join(
        "{ nom = %s, bonus = %s }" % (lua(f), lua(BONUS_FAMILLE[i])) for i, f in enumerate(FAMILLES)))
    l.append("SolUI.RELIQUES = {")
    for i, (cle, nom, famille, _, (x, y), indice, p, _) in enumerate(RELIQUES):
        l.append("    { objet = %d, cle = %s, nom = %s, famille = %d, indice = %s, x = %d, y = %d, puissance = %d },"
                 % (RELIQUE + i, lua(cle), lua(nom), famille + 1, lua(indice), x, y, p))
    l.append("}")
    l.append("SolUI.PUISSANCES_QUETES = SolUI.PUISSANCES_QUETES or {}")
    l.append("for quete, a in pairs(SolUI.ANNEXES) do SolUI.PUISSANCES_QUETES[quete] = a.puissance end")
    l.append("if SolUI.CATALOGUE then")
    l.append("    table.insert(SolUI.CATALOGUE, { nom = \"Durotar\", objets = {")
    l += ["        { %d, %s, 3 }," % (RELIQUE + i, lua(r[1])) for i, r in enumerate(RELIQUES)]
    l.append("    } })")
    l.append("end")
    with open(LUA, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(l) + "\n")


if __name__ == "__main__":
    construire()
