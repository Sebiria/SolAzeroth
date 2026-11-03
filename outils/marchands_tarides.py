"""Lot T9 des Tarides (03/11/2026) : marchands et services (§4.7.7 et §4.7.8 du brouillon des Tarides).

- Marchands d'équipement : nos pièces vertes des Tarides (artisanat_tarides.py, migration 141) à la place de celles
  de Blizzard, au prix `puissance × poids × 300` (equipement_v3.prix, déjà dans BuyPrice), sans revente
  (SellPrice = 0). La Croisée, paliers I à III : Nargal (armes et main gauche), Jahan (maille et cuir), Halija (tissu
  et capes) ; le Camp Taurajo, palier III : Sanuye (maille et cuir). L'achat reste limité par la puissance de la
  recette (v3_equipement.cpp, OnPlayerBeforeBuyItemFromVendor).
- Retraits de Blizzard, tous gardés dans solazeroth_v3_t9_ventes_origine (la migration de retour les remet) :
  les herbes et les poisons de Hula'mahi ; les recettes vendues par les marchands qui n'apparaissent qu'en zones 14
  et 17 (nos recettes passent par la fenêtre Artisanat ; les marchands des fêtes présents ailleurs gardent les
  leurs) ; l'équipement des marchands d'Orgrimmar (même filtre que la migration 135 pour les zones 14 et 17 :
  chemises, tabards, sacs, cannes à pêche et armes diverses restent). L'équipement de Cabestan est déjà retiré (135).
- Hraq (3477, fournitures de forge, la Croisée), sans copie : fournisseur de matériaux comme Mogra
  (v3_fournisseur.cpp), son état d'origine dans solazeroth_v3_t9_pnj_origine. Il vend les cinq matériaux du palier I
  et les cinq des Tarides, aux prix de base du §4.7.8 (la puissance de l'acheteur les multiplie, au serveur).
- Bateau de Cabestan (transports, guid 7, entrée 20808) fermé tant que Baie-du-Butin n'est pas une zone v3 (décision
  9) ; sa ligne est gardée dans solazeroth_v3_t9_transports_origine.
- Gardés : armuriers (réparation), aubergistes, coursiers du vent (au prix de Blizzard).

py marchands_tarides.py   (écrit la migration 142)
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import artisanat_tarides
from fournisseur_v3 import PLAFOND, nom

MIGRATION = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "sql", "migrations",
                         "142_v3_tarides_marchands")
NARGAL, JAHAN, HALIJA, SANUYE = 3479, 3483, 3486, 10380
HULAMAHI, HRAQ = 3490, 3477
BATEAU = 7                     # transports.guid (entrée 20808, Baie-du-Butin et Cabestan)
ORGRIMMAR = 1637
# Prix de base du §4.7.8 (cuivres, puissance 12 ou moins) : les cinq du palier I (ceux de Mogra), puis les Tarides.
MATERIAUX = [(2835, 800), (2589, 1000), (2934, 1000), (2318, 2000), (2770, 4000),
             (2836, 1111), (2592, 1600), (2319, 3333), (2771, 6061), (2775, 55556)]
# Même filtre que la migration 135 : équipement de Blizzard, hors chemises, sacs, tabards, armes diverses et cannes.
EQUIPEMENT = ("i.class IN (2, 4) AND i.entry < 900000 AND i.InventoryType NOT IN (0, 4, 18, 19) "
              "AND NOT (i.class = 2 AND i.subclass IN (14, 20))")


def vendeur(piece):
    """Marchands de la pièce : (entrée, palier, famille, …) du générateur de l'artisanat."""
    entree, palier, famille = piece[0], piece[1], piece[2]
    if famille in ("armes", "mains"):
        return [HALIJA] if piece[3].startswith("Cape") else [NARGAL]   # la cape chez la marchande de tissu
    if famille in ("maille", "cuir"):
        return [JAHAN] + ([SANUYE] if palier == 3 else [])
    return [HALIJA]


