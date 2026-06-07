# Bundled sidecar launcher (copied beside python-venv/ and server/ in package layout)
$ErrorActionPreference = "Stop"
$Dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$VenvPython = Join-Path $Dir "python-venv\Scripts\python.exe"
$DataDir = if ($env:VOICEBRIDGE_DATA_DIR) { $env:VOICEBRIDGE_DATA_DIR } else {
    Join-Path $env:APPDATA "VoiceBridgeAI"
}
$Log = Join-Path $DataDir "server.log"

New-Item -ItemType Directory -Force -Path $DataDir | Out-Null

if (-not (Test-Path $VenvPython)) {
    "VoiceBridgeAI: bundled Python venv missing at $VenvPython" | Add-Content $Log
    exit 1
}

$variantFile = Join-Path $Dir "bundle-variant.txt"
if (Test-Path $variantFile) {
    $env:VOICEBRIDGE_BUNDLE_VARIANT = (Get-Content $variantFile -Raw).Trim()
}

if ($env:VOICEBRIDGE_BUNDLE_VARIANT -eq "local" -and (Test-Path (Join-Path $Dir "bundled-models"))) {
    $env:VOICEBRIDGE_MODELS_DIR = Join-Path $Dir "bundled-models"
}

$envFile = Join-Path $DataDir ".env"
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^\s*([^#=]+)=(.*)$') {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            Set-Item -Path "env:$name" -Value $value
        }
    }
}

$env:VOICEBRIDGE_DATA_DIR = $DataDir

switch ($env:VOICEBRIDGE_BUNDLE_VARIANT) {
    "cloud" {
        if (-not $env:VOICEBRIDGE_OPTIONAL_LOCAL_MODELS) { $env:VOICEBRIDGE_OPTIONAL_LOCAL_MODELS = "1" }
        if (-not $env:LOCAL_WHISPER_ENABLED) { $env:LOCAL_WHISPER_ENABLED = "0" }
        if (-not $env:LOCAL_ARGOS_ENABLED) { $env:LOCAL_ARGOS_ENABLED = "0" }
    }
    "local" {
        if (-not $env:VOICEBRIDGE_OPTIONAL_LOCAL_MODELS) { $env:VOICEBRIDGE_OPTIONAL_LOCAL_MODELS = "0" }
        if (-not $env:LOCAL_WHISPER_ENABLED) { $env:LOCAL_WHISPER_ENABLED = "1" }
        if (-not $env:LOCAL_ARGOS_ENABLED) { $env:LOCAL_ARGOS_ENABLED = "1" }
        if (Test-Path (Join-Path $Dir "bundled-models")) {
            $env:VOICEBRIDGE_MODELS_DIR = Join-Path $Dir "bundled-models"
        }
    }
    default {
        if (-not $env:VOICEBRIDGE_OPTIONAL_LOCAL_MODELS) { $env:VOICEBRIDGE_OPTIONAL_LOCAL_MODELS = "1" }
    }
}

"=== $(Get-Date) VoiceBridgeAI sidecar start (variant=$($env:VOICEBRIDGE_BUNDLE_VARIANT)) ===" | Add-Content $Log
Set-Location (Join-Path $Dir "server")
& $VenvPython main.py 2>&1 | Add-Content $Log
