# CityCare — build APK release pointant vers l'API VPS (HTTPS)
# Prérequis : deploy/production.url contient une seule ligne https://…/api/v1
$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $Root

$UrlFile = Join-Path $Root "deploy\production.url"
if (-not (Test-Path $UrlFile)) {
    Write-Error @"
Fichier manquant : deploy\production.url

1. Déployez l'API sur le VPS (voir deploy\README.md)
2. Créez deploy\production.url avec une ligne :
   https://api.votredomaine.com/api/v1
"@
}

$ApiUrl = (Get-Content $UrlFile -Raw).Trim()
if ($ApiUrl -notmatch '^https://.+/api/v1/?$') {
    Write-Error "URL invalide dans deploy\production.url : '$ApiUrl' (attendu https://…/api/v1)"
}
$ApiUrl = $ApiUrl.TrimEnd('/')

Write-Host "=== Build APK release ===" -ForegroundColor Cyan
Write-Host "API : $ApiUrl"

try {
    $health = Invoke-RestMethod -Uri "$ApiUrl/health" -TimeoutSec 20
    Write-Host "Health OK : $($health.service) $($health.version)" -ForegroundColor Green
} catch {
    Write-Warning "Impossible de joindre $ApiUrl/health depuis ce PC. Build quand même… ($_)"
}

$env:TEMP = 'D:\temp'
$env:PUB_CACHE = 'D:\pub-cache'
$env:GRADLE_USER_HOME = 'D:\gradle-home'
New-Item -ItemType Directory -Force -Path D:\temp, D:\pub-cache, D:\gradle-home | Out-Null

$Flutter = "C:\src\flutter\bin\flutter.bat"
if (-not (Test-Path $Flutter)) {
    $Flutter = (Get-Command flutter -ErrorAction SilentlyContinue).Source
}
if (-not $Flutter) {
    Write-Error "flutter introuvable"
}

& $Flutter build apk --release --dart-define="CITYCARE_API_URL=$ApiUrl"
if ($LASTEXITCODE -ne 0) {
    Write-Error "Build échoué"
}

$Apk = Join-Path $Root "build\app\outputs\flutter-apk\app-release.apk"
Write-Host ""
Write-Host "APK prêt : $Apk" -ForegroundColor Green
Write-Host "Installation USB (optionnel) :"
Write-Host "  adb install -r `"$Apk`""
Write-Host "Ensuite : débranchez le câble, utilisez 4G/Wi‑Fi, connectez-vous."
