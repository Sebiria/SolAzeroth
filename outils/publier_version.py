"""Fabrique les fichiers à publier d'une version de Sol'Azeroth (version publique, 02/11/2026).

Usage : py outils\\publier_version.py 3.0.0 [--complet] [--notes notes.md] [--version-min 3.0.0]

Sorties dans dist\\ :
- SolAzeroth-<version>.solmaj : la mise à jour, appliquée par le menu du lanceur (scripts\\mise_a_jour.ps1). Elle est
  cumulative : tout le programme y est (serveur, scripts, migrations, patch client, data\\dbc), on peut donc sauter des
  versions. --version-min : archive complète la plus ancienne qu'elle accepte (cartes et MySQL compatibles).
- avec --complet, SolAzeroth-<version>.zip : l'archive à extraire, avec en plus les cartes (data), MySQL portable et
  la base de départ (monde à jour de toutes les migrations, sans personnage ni compte).

Le client WoW n'est jamais inclus. Les migrations doivent toutes être appliquées sur la base de développement.
"""
import argparse
import datetime
import glob
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
import zipfile

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BIN = os.path.join(RACINE, "build", "bin", "RelWithDebInfo")
MYSQL = r"C:\Program Files\MySQL\MySQL Server 8.4"
IDENTIFIANTS = os.path.join(RACINE, "config", "mysql-acore.cnf")
DIST = os.path.join(RACINE, "dist")
SYSTEME = os.path.join(os.environ.get("SystemRoot", r"C:\Windows"), "System32")

# Exécutables MySQL utiles au jeu, et bibliothèques Visual C++ livrées à côté du serveur (déploiement local permis).
MYSQL_EXE = ["mysqld.exe", "mysql.exe", "mysqldump.exe", "mysqladmin.exe"]
VCRUNTIME = ["msvcp140.dll", "msvcp140_1.dll", "msvcp140_2.dll", "vcruntime140.dll", "vcruntime140_1.dll", "concrt140.dll"]

# Tables à contenu fixe, livrées avec leurs lignes ; les autres (personnages, comptes, progression) sont vides.
DONNEES_FIXES = {
    "acore_auth": ["build_info", "motd", "rbac_default_permissions", "rbac_linked_permissions", "rbac_permissions",
                   "realmlist", "updates", "updates_include"],
    "acore_characters": ["solazeroth_migrations", "updates", "updates_include", "worldstates", "world_state",
                         "active_arena_season", "warden_action", "mail_server_template",
                         "mail_server_template_conditions", "mail_server_template_items"],
}

LISEZMOI = """Sol'Azeroth {version} — World of Warcraft 3.3.5a solo et hors ligne
=====================================================================

Il te faut ton propre client World of Warcraft 3.3.5a (build 12340) en français (frFR).
Il n'est pas fourni : c'est un logiciel de Blizzard, on n'a pas le droit de le distribuer.

Installation
1. Extrais cette archive où tu veux (évite Program Files).
2. Double-clique « Sol'Azeroth.bat ». Au premier lancement, choisis le dossier de ton client WoW
   (celui qui contient Wow.exe) ; la base se prépare ensuite en quelques minutes.
3. Clique « Jouer ». La connexion se fait toute seule (Maj enfoncée pour l'éviter).

Mises à jour
Télécharge le fichier .solmaj de la nouvelle version, puis dans le menu : « Appliquer une mise à jour… ».
Tes personnages sont gardés, une sauvegarde est faite avant.

Bugs
Touche « ! » en jeu pour signaler un bug à l'endroit où tu es. Bouton « Exporter » de cette fenêtre (ou du menu) :
tu choisis où enregistrer un fichier .txt, à envoyer au développeur. Les signalements exportés quittent le jeu.

Tout reste sur ton PC : le serveur n'écoute que ta propre machine (127.0.0.1).
Sources (GPL-2.0) : https://github.com/Sebiria/SolAzeroth
Ce projet n'est pas affilié à Blizzard Entertainment ni à AzerothCore.
"""

LANCEUR_BAT = """@echo off
title Sol'Azeroth
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\\menu.ps1"
if errorlevel 1 pause
"""


