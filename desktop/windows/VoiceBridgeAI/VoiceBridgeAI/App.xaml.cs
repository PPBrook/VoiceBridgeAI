using Microsoft.UI.Xaml;

namespace VoiceBridgeAI;

public partial class App : Application
{
    public static App? CurrentApp { get; private set; }

    private TrayController? _tray;
    private MainWindow? _mainWindow;

    public App()
    {
        CurrentApp = this;
        InitializeComponent();
    }

    protected override void OnLaunched(LaunchActivatedEventArgs args)
    {
        _tray = new TrayController(ShowMainWindow, Quit);
        _mainWindow = new MainWindow(_tray);
        _mainWindow.Activate();

        _ = _mainWindow.RefreshEngineStatusAsync();
    }

    public void ShowMainWindow()
    {
        if (_mainWindow is null)
        {
            _mainWindow = new MainWindow(_tray!);
        }

        _mainWindow.Activate();
    }

    private void Quit()
    {
        ServerManager.Shared.StopIfOwned();
        _tray?.Dispose();
        _mainWindow?.CloseApp();
        Exit();
    }
}
