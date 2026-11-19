# Runs the multi-process network smoke test on this machine:
# 1 host + 3 clients (full lobby of 4) + 1 extra client that must be refused.
# Usage (from the project folder):  powershell -ExecutionPolicy Bypass -File tests/run_net_smoke.ps1
param(
    [string]$Godot = "D:\GoDot\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe",
    [string]$LogDir = (Join-Path $env:TEMP "night-shift-net-smoke")
)

$project = Split-Path -Parent $PSScriptRoot
New-Item -ItemType Directory -Force $LogDir | Out-Null
Get-ChildItem $LogDir -Filter *.log -ErrorAction SilentlyContinue | Remove-Item

function Start-Role([string]$Role, [string]$Name) {
    $log = Join-Path $LogDir "$Role-$Name.log"
    $argList = @("--headless", "--path", "`"$project`"", "res://tests/net_smoke.tscn", "--", "--role=$Role", "--name=$Name")
    Start-Process -FilePath $Godot -ArgumentList $argList -NoNewWindow -PassThru `
        -RedirectStandardOutput $log -RedirectStandardError "$log.err"
}

$procs = @()
$procs += Start-Role "host" "H"
Start-Sleep -Seconds 2
foreach ($n in 1..3) { $procs += Start-Role "client" "C$n" }
Start-Sleep -Seconds 4
$procs += Start-Role "extra" "X"

$procs | Wait-Process -Timeout 180 -ErrorAction SilentlyContinue
$failed = 0
foreach ($p in $procs) {
    if (-not $p.HasExited) { $p | Stop-Process -Force; $failed++ ; continue }
    if ($p.ExitCode -ne 0) { $failed++ }
}
Get-ChildItem $LogDir -Filter *.log | ForEach-Object {
    Get-Content $_.FullName | Select-String -Pattern "PASS|FAIL|NET SMOKE|SCRIPT ERROR|ERROR:"
}
if ($failed -eq 0) { Write-Host "ALL ROLES OK" } else { Write-Host "$failed ROLE(S) FAILED" }
exit $failed
