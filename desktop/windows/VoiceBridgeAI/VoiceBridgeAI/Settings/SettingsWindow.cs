using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using System.Text.Json;

namespace VoiceBridgeAI.Settings;

public sealed class SettingsWindow : Window
{
    private readonly ComboBox _asrCombo = new() { HorizontalAlignment = HorizontalAlignment.Stretch };
    private readonly ComboBox _partialCombo = new() { HorizontalAlignment = HorizontalAlignment.Stretch };
    private readonly ComboBox _finalCombo = new() { HorizontalAlignment = HorizontalAlignment.Stretch };
    private readonly ComboBox _reviseCombo = new() { HorizontalAlignment = HorizontalAlignment.Stretch };
    private readonly Button _saveButton = new() { Content = "保存引擎", MinWidth = 120 };
    private readonly TextBlock _statusText = new() { TextWrapping = TextWrapping.WrapWholeWords };
    private readonly Border _statusPanel = new()
    {
        Padding = new Thickness(12, 8, 12, 8),
        Visibility = Visibility.Collapsed,
    };

    private readonly CloudSettingsPanel _cloudPanel = new();
    private readonly TranscriptSettingsPanel _transcriptPanel = new();
    private readonly LocalModelsSettingsPanel? _localModelsPanel = BundleVariant.IncludesLocalModels ? new() : null;
    private JsonDocument? _healthDoc;
    private EngineConfig _engine = new();
    private bool _loaded;

    public SettingsWindow()
    {
        Title = "VoiceBridgeAI 设置" + BundleVariant.DisplaySuffix;
        Content = BuildContent();
        Activated += OnActivated;
    }

