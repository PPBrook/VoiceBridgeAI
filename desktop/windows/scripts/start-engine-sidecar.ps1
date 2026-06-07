# Sidecar bootstrap: ensure .venv then start server (called from WinUI app)
$ErrorActionPreference = "Stop"
$Root = if ($env:VOICEBRIDGE_DATA_DIR) { $env:VOICEBRIDGE_DATA_DIR } else {
    Split-Path -Parent $MyInvocation.MyCommand.Path
}
$Log = Join-Path $Root "sidecar-bootstrap.log"

function Write-Log($msg) {
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $msg"
    Add-Content -Path $Log -Value $line
    Write-Output $line
}

try {
    Set-Location $Root
    Write-Log "sidecar start root=$Root"

    function Resolve-PythonLauncher {
        $py = Get-Command python -ErrorAction SilentlyContinue
        if ($py) { return @($py.Source) }
        $launcher = Get-Command py -ErrorAction SilentlyContinue
        if ($launcher) { return @($launcher.Source, "-3") }
        throw "Python not found in PATH"
    }

    $venvPython = Join-Path $Root ".venv\Scripts\python.exe"
    if (-not (Test-Path $venvPython)) {
        Write-Log "creating .venv"
        $pythonCmd = Resolve-PythonLauncher
        & @pythonCmd -m venv (Join-Path $Root ".venv") 2>&1 | ForEach-Object { Write-Log $_ }
    }

    if (-not (Test-Path $venvPython)) {
        throw "venv missing at $venvPython"
    }

    Write-Log "pip install ..."
    & $venvPython -m pip install -q --upgrade pip 2>&1 | ForEach-Object { Write-Log $_ }
    & $venvPython -m pip install -q -r (Join-Path $Root "requirements.txt") 2>&1 | ForEach-Object { Write-Log $_ }

    $env:VOICEBRIDGE_DATA_DIR = $Root
    Write-Log "starting server/main.py"
    Set-Location (Join-Path $Root "server")
    & $venvPython main.py 2>&1 | ForEach-Object { Write-Log $_ }
}
catch {
    Write-Log "FATAL: $_"
    exit 1
}
