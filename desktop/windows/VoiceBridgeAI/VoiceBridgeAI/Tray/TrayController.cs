using System.Drawing;
using System.Windows.Forms;

namespace VoiceBridgeAI;

public sealed class TrayController : IDisposable
{
    private readonly NotifyIcon _icon;
    private readonly Action _showMainWindow;
    private readonly Action _quit;
    private bool _engineRunning;

    public TrayController(Action showMainWindow, Action quit)
    {
        _showMainWindow = showMainWindow;
        _quit = quit;

        _icon = new NotifyIcon
        {
            Icon = SystemIcons.Application,
            Visible = true,
            Text = "VoiceBridgeAI",
        };

        RebuildMenu();
        _icon.DoubleClick += (_, _) => _showMainWindow();
    }

    public void SetEngineRunning(bool running)
    {
        if (_engineRunning == running)
        {
            return;
        }

        _engineRunning = running;
        _icon.Text = running ? "VoiceBridgeAI · 引擎运行中" : "VoiceBridgeAI";
        RebuildMenu();
    }

    private void RebuildMenu()
    {
        var menu = new ContextMenuStrip();

        menu.Items.Add("显示主窗口", null, (_, _) => _showMainWindow());
        menu.Items.Add(new ToolStripSeparator());

        var engineLabel = _engineRunning ? "引擎运行中" : "启动引擎";
        var engineItem = menu.Items.Add(engineLabel, null, async (_, _) =>
        {
            if (_engineRunning)
            {
                _showMainWindow();
                return;
            }

            _ = await ServerManager.Shared.EnsureRunningAsync();
            SetEngineRunning(await ServerManager.Shared.PingAsync());
        });
        engineItem.Enabled = !_engineRunning;

        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add("退出 VoiceBridgeAI", null, (_, _) => _quit());

        _icon.ContextMenuStrip = menu;
    }

    public void Dispose()
    {
        _icon.Visible = false;
        _icon.Dispose();
    }
}