def main():
    pieces = artisanat_tarides.pieces()
    paliers = sorted({p[1] for p in pieces})
    assert paliers == [1, 2, 3], paliers
    familles = {p[2] for p in pieces}
    assert familles <= {"maille", "cuir", "tissu", "armes", "mains"}, familles
    ventes = {}
    for p in pieces:
        for v in vendeur(p):
            ventes.setdefault(v, []).append(p[0])
    marchands = ", ".join(str(v) for v in (NARGAL, JAHAN, HALIJA, SANUYE))
    premiere, derniere = pieces[0][0], pieces[-1][0]
    up, down = [], []
    w = up.append
    w("-- Lot T9 des Tarides (03/11/2026) : marchands et services. Généré par outils\\marchands_tarides.py : ne pas")
    w("-- modifier à la main. Ne touche pas aux marchands de Durotar (sauf les recettes de Blizzard, retirées).")
    w("USE acore_world;")
    w("")
    w("-- Retraits de Blizzard, gardés pour le retour.")
    w("CREATE TABLE IF NOT EXISTS solazeroth_v3_t9_ventes_origine SELECT * FROM npc_vendor WHERE 1 = 0;")
    w("-- Herbes et poisons de Hula'mahi.")
    w("INSERT INTO solazeroth_v3_t9_ventes_origine SELECT v.* FROM npc_vendor v JOIN item_template i ON i.entry = v.item "
      "WHERE v.entry = %d AND ((i.class = 0 AND i.subclass = 8) OR (i.class = 7 AND i.subclass = 9));" % HULAMAHI)
    w("-- Recettes des marchands qui n'apparaissent qu'en zones 14 et 17.")
    w("INSERT IGNORE INTO solazeroth_v3_t9_ventes_origine SELECT v.* FROM npc_vendor v JOIN item_template i ON i.entry = "
      "v.item WHERE i.class = 9 AND v.entry IN (SELECT id FROM creature GROUP BY id HAVING SUM(zoneId IN (14, 17)) > 0 "
      "AND SUM(zoneId NOT IN (14, 17)) = 0);")
    w("-- Équipement des marchands d'Orgrimmar.")
    w("INSERT IGNORE INTO solazeroth_v3_t9_ventes_origine SELECT v.* FROM npc_vendor v JOIN item_template i ON i.entry = "
      "v.item WHERE v.entry IN (SELECT DISTINCT id FROM creature WHERE zoneId = %d) AND %s;" % (ORGRIMMAR, EQUIPEMENT))
    w("DELETE v FROM npc_vendor v JOIN solazeroth_v3_t9_ventes_origine o ON o.entry = v.entry AND o.item = v.item "
      "AND o.ExtendedCost = v.ExtendedCost;")
    w("")
    w("-- Nos pièces vertes des Tarides (BuyPrice : puissance × poids × 300 ; SellPrice 0).")
    w("DELETE FROM npc_vendor WHERE entry IN (%s) AND item BETWEEN %d AND %d;" % (marchands, premiere, derniere))
    for v in (NARGAL, JAHAN, HALIJA, SANUYE):
        w("SET @slot = (SELECT COALESCE(MAX(slot), 0) FROM npc_vendor WHERE entry = %d);" % v)
        w("INSERT INTO npc_vendor (entry, slot, item, maxcount, incrtime, ExtendedCost, VerifiedBuild) VALUES %s;"
          % ", ".join("(%d, @slot + %d, %d, 0, 0, 0, 0)" % (v, n, e) for n, e in enumerate(ventes[v], 1)))
    w("")
    w("-- Hraq, fournisseur de matériaux (v3_fournisseur.cpp) : son état d'origine pour le retour.")
    w("CREATE TABLE IF NOT EXISTS solazeroth_v3_t9_pnj_origine SELECT entry, npcflag, gossip_menu_id, ScriptName "
      "FROM creature_template WHERE entry = %d;" % HRAQ)
    w("UPDATE creature_template SET npcflag = 1, gossip_menu_id = 0, ScriptName = 'npc_solazeroth_v3_fournisseur' "
      "WHERE entry = %d;" % HRAQ)
    w("SET @manque = (SELECT COUNT(*) = 0 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = 'acore_world' AND "
      "TABLE_NAME = 'solazeroth_v3_fournisseur' AND COLUMN_NAME = 'pnj');")
    w("SET @requete = IF(@manque, 'ALTER TABLE solazeroth_v3_fournisseur ADD COLUMN pnj INT UNSIGNED NOT NULL DEFAULT "
      "910030 FIRST, DROP PRIMARY KEY, ADD PRIMARY KEY (pnj, objet)', 'DO 0');")
    w("PREPARE sol_requete FROM @requete;")
    w("EXECUTE sol_requete;")
    w("DEALLOCATE PREPARE sol_requete;")
    w("DELETE FROM solazeroth_v3_fournisseur WHERE pnj = %d;" % HRAQ)
    echappe = lambda s: s.replace("'", "''")
    w("INSERT INTO solazeroth_v3_fournisseur (pnj, objet, nom, prix, plafond) VALUES %s;" % ", ".join(
        "(%d, %d, '%s', %d, %d)" % (HRAQ, e, echappe(nom(e)), prix, PLAFOND) for e, prix in MATERIAUX))
    w("")
    w("-- Bateau de Cabestan fermé (décision 9).")
    w("CREATE TABLE IF NOT EXISTS solazeroth_v3_t9_transports_origine SELECT * FROM transports WHERE guid = %d;" % BATEAU)
    w("DELETE FROM transports WHERE guid = %d;" % BATEAU)
    w("")

    x = down.append
    x("-- Retour du lot T9 des Tarides : marchands, Hraq et bateau d'origine.")
    x("USE acore_world;")
    x("DELETE FROM npc_vendor WHERE entry IN (%s) AND item BETWEEN %d AND %d;" % (marchands, premiere, derniere))
    x("INSERT IGNORE INTO npc_vendor SELECT * FROM solazeroth_v3_t9_ventes_origine;")
    x("UPDATE creature_template c JOIN solazeroth_v3_t9_pnj_origine o ON o.entry = c.entry SET c.npcflag = o.npcflag, "
      "c.gossip_menu_id = o.gossip_menu_id, c.ScriptName = o.ScriptName;")
    x("DELETE FROM solazeroth_v3_fournisseur WHERE pnj = %d;" % HRAQ)
    x("INSERT IGNORE INTO transports SELECT * FROM solazeroth_v3_t9_transports_origine;")
    x("DROP TABLE IF EXISTS solazeroth_v3_t9_ventes_origine, solazeroth_v3_t9_pnj_origine, "
      "solazeroth_v3_t9_transports_origine;")
    x("")
    for suffixe, contenu in ((".up.sql", up), (".down.sql", down)):
        with open(MIGRATION + suffixe, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(contenu))
    print("Migration 142 écrite :", ", ".join("%d : %d pièces" % (v, len(ventes[v])) for v in ventes))


if __name__ == "__main__":
    main()
