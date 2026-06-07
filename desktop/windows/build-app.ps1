# 构建独立 Windows 包：.\build-app.ps1 cloud | local
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet("cloud", "local")]
    [string]$Variant,

    [switch]$SkipZip,

    [switch]$Setup
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $Root "../..")).Path
$Project = Join-Path $Root "VoiceBridgeAI/VoiceBridgeAI/VoiceBridgeAI.csproj"
$Scripts = Join-Path $Root "scripts"
$BundleSeed = Join-Path $Scripts "bundle-seed"

. (Join-Path $BundleSeed "Merge-DemoSecrets.ps1")

Write-Host "VoiceBridgeAI Windows build environment check …"
& (Join-Path $Root "check-build-env.ps1")
if ($LASTEXITCODE -ne 0) {
    throw "Build environment incomplete. See messages above."
}

Write-Host ""

$SkipVenv = $env:SKIP_VENV -eq "1"
$SkipModels = $env:SKIP_MODELS -eq "1"
$CopyVenv = if ($null -eq $env:BUNDLE_COPY_VENV) { "1" } else { $env:BUNDLE_COPY_VENV }

switch ($Variant) {
    "cloud" {
        $AppName = "VoiceBridgeAI-Cloud"
        $Requirements = Join-Path $RepoRoot "requirements-cloud.txt"
        $Seed = Join-Path $BundleSeed "cloud.env"
    }
    "local" {
        $AppName = "VoiceBridgeAI-Local"
        $Requirements = Join-Path $RepoRoot "requirements.txt"
        $Seed = Join-Path $BundleSeed "local.env"
    }
}

$DistDir = Join-Path $Root "dist"
$OutDir = Join-Path $DistDir $AppName

function Resolve-PythonLauncher {
    $candidates = @(
        @{ Exe = "py"; Args = @("-3") },
        @{ Exe = "python"; Args = @() },
        @{ Exe = "python3"; Args = @() }
    )
    foreach ($c in $candidates) {
        $cmd = Get-Command $c.Exe -ErrorAction SilentlyContinue
        if ($cmd) {
            return @{ Path = $cmd.Source; Args = $c.Args }
        }
    }
    throw "Python not found. Install Python 3.10+ and ensure it is on PATH."
}

function Copy-TreeFiltered {
    param(
        [string]$Source,
        [string]$Destination
    )
    if (Test-Path $Destination) {
        Remove-Item -Recurse -Force $Destination
    }
    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    Get-ChildItem -Path $Source -Recurse -Force | Where-Object {
        $_.FullName -notmatch '\\__pycache__\\' -and $_.Extension -ne '.pyc'
    } | ForEach-Object {
        $relative = $_.FullName.Substring($Source.Length).TrimStart('\', '/')
        $target = Join-Path $Destination $relative
        if ($_.PSIsContainer) {
            New-Item -ItemType Directory -Force -Path $target | Out-Null
        }
        else {
            $parent = Split-Path $target -Parent
            if (-not (Test-Path $parent)) {
                New-Item -ItemType Directory -Force -Path $parent | Out-Null
            }
            Copy-Item -LiteralPath $_.FullName -Destination $target -Force
        }
    }
}

function Install-PipWithRetry {
    param(
        [string]$VenvPython,
        [string]$RequirementsFile
    )
    $max = if ($env:PIP_INSTALL_ATTEMPTS) { [int]$env:PIP_INSTALL_ATTEMPTS } else { 4 }
    & $VenvPython -m pip install --upgrade pip
    for ($n = 1; $n -le $max; $n++) {
        Write-Host "pip install ($n/$max) …"
        & $VenvPython -m pip install --retries 5 --default-timeout=180 -r $RequirementsFile
        if ($LASTEXITCODE -eq 0) { return }
        Write-Host "pip 失败，重试…" -ForegroundColor Yellow
        Start-Sleep -Seconds 3
    }
    throw "pip install 多次失败。若仓库已有 .venv，可设 `$env:BUNDLE_COPY_VENV='1' 后重试。"
}

function Build-InnoSetup {
    param(
        [string]$AppName,
        [string]$AppDisplayName,
        [string]$SourceDir,
        [string]$DistDir
    )
    $candidates = @(
        "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
        "$env:ProgramFiles\Inno Setup 6\ISCC.exe",
        "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
    )
    $iscc = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $iscc) {
        Write-Host ""
        Write-Host "未找到 Inno Setup 6（ISCC.exe）。可选安装：" -ForegroundColor Yellow
        Write-Host "  winget install -e --id JRSoftware.InnoSetup"
        Write-Host "或仅分发 zip：不加 -Setup 参数"
        return
    }

    $iss = Join-Path $Root "installer\VoiceBridgeAI.iss"
    if (-not (Test-Path $iss)) {
        throw "Missing installer script: $iss"
    }

    $outputBase = "$AppName-Setup"
    $setupPath = Join-Path $DistDir "$outputBase.exe"
    if (Test-Path $setupPath) {
        Remove-Item -Force $setupPath
    }

    Write-Host "生成安装程序: $setupPath"
    & $iscc `
        "/DAppName=$AppName" `
        "/DAppDisplayName=$AppDisplayName" `
        "/DSourceDir=$SourceDir" `
        "/DOutputDir=$DistDir" `
        "/DOutputBaseFilename=$outputBase" `
        $iss
    if ($LASTEXITCODE -ne 0) {
        throw "Inno Setup compile failed"
    }

    if (Test-Path $setupPath) {
        $setupSize = (Get-Item $setupPath).Length
        Write-Host ("Setup.exe 大小: {0:N1} MB" -f ($setupSize / 1MB))
    }
}

