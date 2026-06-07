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
dotnet run --project $Project -c Release
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
        Write-Host "No startup log. Common fix: install Windows App Runtime 1.6 x64"
        Write-Host "https://learn.microsoft.com/windows/apps/windows-app-sdk/downloads"
    }
    Read-Host "Press Enter to close"
}
