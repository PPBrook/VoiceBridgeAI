# Install or upgrade Windows App Runtime 1.6 (x64)
param(
    [switch]$Upgrade
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "VoiceBridgeAI: Windows App Runtime 1.6 (x64)"

$installed = Get-AppxPackage -Name "Microsoft.WindowsAppRuntime.1.6*" -ErrorAction SilentlyContinue
if ($installed -and -not $Upgrade) {
    Write-Host "Already installed: $($installed.Name) $($installed.Version)"
    Write-Host "If the client still fails, re-run with:  .\install-runtime.ps1 -Upgrade"
    exit 0
}

if ($installed) {
    Write-Host "Upgrading runtime (current: $($installed.Version)) ..."
}

Write-Host ""

if (Get-Command winget -ErrorAction SilentlyContinue) {
    Write-Host "Trying winget ..."
    winget upgrade -e --id Microsoft.WindowsAppRuntime.1.6 --accept-package-agreements --accept-source-agreements 2>$null
    if ($LASTEXITCODE -ne 0) {
        winget install -e --id Microsoft.WindowsAppRuntime.1.6 --accept-package-agreements --accept-source-agreements
    }
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "Done. Close PowerShell, open a new window, then:  .\run.ps1"
        exit 0
    }
    Write-Host "winget failed (code $LASTEXITCODE), trying direct download ..."
}

$Url = "https://aka.ms/windowsappsdk/1.6/latest/windowsappruntimeinstall-x64.exe"
$Installer = Join-Path $env:TEMP "WindowsAppRuntimeInstall-x64.exe"

Write-Host "Downloading $Url"
Invoke-WebRequest -Uri $Url -OutFile $Installer -UseBasicParsing

Write-Host "Running installer ..."
Start-Process -FilePath $Installer -Wait

Write-Host ""
Write-Host "Close PowerShell, open a new window, then:"
Write-Host "  cd desktop\windows"
Write-Host "  .\run.ps1"
