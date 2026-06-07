using Microsoft.UI.Input;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Controls.Primitives;
using Microsoft.UI.Xaml.Input;
using Microsoft.UI.Xaml.Media;
using System.Numerics;
using VoiceBridgeAI.Session;

namespace VoiceBridgeAI.Overlay;

public sealed partial class OverlayWindow : Window
{
    private bool _configured;
    private bool _updatingSliders;
    private SubtitleStore? _lastStore;

    public OverlayWindow()
    {
        InitializeComponent();
        OverlayPreferences.Changed += OnPreferencesChanged;
        Activated += OnFirstActivated;
        Closed += (_, _) => OverlayPreferences.Changed -= OnPreferencesChanged;
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
            OverlayBorder.Translation = new Vector3(0, 0, 24);
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
        _updatingSliders = true;
        BgOpacitySlider.Value = OverlayPreferences.BackgroundOpacity;
        TextOpacitySlider.Value = OverlayPreferences.TextOpacity;
        EnToggle.IsChecked = OverlayPreferences.ShowEnglish;
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

    private void DragHandle_PointerEntered(object sender, PointerRoutedEventArgs e)
    {
        if (sender is UIElement element)
        {
            element.ProtectedCursor = InputSystemCursor.Create(InputSystemCursorShape.SizeAll);
        }
    }

    private void DragHandle_PointerExited(object sender, PointerRoutedEventArgs e)
    {
        if (sender is UIElement element)
        {
            element.ProtectedCursor = InputSystemCursor.Create(InputSystemCursorShape.Arrow);
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
        if (_updatingSliders)
        {
            return;
        }

        OverlayPreferences.ShowEnglish = EnToggle.IsChecked == true;
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
