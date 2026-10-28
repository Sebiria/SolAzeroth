# Migrations SQL versionnées de Sol'Azeroth (dossier sql\migrations)
#   sans argument      : applique les migrations pas encore appliquées, après une sauvegarde avant-maj
#   -Annuler <numéro>  : rejoue le fichier .down.sql de cette migration et la marque comme non appliquée
#   -Liste             : affiche l'état des migrations
param([int]$Annuler, [switch]$Liste)
$ErrorActionPreference = 'Stop'

$racine = 'C:\SolAzeroth'
$mysql = 'C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe'
$identifiants = "$racine\config\mysql-acore.cnf"
$dossier = "$racine\sql\migrations"

function Sql([string]$requete) {
    $sortie = & $mysql "--defaults-extra-file=$identifiants" --default-character-set=utf8mb4 -N -B -e $requete
    if ($LASTEXITCODE -ne 0) { throw "Requête SQL en échec : $requete" }
    $sortie
}

function Fichier([string]$chemin) {
    & cmd.exe /c "`"$mysql`" `"--defaults-extra-file=$identifiants`" --default-character-set=utf8mb4 < `"$chemin`""
    if ($LASTEXITCODE -ne 0) { throw "Échec de $([IO.Path]::GetFileName($chemin))" }
}

Sql "CREATE TABLE IF NOT EXISTS acore_characters.solazeroth_migrations (numero INT UNSIGNED NOT NULL PRIMARY KEY, nom VARCHAR(128) NOT NULL, applique_le DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP) ENGINE=InnoDB" | Out-Null
$appliquees = @(Sql "SELECT numero FROM acore_characters.solazeroth_migrations" | ForEach-Object { [int]$_ })

$migrations = Get-ChildItem $dossier -Filter '*.up.sql' | Sort-Object Name | ForEach-Object {
    [pscustomobject]@{ Numero = [int]($_.Name.Split('_')[0]); Nom = $_.Name -replace '\.up\.sql$', ''; Up = $_.FullName; Down = $_.FullName -replace '\.up\.sql$', '.down.sql' }
}

if ($Liste) {
    $migrations | ForEach-Object { "{0}  {1}" -f $(if ($appliquees -contains $_.Numero) { '[x]' } else { '[ ]' }), $_.Nom }
    return
}

if ($Annuler) {
    $m = $migrations | Where-Object Numero -eq $Annuler
    if (-not $m) { throw "Migration $Annuler introuvable" }
    if ($appliquees -notcontains $Annuler) { throw "La migration $Annuler n'est pas appliquée" }
    & "$PSScriptRoot\sauvegarde.ps1" -Type avant-maj
    Write-Output "Annulation de $($m.Nom)..."
    Fichier $m.Down
    Sql "DELETE FROM acore_characters.solazeroth_migrations WHERE numero = $Annuler" | Out-Null
    Write-Output 'Annulation terminée.'
    return
}

$aFaire = @($migrations | Where-Object { $appliquees -notcontains $_.Numero })
if ($aFaire.Count -eq 0) { Write-Output 'Base à jour.'; return }

& "$PSScriptRoot\sauvegarde.ps1" -Type avant-maj
foreach ($m in $aFaire) {
    Write-Output "Migration $($m.Nom)..."
    Fichier $m.Up
    Sql "INSERT INTO acore_characters.solazeroth_migrations (numero, nom) VALUES ($($m.Numero), '$($m.Nom)')" | Out-Null
}
Write-Output "$($aFaire.Count) migration(s) appliquée(s)."
