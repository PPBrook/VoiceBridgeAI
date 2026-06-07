using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using System.Text.Json;

namespace VoiceBridgeAI.Settings;

public sealed class LocalModelsSettingsPanel
{
    private enum RowAction
    {
        Download,
        SwitchModel,
        None,
    }

    private sealed class ModelRow
    {
        public required ToggleSwitch Toggle { get; init; }
        public required TextBlock Meta { get; init; }
        public required Button ActionButton { get; init; }
        public required Button DeleteButton { get; init; }
        public required ProgressBar ProgressBar { get; init; }
        public required TextBlock ActionStatus { get; init; }
        public RowAction PendingAction { get; set; } = RowAction.Download;
    }

    private readonly LocalModelStore _store = new();
    private readonly Dictionary<string, ModelRow> _modelRows = new();
    private readonly Dictionary<string, CancellationTokenSource> _downloadPolls = new();
    private readonly ComboBox _whisperModelCombo = new() { MinWidth = 200, HorizontalAlignment = HorizontalAlignment.Left };
    private readonly TextBlock _dirLabel = new() { FontSize = 10, Opacity = 0.65, TextWrapping = TextWrapping.WrapWholeWords };
    private readonly TextBlock _whisperDetailLabel = new() { FontSize = 10, Opacity = 0.8, TextWrapping = TextWrapping.WrapWholeWords };
    private readonly TextBlock _disabledNotice = new()
    {
        TextWrapping = TextWrapping.WrapWholeWords,
        Visibility = Visibility.Collapsed,
        Opacity = 0.85,
    };

    private bool _suppressToggle;
    private bool _suppressWhisperCombo;
    private string? _selectedWhisperBeforeReload;

    public UIElement Root { get; }
    public XamlRoot? HostRoot { get; set; }
    public Action? OnEngineRefreshNeeded { get; set; }

    public LocalModelsSettingsPanel()
    {
        Root = BuildContent();
    }

    public Task ReloadAsync()
    {
        _selectedWhisperBeforeReload = SelectedWhisperModel();
        var health = SettingsStore.Shared.Health;

        if (health.TryGetProperty("modelsDir", out var dirEl) && dirEl.ValueKind == JsonValueKind.String)
        {
            _dirLabel.Text = $"目录：{dirEl.GetString()}";
        }
        else
        {
            _dirLabel.Text = "目录：—";
        }

        var optional = LocalModelJson.ReadBool(health, "optionalLocalModels") ?? true;
        _disabledNotice.Visibility = optional ? Visibility.Collapsed : Visibility.Visible;
        _disabledNotice.Text = optional
            ? ""
            : "当前为预装本地版，模型已内置；以下开关控制是否在「引擎」页显示对应选项。";

        FillWhisperCombo(health);

        if (!health.TryGetProperty("localModels", out var models) || models.ValueKind != JsonValueKind.Array)
        {
            return Task.CompletedTask;
        }

        foreach (var item in models.EnumerateArray())
        {
            var id = LocalModelJson.ReadString(item, "id");
            if (string.IsNullOrEmpty(id) || !_modelRows.TryGetValue(id, out var row))
            {
                continue;
            }

            var enabled = LocalModelJson.ReadBool(item, "enabled") ?? true;
            var hint = LocalModelJson.ReadString(item, "sizeHint");
            var desc = LocalModelJson.ReadString(item, "description");

            _suppressToggle = true;
            row.Toggle.IsOn = enabled;
            _suppressToggle = false;

            if (IsDownloading(id))
            {
                continue;
            }

            ClearRowStatus(id);

            if (id == "whisper")
            {
                UpdateWhisperRow(row, item, enabled);
                var detail = WhisperStatusText(item, hint, desc, enabled);
                _whisperDetailLabel.Text = detail;
                _whisperDetailLabel.Foreground = detail.StartsWith("已安装", StringComparison.Ordinal)
                    ? new SolidColorBrush(Microsoft.UI.Colors.ForestGreen)
                    : new SolidColorBrush(Microsoft.UI.Colors.Gray);
            }
            else
            {
                var installed = LocalModelJson.ReadBool(item, "installed") ?? false;
                row.Meta.Text = installed
                    ? enabled ? $"已安装 · {hint}" : $"已安装 · 已禁用 · {hint}"
                    : $"未安装 · {desc} · {hint}";
                row.Meta.Foreground = installed
                    ? new SolidColorBrush(Microsoft.UI.Colors.ForestGreen)
                    : new SolidColorBrush(Microsoft.UI.Colors.Gray);
                row.PendingAction = installed ? RowAction.None : RowAction.Download;
                row.ActionButton.Content = installed ? "已安装" : "下载";
                row.ActionButton.IsEnabled = enabled && !installed;
                row.DeleteButton.Visibility = installed ? Visibility.Visible : Visibility.Collapsed;
                row.DeleteButton.IsEnabled = installed;
            }
        }

        _whisperModelCombo.IsEnabled = _modelRows.TryGetValue("whisper", out var whisperRow) && whisperRow.Toggle.IsOn;
        ResumeActiveDownloadIfNeeded(health);
        return Task.CompletedTask;
    }

