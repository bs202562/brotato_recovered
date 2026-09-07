$ErrorActionPreference = 'Stop'
$foundationRoot = Split-Path -Parent $PSScriptRoot
$foundationProject = Join-Path $foundationRoot 'gdproj'
$foundationManifest = Get-Content (Join-Path $foundationProject 'combat3d/models.json') -Raw | ConvertFrom-Json -AsHashtable
$foundationCases = @(
    @{ Key = 'character_doctor'; Name = 'doctor'; Args = '--combat3d-character=doctor --combat3d-wave=1'; Wave = 1 },
    @{ Key = 'enemy:baby_alien'; Name = 'shopper'; Args = '--combat3d-wave=1'; Wave = 1 },
    @{ Key = 'enemy:spitter'; Name = 'janitor'; Args = '--combat3d-wave=4'; Wave = 4 },
    @{ Key = 'enemy:colossus'; Name = 'riot'; Args = '--combat3d-wave=12 --combat3d-difficulty=2 --combat3d-elite=colossus'; Wave = 12 },
    @{ Key = 'enemy:mom'; Name = 'chef'; Args = '--combat3d-wave=12 --combat3d-difficulty=2 --combat3d-elite=mom'; Wave = 12 }
)
foreach ($foundationCase in $foundationCases) {
    $foundationEntry = $foundationManifest[$foundationCase.Key]
    $foundationStem = Join-Path $foundationRoot ('docs/foundation-' + $foundationCase.Name)
    $foundationArgs = '--path "' + $foundationProject + '" --no-window res://combat3d/smoke_test.tscn ' + $foundationCase.Args + ' --combat3d-require-art=' + $foundationEntry.art_identity + ' --combat3d-require-model=' + $foundationEntry.path
    $foundationProcess = Start-Process -FilePath 'D:/tools/Godot_v3.6.3-stable_win64/Godot_v3.6.3-stable_win64.exe' -ArgumentList $foundationArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput ($foundationStem + '.log') -RedirectStandardError ($foundationStem + '.err')
    if (-not $foundationProcess.WaitForExit(45000)) { Stop-Process -Id $foundationProcess.Id; throw ('Timed out: ' + $foundationCase.Name) }
    $foundationOutput = Get-Content ($foundationStem + '.log') -Raw
    $foundationErrors = Get-Content ($foundationStem + '.err') -Raw
    if ($foundationProcess.ExitCode -ne 0 -or $foundationOutput -notmatch 'COMBAT3D_TEST_COMPLETE' -or $foundationOutput -notmatch 'COMBAT3D_MODEL_VERIFIED' -or $foundationOutput -notmatch 'COMBAT3D_ART_IDENTITY_VERIFIED' -or $foundationErrors -match 'SCRIPT ERROR|Parse Error|Assertion failed') { throw ('Failed: ' + $foundationCase.Name) }
    Copy-Item -LiteralPath (Join-Path $foundationRoot ('docs/combat3d-wave-' + $foundationCase.Wave + '.png')) -Destination ($foundationStem + '.png')
    Write-Output ('PASS ' + $foundationCase.Key)
}
