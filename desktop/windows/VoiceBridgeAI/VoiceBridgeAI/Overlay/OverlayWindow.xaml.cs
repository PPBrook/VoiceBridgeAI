using Microsoft.UI;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Controls.Primitives;
using Microsoft.UI.Xaml.Input;
using Microsoft.UI.Xaml.Media;
using VoiceBridgeAI.Session;

namespace VoiceBridgeAI.Overlay;

public sealed partial class OverlayWindow : Window
{
    private bool _configured;
    private bool _updatingSliders;
    private SubtitleStore? _lastStore;
    private Slider? _bgOpacitySlider;
    private Slider? _textOpacitySlider;
    private ToggleButton? _enToggle;

    public OverlayWindow()
    {
        InitializeComponent();
        BuildHeaderChrome();
        OverlayPreferences.Changed += OnPreferencesChanged;
        Activated += OnFirstActivated;
        Closed += (_, _) => OverlayPreferences.Changed -= OnPreferencesChanged;
    }

    private void BuildHeaderChrome()
    {
        HeaderHost.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        HeaderHost.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        HeaderHost.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

        var title = new TextBlock
        {
            Text = "VoiceBridgeAI",
            Opacity = 0.55,
            VerticalAlignment = VerticalAlignment.Center,
        };
        title.PointerPressed += DragHandle_PointerPressed;
        Grid.SetColumn(title, 0);
        HeaderHost.Children.Add(title);

        var dragSpacer = new Border { Background = new SolidColorBrush(Colors.Transparent) };
        dragSpacer.PointerPressed += DragHandle_PointerPressed;
        Grid.SetColumn(dragSpacer, 1);
        HeaderHost.Children.Add(dragSpacer);

        var toolPanel = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 6 };
        Grid.SetColumn(toolPanel, 2);
        HeaderHost.Children.Add(toolPanel);

        toolPanel.Children.Add(MakeSliderGroup("背景", 0.15, 1.0, out _bgOpacitySlider, "背景不透明度"));
        toolPanel.Children.Add(MakeSliderGroup("文字", 0.25, 1.0, out _textOpacitySlider, "字幕文字不透明度"));

        _enToggle = new ToggleButton
        {
            Content = "EN",
            MinWidth = 34,
            MinHeight = 26,
            FontSize = 10,
            FontWeight = Microsoft.UI.Text.FontWeights.Bold,
        };
        ToolTipService.SetToolTip(_enToggle, "切换英文显示");
        _enToggle.Checked += EnToggle_Changed;
        _enToggle.Unchecked += EnToggle_Changed;
        toolPanel.Children.Add(_enToggle);

        var stopButton = new Button
        {
            Content = "×",
            Width = 28,
            Height = 28,
        };
        ToolTipService.SetToolTip(stopButton, "停止字幕");
        stopButton.Click += StopClicked;
        toolPanel.Children.Add(stopButton);

