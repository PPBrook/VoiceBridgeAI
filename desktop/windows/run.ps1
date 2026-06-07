# VoiceBridgeAI Windows client — dev launcher (mirrors desktop/macos/run.sh)
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $Root "../..")).Path
$env:VOICEBRIDGE_ROOT = $RepoRoot

Write-Host "VoiceBridgeAI Windows client - repo: $RepoRoot"

$Project = Join-Path $Root "VoiceBridgeAI/VoiceBridgeAI/VoiceBridgeAI.csproj"
if (-not (Test-Path $Project)) {
    Write-Error "Missing project: $Project"
}

Set-Location $Root
dotnet run --project $Project -c Release
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "客户端退出，代码: $LASTEXITCODE"
    Read-Host "按 Enter 关闭"
}
