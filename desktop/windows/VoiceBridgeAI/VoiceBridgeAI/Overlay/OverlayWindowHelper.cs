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
    public const int DefaultWidth = 760;
    public const int DefaultHeight = 212;

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

        window.AppWindow.Changed += (_, args) =>
        {
            if (args.DidPositionChange)
            {
                SavePosition(window);
            }
        };

        PositionOverlay(window);
    }

    public static void PositionOverlay(Window window)
    {
        var saved = OverlayPreferences.SavedPosition;
        if (saved is { } pos)
        {
            SetWindowPosition(window, pos.X, pos.Y);
            return;
        }

        PositionBottomCenter(window);
    }

    public static void PositionBottomCenter(Window window)
    {
        var workArea = GetPrimaryWorkArea();
        var x = workArea.Left + (workArea.Width - DefaultWidth) / 2;
        var y = workArea.Top + (int)(workArea.Height * 0.12);
        SetWindowPosition(window, x, y);
    }

    public static void SavePosition(Window window)
    {
        var hwnd = WindowNative.GetWindowHandle(window);
        if (hwnd == IntPtr.Zero)
        {
            return;
        }

        if (!GetWindowRect(hwnd, out var rect))
        {
            return;
        }

        OverlayPreferences.SavePosition(rect.Left, rect.Top);
    }

    private static void SetWindowPosition(Window window, int x, int y)
    {
        var hwnd = WindowNative.GetWindowHandle(window);
        if (hwnd == IntPtr.Zero)
        {
            return;
        }

        SetWindowPos(hwnd, HWND_TOPMOST, x, y, DefaultWidth, DefaultHeight, SWP_SHOWWINDOW);
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
    private static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

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
