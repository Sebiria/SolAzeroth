@echo off
title Sol'Azeroth - Restauration
echo Restaure la sauvegarde la plus recente (personnages et comptes).
echo L'etat actuel est d'abord copie dans une sauvegarde "avant-restauration".
echo.
set /p ok=Continuer ? (o/n)
if /i not "%ok%"=="o" exit /b
powershell -NoProfile -File "%~dp0scripts\restaurer.ps1" %*
echo.
pause
