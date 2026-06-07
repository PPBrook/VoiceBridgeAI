# 打包时将仓库根目录 .env 中的云端密钥合并进 bundle-seed.env（镜像 macOS merge-demo-secrets.sh）

function Append-BundleEnvSecrets {
    param(
        [Parameter(Mandatory = $true)][string]$DestPath,
        [Parameter(Mandatory = $true)][string]$RepoRoot
    )

    if ($env:BUNDLE_SECRETS_FILE -and (Test-Path $env:BUNDLE_SECRETS_FILE)) {
        Add-Content -Path $DestPath -Value @("", "# --- bundled credentials (BUNDLE_SECRETS_FILE) ---")
        Get-Content $env:BUNDLE_SECRETS_FILE | Add-Content -Path $DestPath
        Write-Host "已合并 BUNDLE_SECRETS_FILE: $($env:BUNDLE_SECRETS_FILE)"
        return
    }

    if ($env:BUNDLE_SECRETS_FROM_REPO_ENV -eq "0") {
        Write-Host "提示: BUNDLE_SECRETS_FROM_REPO_ENV=0，未合并云端密钥"
        return
    }

    $envFile = Join-Path $RepoRoot ".env"
    if (-not (Test-Path $envFile)) {
        Write-Host "提示: 未合并云端密钥（仓库根目录无 .env）"
        return
    }

    $pattern = '^(TENCENT_|OPENAI_|QINIU_|ALIYUN_|DEEPSEEK_|DEEPL_|BAIDU_|GOOGLE_)'
    $extracted = Get-Content $envFile | Where-Object {
        $_ -match $pattern -and $_ -notmatch '^\s*#'
    }
    if (-not $extracted) {
        Write-Host "提示: .env 中未找到云端密钥行（TENCENT_/OPENAI_/…）"
        return
    }

    Add-Content -Path $DestPath -Value @("", "# --- from repo .env at build time ---")
    $extracted | Add-Content -Path $DestPath
    Write-Host "已从仓库 .env 合并云端密钥"
}

function Test-BundledModels {
    param([Parameter(Mandatory = $true)][string]$ModelsDir)

    $ok = $true
    $whisperMarker = Join-Path $ModelsDir "whisper\.installed-tiny.en"
    $argosMarker = Join-Path $ModelsDir "argos\.installed-en-zh"
    $hub = Join-Path $ModelsDir "hf\hub"
    $pkg = Join-Path $ModelsDir "argos\packages"

    if (-not (Test-Path $whisperMarker)) {
        Write-Error "缺少 Whisper 标记 $whisperMarker"
        $ok = $false
    }
    if (-not (Test-Path $argosMarker)) {
        Write-Error "缺少 Argos 标记 $argosMarker"
        $ok = $false
    }
    if (-not (Test-Path $hub) -or -not (Get-ChildItem $hub -ErrorAction SilentlyContinue)) {
        Write-Error "Whisper HF 缓存为空 ($hub)"
        $ok = $false
    }
    if (-not (Test-Path $pkg) -or -not (Get-ChildItem $pkg -ErrorAction SilentlyContinue)) {
        Write-Error "Argos 语言包为空 ($pkg)"
        $ok = $false
    }

    if (-not $ok) {
        throw "本地模型未完整打入包。可设置 VOICEBRIDGE_MODELS_SOURCE 或检查网络后重试。"
    }
    Write-Host "已验证内置模型: Whisper tiny.en + Argos en→zh"
}
