$ErrorActionPreference = 'Stop'
$trenchBroom = 'C:\Users\nit\Documents\TrenchBroom-Win64-AMD64-v2026.2-Release\TrenchBroom.exe'
$map = Join-Path $PSScriptRoot '..\maps\ventilation_blockout.map'
Start-Process -FilePath $trenchBroom -ArgumentList @($map) -WorkingDirectory (Split-Path $trenchBroom)

