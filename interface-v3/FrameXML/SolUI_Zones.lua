-- Généré par outils\zones_interface.py : ne pas modifier à la main.
-- Lot T10 des Tarides : les zones v3 et leurs donjons, pour l'interface (registre, menus d'artisanat par zone
-- puis par palier, composant et panoplie du donjon, marchands des pièces). debut : début de la plage de la zone
-- (gabarit_zone.py) ; paliers : { puissance la plus haute des pièces, nom du niveau du menu }.
SolUI.ZONES = {
    { id = 14, nom = "Durotar", debut = 1, marchands = "de Razor Hill",
      paliers = { { 4, "Rudimentaire" }, { 10, "Inhabituel" } },
      donjon = { carte = 389, nom = "Gouffre de Ragefeu", court = "Gouffre", de = "du Gouffre de Ragefeu",
          composant = 910190, nomComposant = "Braise du Gouffre", taux = 15, puissanceMin = 1,
          suffixe = " du Gouffre", panoplie = "Panoplie du Gouffre", bonus = { { 2, "+ 3 % de dégâts" }, { 4, "− 5 % de dégâts subis" }, { 6, "3 % de vol de vie" } } } },
    { id = 17, nom = "Les Tarides", debut = 14, marchands = "de la Croisée et du Camp Taurajo",
      paliers = { { 18, "La Croisée" }, { 24, "Les oasis" }, { 30, "Taurajo" } },
      donjon = { carte = 43, nom = "Cavernes des Lamentations", court = "Cavernes", de = "des Cavernes des Lamentations",
          composant = 910191, nomComposant = "Graine de cauchemar", taux = 10, puissanceMin = 15,
          suffixe = " des Lamentations", panoplie = "Panoplie des Lamentations", bonus = { { 2, "+ 3 % de dégâts" }, { 4, "− 5 % de dégâts subis" }, { 6, "3 % de vol de vie" } } } },
}
