@echo off
title Sol'Azeroth
powershell -NoProfile -File "%~dp0scripts\lanceur.ps1" %*
rem La fenêtre se ferme seule si tout s'est bien passé ; en cas d'erreur, elle reste ouverte pour la lire.
if errorlevel 1 (
    echo.
    echo Une erreur s'est produite : lis le message ci-dessus.
    pause
)
