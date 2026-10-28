# Lanceur Sol'Azeroth : MySQL -> authserver -> worldserver -> WoW, puis arrêt propre et sauvegarde.
# Pendant le jeu : sauvegarde automatique à l'intervalle choisi (.sauvegarder 5/10/15/30/60)
# et sauvegarde manuelle (.sauvegarder ou bouton du menu Echap).
param([switch]$SansJeu)  # -SansJeu : démarre le serveur sans lancer WoW (tests) ; arrêt en créant runtime\stop.flag
$ErrorActionPreference = 'Stop'

$racine = 'C:\SolAzeroth'
$bin = "$racine\build\bin\RelWithDebInfo"
# Dossier du client WoW 3.3.5a : une ligne dans config\client.txt (propre à chaque machine).
$client = (Get-Content "$racine\config\client.txt" -TotalCount 1 -ErrorAction SilentlyContinue)
if (-not $client -or -not (Test-Path "$client\Wow.exe")) { throw "Indique le dossier du client WoW (celui de Wow.exe) dans $racine\config\client.txt" }
$runtime = "$racine\runtime"
$logs = "$racine\logs"
$consoleLog = "$logs\worldserver-console.log"
$demande = "$runtime\save_request.flag"
$fichierIntervalle = "$runtime\save_interval.txt"

