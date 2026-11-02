-- Généré par outils\equipement_v3.py : ne pas modifier à la main.
-- Recettes de la fenêtre Équipement, par catégorie : { objet, nom, puissance de la pièce,
-- puissance requise, prix en cuivre, { { composant, nombre }, … }, genre (sous-catégorie du menu) }.
SolUI.RECETTES = {
    { nom = "Rudimentaire", forge = false, recettes = {
        { 910227, "Épée grossière en cuivre", 4, 0, 20, { { 2770, 3 }, { 2934, 1 } }, "Armes et boucliers" },
        { 910228, "Hache grossière en cuivre", 4, 0, 20, { { 2770, 3 }, { 2934, 1 } }, "Armes et boucliers" },
        { 910229, "Masse grossière en cuivre", 4, 0, 20, { { 2770, 3 }, { 2934, 1 } }, "Armes et boucliers" },
        { 910230, "Dague grossière en cuivre", 4, 0, 20, { { 2770, 2 }, { 2934, 1 } }, "Armes et boucliers" },
        { 910231, "Rondache en cuivre", 3, 0, 15, { { 2770, 4 } }, "Armes et boucliers" },
        { 910232, "Gilet grossier en cuivre", 3, 0, 15, { { 2770, 5 } }, "Maille" },
        { 910233, "Gilet en cuir cousu main", 3, 0, 15, { { 2934, 5 } }, "Cuir" },
        { 910234, "Gilet en lin brun", 3, 0, 15, { { 2589, 4 } }, "Tissu" },
    } },
    { nom = "Maille", forge = true, recettes = {
        { 910201, "Haubert en anneaux de cuivre", 10, 8, 50, { { 2770, 16 }, { 2835, 4 } }, "Maille" },
        { 910202, "Jambières en anneaux de cuivre", 9, 7, 45, { { 2770, 10 }, { 2835, 2 } }, "Maille" },
        { 910203, "Bottes en anneaux de cuivre", 8, 6, 40, { { 2770, 8 }, { 2835, 2 } }, "Maille" },
        { 910204, "Gantelets en cuivre", 8, 6, 40, { { 2770, 8 }, { 2835, 2 } }, "Maille" },
        { 910205, "Brassards en cuivre", 7, 5, 35, { { 2770, 4 }, { 2835, 2 } }, "Maille" },
        { 910206, "Ceinture en anneaux de cuivre", 8, 6, 40, { { 2770, 6 }, { 2835, 2 } }, "Maille" },
        { 910207, "Bouclier en cuivre", 9, 7, 45, { { 2770, 10 }, { 2835, 4 } }, "Armes et boucliers" },
    } },
    { nom = "Armes", forge = true, recettes = {
        { 910208, "Épée courte en cuivre", 9, 7, 45, { { 2770, 8 }, { 2835, 2 }, { 2318, 2 } }, "Armes et boucliers" },
        { 910209, "Hache en cuivre", 9, 7, 45, { { 2770, 8 }, { 2835, 2 }, { 2318, 2 } }, "Armes et boucliers" },
        { 910210, "Masse en cuivre", 9, 7, 45, { { 2770, 8 }, { 2835, 2 }, { 2318, 2 } }, "Armes et boucliers" },
        { 910211, "Dague en cuivre", 9, 7, 45, { { 2770, 6 }, { 2835, 2 }, { 2318, 2 } }, "Armes et boucliers" },
        { 910212, "Claymore en cuivre", 10, 8, 50, { { 2770, 14 }, { 2835, 4 }, { 2318, 2 } }, "Armes et boucliers" },
    } },
    { nom = "Cuir", forge = false, recettes = {
        { 910213, "Gilet en cuir estampé", 10, 8, 50, { { 2318, 10 }, { 2934, 4 } }, "Cuir" },
        { 910214, "Pantalon en cuir cousu", 9, 7, 45, { { 2318, 8 }, { 2934, 4 } }, "Cuir" },
        { 910215, "Bottes en cuir cousu", 8, 6, 40, { { 2318, 6 }, { 2934, 2 } }, "Cuir" },
        { 910216, "Gants en cuir estampé", 8, 6, 40, { { 2318, 6 }, { 2934, 2 } }, "Cuir" },
        { 910217, "Brassards en cuir cousu", 7, 5, 35, { { 2318, 4 }, { 2934, 2 } }, "Cuir" },
        { 910218, "Ceinture en cuir cousu", 8, 6, 40, { { 2318, 6 }, { 2934, 2 } }, "Cuir" },
        { 910219, "Cape en cuir estampé", 9, 7, 45, { { 2318, 6 }, { 2934, 2 } }, "Tissu" },
    } },
    { nom = "Tissu", forge = false, recettes = {
        { 910220, "Gilet rouge en lin", 10, 8, 50, { { 2589, 12 } }, "Tissu" },
        { 910221, "Pantalon en lin", 9, 7, 45, { { 2589, 10 } }, "Tissu" },
        { 910222, "Bottes en lin", 8, 6, 40, { { 2589, 8 }, { 2318, 2 } }, "Tissu" },
        { 910223, "Gants en lin épais", 8, 6, 40, { { 2589, 8 } }, "Tissu" },
        { 910224, "Brassards en lin", 7, 5, 35, { { 2589, 6 } }, "Tissu" },
        { 910225, "Ceinture en lin", 8, 6, 40, { { 2589, 6 } }, "Tissu" },
        { 910226, "Cape en lin renforcé", 9, 7, 45, { { 2589, 8 } }, "Tissu" },
    } },
}
