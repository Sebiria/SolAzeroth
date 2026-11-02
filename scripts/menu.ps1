# Menu du lanceur Sol'Azeroth (version publique, 02/11/2026), ouvert par « Sol'Azeroth.bat » :
# Jouer, mise à jour (.solmaj), export des signalements, restauration, dossier du client.
# Au premier lancement de l'archive des joueurs, il fait l'installation (installer.ps1).
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\commun.ps1"
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

function Message([string]$texte, [string]$icone = 'Information') {
    [void][System.Windows.Forms.MessageBox]::Show($texte, "Sol'Azeroth", 'OK', $icone)
}

# Lance un script en montrant ses messages dans la console ; renvoie $true s'il a réussi.
function Executer([scriptblock]$action, [string]$titre) {
    $script:fenetre.Hide()
    try { & $action | ForEach-Object { Write-Host $_ }; return $true }
    catch { Message "$titre : $_" 'Error'; return $false }
    finally { $script:fenetre.Show(); $script:fenetre.Activate(); MajSignalements }
}

if ($portable -and -not (Test-Path "$racine\config\installe.txt")) {
    Message ("Bienvenue dans Sol'Azeroth !`n`nPremière installation : choisis le dossier de ton client World of Warcraft " +
        "3.3.5a en français (celui qui contient Wow.exe). La préparation de la base prend ensuite quelques minutes.")
    try { & "$PSScriptRoot\installer.ps1" | ForEach-Object { Write-Host $_ } }
    catch { Message "L'installation n'a pas abouti : $_" 'Error'; ArreterMysql; exit 1 }
}

$fenetre = New-Object System.Windows.Forms.Form
$fenetre.Text = "Sol'Azeroth $(Version)"
$fenetre.StartPosition = 'CenterScreen'
$fenetre.FormBorderStyle = 'FixedSingle'
$fenetre.MaximizeBox = $false
$fenetre.ClientSize = New-Object System.Drawing.Size(360, 420)
$fenetre.BackColor = [System.Drawing.Color]::FromArgb(32, 33, 36)
$fenetre.ForeColor = [System.Drawing.Color]::FromArgb(230, 228, 222)
$fenetre.Font = New-Object System.Drawing.Font('Segoe UI', 10)

$titre = New-Object System.Windows.Forms.Label
$titre.Text = "Sol'Azeroth"
$titre.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 20)
$titre.SetBounds(24, 18, 312, 40)
$fenetre.Controls.Add($titre)
$sousTitre = New-Object System.Windows.Forms.Label
$sousTitre.Text = "Version $(Version) · solo, hors ligne"
$sousTitre.ForeColor = [System.Drawing.Color]::FromArgb(150, 150, 150)
$sousTitre.SetBounds(26, 58, 312, 22)
$fenetre.Controls.Add($sousTitre)

$y = 96
function Bouton([string]$texte, [scriptblock]$clic, [int]$hauteur = 40) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $texte
    $b.FlatStyle = 'Flat'
    $b.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(90, 90, 90)
    $b.BackColor = [System.Drawing.Color]::FromArgb(48, 49, 53)
    $b.SetBounds(24, $script:y, 312, $hauteur)
    $b.Add_Click($clic)
    $fenetre.Controls.Add($b)
    $script:y += $hauteur + 10
    $b
}

$jouer = Bouton 'Jouer' { [void](Executer { & "$PSScriptRoot\lanceur.ps1" -GarderMysql } 'Le jeu ne s''est pas lancé') } 56
$jouer.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 13)
$jouer.BackColor = [System.Drawing.Color]::FromArgb(150, 105, 40)

$signalements = Bouton 'Exporter les signalements' {
    [void](Executer { & "$PSScriptRoot\signalements.ps1" -Exporter } 'Export impossible')
}

[void](Bouton 'Appliquer une mise à jour…' {
    $dialogue = New-Object System.Windows.Forms.OpenFileDialog
    $dialogue.Title = 'Choisis le fichier de mise à jour'
    $dialogue.Filter = "Mise à jour Sol'Azeroth (*.solmaj)|*.solmaj"
    if ($dialogue.ShowDialog($fenetre) -ne 'OK') { return }
    $nom = $dialogue.FileName
    if (Executer { & "$PSScriptRoot\mise_a_jour.ps1" -Fichier $nom } 'La mise à jour a échoué') {
        Message "Mise à jour installée : version $(Version)."
        $fenetre.Text = "Sol'Azeroth $(Version)"
        $sousTitre.Text = "Version $(Version) · solo, hors ligne"
    }
})

[void](Bouton 'Restaurer la dernière sauvegarde' {
    $ok = [System.Windows.Forms.MessageBox]::Show(("Remettre les personnages et le compte à la dernière sauvegarde ?`n" +
        "L'état actuel est d'abord gardé dans une sauvegarde « avant-restauration »."), "Sol'Azeroth", 'YesNo', 'Question')
    if ($ok -eq 'Yes' -and (Executer { & "$PSScriptRoot\restaurer.ps1" } 'Restauration impossible')) { Message 'Sauvegarde restaurée.' }
})

[void](Bouton 'Dossier du client WoW…' {
    $dialogue = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialogue.Description = 'Dossier de ton client World of Warcraft 3.3.5a (celui qui contient Wow.exe).'
    if ($dialogue.ShowDialog($fenetre) -ne 'OK') { return }
    if (-not (Test-Path "$($dialogue.SelectedPath)\Wow.exe")) { Message 'Wow.exe est introuvable dans ce dossier.' 'Warning'; return }
    [IO.File]::WriteAllText("$racine\config\client.txt", $dialogue.SelectedPath, (New-Object System.Text.UTF8Encoding $false))
    Message "Client enregistré : $($dialogue.SelectedPath)"
})

[void](Bouton 'Ouvrir le dossier du jeu' { Start-Process explorer.exe $racine })

function MajSignalements {
    try { $n = [int](& "$PSScriptRoot\signalements.ps1" -Nombre) } catch { $n = 0 }
    $signalements.Text = if ($n) { "Exporter les signalements ($n)" } else { 'Exporter les signalements' }
    $signalements.Enabled = $n -gt 0
}

$fenetre.Add_Shown({ MajSignalements })
[void]$fenetre.ShowDialog()
ArreterMysql
