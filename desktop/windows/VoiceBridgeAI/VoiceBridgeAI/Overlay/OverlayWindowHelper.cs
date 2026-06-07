using Microsoft.UI;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml;
using System.Runtime.InteropServices;
using WinRT.Interop;

namespace VoiceBridgeAI.Overlay;

public static class OverlayWindowHelper
{
    private static readonly IntPtr HWND_TOPMOST = new(-1);
    private const uint SWP_SHOWWINDOW = 0x0040;

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

        var workArea = GetPrimaryWorkArea();
        var x = workArea.Left + (workArea.Width - width) / 2;
        var y = workArea.Top + (int)(workArea.Height * 0.12);

        var hwnd = WindowNative.GetWindowHandle(window);
        if (hwnd == IntPtr.Zero)
        {
            return;
        }

        SetWindowPos(hwnd, HWND_TOPMOST, x, y, width, height, SWP_SHOWWINDOW);
    }

    private static RECT GetPrimaryWorkArea()
    {
        var area = new RECT();
        if (!SystemParametersInfo(SPI_GETWORKAREA, 0, ref area, 0))
        {
            area = new RECT { Left = 0, Top = 0, Right = 1280, Bottom = 800 };
        }

        return area;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct RECT
    {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;

        public int Width => Right - Left;
        public int Height => Bottom - Top;
    }

    private const uint SPI_GETWORKAREA = 0x0030;

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool SystemParametersInfo(uint uiAction, uint uiParam, ref RECT pvParam, uint fWinIni);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool SetWindowPos(
        IntPtr hWnd,
        IntPtr hWndInsertAfter,
        int x,
        int y,
        int cx,
        int cy,
        uint uFlags);
}