function Info($message) { Write-Host ("[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $message) }

function Sauvegarder($type) {
    Info "Sauvegarde ($type)..."
    if ($script:world -and -not $script:world.HasExited) {
        $script:world.StandardInput.WriteLine('saveall')
        Start-Sleep -Seconds 3
    }
    $resultat = 'OK'
    try { & "$PSScriptRoot\sauvegarde.ps1" -Type $type | ForEach-Object { Info $_ } }
    catch { Info "ERREUR : $_"; $resultat = 'ERREUR' }
    # Le script ALE sauvegarde.lua lit ce fichier et prévient le joueur en jeu.
    if ($type -eq 'manuelle') { Set-Content "$runtime\save_done.txt" $resultat -Encoding ASCII }
}

function Intervalle {
    if (Test-Path $fichierIntervalle) {
        $valeur = 0
        if ([int]::TryParse((Get-Content $fichierIntervalle -TotalCount 1), [ref]$valeur) -and $valeur -gt 0) { return $valeur }
    }
    return 15
}

New-Item -ItemType Directory -Force $runtime, $logs | Out-Null
Remove-Item $demande -ErrorAction SilentlyContinue

if (Get-Process worldserver, authserver -ErrorAction SilentlyContinue) {
    throw "Un serveur tourne déjà. Ferme-le avant de relancer."
}

# 1. MySQL
$service = Get-Service MySQL84
if ($service.Status -ne 'Running') {
    Info 'Démarrage de MySQL...'
    Start-Service MySQL84
}

# Migrations SQL en attente (sauvegarde avant-maj automatique s'il y en a)
& "$PSScriptRoot\migrer.ps1" | ForEach-Object { Info $_ }

# 2. Realmlist et addon dans le client
Set-Content "$client\Data\frFR\realmlist.wtf" 'set realmlist 127.0.0.1' -Encoding ASCII
$configWtf = "$client\WTF\Config.wtf"
if (Test-Path $configWtf) {
    # Réglages imposés à chaque lancement : mode fenêtré agrandi (le plein écran donne un écran noir au changement de fenêtre),
    # curseur matériel et images par seconde plafonnées (sinon l'écran de connexion se fige quand la souris bouge).
    $imposes = [ordered]@{
        realmList  = '127.0.0.1'
        gxWindow   = '1'
        gxMaximize = '1'
        gxCursor   = '1'
        maxFPS     = '120'
        maxFPSBk   = '30'
    }
    $lignes = @(Get-Content $configWtf | Where-Object { $_ -notmatch ('^SET (' + ($imposes.Keys -join '|') + ') ') })
    $lignes += $imposes.Keys | ForEach-Object { "SET $_ `"$($imposes[$_])`"" }
    $lignes | Set-Content $configWtf -Encoding ASCII
}
Copy-Item "$racine\addons\*" "$client\Interface\AddOns\" -Recurse -Force
# Patch client unique (V7) : il contient aussi les fichiers de mod-arac, donc Patch-A.MPQ est rangé dans les archives.
Copy-Item "$racine\patch-client\patch-frFR-4.MPQ" "$client\Data\frFR\" -Force
if (Test-Path "$client\Data\Patch-A.MPQ") { Move-Item "$client\Data\Patch-A.MPQ" "$racine\archives\Patch-A.MPQ" -Force }
# Le client garde une copie des objets, PNJ et quêtes : on la vide pour qu'il reprenne celle du serveur.
Remove-Item "$client\Cache\WDB" -Recurse -Force -ErrorAction SilentlyContinue

# 3. authserver puis worldserver
Info 'Démarrage du serveur de connexion...'
$auth = Start-Process "$bin\authserver.exe" -WorkingDirectory $bin -WindowStyle Minimized -PassThru

Info 'Démarrage du serveur de jeu...'
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = 'cmd.exe'
$psi.Arguments = "/c `"`"$bin\worldserver.exe`" > `"$consoleLog`" 2>&1`""
$psi.WorkingDirectory = $bin
$psi.UseShellExecute = $false
$psi.RedirectStandardInput = $true
$psi.CreateNoWindow = $true
Remove-Item $consoleLog -ErrorAction SilentlyContinue
$script:world = [System.Diagnostics.Process]::Start($psi)
# La première écriture porte un BOM UTF-8 : une ligne vide l'absorbe pour que les vraies commandes passent.
$script:world.StandardInput.WriteLine('')

# 4. Attente du "ready..."
$limite = (Get-Date).AddMinutes(10)
while (-not (Test-Path $consoleLog) -or -not (Select-String -Path $consoleLog -Pattern 'ready\.\.\.' -Quiet)) {
    if ($script:world.HasExited) { throw "Le serveur de jeu s'est arrêté au démarrage. Voir $consoleLog et $logs\Errors.log" }
    if ((Get-Date) -gt $limite) { throw "Le serveur de jeu ne répond pas après 10 minutes. Voir $consoleLog" }
    Start-Sleep -Seconds 2
}
Info 'Serveur prêt.'

# 5. Le jeu
$jeu = $null
if (-not $SansJeu) {
    Info 'Lancement de World of Warcraft...'
    $jeu = Start-Process "$client\Wow.exe" -WorkingDirectory $client -PassThru
}
Info "Sauvegarde automatique toutes les $(Intervalle) minutes. Ne ferme pas cette fenêtre."

$prochaine = (Get-Date).AddMinutes((Intervalle))
$intervalleActuel = Intervalle
while ($true) {
    if ($jeu -and $jeu.HasExited) { Info 'Jeu fermé.'; break }
    if (Test-Path "$runtime\stop.flag") { Remove-Item "$runtime\stop.flag"; Info 'Arrêt demandé.'; break }
    if ($script:world.HasExited) { Info "ATTENTION : le serveur de jeu s'est arrêté. Voir $logs\Errors.log"; break }

    if (Test-Path $demande) {
        Remove-Item $demande -ErrorAction SilentlyContinue
        Sauvegarder 'manuelle'
    }

    $nouvelIntervalle = Intervalle
    if ($nouvelIntervalle -ne $intervalleActuel) {
        $intervalleActuel = $nouvelIntervalle
        $prochaine = (Get-Date).AddMinutes($intervalleActuel)
        Info "Intervalle de sauvegarde : $intervalleActuel minutes."
    }
    if ((Get-Date) -ge $prochaine) {
        Sauvegarder 'auto'
        $prochaine = (Get-Date).AddMinutes($intervalleActuel)
    }
    Start-Sleep -Seconds 2
}

# 6. Arrêt propre puis sauvegarde de fermeture
if (-not $script:world.HasExited) {
    Info 'Arrêt du serveur de jeu (sauvegarde des personnages)...'
    $script:world.StandardInput.WriteLine('server shutdown 1')
    if (-not $script:world.WaitForExit(120000)) {
        Info "Le serveur ne s'arrête pas, arrêt forcé."
        Get-Process worldserver -ErrorAction SilentlyContinue | Stop-Process -Force
    }
}
if (-not $auth.HasExited) { Stop-Process $auth.Id -Force }
$script:world = $null
Sauvegarder 'fermeture'
Info 'Terminé.'