def fichiers_dossier(source, destination, exclus=()):
    """(chemin dans l'archive, chemin sur le disque) de tous les fichiers d'un dossier."""
    for dossier, sous, noms in os.walk(source):
        sous[:] = [d for d in sous if d not in ("__pycache__",)]
        for nom in noms:
            if any(nom.lower().endswith(e) for e in exclus):
                continue
            chemin = os.path.join(dossier, nom)
            yield destination + "/" + os.path.relpath(chemin, source).replace("\\", "/"), chemin


def programme():
    """Ce qui change d'une version à l'autre : le contenu de chaque .solmaj (et de l'archive complète)."""
    for nom in ["worldserver.exe", "authserver.exe"]:
        yield "serveur/" + nom, os.path.join(BIN, nom)
    for chemin in glob.glob(os.path.join(BIN, "*.dll")):
        yield "serveur/" + os.path.basename(chemin), chemin
    for nom in VCRUNTIME:
        if os.path.exists(os.path.join(SYSTEME, nom)):
            yield "serveur/" + nom, os.path.join(SYSTEME, nom)
    for chemin in glob.glob(os.path.join(BIN, "configs", "*.dist")) + glob.glob(os.path.join(BIN, "configs", "modules", "*.dist")):
        yield "serveur/" + os.path.relpath(chemin, BIN).replace("\\", "/"), chemin
    yield from fichiers_dossier(os.path.join(RACINE, "lua_scripts"), "lua_scripts")
    yield from fichiers_dossier(os.path.join(RACINE, "addons"), "addons")
    yield from fichiers_dossier(os.path.join(RACINE, "scripts"), "scripts")
    yield from fichiers_dossier(os.path.join(RACINE, "sql", "migrations"), "sql/migrations")
    yield from fichiers_dossier(os.path.join(RACINE, "data", "dbc"), "data/dbc")
    yield "patch-client/patch-frFR-4.MPQ", os.path.join(RACINE, "patch-client", "patch-frFR-4.MPQ")


def complements():
    """Ce que seule l'archive complète contient : cartes, MySQL portable, licences."""
    for nom in ["Cameras", "maps", "vmaps", "mmaps"]:
        yield from fichiers_dossier(os.path.join(RACINE, "data", nom), "data/" + nom)
    for nom in MYSQL_EXE:
        yield "mysql/bin/" + nom, os.path.join(MYSQL, "bin", nom)
    for chemin in glob.glob(os.path.join(MYSQL, "bin", "*.dll")):
        nom = os.path.basename(chemin).lower()
        if "debug" not in nom and not nom.startswith("mysqlrouter"):
            yield "mysql/bin/" + os.path.basename(chemin), chemin
    yield from fichiers_dossier(os.path.join(MYSQL, "share", "english"), "mysql/share/english")
    yield from fichiers_dossier(os.path.join(MYSQL, "share", "charsets"), "mysql/share/charsets")
    for nom in ["messages_to_clients.txt", "messages_to_error_log.txt", "dictionary.txt"]:
        yield "mysql/share/" + nom, os.path.join(MYSQL, "share", nom)
    yield "mysql/LICENSE", os.path.join(MYSQL, "LICENSE")
    yield "LICENSE", os.path.join(RACINE, "azerothcore", "LICENSE")


def requete(sql):
    sortie = subprocess.run([os.path.join(MYSQL, "bin", "mysql.exe"), "--defaults-extra-file=" + IDENTIFIANTS, "-N", "-B",
                             "-e", sql], capture_output=True, text=True, encoding="utf-8", check=True)
    return [ligne.split("\t") for ligne in sortie.stdout.splitlines()]


def verifier_migrations():
    appliquees = {int(l[0]) for l in requete("SELECT numero FROM acore_characters.solazeroth_migrations")}
    fichiers = {int(os.path.basename(f).split("_")[0]) for f in glob.glob(os.path.join(RACINE, "sql", "migrations", "*.up.sql"))}
    manque = sorted(fichiers - appliquees)
    if manque:
        sys.exit("Migrations pas encore appliquées sur la base : %s (lance Jouer.bat ou scripts\\migrer.ps1)." % manque)


