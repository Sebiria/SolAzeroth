-- Généré par outils\cuisine_v3.py (auras_nommees.py) : ne pas modifier à la main.
-- Catégorie Cuisine de la fenêtre Équipement : { plat, nom, puissance du repas, puissance requise,
-- prix en cuivre, { { composant, nombre }, … }, zone }. Se fabrique près d'un feu.
table.insert(SolUI.RECETTES, { nom = "Cuisine", feu = true, recettes = {
    { 787, "Maquereau ombré", 6, 0, 0, { { 6303, 1 }, { 2447, 1 }, { 30817, 1 } }, "Durotar" },
    { 3662, "Steak de crocilisque", 6, 0, 0, { { 2924, 1 }, { 765, 1 }, { 159, 1 } }, "Durotar" },
    { 5473, "Surprise du scorpide", 6, 0, 0, { { 5466, 1 }, { 2449, 1 }, { 1179, 1 } }, "Durotar" },
    { 5095, "Thon arc-en-ciel", 6, 0, 0, { { 6361, 1 }, { 765, 1 }, { 4289, 1 } }, "Durotar" },
    { 2681, "Viande de sanglier rôtie", 6, 0, 0, { { 769, 1 }, { 2447, 1 }, { 2678, 1 } }, "Durotar" },
} })
