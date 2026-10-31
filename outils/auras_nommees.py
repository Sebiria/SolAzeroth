"""Auras Sol'Azeroth avec un vrai nom (V7).

Ajoute des sorts d'aura sans effet (aura factice), qui ne servent qu'à l'affichage : le module calcule les effets.
- côté client : Spell.dbc complet dans patch-client\\fichiers\\DBFilesClient ;
- côté serveur : migration SQL dans la table spell_dbc (le serveur y lit les sorts en plus de Spell.dbc).
"""
import os
import subprocess

import dbc
import icones_retail
import techniques_v3
from hauts_faits_natifs import DBC_CLIENT, DBC_SERVEUR, FRFR, IDENTIFIANTS, MASQUE, MYSQL, sql_texte

MIGRATION = r"C:\SolAzeroth\sql\migrations\050_auras_nommees"
MODELE = 17498                      # « Vitesse » : aura simple sur soi, sans visuel

DEBUFF = 0x04000000                 # SPELL_ATTR0_AURA_IS_DEBUFF
SANS_ANNULATION = 0x80000000        # SPELL_ATTR0_CANT_CANCEL
APRES_LA_MORT = 0x00100000          # SPELL_ATTR3_DEATH_PERSISTENT

# id, nom, description (infobulle de l'aura), icône (SpellIcon.dbc), cumuls max, néfaste
AURAS = [
    (100001, "Raid épuisé",
     "Quatrième passage du jour dans ce raid : le butin rare y est réduit jusqu'à demain.", 134, 0, True),
    (100002, "Sous-équipé",
     "Équipement trop faible pour ce monstre. Chaque cumul : -1 % de dégâts et de soins infligés, +1 % de dégâts subis.", 2771, 20, True),
    (100003, "Bien équipé",
     "Équipement supérieur au niveau de ce monstre. Chaque cumul : +1 % de dégâts et de soins infligés.", 291, 10, False),
]

TEXTES = [136, 153, 170, 187]       # nom, rang, description, infobulle (16 langues puis un masque)

# Sorts à incantation sans effet propre (le module agit à la fin de l'incantation, via un SpellScript).
# Calibrage final (29/10/2026) : migration 058, à part de la 050 déjà appliquée.
MIGRATION_INCANTATIONS = r"C:\SolAzeroth\sql\migrations\058_incantations"
MODELE_INCANTATION = 8690           # Pierre de foyer : 10 s d'incantation, interrompue par le mouvement
INTERRUPTION = 0x01 | 0x08 | 0x10   # mouvement, interruption, arrêt sur dégâts directs (SPELL_INTERRUPT_FLAG_ABORT_ON_DMG)
# id, nom, description, icône (SpellIcon.dbc ; 2970 : celle de la double spécialisation), nom du SpellScript du module
INCANTATIONS = [
    (100004, "Changement de spécialisation",
     "Change d'emplacement de spécialisation. Interrompu par le mouvement et par les dégâts.", 2970,
     "spell_solazeroth_changement_spe"),
]


def nouvelle_aura(d, modele, ident, nom, texte, icone, cumuls, nefaste):
    e = list(modele)
    e[0] = ident
    e[4] = SANS_ANNULATION | (DEBUFF if nefaste else 0)
    e[5:12] = [0] * 7
    e[7] = APRES_LA_MORT
    e[40] = 21                      # durée infinie
    e[49] = cumuls
    e[95] = 4                       # SPELL_AURA_DUMMY
    e[80] = 0xFFFFFFFF              # valeur de base -1, soit 0
    e[133] = icone
    for debut, chaine in zip(TEXTES, [nom, "", texte, texte]):
        e[debut:debut + 16] = [0] * 16
        if chaine:
            e[debut] = e[debut + FRFR] = d.ajouter_texte(chaine)
        e[debut + 16] = MASQUE if chaine else 0
    return e


def nouvelle_incantation(d, modele, ident, nom, texte, icone):
    e = list(modele)
    e[0] = ident
    e[1] = 0                        # pas de catégorie (la pierre de foyer partage sa recharge avec les objets)
    e[29] = e[30] = 0               # pas de recharge
    e[31] = INTERRUPTION
    e[71:74] = [3, 0, 0]            # SPELL_EFFECT_DUMMY sur le premier effet seulement
    e[74:77] = [0, 0, 0]
    e[80:83] = [0, 0, 0]
    e[86:89] = [1, 0, 0]            # TARGET_UNIT_CASTER
    e[89:92] = [0, 0, 0]
    e[95:98] = [0, 0, 0]
    e[133] = icone
    for debut, chaine in zip(TEXTES, [nom, "", texte, ""]):
        e[debut:debut + 16] = [0] * 16
        if chaine:
            e[debut] = e[debut + FRFR] = d.ajouter_texte(chaine)
        e[debut + 16] = MASQUE if chaine else 0
    return e


def ecrire_migration(chemin, entete, lignes_sql, retour):
    for suffixe, contenu in ((".up.sql", entete + lignes_sql), (".down.sql", retour)):
        with open(chemin + suffixe, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(contenu) + "\n")