    private UIElement BuildContent()
    {
        var scroll = new ScrollViewer { VerticalScrollBarVisibility = ScrollBarVisibility.Auto };
        var stack = new StackPanel { Spacing = 12, Padding = new Thickness(0, 0, 4, 8) };

        stack.Children.Add(new TextBlock
        {
            Text = "本地模型（可选下载）",
            FontWeight = Microsoft.UI.Text.FontWeights.SemiBold,
            FontSize = 14,
        });
        stack.Children.Add(new TextBlock
        {
            Text = "本地模型按需下载，后台进行并显示进度。勾选启用后可在「引擎」页选用；Whisper 安装后可切换规格。",
            FontSize = 11,
            Opacity = 0.8,
            TextWrapping = TextWrapping.WrapWholeWords,
        });
        stack.Children.Add(_disabledNotice);
        stack.Children.Add(_dirLabel);

        var whisperHeader = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8 };
        whisperHeader.Children.Add(new TextBlock
        {
            Text = "Whisper 规格",
            VerticalAlignment = VerticalAlignment.Center,
        });
        whisperHeader.Children.Add(_whisperModelCombo);
        _whisperModelCombo.SelectionChanged += (_, _) =>
        {
            if (!_suppressWhisperCombo)
            {
                ReloadAsync();
            }
        };

        var whisperBlock = new StackPanel { Spacing = 4 };
        whisperBlock.Children.Add(whisperHeader);
        whisperBlock.Children.Add(_whisperDetailLabel);
        stack.Children.Add(whisperBlock);

        foreach (var id in new[] { "whisper", "argos" })
        {
            stack.Children.Add(BuildModelRow(id));
        }

        var reloadButton = new Button { Content = "重新加载", HorizontalAlignment = HorizontalAlignment.Left, Margin = new Thickness(0, 8, 0, 0) };
        reloadButton.Click += async (_, _) => await ReloadAsync();
        stack.Children.Add(reloadButton);

