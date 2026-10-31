-- Généré par outils\joaillerie_v3.py : ne pas modifier à la main.
-- Joaillerie (fenêtre Équipement) : prospection, tailles { pierre, nom, brute, nombre } et pierres des rangs.
SolUI.JOAILLERIE = {
    minerai = 2770, parProspection = 5,
    chances = { { 774, 55 }, { 818, 35 }, { 1210, 10 } },
    tailles = {
        { 910180, "Malachite taillée", 774, 2 },
        { 910181, "Œil de tigre taillé", 818, 2 },
        { 910182, "Œil ténébreux taillé", 1210, 2 },
    },
    rangs = { [4] = { { 910180, 2 }, { 910181, 1 } }, [5] = { { 910181, 2 }, { 910182, 1 } } },
}
-- Les pierres taillées dans la catégorie Gemmes de la Collection.
for _, c in ipairs(SolUI.CATALOGUE or {}) do
    if c.nom == "Gemmes" then
        table.insert(c.objets, { 910180, "Malachite taillée", 3 })
        table.insert(c.objets, { 910181, "Œil de tigre taillé", 3 })
        table.insert(c.objets, { 910182, "Œil ténébreux taillé", 3 })
    end
end
