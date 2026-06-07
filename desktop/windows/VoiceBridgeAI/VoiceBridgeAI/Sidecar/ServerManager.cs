using System.Diagnostics;
using System.Net.Http;
using System.Text.Json;

namespace VoiceBridgeAI;

public sealed class ServerManager
{
    public static ServerManager Shared { get; } = new();

    private readonly HttpClient _http = new() { Timeout = TimeSpan.FromSeconds(3) };
    private Process? _process;

    private ServerManager()
    {
    }

    public async Task<bool> PingAsync()
    {
        try
        {
            using var response = await _http.GetAsync(AppSettings.HealthUri);
            return response.IsSuccessStatusCode;
        }
        catch
        {
            return false;
        }
    }

    public async Task<JsonDocument?> GetHealthJsonAsync()
    {
        try
        {
            await using var stream = await _http.GetStreamAsync(AppSettings.HealthUri);
            return await JsonDocument.ParseAsync(stream);
        }
        catch
        {
            return null;
        }
    }

    public async Task<string?> EnsureRunningAsync()
    {
        if (await PingAsync())
        {
            return null;
        }

        var plan = SidecarLaunch.CreatePlan();
        if (plan is null)
        {
            return """
                无法启动引擎侧车。
                · 开发模式：在 PowerShell 运行一次：
                  cd <仓库根目录>
                  .\run.ps1
                  （Ctrl+C 停掉后再用 App「启动引擎」）
                · 或设置环境变量 VOICEBRIDGE_ROOT 指向仓库根目录
                """;
        }

        var startInfo = new ProcessStartInfo
        {
            FileName = plan.Executable,
            WorkingDirectory = plan.WorkingDirectory,
            UseShellExecute = false,
            CreateNoWindow = true,
        };

        foreach (var arg in plan.Arguments)
        {
            startInfo.ArgumentList.Add(arg);
        }

        foreach (var (key, value) in plan.Environment)
        {
            startInfo.Environment[key] = value;
        }

        try
        {
            _process = Process.Start(startInfo);
        }
        catch (Exception ex)
        {
            return $"启动引擎侧车失败：{ex.Message}";
        }

        if (_process is null)
        {
            return "启动引擎侧车失败：Process.Start 返回 null";
        }

        // First pip/venv setup can take several minutes
        for (var i = 0; i < 300; i++)
        {
            if (await PingAsync())
            {
                return null;
            }

            if (_process.HasExited)
            {
                var exitCode = _process.ExitCode;
                _process = null;
                if (await PingAsync())
                {
                    return null;
                }

                return StartupFailureMessage(exitCode, plan);
            }

            await Task.Delay(800);
        }

        return StartupFailureMessage(null, plan, timedOut: true);
    }

    private static string StartupFailureMessage(int? exitCode, SidecarLaunch.Plan plan, bool timedOut = false)
    {
        var port = AppSettings.Port;
        var lines = new List<string>();

        if (timedOut)
        {
            lines.Add($"引擎侧车启动超时（端口 {port}）。");
            lines.Add("· 首次启动需 pip 安装依赖，可在仓库根目录手动 .\\run.ps1 查看进度");
        }
        else if (exitCode.HasValue)
        {
            lines.Add($"引擎侧车启动失败（退出码 {exitCode}）。");
        }

        if (exitCode == 1)
        {
            lines.Add($"· 端口 {port} 可能被占用");
        }

        lines.Add("· 确认已安装 Python 3.10+ 并加入 PATH（或 py -3 可用）");

        if (plan.ModeLabel is "dev" or "dev-setup")
        {
            lines.Add("· 在仓库根目录手动 .\\run.ps1 查看错误");
            var logTail = SidecarLaunch.ReadBootstrapLogTail();
            if (!string.IsNullOrWhiteSpace(logTail))
            {
                lines.Add("· 最近日志 sidecar-bootstrap.log：");
                lines.Add(logTail);
            }
        }
        else
        {
            lines.Add($"· 查看日志：{AppSupport.ServerLogPath}");
        }

        return string.Join('\n', lines);
    }

    public void StopIfOwned()
    {
        if (_process is null || _process.HasExited)
        {
            _process = null;
            return;
        }

        try
        {
            _process.Kill(entireProcessTree: true);
        }
        catch
        {
        }

        _process = null;
    }
}
