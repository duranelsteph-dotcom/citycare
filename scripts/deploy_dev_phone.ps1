# Tout-en-un : backend + tunnel Cloudflare + build APK + install (si USB)
$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $Root

& (Join-Path $PSScriptRoot "start_dev_tunnel.ps1")

$env:TEMP = "D:\temp"
$env:TMP = "D:\temp"
$env:PUB_CACHE = "D:\pub-cache"
$env:GRADLE_USER_HOME = "D:\gradle-home"
New-Item -ItemType Directory -Force -Path D:\temp | Out-Null

Write-Host "Build APK..." -ForegroundColor Cyan
C:\src\flutter\bin\flutter.bat build apk --debug --target-platform android-arm64
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
$devices = & $adb devices 2>&1 | Select-String "device$"
if ($devices) {
    Write-Host "Installation sur le telephone..." -ForegroundColor Cyan
    & $adb install -r "$Root\build\app\outputs\flutter-apk\app-debug.apk"
} else {
    Write-Host "Telephone non branche — copiez l'APK manuellement :" -ForegroundColor Yellow
    Write-Host "$Root\build\app\outputs\flutter-apk\app-debug.apk"
    Write-Host "Puis effacez les donnees CityCare avant de vous connecter."
}

Write-Host ""
Write-Host "Compte demo : +237699000001 / motdepasse — OTP otp_dev" -ForegroundColor Green
