using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using VoiceBridgeAI.Session;

namespace VoiceBridgeAI.Settings;

public sealed class TranscriptSettingsPanel
{
    private readonly ToggleSwitch _recordToggle = new() { OnContent = "启用", OffContent = "禁用" };
    private readonly TextBlock _noteLabel = new() { TextWrapping = TextWrapping.WrapWholeWords, FontSize = 11, Opacity = 0.8 };
    private readonly TextBlock _directoryLabel = new() { FontSize = 10, Opacity = 0.65, TextWrapping = TextWrapping.WrapWholeWords };
    private readonly TextBox _prefixField = new() { PlaceholderText = "字幕记录", HorizontalAlignment = HorizontalAlignment.Stretch };
    private readonly TextBox _templateField = new() { PlaceholderText = "{prefix}_{datetime}", HorizontalAlignment = HorizontalAlignment.Stretch };
    private readonly ComboBox _formatCombo = new() { MinWidth = 180, HorizontalAlignment = HorizontalAlignment.Left };
    private readonly ComboBox _layoutCombo = new() { MinWidth = 180, HorizontalAlignment = HorizontalAlignment.Left };
    private readonly ComboBox _convertLayoutCombo = new() { MinWidth = 180, HorizontalAlignment = HorizontalAlignment.Left };
    private readonly ComboBox _convertFormatCombo = new() { MinWidth = 180, HorizontalAlignment = HorizontalAlignment.Left };
    private readonly TextBlock _statusLabel = new() { FontSize = 10, TextWrapping = TextWrapping.WrapWholeWords };

    private bool _suppressEvents;
    private Window? _hostWindow;

    public UIElement Root { get; }

    public TranscriptSettingsPanel()
    {
        Root = BuildContent();
    }

    public void AttachHostWindow(Window window) => _hostWindow = window;

    public void Reload()
    {
        _suppressEvents = true;
        try
        {
            _recordToggle.IsOn = TranscriptPreferences.RecordEnabled;
            _prefixField.Text = TranscriptPreferences.FilePrefix;
            _templateField.Text = TranscriptPreferences.FilenameTemplate;
            _directoryLabel.Text = TranscriptPreferences.DirectoryDisplayPath;
            _noteLabel.Text = $"每次开始悬浮字幕时创建新文件；仅保存定稿句。{TranscriptPreferences.FilenameTokenHelp}";

            FillEnumCombo(_formatCombo, Enum.GetValues<TranscriptPreferences.FileFormat>());
            SelectEnumCombo(_formatCombo, TranscriptPreferences.FileFormatValue);

            FillEnumCombo(_layoutCombo, Enum.GetValues<TranscriptPreferences.ContentLayout>());
            SelectEnumCombo(_layoutCombo, TranscriptPreferences.ContentLayoutValue);

            FillEnumCombo(_convertLayoutCombo, Enum.GetValues<TranscriptPreferences.ContentLayout>());
            SelectEnumCombo(_convertLayoutCombo, TranscriptPreferences.ContentLayoutValue);

            FillEnumCombo(_convertFormatCombo, Enum.GetValues<TranscriptPreferences.FileFormat>());
            SelectEnumCombo(_convertFormatCombo, TranscriptPreferences.FileFormatValue);

            UpdatePreview();
        }
        finally
        {
            _suppressEvents = false;
        }
    }

    private UIElement BuildContent()
    {
        var scroll = new ScrollViewer { VerticalScrollBarVisibility = ScrollBarVisibility.Auto };
        var stack = new StackPanel { Spacing = 10, Padding = new Thickness(0, 0, 4, 8) };

        stack.Children.Add(new TextBlock
        {
            Text = "字幕记录",
            FontWeight = Microsoft.UI.Text.FontWeights.SemiBold,
            FontSize = 14,
        });
        stack.Children.Add(_noteLabel);

        var recordRow = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8 };
        recordRow.Children.Add(_recordToggle);
        recordRow.Children.Add(new TextBlock
        {
            Text = "启用字幕记录",
            VerticalAlignment = VerticalAlignment.Center,
        });
        _recordToggle.Toggled += (_, _) =>
        {
            if (_suppressEvents)
            {
                return;
            }

            TranscriptPreferences.RecordEnabled = _recordToggle.IsOn;
        };
        stack.Children.Add(recordRow);

