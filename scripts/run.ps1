# Quick run helper for Windows (PowerShell).
# Usage: .\scripts\run.ps1 [device]
#   device: windows | chrome | edge | android (default: chrome)

param(
    [string]$Device = "chrome"
)

$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

switch ($Device.ToLower()) {
    "windows" { flutter run -d windows }
    "android" { flutter run -d android }
    "edge" { flutter run -d edge }
    default { flutter run -d chrome }
}
