-- Généré par outils\orbes_v3.py : ne pas modifier à la main.
-- Lot D5 : orbes de joaillerie, rangés avec les boucliers de leur niveau (même format que SolUI_Recettes.lua).
table.insert(SolUI.RECETTES, { nom = "Rudimentaire", forge = false, recettes = {
    { 910237, "Orbe de malachite brute", 3, 0, 15, { { 774, 1 }, { 2770, 2 } }, "Armes et boucliers" },
} })
table.insert(SolUI.RECETTES, { nom = "Joaillerie", forge = false, recettes = {
    { 910236, "Orbe de malachite", 9, 7, 45, { { 910180, 1 }, { 2770, 4 } }, "Armes et boucliers" },
} })
table.insert(SolUI.RECETTES, { nom = "Gouffre : joaillerie", forge = false, gouffre = true, recettes = {
    { 910272, "Orbe ardent du Gouffre", 14, 10, 5000, { { 910190, 1 }, { 910181, 1 }, { 910120, 40 }, { 2770, 4 } }, "Armes et boucliers" },
} })