def dump(base, sortie, options):
    with open(sortie, "ab") as f:
        subprocess.run([os.path.join(MYSQL, "bin", "mysqldump.exe"), "--defaults-extra-file=" + IDENTIFIANTS,
                        "--single-transaction", "--no-tablespaces", "--default-character-set=utf8mb4"] + options,
                       stdout=f, check=True)


def base_de_depart(dossier):
    """Dumps de départ : le monde entier ; comptes et personnages en structure seule, sauf les tables fixes."""
    fichiers = []
    for base in ["acore_auth", "acore_characters", "acore_world"]:
        sortie = os.path.join(dossier, base + ".sql")
        open(sortie, "wb").close()
        print("  dump de", base)
        if base == "acore_world":
            dump(base, sortie, ["--databases", base])
        else:
            dump(base, sortie, ["--no-data", "--databases", base])
            dump(base, sortie, ["--no-create-info", base] + DONNEES_FIXES[base])
            # Sans compteur AUTO_INCREMENT : il trahirait le nombre de lignes de la base de développement.
            with open(sortie, "rb") as f:
                texte = re.sub(rb"(\) ENGINE=[^\n]*?) AUTO_INCREMENT=\d+", rb"\1", f.read())
            with open(sortie, "wb") as f:
                f.write(texte)
        fichiers.append(("base/%s.sql" % base, sortie))
    return fichiers


def empreinte(chemin):
    h = hashlib.sha256()
    with open(chemin, "rb") as f:
        for bloc in iter(lambda: f.read(1 << 20), b""):
            h.update(bloc)
    return h.hexdigest().upper()


def ecrire_zip(chemin, contenu, textes):
    """contenu : (chemin dans l'archive, fichier) ; textes : (chemin dans l'archive, texte)."""
    os.makedirs(os.path.dirname(chemin), exist_ok=True)
    with zipfile.ZipFile(chemin + ".tmp", "w", zipfile.ZIP_DEFLATED, compresslevel=6) as z:
        for nom, texte in textes:
            z.writestr(nom, texte.encode("utf-8"))
        for nom, fichier in contenu:
            z.write(fichier, nom)
    os.replace(chemin + ".tmp", chemin)
    print("Écrit :", chemin, "(%.0f Mo)" % (os.path.getsize(chemin) / 1048576))


def main():
    p = argparse.ArgumentParser()
    p.add_argument("version")
    p.add_argument("--complet", action="store_true")
    p.add_argument("--notes")
    p.add_argument("--version-min")
    a = p.parse_args()
    notes = open(a.notes, encoding="utf-8-sig").read() if a.notes else ""

    prog = list(programme())
    manquants = [f for _, f in prog if not os.path.exists(f)]
    if manquants:
        sys.exit("Fichiers introuvables : %s" % manquants)
    textes = [("version.txt", a.version + "\n"), ("Sol'Azeroth.bat", LANCEUR_BAT.replace("\n", "\r\n")),
              ("LISEZMOI.txt", LISEZMOI.format(version=a.version).replace("\n", "\r\n"))]

    # La mise à jour : le programme, version.txt et le lanceur, avec leurs empreintes.
    with tempfile.TemporaryDirectory() as travail:
        petits = []
        for nom, texte in textes:
            chemin = os.path.join(travail, nom)
            with open(chemin, "w", encoding="utf-8", newline="") as f:
                f.write(texte)
            petits.append((nom, chemin))
        maj = [("fichiers/" + n, f) for n, f in petits + prog]
        manifeste = {"version": a.version, "version_min": a.version_min or a.version,
                     "date": datetime.date.today().isoformat(), "notes": notes,
                     "empreintes": {n[len("fichiers/"):]: empreinte(f) for n, f in maj}}
        ecrire_zip(os.path.join(DIST, "SolAzeroth-%s.solmaj" % a.version), maj,
                   [("manifeste.json", json.dumps(manifeste, ensure_ascii=False, indent=1))])

        if a.complet:
            verifier_migrations()
            base = base_de_depart(travail)
            prefixe = "SolAzeroth-%s/" % a.version
            contenu = [(prefixe + n, f) for n, f in prog + list(complements()) + base]
            ecrire_zip(os.path.join(DIST, "SolAzeroth-%s.zip" % a.version), contenu,
                       [(prefixe + n, t) for n, t in textes])


if __name__ == "__main__":
    main()