    private UIElement BuildContent()
    {
        var root = new Grid { Padding = new Thickness(28, 24, 28, 24) };
        root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        root.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });

        var header = new StackPanel { Spacing = 4, Margin = new Thickness(0, 0, 0, 12) };
        header.Children.Add(new TextBlock { Text = "VoiceBridgeAI 设置", FontSize = 22, FontWeight = Microsoft.UI.Text.FontWeights.SemiBold });
        header.Children.Add(new TextBlock
        {
            Text = "引擎 / 本地模型 / 字幕记录 / 接口密钥 — 各 Tab 对应 macOS 设置面板。",
            TextWrapping = TextWrapping.WrapWholeWords,
            Opacity = 0.8,
        });
        Grid.SetRow(header, 0);
        root.Children.Add(header);

        var tabs = new TabView { HorizontalAlignment = HorizontalAlignment.Stretch };
        tabs.TabItems.Add(new TabViewItem
        {
            Header = "引擎",
            Content = BuildEngineTab(),
            IsSelected = true,
        });
        if (_localModelsPanel is not null)
        {
            _localModelsPanel.OnEngineRefreshNeeded = RefreshEngineFromStore;
            tabs.TabItems.Add(new TabViewItem
            {
                Header = "本地模型",
                Content = _localModelsPanel.Root,
            });
        }
        tabs.TabItems.Add(new TabViewItem
        {
            Header = "字幕记录",
            Content = _transcriptPanel.Root,
        });
        tabs.TabItems.Add(new TabViewItem
        {
            Header = "接口密钥",
            Content = _cloudPanel.Root,
        });
        Grid.SetRow(tabs, 1);
        root.Children.Add(tabs);

        return root;
    }

    private UIElement BuildEngineTab()
    {
        var root = new Grid();
        root.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
        root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });

        var scroll = new ScrollViewer { VerticalScrollBarVisibility = ScrollBarVisibility.Auto };
        var form = new StackPanel { Spacing = 16 };
        form.Children.Add(MakeField("语音识别", null, _asrCombo));
        form.Children.Add(MakeField("句中翻译", "推荐 MT · 实时句中翻译", _partialCombo));
        form.Children.Add(MakeField("句末润色", "推荐 LLM · 句末润色与断句", _finalCombo));
        form.Children.Add(MakeField("观看场景", null, _reviseCombo));
        scroll.Content = form;
        Grid.SetRow(scroll, 0);
        root.Children.Add(scroll);

        var footer = new StackPanel { Spacing = 10, Margin = new Thickness(0, 16, 0, 0) };
        var buttons = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8 };
        _saveButton.Click += SaveClicked;
        buttons.Children.Add(_saveButton);
        var reloadButton = new Button { Content = "重新加载" };
        reloadButton.Click += ReloadClicked;
        buttons.Children.Add(reloadButton);
        footer.Children.Add(buttons);
        _statusPanel.Child = _statusText;
        footer.Children.Add(_statusPanel);
        Grid.SetRow(footer, 1);
        root.Children.Add(footer);

        return root;
    }

    private static StackPanel MakeField(string title, string? hint, ComboBox combo)
    {
        var panel = new StackPanel { Spacing = 6 };
        panel.Children.Add(new TextBlock { Text = title, FontWeight = Microsoft.UI.Text.FontWeights.SemiBold });
        if (!string.IsNullOrEmpty(hint))
        {
            panel.Children.Add(new TextBlock { Text = hint, FontSize = 11, Opacity = 0.8 });
        }

        panel.Children.Add(combo);
        return panel;
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
        _saveButton.IsEnabled = false;
        ShowStatus("正在加载…", StatusKind.Info);

        try
        {
            if (Content is FrameworkElement root)
            {
                if (_localModelsPanel is not null)
                {
                    _localModelsPanel.HostRoot = root.XamlRoot;
                }

                _transcriptPanel.AttachHostWindow(this);
            }

            await SettingsStore.Shared.RefreshAsync();
            _healthDoc?.Dispose();
            _healthDoc = JsonDocument.Parse(SettingsStore.Shared.Health.GetRawText());
            _engine = Clone(SettingsStore.Shared.Engine);
            PopulateCombos();
            if (_localModelsPanel is not null)
            {
                await _localModelsPanel.ReloadAsync();
            }

            _transcriptPanel.Reload();
            await _cloudPanel.ReloadAsync();
            ShowStatus(null, StatusKind.Info);
            _loaded = true;
        }
        catch (Exception ex)
        {
            ShowStatus($"无法加载设置：{ex.Message}", StatusKind.Error);
        }
        finally
        {
            _saveButton.IsEnabled = true;
        }
    }

    private void RefreshEngineFromStore()
    {
        try
        {
            _healthDoc?.Dispose();
            _healthDoc = JsonDocument.Parse(SettingsStore.Shared.Health.GetRawText());
            _engine = Clone(SettingsStore.Shared.Engine);
            PopulateCombos();
        }
        catch
        {
            // health already merged by local model actions
        }
    }

    private void PopulateCombos()
    {
        if (_healthDoc is null)
        {
            return;
        }

        var health = _healthDoc.RootElement;
        FillCombo(_asrCombo, ProviderOption.List(health, "asrModes"), _engine.AsrProvider);
        FillCombo(_partialCombo, ProviderOption.List(health, "partialProviders"), _engine.PartialProvider);
        FillCombo(_finalCombo, ProviderOption.List(health, "finalProviders"), _engine.FinalProvider);
        FillCombo(_reviseCombo, ProviderOption.List(health, "reviseModes"), _engine.ReviseMode);
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
        _engine.AsrProvider = SelectedId(_asrCombo);
        _engine.PartialProvider = SelectedId(_partialCombo);
        _engine.FinalProvider = SelectedId(_finalCombo);
        _engine.ReviseMode = SelectedId(_reviseCombo);

        _saveButton.IsEnabled = false;
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
            _saveButton.IsEnabled = true;
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
            _statusPanel.Visibility = Visibility.Collapsed;
            _statusText.Text = "";
            return;
        }

        _statusText.Text = message;
        _statusPanel.Visibility = Visibility.Visible;
        _statusText.Foreground = kind switch
        {
            StatusKind.Success => new SolidColorBrush(Microsoft.UI.Colors.ForestGreen),
            StatusKind.Error => new SolidColorBrush(Microsoft.UI.Colors.IndianRed),
            _ => new SolidColorBrush(Microsoft.UI.Colors.Gray),
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
