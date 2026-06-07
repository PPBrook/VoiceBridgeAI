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

# Run via dotnet host (VoiceBridgeAI.dll) — unsigned apphost .exe is often blocked by Smart App Control
dotnet build $Project -c Release
if ($LASTEXITCODE -ne 0) {
    Write-Error "Build failed"
}

$Dll = Join-Path $Root "VoiceBridgeAI/VoiceBridgeAI/bin/Release/net8.0-windows10.0.19041.0/win-x64/VoiceBridgeAI.dll"
if (-not (Test-Path $Dll)) {
    Write-Error "Missing build output: $Dll"
}

Write-Host "Starting via dotnet exec (bypasses blocked VoiceBridgeAI.exe apphost) ..."
dotnet exec $Dll
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "Client exited with code: $LASTEXITCODE"
    if ($LASTEXITCODE -eq -532462766) {
        Write-Host "(0xE0434352 = unhandled .NET exception — see log below or a popup dialog)"
    }
    if (Test-Path $LogPath) {
        Write-Host ""
        Write-Host "Startup log ($LogPath):"
        Get-Content $LogPath -Tail 40
    }
    else {
        Write-Host ""
        Write-Host "No startup log. Common fixes:"
        Write-Host "  1. Install Windows App Runtime 1.6 x64 (required once):"
        Write-Host "     cd desktop\windows"
        Write-Host "     .\install-runtime.ps1"
        Write-Host "  2. Smart App Control blocked the app:"
        Write-Host "     Settings -> Privacy & security -> Windows Security -> App & browser control"
        Write-Host "     -> Smart App Control -> Off (requires restart)"
    }
    Read-Host "Press Enter to close"
}
