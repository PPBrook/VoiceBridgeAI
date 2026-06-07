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
    Write-Host "Run:  .\install-runtime.ps1"
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

# WinUI must launch via apphost .exe (dotnet exec -> 0xC0000145 DLL not found)
Get-ChildItem $OutDir -File -Recurse -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue

Write-Host "Starting $Exe ..."
Write-Host "(If blocked: Settings -> Privacy -> Windows Security -> App control -> Smart App Control -> Off)"
Write-Host ""

Push-Location $OutDir
try {
    $proc = Start-Process -FilePath $Exe -WorkingDirectory $OutDir -PassThru -Wait
    $exitCode = $proc.ExitCode
}
catch [System.ComponentModel.Win32Exception] {
    Write-Host ""
    Write-Host "Could not start VoiceBridgeAI.exe: $($_.Exception.Message)"
    Write-Host ""
    Write-Host "Smart App Control often blocks unsigned dev builds."
    Write-Host "Turn OFF: Settings -> Privacy and security -> Windows Security"
    Write-Host "          -> App and browser control -> Smart App Control -> Off (restart PC)"
    Write-Host ""
    Write-Host "Then run this script again."
    $exitCode = 1
}
finally {
    Pop-Location
}

if ($exitCode -ne 0) {
    Write-Host ""
    Write-Host "Client exited with code: $exitCode"
    if (Test-Path $LogPath) {
        Write-Host ""
        Write-Host "Startup log ($LogPath):"
        Get-Content $LogPath -Tail 20
    }
    Read-Host "Press Enter to close"
}
