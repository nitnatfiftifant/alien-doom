$ErrorActionPreference = 'Stop'

$candidates = @(
    'C:\Users\nit\Downloads\Godot_v4.8-dev5_win64.exe\Godot_v4.8-dev5_win64_console.exe',
    'C:\Users\nit\Downloads\Godot_v4.8-dev5_win64.exe',
    'D:\BeProgrammer\Godot_Engine_Experimental\Godot_v4.8-dev5_win64.exe',
    'C:\Users\HP\Downloads\Godot_v4.8-dev5_win64.exe\Godot_v4.8-dev5_win64_console.exe',
    'C:\Users\HP\Downloads\Godot_v4.8-dev5_win64.exe'
)

$godot = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $godot) {
    $found = Get-Command Godot* -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) { $godot = $found.Source }
}

if (-not $godot) {
    Write-Error "Godot executable not found. Checked: $($candidates -join ', ')"
    exit 1
}

$project = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$scripts = @(
    'res://tools/validate_integration.gd',
    'res://tests/mvp_smoke_test.gd',
    'res://tests/human_hfsm_test.gd',
    'res://tests/surface_and_perception_test.gd',
    'res://tests/acid_and_ragdoll_test.gd'
)

foreach ($script in $scripts) {
    Write-Host "[*] Running $script..." -ForegroundColor Cyan
    $p = Start-Process -FilePath $godot -ArgumentList @('--headless', '--path', $project, '--script', $script) -Wait -PassThru -NoNewWindow
    if ($p.ExitCode -ne 0) {
        Write-Error "Test $script failed with code $($p.ExitCode)"
        exit $p.ExitCode
    }
}
Write-Host "[+] All integration and smoke tests passed!" -ForegroundColor Green
exit 0
