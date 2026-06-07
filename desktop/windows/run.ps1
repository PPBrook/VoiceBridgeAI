# VoiceBridgeAI Windows client - dev launcher
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $Root "../..")).Path
$env:VOICEBRIDGE_ROOT = $RepoRoot
$LogPath = Join-Path $env:LOCALAPPDATA "VoiceBridgeAI\client-startup.log"

Write-Host "VoiceBridgeAI Windows client - repo: $RepoRoot"

$Project = Join-Path $Root "VoiceBridgeAI/VoiceBridgeAI/VoiceBridgeAI.csproj"
if (-not (Test-Path $Project)) {
    Write-Error "Missing project: $Project"
}

Set-Location $Root

$Runtime = Get-AppxPackage -Name "Microsoft.WindowsAppRuntime.1.6*" -ErrorAction SilentlyContinue
if (-not $Runtime) {
    Write-Host ""
    Write-Host "WARNING: Windows App Runtime 1.6 not detected."
    Write-Host "Run once (as admin if prompted):  .\install-runtime.ps1"
    Write-Host ""
}

dotnet build $Project -c Release
if ($LASTEXITCODE -ne 0) {
    Write-Error "Build failed"
}

$OutDir = Join-Path $Root "VoiceBridgeAI/VoiceBridgeAI/bin/Release/net8.0-windows10.0.19041.0/win-x64"
$Dll = Join-Path $OutDir "VoiceBridgeAI.dll"
if (-not (Test-Path $Dll)) {
    Write-Error "Missing build output: $Dll"
}

# Must run from output dir so WinApp SDK native/bootstrap DLLs resolve (exit 0xC0000145 otherwise)
Write-Host "Starting from $OutDir ..."
Push-Location $OutDir
try {
    dotnet exec VoiceBridgeAI.dll
    $exitCode = $LASTEXITCODE
}
finally {
    Pop-Location
}

if ($exitCode -ne 0) {
    Write-Host ""
    Write-Host "Client exited with code: $exitCode"
    if ($exitCode -eq -532462766) {
        Write-Host "(0xE0434352 = unhandled .NET exception)"
    }
    if ($exitCode -eq -1073741189) {
        Write-Host "(0xC0000145 = DLL not found — try: .\install-runtime.ps1 -Upgrade)"
    }
    if (Test-Path $LogPath) {
        Write-Host ""
        Write-Host "Startup log ($LogPath) — last 40 lines:"
        Get-Content $LogPath -Tail 40
    }
    Write-Host ""
    Write-Host "Fixes:"
    Write-Host "  1. .\install-runtime.ps1 -Upgrade"
    Write-Host "  2. Smart App Control off (Settings -> Windows Security -> App control)"
    Read-Host "Press Enter to close"
}
