"""Vérifie les outils : lecture du patch mod-arac, aller-retour des DBC, écriture d'un MPQ relu."""
import os
import time

import dbc
import mpq

with open(r"C:\SolAzeroth\config\client.txt", encoding="utf-8-sig") as f:
    CLIENT = os.path.join(f.readline().strip(), "Data")
ARAC = r"C:\SolAzeroth\azerothcore\modules\mod-arac\patch-contents\DBFilesContent"

for nom in ["CharBaseInfo", "CharStartOutfit", "SkillRaceClassInfo"]:
    contenu = mpq.lire(os.path.join(CLIENT, "Patch-A.MPQ"), "DBFilesClient\\" + nom + ".dbc")
    with open(os.path.join(ARAC, nom + ".dbc"), "rb") as f:
        print("Patch-A", nom, "identique :", contenu == f.read())

fichiers = {}
for nom in ["Achievement", "Achievement_Criteria", "Spell", "CurrencyTypes"]:
    with open(r"C:\SolAzeroth\data\dbc\%s.dbc" % nom, "rb") as f:
        brut = f.read()
    d = dbc.Dbc(brut)
    print(nom, len(d.enregistrements), "lignes,", d.nb_champs, "champs, aller-retour :", d.octets() == brut)
    fichiers["DBFilesClient\\" + nom + ".dbc"] = brut

debut = time.time()
sortie = os.path.join(os.environ["TEMP"], "test_solazeroth.MPQ")
mpq.ecrire(sortie, fichiers)
print("MPQ écrit :", os.path.getsize(sortie), "octets en", round(time.time() - debut, 1), "s")
print("Liste :", mpq.lister(sortie))
print("Relecture identique :", all(mpq.lire(sortie, k) == v for k, v in fichiers.items()))
os.remove(sortie)
