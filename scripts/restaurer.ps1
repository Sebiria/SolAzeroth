# Restauration d'une sauvegarde Sol'Azeroth
#   sans argument : restaure la sauvegarde courante la plus récente
#   -Dossier <chemin> : restaure ce dossier de sauvegarde précis
param([string]$Dossier)
$ErrorActionPreference = 'Stop'

$racine = 'C:\SolAzeroth'
$mysql = 'C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe'
$identifiants = "$racine\config\mysql-acore.cnf"

if (Get-Process worldserver, authserver -ErrorAction SilentlyContinue) {
    throw "Le serveur tourne encore. Ferme le jeu et attends l'arrêt du serveur avant de restaurer."
}

if (-not $Dossier) {
    $Dossier = Get-ChildItem "$racine\backups\courantes" -Directory -ErrorAction SilentlyContinue |
        Where-Object Name -notlike '*_avant-restauration' |
        Sort-Object Name -Descending | Select-Object -First 1 -ExpandProperty FullName
    if (-not $Dossier) { throw "Aucune sauvegarde trouvée dans $racine\backups\courantes" }
}
$fichiers = Get-ChildItem $Dossier -Filter *.sql
if (-not $fichiers) { throw "Aucun fichier .sql dans $Dossier" }

Write-Output "Restauration de : $Dossier"
Write-Output "Copie de sécurité de l'état actuel avant de restaurer..."
& "$PSScriptRoot\sauvegarde.ps1" -Type avant-restauration

foreach ($f in $fichiers) {
    Write-Output "  $($f.Name)..."
    & cmd.exe /c "`"$mysql`" `"--defaults-extra-file=$identifiants`" --default-character-set=utf8mb4 < `"$($f.FullName)`""
    if ($LASTEXITCODE -ne 0) { throw "Échec de la restauration de $($f.Name) (code $LASTEXITCODE)" }
}
Write-Output "Restauration terminée."
