# Tunnel HTTPS gratuit sans compte (Cloudflare Quick Tunnel)
$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
$TunnelFile = Join-Path $Root "lib\app\tunnel_api_url.dart"
$Port = 8000
$LogFile = Join-Path $env:TEMP "citycare-cloudflared.log"

function Find-Cloudflared {
    if (Test-Path "D:\tools\cloudflared\cloudflared.exe") { return "D:\tools\cloudflared\cloudflared.exe" }
    $cmd = Get-Command cloudflared -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $winget = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Recurse -Filter "cloudflared.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($winget) { return $winget.FullName }
    return $null
}

$Exe = Find-Cloudflared
if (-not $Exe) {
    Write-Error "cloudflared introuvable. Installez : winget install Cloudflare.cloudflared"
}

Get-Process -Name cloudflared -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Remove-Item $LogFile -ErrorAction SilentlyContinue

Write-Host "Démarrage Cloudflare Tunnel vers localhost:$Port ..."
$LogErr = Join-Path $env:TEMP "citycare-cloudflared.err.log"
Start-Process -FilePath $Exe -ArgumentList "tunnel", "--url", "http://127.0.0.1:$Port", "--no-autoupdate" `
    -RedirectStandardOutput $LogFile -RedirectStandardError $LogErr -WindowStyle Hidden

$publicUrl = $null
for ($i = 0; $i -lt 45; $i++) {
    Start-Sleep -Seconds 1
    foreach ($path in @($LogFile, $LogErr)) {
        if (-not (Test-Path $path)) { continue }
        $log = Get-Content $path -Raw -ErrorAction SilentlyContinue
        if ($log -match '(https://[a-z0-9-]+\.trycloudflare\.com)') {
            $publicUrl = $Matches[1]
            break
        }
    }
    if ($publicUrl) { break }
}

if (-not $publicUrl) {
    Write-Error "Impossible de récupérer l'URL Cloudflare. Log : $LogFile"
}

$apiUrl = "$publicUrl/api/v1"
$content = @"
/// Généré par scripts/start_cloudflare_tunnel.ps1 — $(Get-Date -Format 'yyyy-MM-dd HH:mm')
library;

const kTunnelApiUrl = '$apiUrl';
"@

Set-Content -Path $TunnelFile -Value $content -Encoding UTF8
Write-Host ""
Write-Host "=== Tunnel Cloudflare actif ===" -ForegroundColor Green
Write-Host "URL publique : $publicUrl"
Write-Host "URL API      : $apiUrl"
Write-Host "Fichier      : $TunnelFile"
Write-Host ""