        _bgOpacitySlider!.ValueChanged += BgOpacitySlider_ValueChanged;
        _textOpacitySlider!.ValueChanged += TextOpacitySlider_ValueChanged;
    }

    private static StackPanel MakeSliderGroup(string label, double min, double max, out Slider slider, string tip)
    {
        var panel = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 4 };
        panel.Children.Add(new TextBlock
        {
            Text = label,
            FontSize = 10,
            Opacity = 0.55,
            VerticalAlignment = VerticalAlignment.Center,
        });
        slider = new Slider
        {
            Width = label == "背景" ? 64 : 52,
            Minimum = min,
            Maximum = max,
            StepFrequency = 0.01,
            VerticalAlignment = VerticalAlignment.Center,
        };
        ToolTipService.SetToolTip(slider, tip);
        panel.Children.Add(slider);
        return panel;
    }

    private void OnFirstActivated(object sender, WindowActivatedEventArgs args)
    {
        if (_configured)
        {
            return;
        }

        _configured = true;
        try
        {
            OverlayWindowHelper.ConfigureOverlay(this);
            SyncControlsFromPreferences();
            ApplyBackgroundOpacity(OverlayPreferences.BackgroundOpacity);
        }
        catch
        {
            // Position/style failure should not crash the app.
        }
    }

    private void OnPreferencesChanged()
    {
        SyncControlsFromPreferences();
        ApplyBackgroundOpacity(OverlayPreferences.BackgroundOpacity);
        if (_lastStore is not null)
        {
            Update(_lastStore);
        }
    }

    private void SyncControlsFromPreferences()
    {
        if (_bgOpacitySlider is null || _textOpacitySlider is null || _enToggle is null)
        {
            return;
        }

        _updatingSliders = true;
        _bgOpacitySlider.Value = OverlayPreferences.BackgroundOpacity;
        _textOpacitySlider.Value = OverlayPreferences.TextOpacity;
        _enToggle.IsChecked = OverlayPreferences.ShowEnglish;
        _updatingSliders = false;
    }

    private void ApplyBackgroundOpacity(double opacity)
    {
        var alpha = (byte)Math.Round(opacity * 255);
        OverlayBorder.Background = new SolidColorBrush(Color.FromArgb(alpha, 0, 0, 0));
    }

    private double TextAlpha(double baseAlpha) =>
        Math.Min(1.0, Math.Max(0, baseAlpha * OverlayPreferences.TextOpacity));

    public void Update(SubtitleStore store)
    {
        _lastStore = store;

        if (!store.IsVisible)
        {
            Hide();
            return;
        }

        Show();

        if (!string.IsNullOrEmpty(store.ErrorMessage))
        {
            ErrorLabel.Text = store.ErrorMessage;
            ErrorLabel.Opacity = TextAlpha(0.95);
            ErrorLabel.Visibility = Visibility.Visible;
            HistoryZhLabel.Visibility = Visibility.Collapsed;
            EnLabel.Visibility = Visibility.Collapsed;
            ZhLabel.Text = "";
            return;
        }

        ErrorLabel.Visibility = Visibility.Collapsed;

        if (store.Segments.Count == 0)
        {
            HistoryZhLabel.Visibility = Visibility.Collapsed;
            EnLabel.Visibility = Visibility.Collapsed;
            ZhLabel.Text = store.StatusMessage;
            ZhLabel.Opacity = TextAlpha(0.9);
            return;
        }

        if (store.Segments.Count >= 2)
        {
            ApplyHistory(store.Segments[^2]);
            ApplyCurrent(store.Segments[^1]);
        }
        else
        {
            HistoryZhLabel.Visibility = Visibility.Collapsed;
            ApplyCurrent(store.Segments[^1]);
        }
    }

    private void ApplyHistory(SubtitleSegment seg)
    {
        var zh = DisplayChinese(seg);
        if (string.IsNullOrEmpty(zh))
        {
            HistoryZhLabel.Visibility = Visibility.Collapsed;
            return;
        }

        HistoryZhLabel.Text = zh;
        HistoryZhLabel.Opacity = TextAlpha(1);
        HistoryZhLabel.Visibility = Visibility.Visible;
    }

    private void ApplyCurrent(SubtitleSegment seg)
    {
        var zh = DisplayChinese(seg);
        var en = seg.Text;

        if (string.IsNullOrEmpty(zh) && seg.Partial)
        {
            ZhLabel.Text = "…";
            ZhLabel.Opacity = TextAlpha(0.78);
        }
        else
        {
            ZhLabel.Text = string.IsNullOrEmpty(zh) ? "…" : zh;
            ZhLabel.Opacity = TextAlpha(seg.Partial ? 0.78 : 1);
        }

        if (OverlayPreferences.ShowEnglish && !string.IsNullOrEmpty(en))
        {
            EnLabel.Text = en;
            EnLabel.Opacity = TextAlpha(seg.Partial ? 0.72 : 0.92);
            EnLabel.Visibility = Visibility.Visible;
        }
        else
        {
            EnLabel.Visibility = Visibility.Collapsed;
        }
    }

    private static string DisplayChinese(SubtitleSegment seg)
    {
        if (!string.IsNullOrWhiteSpace(seg.Translation))
        {
            return seg.Translation;
        }

        return seg.Partial ? "" : seg.Text;
    }

    private void DragHandle_PointerPressed(object sender, PointerRoutedEventArgs e)
    {
        if (e.GetCurrentPoint(null).Properties.IsLeftButtonPressed)
        {
            WindowDragHelper.Drag(this);
        }
    }

    private void BgOpacitySlider_ValueChanged(object sender, RangeBaseValueChangedEventArgs e)
    {
        if (_updatingSliders)
        {
            return;
        }

        OverlayPreferences.BackgroundOpacity = e.NewValue;
        ApplyBackgroundOpacity(e.NewValue);
    }

    private void TextOpacitySlider_ValueChanged(object sender, RangeBaseValueChangedEventArgs e)
    {
        if (_updatingSliders)
        {
            return;
        }

        OverlayPreferences.TextOpacity = e.NewValue;
        if (_lastStore is not null)
        {
            Update(_lastStore);
        }
    }

    private void EnToggle_Changed(object sender, RoutedEventArgs e)
    {
        if (_updatingSliders || _enToggle is null)
        {
            return;
        }

        OverlayPreferences.ShowEnglish = _enToggle.IsChecked == true;
        if (_lastStore is not null)
        {
            Update(_lastStore);
        }
    }

    private void StopClicked(object sender, RoutedEventArgs e)
    {
        SessionController.Shared.Stop();
    }

    private void Show()
    {
        Activate();
        AppWindow.Show();
    }

    private void Hide()
    {
        AppWindow.Hide();
    }
}
