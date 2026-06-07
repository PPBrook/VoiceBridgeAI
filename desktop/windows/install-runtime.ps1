# Install Windows App Runtime 1.6 (x64) — required once for WinUI client
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "VoiceBridgeAI: checking Windows App Runtime 1.6 ..."

$installed = Get-AppxPackage -Name "Microsoft.WindowsAppRuntime.1.6*" -ErrorAction SilentlyContinue
if ($installed) {
    Write-Host "Already installed: $($installed.Name) $($installed.Version)"
    exit 0
}

Write-Host "Not found. Installing (admin may prompt) ..."
Write-Host ""

if (Get-Command winget -ErrorAction SilentlyContinue) {
    Write-Host "Trying winget ..."
    winget install -e --id Microsoft.WindowsAppRuntime.1.6 --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "Done. Re-open PowerShell and run: cd desktop\windows; .\run.ps1"
        exit 0
    }
    Write-Host "winget failed (code $LASTEXITCODE), trying direct download ..."
}

$Url = "https://aka.ms/windowsappsdk/1.6/latest/windowsappruntimeinstall-x64.exe"
$Installer = Join-Path $env:TEMP "WindowsAppRuntimeInstall-x64.exe"

Write-Host "Downloading $Url"
Invoke-WebRequest -Uri $Url -OutFile $Installer -UseBasicParsing

Write-Host "Running installer (click through the wizard) ..."
Start-Process -FilePath $Installer -Wait

Write-Host ""
Write-Host "If install succeeded, re-open PowerShell and run:"
Write-Host "  cd desktop\windows"
Write-Host "  .\run.ps1"
