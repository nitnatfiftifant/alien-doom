$ErrorActionPreference = 'Stop'

$candidates = @(
    'D:\BeProgrammer\TrenchBroom\TrenchBroom.exe',
    'C:\Program Files\TrenchBroom\TrenchBroom.exe'
)

$trenchBroom = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $trenchBroom) {
    $found = Get-Command TrenchBroom* -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) { $trenchBroom = $found.Source }
}

if (-not $trenchBroom) {
    Write-Error "TrenchBroom executable not found. Checked: $($candidates -join ', ')"
    exit 1
}

$map = if ($args.Count -gt 0) { $args[0] } else { Join-Path $PSScriptRoot '..\maps\ventilation_blockout.map' }
Start-Process -FilePath $trenchBroom -ArgumentList @($map) -WorkingDirectory (Split-Path $trenchBroom)