        scroll.Content = stack;
        return scroll;
    }

    private UIElement BuildModelRow(string id)
    {
        var toggle = new ToggleSwitch { OnContent = "启用", OffContent = "禁用" };
        toggle.Toggled += (_, _) => EnableToggled(id);

        var title = new TextBlock
        {
            Text = id == "whisper" ? "Whisper 语音识别" : "Argos 英译中",
            FontWeight = Microsoft.UI.Text.FontWeights.SemiBold,
            FontSize = 12,
            VerticalAlignment = VerticalAlignment.Center,
        };

        var meta = new TextBlock
        {
            Text = "—",
            FontSize = 10,
            Opacity = 0.8,
            VerticalAlignment = VerticalAlignment.Center,
            TextWrapping = TextWrapping.WrapWholeWords,
            MaxWidth = 220,
        };

        var actionButton = new Button { Content = "下载", MinWidth = 64 };
        actionButton.Tag = id;
        actionButton.Click += ActionClicked;

        var deleteButton = new Button { Content = "删除", MinWidth = 64, Visibility = Visibility.Collapsed };
        deleteButton.Tag = id;
        deleteButton.Click += DeleteClicked;

        var progressBar = new ProgressBar
        {
            Minimum = 0,
            Maximum = 100,
            Width = 110,
            Visibility = Visibility.Collapsed,
            VerticalAlignment = VerticalAlignment.Center,
        };

        var actionStatus = new TextBlock
        {
            FontSize = 10,
            Opacity = 0.8,
            TextWrapping = TextWrapping.WrapWholeWords,
            MaxWidth = 180,
            VerticalAlignment = VerticalAlignment.Center,
        };

        _modelRows[id] = new ModelRow
        {
            Toggle = toggle,
            Meta = meta,
            ActionButton = actionButton,
            DeleteButton = deleteButton,
            ProgressBar = progressBar,
            ActionStatus = actionStatus,
        };

        var row = new Grid { Margin = new Thickness(0, 4, 0, 4) };
        row.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        row.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        row.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        row.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        row.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        row.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(150) });

        var left = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 10 };
        left.Children.Add(toggle);
        left.Children.Add(title);
        if (id != "whisper")
        {
            left.Children.Add(meta);
        }

        Grid.SetColumn(left, 0);
        Grid.SetColumnSpan(left, 2);
        row.Children.Add(left);

        Grid.SetColumn(actionButton, 2);
        row.Children.Add(actionButton);
        Grid.SetColumn(deleteButton, 3);
        row.Children.Add(deleteButton);
        Grid.SetColumn(progressBar, 4);
        row.Children.Add(progressBar);
        Grid.SetColumn(actionStatus, 5);
        row.Children.Add(actionStatus);

        return new Border
        {
            BorderBrush = new SolidColorBrush(Microsoft.UI.Colors.Gray),
            BorderThickness = new Thickness(1),
            CornerRadius = new CornerRadius(8),
            Padding = new Thickness(12, 10, 12, 10),
            Child = row,
        };
    }

    private void FillWhisperCombo(JsonElement health)
    {
        _suppressWhisperCombo = true;
        try
        {
            var previous = _selectedWhisperBeforeReload ?? SelectedWhisperModel();
            var current = LocalModelJson.ReadString(health, "whisperModel");
            if (string.IsNullOrEmpty(current))
            {
                current = "tiny.en";
            }

            var selectId = previous ?? current;
            _whisperModelCombo.Items.Clear();

            if (health.TryGetProperty("whisperChoices", out var choices) && choices.ValueKind == JsonValueKind.Array)
            {
                var index = 0;
                var selectIndex = 0;
                foreach (var item in choices.EnumerateArray())
                {
                    var id = LocalModelJson.ReadString(item, "id");
                    if (string.IsNullOrEmpty(id))
                    {
                        continue;
                    }

                    var label = LocalModelJson.ReadString(item, "label");
                    if (string.IsNullOrEmpty(label))
                    {
                        label = id;
                    }

                    _whisperModelCombo.Items.Add(new ComboBoxItem { Content = label, Tag = id });
                    if (id == selectId)
                    {
                        selectIndex = index;
                    }

                    index++;
                }

                if (_whisperModelCombo.Items.Count > 0)
                {
                    _whisperModelCombo.SelectedIndex = selectIndex;
                }
            }

            if (_whisperModelCombo.Items.Count == 0)
            {
                _whisperModelCombo.Items.Add(new ComboBoxItem { Content = "tiny.en", Tag = "tiny.en" });
                _whisperModelCombo.SelectedIndex = 0;
            }
        }
        finally
        {
            _suppressWhisperCombo = false;
        }
    }

    private string? SelectedWhisperModel()
    {
        if (_whisperModelCombo.SelectedItem is ComboBoxItem item && item.Tag is string id && !string.IsNullOrEmpty(id))
        {
            return id;
        }

        return null;
    }

    private string WhisperSizeHint(JsonElement health, string modelId, string fallback)
    {
        if (!health.TryGetProperty("whisperChoices", out var choices) || choices.ValueKind != JsonValueKind.Array)
        {
            return fallback;
        }

        foreach (var item in choices.EnumerateArray())
        {
            if (LocalModelJson.ReadString(item, "id") == modelId)
            {
                var hint = LocalModelJson.ReadString(item, "sizeHint");
                return string.IsNullOrEmpty(hint) ? fallback : hint;
            }
        }

        return fallback;
    }

    private string WhisperStatusText(JsonElement item, string hint, string desc, bool enabled)
    {
        var health = SettingsStore.Shared.Health;
        var installedModels = new HashSet<string>(StringComparer.Ordinal);
        if (item.TryGetProperty("installedModels", out var installedArr) && installedArr.ValueKind == JsonValueKind.Array)
        {
            foreach (var el in installedArr.EnumerateArray())
            {
                if (el.ValueKind == JsonValueKind.String)
                {
                    var s = el.GetString();
                    if (!string.IsNullOrEmpty(s))
                    {
                        installedModels.Add(s);
                    }
                }
            }
        }

        var active = LocalModelJson.ReadString(item, "activeModel");
        if (string.IsNullOrEmpty(active))
        {
            active = LocalModelJson.ReadString(health, "whisperModel");
        }

        if (string.IsNullOrEmpty(active))
        {
            active = "tiny.en";
        }

        var selected = SelectedWhisperModel() ?? active;
        var selectedHint = WhisperSizeHint(health, selected, hint);
        var installedOverall = LocalModelJson.ReadBool(item, "installed") ?? false;
        var activeInstalled = LocalModelJson.ReadBool(item, "activeInstalled") ?? false;
        var anyInstalled = installedOverall || activeInstalled || installedModels.Count > 0;
        var selectedInstalled = installedModels.Contains(selected)
            || (activeInstalled && selected == active)
            || (installedOverall && selected == active);

        if (selectedInstalled)
        {
            if (selected == active)
            {
                return enabled
                    ? $"已安装 · 当前使用 {selected} · {selectedHint}"
                    : $"已安装 · 当前使用 {selected} · 已禁用";
            }

            return enabled
                ? $"已安装 {selected} · {selectedHint}（当前使用 {active}，点「切换」生效）"
                : $"已安装 {selected} · 已禁用";
        }

        if (anyInstalled)
        {
            return $"未下载 {selected} · {selectedHint}（当前使用 {active}）";
        }

        return $"未安装 · {desc} · {selectedHint}";
    }

    private void UpdateWhisperRow(ModelRow row, JsonElement item, bool enabled)
    {
        var health = SettingsStore.Shared.Health;
        var installedModels = new HashSet<string>(StringComparer.Ordinal);
        if (item.TryGetProperty("installedModels", out var installedArr) && installedArr.ValueKind == JsonValueKind.Array)
        {
            foreach (var el in installedArr.EnumerateArray())
            {
                if (el.ValueKind == JsonValueKind.String)
                {
                    var s = el.GetString();
                    if (!string.IsNullOrEmpty(s))
                    {
                        installedModels.Add(s);
                    }
                }
            }
        }

        var active = LocalModelJson.ReadString(item, "activeModel");
        if (string.IsNullOrEmpty(active))
        {
            active = LocalModelJson.ReadString(health, "whisperModel");
        }

        if (string.IsNullOrEmpty(active))
        {
            active = "tiny.en";
        }

        var selected = SelectedWhisperModel() ?? active;
        var installedOverall = LocalModelJson.ReadBool(item, "installed") ?? false;
        var activeInstalled = LocalModelJson.ReadBool(item, "activeInstalled") ?? false;
        var selectedInstalled = installedModels.Contains(selected)
            || (activeInstalled && selected == active)
            || (installedOverall && selected == active);

        if (selectedInstalled)
        {
            row.DeleteButton.Visibility = Visibility.Visible;
            row.DeleteButton.IsEnabled = true;
            if (selected == active)
            {
                row.PendingAction = RowAction.None;
                row.ActionButton.Content = "已安装";
                row.ActionButton.IsEnabled = false;
            }
            else
            {
                row.PendingAction = RowAction.SwitchModel;
                row.ActionButton.Content = "切换";
                row.ActionButton.IsEnabled = enabled;
            }
        }
        else
        {
            row.DeleteButton.Visibility = Visibility.Collapsed;
            row.DeleteButton.IsEnabled = false;
            row.PendingAction = RowAction.Download;
            row.ActionButton.Content = "下载";
            row.ActionButton.IsEnabled = enabled;
        }
    }

    private async void EnableToggled(string id)
    {
        if (_suppressToggle || !_modelRows.TryGetValue(id, out _))
        {
            return;
        }

        var enabled = _modelRows[id].Toggle.IsOn;
        SetRowStatus(id, "正在保存…");

        try
        {
            var body = new Dictionary<string, object>();
            if (id == "whisper")
            {
                body["whisperEnabled"] = enabled;
            }
            else if (id == "argos")
            {
                body["argosEnabled"] = enabled;
            }

            var msg = await _store.UpdateSettingsAsync(body);
            await SettingsStore.Shared.RefreshAsync();
            await ReloadAsync();
            SetRowStatus(id, msg, success: true);
            OnEngineRefreshNeeded?.Invoke();
        }
        catch (Exception ex)
        {
            SetRowStatus(id, ex.Message, success: false);
            await ReloadAsync();
        }
    }

    private async void ActionClicked(object sender, RoutedEventArgs e)
    {
        if (sender is not Button button || button.Tag is not string id || !_modelRows.TryGetValue(id, out var row))
        {
            return;
        }

        if (id == "whisper" && row.PendingAction == RowAction.SwitchModel)
        {
            button.IsEnabled = false;
            try
            {
                var model = SelectedWhisperModel();
                if (string.IsNullOrEmpty(model))
                {
                    await ReloadAsync();
                    return;
                }

                SetRowStatus(id, "正在切换…");
                var msg = await _store.UpdateSettingsAsync(new Dictionary<string, object>
                {
                    ["whisperModel"] = model,
                    ["action"] = "switch",
                });
                await SettingsStore.Shared.RefreshAsync();
                await ReloadAsync();
                SetRowStatus(id, msg, success: true);
                OnEngineRefreshNeeded?.Invoke();
            }
            catch (Exception ex)
            {
                SetRowStatus(id, ex.Message, success: false);
                await ReloadAsync();
            }

            return;
        }

        var whisperModel = id == "whisper" ? SelectedWhisperModel() : null;
        if (!await ConfirmDownloadAsync(id, whisperModel))
        {
            await ReloadAsync();
            return;
        }

        button.IsEnabled = false;
        try
        {
            await BeginDownloadAsync(id, whisperModel);
        }
        catch (Exception ex)
        {
            HideDownloadProgress(id);
            SetRowStatus(id, ex.Message, success: false);
            await ReloadAsync();
        }
    }

    private async void DeleteClicked(object sender, RoutedEventArgs e)
    {
        if (sender is not Button button || button.Tag is not string id)
        {
            return;
        }

        if (!await ConfirmDeleteAsync(id))
        {
            return;
        }

        button.IsEnabled = false;
        SetRowStatus(id, "正在删除…");
        try
        {
            string? whisperModel = id == "whisper" ? SelectedWhisperModel() : null;
            var msg = await _store.DeleteAsync(id, whisperModel);
            await SettingsStore.Shared.RefreshAsync();
            await ReloadAsync();
            SetRowStatus(id, msg, success: true);
            OnEngineRefreshNeeded?.Invoke();
        }
        catch (Exception ex)
        {
            SetRowStatus(id, ex.Message, success: false);
            await ReloadAsync();
        }
    }

    private async Task<bool> ConfirmDownloadAsync(string id, string? whisperModel)
    {
        if (HostRoot is null)
        {
            return true;
        }

        var health = SettingsStore.Shared.Health;
        var sizeHint = SizeHintForModel(health, id, whisperModel);
        var dialog = new ContentDialog
        {
            Title = "下载本地模型？",
            PrimaryButtonText = "下载",
            CloseButtonText = "取消",
            DefaultButton = ContentDialogButton.Primary,
            XamlRoot = HostRoot,
        };

        if (id == "whisper" && !string.IsNullOrEmpty(whisperModel))
        {
            dialog.Content = $"将后台下载 Whisper {whisperModel}（{sizeHint}）。\n建议 Wi-Fi 环境；可关闭设置页，下载会继续进行。";
        }
        else if (id == "argos")
        {
            dialog.Content = $"将后台下载 Argos 英译中（{sizeHint}）。\n建议 Wi-Fi 环境；可关闭设置页，下载会继续进行。";
        }
        else
        {
            dialog.Content = $"将后台下载（{sizeHint}）。建议 Wi-Fi 环境。";
        }

        return await dialog.ShowAsync() == ContentDialogResult.Primary;
    }

    private async Task<bool> ConfirmDeleteAsync(string id)
    {
        if (HostRoot is null)
        {
            return true;
        }

        var dialog = new ContentDialog
        {
            Title = "删除本地模型？",
            PrimaryButtonText = "删除",
            CloseButtonText = "取消",
            DefaultButton = ContentDialogButton.Primary,
            XamlRoot = HostRoot,
        };

        if (id == "whisper")
        {
            var model = SelectedWhisperModel() ?? "当前规格";
            dialog.Content = $"将删除 Whisper {model} 的本地文件。删除后需重新下载才能使用。";
        }
        else if (id == "argos")
        {
            dialog.Content = "将删除 Argos 英译中语言包。删除后需重新下载才能使用。";
        }
        else
        {
            dialog.Content = "删除后需重新下载才能使用。";
        }

        return await dialog.ShowAsync() == ContentDialogResult.Primary;
    }

    private static string SizeHintForModel(JsonElement health, string id, string? whisperModel)
    {
        if (id == "whisper" && !string.IsNullOrEmpty(whisperModel))
        {
            if (health.TryGetProperty("whisperChoices", out var choices) && choices.ValueKind == JsonValueKind.Array)
            {
                foreach (var item in choices.EnumerateArray())
                {
                    if (LocalModelJson.ReadString(item, "id") == whisperModel)
                    {
                        var hint = LocalModelJson.ReadString(item, "sizeHint");
                        return string.IsNullOrEmpty(hint) ? "~75 MB" : hint;
                    }
                }
            }

            return "~75 MB";
        }

        var model = LocalModelJson.FindLocalModel(health, id);
        if (model is { } el)
        {
            var hint = LocalModelJson.ReadString(el, "sizeHint");
            return string.IsNullOrEmpty(hint) ? "—" : hint;
        }

        return "—";
    }

    private async Task BeginDownloadAsync(string id, string? whisperModel)
    {
        var job = await _store.StartDownloadAsync(id, whisperModel);
        ApplyDownloadProgress(id, job);
        FollowDownloadJob(id, job.Id);
    }

    private void FollowDownloadJob(string rowId, string jobId)
    {
        CancelDownloadPoll(rowId);
        var cts = new CancellationTokenSource();
        _downloadPolls[rowId] = cts;
        _ = PollDownloadLoopAsync(rowId, jobId, cts);
    }

    private async Task PollDownloadLoopAsync(string rowId, string jobId, CancellationTokenSource cts)
    {
        try
        {
            while (!cts.IsCancellationRequested)
            {
                await Task.Delay(500, cts.Token);
                var job = await _store.PollDownloadJobAsync(jobId, cts.Token);
                ApplyDownloadProgress(rowId, job);
                if (job.Status == "done")
                {
                    HideDownloadProgress(rowId);
                    await SettingsStore.Shared.RefreshAsync();
                    await ReloadAsync();
                    SetRowStatus(rowId, job.DisplayMessage, success: true);
                    OnEngineRefreshNeeded?.Invoke();
                    return;
                }
            }
        }
        catch (OperationCanceledException)
        {
            // panel closed or superseded
        }
        catch (Exception ex)
        {
            HideDownloadProgress(rowId);
            await ReloadAsync();
            SetRowStatus(rowId, ex.Message, success: false);
        }
        finally
        {
            if (_downloadPolls.TryGetValue(rowId, out var existing) && existing == cts)
            {
                _downloadPolls.Remove(rowId);
            }

            cts.Dispose();
        }
    }

    private void ResumeActiveDownloadIfNeeded(JsonElement health)
    {
        if (!health.TryGetProperty("activeDownload", out var jobEl)
            || LocalModelDownloadJob.From(jobEl) is not { Status: "running" } job)
        {
            return;
        }

        var rowId = job.ModelId;
        if (!MatchesActiveJob(job, rowId) || IsDownloading(rowId))
        {
            return;
        }

        ApplyDownloadProgress(rowId, job);
        FollowDownloadJob(rowId, job.Id);
    }

    private bool MatchesActiveJob(LocalModelDownloadJob job, string rowId)
    {
        if (job.ModelId != rowId)
        {
            return false;
        }

        if (rowId == "whisper" && !string.IsNullOrEmpty(job.WhisperModel))
        {
            var selected = SelectedWhisperModel();
            return selected == job.WhisperModel;
        }

        return true;
    }

    private bool IsDownloading(string id) =>
        _downloadPolls.TryGetValue(id, out var cts) && !cts.IsCancellationRequested;

    private void CancelDownloadPoll(string id)
    {
        if (_downloadPolls.Remove(id, out var cts))
        {
            cts.Cancel();
            cts.Dispose();
        }
    }

    private void ApplyDownloadProgress(string id, LocalModelDownloadJob job)
    {
        if (!_modelRows.TryGetValue(id, out var row))
        {
            return;
        }

        row.ProgressBar.Visibility = Visibility.Visible;
        row.ProgressBar.Value = job.Progress * 100;
        row.ActionButton.IsEnabled = false;
        row.DeleteButton.IsEnabled = false;
        SetRowStatus(id, job.DisplayMessage);

        if (id == "whisper")
        {
            _whisperDetailLabel.Text = "后台下载中，可关闭此页面继续等待";
            _whisperDetailLabel.Foreground = new SolidColorBrush(Microsoft.UI.Colors.Gray);
        }
    }

    private void HideDownloadProgress(string id)
    {
        if (!_modelRows.TryGetValue(id, out var row))
        {
            return;
        }

        row.ProgressBar.Visibility = Visibility.Collapsed;
        row.ProgressBar.Value = 0;
    }

    private void ClearRowStatus(string id) => SetRowStatus(id, "");

    private void SetRowStatus(string id, string text, bool? success = null)
    {
        if (!_modelRows.TryGetValue(id, out var row))
        {
            return;
        }

        row.ActionStatus.Text = text;
        row.ActionStatus.Visibility = string.IsNullOrEmpty(text) ? Visibility.Collapsed : Visibility.Visible;
        if (success is null)
        {
            row.ActionStatus.Foreground = new SolidColorBrush(Microsoft.UI.Colors.Gray);
        }
        else
        {
            row.ActionStatus.Foreground = success.Value
                ? new SolidColorBrush(Microsoft.UI.Colors.ForestGreen)
                : new SolidColorBrush(Microsoft.UI.Colors.IndianRed);
        }
    }
}
