using VoiceBridgeAI.Session;

namespace VoiceBridgeAI;

public sealed class TrayController : IDisposable
{
    private const int MenuShow = 1;
    private const int MenuToggleSession = 2;
    private const int MenuEngine = 3;
    private const int MenuOpenTranscripts = 5;
    private const int MenuSettings = 6;
    private const int MenuQuit = 7;

    private readonly Tray.NativeTrayIcon _icon;
    private readonly Action _showMainWindow;
    private readonly Action _showSettings;
    private readonly Action _quit;
    private bool _engineRunning;

    public TrayController(Action showMainWindow, Action showSettings, Action quit)
    {
        _showMainWindow = showMainWindow;
        _showSettings = showSettings;
        _quit = quit;

        _icon = new Tray.NativeTrayIcon(_showMainWindow, BuildMenuItems);
        try
        {
            _icon.Show("VoiceBridgeAI");
        }
        catch (Exception ex)
        {
            throw new InvalidOperationException($"托盘图标不可用: {ex.Message}", ex);
        }
    }

    public void SetEngineRunning(bool running)
    {
        _engineRunning = running;
        UpdateTooltip();
    }

    public void RefreshMenu()
    {
        UpdateTooltip();
    }

    private IReadOnlyList<Tray.NativeTrayIcon.TrayMenuItem> BuildMenuItems()
    {
        var session = SessionController.Shared;
        var items = new List<Tray.NativeTrayIcon.TrayMenuItem>
        {
            new(MenuShow, "显示主窗口", _showMainWindow),
            Tray.NativeTrayIcon.TrayMenuItem.Separator(),
        };

        var toggleTitle = session.IsRunning
            ? "停止悬浮字幕"
            : session.IsStarting
                ? "正在启动…"
                : "开始悬浮字幕";

        items.Add(new Tray.NativeTrayIcon.TrayMenuItem(
            MenuToggleSession,
            toggleTitle,
            () => _ = ToggleSessionAsync(),
            !session.IsStarting));

        items.Add(Tray.NativeTrayIcon.TrayMenuItem.Separator());

        var engineLabel = _engineRunning ? "引擎运行中" : "启动引擎";
        items.Add(new Tray.NativeTrayIcon.TrayMenuItem(
            MenuEngine,
            engineLabel,
            () => _ = StartEngineAsync(),
            !_engineRunning));

        items.Add(Tray.NativeTrayIcon.TrayMenuItem.Separator());
        items.Add(new Tray.NativeTrayIcon.TrayMenuItem(
            MenuOpenTranscripts,
            "打开字幕记录…",
            () => TranslationRecorder.Shared.OpenTranscriptsDirectory()));
        items.Add(new Tray.NativeTrayIcon.TrayMenuItem(MenuSettings, "设置…", _showSettings));

        items.Add(Tray.NativeTrayIcon.TrayMenuItem.Separator());
        items.Add(new Tray.NativeTrayIcon.TrayMenuItem(MenuQuit, "退出 VoiceBridgeAI", _quit));
        return items;
    }

    private async Task ToggleSessionAsync()
    {
        var session = SessionController.Shared;
        if (session.IsStarting)
        {
            return;
        }

        if (session.IsRunning)
        {
            session.Stop();
        }
        else
        {
            var err = await session.StartAsync();
            if (err is not null)
            {
                App.CurrentApp?.ShowMainWindow(err);
            }
        }

        UpdateTooltip();
    }

    private async Task StartEngineAsync()
    {
        if (_engineRunning)
        {
            _showMainWindow();
            return;
        }

        var err = await ServerManager.Shared.EnsureRunningAsync();
        var running = await ServerManager.Shared.PingAsync();
        SetEngineRunning(running);
        if (err is not null)
        {
            App.CurrentApp?.ShowMainWindow(err);
        }
    }

    private void UpdateTooltip()
    {
        var session = SessionController.Shared;
        var text = session.IsRunning
            ? "VoiceBridgeAI · 字幕运行中"
            : _engineRunning
                ? "VoiceBridgeAI · 引擎运行中"
                : "VoiceBridgeAI";
        _icon.UpdateTooltip(text);
    }

    public void Dispose()
    {
        _icon.Dispose();
    }
}
