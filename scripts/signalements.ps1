# Signalements de bugs (touche « ! » en jeu, table acore_characters.solazeroth_v3_signalements)
#   -Nombre    : affiche le nombre de signalements pas encore exportés
#   -Exporter  : demande où enregistrer (fenêtre Windows « Enregistrer sous »), écrit un fichier .txt lisible, puis
#                supprime de la base les signalements exportés. Sur l'installation de développement, ils restent et
#                sont seulement marqués exporte = 1, pour garder la liste de travail (colonne traite).
#   -Fichier <chemin> : avec -Exporter, écrit là sans poser de question (essais)
# Appelé par le lanceur pendant la partie (bouton Exporter de la fenêtre de signalement) et par le menu.
param([switch]$Nombre, [switch]$Exporter, [string]$Fichier)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\commun.ps1"

$resultat = "$runtime\signalements_resultat.txt"
$classes = @{ 1 = 'Guerrier'; 2 = 'Paladin'; 3 = 'Chasseur'; 4 = 'Voleur'; 5 = 'Prêtre'; 6 = 'Chevalier de la mort'
              7 = 'Chaman'; 8 = 'Mage'; 9 = 'Démoniste'; 11 = 'Druide' }

# Compte rendu relayé en jeu par v3_signalement.cpp (UTF-8 sans BOM).
function CompteRendu([string]$message) {
    New-Item -ItemType Directory -Force $runtime | Out-Null
    [IO.File]::WriteAllText($resultat, $message, (New-Object System.Text.UTF8Encoding $false))
    Write-Output $message
}

DemarrerMysql
$attente = [int](Sql 'SELECT COUNT(*) FROM acore_characters.solazeroth_v3_signalements WHERE exporte = 0')
if ($Nombre) { Write-Output $attente; return }
if (-not $Exporter) { throw 'Préciser -Nombre ou -Exporter' }
if ($attente -eq 0) { CompteRendu 'aucun signalement à exporter.'; return }

# mysql -B échappe tabulations, retours à la ligne et antislashs : on les rétablit champ par champ.
function Champ([string]$texte) { $texte -replace '\\t', ' ' -replace '\\n', ' / ' -replace '\\\\', '\' }

$lignes = @(Sql ('SELECT id, DATE_FORMAT(quand, ''%d/%m/%Y %H:%i''), personnage, classe, carte, zone, lieu, nom_lieu, ' +
    'ROUND(x, 1), ROUND(y, 1), ROUND(z, 1), cible, texte FROM acore_characters.solazeroth_v3_signalements ' +
    'WHERE exporte = 0 ORDER BY id'))
$ids = @()
$texte = New-Object System.Text.StringBuilder
[void]$texte.AppendLine("Signalements Sol'Azeroth")
[void]$texte.AppendLine("Version du jeu : $(Version)")
[void]$texte.AppendLine("Exporté le : $(Get-Date -Format 'dd/MM/yyyy HH:mm')")
[void]$texte.AppendLine("Nombre : $($lignes.Count)")
foreach ($ligne in $lignes) {
    $c = $ligne -split "`t"
    $ids += [int]$c[0]
    $classe = $classes[[int]$c[3]]
    [void]$texte.AppendLine('')
    [void]$texte.AppendLine("=== Signalement $($c[0]) — $($c[1]) ===")
    [void]$texte.AppendLine("Personnage : $(Champ $c[2])$(if ($classe) { " ($classe)" })")
    [void]$texte.AppendLine("Lieu : $(if ($c[7]) { Champ $c[7] } else { '?' }) (carte $($c[4]), zone $($c[5]), lieu $($c[6]))")
    [void]$texte.AppendLine("Position : $($c[8]) $($c[9]) $($c[10])")
    if ($c[11]) { [void]$texte.AppendLine("Cible : $(Champ $c[11])") }
    [void]$texte.AppendLine("Description : $(Champ $c[12])")
}

if (-not $Fichier) {
    $proprio = Proprietaire
    try {
        $dialogue = New-Object System.Windows.Forms.SaveFileDialog
        $dialogue.Title = "Où enregistrer tes signalements Sol'Azeroth ?"
        $dialogue.Filter = 'Fichier texte (*.txt)|*.txt'
        $dialogue.InitialDirectory = [Environment]::GetFolderPath('Desktop')
        $dialogue.FileName = "Signalements Sol'Azeroth $(Get-Date -Format 'yyyy-MM-dd HH-mm').txt"
        $choix = $dialogue.ShowDialog($proprio)
    } finally { $proprio.Close() }
    if ($choix -ne [System.Windows.Forms.DialogResult]::OK) {
        CompteRendu "export annulé : les $attente signalement(s) restent dans le jeu."
        return
    }
    $Fichier = $dialogue.FileName
}

[IO.File]::WriteAllText($Fichier, $texte.ToString().Replace("`r`n", "`n").Replace("`n", "`r`n"),
    (New-Object System.Text.UTF8Encoding $true))
$liste = $ids -join ','
if ($portable) { Sql "DELETE FROM acore_characters.solazeroth_v3_signalements WHERE id IN ($liste)" | Out-Null }
else { Sql "UPDATE acore_characters.solazeroth_v3_signalements SET exporte = 1 WHERE id IN ($liste)" | Out-Null }
CompteRendu "$($ids.Count) signalement(s) exporté(s) dans « $([IO.Path]::GetFileName($Fichier)) ». Envoie ce fichier au développeur, merci !"
