# Démarre ngrok vers localhost:8000 et met à jour lib/app/tunnel_api_url.dart
# Prérequis : compte gratuit sur https://dashboard.ngrok.com
#   ngrok config add-authtoken VOTRE_TOKEN
#   (ou variable d'environnement NGROK_AUTHTOKEN)

$ErrorActionPreference = "Stop"

function Find-NgrokExe {
    $candidates = @(
        "D:\tools\ngrok\ngrok.exe",
        (Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Links\ngrok.exe"),
        (Join-Path $PSScriptRoot "..\tools\ngrok\ngrok.exe")
    )
    foreach ($path in $candidates) {
        if ($path -and (Test-Path $path)) { return (Resolve-Path $path).Path }
    }
    $cmd = Get-Command ngrok -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $winget = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Recurse -Filter "ngrok.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($winget) { return $winget.FullName }
    return $null
}

$NgrokExe = Find-NgrokExe
if (-not $NgrokExe) {
    Write-Error "ngrok introuvable. Installez-le : winget install Ngrok.Ngrok"
}

$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
$TunnelFile = Join-Path $Root "lib\app\tunnel_api_url.dart"
$Port = 8000

# Arrête une instance ngrok CityCare déjà ouverte
Get-Process -Name ngrok -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1

Write-Host "Démarrage ngrok http $Port ..."
Start-Process -FilePath $NgrokExe -ArgumentList "http", $Port, "--log=stdout" -WindowStyle Minimized

$publicUrl = $null
for ($i = 0; $i -lt 30; $i++) {
    Start-Sleep -Seconds 1
    try {
        $tunnels = Invoke-RestMethod -Uri "http://127.0.0.1:4040/api/tunnels" -TimeoutSec 2
        $publicUrl = ($tunnels.tunnels | Where-Object { $_.proto -eq "https" } | Select-Object -First 1).public_url
        if ($publicUrl) { break }
    } catch {
        # ngrok démarre encore
    }
}

if (-not $publicUrl) {
    Write-Error @"
Impossible de récupérer l'URL ngrok.
1. Créez un compte sur https://dashboard.ngrok.com
2. Copiez votre authtoken
3. Exécutez : & '$NgrokExe' config add-authtoken VOTRE_TOKEN
4. Relancez ce script
"@
}

$apiUrl = "$publicUrl/api/v1"
$content = @"
/// Généré par scripts/start_ngrok.ps1 — $(Get-Date -Format 'yyyy-MM-dd HH:mm')
library;

const kTunnelApiUrl = '$apiUrl';
"@

Set-Content -Path $TunnelFile -Value $content -Encoding UTF8
Write-Host ""
Write-Host "=== Tunnel ngrok actif ===" -ForegroundColor Green
Write-Host "URL publique : $publicUrl"
Write-Host "URL API      : $apiUrl"
Write-Host "Fichier      : $TunnelFile"
Write-Host ""
Write-Host "Prochaines étapes :" -ForegroundColor Cyan
Write-Host "  1. Backend : cd backend; .\.venv\Scripts\python.exe -m app.run_api"
Write-Host "  2. Rebuild : flutter build apk --debug --target-platform android-arm64"
Write-Host "     (ou flutter run — l'app lit kTunnelApiUrl automatiquement)"
Write-Host "  3. Sur le téléphone : effacez les données CityCare puis reconnectez-vous"
Write-Host ""