Write-Host "编译 WinUI release …"
Set-Location $Root
dotnet publish $Project -c Release -r win-x64 --self-contained true -o $OutDir
if ($LASTEXITCODE -ne 0) {
    throw "dotnet publish failed"
}

Write-Host "写入 bundle 标记 …"
Set-Content -Path (Join-Path $OutDir "bundle-variant.txt") -Value $Variant -Encoding UTF8 -NoNewline
Copy-Item -Path $Seed -Destination (Join-Path $OutDir "bundle-seed.env") -Force

if ($Variant -eq "local" -or $env:BUNDLE_DEMO_SECRETS -eq "1") {
    Append-BundleEnvSecrets -DestPath (Join-Path $OutDir "bundle-seed.env") -RepoRoot $RepoRoot
}

Write-Host "复制 Python server …"
Copy-TreeFiltered -Source (Join-Path $RepoRoot "server") -Destination (Join-Path $OutDir "server")
Copy-Item -Path $Requirements -Destination (Join-Path $OutDir "requirements.txt") -Force
Copy-Item -Path (Join-Path $Scripts "run-server.ps1") -Destination (Join-Path $OutDir "run-server.ps1") -Force

$BundledVenv = Join-Path $OutDir "python-venv"
$RepoVenvPython = Join-Path $RepoRoot ".venv\Scripts\python.exe"

if ($SkipVenv) {
    Write-Host "SKIP_VENV=1 — 跳过 venv（包无法独立运行）"
}
else {
    Write-Host "创建内置 Python 环境 ($Variant) …"
    if ($CopyVenv -eq "1" -and (Test-Path $RepoVenvPython)) {
        Write-Host "复用仓库 .venv → python-venv（跳过 pip 下载，推荐）"
        Copy-TreeFiltered -Source (Join-Path $RepoRoot ".venv") -Destination $BundledVenv
    }
    else {
        if (Test-Path $BundledVenv) {
            Remove-Item -Recurse -Force $BundledVenv
        }
        $launcher = Resolve-PythonLauncher
        $createArgs = @($launcher.Args + @("-m", "venv", $BundledVenv)) | Where-Object { $_ }
        & $launcher.Path @createArgs
        if ($LASTEXITCODE -ne 0) {
            throw "python -m venv failed"
        }
        $venvPython = Join-Path $BundledVenv "Scripts\python.exe"
        Install-PipWithRetry -VenvPython $venvPython -RequirementsFile (Join-Path $OutDir "requirements.txt")
    }

    # Python 3.14 venv may include a Unicode alias (e.g. 𝜋thon.exe) that breaks some zip tools
    $scriptsDir = Join-Path $BundledVenv "Scripts"
    if (Test-Path $scriptsDir) {
        Get-ChildItem -LiteralPath $scriptsDir -File | ForEach-Object {
            if ($_.Name -match '[^\x21-\x7E]') {
                Write-Host "Removing non-ASCII venv entry: $($_.Name)"
                Remove-Item -LiteralPath $_.FullName -Force
            }
        }
    }
}

