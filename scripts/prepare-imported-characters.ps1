param(
    [Parameter(Mandatory)][string[]]$CharacterIds,
    [string]$GodotPath = 'D:/tools/Godot_v3.6.3-stable_win64/Godot_v3.6.3-stable_win64.exe'
)
& (Join-Path $PSScriptRoot 'prepare-imported-weapons.ps1') -CharacterIds $CharacterIds -GodotPath $GodotPath
