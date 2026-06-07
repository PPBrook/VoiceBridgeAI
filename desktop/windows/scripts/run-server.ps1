# Bundled sidecar launcher for Windows package (placeholder — wired in build-app.ps1)
$ErrorActionPreference = "Stop"
$Resources = Split-Path -Parent $MyInvocation.MyCommand.Path
$VenvPython = Join-Path $Resources "python-venv\Scripts\python.exe"
$DataDir = if ($env:VOICEBRIDGE_DATA_DIR) { $env:VOICEBRIDGE_DATA_DIR } else {
    Join-Path $env:APPDATA "VoiceBridgeAI"
}

if (-not (Test-Path $VenvPython)) {
    Write-Error "Bundled python venv missing at $VenvPython"
}

New-Item -ItemType Directory -Force -Path $DataDir | Out-Null
$log = Join-Path $DataDir "server.log"
"=== $(Get-Date) VoiceBridgeAI sidecar start ===" | Add-Content $log

$env:VOICEBRIDGE_DATA_DIR = $DataDir
Set-Location (Join-Path $Resources "server")
& $VenvPython main.py 2>&1 | Add-Content $log
