using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Controls.Primitives;
using Microsoft.UI.Xaml.Input;
using Microsoft.UI.Xaml.Media;
using VoiceBridgeAI.Session;
using VoiceBridgeAI.Settings;
using Windows.UI;

namespace VoiceBridgeAI.Overlay;

public sealed partial class OverlayWindow : Window
{
    private bool _configured;
    private bool _syncingControls;
    private SubtitleStore? _lastStore;
    private double _textOpacity = 1.0;
    private Brush ChromeBrush => (Brush)Resources["ChromeBrush"];

    private Brush ChromeMutedBrush => (Brush)Resources["ChromeMutedBrush"];

    public OverlayWindow()
    {
        InitializeComponent();
        _textOpacity = OverlayPreferences.TextOpacity;
        OverlayPreferences.Changed += OnPreferencesChanged;
        TranscriptPreferences.Changed += OnTranscriptPreferencesChanged;
        Activated += OnFirstActivated;
        Closed += (_, _) =>
        {
            OverlayPreferences.Changed -= OnPreferencesChanged;
            TranscriptPreferences.Changed -= OnTranscriptPreferencesChanged;
        };

        TitleLabel.PointerPressed += DragArea_PointerPressed;
        ApplyBackgroundOpacity(OverlayPreferences.BackgroundOpacity);
        SyncControlsFromPreferences();
        ApplyTextOpacityToAllVisibleContent();
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
            CardShell.Shadow = new ThemeShadow();
            CardShell.Translation = new System.Numerics.Vector3(0, 0, 24);
            SyncControlsFromPreferences();
            ApplyBackgroundOpacity(OverlayPreferences.BackgroundOpacity);
            ApplyTextOpacityToAllVisibleContent();
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
        ApplyTextOpacityToAllVisibleContent();
    }

    private void OnTranscriptPreferencesChanged()
    {
        SyncRecordToggle();
    }

    private void SyncControlsFromPreferences()
    {
        _syncingControls = true;
        BgOpacitySlider.Value = OverlayPreferences.BackgroundOpacity;
        TextOpacitySlider.Value = OverlayPreferences.TextOpacity;
        EnToggle.IsChecked = OverlayPreferences.ShowEnglish;
        var showEn = OverlayPreferences.ShowEnglish;
        EnToggle.Opacity = showEn ? 1.0 : 0.55;
        EnToggle.Foreground = showEn ? ChromeBrush : ChromeMutedBrush;
        SyncRecordToggle();
        _syncingControls = false;
    }

    private void SyncRecordToggle()
    {
        var enabled = TranscriptPreferences.RecordEnabled;
        RecordToggle.IsChecked = enabled;
        RecordToggle.Opacity = enabled ? 1.0 : 0.55;
        RecordToggle.Foreground = enabled ? ChromeBrush : ChromeMutedBrush;
    }

    private void ApplyBackgroundOpacity(double opacity)
    {
        var value = Math.Clamp(opacity, 0.15, 1.0);

        BackdropFill.Fill = new SolidColorBrush(Color.FromArgb(
            (byte)Math.Round(value * 210),
            18,
            18,
            24));

        TintOverlay.Fill = new SolidColorBrush(Color.FromArgb(
            (byte)Math.Round(value * 135),
            0,
            0,
            0));
    }

    private double TextAlpha(double baseAlpha) =>
        Math.Clamp(baseAlpha * _textOpacity, 0, 1);

    private void ApplyTextOpacityToAllVisibleContent()
    {
        _textOpacity = OverlayPreferences.TextOpacity;

        if (_lastStore is not null)
        {
            RenderStore(_lastStore);
            return;
        }

        ZhLabel.Opacity = TextAlpha(0.9);
        HistoryZhLabel.Opacity = TextAlpha(0.55);
        HistoryEnLabel.Opacity = TextAlpha(0.45);
        EnLabel.Opacity = TextAlpha(0.92);
        ErrorLabel.Opacity = TextAlpha(0.95);
    }

    public void Update(SubtitleStore store)
    {
        _lastStore = store;
        SyncRecordToggle();
        UpdateModeBadge();

        if (!store.IsVisible)
        {
            Hide();
            return;
        }

        Show();
        RenderStore(store);
    }

    private void RenderStore(SubtitleStore store)
    {
        if (!string.IsNullOrEmpty(store.ErrorMessage))
        {
            ErrorLabel.Text = store.ErrorMessage;
            ErrorLabel.Opacity = TextAlpha(0.95);
            ErrorLabel.Visibility = Visibility.Visible;
            HistoryZhLabel.Visibility = Visibility.Collapsed;
            HistoryEnLabel.Visibility = Visibility.Collapsed;
            EnLabel.Visibility = Visibility.Collapsed;
            ZhLabel.Text = "";
            return;
        }

        ErrorLabel.Visibility = Visibility.Collapsed;

        if (store.Segments.Count == 0)
        {
            HistoryZhLabel.Visibility = Visibility.Collapsed;
            HistoryEnLabel.Visibility = Visibility.Collapsed;
            EnLabel.Visibility = Visibility.Collapsed;
            ZhLabel.Text = store.StatusMessage;
            ZhLabel.Foreground = ChromeBrush;
            ZhLabel.Opacity = TextAlpha(0.9);
            return;
        }

        ZhLabel.Foreground = new SolidColorBrush(Microsoft.UI.Colors.WhiteSmoke);

        if (store.Segments.Count >= 2)
        {
            ApplyHistory(store.Segments[^2]);
            ApplyCurrent(store.Segments[^1]);
        }
        else
        {
            HistoryZhLabel.Visibility = Visibility.Collapsed;
            HistoryEnLabel.Visibility = Visibility.Collapsed;
            ApplyCurrent(store.Segments[^1]);
        }
    }

