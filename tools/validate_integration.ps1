$ErrorActionPreference = 'Stop'
$godot = 'C:\Users\nit\Downloads\Godot_v4.8-dev5_win64.exe\Godot_v4.8-dev5_win64_console.exe'
$project = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
& $godot --headless --path $project --script res://tools/validate_integration.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $godot --headless --path $project --script res://tests/mvp_smoke_test.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $godot --headless --path $project --script res://tests/surface_and_perception_test.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $godot --headless --path $project --script res://tests/acid_and_ragdoll_test.gd
exit $LASTEXITCODE
