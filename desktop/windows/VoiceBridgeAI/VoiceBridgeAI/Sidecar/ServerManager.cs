using System.Diagnostics;
using System.Net.Http;
using System.Text.Json;

namespace VoiceBridgeAI;

public sealed class ServerManager
{
    public static ServerManager Shared { get; } = new();

    private readonly HttpClient _http = new() { Timeout = TimeSpan.FromSeconds(2) };
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
                · 若使用安装包：请重新运行 build-app.ps1 完整打包（含 Python 环境）
                · 若开发模式：设置 VOICEBRIDGE_ROOT 指向含 run.ps1 的仓库根
                """;
        }

        var startInfo = new ProcessStartInfo
        {
            FileName = plan.Executable,
            WorkingDirectory = plan.WorkingDirectory,
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
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

        for (var i = 0; i < 120; i++)
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
        }
        else if (exitCode.HasValue)
        {
            lines.Add($"引擎侧车启动失败（退出码 {exitCode}）。");
        }

        if (exitCode == 1)
        {
            lines.Add($"· 端口 {port} 可能被占用");
        }

        if (plan.ModeLabel == "bundled")
        {
            lines.Add($"· 查看日志：{AppSupport.ServerLogPath}");
            lines.Add("· 可尝试删除后重启 App，或重新 build-app.ps1 打包");
        }
        else
        {
            lines.Add("· 在仓库根目录手动 .\\run.ps1 查看错误");
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
            // Best effort on shutdown.
        }

        _process = null;
    }
}
