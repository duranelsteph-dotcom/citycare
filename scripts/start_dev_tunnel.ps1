# Backend + tunnel HTTPS (Cloudflare sans compte, sinon ngrok)
$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $Root

Write-Host "=== CityCare dev tunnel ===" -ForegroundColor Cyan

try {
    $health = Invoke-WebRequest -Uri "http://127.0.0.1:8000/api/v1/health" -UseBasicParsing -TimeoutSec 2
    Write-Host "Backend actif (health $($health.StatusCode))"
} catch {
    Write-Host "Démarrage backend..."
    Start-Process -FilePath "$Root\backend\.venv\Scripts\python.exe" `
        -ArgumentList "-m", "app.run_api" `
        -WorkingDirectory "$Root\backend" `
        -WindowStyle Minimized
    Start-Sleep -Seconds 5
}

# Cloudflare = sans compte. Ngrok seulement si authtoken valide.
$ngrokConfig = "$env:LOCALAPPDATA\ngrok\ngrok.yml"
$useNgrok = $false
if (Test-Path $ngrokConfig) {
    $cfg = Get-Content $ngrokConfig -Raw
    if ($cfg -match 'authtoken:\s*(\S+)' -and $Matches[1] -notmatch 'VOTRE_TOKEN') {
        $useNgrok = $true
    }
}

if ($useNgrok) {
    Write-Host "Tunnel ngrok (authtoken détecté)..."
    & (Join-Path $PSScriptRoot "start_ngrok.ps1")
} else {
    Write-Host "Tunnel Cloudflare (gratuit, sans compte)..."
    & (Join-Path $PSScriptRoot "start_cloudflare_tunnel.ps1")
}
