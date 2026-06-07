using Microsoft.UI.Dispatching;
using Microsoft.UI.Xaml;
using VoiceBridgeAI.Overlay;
using VoiceBridgeAI.Session;

namespace VoiceBridgeAI;

public partial class App : Application
{
    public static App? CurrentApp { get; private set; }

    private TrayController? _tray;
    private MainWindow? _mainWindow;
    private OverlayWindow? _overlay;
    private Settings.SettingsWindow? _settingsWindow;

    public App()
    {
        CurrentApp = this;
        InitializeComponent();
        UnhandledException += (_, args) =>
        {
            StartupDiagnostics.Log("未处理异常", args.Exception);
            args.Handled = true;
        };
    }

    protected override void OnLaunched(LaunchActivatedEventArgs args)
    {
        try
        {
            EnsureUiSynchronizationContext();

            SessionController.Shared.StateChanged += OnSessionStateChanged;
            SessionController.Shared.Store.Changed += OnSubtitleChanged;

            _mainWindow = new MainWindow(null);
            _mainWindow.Activate();

            try
            {
                _tray = new TrayController(() => ShowMainWindow(), ShowSettingsWindow, Quit);
                _mainWindow.AttachTray(_tray);
            }
            catch (Exception ex)
            {
                StartupDiagnostics.Log("托盘图标初始化失败（可继续使用主窗口）", ex);
            }

            _ = _mainWindow.RefreshEngineStatusAsync();
        }
        catch (Exception ex)
        {
            StartupDiagnostics.Log("OnLaunched", ex);
            throw;
        }
    }

    private static void EnsureUiSynchronizationContext()
    {
        var queue = DispatcherQueue.GetForCurrentThread();
        if (queue is null)
        {
            return;
        }

        SynchronizationContext.SetSynchronizationContext(new DispatcherQueueSynchronizationContext(queue));
    }

    private void EnsureOverlay()
    {
        _overlay ??= new OverlayWindow();
    }

    private void OnSessionStateChanged()
    {
        _tray?.RefreshMenu();
        if (SessionController.Shared.Store.IsVisible)
        {
            EnsureOverlay();
        }

        _overlay?.Update(SessionController.Shared.Store);
    }

    private void OnSubtitleChanged()
    {
        if (SessionController.Shared.Store.IsVisible)
        {
            EnsureOverlay();
        }

        _overlay?.Update(SessionController.Shared.Store);
    }

    public void ShowMainWindow(string? errorMessage = null)
    {
        if (_mainWindow is null)
        {
            _mainWindow = new MainWindow(_tray);
        }

        _mainWindow.Activate();
        if (!string.IsNullOrWhiteSpace(errorMessage))
        {
            _mainWindow.ShowError(errorMessage);
        }
    }

    public void ShowSettingsWindow()
    {
        if (_settingsWindow is null)
        {
            _settingsWindow = new Settings.SettingsWindow();
            _settingsWindow.Closed += (_, _) => _settingsWindow = null;
        }

        _settingsWindow.Activate();
    }

    private void Quit()
    {
        SessionController.Shared.Stop();
        ServerManager.Shared.StopIfOwned();
        _tray?.Dispose();
        _mainWindow?.CloseApp();
        Exit();
    }
}
