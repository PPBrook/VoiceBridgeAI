using Microsoft.UI.Xaml;
using VoiceBridgeAI.Session;

namespace VoiceBridgeAI.Overlay;

public sealed partial class OverlayWindow : Window
{
    public OverlayWindow()
    {
        InitializeComponent();
        OverlayWindowHelper.ConfigureOverlay(this);
    }

    public void Update(SubtitleStore store)
    {
        if (!store.IsVisible)
        {
            Hide();
            return;
        }

        Show();

        if (!string.IsNullOrEmpty(store.ErrorMessage))
        {
            ErrorLabel.Text = store.ErrorMessage;
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
            ZhLabel.Opacity = 0.9;
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
        HistoryZhLabel.Visibility = Visibility.Visible;
    }

    private void ApplyCurrent(SubtitleSegment seg)
    {
        var zh = DisplayChinese(seg);
        if (string.IsNullOrEmpty(zh) && seg.Partial)
        {
            ZhLabel.Text = "…";
            ZhLabel.Opacity = 0.78;
        }
        else
        {
            ZhLabel.Text = string.IsNullOrEmpty(zh) ? "…" : zh;
            ZhLabel.Opacity = seg.Partial ? 0.78 : 1;
        }

        EnLabel.Visibility = Visibility.Collapsed;
    }

    private static string DisplayChinese(SubtitleSegment seg)
    {
        if (!string.IsNullOrWhiteSpace(seg.Translation))
        {
            return seg.Translation;
        }

        return seg.Partial ? "" : seg.Text;
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
