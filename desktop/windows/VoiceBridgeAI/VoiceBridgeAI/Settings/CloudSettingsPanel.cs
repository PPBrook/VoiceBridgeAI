using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using System.Text.Json;

namespace VoiceBridgeAI.Settings;

public sealed class CloudSettingsPanel
{
    private readonly CloudStore _store = new();
    private readonly CloudCredentialsForm _form = new();
    private readonly Dictionary<string, TextBlock> _testStatuses = new();
    private readonly HashSet<string> _inFlightTests = new(StringComparer.Ordinal);

    private readonly TextBox _tencentAppId = new();
    private readonly PasswordBox _tencentSecretId = new();
    private readonly PasswordBox _tencentSecretKey = new();
    private readonly TextBox _tencentEngine = new();
    private readonly TextBox _tencentRegion = new();
    private readonly TextBox _tencentProject = new();

    private readonly PasswordBox _qiniuKey = new();
    private readonly TextBox _qiniuBase = new();
    private readonly TextBox _qiniuModel = new();

    private readonly PasswordBox _aliyunKey = new();
    private readonly TextBox _aliyunBase = new();
    private readonly TextBox _aliyunModel = new();

    private readonly TextBox _baiduAppId = new();
    private readonly PasswordBox _baiduSecret = new();

    private readonly PasswordBox _deeplKey = new();

    private readonly PasswordBox _deepseekKey = new();
    private readonly TextBox _deepseekBase = new();
    private readonly TextBox _deepseekModel = new();

    private readonly PasswordBox _openaiKey = new();
    private readonly TextBox _openaiBase = new();
    private readonly TextBox _openaiModel = new();
    private readonly TextBox _openaiAsrModel = new();

    private readonly Button _saveButton = new() { Content = "保存配置", MinWidth = 120 };
    private readonly Button _testAllButton = new() { Content = "一键测试全部", MinWidth = 120 };
    private readonly TextBlock _statusText = new() { TextWrapping = TextWrapping.WrapWholeWords };
    private readonly Border _statusPanel = new()
    {
        Padding = new Thickness(12, 8, 12, 8),
        Visibility = Visibility.Collapsed,
    };

    public UIElement Root { get; }

    public CloudSettingsPanel()
    {
        Root = BuildContent();
    }

    public async Task ReloadAsync()
    {
        _saveButton.IsEnabled = false;
        ShowStatus("正在加载…", StatusKind.Info);
        try
        {
            await SettingsStore.Shared.RefreshAsync();
            _form.BindFrom(SettingsStore.Shared.Health);
            ApplyFormToFields();
            RefreshTestStatuses();
            ShowStatus(null, StatusKind.Info);
        }
        catch (Exception ex)
        {
            ShowStatus($"无法加载：{ex.Message}", StatusKind.Error);
        }
        finally
        {
            _saveButton.IsEnabled = true;
        }
    }

