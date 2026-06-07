# VoiceBridgeAI engine - Windows dev launcher (mirrors run.sh)
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Root

$env:VOICEBRIDGE_DATA_DIR = $Root

function Resolve-PythonLauncher {
    $py = Get-Command python -ErrorAction SilentlyContinue
    if ($py) { return @($py.Source) }

    $py3 = Get-Command python3 -ErrorAction SilentlyContinue
    if ($py3) { return @($py3.Source) }

    $launcher = Get-Command py -ErrorAction SilentlyContinue
    if ($launcher) { return @($launcher.Source, "-3") }

    throw "Python not found. Install Python 3.10+ from https://www.python.org/downloads/ and check 'Add python.exe to PATH', then reopen PowerShell."
}

$venvPython = Join-Path $Root ".venv\Scripts\python.exe"
if (-not (Test-Path $venvPython)) {
    Write-Host "Creating .venv ..."
    $pythonCmd = Resolve-PythonLauncher
    & @pythonCmd -m venv .venv
}

if (-not (Test-Path $venvPython)) {
    throw "Failed to create .venv at $venvPython"
}

& $venvPython -m pip install -q --upgrade pip
& $venvPython -m pip install -q -r requirements.txt

$port = if ($env:VOICEBRIDGE_PORT) { $env:VOICEBRIDGE_PORT } else { "8765" }
try {
    $listener = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
    if ($listener) {
        Write-Error "Port $port is already in use."
    }
}
catch {
    # Get-NetTCPConnection unavailable on some SKUs; server will fail loudly if port busy.
}

Write-Host "VoiceBridgeAI engine - http://127.0.0.1:$port"
Set-Location (Join-Path $Root "server")
& $venvPython main.py
