param(
    [Parameter(Mandatory, ParameterSetName='Weapons')][string[]]$WeaponIds,
    [Parameter(Mandatory, ParameterSetName='Props')][string[]]$PropIds,
    [Parameter(Mandatory, ParameterSetName='Characters')][string[]]$CharacterIds,
    [Parameter(Mandatory, ParameterSetName='Enemies')][string[]]$EnemyIds,
    [string]$GodotPath = 'D:/tools/Godot_v3.6.3-stable_win64/Godot_v3.6.3-stable_win64.exe'
)
$ErrorActionPreference = 'Stop'
$prepareRoot = Split-Path -Parent $PSScriptRoot
$prepareProject = Join-Path $prepareRoot 'gdproj'
$prepareManifest = Get-Content (Join-Path $prepareProject 'combat3d/models.json') -Raw | ConvertFrom-Json -AsHashtable
$prepareProps = $PSCmdlet.ParameterSetName -eq 'Props'
$prepareCharacters = $PSCmdlet.ParameterSetName -eq 'Characters'
$prepareEnemies = $PSCmdlet.ParameterSetName -eq 'Enemies'
$preparePrefixLength = if ($prepareProps) { 5 } elseif ($prepareCharacters) { 10 } elseif ($prepareEnemies) { 6 } else { 7 }
$prepareIds = if ($prepareProps) { @($PropIds | ForEach-Object { if ($_ -notmatch '^[a-z0-9_]+$') { throw "Invalid prop key: $_" }; 'prop:' + $_ } | Select-Object -Unique) } elseif ($prepareCharacters) { @($CharacterIds | ForEach-Object { if ($_ -notmatch '^[a-z0-9_]+$') { throw "Invalid character key: $_" }; 'character_' + $_ } | Select-Object -Unique) } elseif ($prepareEnemies) { @($EnemyIds | ForEach-Object { if ($_ -notmatch '^[a-z0-9_]+$') { throw "Invalid enemy key: $_" }; 'enemy:' + $_ } | Select-Object -Unique) } else { @($WeaponIds | Select-Object -Unique) }
foreach ($prepareId in $prepareIds) {
    if ($prepareId -notmatch $(if ($prepareProps) { '^prop:[a-z0-9_]+$' } elseif ($prepareCharacters) { '^character_[a-z0-9_]+$' } elseif ($prepareEnemies) { '^enemy:[a-z0-9_]+$' } else { '^weapon_[a-z0-9_]+$' }) -or -not $prepareManifest[$prepareId].path) { throw "Missing imported model: $prepareId" }
}
$prepareStem = Join-Path $prepareRoot ('docs/prepare-' + (($prepareIds -join '-') -replace ':', '-'))

function Test-CurrentImport($SourcePath, $ExpectedHash) {
    $remapPath = $SourcePath + '.import'
    if (-not (Test-Path -LiteralPath $remapPath)) { return $false }
    $remapText = Get-Content -LiteralPath $remapPath -Raw
    $remapMatch = [regex]::Match($remapText, '(?m)^path="res://([^"]+)"')
    if (-not $remapMatch.Success) { return $false }
    $importedPath = Join-Path $prepareProject $remapMatch.Groups[1].Value
    $digestPath = [IO.Path]::ChangeExtension($importedPath, 'md5')
    if (-not (Test-Path -LiteralPath $importedPath) -or -not (Test-Path -LiteralPath $digestPath)) { return $false }
    $digestText = Get-Content -LiteralPath $digestPath -Raw
    return $digestText -match ('source_md5="' + $ExpectedHash + '"')
}

