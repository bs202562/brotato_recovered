param(
    [Parameter(Mandatory)][string[]]$CharacterIds,
    [string]$GodotPath = 'D:/tools/Godot_v3.6.3-stable_win64/Godot_v3.6.3-stable_win64.exe'
)
$ErrorActionPreference = 'Stop'
$reviewRoot = Split-Path -Parent $PSScriptRoot
$reviewProject = Join-Path $reviewRoot 'gdproj'
$reviewDocs = Join-Path $reviewRoot 'docs'
$reviewManifest = Get-Content (Join-Path $reviewProject 'combat3d/models.json') -Raw | ConvertFrom-Json -AsHashtable
$reviewQueue = Get-Content (Join-Path $reviewDocs 'model-production-queue.json') -Raw | ConvertFrom-Json
foreach ($reviewCharacter in $CharacterIds) {
    if ($reviewCharacter -notmatch '^character_[a-z0-9_]+$') { throw "Invalid character: $reviewCharacter" }
    $reviewEntry = $reviewManifest[$reviewCharacter]
    $reviewSource = @($reviewQueue.models | Where-Object id -eq $reviewCharacter)[0].source
    if (-not $reviewEntry.path -or -not $reviewSource) { throw "Missing character configuration: $reviewCharacter" }
    $reviewStem = Join-Path $reviewDocs ($reviewCharacter + '-model-battle')
    $reviewArgs = '--path "' + $reviewProject + '" --no-window res://combat3d/smoke_test.tscn --combat3d-character-resource=' + $reviewSource + ' --combat3d-require-art=' + $reviewCharacter + ' --combat3d-require-model=' + $reviewEntry.path
    $reviewProcess = Start-Process -FilePath $GodotPath -ArgumentList $reviewArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput ($reviewStem+'.log') -RedirectStandardError ($reviewStem+'.err')
    if (-not $reviewProcess.WaitForExit(45000)) { Stop-Process -Id $reviewProcess.Id; throw "Character review timed out: $reviewCharacter" }
    $reviewOutput = Get-Content ($reviewStem+'.log') -Raw
    $reviewErrors = Get-Content ($reviewStem+'.err') -Raw
    if ($reviewProcess.ExitCode -ne 0 -or $reviewOutput -notmatch 'COMBAT3D_TEST_COMPLETE' -or $reviewOutput -notmatch ('COMBAT3D_CHARACTER_ANIMATION_VERIFIED: ' + $reviewCharacter) -or $reviewErrors -match 'SCRIPT ERROR|Parse Error|Assertion failed') { throw "Character review failed: $reviewStem" }
    Copy-Item -LiteralPath (Join-Path $reviewDocs 'combat3d-wave-1.png') -Destination ($reviewStem+'.png')
    Copy-Item -LiteralPath (Join-Path $reviewDocs 'combat3d-wave-1-hud.png') -Destination ($reviewStem+'-hud.png')
    Write-Output "PASS $reviewCharacter model, configured animation and actual battle"
}
