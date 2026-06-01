$ErrorActionPreference = "Stop"

$appRoot = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $appRoot "config\google.dev.json"

if (-not (Test-Path $configPath)) {
  Copy-Item (Join-Path $appRoot "config\google.dev.json.example") $configPath
  Write-Host "Se creo config/google.dev.json. Actualiza GOOGLE_WEB_CLIENT_ID con un OAuth Web client."
}

Set-Location $appRoot
flutter run -d chrome --web-port=8080 --dart-define-from-file=config/google.dev.json
