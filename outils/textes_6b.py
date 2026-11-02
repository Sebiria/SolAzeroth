"""Audit du jeu, lot 6b (02/11/2026, C8 du consensus) : les textes de Durotar.
- Reliques : une description qui raconte quelque chose, à la place de « Relique (famille), annexe A31 de Durotar ».
- Annexes : la voix du PNJ séparée de la liste des récompenses (deux sauts de ligne, la liste en gris).
- Accord au genre du joueur ($G) des textes qui s'adressent à lui.
- Ruga Brise-cendre : sa propre apparence (celle de la Grunt Mojka), plus celle de Zureetha Mireloin.
- PNJ de Durotar, d'Orgrimmar et du Gouffre qui affichent un indicateur de quête sans en avoir : drapeau retiré.
Les générateurs d'origine (annexes_durotar.py, document de l'histoire) reçoivent les mêmes accords ; leurs migrations
déjà appliquées (063, 066, 104) ne sont pas réécrites.

py textes_6b.py   (écrit la migration 120)
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import annexes_durotar as annexes
from quetes_durotar import s

MIGRATION = r"C:\SolAzeroth\sql\migrations\120_v3_textes"
RUGA, APPARENCE_RUGA, APPARENCE_ZUREETHA = 910001, 3564, 1875

RECITS = {
    "A31": "Sa lame sent encore le soufre. Yarrog s'en servait pour ouvrir la paume de ses recrues et sceller leur serment dans le sang.",
    "A32": "« Le Chef de guerre vous a faits esclaves de la paix. La Lame vous rendra le feu. » L'écriture est soignée, presque fière.",
    "A33": "Les fidèles du culte portent des colliers brûlants. Celui-ci est froid : son porteur a renié la Lame, et la Lame ne l'a pas pardonné.",
    "A34": "Une bougie de graisse noire, fondue sur un autel. Féplouf en allumait une à chaque orage qu'il appelait.",
    "A35": "Le sceau montre une lame dans les flammes. Les ordres désignent les fermes à brûler, et la date est proche.",
    "A36": "Un masque modelé dans la cendre d'un bûcher. Le gangretisseur le portait pour parler aux démons sans qu'ils voient son visage.",
    "A37": "Gravée aux armes de Portvaillant. Benedict la gardait pour guetter une flotte qui ne viendra plus.",
    "A38": "Les dernières pages parlent d'une tempête, d'un récif et d'un équipage qui rêvait de rentrer à Kul Tiras. L'encre a coulé sur le reste.",
    "A39": "Un marin de Tiragarde écrit à sa fille, à Boralus. Il promet de rentrer avant l'hiver. La lettre n'est jamais partie.",
    "A40": "Arraché d'un uniforme de marine. Celui qui l'a jeté a préféré la terre rouge des orcs aux ordres d'un amiral mort.",
    "A41": "Une demande de renforts pour Tiragarde, adressée à Theramore. Le sceau n'a jamais été brisé.",
    "A42": "Taillé par les anciens de Sen'jin, il gardait les huttes des mauvais esprits. Les Kolkar l'ont pris comme trophée.",
    "A43": "Les Sombrelances le posaient sur l'autel des loas avant chaque pêche. Zalazane évite cet îlot : les loas s'y souviennent de lui.",
    "A44": "Un présent de chasse, sculpté pour un chef troll mort depuis longtemps. Les esprits de la terre l'ont gardé pour lui.",
    "A45": "Des perles pêchées une à une par les enfants de Sen'jin. Le renégat l'a volé pour le revendre aux pirates.",
    "A46": "Une offrande aux loas de la mer, jetée à l'eau pour une pêche heureuse. Le requin l'a gardée plus longtemps que prévu.",
}

# (quête, champ, texte d'avant, texte d'après) ; quest_template.QuestDescription ou quest_request_items.CompletionText.
GENRE = [
    (910013, "D", "Ne t'y risque pas avant d'être prêt.", "Ne t'y risque pas avant d'être $Gprêt:prête;."),
    (910024, "D", "Si tu n'es pas prêt, attends de l'être.", "Si tu n'es pas $Gprêt:prête;, attends de l'être."),
    (910026, "P", "Toi, es-tu prêt ?", "Toi, es-tu $Gprêt:prête; ?"),
    (910211, "D", "quand tu seras mieux équipé,", "quand tu seras mieux $Géquipé:équipée;,"),
    (910227, "D", "Dis-moi quand tu es prêt.", "Dis-moi quand tu es $Gprêt:prête;."),
]
CHAMPS = {"D": ("quest_template", "QuestDescription"), "P": ("quest_request_items", "CompletionText")}
# Zones où l'indicateur de quête est corrigé : Durotar, Orgrimmar ; et le Gouffre de Ragefeu (carte 389).
ZONES, GOUFFRE = (14, 1637), 389


def recompense(a):
    """RewardText : la voix du PNJ, puis les récompenses en gris (0x b4b8bf, le gris de l'interface)."""
    liste = annexes.recompense_texte(a)
    return a["fin"] + ("$B$B|cffb4b8bfRécompenses : %s|r" % liste if liste else "")


def main():
    up = ["-- Audit du jeu, lot 6b (02/11/2026, C8) : textes de Durotar. Généré par outils\\textes_6b.py : ne pas modifier",
          "-- à la main.",
          "USE acore_world;"]
    down = ["USE acore_world;"]
    for i, (cle, *_r) in enumerate(annexes.RELIQUES):
        objet = annexes.RELIQUE + i
        up.append("UPDATE item_template SET description = %s WHERE entry = %d;" % (s(RECITS[cle]), objet))
        up.append("UPDATE item_template_locale SET Description = %s WHERE ID = %d AND locale = 'frFR';"
                  % (s(RECITS[cle]), objet))
        ancien = "Relique (%s), annexe %s de Durotar." % (annexes.FAMILLES[_r[1]], cle)
        down.append("UPDATE item_template SET description = %s WHERE entry = %d;" % (s(ancien), objet))
        down.append("UPDATE item_template_locale SET Description = %s WHERE ID = %d AND locale = 'frFR';"
                    % (s(ancien), objet))
    for a in annexes.A:
        up.append("UPDATE quest_offer_reward SET RewardText = %s WHERE ID = %d;" % (s(recompense(a)), a["q"]))
        down.append("UPDATE quest_offer_reward SET RewardText = %s WHERE ID = %d;"
                    % (s((a["fin"] + " " + annexes.recompense_texte(a)).strip()), a["q"]))
    for quete, champ, avant, apres in GENRE:
        table, colonne = CHAMPS[champ]
        cle = "ID"
        up.append("UPDATE %s SET %s = REPLACE(%s, %s, %s) WHERE %s = %d;" % (table, colonne, colonne, s(avant), s(apres), cle, quete))
        down.append("UPDATE %s SET %s = REPLACE(%s, %s, %s) WHERE %s = %d;" % (table, colonne, colonne, s(apres), s(avant), cle, quete))
    up.append("UPDATE creature_template_model SET CreatureDisplayID = %d WHERE CreatureID = %d AND Idx = 0;"
              % (APPARENCE_RUGA, RUGA))
    down.append("UPDATE creature_template_model SET CreatureDisplayID = %d WHERE CreatureID = %d AND Idx = 0;"
                % (APPARENCE_ZUREETHA, RUGA))
    up += ["CREATE TABLE IF NOT EXISTS solazeroth_v3_faux_indicateurs (entry INT UNSIGNED NOT NULL PRIMARY KEY);",
           "INSERT IGNORE INTO solazeroth_v3_faux_indicateurs SELECT DISTINCT t.entry FROM creature c JOIN creature_template t "
           "ON t.entry = c.id WHERE (c.zoneId IN (%s) OR c.map = %d) AND (t.npcflag & 2) "
           "AND NOT EXISTS (SELECT 1 FROM creature_queststarter q WHERE q.id = t.entry) "
           "AND NOT EXISTS (SELECT 1 FROM creature_questender q WHERE q.id = t.entry);" % (", ".join(map(str, ZONES)), GOUFFRE),
           "UPDATE creature_template t JOIN solazeroth_v3_faux_indicateurs f ON f.entry = t.entry SET t.npcflag = t.npcflag & ~2;",
           ""]
    down += ["UPDATE creature_template t JOIN solazeroth_v3_faux_indicateurs f ON f.entry = t.entry SET t.npcflag = t.npcflag | 2;",
             "DROP TABLE IF EXISTS solazeroth_v3_faux_indicateurs;", ""]
    for suffixe, lignes in ((".up.sql", up), (".down.sql", down)):
        with open(MIGRATION + suffixe, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(lignes))
    print("Migration 120 écrite : %d reliques, %d annexes, %d accords." % (len(annexes.RELIQUES), len(annexes.A), len(GENRE)))


if __name__ == "__main__":
    main()
