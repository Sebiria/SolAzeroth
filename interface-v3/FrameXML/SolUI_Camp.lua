-- Généré par outils\bivouac_v3.py : ne pas modifier à la main.
-- F7 : rangs de la potion et nœuds de l'arbre du camp. couts : { { objet, nombre }, … } (objet 0 : or, en cuivre).
SolUI.CAMP = {
    potion = {
        [0] = { nom = "", effet = "1 charge, rend 30 % de la vie.", couts = {  } },
        [1] = { nom = "Potion de Durotar", effet = "2 charges, rendent 35 % de la vie.", couts = { { 2447, 12 }, { 765, 8 }, { 2449, 4 }, { 910120, 50 }, { 0, 4000 } } },
        [2] = { nom = "Potion revigorante", effet = "2 charges, rendent 35 % de la vie, puis 1 % par seconde pendant 10 s.", couts = { { 2449, 12 }, { 910181, 2 }, { 910120, 120 }, { 37711, 20 }, { 0, 10000 } } },
    },
    feu = {
        [0] = { nom = "", effet = "Repos au coin du feu : vie maximale +5 % pendant 30 minutes, 1 % de la vie par seconde hors combat.", couts = {  } },
        [1] = { nom = "Flamme du guerrier", effet = "Le Repos donne aussi +10 % de dégâts.", couts = {  } },
        [2] = { nom = "Braises tenaces", effet = "Repos : vie maximale +5 %, +10 % de dégâts, +5 à la caractéristique principale de la spécialisation, 2 % de la vie par seconde hors combat, 30 minutes.", couts = { { 2770, 20 }, { 2589, 16 }, { 2318, 12 }, { 910120, 60 }, { 37711, 20 } } },
        [3] = { nom = "Feu de bivouac", effet = "Le même Repos, pendant 40 minutes.", couts = { { 2835, 8 }, { 2770, 20 }, { 910180, 2 }, { 910120, 160 }, { 37711, 40 }, { 0, 8000 } } },
    },
}
