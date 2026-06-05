# Fixes corrupted/incomplete Firebase C++ SDK extraction on Windows builds.
# Run from project root: .\scripts\fix_windows_firebase_build.ps1

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

Write-Host "Stopping stray build processes..." -ForegroundColor Cyan
Get-Process | Where-Object { $_.ProcessName -match 'cmake|ninja|msbuild|flutter|dart' } |
    Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

Write-Host "Cleaning Windows Firebase native build cache..." -ForegroundColor Cyan

$paths = @(
    "build\windows",
    "windows\flutter\ephemeral"
)

foreach ($rel in $paths) {
    $full = Join-Path $projectRoot $rel
    if (Test-Path $full) {
        Remove-Item -Recurse -Force $full
        Write-Host "  Removed $rel"
    }
}

$zipUrl = "https://dl.google.com/firebase/sdk/cpp/firebase_cpp_sdk_windows_13.5.0.zip"
$zipPath = Join-Path $projectRoot "build\windows\x64\firebase_cpp_sdk_windows_13.5.0.zip"
$extractRoot = Join-Path $projectRoot "build\windows\x64\extracted"
New-Item -ItemType Directory -Path (Split-Path $zipPath) -Force | Out-Null

Write-Host ""
Write-Host "Downloading Firebase C++ SDK (~913 MB, use a stable connection)..." -ForegroundColor Cyan
# -C - resumes if a previous download was interrupted
curl.exe -L --http1.1 -C - -o $zipPath $zipUrl
if ($LASTEXITCODE -ne 0) { throw "Firebase SDK download failed." }

Write-Host "Extracting SDK..." -ForegroundColor Cyan
Remove-Item -Recurse -Force $extractRoot -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $extractRoot -Force | Out-Null
Expand-Archive -Path $zipPath -DestinationPath $extractRoot -Force

$sdkCMake = Join-Path $extractRoot "firebase_cpp_sdk_windows\CMakeLists.txt"
if (-not (Test-Path $sdkCMake)) {
    throw "Extraction failed. Delete build\windows and run this script again."
}

Write-Host ""
Write-Host "Re-fetching dependencies..." -ForegroundColor Cyan
flutter pub get

Write-Host ""
Write-Host "Rebuilding Windows app..." -ForegroundColor Cyan
flutter build windows

Write-Host ""
Write-Host "Done. Run with: flutter run -d windows" -ForegroundColor Green
