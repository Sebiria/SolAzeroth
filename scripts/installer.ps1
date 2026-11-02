# Première installation de l'archive des joueurs (version publique, 02/11/2026), lancée par le menu :
#   1. dossier du client WoW 3.3.5a frFR (fenêtre de choix, ou -Client <dossier>) ;
#   2. MySQL portable : base vide, utilisateur acore au mot de passe tiré au hasard (config\mysql-acore.cnf) ;
#   3. import de la base de départ (dossier base\ : monde à jour, aucun personnage, aucun compte) ;
#   4. réglages du serveur (configurer.ps1).
# Le compte de jeu local est créé par le lanceur au premier lancement (il faut le serveur pour cela).
param([string]$Client)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\commun.ps1"
if (-not $portable) { throw "Installation de développement : il n'y a rien à installer." }

# Vérifie un dossier de client ; renvoie le message d'erreur, ou rien s'il convient.
function ProblemeClient([string]$dossier) {
    if (-not $dossier -or -not (Test-Path "$dossier\Wow.exe")) { return "Wow.exe est introuvable dans ce dossier." }
    $version = (Get-Item "$dossier\Wow.exe").VersionInfo
    if ("$($version.FileVersion) $($version.ProductVersion)" -notmatch '12340') {
        return "Ce Wow.exe n'est pas la version 3.3.5a (12340) : $($version.FileVersion)."
    }
    if (-not (Test-Path "$dossier\Data\frFR")) {
        return "Ce client n'est pas en français (pas de dossier Data\frFR). Sol'Azeroth demande pour l'instant un client 3.3.5a frFR."
    }
}

function ChoisirClient {
    $proprio = Proprietaire
    try {
        while ($true) {
            $dialogue = New-Object System.Windows.Forms.FolderBrowserDialog
            $dialogue.Description = "Choisis le dossier de ton client World of Warcraft 3.3.5a (celui qui contient Wow.exe)."
            $dialogue.ShowNewFolderButton = $false
            if ($dialogue.ShowDialog($proprio) -ne [System.Windows.Forms.DialogResult]::OK) { throw 'Installation annulée.' }
            $probleme = ProblemeClient $dialogue.SelectedPath
            if (-not $probleme) { return $dialogue.SelectedPath }
            [void][System.Windows.Forms.MessageBox]::Show($proprio, $probleme, "Sol'Azeroth", 'OK', 'Warning')
        }
    } finally { $proprio.Close() }
}

function MotAuHasard {
    -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 24 | ForEach-Object { [char]$_ })
}

New-Item -ItemType Directory -Force $runtime, $logs, "$racine\config", "$racine\backups" | Out-Null

# 1. Client
if (-not $Client) { $Client = ChoisirClient }
$probleme = ProblemeClient $Client
if ($probleme) { throw $probleme }
[IO.File]::WriteAllText("$racine\config\client.txt", $Client, (New-Object System.Text.UTF8Encoding $false))
Write-Output "Client WoW : $Client"

# 2. MySQL portable
$donnees = "$racine\mysql\data"
if (-not (Test-Path "$donnees\mysql")) {
    if (Get-Process mysqld -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "$racine\*" }) {
        throw "Le MySQL de Sol'Azeroth tourne déjà alors que sa base n'existe pas : redémarre l'ordinateur, puis relance."
    }
    Remove-Item $donnees -Recurse -Force -ErrorAction SilentlyContinue
    $m = ($racine -replace '\\', '/') + '/mysql'
    @('[mysqld]', "basedir=`"$m`"", "datadir=`"$m/data`"", "port=$portMysql", 'bind-address=127.0.0.1', 'mysqlx=OFF',
      'character-set-server=utf8mb4', 'max_allowed_packet=64M', 'innodb_buffer_pool_size=256M') |
        Set-Content "$racine\mysql\my.ini" -Encoding ASCII
    Write-Output 'Préparation de MySQL...'
    $ok = MysqlMuet 'mysqld.exe' "`"--defaults-file=$racine\mysql\my.ini`" --initialize-insecure"
    if (-not $ok -or -not (Test-Path "$donnees\mysql")) { throw "MySQL n'a pas pu créer sa base (voir $donnees\*.err)." }

    # Utilisateur acore au mot de passe tiré au hasard ; root reçoit aussi un mot de passe au hasard, jamais noté.
    $mdp = MotAuHasard
    @('[client]', 'user=acore', "password=$mdp", 'host=127.0.0.1', "port=$portMysql") |
        Set-Content $identifiants -Encoding ASCII
    Start-Process "$mysqlBin\mysqld.exe" -ArgumentList "--defaults-file=`"$racine\mysql\my.ini`"" -WindowStyle Hidden
    $limite = (Get-Date).AddMinutes(2)
    do {
        if ((Get-Date) -gt $limite) { throw "MySQL ne démarre pas (voir $donnees\*.err)." }
        Start-Sleep -Seconds 1
    } until (MysqlMuet 'mysqladmin.exe' "-u root --skip-password --host=127.0.0.1 --port=$portMysql ping")
    $requete = "CREATE USER 'acore'@'localhost' IDENTIFIED BY '$mdp'; CREATE USER 'acore'@'127.0.0.1' IDENTIFIED BY '$mdp'; " +
        "GRANT ALL PRIVILEGES ON *.* TO 'acore'@'localhost' WITH GRANT OPTION; " +
        "GRANT ALL PRIVILEGES ON *.* TO 'acore'@'127.0.0.1' WITH GRANT OPTION; " +
        "ALTER USER 'root'@'localhost' IDENTIFIED BY '$(MotAuHasard)'; FLUSH PRIVILEGES;"
    if (-not (MysqlMuet 'mysql.exe' "-u root --skip-password --host=127.0.0.1 --port=$portMysql -e `"$requete`"")) {
        throw 'Impossible de créer l''utilisateur de la base.'
    }
}
DemarrerMysql

# 3. Base de départ
if (-not (Sql "SHOW DATABASES LIKE 'acore_world'")) {
    foreach ($base in 'acore_auth', 'acore_characters', 'acore_world') {
        Write-Output "Import de $base (le monde prend quelques minutes)..."
        SqlFichier "$racine\base\$base.sql"
    }
    # Statistiques des tables tout de suite : sans elles, juste après l'import, MySQL choisit pour certaines requêtes
    # de démarrage (passants de l'ambiance, sur waypoint_data) un plan qui dure des dizaines de minutes.
    Write-Output 'Statistiques de la base...'
    foreach ($base in 'acore_auth', 'acore_characters', 'acore_world') {
        $tables = @(Sql "SELECT table_name FROM information_schema.tables WHERE table_schema = '$base' AND table_type = 'BASE TABLE'")
        Sql ('ANALYZE TABLE ' + (($tables | ForEach-Object { "$base.``$_``" }) -join ', ')) | Out-Null
    }
}

# 4. Réglages du serveur
& "$PSScriptRoot\configurer.ps1" | Out-Null
Set-Content "$racine\config\installe.txt" (Get-Date -Format 'yyyy-MM-dd HH:mm') -Encoding ASCII
Write-Output 'Installation terminée.'
