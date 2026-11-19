# Exports the Windows build and packs it for friends:
#   build/NightShift.exe, build/LICENSES.txt, build/HOW_TO_PLAY.txt, build/NightShift.zip
# Usage (from the project folder):  powershell -ExecutionPolicy Bypass -File tests/export_build.ps1
# Needs the Godot 4.7 export templates (Editor > Manage Export Templates).
param(
    [string]$Godot = "D:\GoDot\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe"
)

$ErrorActionPreference = "Stop"
$project = Split-Path -Parent $PSScriptRoot
$build = Join-Path $project "build"
New-Item -ItemType Directory -Force $build | Out-Null

& $Godot --headless --path $project --import | Out-Null
& $Godot --headless --path $project --export-release "Windows Desktop" (Join-Path $build "NightShift.exe") | Out-Null
if ($LASTEXITCODE -ne 0) { Write-Host "EXPORT FAILED ($LASTEXITCODE)"; exit 1 }

# Godot is MIT licensed: its notice must ship with the game.
& $Godot --headless --path $project --script res://tests/write_licenses.gd -- (Join-Path $build "LICENSES.txt") | Out-Null
Copy-Item (Join-Path $project "docs\HOW_TO_PLAY.txt") (Join-Path $build "HOW_TO_PLAY.txt") -Force

$zip = Join-Path $build "NightShift.zip"
Remove-Item $zip -ErrorAction SilentlyContinue
Compress-Archive -Path (Join-Path $build "NightShift.exe"), (Join-Path $build "LICENSES.txt"), (Join-Path $build "HOW_TO_PLAY.txt") -DestinationPath $zip
Get-ChildItem $build | Select-Object Name, @{n = "MB"; e = { [math]::Round($_.Length / 1MB, 1) } } | Format-Table -AutoSize
Write-Host "BUILD OK"
