using System.Text.Json;

namespace VoiceBridgeAI.Overlay;

public static class OverlayPreferences
{
    private const string FileName = "overlay-prefs.json";
    private static readonly object Gate = new();
    private static OverlayPrefsData? _cache;

    public static event Action? Changed;

    /// <summary>背景不透明度 0.15～1.0，默认 0.78。</summary>
    public static double BackgroundOpacity
    {
        get => Clamp(Load().BackgroundOpacity, 0.15, 1.0, 0.78);
        set
        {
            var clamped = Clamp(value, 0.15, 1.0, 0.78);
            if (Math.Abs(Load().BackgroundOpacity - clamped) < 0.0001)
            {
                return;
            }

            Load().BackgroundOpacity = clamped;
            Persist();
            Changed?.Invoke();
        }
    }

    /// <summary>字幕文字不透明度 0.25～1.0，默认 1.0。</summary>
    public static double TextOpacity
    {
        get => Clamp(Load().TextOpacity, 0.25, 1.0, 1.0);
        set
        {
            var clamped = Clamp(value, 0.25, 1.0, 1.0);
            if (Math.Abs(Load().TextOpacity - clamped) < 0.0001)
            {
                return;
            }

            Load().TextOpacity = clamped;
            Persist();
            Changed?.Invoke();
        }
    }

    public static bool ShowEnglish
    {
        get => Load().ShowEnglish;
        set
        {
            if (Load().ShowEnglish == value)
            {
                return;
            }

            Load().ShowEnglish = value;
            Persist();
            Changed?.Invoke();
        }
    }

    public static (int X, int Y)? SavedPosition
    {
        get
        {
            var data = Load();
            if (data.PosX is int x && data.PosY is int y)
            {
                return (x, y);
            }

            return null;
        }
    }

    public static void SavePosition(int x, int y)
    {
        var data = Load();
        if (data.PosX == x && data.PosY == y)
        {
            return;
        }

        data.PosX = x;
        data.PosY = y;
        Persist();
    }

    private static OverlayPrefsData Load()
    {
        lock (Gate)
        {
            if (_cache is not null)
            {
                return _cache;
            }

            _cache = ReadFromDisk();
            return _cache;
        }
    }

    private static void Persist()
    {
        lock (Gate)
        {
            if (_cache is null)
            {
                return;
            }

            WriteToDisk(_cache);
        }
    }

    private static OverlayPrefsData ReadFromDisk()
    {
        try
        {
            Directory.CreateDirectory(AppSupport.DataDirectory);
            var path = PrefsPath();
            if (!File.Exists(path))
            {
                return new OverlayPrefsData();
            }

            var json = File.ReadAllText(path);
            return JsonSerializer.Deserialize<OverlayPrefsData>(json) ?? new OverlayPrefsData();
        }
        catch
        {
            return new OverlayPrefsData();
        }
    }

    private static void WriteToDisk(OverlayPrefsData data)
    {
        try
        {
            Directory.CreateDirectory(AppSupport.DataDirectory);
            var json = JsonSerializer.Serialize(data);
            File.WriteAllText(PrefsPath(), json);
        }
        catch
        {
            // Preference persistence failure should not crash the app.
        }
    }

    private static string PrefsPath() => Path.Combine(AppSupport.DataDirectory, FileName);

    private static double Clamp(double value, double min, double max, double fallback) =>
        double.IsNaN(value) ? fallback : Math.Min(max, Math.Max(min, value));

    private sealed class OverlayPrefsData
    {
        public double BackgroundOpacity { get; set; } = 0.78;
        public double TextOpacity { get; set; } = 1.0;
        public bool ShowEnglish { get; set; } = true;
        public int? PosX { get; set; }
        public int? PosY { get; set; }
    }
}
