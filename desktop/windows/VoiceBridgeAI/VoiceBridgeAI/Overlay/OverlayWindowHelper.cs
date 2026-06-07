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
    private const int GWL_EXSTYLE = -20;
    private const int WS_EX_LAYERED = 0x00080000;
    private const int DWMWA_SYSTEMBACKDROP_TYPE = 38;
    private const int DWMSBT_NONE = 3;
    public const int DefaultWidth = 760;
    public const int DefaultHeight = 212;

    public static void ConfigureOverlay(Window window)
    {
        window.ExtendsContentIntoTitleBar = true;

        try
        {
            window.SystemBackdrop = null;
        }
        catch
        {
            // Older Windows builds may not expose SystemBackdrop.
        }

        if (window.AppWindow.Presenter is OverlappedPresenter presenter)
        {
            presenter.SetBorderAndTitleBar(false, false);
            presenter.IsAlwaysOnTop = true;
            presenter.IsResizable = false;
        }

        var titleBar = window.AppWindow.TitleBar;
        titleBar.ExtendsContentIntoTitleBar = true;
        if (AppWindowTitleBar.IsCustomizationSupported())
        {
            titleBar.ButtonBackgroundColor = Colors.Transparent;
            titleBar.ButtonInactiveBackgroundColor = Colors.Transparent;
            titleBar.BackgroundColor = Colors.Transparent;
            titleBar.InactiveBackgroundColor = Colors.Transparent;
        }

        EnableTransparentWindowChrome(window);

        window.AppWindow.Changed += (_, args) =>
        {
            if (args.DidPositionChange)
            {
                SavePosition(window);
            }
        };

        PositionOverlay(window);
    }

    private static void EnableTransparentWindowChrome(Window window)
    {
        var hwnd = WindowNative.GetWindowHandle(window);
        if (hwnd == IntPtr.Zero)
        {
            return;
        }

        var exStyle = GetWindowLong(hwnd, GWL_EXSTYLE);
        SetWindowLong(hwnd, GWL_EXSTYLE, exStyle | WS_EX_LAYERED);

        var margins = new MARGINS { Left = -1, Right = -1, Top = -1, Bottom = -1 };
        _ = DwmExtendFrameIntoClientArea(hwnd, ref margins);

        var backdrop = DWMSBT_NONE;
        _ = DwmSetWindowAttribute(hwnd, DWMWA_SYSTEMBACKDROP_TYPE, ref backdrop, Marshal.SizeOf<int>());
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
    private struct MARGINS
    {
        public int Left;
        public int Right;
        public int Top;
        public int Bottom;
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
    private static extern int GetWindowLong(IntPtr hWnd, int nIndex);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern int SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);

    [DllImport("dwmapi.dll")]
    private static extern int DwmExtendFrameIntoClientArea(IntPtr hWnd, ref MARGINS margins);

    [DllImport("dwmapi.dll")]
    private static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int attrValue, int attrSize);

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
