# setup_trenchbroom.ps1
# Automates connecting Alien Doom (Godot) with TrenchBroom.

$ErrorActionPreference = 'Stop'

Write-Host "=== Setting up TrenchBroom for Alien Doom ===" -ForegroundColor Cyan

# 1. Locate Godot
$godotCandidates = @(
    'D:\BeProgrammer\Godot_Engine_Experimental\Godot_v4.8-dev5_win64.exe',
    'C:\Users\HP\Downloads\Godot_v4.8-dev5_win64.exe\Godot_v4.8-dev5_win64_console.exe',
    'C:\Users\HP\Downloads\Godot_v4.8-dev5_win64.exe'
)
$godot = $godotCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $godot) {
    $found = Get-Command Godot* -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) { $godot = $found.Source }
}
if (-not $godot) {
    Write-Error "Godot executable not found. Checked: $($godotCandidates -join ', ')"
    exit 1
}
Write-Host "[+] Found Godot: $godot" -ForegroundColor Green

# 2. Locate TrenchBroom
$tbCandidates = @(
    'D:\BeProgrammer\TrenchBroom\TrenchBroom.exe',
    'C:\Program Files\TrenchBroom\TrenchBroom.exe'
)
$trenchBroom = $tbCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $trenchBroom) {
    $found = Get-Command TrenchBroom* -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) { $trenchBroom = $found.Source }
}
if (-not $trenchBroom) {
    Write-Error "TrenchBroom executable not found. Checked: $($tbCandidates -join ', ')"
    exit 1
}
Write-Host "[+] Found TrenchBroom: $trenchBroom" -ForegroundColor Green

$projectDir = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$projectDirForward = $projectDir.Replace('\', '/')
$tbDir = Split-Path $trenchBroom

# 3. Export FGD and GameConfig via Godot
Write-Host "[*] Exporting FGD and TrenchBroom game config from Godot..." -ForegroundColor Yellow
$proc = Start-Process -FilePath $godot -ArgumentList @('--headless', '--path', $projectDir, '--script', 'res://tools/export_trenchbroom_config.gd') -Wait -PassThru -NoNewWindow
if ($proc.ExitCode -ne 0) {
    Write-Error "Failed to export TrenchBroom configuration (ExitCode: $($proc.ExitCode))."
    exit $proc.ExitCode
}

# 4. Configure AppData Preferences.json
$appdataTb = Join-Path $env:APPDATA 'TrenchBroom'
if (-not (Test-Path $appdataTb)) {
    New-Item -ItemType Directory -Path $appdataTb -Force | Out-Null
}
$prefFile = Join-Path $appdataTb 'Preferences.json'
$prefs = @{}
if (Test-Path $prefFile) {
    try {
        $prefs = Get-Content $prefFile -Raw -Encoding UTF8 | ConvertFrom-Json -AsHashtable
    } catch {
        $prefs = @{}
    }
}
$prefs['Games/Alien Doom/Path'] = $projectDir
$prefs['Games/Alien Doom/Default Engine'] = 'Godot'
$prefsJson = $prefs | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText($prefFile, $prefsJson, [System.Text.Encoding]::UTF8)
Write-Host "[+] Updated TrenchBroom Preferences: Games/Alien Doom/Path -> $projectDir" -ForegroundColor Green

# 5. Create GameEngineProfiles.cfg
$engineConfig = @{
    version = 1.0
    profiles = @(
        @{
            name = "Godot"
            path = $godot.Replace('\', '/')
            parameters = '--path "${GAME_DIR_PATH}"'
        }
    )
}
$engineJson = $engineConfig | ConvertTo-Json -Depth 10

$targetGamesDirs = @(
    (Join-Path $appdataTb 'games\AlienDoom'),
    (Join-Path $tbDir 'games\AlienDoom')
)
foreach ($dir in $targetGamesDirs) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $engineFile = Join-Path $dir 'GameEngineProfiles.cfg'
    [System.IO.File]::WriteAllText($engineFile, $engineJson, [System.Text.Encoding]::UTF8)
}
Write-Host "[+] Configured GameEngineProfiles.cfg (launch Godot straight from TrenchBroom)" -ForegroundColor Green

# 6. Ensure default FuncGodotLocalConfig template exists (ignored by git)
$localConfigPath = Join-Path $projectDir 'addons\func_godot\func_godot_local_config.tres'
if (-not (Test-Path $localConfigPath)) {
    $template = @"
[gd_resource type="Resource" script_class="FuncGodotLocalConfig" format=3 uid="uid://bqjt7nyekxgog"]

[ext_resource type="Script" uid="uid://xsjnhahhyein" path="res://addons/func_godot/src/util/func_godot_local_config.gd" id="1_g8kqj"]

[resource]
script = ExtResource("1_g8kqj")
"@
    [System.IO.File]::WriteAllText($localConfigPath, $template, [System.Text.Encoding]::UTF8)
    Write-Host "[+] Recreated func_godot_local_config.tres template" -ForegroundColor Green
}

Write-Host "`n=== Setup Complete! ===" -ForegroundColor Cyan
Write-Host "You can now launch TrenchBroom via: .\tools\open_trenchbroom.ps1"
Write-Host "In TrenchBroom, open maps/ventilation_blockout.map or create new maps under maps/."
Write-Host "All textures and entities (info_alien_start, info_human_spawn, info_nest, etc.) are available."
