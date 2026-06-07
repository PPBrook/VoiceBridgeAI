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

    public App()
    {
        CurrentApp = this;
        InitializeComponent();
    }

    protected override void OnLaunched(LaunchActivatedEventArgs args)
    {
        _overlay = new OverlayWindow();
        SessionController.Shared.StateChanged += OnSessionStateChanged;
        SessionController.Shared.Store.Changed += OnSubtitleChanged;

        _tray = new TrayController(ShowMainWindow, Quit);
        _mainWindow = new MainWindow(_tray);
        _mainWindow.Activate();

        _ = _mainWindow.RefreshEngineStatusAsync();
    }

    private void OnSessionStateChanged()
    {
        _tray?.RefreshMenu();
        _overlay?.Update(SessionController.Shared.Store);
    }

    private void OnSubtitleChanged()
    {
        _overlay?.Update(SessionController.Shared.Store);
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
        SessionController.Shared.Stop();
        ServerManager.Shared.StopIfOwned();
        _tray?.Dispose();
        _mainWindow?.CloseApp();
        Exit();
    }
}
