# Applique un fichier de mise à jour Sol'Azeroth (.solmaj), fabriqué par outils\publier_version.py.
# Un .solmaj est un zip :
#   manifeste.json   version, version_min (archive de base requise), date, notes, empreintes SHA-256 des fichiers
#   fichiers\...     arborescence recopiée sur l'installation (serveur, scripts, migrations, patch client, data\dbc...)
# Une mise à jour est cumulative : elle contient tout le programme, on peut donc sauter des versions.
# Jamais touchés : la base (mysql\data), config\, backups\, journaux\, logs\.
param([Parameter(Mandatory)][string]$Fichier)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\commun.ps1"
Add-Type -AssemblyName System.IO.Compression.FileSystem

if (-not $portable) { throw "Installation de développement : les mises à jour .solmaj sont pour l'archive des joueurs." }
if (Get-Process worldserver, authserver -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "$racine\*" }) {
    throw 'Le serveur tourne : ferme le jeu avant de mettre à jour.'
}

$zip = [IO.Compression.ZipFile]::OpenRead($Fichier)
try {
    $entree = $zip.GetEntry('manifeste.json')
    if (-not $entree) { throw "Ce fichier n'est pas une mise à jour Sol'Azeroth (pas de manifeste)." }
    $lecteur = New-Object IO.StreamReader($entree.Open(), [Text.Encoding]::UTF8)
    $manifeste = $lecteur.ReadToEnd() | ConvertFrom-Json
    $lecteur.Close()

    $actuelle = [version](Version)
    if ($actuelle -lt [version]$manifeste.version_min) {
        throw "Cette mise à jour demande au moins la version $($manifeste.version_min) (tu as la $actuelle) : télécharge l'archive complète."
    }
    Write-Output "Mise à jour $actuelle -> $($manifeste.version)"

    # Extraction dans un dossier de travail, empreintes vérifiées avant de toucher à l'installation.
    $travail = "$runtime\mise-a-jour"
    Remove-Item $travail -Recurse -Force -ErrorAction SilentlyContinue
    $attendus = @{}
    $manifeste.empreintes.PSObject.Properties | ForEach-Object { $attendus[$_.Name] = $_.Value }
    $interdits = '^(mysql/data|config|backups|journaux|logs)(/|$)'
    foreach ($e in $zip.Entries) {
        if ($e.FullName -eq 'manifeste.json' -or $e.FullName.EndsWith('/')) { continue }
        if (-not $e.FullName.StartsWith('fichiers/')) { throw "Fichier inattendu : $($e.FullName)" }
        $relatif = $e.FullName.Substring(9)
        if ($relatif -match '(^|/)\.\.(/|$)' -or $relatif -match $interdits -or $relatif -match ':') { throw "Chemin refusé : $relatif" }
        if (-not $attendus.ContainsKey($relatif)) { throw "Fichier hors manifeste : $relatif" }
        $cible = Join-Path $travail $relatif
        New-Item -ItemType Directory -Force (Split-Path $cible) | Out-Null
        [IO.Compression.ZipFileExtensions]::ExtractToFile($e, $cible, $true)
        $empreinte = (Get-FileHash $cible -Algorithm SHA256).Hash
        if ($empreinte -ne $attendus[$relatif]) { throw "Fichier abîmé : $relatif (télécharge à nouveau la mise à jour)" }
        $attendus.Remove($relatif)
    }
    if ($attendus.Count) { throw "Fichiers manquants dans la mise à jour : $($attendus.Keys -join ', ')" }
} finally { $zip.Dispose() }

# Recopie, puis migrations SQL (migrer.ps1 fait d'abord une sauvegarde avant-maj) et réglages.
Copy-Item "$travail\*" $racine -Recurse -Force
Remove-Item $travail -Recurse -Force
& "$PSScriptRoot\migrer.ps1"
& "$PSScriptRoot\configurer.ps1" | Out-Null
Write-Output "Version $(Version) installée."
if ($manifeste.notes) { Write-Output ''; Write-Output $manifeste.notes }
