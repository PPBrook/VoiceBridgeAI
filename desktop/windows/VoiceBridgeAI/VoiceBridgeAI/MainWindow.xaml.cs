using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using System.Text.Json;

namespace VoiceBridgeAI;

public sealed partial class MainWindow : Window
{
    private readonly TrayController? _tray;
    private readonly DispatcherTimer _pollTimer;
    private bool _refreshing;

    public MainWindow(TrayController? tray)
    {
        _tray = tray;
        InitializeComponent();

        Title = "VoiceBridgeAI" + BundleVariant.DisplaySuffix;

        _pollTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(4) };
        _pollTimer.Tick += async (_, _) => await RefreshEngineStatusAsync();
        _pollTimer.Start();

        Closed += (_, _) => _pollTimer.Stop();
    }

    public async Task RefreshEngineStatusAsync()
    {
        if (_refreshing)
        {
            return;
        }

        _refreshing = true;
        try
        {
            ClearError();
            var healthy = await ServerManager.Shared.PingAsync();
            if (healthy)
            {
                StatusText.Text = "引擎运行中";
                StartEngineButton.IsEnabled = false;
                _tray?.SetEngineRunning(true);
                await LoadHealthSummaryAsync();
                return;
            }

            StatusText.Text = "引擎未运行";
            EngineText.Text = "引擎：—";
            StartEngineButton.IsEnabled = true;
            _tray?.SetEngineRunning(false);
        }
        finally
        {
            _refreshing = false;
        }
    }

    private async Task LoadHealthSummaryAsync()
    {
        try
        {
            using var doc = await ServerManager.Shared.GetHealthJsonAsync();
            if (doc is null)
            {
                EngineText.Text = "引擎：已连接";
                return;
            }

            var root = doc.RootElement;
            var asr = root.TryGetProperty("asrProvider", out var asrEl) ? asrEl.GetString() : null;
            var partial = root.TryGetProperty("partialProvider", out var partialEl) ? partialEl.GetString() : null;
            var final = root.TryGetProperty("finalProvider", out var finalEl) ? finalEl.GetString() : null;
            EngineText.Text = $"引擎：ASR={asr ?? "—"} · 翻译={partial ?? "—"}/{final ?? "—"}";
        }
        catch
        {
            EngineText.Text = "引擎：已连接";
        }
    }

    private async void StartEngineClicked(object sender, RoutedEventArgs e)
    {
        StartEngineButton.IsEnabled = false;
        StatusText.Text = "正在启动引擎…";
        ClearError();

        var error = await ServerManager.Shared.EnsureRunningAsync();
        if (error is not null)
        {
            ShowError(error);
            StartEngineButton.IsEnabled = true;
            StatusText.Text = "引擎未运行";
            _tray?.SetEngineRunning(false);
            return;
        }

        await RefreshEngineStatusAsync();
    }

    private async void RefreshClicked(object sender, RoutedEventArgs e)
    {
        await RefreshEngineStatusAsync();
    }

    public void ShowError(string message)
    {
        ErrorText.Text = message;
        ErrorText.Visibility = Visibility.Visible;
    }

    private void ClearError()
    {
        ErrorText.Text = "";
        ErrorText.Visibility = Visibility.Collapsed;
    }

    public void CloseApp()
    {
        _pollTimer.Stop();
        Close();
    }
}
