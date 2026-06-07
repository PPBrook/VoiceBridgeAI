# VoiceBridgeAI engine - Windows dev launcher (mirrors run.sh)
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Root

$env:VOICEBRIDGE_DATA_DIR = $Root

$venvPython = Join-Path $Root ".venv\Scripts\python.exe"
if (-not (Test-Path $venvPython)) {
    Write-Host "Creating .venv ..."
    python -m venv .venv
}

& $venvPython -m pip install -q --upgrade pip
& $venvPython -m pip install -q -r requirements.txt

$port = if ($env:VOICEBRIDGE_PORT) { $env:VOICEBRIDGE_PORT } else { "8765" }
$listener = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
if ($listener) {
    Write-Error "Port $port is already in use."
}

Write-Host "VoiceBridgeAI engine - http://127.0.0.1:$port"
Set-Location (Join-Path $Root "server")
& $venvPython main.py