function Ensure-CurrentImports([string[]]$Sources, [string]$LogStem) {
    $expected = @{}
    foreach ($source in $Sources) { $expected[$source] = (Get-FileHash -LiteralPath $source -Algorithm MD5).Hash.ToLowerInvariant() }
    $pending = @($Sources | Where-Object { -not (Test-CurrentImport $_ $expected[$_]) })
    if ($pending.Count -eq 0) { return }
    $importProcess = Start-Process -FilePath $GodotPath -ArgumentList ('--path "' + $prepareProject + '" --editor') -WindowStyle Hidden -PassThru -RedirectStandardOutput ($LogStem + '.log') -RedirectStandardError ($LogStem + '.err')
    try {
        $timer = [Diagnostics.Stopwatch]::StartNew()
        while ($pending.Count -gt 0) {
            if ($importProcess.HasExited) { throw "Editor exited before imports completed: $LogStem" }
            if ($timer.Elapsed.TotalSeconds -gt 60) { throw ('Import timed out: ' + ($pending -join ', ')) }
            Start-Sleep -Milliseconds 500
            $pending = @($Sources | Where-Object { -not (Test-CurrentImport $_ $expected[$_]) })
        }
    } finally {
        if (-not $importProcess.HasExited) { Stop-Process -Id $importProcess.Id }
    }
}

$modelSources = @($prepareIds | ForEach-Object { Join-Path $prepareProject $prepareManifest[$_].path.Substring(6) })
Ensure-CurrentImports $modelSources ($prepareStem + '-import')
$iconKeys = ($prepareIds | ForEach-Object { $_.Substring($preparePrefixLength) }) -join ','
$iconRenderer = if ($prepareProps) { 'res://combat3d/render_character_icons.tscn --prop-icons=' } elseif ($prepareCharacters) { 'res://combat3d/render_character_icons.tscn --character-icons=' } elseif ($prepareEnemies) { 'res://combat3d/render_character_icons.tscn --enemy-icons=' } else { 'res://combat3d/render_weapon_icons.tscn --weapon-icons=' }
$iconArgs = '--path "' + $prepareProject + '" --no-window ' + $iconRenderer + $iconKeys
$iconProcess = Start-Process -FilePath $GodotPath -ArgumentList $iconArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput ($prepareStem + '-icons.log') -RedirectStandardError ($prepareStem + '-icons.err')
if (-not $iconProcess.WaitForExit(45000)) { Stop-Process -Id $iconProcess.Id; throw 'Model icon rendering timed out' }
$iconLog = Get-Content ($prepareStem + '-icons.log') -Raw
$iconErrors = Get-Content ($prepareStem + '-icons.err') -Raw
$expectedCompletion = if ($prepareProps) { 'COMBAT3D_PROP_ICONS_COMPLETE: ' + $prepareIds.Count } elseif ($prepareCharacters) { 'COMBAT3D_CHARACTER_ICONS_COMPLETE: ' + $prepareIds.Count } elseif ($prepareEnemies) { 'COMBAT3D_ENEMY_ICONS_COMPLETE: ' + $prepareIds.Count } else { 'COMBAT3D_WEAPON_ICONS_COMPLETE: ' + ($prepareIds.Count * 4) }
$completionPattern = '(?m)^' + [regex]::Escape($expectedCompletion) + '\r?$'
if ($iconProcess.ExitCode -ne 0 -or $iconLog -notmatch $completionPattern -or $iconErrors -match 'SCRIPT ERROR|Parse Error|Assertion failed') { throw "Model icon rendering failed: $prepareStem" }
$iconSources = if ($prepareProps) { @($prepareIds | ForEach-Object { Join-Path $prepareProject ('combat3d/art/props/' + $_.Substring(5) + '.png') }) } elseif ($prepareCharacters) { @($prepareIds | ForEach-Object { Join-Path $prepareProject ('combat3d/art/characters/' + $_ + '.png') }) } elseif ($prepareEnemies) { @($prepareIds | ForEach-Object { Join-Path $prepareProject ('combat3d/art/enemies/' + $_.Substring(6) + '.png') }) } else { @($prepareIds | ForEach-Object { $iconId = $_; 0..3 | ForEach-Object { Join-Path $prepareProject ('combat3d/art/weapons/' + $iconId + '_' + $_ + '.png') } }) }
Ensure-CurrentImports $iconSources ($prepareStem + '-refresh')
Write-Output ('PREPARED ' + ($prepareIds -join ', ') + ': source hashes match imports; icons rendered and refreshed. Visual and battle review still required.')
