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
    Write-Host "WARNING: Windows App Runtime 1.6 not detected. Run: .\install-runtime.ps1"
    Write-Host ""
}

dotnet build $Project -c Release
if ($LASTEXITCODE -ne 0) {
    Write-Error "Build failed"
}

$OutDir = Join-Path $Root "VoiceBridgeAI/VoiceBridgeAI/bin/Release/net8.0-windows10.0.19041.0/win-x64"
$Exe = Join-Path $OutDir "VoiceBridgeAI.exe"
if (-not (Test-Path $Exe)) {
    Write-Error "Missing build output: $Exe"
}

Get-ChildItem $OutDir -File -Recurse -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue

# Help the exe find repo root when launched without inherited env
Set-Content -Path (Join-Path $OutDir "voicebridge-repo-path") -Value $RepoRoot -Encoding utf8NoBOM

Write-Host "Starting $Exe ..."
Write-Host ""

Push-Location $OutDir
$exitCode = 0
$blockedByPolicy = $false
try {
    $proc = Start-Process -FilePath $Exe -WorkingDirectory $OutDir -PassThru -Wait
    $exitCode = $proc.ExitCode
}
catch {
    $msg = $_.Exception.Message
    if ($msg -match "Application Control|应用控制|4551") {
        $blockedByPolicy = $true
        Write-Host "============================================================"
        Write-Host " BLOCKED: Smart App Control (unsigned dev build)"
        Write-Host "============================================================"
        Write-Host ""
        Write-Host "WinUI must run VoiceBridgeAI.exe. Windows blocks unsigned apps."
        Write-Host "There is no code workaround — turn Smart App Control OFF once:"
        Write-Host ""
        Write-Host "  1. Settings -> Privacy and security -> Windows Security"
        Write-Host "  2. App and browser control -> Smart App Control"
        Write-Host "  3. Select OFF -> Restart PC (required)"
        Write-Host "  4. Run:  .\run.ps1"
        Write-Host ""
        Write-Host "Opening Windows Security settings ..."
        Start-Process "windowsdefender://smartappcontrol" -ErrorAction SilentlyContinue
        if ($LASTEXITCODE -ne 0) {
            Start-Process "ms-settings:windowsdefender" -ErrorAction SilentlyContinue
        }
        Write-Host ""
        Write-Host "Meanwhile you can test the Python engine only:"
        Write-Host "  cd C:\Users\pengp\VoiceBridgeAI"
        Write-Host "  .\run.ps1"
        $exitCode = 1
    }
    else {
        Write-Error $_
    }
}
finally {
    Pop-Location
}

if ($exitCode -ne 0 -and -not $blockedByPolicy) {
    Write-Host "Client exited with code: $exitCode"
    if (Test-Path $LogPath) {
        Get-Content $LogPath -Tail 20
    }
    Read-Host "Press Enter to close"
}
