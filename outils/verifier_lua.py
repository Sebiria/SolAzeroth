"""Vérifie la syntaxe des fichiers Lua avec Lua 5.1, la version du jeu et d'ALE (pip install lupa).

Usage : py outils\verifier_lua.py              (tous les addons et scripts ALE)
        py outils\verifier_lua.py fichier.lua  (fichiers choisis)
"""
import glob
import sys

import lupa.lua51 as lupa

lua = lupa.LuaRuntime()
compiler = lua.eval("function(s, n) local _, e = loadstring(s, n) return e end")
motifs = sys.argv[1:] or [r"C:\SolAzeroth\addons\*\*.lua", r"C:\SolAzeroth\lua_scripts\*.lua"]
erreurs = 0
for motif in motifs:
    for chemin in glob.glob(motif):
        with open(chemin, encoding="utf-8-sig") as f:
            erreur = compiler(f.read(), "=" + chemin)
        if erreur:
            erreurs += 1
            print("ERREUR", erreur)
print("Syntaxe correcte." if not erreurs else "%d fichier(s) en erreur." % erreurs)
sys.exit(1 if erreurs else 0)