        stack.Children.Add(MakeLabeledBlock("保存目录", _directoryLabel));

        var dirButtons = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8 };
        var chooseButton = new Button { Content = "选择目录…" };
        chooseButton.Click += ChooseDirectoryClicked;
        dirButtons.Children.Add(chooseButton);
        var resetButton = new Button { Content = "恢复默认目录" };
        resetButton.Click += ResetDirectoryClicked;
        dirButtons.Children.Add(resetButton);
        var openButton = new Button { Content = "在资源管理器中打开" };
        openButton.Click += (_, _) => TranslationRecorder.Shared.OpenTranscriptsDirectory();
        dirButtons.Children.Add(openButton);
        stack.Children.Add(dirButtons);

        stack.Children.Add(MakeLabeledBlock("文件名前缀", _prefixField));
        stack.Children.Add(MakeLabeledBlock("文件名模板", _templateField));
        _prefixField.TextChanged += (_, _) => PersistFields();
        _templateField.TextChanged += (_, _) => PersistFields();

        stack.Children.Add(MakeFormRow("文件格式", _formatCombo, FormatChanged));
        stack.Children.Add(MakeFormRow("内容形式", _layoutCombo, LayoutChanged));
        stack.Children.Add(_statusLabel);

        stack.Children.Add(new TextBlock
        {
            Text = "转换已有记录",
            FontWeight = Microsoft.UI.Text.FontWeights.SemiBold,
            Margin = new Thickness(0, 12, 0, 0),
        });
        stack.Children.Add(new TextBlock
        {
            Text = "将已有 .md / .txt 记录转为其他内容形式，生成新文件（原文件保留）。",
            FontSize = 10,
            Opacity = 0.8,
            TextWrapping = TextWrapping.WrapWholeWords,
        });
        stack.Children.Add(MakeFormRow("目标形式", _convertLayoutCombo, null));
        stack.Children.Add(MakeFormRow("目标格式", _convertFormatCombo, null));

        var convertButton = new Button { Content = "转换已有文件…", HorizontalAlignment = HorizontalAlignment.Left };
        convertButton.Click += ConvertExistingClicked;
        stack.Children.Add(convertButton);

        var reloadButton = new Button { Content = "重新加载", HorizontalAlignment = HorizontalAlignment.Left, Margin = new Thickness(0, 8, 0, 0) };
        reloadButton.Click += (_, _) => Reload();
        stack.Children.Add(reloadButton);

        scroll.Content = stack;
        return scroll;
    }

    private static StackPanel MakeLabeledBlock(string title, UIElement field)
    {
        var panel = new StackPanel { Spacing = 4 };
        panel.Children.Add(new TextBlock { Text = title, FontSize = 12, Opacity = 0.85 });
        panel.Children.Add(field);
        return panel;
    }

    private static StackPanel MakeFormRow(string title, ComboBox combo, SelectionChangedEventHandler? changed)
    {
        var panel = new StackPanel { Spacing = 4 };
        panel.Children.Add(new TextBlock { Text = title, FontSize = 12, Opacity = 0.85 });
        if (changed is not null)
        {
            combo.SelectionChanged += changed;
        }

        panel.Children.Add(combo);
        return panel;
    }

    private static void FillEnumCombo<T>(ComboBox combo, IEnumerable<T> values) where T : struct, Enum
    {
        combo.Items.Clear();
        foreach (var value in values)
        {
            var label = value switch
            {
                TranscriptPreferences.FileFormat ff => TranscriptPreferences.LabelFor(ff),
                TranscriptPreferences.ContentLayout cl => TranscriptPreferences.LabelFor(cl),
                _ => value.ToString(),
            };
            combo.Items.Add(new ComboBoxItem { Content = label, Tag = value.ToString() });
        }
    }

    private static void SelectEnumCombo<T>(ComboBox combo, T selected) where T : struct, Enum
    {
        var raw = selected.ToString();
        for (var i = 0; i < combo.Items.Count; i++)
        {
            if (combo.Items[i] is ComboBoxItem item && item.Tag is string tag && tag == raw)
            {
                combo.SelectedIndex = i;
                return;
            }
        }

        if (combo.Items.Count > 0)
        {
            combo.SelectedIndex = 0;
        }
    }

    private static T? SelectedEnum<T>(ComboBox combo) where T : struct, Enum
    {
        if (combo.SelectedItem is ComboBoxItem item
            && item.Tag is string raw
            && Enum.TryParse<T>(raw, out var value))
        {
            return value;
        }

        return null;
    }

    private void PersistFields()
    {
        if (_suppressEvents)
        {
            return;
        }

        TranscriptPreferences.FilePrefix = _prefixField.Text;
        TranscriptPreferences.FilenameTemplate = _templateField.Text;
        UpdatePreview();
    }

    private void FormatChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_suppressEvents)
        {
            return;
        }

        if (SelectedEnum<TranscriptPreferences.FileFormat>(_formatCombo) is { } format)
        {
            TranscriptPreferences.FileFormatValue = format;
            UpdatePreview();
        }
    }

    private void LayoutChanged(object sender, SelectionChangedEventArgs e)
    {
        if (_suppressEvents)
        {
            return;
        }

        if (SelectedEnum<TranscriptPreferences.ContentLayout>(_layoutCombo) is { } layout)
        {
            TranscriptPreferences.ContentLayoutValue = layout;
            UpdatePreview();
        }
    }

    private void UpdatePreview()
    {
        var sample = TranscriptPreferences.SessionFilename(DateTime.Now, "speech");
        var layout = TranscriptPreferences.LabelFor(TranscriptPreferences.ContentLayoutValue);
        _statusLabel.Text = $"示例文件名：{sample} · 内容：{layout}";
        _statusLabel.Foreground = new SolidColorBrush(Microsoft.UI.Colors.Gray);
    }

    private async void ChooseDirectoryClicked(object sender, RoutedEventArgs e)
    {
        if (_hostWindow is null)
        {
            ShowStatus("请先打开设置窗口后再选择目录", success: false);
            return;
        }

        var path = await PickerWindowHelper.PickFolderAsync(_hostWindow, TranscriptPreferences.StorageDirectory);
        if (string.IsNullOrEmpty(path))
        {
            return;
        }

        TranscriptPreferences.StorageDirectory = path;
        _directoryLabel.Text = TranscriptPreferences.DirectoryDisplayPath;
        ShowStatus("已设置保存目录", success: true);
    }

    private void ResetDirectoryClicked(object sender, RoutedEventArgs e)
    {
        TranscriptPreferences.ResetDirectoryToDefault();
        _directoryLabel.Text = TranscriptPreferences.DirectoryDisplayPath;
        ShowStatus("已恢复默认目录", success: true);
    }

    private async void ConvertExistingClicked(object sender, RoutedEventArgs e)
    {
        if (_hostWindow is null)
        {
            ShowStatus("请先打开设置窗口后再转换文件", success: false);
            return;
        }

        if (SelectedEnum<TranscriptPreferences.ContentLayout>(_convertLayoutCombo) is not { } layout
            || SelectedEnum<TranscriptPreferences.FileFormat>(_convertFormatCombo) is not { } format)
        {
            return;
        }

        var source = await PickerWindowHelper.PickTranscriptFileAsync(_hostWindow, TranscriptPreferences.StorageDirectory);
        if (string.IsNullOrEmpty(source))
        {
            return;
        }

        try
        {
            var dest = TranslationRecorder.ConvertFile(source, layout, format);
            ShowStatus($"已生成：{Path.GetFileName(dest)}", success: true);
            System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo
            {
                FileName = "explorer.exe",
                Arguments = $"/select,\"{dest}\"",
                UseShellExecute = true,
            });
        }
        catch (Exception ex)
        {
            ShowStatus(ex.Message, success: false);
        }
    }

    private void ShowStatus(string message, bool success)
    {
        _statusLabel.Text = message;
        _statusLabel.Foreground = success
            ? new SolidColorBrush(Microsoft.UI.Colors.ForestGreen)
            : new SolidColorBrush(Microsoft.UI.Colors.IndianRed);
    }
}