if ($Variant -eq "local" -and -not $SkipVenv -and -not $SkipModels) {
    $ModelsDir = Join-Path $OutDir "bundled-models"
    New-Item -ItemType Directory -Force -Path $ModelsDir | Out-Null

    $modelsSource = $env:VOICEBRIDGE_MODELS_SOURCE
    $whisperMarker = if ($modelsSource) { Join-Path $modelsSource "whisper\.installed-tiny.en" } else { $null }

    if ($modelsSource -and (Test-Path $whisperMarker)) {
        Write-Host "复制已有本地模型: $modelsSource → bundled-models"
        Copy-TreeFiltered -Source $modelsSource -Destination $ModelsDir
        $argosSource = if ($env:ARGOS_PACKAGES_SOURCE) {
            $env:ARGOS_PACKAGES_SOURCE
        }
        else {
            Join-Path $env:USERPROFILE ".local\share\argos-translate\packages"
        }
        if (Test-Path $argosSource) {
            $destPkg = Join-Path $ModelsDir "argos\packages"
            New-Item -ItemType Directory -Force -Path $destPkg | Out-Null
            Copy-TreeFiltered -Source $argosSource -Destination $destPkg
        }
    }
    else {
        Write-Host "下载内置模型（Whisper tiny.en + Argos en→zh，需网络，约 3–10 分钟）…"
        $venvPython = Join-Path $BundledVenv "Scripts\python.exe"
        $env:VOICEBRIDGE_MODELS_DIR = $ModelsDir
        Push-Location (Join-Path $RepoRoot "server")
        try {
            & $venvPython (Join-Path $Scripts "prepare-bundled-models.py")
            if ($LASTEXITCODE -ne 0) {
                throw "prepare-bundled-models.py failed"
            }
        }
        finally {
            Pop-Location
        }
    }

    Test-BundledModels -ModelsDir $ModelsDir
}

Get-ChildItem $OutDir -Recurse -File -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "已生成: $OutDir"
$size = (Get-ChildItem $OutDir -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
if ($size) {
    Write-Host ("大小: {0:N1} MB" -f ($size / 1MB))
}

if (-not $SkipZip) {
    $ZipPath = Join-Path $DistDir "$AppName.zip"
    if (Test-Path $ZipPath) {
        Remove-Item -Force $ZipPath
    }
    Write-Host "打包 zip: $ZipPath"
    Compress-Archive -Path $OutDir -DestinationPath $ZipPath -CompressionLevel Optimal
    $zipSize = (Get-Item $ZipPath).Length
    Write-Host ("zip 大小: {0:N1} MB" -f ($zipSize / 1MB))
}

$displayName = switch ($Variant) {
    "cloud" { "VoiceBridgeAI（云端）" }
    "local" { "VoiceBridgeAI（本地）" }
    default { $AppName }
}

if ($Setup) {
    Build-InnoSetup -AppName $AppName -AppDisplayName $displayName -SourceDir $OutDir -DistDir $DistDir
}

Write-Host ""
switch ($Variant) {
    "cloud" {
        Write-Host "云端版 — 用户需："
        if ($Setup) {
            Write-Host "  1. 运行 $AppName-Setup.exe 安装"
        }
        else {
            Write-Host "  1. 解压 $AppName.zip 到任意目录"
        }
        Write-Host "  2. 运行 VoiceBridgeAI.exe → 设置 → 填写云端 API 密钥"
        Write-Host "  3. 开始悬浮字幕"
    }
    "local" {
        Write-Host "本地版 — 用户需："
        if ($Setup) {
            Write-Host "  1. 运行 $AppName-Setup.exe 安装"
        }
        else {
            Write-Host "  1. 解压 $AppName.zip 到任意目录"
        }
        Write-Host "  2. 运行 VoiceBridgeAI.exe → 直接开始悬浮字幕"
    }
}
Write-Host ""
Write-Host "配置目录: $env:APPDATA\$AppName\"
Write-Host "侧车日志: $env:APPDATA\$AppName\server.log"