    private void ApplyHistory(SubtitleSegment seg)
    {
        var zh = DisplayChinese(seg);
        var en = seg.Text;
        var showEn = OverlayPreferences.ShowEnglish && !string.IsNullOrEmpty(en);

        if (string.IsNullOrEmpty(zh) && !showEn)
        {
            HistoryZhLabel.Visibility = Visibility.Collapsed;
            HistoryEnLabel.Visibility = Visibility.Collapsed;
            return;
        }

        HistoryZhLabel.Text = string.IsNullOrEmpty(zh) ? "" : zh;
        HistoryZhLabel.Opacity = TextAlpha(string.IsNullOrEmpty(zh) ? 0 : 0.55);
        HistoryZhLabel.Visibility = string.IsNullOrEmpty(zh) ? Visibility.Collapsed : Visibility.Visible;

        HistoryEnLabel.Text = showEn ? en : "";
        HistoryEnLabel.Opacity = TextAlpha(showEn ? 0.45 : 0);
        HistoryEnLabel.Visibility = showEn ? Visibility.Visible : Visibility.Collapsed;
    }

    private void ApplyCurrent(SubtitleSegment seg)
    {
        var zh = DisplayChinese(seg);
        var en = seg.Text;

        if (string.IsNullOrEmpty(zh) && seg.Partial)
        {
            ZhLabel.Text = "…";
            ZhLabel.Foreground = ChromeBrush;
            ZhLabel.Opacity = TextAlpha(0.78);
        }
        else
        {
            ZhLabel.Text = string.IsNullOrEmpty(zh) ? "…" : zh;
            ZhLabel.Foreground = new SolidColorBrush(Microsoft.UI.Colors.WhiteSmoke);
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

    private void UpdateModeBadge()
    {
        if (!SessionController.Shared.IsRunning)
        {
            ModeBadge.Visibility = Visibility.Collapsed;
            return;
        }

        var modeId = SettingsStore.Shared.Engine.ReviseMode;
        var label = ProviderOption.List(SettingsStore.Shared.Health, "reviseModes")
            .FirstOrDefault(p => p.Id == modeId).Label ?? modeId;
        ModeBadge.Text = label;
        ModeBadge.Visibility = Visibility.Visible;
    }

    private static string DisplayChinese(SubtitleSegment seg)
    {
        if (!string.IsNullOrWhiteSpace(seg.Translation))
        {
            return seg.Translation;
        }

        return seg.Partial ? "" : seg.Text;
    }

    private void DragArea_PointerPressed(object sender, PointerRoutedEventArgs e)
    {
        if (e.GetCurrentPoint(null).Properties.IsLeftButtonPressed)
        {
            WindowDragHelper.Drag(this);
        }
    }

    private void BgOpacitySlider_ValueChanged(object sender, RangeBaseValueChangedEventArgs e)
    {
        if (_syncingControls)
        {
            return;
        }

        OverlayPreferences.BackgroundOpacity = e.NewValue;
        ApplyBackgroundOpacity(e.NewValue);
    }

    private void TextOpacitySlider_ValueChanged(object sender, RangeBaseValueChangedEventArgs e)
    {
        if (_syncingControls)
        {
            return;
        }

        OverlayPreferences.TextOpacity = e.NewValue;
        ApplyTextOpacityToAllVisibleContent();
    }

    private void EnToggle_Changed(object sender, RoutedEventArgs e)
    {
        if (_syncingControls)
        {
            return;
        }

        var on = EnToggle.IsChecked == true;
        OverlayPreferences.ShowEnglish = on;
        EnToggle.Opacity = on ? 1.0 : 0.55;
        EnToggle.Foreground = on ? ChromeBrush : ChromeMutedBrush;

        if (_lastStore is not null)
        {
            RenderStore(_lastStore);
        }
    }

    private void RecordToggle_Changed(object sender, RoutedEventArgs e)
    {
        if (_syncingControls)
        {
            return;
        }

        var enabled = RecordToggle.IsChecked == true;
        TranscriptPreferences.RecordEnabled = enabled;
        SyncRecordToggle();

        if (enabled && SessionController.Shared.IsRunning)
        {
            try
            {
                var modeId = SettingsStore.Shared.Engine.ReviseMode;
                var label = ProviderOption.List(SettingsStore.Shared.Health, "reviseModes")
                    .FirstOrDefault(p => p.Id == modeId).Label ?? modeId;
                TranslationRecorder.Shared.BeginSessionIfNeeded(modeId, label);
            }
            catch
            {
                TranslationRecorder.Shared.BeginSessionIfNeeded("speech", "speech");
            }
        }
    }

    private void StopClicked(object sender, RoutedEventArgs e)
    {
        SessionController.Shared.Stop();
    }

    private void Show()
    {
        ApplyBackgroundOpacity(OverlayPreferences.BackgroundOpacity);
        Activate();
        AppWindow.Show();
    }

    private void Hide()
    {
        AppWindow.Hide();
    }
}
