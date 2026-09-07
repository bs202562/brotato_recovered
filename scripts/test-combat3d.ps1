param(
    [string]$GodotPath = 'D:\tools\Godot_v3.6.3-stable_win64\Godot_v3.6.3-stable_win64.exe'
)
$ErrorActionPreference = 'Stop'
$combatRoot = Split-Path -Parent $PSScriptRoot
$combatProject = Join-Path $combatRoot 'gdproj'
$combatDocs = Join-Path $combatRoot 'docs'
$combatCases = @(
    @{ Name = 'wave1'; Args = ''; Marker = 'COMBAT3D_TEST_COMPLETE' },
    @{ Name = 'wave12'; Args = '--combat3d-wave=12'; Marker = 'COMBAT3D_TEST_COMPLETE' },
    @{ Name = 'wave20'; Args = '--combat3d-wave=20'; Marker = 'COMBAT3D_TEST_COMPLETE' },
    @{ Name = 'cycle'; Args = '--combat3d-cycle'; Marker = 'COMBAT3D_TEST_CYCLE_COMPLETE' }
)
foreach ($combatCase in $combatCases) {
    $combatOut = Join-Path $combatDocs ('combat3d-' + $combatCase.Name + '.log')
    $combatErr = Join-Path $combatDocs ('combat3d-' + $combatCase.Name + '-errors.log')
    $combatArguments = '--path "' + $combatProject + '" --no-window res://combat3d/smoke_test.tscn ' + $combatCase.Args
    $combatProcess = Start-Process -FilePath $GodotPath -ArgumentList $combatArguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $combatOut -RedirectStandardError $combatErr
    if (-not $combatProcess.WaitForExit(60000)) {
        Stop-Process -Id $combatProcess.Id
        throw ('Timed out: ' + $combatCase.Name)
    }
    $combatOutput = Get-Content -LiteralPath $combatOut -Raw
    $combatErrors = Get-Content -LiteralPath $combatErr -Raw
    if ($combatOutput -notmatch $combatCase.Marker -or $combatErrors -match 'SCRIPT ERROR|Parse Error|Assertion failed') {
        throw ('Failed: ' + $combatCase.Name + '. Inspect ' + $combatErr)
    }
    Write-Output ('PASS ' + $combatCase.Name)
}
Write-Output 'The recovered project has baseline shutdown resource-leak warnings; inspect the error logs for any new engine errors. Headless FPS is not a device performance benchmark.'
