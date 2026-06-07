using Windows.Storage;

namespace VoiceBridgeAI.Overlay;

public static class OverlayPreferences
{
    private const string BgKey = "overlayBackgroundOpacity";
    private const string TextKey = "overlayTextOpacity";
    private const string ShowEnglishKey = "overlayShowEnglish";
    private const string PosXKey = "overlayPosX";
    private const string PosYKey = "overlayPosY";

    public static event Action? Changed;

    private static ApplicationDataContainer Local => ApplicationData.Current.LocalSettings;

    /// <summary>背景不透明度 0.15～1.0，默认 0.78。</summary>
    public static double BackgroundOpacity
    {
        get => Clamp(ReadDouble(BgKey), 0.15, 1.0, 0.78);
        set
        {
            var clamped = Clamp(value, 0.15, 1.0, 0.78);
            Local.Values[BgKey] = clamped;
            Changed?.Invoke();
        }
    }

    /// <summary>字幕文字不透明度 0.25～1.0，默认 1.0。</summary>
    public static double TextOpacity
    {
        get => Clamp(ReadDouble(TextKey), 0.25, 1.0, 1.0);
        set
        {
            var clamped = Clamp(value, 0.25, 1.0, 1.0);
            Local.Values[TextKey] = clamped;
            Changed?.Invoke();
        }
    }

    public static bool ShowEnglish
    {
        get => !Local.Values.ContainsKey(ShowEnglishKey) || (bool)Local.Values[ShowEnglishKey];
        set
        {
            Local.Values[ShowEnglishKey] = value;
            Changed?.Invoke();
        }
    }

    public static (int X, int Y)? SavedPosition
    {
        get
        {
            if (!Local.Values.ContainsKey(PosXKey) || !Local.Values.ContainsKey(PosYKey))
            {
                return null;
            }

            return ((int)Local.Values[PosXKey], (int)Local.Values[PosYKey]);
        }
    }

    public static void SavePosition(int x, int y)
    {
        Local.Values[PosXKey] = x;
        Local.Values[PosYKey] = y;
    }

    private static double ReadDouble(string key)
    {
        if (!Local.Values.ContainsKey(key))
        {
            return double.NaN;
        }

        return Local.Values[key] switch
        {
            double d => d,
            float f => f,
            int i => i,
            _ => double.NaN,
        };
    }

    private static double Clamp(double value, double min, double max, double fallback) =>
        double.IsNaN(value) ? fallback : Math.Min(max, Math.Max(min, value));
}
