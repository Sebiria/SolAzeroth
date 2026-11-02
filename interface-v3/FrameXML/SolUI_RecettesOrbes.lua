-- Généré par outils\orbes_v3.py : ne pas modifier à la main.
-- Lot D5 : orbes à fabriquer, rangés avec le tissu de leur niveau (même format que SolUI_Recettes.lua).
table.insert(SolUI.RECETTES, { nom = "Rudimentaire", forge = false, recettes = {
    { 910237, "Orbe de lin grossier", 3, 0, 15, { { 2589, 4 } }, "Tissu" },
} })
table.insert(SolUI.RECETTES, { nom = "Tissu", forge = false, recettes = {
    { 910236, "Orbe en lin", 9, 7, 45, { { 2589, 10 } }, "Tissu" },
} })
table.insert(SolUI.RECETTES, { nom = "Gouffre : tissu", forge = false, gouffre = true, recettes = {
    { 910272, "Crâne du Gouffre", 14, 10, 5000, { { 910190, 1 }, { 2589, 14 }, { 910120, 40 }, { 910180, 1 } }, "Tissu" },
} })
