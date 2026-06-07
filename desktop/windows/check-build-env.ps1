# Verify Windows client build prerequisites
$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ok = $true

function Test-Requirement {
    param(
        [string]$Name,
        [bool]$Passed,
        [string]$Hint
    )
    if ($Passed) {
        Write-Host "[OK]   $Name" -ForegroundColor Green
    }
    else {
        Write-Host "[MISS] $Name" -ForegroundColor Red
        Write-Host "       $Hint" -ForegroundColor Yellow
        $script:ok = $false
    }
}

Write-Host "VoiceBridgeAI Windows build environment"
Write-Host ""

$dotnet = Get-Command dotnet -ErrorAction SilentlyContinue
if ($dotnet) {
    $ver = (& dotnet --version 2>$null).Trim()
    if ($ver -match '^8\.|^9\.') {
        Test-Requirement ".NET SDK $ver" $true ""
    }
    else {
        Test-Requirement ".NET SDK $ver" $false "Install .NET 8 SDK: https://dotnet.microsoft.com/download/dotnet/8.0"
    }
}
else {
    Test-Requirement ".NET SDK" $false "Install .NET 8 SDK"
}

$runtime = Get-AppxPackage -Name "Microsoft.WindowsAppRuntime.1.6*" -ErrorAction SilentlyContinue
Test-Requirement "Windows App Runtime 1.6" ([bool]$runtime) "Run: .\install-runtime.ps1"

$kitsPaths = @(
    "${env:ProgramFiles(x86)}\Windows Kits\10",
    "$env:ProgramFiles\Windows Kits\10"
)
$hasSdk = $false
foreach ($p in $kitsPaths) {
    if (Test-Path (Join-Path $p "bin\10.0.22621.0\x64\rc.exe")) {
        $hasSdk = $true
        break
    }
    if (Test-Path (Join-Path $p "bin\10.0.26100.0\x64\rc.exe")) {
        $hasSdk = $true
        break
    }
    if (Test-Path (Join-Path $p "UnionMetadata")) {
        $hasSdk = $true
        break
    }
}

$msbuild = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe"
if (-not (Test-Path -LiteralPath $msbuild)) {
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path -LiteralPath $vswhere) {
        $install = & $vswhere -latest -products * -requires Microsoft.Component.MSBuild -property installationPath 2>$null
        if ($install) {
            $msbuild = Join-Path $install "MSBuild\Current\Bin\MSBuild.exe"
        }
    }
}
Test-Requirement "MSBuild (VS Build Tools)" (Test-Path -LiteralPath $msbuild) "Install VS 2022 Build Tools with「Windows 应用程序开发」workload"
Test-Requirement "Windows 10 SDK (Windows Kits)" $hasSdk @"
Install Visual Studio 2022 Build Tools → workload「Windows 应用程序开发」
或单独安装 Windows SDK: https://developer.microsoft.com/windows/downloads/windows-sdk/
WinUI XamlCompiler 依赖此 SDK；缺少时 dotnet build 会报 MSB3073 且无具体 XAML 错误。
"@

$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) { $python = Get-Command py -ErrorAction SilentlyContinue }
Test-Requirement "Python 3.10+" ([bool]$python) "Install Python 3.10–3.12 from python.org (3.14 may lack wheels for some deps)"

Write-Host ""
if ($ok) {
    Write-Host "Environment looks ready. Try: .\run.ps1" -ForegroundColor Green
    exit 0
}

Write-Host "Fix the items above, then re-run this script." -ForegroundColor Yellow
exit 1
