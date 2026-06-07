using System.Runtime.InteropServices;

namespace VoiceBridgeAI;

internal static class StartupDiagnostics
{
    private const uint MB_OK = 0x00000000;
    private const uint MB_ICONERROR = 0x00000010;

    public static void Log(string stage, Exception ex)
    {
        var text = $"[{DateTime.Now:yyyy-MM-dd HH:mm:ss}] {stage}{Environment.NewLine}{ex}";
        try
        {
            var logDir = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "VoiceBridgeAI");
            Directory.CreateDirectory(logDir);
            File.AppendAllText(Path.Combine(logDir, "client-startup.log"), text + Environment.NewLine);
        }
        catch
        {
            // Best effort.
        }

        MessageBox(IntPtr.Zero, text, "VoiceBridgeAI 启动失败", MB_OK | MB_ICONERROR);
    }

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern int MessageBox(IntPtr hWnd, string text, string caption, uint type);
}
