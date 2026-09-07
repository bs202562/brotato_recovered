param(
    [Parameter(Mandatory)][string[]]$EnemyIds,
    [string]$GodotPath = 'D:/tools/Godot_v3.6.3-stable_win64/Godot_v3.6.3-stable_win64.exe'
)
$ErrorActionPreference = 'Stop'
$reviewRoot = Split-Path -Parent $PSScriptRoot
$reviewProject = Join-Path $reviewRoot 'gdproj'
$reviewDocs = Join-Path $reviewRoot 'docs'
$reviewManifest = Get-Content (Join-Path $reviewProject 'combat3d/models.json') -Raw | ConvertFrom-Json -AsHashtable
foreach ($reviewEnemy in $EnemyIds) {
    if ($reviewEnemy -notmatch '^enemy:[a-z0-9_]+$') { throw "Invalid enemy: $reviewEnemy" }
    $reviewEntry = $reviewManifest[$reviewEnemy]
    $reviewName = $reviewEnemy.Substring(6)
    $reviewScenes = @(Get-ChildItem -LiteralPath (Join-Path $reviewProject 'entities/units/enemies'), (Join-Path $reviewProject 'dlcs') -Filter ($reviewName+'.tscn') -File -Recurse | Where-Object { (Get-Content -LiteralPath $_.FullName -Raw) -match ('enemy_id = "'+[regex]::Escape($reviewName)+'"') })
    if ($reviewScenes.Count -ne 1) { throw "Expected one actual enemy scene for $reviewEnemy; found $($reviewScenes.Count)" }
    $reviewSource = 'res://' + [IO.Path]::GetRelativePath($reviewProject, $reviewScenes[0].FullName).Replace('\','/')
    if (-not $reviewEntry.path -or -not $reviewSource) { throw "Missing enemy configuration: $reviewEnemy" }
    $reviewStem = Join-Path $reviewDocs ('enemy_' + $reviewName + '-model-battle')
    $reviewArgs = '--path "' + $reviewProject + '" --no-window res://combat3d/smoke_test.tscn --combat3d-capture-on-art --combat3d-review-enemy=' + $reviewSource + ' --combat3d-require-art=' + $reviewEntry.art_identity + ' --combat3d-require-model=' + $reviewEntry.path
    $reviewProcess = Start-Process -FilePath $GodotPath -ArgumentList $reviewArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput ($reviewStem+'.log') -RedirectStandardError ($reviewStem+'.err')
    if (-not $reviewProcess.WaitForExit(45000)) { Stop-Process -Id $reviewProcess.Id; throw "Enemy review timed out: $reviewEnemy" }
    $reviewOutput = Get-Content ($reviewStem+'.log') -Raw
    $reviewErrors = Get-Content ($reviewStem+'.err') -Raw
    if ($reviewProcess.ExitCode -ne 0 -or $reviewOutput -notmatch 'COMBAT3D_TEST_COMPLETE' -or $reviewOutput -notmatch ('COMBAT3D_ENEMY_ANIMATION_VERIFIED: ' + $reviewEnemy) -or $reviewErrors -match 'SCRIPT ERROR|Parse Error|Assertion failed') { throw "Enemy review failed: $reviewStem" }
    Copy-Item -LiteralPath (Join-Path $reviewDocs 'combat3d-wave-1.png') -Destination ($reviewStem+'.png')
    Copy-Item -LiteralPath (Join-Path $reviewDocs 'combat3d-wave-1-hud.png') -Destination ($reviewStem+'-hud.png')
    Write-Output "PASS $reviewEnemy model, configured animation and actual battle"
}
