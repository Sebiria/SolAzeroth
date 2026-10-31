-- Généré par outils\equipement_v3.py : ne pas modifier à la main.
-- Recettes de la fenêtre Équipement, par catégorie : { objet, nom, puissance de la pièce,
-- puissance requise, prix en cuivre, { { composant, nombre }, … } }.
SolUI.RECETTES = {
    { nom = "Maille", forge = true, recettes = {
        { 910201, "Haubert en anneaux de cuivre", 10, 6, 50, { { 2770, 16 }, { 2835, 4 } } },
        { 910202, "Jambières en anneaux de cuivre", 9, 5, 45, { { 2770, 10 }, { 2835, 2 } } },
        { 910203, "Bottes en anneaux de cuivre", 8, 4, 40, { { 2770, 8 }, { 2835, 2 } } },
        { 910204, "Gantelets en cuivre", 8, 4, 40, { { 2770, 8 }, { 2835, 2 } } },
        { 910205, "Brassards en cuivre", 7, 3, 35, { { 2770, 4 }, { 2835, 2 } } },
        { 910206, "Ceinture en anneaux de cuivre", 8, 4, 40, { { 2770, 6 }, { 2835, 2 } } },
        { 910207, "Bouclier en cuivre", 9, 5, 45, { { 2770, 10 }, { 2835, 4 } } },
    } },
    { nom = "Armes", forge = true, recettes = {
        { 910208, "Épée courte en cuivre", 9, 5, 45, { { 2770, 8 }, { 2835, 2 }, { 2318, 2 } } },
        { 910209, "Hache en cuivre", 9, 5, 45, { { 2770, 8 }, { 2835, 2 }, { 2318, 2 } } },
        { 910210, "Masse en cuivre", 9, 5, 45, { { 2770, 8 }, { 2835, 2 }, { 2318, 2 } } },
        { 910211, "Dague en cuivre", 9, 5, 45, { { 2770, 6 }, { 2835, 2 }, { 2318, 2 } } },
        { 910212, "Claymore en cuivre", 10, 6, 50, { { 2770, 14 }, { 2835, 4 }, { 2318, 2 } } },
    } },
    { nom = "Cuir", forge = false, recettes = {
        { 910213, "Gilet en cuir estampé", 10, 6, 50, { { 2318, 10 }, { 2934, 4 } } },
        { 910214, "Pantalon en cuir cousu", 9, 5, 45, { { 2318, 8 }, { 2934, 4 } } },
        { 910215, "Bottes en cuir cousu", 8, 4, 40, { { 2318, 6 }, { 2934, 2 } } },
        { 910216, "Gants en cuir estampé", 8, 4, 40, { { 2318, 6 }, { 2934, 2 } } },
        { 910217, "Brassards en cuir cousu", 7, 3, 35, { { 2318, 4 }, { 2934, 2 } } },
        { 910218, "Ceinture en cuir cousu", 8, 4, 40, { { 2318, 6 }, { 2934, 2 } } },
        { 910219, "Cape en cuir estampé", 9, 5, 45, { { 2318, 6 }, { 2934, 2 } } },
    } },
    { nom = "Tissu", forge = false, recettes = {
        { 910220, "Gilet rouge en lin", 10, 6, 50, { { 2589, 12 } } },
        { 910221, "Pantalon en lin", 9, 5, 45, { { 2589, 10 } } },
        { 910222, "Bottes en lin", 8, 4, 40, { { 2589, 8 }, { 2318, 2 } } },
        { 910223, "Gants en lin épais", 8, 4, 40, { { 2589, 8 } } },
        { 910224, "Brassards en lin", 7, 3, 35, { { 2589, 6 } } },
        { 910225, "Ceinture en lin", 8, 4, 40, { { 2589, 6 } } },
        { 910226, "Cape en lin renforcé", 9, 5, 45, { { 2589, 8 } } },
    } },
}