def types_colonnes():
    sortie = subprocess.run([MYSQL, "--defaults-extra-file=" + IDENTIFIANTS, "-N", "-B", "-e",
                             "SELECT COLUMN_TYPE FROM information_schema.columns WHERE table_schema = 'acore_world' "
                             "AND table_name = 'spell_dbc' ORDER BY ORDINAL_POSITION"],
                            capture_output=True, check=True).stdout.decode()
    return sortie.splitlines()


def valeur_sql(d, type_colonne, valeur):
    if type_colonne.startswith(("varchar", "text")):
        return sql_texte(d.texte(valeur)) if valeur else "NULL"
    if type_colonne == "float":
        return repr(dbc.flottant(valeur))
    if type_colonne == "int" and valeur >= 0x80000000:
        return str(valeur - 0x100000000)
    return str(valeur)


def main():
    d = dbc.Dbc.ouvrir(os.path.join(DBC_SERVEUR, "Spell.dbc"))
    modele = d.chercher(MODELE)
    lignes = [nouvelle_aura(d, modele, *a) for a in AURAS]
    incantations = [nouvelle_incantation(d, d.chercher(MODELE_INCANTATION), *i[:4]) for i in INCANTATIONS]
    kit = techniques_v3.lignes(d, icones_retail.identifiants())
    d.enregistrements.extend(lignes + incantations + kit)
    os.makedirs(DBC_CLIENT, exist_ok=True)
    d.enregistrer(os.path.join(DBC_CLIENT, "Spell.dbc"))

    premier, dernier = AURAS[0][0], AURAS[-1][0]
    up = ["-- Auras Sol'Azeroth nommées (V7). Généré par outils\\auras_nommees.py : ne pas modifier à la main.",
          "-- Le client lit les mêmes sorts dans patch-frFR-4.MPQ.",
          "USE acore_world;",
          "DELETE FROM spell_dbc WHERE ID BETWEEN %d AND %d;" % (premier, dernier)]
    types = types_colonnes()
    assert len(types) == d.nb_champs, "spell_dbc n'a pas le même nombre de colonnes que Spell.dbc"
    for e in lignes:
        up.append("INSERT INTO spell_dbc VALUES (%s);" % ", ".join(valeur_sql(d, t, v) for t, v in zip(types, e)))
    down = ["-- Retire les auras Sol'Azeroth nommées.", "USE acore_world;", up[3]]
    for suffixe, contenu in ((".up.sql", up), (".down.sql", down)):
        with open(MIGRATION + suffixe, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(contenu) + "\n")
    ids = ", ".join(str(i[0]) for i in INCANTATIONS)
    up = ["-- Sorts à incantation Sol'Azeroth (calibrage final). Généré par outils\\auras_nommees.py : ne pas modifier à la main.",
          "-- Le client lit les mêmes sorts dans patch-frFR-4.MPQ ; le module agit à la fin de l'incantation (SpellScript).",
          "USE acore_world;",
          "DELETE FROM spell_dbc WHERE ID IN (%s);" % ids,
          "DELETE FROM spell_script_names WHERE spell_id IN (%s);" % ids]
    sql = ["INSERT INTO spell_dbc VALUES (%s);" % ", ".join(valeur_sql(d, t, v) for t, v in zip(types, e)) for e in incantations]
    sql += ["INSERT INTO spell_script_names (spell_id, ScriptName) VALUES (%d, '%s');" % (i[0], i[4]) for i in INCANTATIONS]
    ecrire_migration(MIGRATION_INCANTATIONS, up, sql, ["-- Retire les sorts à incantation Sol'Azeroth.", "USE acore_world;", up[3], up[4]])
    ids = ", ".join(str(e[0]) for e in kit)
    up = ["-- v3, F3 : kit du guerrier tank. Généré par outils\\auras_nommees.py (techniques_v3.py) : ne pas modifier à la main.",
          "-- Le client lit les mêmes sorts dans patch-frFR-4.MPQ ; le Rempart et les effets propres sont dans v3_kit.cpp.",
          "USE acore_world;",
          "DELETE FROM spell_dbc WHERE ID IN (%s);" % ids,
          "DELETE FROM spell_script_names WHERE spell_id IN (%s);" % ids]
    sql = ["INSERT INTO spell_dbc VALUES (%s);" % ", ".join(valeur_sql(d, t, v) for t, v in zip(types, e)) for e in kit]
    sql += ["INSERT INTO spell_script_names (spell_id, ScriptName) VALUES (%d, '%s');" % s for s in sorted(techniques_v3.SCRIPTS.items())]
    ecrire_migration(techniques_v3.MIGRATION, up, sql, ["-- Retire le kit du guerrier tank v3.", "USE acore_world;", up[3], up[4]])
    print(len(lignes), "auras,", len(incantations), "incantation(s) et", len(kit), "techniques : Spell.dbc client, migrations 050, 058 et 061 écrits.")


if __name__ == "__main__":
    main()