    private UIElement BuildContent()
    {
        var outer = new Grid();
        outer.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
        outer.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });

        var scroll = new ScrollViewer { VerticalScrollBarVisibility = ScrollBarVisibility.Auto };
        var stack = new StackPanel { Spacing = 16, Padding = new Thickness(0, 0, 4, 8) };

        stack.Children.Add(new TextBlock
        {
            Text = "填写云端 API 密钥。密钥留空表示不修改已有值；保存后写入 .env。",
            TextWrapping = TextWrapping.WrapWholeWords,
            Opacity = 0.8,
        });

        stack.Children.Add(MakeRegionHeader("国内接口"));
        foreach (var id in CloudProviderRegistry.DomesticOrder)
        {
            stack.Children.Add(BuildProviderSection(id));
        }

        stack.Children.Add(MakeRegionHeader("海外接口"));
        foreach (var id in CloudProviderRegistry.OverseasOrder)
        {
            stack.Children.Add(BuildProviderSection(id));
        }

        scroll.Content = stack;
        Grid.SetRow(scroll, 0);
        outer.Children.Add(scroll);

        var footer = new StackPanel { Spacing = 10, Margin = new Thickness(0, 12, 0, 0) };
        var buttons = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8 };
        _saveButton.Click += SaveClicked;
        _testAllButton.Click += TestAllClicked;
        buttons.Children.Add(_saveButton);
        buttons.Children.Add(_testAllButton);
        var reloadButton = new Button { Content = "重新加载" };
        reloadButton.Click += async (_, _) => await ReloadAsync();
        buttons.Children.Add(reloadButton);
        footer.Children.Add(buttons);
        _statusPanel.Child = _statusText;
        footer.Children.Add(_statusPanel);
        Grid.SetRow(footer, 1);
        outer.Children.Add(footer);

        return outer;
    }

    private UIElement BuildProviderSection(string providerId)
    {
        var card = new Border
        {
            BorderBrush = new SolidColorBrush(Microsoft.UI.Colors.Gray),
            BorderThickness = new Thickness(1),
            CornerRadius = new CornerRadius(8),
            Padding = new Thickness(14, 12, 14, 12),
        };

        var body = new StackPanel { Spacing = 10 };
        body.Children.Add(new TextBlock
        {
            Text = CloudProviderRegistry.TitleFor(providerId),
            FontWeight = Microsoft.UI.Text.FontWeights.SemiBold,
        });

        switch (providerId)
        {
            case "tencent":
                body.Children.Add(MakeField("AppId", _tencentAppId));
                body.Children.Add(MakeSecretField("SecretId", _tencentSecretId));
                body.Children.Add(MakeSecretField("SecretKey", _tencentSecretKey));
                body.Children.Add(MakeField("识别引擎", _tencentEngine, "16k_en"));
                body.Children.Add(MakeField("TMT 区域", _tencentRegion, "ap-guangzhou"));
                body.Children.Add(MakeField("Project", _tencentProject, "0"));
                break;
            case "qiniu":
                body.Children.Add(MakeSecretField("API Key", _qiniuKey));
                body.Children.Add(MakeField("Base URL", _qiniuBase, "https://api.qnaigc.com/v1"));
                body.Children.Add(MakeField("Model", _qiniuModel, "qwen-turbo"));
                break;
            case "aliyun":
                body.Children.Add(MakeSecretField("API Key", _aliyunKey));
                body.Children.Add(MakeField("Base URL", _aliyunBase));
                body.Children.Add(MakeField("Model", _aliyunModel, "qwen-turbo"));
                break;
            case "baidu":
                body.Children.Add(MakeField("AppId", _baiduAppId));
                body.Children.Add(MakeSecretField("Secret Key", _baiduSecret));
                break;
            case "deepseek":
                body.Children.Add(MakeSecretField("API Key", _deepseekKey));
                body.Children.Add(MakeField("Base URL", _deepseekBase, "https://api.deepseek.com/v1"));
                body.Children.Add(MakeField("Model", _deepseekModel, "deepseek-chat"));
                break;
            case "openai":
                body.Children.Add(MakeSecretField("API Key", _openaiKey));
                body.Children.Add(MakeField("Base URL", _openaiBase, "https://api.openai.com/v1"));
                body.Children.Add(MakeField("Chat Model", _openaiModel, "gpt-4o-mini"));
                body.Children.Add(MakeField("ASR Model", _openaiAsrModel, "whisper-1"));
                break;
            case "deepl":
                body.Children.Add(MakeSecretField("API Key", _deeplKey, "…:fx（免费版）"));
                break;
            case "google":
                body.Children.Add(new TextBlock
                {
                    Text = "无需密钥，需本机可访问 Google 翻译。",
                    FontSize = 12,
                    Opacity = 0.75,
                    TextWrapping = TextWrapping.WrapWholeWords,
                });
                break;
        }

        var tests = CloudProviderRegistry.TestsFor(providerId);
        if (tests.Count > 0)
        {
            body.Children.Add(new TextBlock
            {
                Text = "连接测试",
                FontSize = 11,
                FontWeight = Microsoft.UI.Text.FontWeights.SemiBold,
                Opacity = 0.75,
                Margin = new Thickness(0, 4, 0, 0),
            });

            foreach (var test in tests)
            {
                body.Children.Add(BuildTestRow(test));
            }
        }

        card.Child = body;
        return card;
    }

    private UIElement BuildTestRow(CloudProviderTest test)
    {
        var row = new Grid();
        row.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        row.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        row.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(140) });

        var label = new TextBlock
        {
            Text = test.Label,
            VerticalAlignment = VerticalAlignment.Center,
        };
        Grid.SetColumn(label, 0);
        row.Children.Add(label);

        var button = new Button { Content = "测试", MinWidth = 64 };
        button.Tag = test;
        button.Click += TestClicked;
        Grid.SetColumn(button, 1);
        row.Children.Add(button);

        var status = new TextBlock
        {
            Text = "未测试",
            FontSize = 11,
            Opacity = 0.8,
            TextWrapping = TextWrapping.WrapWholeWords,
            VerticalAlignment = VerticalAlignment.Center,
            Margin = new Thickness(8, 0, 0, 0),
        };
        _testStatuses[test.Key] = status;
        Grid.SetColumn(status, 2);
        row.Children.Add(status);

        return row;
    }

    private static TextBlock MakeRegionHeader(string title) => new()
    {
        Text = title,
        FontSize = 13,
        FontWeight = Microsoft.UI.Text.FontWeights.SemiBold,
        Opacity = 0.85,
        Margin = new Thickness(0, 8, 0, 0),
    };

    private static StackPanel MakeField(string label, TextBox box, string? placeholder = null)
    {
        if (!string.IsNullOrEmpty(placeholder))
        {
            box.PlaceholderText = placeholder;
        }

        box.HorizontalAlignment = HorizontalAlignment.Stretch;
        var panel = new StackPanel { Spacing = 4 };
        panel.Children.Add(new TextBlock { Text = label, FontSize = 12, Opacity = 0.85 });
        panel.Children.Add(box);
        return panel;
    }

    private static StackPanel MakeSecretField(string label, PasswordBox box, string? placeholder = null)
    {
        if (!string.IsNullOrEmpty(placeholder))
        {
            box.PlaceholderText = placeholder;
        }

        box.HorizontalAlignment = HorizontalAlignment.Stretch;
        var panel = new StackPanel { Spacing = 4 };
        panel.Children.Add(new TextBlock { Text = label, FontSize = 12, Opacity = 0.85 });
        panel.Children.Add(box);
        return panel;
    }

    private void ApplyFormToFields()
    {
        var health = SettingsStore.Shared.Health;

        _tencentAppId.Text = _form.TencentAppId;
        _tencentEngine.Text = _form.TencentEngine;
        _tencentRegion.Text = _form.TencentRegion;
        _tencentProject.Text = _form.TencentProject;
        SetSecretPlaceholder(_tencentSecretId, health, "tencent", "hasSecretId", "SecretId");
        SetSecretPlaceholder(_tencentSecretKey, health, "tencent", "hasSecretKey", "SecretKey");
        _tencentSecretId.Password = "";
        _tencentSecretKey.Password = "";

        _qiniuBase.Text = _form.QiniuBaseUrl;
        _qiniuModel.Text = _form.QiniuModel;
        SetSecretPlaceholder(_qiniuKey, health, "qiniu", "hasApiKey", "API Key");
        _qiniuKey.Password = "";

        _aliyunBase.Text = _form.AliyunBaseUrl;
        _aliyunModel.Text = _form.AliyunModel;
        SetSecretPlaceholder(_aliyunKey, health, "aliyun", "hasApiKey", "API Key");
        _aliyunKey.Password = "";

        _baiduAppId.Text = _form.BaiduAppId;
        SetSecretPlaceholder(_baiduSecret, health, "baidu", "hasSecretKey", "Secret Key");
        _baiduSecret.Password = "";

        SetSecretPlaceholder(_deeplKey, health, "deepl", "hasApiKey", "API Key");
        _deeplKey.Password = "";

        _deepseekBase.Text = _form.DeepseekBaseUrl;
        _deepseekModel.Text = _form.DeepseekModel;
        SetSecretPlaceholder(_deepseekKey, health, "deepseek", "hasApiKey", "API Key");
        _deepseekKey.Password = "";

        _openaiBase.Text = _form.OpenaiBaseUrl;
        _openaiModel.Text = _form.OpenaiModel;
        _openaiAsrModel.Text = _form.OpenaiAsrModel;
        SetSecretPlaceholder(_openaiKey, health, "openai", "hasApiKey", "API Key");
        _openaiKey.Password = "";
    }

    private static void SetSecretPlaceholder(PasswordBox box, JsonElement health, string provider, string flag, string label)
    {
        var configured = health.TryGetProperty(provider, out var section)
            && section.TryGetProperty(flag, out var flagEl)
            && flagEl.ValueKind == JsonValueKind.True;
        box.PlaceholderText = configured ? "已配置，留空不修改" : label;
    }

    private void ReadFieldsIntoForm()
    {
        _form.TencentAppId = _tencentAppId.Text;
        _form.TencentSecretId = _tencentSecretId.Password;
        _form.TencentSecretKey = _tencentSecretKey.Password;
        _form.TencentEngine = _tencentEngine.Text;
        _form.TencentRegion = _tencentRegion.Text;
        _form.TencentProject = _tencentProject.Text;

        _form.QiniuApiKey = _qiniuKey.Password;
        _form.QiniuBaseUrl = _qiniuBase.Text;
        _form.QiniuModel = _qiniuModel.Text;

        _form.AliyunApiKey = _aliyunKey.Password;
        _form.AliyunBaseUrl = _aliyunBase.Text;
        _form.AliyunModel = _aliyunModel.Text;

        _form.BaiduAppId = _baiduAppId.Text;
        _form.BaiduSecretKey = _baiduSecret.Password;

        _form.DeeplApiKey = _deeplKey.Password;

        _form.DeepseekApiKey = _deepseekKey.Password;
        _form.DeepseekBaseUrl = _deepseekBase.Text;
        _form.DeepseekModel = _deepseekModel.Text;

        _form.OpenaiApiKey = _openaiKey.Password;
        _form.OpenaiBaseUrl = _openaiBase.Text;
        _form.OpenaiModel = _openaiModel.Text;
        _form.OpenaiAsrModel = _openaiAsrModel.Text;
    }

    private async void SaveClicked(object sender, RoutedEventArgs e)
    {
        ReadFieldsIntoForm();
        if (_form.ToPayload().Count == 0)
        {
            ShowStatus("没有可保存的内容（请填写至少一项）", StatusKind.Error);
            return;
        }

        _saveButton.IsEnabled = false;
        ShowStatus("正在保存…", StatusKind.Info);
        try
        {
            var message = await _store.SaveAsync(_form);
            _form.ClearSecrets();
            await ReloadAsync();
            ShowStatus(message, StatusKind.Success);
        }
        catch (Exception ex)
        {
            ShowStatus(ex.Message, StatusKind.Error);
        }
        finally
        {
            _saveButton.IsEnabled = true;
        }
    }

    private async void TestAllClicked(object sender, RoutedEventArgs e)
    {
        ReadFieldsIntoForm();
        _testAllButton.IsEnabled = false;
        ShowStatus("正在测试全部接口…", StatusKind.Info);

        var serverErr = await ServerManager.Shared.EnsureRunningAsync();
        if (serverErr is not null)
        {
            ShowStatus(serverErr, StatusKind.Error);
            _testAllButton.IsEnabled = true;
            return;
        }

        var (summary, results) = await _store.TestAllAsync(_form);
        foreach (var (key, ok, message) in results)
        {
            SetTestStatus(key, ok, message);
        }

        RefreshTestStatuses();
        ShowStatus(summary, summary.Contains("失败", StringComparison.Ordinal) ? StatusKind.Error : StatusKind.Success);
        _testAllButton.IsEnabled = true;
    }

    private async void TestClicked(object sender, RoutedEventArgs e)
    {
        if (sender is not Button button || button.Tag is not CloudProviderTest test)
        {
            return;
        }

        if (_inFlightTests.Contains(test.Key))
        {
            return;
        }

        ReadFieldsIntoForm();
        _inFlightTests.Add(test.Key);
        SetTestStatus(test.Key, null, "测试中…");
        button.IsEnabled = false;

        var serverErr = await ServerManager.Shared.EnsureRunningAsync();
        if (serverErr is not null)
        {
            SetTestStatus(test.Key, false, serverErr);
            ShowStatus(serverErr, StatusKind.Error);
            _inFlightTests.Remove(test.Key);
            button.IsEnabled = true;
            return;
        }

        var (ok, message) = await _store.TestAsync(test.Layer, test.ProviderId, _form);
        SetTestStatus(test.Key, ok, message);
        if (!ok)
        {
            ShowStatus(message, StatusKind.Error);
        }

        _inFlightTests.Remove(test.Key);
        button.IsEnabled = true;
    }

    private void RefreshTestStatuses()
    {
        var health = SettingsStore.Shared.Health;
        foreach (var (key, label) in _testStatuses)
        {
            var parts = key.Split(':', 2);
            if (parts.Length != 2)
            {
                continue;
            }

            if (_inFlightTests.Contains(key))
            {
                continue;
            }

            if (CloudCredentialsForm.IsVerified(health, parts[0], parts[1]))
            {
                SetTestStatus(key, true, "已通过");
            }
        }
    }

    private void SetTestStatus(string key, bool? ok, string message)
    {
        if (!_testStatuses.TryGetValue(key, out var label))
        {
            return;
        }

        label.Text = message;
        label.Foreground = ok switch
        {
            true => new SolidColorBrush(Microsoft.UI.Colors.ForestGreen),
            false => new SolidColorBrush(Microsoft.UI.Colors.IndianRed),
            _ => new SolidColorBrush(Microsoft.UI.Colors.Gray),
        };
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

    private enum StatusKind
    {
        Info,
        Success,
        Error,
    }
}
