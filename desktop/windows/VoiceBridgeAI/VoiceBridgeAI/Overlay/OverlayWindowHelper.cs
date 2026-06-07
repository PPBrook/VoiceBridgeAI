using Microsoft.UI;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml;

namespace VoiceBridgeAI.Overlay;

public static class OverlayWindowHelper
{
    public static void ConfigureOverlay(Window window)
    {
        window.ExtendsContentIntoTitleBar = true;

        if (window.AppWindow.Presenter is OverlappedPresenter presenter)
        {
            presenter.SetBorderAndTitleBar(false, false);
            presenter.IsAlwaysOnTop = true;
            presenter.IsResizable = false;
        }

        window.AppWindow.TitleBar.ExtendsContentIntoTitleBar = true;
        if (AppWindowTitleBar.IsCustomizationSupported())
        {
            window.AppWindow.TitleBar.ButtonBackgroundColor = Colors.Transparent;
            window.AppWindow.TitleBar.ButtonInactiveBackgroundColor = Colors.Transparent;
        }

        PositionBottomCenter(window);
    }

    public static void PositionBottomCenter(Window window)
    {
        const int width = 760;
        const int height = 188;
        var area = DisplayArea.Primary?.WorkArea ?? new RectInt32(0, 0, 1280, 800);
        var x = area.X + (area.Width - width) / 2;
        var y = area.Y + (int)(area.Height * 0.12);
        window.AppWindow.MoveAndResize(new RectInt32(x, y, width, height));
    }
}
