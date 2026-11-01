-- Généré par outils\passifs_v3.py (auras_nommees.py) : ne pas modifier à la main.
-- Difficultés { écart, vie et dégâts, techniques, éclats, palier }, techniques des monstres, rangs de réputation,
-- emplacements, passifs de donjon { numéro, nom, effet } et du monde extérieur { numéro, branche, nom, effet }.
SolUI.DIFFICULTES = {
    { 0, "1", 0, "1", 0 },
    { 0, "1,1", 1, "1,5", 12 },
    { 0, "1,25", 2, "2", 20 },
    { 1, "1,3", 2, "2,5", 30 },
    { 1, "1,4", 3, "3", 38 },
}
SolUI.TECHNIQUES_DONJON = { "Enragé : sous 30 % de vie, + 50 % de dégâts", "Renforçant : à sa mort, + 20 % de dégâts et de vie aux monstres à 30 m", "Volcanique : une pluie de feu sous vos pieds toutes les 10 s", "Explosif : une sphère instable à détruire en 6 s toutes les 12 s" }
SolUI.RANGS_REPUTATION = { 0, 100, 300, 600, 1000, 1600, 2400, 3400, 4600, 6000 }
SolUI.EMPLACEMENTS_DONJON = { 1, 2, 4, 6, 8, 10 }
SolUI.EMPLACEMENTS_EXTERIEUR = { { 2, 25 }, { 5, 50 }, { 9, 100 }, { 15, 175 }, { 23, 275 }, { 31, 400 } }
SolUI.PASSIFS_DONJON = {
    { 1, "Peau de braise", "− 8 % de dégâts subis." },
    { 2, "Soif de sang", "6 % des dégâts infligés rendus en vie." },
    { 3, "Second souffle", "Une fois par combat, sous 30 % de vie : rend 15 % de la vie." },
    { 4, "Épines", "Renvoie 7 % des dégâts de mêlée subis." },
    { 5, "Récupération", "+ 2 % de vie par seconde hors combat." },
    { 6, "Bourreau", "+ 30 % de dégâts contre une cible sous 35 % de vie." },
    { 7, "Élan", "+ 2 % de dégâts par monstre tué, jusqu'à + 10 % ; perdu à la mort." },
    { 8, "Brise-chef", "+ 10 % de dégâts contre les boss." },
    { 9, "Contre la meute", "− 3 % de dégâts subis par ennemi au contact au-delà du premier, jusqu'à − 12 %." },
    { 10, "Fureur du nombre", "+ 4 % de dégâts par ennemi qui vous attaque, jusqu'à + 16 %." },
    { 11, "Premier sang", "+ 50 % de dégâts contre un monstre au-dessus de 80 % de vie." },
    { 12, "Carrure", "+ 8 % de vie maximale." },
    { 13, "Main vive", "Recharges des techniques − 10 %." },
    { 14, "Cuirasse", "+ 6 % d'armure." },
    { 15, "Pied sûr", "− 30 % de dégâts des pluies de feu, explosions et sorts de zone." },
    { 16, "Fin de combat", "À la fin de chaque combat, rend 10 % de la vie." },
    { 17, "Contre-attaque", "Quand on vous frappe, 20 % de chances de rendre une attaque." },
    { 18, "Tenace", "− 25 % de durée des étourdissements, immobilisations et ralentissements." },
    { 19, "Dernier rempart", "Une fois par donjon, une mort est évitée : vous restez à 30 % de vie." },
    { 20, "Charognard", "+ 25 % d'éclats dans le donjon." },
    { 21, "Pilleur de faille", "+ 1 Marque du voyageur par boss." },
}
SolUI.PASSIFS_EXTERIEUR = {
    { 31, "Combat", "Embuscade", "+ 80 % de dégâts contre un monstre au-dessus de 90 % de vie." },
    { 32, "Combat", "Chasseur de rares", "+ 10 % de dégâts contre les rares, les élites et les chefs renforcés." },
    { 33, "Combat", "Solitaire", "− 8 % de dégâts subis quand un seul monstre vous attaque." },
    { 34, "Combat", "Nettoyeur", "+ 10 % de dégâts contre les monstres des lieux à nettoyer." },
    { 35, "Combat", "Défi tenu", "+ 5 s à chaque épreuve contre la montre." },
    { 36, "Combat", "Mauvais œil", "En mode difficile ou cauchemar, les monstres ont une technique de moins (au moins une)." },
    { 37, "Survie", "Fin de traque", "Chaque monstre tué rend 3 % de la vie." },
    { 38, "Survie", "Second vent", "Régénération hors combat + 50 %." },
    { 39, "Survie", "Instinct de fuite", "Sous 25 % de vie, + 30 % de vitesse de course pendant 6 s (une fois par minute)." },
    { 40, "Survie", "Gorgée de plus", "+ 1 charge de potion." },
    { 41, "Survie", "Veillée", "Le Repos du feu de camp dure + 50 %." },
    { 42, "Survie", "Gourmet", "Les plats durent + 50 %." },
    { 43, "Survie", "Âme tenace", "− 20 % d'âme perdue à la mort." },
    { 44, "Récolte", "Cueilleur", "15 % de chances d'un composant de plus en récoltant (herbes, minerai, pêche)." },
    { 45, "Récolte", "Main experte", "20 % de chances d'un éclat cadavérique en récoltant." },
    { 46, "Récolte", "Éclats d'aventure", "+ 10 % d'éclats hors des instances." },
    { 47, "Récolte", "Chasseur de primes", "+ 20 % de Marques du voyageur des primes, contrats et défis." },
    { 48, "Voyage", "Pas léger", "+ 8 % de vitesse de course à pied." },
    { 49, "Voyage", "Rôdeur", "Les monstres vous repèrent de 6 m moins loin." },
    { 50, "Voyage", "Foyer proche", "Pierre de foyer − 5 min." },
    { 51, "Voyage", "Marchandage", "− 10 % chez les marchands et pour les réparations." },
}
