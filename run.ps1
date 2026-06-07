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

function Test-EnginePortInUse {
    param([string]$Port)
    try {
        return Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
    }
    catch {
        return $null
    }
}

function Show-PortBusyHelp {
    param([string]$Port, [int]$OwningProcess)
    $proc = Get-Process -Id $OwningProcess -ErrorAction SilentlyContinue
    $name = if ($proc) { $proc.ProcessName } else { "unknown" }
    Write-Host ""
    Write-Host "Port $Port is already in use by $name (PID $OwningProcess)."
    try {
        $health = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/api/health" -TimeoutSec 2
        if ($health.status -eq "ok") {
            Write-Host "VoiceBridgeAI engine is already running — skip terminal 1 and start the client:"
            Write-Host "  cd $Root\desktop\windows"
            Write-Host "  .\run.ps1"
            exit 0
        }
    }
    catch {
        # Not our engine — fall through to error below.
    }
    Write-Host "Stop the other process or pick another port: `$env:VOICEBRIDGE_PORT=8766; .\run.ps1"
    exit 1
}

$listener = Test-EnginePortInUse -Port $port
if ($listener) {
    Show-PortBusyHelp -Port $port -OwningProcess $listener.OwningProcess
}

Write-Host "VoiceBridgeAI engine - http://127.0.0.1:$port"
Write-Host "(Keep this terminal open. Start the WinUI client in a second terminal: cd desktop\windows; .\run.ps1)"
Write-Host ""

$serverDir = Join-Path $Root "server"
Push-Location $serverDir
try {
    & $venvPython main.py
}
finally {
    Pop-Location
}
