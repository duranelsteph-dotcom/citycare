# Backend CityCare + tunnel ngrok (Wi-Fi / 4G / hotspot, sans USB)
$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $Root

Write-Host "=== CityCare dev tunnel ===" -ForegroundColor Cyan

# Backend en arrière-plan si pas déjà up
try {
    $health = Invoke-WebRequest -Uri "http://127.0.0.1:8000/api/v1/health" -UseBasicParsing -TimeoutSec 2
    Write-Host "Backend déjà actif (health $($health.StatusCode))"
} catch {
    Write-Host "Démarrage backend..."
    Start-Process -FilePath "$Root\backend\.venv\Scripts\python.exe" `
        -ArgumentList "-m", "app.run_api" `
        -WorkingDirectory "$Root\backend" `
        -WindowStyle Minimized
    Start-Sleep -Seconds 4
}

& (Join-Path $PSScriptRoot "start_ngrok.ps1")
