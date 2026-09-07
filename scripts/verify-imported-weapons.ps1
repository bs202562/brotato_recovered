param(
    [string[]]$WeaponIds = @(),
    [switch]$RequireBurning,
    [ValidateRange(1,20)][int]$Wave = 1,
    [string]$GodotPath = 'D:/tools/Godot_v3.6.3-stable_win64/Godot_v3.6.3-stable_win64.exe'
)
$ErrorActionPreference = 'Stop'
$reviewRoot = Split-Path -Parent $PSScriptRoot
$reviewProject = Join-Path $reviewRoot 'gdproj'
$reviewDocs = Join-Path $reviewRoot 'docs'
$reviewManifest = Get-Content (Join-Path $reviewProject 'combat3d/models.json') -Raw | ConvertFrom-Json -AsHashtable
$reviewQueue = Get-Content (Join-Path $reviewDocs 'model-production-queue.json') -Raw | ConvertFrom-Json
if ($WeaponIds.Count -eq 0) {
    $WeaponIds = @($reviewManifest.Keys | Where-Object { $_ -like 'weapon_*' -and $reviewManifest[$_].path } | Sort-Object)
}
foreach ($reviewWeapon in $WeaponIds) {
    if ($reviewWeapon -notmatch '^weapon_[a-z0-9_]+$') { throw "Invalid weapon identity: $reviewWeapon" }
    $reviewEntry = $reviewManifest[$reviewWeapon]
    $reviewSource = @($reviewQueue.models | Where-Object id -eq $reviewWeapon)[0].source
    if (-not $reviewEntry.path -or -not $reviewSource) { throw "Missing weapon configuration: $reviewWeapon" }
    $reviewStem = Join-Path $reviewDocs ($reviewWeapon + '-placement-battle')
    $reviewArgs = '--path "' + $reviewProject + '" --no-window res://combat3d/smoke_test.tscn --combat3d-wave=' + $Wave + ' --combat3d-require-art=' + $reviewWeapon + ' --combat3d-require-model=' + $reviewEntry.path
    if ($reviewWeapon -ne 'weapon_smg') { $reviewArgs += ' --combat3d-extra-weapon=' + $reviewSource }
    if ($RequireBurning) { $reviewArgs += ' --combat3d-require-burning' }
    $reviewProcess = Start-Process -FilePath $GodotPath -ArgumentList $reviewArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput ($reviewStem + '.log') -RedirectStandardError ($reviewStem + '.err')
    if (-not $reviewProcess.WaitForExit(45000)) {
        Stop-Process -Id $reviewProcess.Id
        throw "Weapon review timed out: $reviewWeapon"
    }
    $reviewOutput = Get-Content ($reviewStem + '.log') -Raw
    $reviewErrors = Get-Content ($reviewStem + '.err') -Raw
    if ($RequireBurning -and $reviewOutput -notmatch 'COMBAT3D_BURNING_EFFECT_VERIFIED') { throw "Burning visual never appeared: $reviewWeapon" }
    if ($reviewProcess.ExitCode -ne 0 -or $reviewOutput -notmatch 'COMBAT3D_TEST_COMPLETE' -or $reviewOutput -notmatch ('COMBAT3D_WEAPON_PRESENTATION_VERIFIED: ' + $reviewWeapon) -or $reviewErrors -match 'SCRIPT ERROR|Parse Error|Assertion failed') {
        throw "Weapon review failed: $reviewWeapon; inspect $reviewStem"
    }
    Copy-Item -LiteralPath (Join-Path $reviewDocs ('combat3d-wave-' + $Wave + '.png')) -Destination ($reviewStem + '.png')
    Copy-Item -LiteralPath (Join-Path $reviewDocs ('combat3d-wave-' + $Wave + '-hud.png')) -Destination ($reviewStem + '-hud.png')
    Write-Output "PASS $reviewWeapon model, centering, tier, battle"
}
