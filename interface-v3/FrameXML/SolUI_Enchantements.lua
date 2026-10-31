-- Généré par outils\enchantement_v3.py : ne pas modifier à la main.
-- Enchantements de la fenêtre Équipement : { id, nom, effet, enchantement, { InventoryType… },
-- { { composant, nombre }, … }, prix en cuivre } ; butin de chaque table de désenchantement.
SolUI.ENCHANTEMENTS = {
    { 1, "Santé mineure", "+5 points de vie", 41, { 5, 20 }, { { 10940, 2 } }, 20 },
    { 2, "Force mineure", "+1 Force", 248, { 9 }, { { 10940, 3 }, { 10938, 1 } }, 40 },
    { 3, "Agilité mineure", "+1 Agilité", 247, { 9 }, { { 10940, 3 }, { 10938, 1 } }, 40 },
    { 4, "Protection mineure", "+10 armure", 783, { 16 }, { { 10940, 2 }, { 10938, 1 } }, 30 },
    { 5, "Protection mineure", "+10 armure", 783, { 14 }, { { 10940, 2 }, { 10938, 1 } }, 30 },
    { 6, "Frappe mineure", "+1 aux dégâts de l'arme", 250, { 13, 21, 22 }, { { 10940, 3 }, { 10938, 2 } }, 50 },
    { 7, "Impact mineur", "+2 aux dégâts de l'arme", 241, { 17 }, { { 10940, 4 }, { 10938, 2 } }, 60 },
}
SolUI.DESENCHANTEMENT = {
    [1] = "Poussière étrange ×1-2 (80 %) ou Essence de magie inférieure ×1-2 (20 %)",
    [2] = "Poussière étrange ×2-3 (75 %) ou Essence de magie supérieure ×1-2 (20 %) ou Petit éclat scintillant ×1 (5 %)",
    [3] = "Poussière étrange ×4-6 (75 %) ou Essence astrale inférieure ×1-2 (15 %) ou Petit éclat scintillant ×1 (10 %)",
    [21] = "Essence de magie inférieure ×1-2 (80 %) ou Poussière étrange ×1-2 (20 %)",
    [22] = "Essence de magie supérieure ×1-2 (75 %) ou Poussière étrange ×2-3 (20 %) ou Petit éclat scintillant ×1 (5 %)",
    [23] = "Essence astrale inférieure ×1-2 (75 %) ou Poussière étrange ×4-6 (15 %) ou Petit éclat scintillant ×1 (10 %)",
    [32] = "Essence planaire inférieure ×2-3 (75 %) ou Poussière des arcanes ×2-3 (22 %) ou Petit éclat prismatique ×1 (3 %)",
    [41] = "Petit éclat scintillant ×1 (100 %)",
}
