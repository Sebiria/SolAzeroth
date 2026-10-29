# Applique les réglages Sol'Azeroth aux fichiers .conf du serveur (à relancer sans risque, il ne change que ces lignes).
# Un fichier .conf absent est d'abord créé depuis son .conf.dist. Les accès à la base (DatabaseInfo) ne sont pas touchés.
param([string]$Dossier = 'C:\SolAzeroth\build\bin\RelWithDebInfo\configs')
$ErrorActionPreference = 'Stop'

$configs = $Dossier

$reglages = [ordered]@{
    'worldserver.conf' = [ordered]@{
        'BindIP'                          = '"127.0.0.1"'
        'DataDir'                         = '"C:/SolAzeroth/data"'
        'LogsDir'                         = '"C:/SolAzeroth/logs"'
        'Logger.ALE'                      = '4,Console Server'
        'SocketTimeOutTime'               = '86400000'
        'PreventAFKLogout'                = '2'
        'AlwaysMaxSkillForLevel'          = '1'
        'ValidateSkillLearnedBySpells'    = '0'
        'EnablePlayerSettings'            = '1'
        'MaxPrimaryTradeSkill'            = '11'
        'SkillGain.Crafting'              = '2'
        'SkillGain.Gathering'             = '2'
        'Instance.IgnoreRaid'             = '1'
        'AccountInstancesPerHour'         = '1000'
        'Guild.AllowMultipleGuildMaster'  = '1'
        # Calibrage final (29/10/2026) : pas de repos hors auberge ou ville, réparations plus chères
        'Rate.Rest.Offline.InWilderness'  = '0'
        'Rate.RepairCost'                 = '1.5'
    }
    'authserver.conf' = [ordered]@{
        'BindIP'  = '"127.0.0.1"'
        'LogsDir' = '"C:/SolAzeroth/logs"'
    }
    'modules\AutoBalance.conf' = [ordered]@{
        'AutoBalance.StatModifier.Health'              = '2.45'
        'AutoBalance.StatModifier.Mana'                = '8.0'
        'AutoBalance.StatModifier.Damage'              = '2.0'
        'AutoBalance.StatModifier.Boss.Health'         = '4.5'
        'AutoBalance.StatModifier.Boss.Mana'           = '8.0'
        'AutoBalance.StatModifier.Boss.Damage'         = '3.0'
        'AutoBalance.StatModifierHeroic.Health'        = '2.45'
        'AutoBalance.StatModifierHeroic.Mana'          = '8.0'
        'AutoBalance.StatModifierHeroic.Damage'        = '2.0'
        'AutoBalance.StatModifierHeroic.Boss.Health'   = '4.5'
        'AutoBalance.StatModifierHeroic.Boss.Mana'     = '8.0'
        'AutoBalance.StatModifierHeroic.Boss.Damage'   = '3.0'
        'AutoBalance.LevelScaling'                     = '0'
        'AutoBalance.RewardScaling.Method'             = '"fixed"'
        'AutoBalance.RewardScaling.XP.Modifier'        = '2.5'
        # Calibrage final : l'or des instances suit le nombre de places (un raid seul ne donne plus tout son or)
        'AutoBalance.RewardScaling.Money'              = '1'
        'AutoBalance.RewardScaling.Money.Modifier'     = '3.0'
        # Calibrage final : les lanceurs de sorts de raid retrouvent leur mana (PV et dégâts des raids inchangés)
        'AutoBalance.StatModifierRaid.Mana'            = '15.0'
        'AutoBalance.StatModifierRaid.Boss.Mana'       = '15.0'
        'AutoBalance.StatModifierRaidHeroic.Mana'      = '15.0'
        'AutoBalance.StatModifierRaidHeroic.Boss.Mana' = '15.0'

        'AutoBalance.PlayerChangeNotify'               = '0'
    }
    'modules\challenge_modes.conf' = [ordered]@{ 'IronMan.Enable' = '0' }
    # Calibrage final : pas de choix du taux d'XP (.xp set retiré)
    'modules\individual_xp.conf'   = [ordered]@{ 'IndividualXp.Enabled' = 'false' }
    'modules\transmog.conf'        = [ordered]@{ 'Transmogrification.ScaledCostModifier' = '2.0' }
    'modules\mod_ale.conf'         = [ordered]@{ 'ALE.ScriptPath' = '"C:/SolAzeroth/lua_scripts"' }
    'modules\mod_solazeroth.conf'  = [ordered]@{}
}

foreach ($fichier in $reglages.Keys) {
    $chemin = Join-Path $configs $fichier
    if (-not (Test-Path $chemin)) {
        if (-not (Test-Path "$chemin.dist")) { throw "Introuvable : $chemin.dist (le serveur est-il compilé ?)" }
        Copy-Item "$chemin.dist" $chemin
    }
    if ($reglages[$fichier].Count -eq 0) { Write-Output "Créé : $fichier"; continue }
    $lignes = [System.Collections.Generic.List[string]](Get-Content $chemin -Encoding UTF8)
    foreach ($cle in $reglages[$fichier].Keys) {
        $nouvelle = "$cle = $($reglages[$fichier][$cle])"
        $motif = '^' + [regex]::Escape($cle) + '\s*='
        $index = -1
        for ($i = 0; $i -lt $lignes.Count; $i++) { if ($lignes[$i] -match $motif) { $index = $i; break } }
        if ($index -ge 0) { $lignes[$index] = $nouvelle } else { $lignes.Add($nouvelle) }
    }
    [System.IO.File]::WriteAllLines($chemin, $lignes, (New-Object System.Text.UTF8Encoding $false))
    Write-Output "Réglé : $fichier"
}
