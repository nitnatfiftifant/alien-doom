# import_textures.ps1
# Copies textures from assets/models/... into textures/ and creates matching materials in materials/

$ErrorActionPreference = 'Stop'

$candidates = @(
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

Write-Host "=== Importing Pixel Textures into Project ===" -ForegroundColor Cyan
Write-Host "[1/3] Copying texture files to textures/..." -ForegroundColor Yellow
$p1 = Start-Process -FilePath $godot -ArgumentList @('--headless', '--path', $project, '--script', 'res://tools/import_pixel_textures.gd') -Wait -PassThru -NoNewWindow

Write-Host "[2/3] Scanning and importing texture assets in Godot..." -ForegroundColor Yellow
$p2 = Start-Process -FilePath $godot -ArgumentList @('--headless', '--editor', '--quit', '--path', $project) -Wait -PassThru -NoNewWindow

Write-Host "[3/3] Generating pixel-perfect materials in materials/..." -ForegroundColor Yellow
$p3 = Start-Process -FilePath $godot -ArgumentList @('--headless', '--path', $project, '--script', 'res://tools/import_pixel_textures.gd') -Wait -PassThru -NoNewWindow

Write-Host "`n[+] Textures successfully imported!" -ForegroundColor Green
Write-Host "TrenchBroom: If open, press Ctrl+Shift+R (Reload Textures) or restart TrenchBroom."
Write-Host "Godot: Materials are pre-configured with nearest-neighbor pixel filtering and zero specular."
