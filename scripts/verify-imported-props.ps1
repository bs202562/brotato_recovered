param(
    [Parameter(Mandatory)][string[]]$PropIds,
    [string]$GodotPath = 'D:/tools/Godot_v3.6.3-stable_win64/Godot_v3.6.3-stable_win64.exe'
)
$ErrorActionPreference = 'Stop'
$reviewRoot = Split-Path -Parent $PSScriptRoot
$reviewProject = Join-Path $reviewRoot 'gdproj'
$reviewDocs = Join-Path $reviewRoot 'docs'
$reviewManifest = Get-Content (Join-Path $reviewProject 'combat3d/models.json') -Raw | ConvertFrom-Json -AsHashtable
$itemSources = @{
    turret = 'res://items/all/turret/turret_data.tres'
    landmine = 'res://items/all/landmines/landmines_data.tres'
    garden = 'res://items/all/garden/garden_data.tres'
    builder_turret = 'res://dlcs/dlc_1/items/builder_turret/builder_turret_0_data.tres'
    flame_turret = 'res://items/all/turret_flame/turret_flame_data.tres'
    healing_turret = 'res://items/all/turret_healing/turret_healing_data.tres'
    laser_turret = 'res://items/all/turret_laser/turret_laser_data.tres'
    rocket_turret = 'res://items/all/turret_rocket/turret_rocket_data.tres'
    tyler = 'res://items/all/tyler/tyler_data.tres'
    wandering_bot = 'res://items/all/wandering_bot/wandering_bot_data.tres'
}
foreach ($reviewPet in @('blazemander', 'bonk_dog', 'bot_o_mine', 'catling_gun', 'doc_moth', 'jellyshield', 'lootworm', 'ratzilla', 'scapegoat')) {
    $itemSources[$reviewPet] = 'res://items/all/' + $reviewPet + '/' + $reviewPet + '.tres'
}
$consumableSources = @{
    poisoned_fruit = 'res://dlcs/dlc_1/consumables/poisoned_fruit_data.tres'
    cursed_chest = 'res://dlcs/dlc_1/consumables/cursed_chest_data.tres'
    fruit = 'res://items/consumables/fruit/fruit_data.tres'
    item_box = 'res://items/consumables/item_box/item_box_data.tres'
    legendary_item_box = 'res://items/consumables/legendary_item_box/legendary_item_box_data.tres'
}
foreach ($reviewProp in $PropIds) {
    if ($reviewProp -notmatch '^[a-z0-9_]+$') { throw "Invalid prop identity: $reviewProp" }
    $reviewEntry = $reviewManifest['prop:' + $reviewProp]
    if (-not $reviewEntry.path) { throw "Missing independent model: $reviewProp" }
    if (-not $itemSources.ContainsKey($reviewProp) -and -not $consumableSources.ContainsKey($reviewProp) -and $reviewProp -ne 'tree') { throw "No actual spawn route configured: $reviewProp" }
    $reviewStem = Join-Path $reviewDocs ($reviewProp + '-model-battle')
    $reviewArgs = '--path "' + $reviewProject + '" --no-window res://combat3d/smoke_test.tscn --combat3d-capture-on-art --combat3d-require-art=prop:' + $reviewProp + ' --combat3d-require-model=' + $reviewEntry.path
    if ($itemSources.ContainsKey($reviewProp)) { $reviewArgs += ' --combat3d-extra-item=' + $itemSources[$reviewProp] }
    if ($reviewProp -eq 'turret') { $reviewArgs += ' --combat3d-require-turret-aim' }
    if ($reviewProp -eq 'tree') { $reviewArgs += (' --combat3d-extra-item=res://items/all/tree/tree_data.tres' * 3) }
    if ($consumableSources.ContainsKey($reviewProp)) { $reviewArgs += ' --combat3d-review-consumable=' + $consumableSources[$reviewProp] }
    $reviewProcess = Start-Process -FilePath $GodotPath -ArgumentList $reviewArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput ($reviewStem + '.log') -RedirectStandardError ($reviewStem + '.err')
    if (-not $reviewProcess.WaitForExit(45000)) { Stop-Process -Id $reviewProcess.Id; throw "Prop review timed out: $reviewProp" }
    $reviewOutput = Get-Content ($reviewStem + '.log') -Raw
    $reviewErrors = Get-Content ($reviewStem + '.err') -Raw
    if ($reviewProcess.ExitCode -ne 0 -or $reviewOutput -notmatch 'COMBAT3D_TEST_COMPLETE' -or $reviewOutput -notmatch ('COMBAT3D_ART_IDENTITY_VERIFIED: prop:' + $reviewProp) -or $reviewOutput -notmatch 'COMBAT3D_MODEL_VERIFIED:' -or $reviewErrors -match 'SCRIPT ERROR|Parse Error|Assertion failed') { throw "Prop review failed: $reviewStem" }
    if ($consumableSources.ContainsKey($reviewProp) -and $reviewOutput -notmatch 'COMBAT3D_CONSUMABLE_PICKUP_VERIFIED:') { throw "Pickup review missing: $reviewProp" }
    if ($reviewProp -eq 'turret' -and $reviewOutput -notmatch 'COMBAT3D_TURRET_AIM_VERIFIED:') { throw 'Turret shooting and aim never verified' }
    Copy-Item -LiteralPath (Join-Path $reviewDocs 'combat3d-wave-1.png') -Destination ($reviewStem + '.png')
    Copy-Item -LiteralPath (Join-Path $reviewDocs 'combat3d-wave-1-hud.png') -Destination ($reviewStem + '-hud.png')
    Write-Output "PASS $reviewProp independent model and actual combat route"
}
