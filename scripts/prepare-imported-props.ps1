param(
    [Parameter(Mandatory)][string[]]$PropIds,
    [string]$GodotPath = 'D:/tools/Godot_v3.6.3-stable_win64/Godot_v3.6.3-stable_win64.exe'
)
# Share the source-MD5 import gate and renderer runner with the weapon pipeline.
& (Join-Path $PSScriptRoot 'prepare-imported-weapons.ps1') -PropIds $PropIds -GodotPath $GodotPath
