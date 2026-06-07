using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using System.Text.Json;

namespace VoiceBridgeAI.Settings;

public sealed partial class SettingsWindow : Window
{
    private JsonDocument? _healthDoc;
    private EngineConfig _engine = new();
    private bool _loaded;

    public SettingsWindow()
    {
        InitializeComponent();
        Title = "VoiceBridgeAI 设置" + BundleVariant.DisplaySuffix;
        Activated += OnActivated;
    }

    private async void OnActivated(object sender, WindowActivatedEventArgs args)
    {
        if (_loaded && args.WindowActivationState != WindowActivationState.Deactivated)
        {
            return;
        }

        await ReloadAsync();
    }

    public async Task ReloadAsync()
    {
        SaveButton.IsEnabled = false;
        ShowStatus("正在加载…", StatusKind.Info);

        try
        {
            await SettingsStore.Shared.RefreshAsync();
            _healthDoc?.Dispose();
            _healthDoc = JsonDocument.Parse(SettingsStore.Shared.Health.GetRawText());
            _engine = Clone(SettingsStore.Shared.Engine);
            PopulateCombos();
            ShowStatus(null, StatusKind.Info);
            _loaded = true;
        }
        catch (Exception ex)
        {
            ShowStatus($"无法加载设置：{ex.Message}", StatusKind.Error);
        }
        finally
        {
            SaveButton.IsEnabled = true;
        }
    }

    private void PopulateCombos()
    {
        if (_healthDoc is null)
        {
            return;
        }

        var health = _healthDoc.RootElement;
        FillCombo(AsrCombo, ProviderOption.List(health, "asrModes"), _engine.AsrProvider);
        FillCombo(PartialCombo, ProviderOption.List(health, "partialProviders"), _engine.PartialProvider);
        FillCombo(FinalCombo, ProviderOption.List(health, "finalProviders"), _engine.FinalProvider);
        FillCombo(ReviseCombo, ProviderOption.List(health, "reviseModes"), _engine.ReviseMode);
    }

    private static void FillCombo(ComboBox combo, IReadOnlyList<ProviderOption> options, string selectedId)
    {
        combo.Items.Clear();
        var selectIndex = 0;
        for (var i = 0; i < options.Count; i++)
        {
            var opt = options[i];
            combo.Items.Add(new ComboBoxItem { Content = opt.Label, Tag = opt.Id });
            if (opt.Id == selectedId)
            {
                selectIndex = i;
            }
        }

        if (combo.Items.Count > 0)
        {
            combo.SelectedIndex = selectIndex;
        }
    }

    private static string SelectedId(ComboBox combo)
    {
        if (combo.SelectedItem is ComboBoxItem item && item.Tag is string id)
        {
            return id;
        }

        return "";
    }

    private async void SaveClicked(object sender, RoutedEventArgs e)
    {
        _engine.AsrProvider = SelectedId(AsrCombo);
        _engine.PartialProvider = SelectedId(PartialCombo);
        _engine.FinalProvider = SelectedId(FinalCombo);
        _engine.ReviseMode = SelectedId(ReviseCombo);

        SaveButton.IsEnabled = false;
        ShowStatus("正在保存…", StatusKind.Info);

        try
        {
            var message = await SettingsStore.Shared.SaveEngineAsync(_engine);
            _healthDoc?.Dispose();
            _healthDoc = JsonDocument.Parse(SettingsStore.Shared.Health.GetRawText());
            _engine = Clone(SettingsStore.Shared.Engine);
            PopulateCombos();
            ShowStatus(message, StatusKind.Success);
        }
        catch (Exception ex)
        {
            ShowStatus($"保存失败：{ex.Message}", StatusKind.Error);
        }
        finally
        {
            SaveButton.IsEnabled = true;
        }
    }

    private async void ReloadClicked(object sender, RoutedEventArgs e)
    {
        await ReloadAsync();
    }

    private void ShowStatus(string? message, StatusKind kind)
    {
        if (string.IsNullOrWhiteSpace(message))
        {
            StatusPanel.Visibility = Visibility.Collapsed;
            StatusText.Text = "";
            return;
        }

        StatusText.Text = message;
        StatusPanel.Visibility = Visibility.Visible;
        StatusText.Foreground = kind switch
        {
            StatusKind.Success => new SolidColorBrush(Microsoft.UI.Colors.ForestGreen),
            StatusKind.Error => new SolidColorBrush(Microsoft.UI.Colors.IndianRed),
            _ => (Brush)Application.Current.Resources["TextFillColorSecondaryBrush"],
        };
    }

    private static EngineConfig Clone(EngineConfig source) => new()
    {
        InputMode = source.InputMode,
        AsrProvider = source.AsrProvider,
        PartialProvider = source.PartialProvider,
        FinalProvider = source.FinalProvider,
        ReviseMode = source.ReviseMode,
        SampleRate = source.SampleRate,
    };

    private enum StatusKind
    {
        Info,
        Success,
        Error,
    }
}
