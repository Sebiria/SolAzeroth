# Sauvegarde des bases Sol'Azeroth
#   -Type auto | manuelle | fermeture | avant-restauration : personnages + comptes,
#         rangées dans backups\courantes (les 10 plus récentes sont gardées)
#   -Type avant-maj : personnages + comptes + monde, rangées dans backups\avant-maj (toutes gardées)
param(
    [Parameter(Mandatory)][ValidateSet('auto', 'manuelle', 'fermeture', 'avant-restauration', 'avant-maj')][string]$Type,
    [int]$Garder = 10
)
$ErrorActionPreference = 'Stop'

$racine = 'C:\SolAzeroth'
$mysqldump = 'C:\Program Files\MySQL\MySQL Server 8.4\bin\mysqldump.exe'
$identifiants = "$racine\config\mysql-acore.cnf"

$bases = @('acore_characters', 'acore_auth')
$dossierType = 'courantes'
if ($Type -eq 'avant-maj') {
    $bases += 'acore_world'
    $dossierType = 'avant-maj'
}

$destination = Join-Path "$racine\backups\$dossierType" ("{0}_{1}" -f (Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'), $Type)
New-Item -ItemType Directory -Force $destination | Out-Null

foreach ($base in $bases) {
    $fichier = Join-Path $destination "$base.sql"
    & $mysqldump "--defaults-extra-file=$identifiants" --single-transaction --no-tablespaces `
        --default-character-set=utf8mb4 --result-file=$fichier --databases $base
    if ($LASTEXITCODE -ne 0) {
        Remove-Item -Recurse -Force $destination
        throw "Échec de la sauvegarde de $base (code $LASTEXITCODE)"
    }
}

if ($dossierType -eq 'courantes') {
    Get-ChildItem "$racine\backups\courantes" -Directory | Sort-Object Name -Descending |
        Select-Object -Skip $Garder | Remove-Item -Recurse -Force
}

Write-Output "Sauvegarde $Type terminée : $destination"
