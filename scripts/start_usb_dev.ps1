# CityCare : API locale + pont USB (pas de tunnel, pas de rebuild)
# Usage : brancher le téléphone, débogage USB ON, puis :
#   .\scripts\start_usb_dev.ps1
$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
$Adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
$Py = Join-Path $Root "backend\.venv\Scripts\python.exe"

Write-Host "=== CityCare USB (adb reverse) ===" -ForegroundColor Cyan

if (-not (Test-Path $Adb)) {
    Write-Error "adb introuvable : $Adb"
}
if (-not (Test-Path $Py)) {
    Write-Error "venv backend manquant : $Py"
}

$devices = & $Adb devices | Select-String "`tdevice$"
if (-not $devices) {
    Write-Error "Aucun téléphone en mode 'device'. Branchez l'USB et activez le débogage."
}

try {
    $null = Invoke-WebRequest -Uri "http://127.0.0.1:8000/api/v1/health" -UseBasicParsing -TimeoutSec 2
    Write-Host "Backend déjà actif."
} catch {
    Write-Host "Démarrage backend..."
    Start-Process -FilePath $Py -ArgumentList "-m", "app.run_api" `
        -WorkingDirectory (Join-Path $Root "backend") -WindowStyle Minimized
    Start-Sleep -Seconds 5
}

$health = Invoke-RestMethod -Uri "http://127.0.0.1:8000/api/v1/health" -TimeoutSec 5
Write-Host "API OK : $($health.service) $($health.version)" -ForegroundColor Green

& $Adb reverse tcp:8000 tcp:8000 | Out-Null
Write-Host "Pont USB : téléphone 127.0.0.1:8000 -> PC :8000" -ForegroundColor Green
& $Adb reverse --list

Write-Host ""
Write-Host "Sur le téléphone : ouvrez CityCare et connectez-vous." -ForegroundColor Yellow
Write-Host "URL utilisée : http://127.0.0.1:8000/api/v1"
Write-Host "Compte démo : +237699000001 / motdepasse / OTP otp_dev"
Write-Host ""
Write-Host "Gardez le câble branché. Si vous débranchez, le serveur redevient injoignable."
