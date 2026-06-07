using System.Drawing;
using System.Windows.Forms;
using VoiceBridgeAI.Session;

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

        RefreshMenu();
        _icon.DoubleClick += (_, _) => _showMainWindow();
    }

    public void SetEngineRunning(bool running)
    {
        _engineRunning = running;
        UpdateTooltip();
        RefreshMenu();
    }

    public void RefreshMenu()
    {
        var session = SessionController.Shared;
        var menu = new ContextMenuStrip();

        menu.Items.Add("显示主窗口", null, (_, _) => _showMainWindow());
        menu.Items.Add(new ToolStripSeparator());

        string toggleTitle;
        if (session.IsRunning)
        {
            toggleTitle = "停止悬浮字幕";
        }
        else if (session.IsStarting)
        {
            toggleTitle = "正在启动…";
        }
        else
        {
            toggleTitle = "开始悬浮字幕";
        }

        var toggleItem = menu.Items.Add(toggleTitle, null, async (_, _) =>
        {
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
                    _showMainWindow();
                }
            }

            RefreshMenu();
        });
        toggleItem.Enabled = !session.IsStarting;

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
        UpdateTooltip();
    }

    private void UpdateTooltip()
    {
        var session = SessionController.Shared;
        if (session.IsRunning)
        {
            _icon.Text = "VoiceBridgeAI · 字幕运行中";
        }
        else if (_engineRunning)
        {
            _icon.Text = "VoiceBridgeAI · 引擎运行中";
        }
        else
        {
            _icon.Text = "VoiceBridgeAI";
        }
    }

    public void Dispose()
    {
        _icon.Visible = false;
        _icon.Dispose();
    }
}
