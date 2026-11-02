# Socle commun des scripts Sol'Azeroth (chargé par « . "$PSScriptRoot\commun.ps1" »).
# Version publique (02/11/2026) : plus aucun chemin imposé. L'installation est le dossier parent de scripts\ ; elle est
#   - « de développement » si le serveur compilé est dans build\bin\RelWithDebInfo et MySQL installé comme service ;
#   - « portable » (archive des joueurs) si le serveur est dans serveur\ et MySQL dans mysql\ (lancé à la demande).

$racine = Split-Path $PSScriptRoot -Parent
$portable = Test-Path "$racine\mysql\bin\mysqld.exe"
$bin = if (Test-Path "$racine\serveur\worldserver.exe") { "$racine\serveur" } else { "$racine\build\bin\RelWithDebInfo" }
$mysqlBin = if ($portable) { "$racine\mysql\bin" } else { 'C:\Program Files\MySQL\MySQL Server 8.4\bin' }
$mysql = "$mysqlBin\mysql.exe"
$identifiants = "$racine\config\mysql-acore.cnf"
$runtime = "$racine\runtime"
$logs = "$racine\logs"
# MySQL portable : port à part pour ne gêner aucune autre installation de MySQL.
$portMysql = 3310
# Compte de jeu créé par l'installation des joueurs (outils\interface_v3.py s'y connecte tout seul). Le serveur
# n'écoute que sur 127.0.0.1 : ce mot de passe public ne protège rien et n'a pas à le faire.
$compteLocal = 'SOLAZEROTH'
$motCompteLocal = 'solazeroth'
# Le serveur, les scripts ALE et le module lisent ce dossier dans la variable SOLAZEROTH_RACINE.
$env:SOLAZEROTH_RACINE = $racine

function Version {
    $v = Get-Content "$racine\version.txt" -TotalCount 1 -ErrorAction SilentlyContinue
    if ($v) { $v.Trim() } else { 'développement' }
}

function Sql([string]$requete) {
    $sortie = & $mysql "--defaults-extra-file=$identifiants" --default-character-set=utf8mb4 -N -B -e $requete
    if ($LASTEXITCODE -ne 0) { throw "Requête SQL en échec : $requete" }
    $sortie
}

function SqlFichier([string]$chemin) {
    & cmd.exe /c "`"$mysql`" `"--defaults-extra-file=$identifiants`" --default-character-set=utf8mb4 < `"$chemin`""
    if ($LASTEXITCODE -ne 0) { throw "Échec de $([IO.Path]::GetFileName($chemin))" }
}

# Outil MySQL en ligne de commande, messages écartés (sous PowerShell 5.1, un avertissement sur la sortie d'erreur
# suffit à faire échouer un script en mode Stop) ; renvoie $true s'il a réussi.
function MysqlMuet([string]$outil, [string]$arguments) {
    & cmd.exe /c "`"$mysqlBin\$outil`" $arguments >nul 2>nul"
    $LASTEXITCODE -eq 0
}

function MysqlPret {
    MysqlMuet 'mysqladmin.exe' "`"--defaults-extra-file=$identifiants`" --connect-timeout=2 ping"
}

# Démarre MySQL s'il ne tourne pas (service MySQL84, ou mysqld portable sans fenêtre).
function DemarrerMysql {
    if (-not $portable) {
        $service = Get-Service MySQL84
        if ($service.Status -ne 'Running') { Start-Service MySQL84 }
        return
    }
    if (MysqlPret) { return }
    Start-Process "$mysqlBin\mysqld.exe" -ArgumentList "--defaults-file=`"$racine\mysql\my.ini`"" -WindowStyle Hidden
    $limite = (Get-Date).AddMinutes(2)
    while (-not (MysqlPret)) {
        if ((Get-Date) -gt $limite) { throw "MySQL ne démarre pas. Voir $racine\mysql\data\*.err" }
        Start-Sleep -Seconds 1
    }
}

# Arrête le MySQL portable (le service de l'installation de développement reste en marche).
function ArreterMysql {
    if (-not $portable -or -not (MysqlPret)) { return }
    [void](MysqlMuet 'mysqladmin.exe' "`"--defaults-extra-file=$identifiants`" shutdown")
}

# Fenêtre propriétaire au premier plan, pour que les boîtes de dialogue Windows passent devant le jeu.
function Proprietaire {
    Add-Type -AssemblyName System.Windows.Forms
    $f = New-Object System.Windows.Forms.Form
    $f.TopMost = $true
    $f.ShowInTaskbar = $false
    $f.StartPosition = 'CenterScreen'
    $f.Size = New-Object System.Drawing.Size(1, 1)
    $f.Opacity = 0
    $f.Show()
    $f.Activate()
    $f
}
