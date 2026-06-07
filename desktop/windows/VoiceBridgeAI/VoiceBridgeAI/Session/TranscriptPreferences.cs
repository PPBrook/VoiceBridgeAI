using System.Globalization;
using System.Text.Json;

namespace VoiceBridgeAI.Session;

public static class TranscriptPreferences
{
    public const string FilenameTokenHelp = "可用占位符：{prefix} {date} {time} {datetime} {mode}";

    private const string FileName = "transcript-prefs.json";
    private static readonly object Gate = new();
    private static TranscriptPrefsData? _cache;

    public static event Action? Changed;

    public enum FileFormat
    {
        Markdown,
        PlainText,
    }

    public enum ContentLayout
    {
        BilingualBlocks,
        Combined,
        EnglishOnly,
        ChineseOnly,
    }

    public static bool RecordEnabled
    {
        get => Load().RecordEnabled ?? true;
        set
        {
            if (Load().RecordEnabled == value)
            {
                return;
            }

            Load().RecordEnabled = value;
            Persist();
            Changed?.Invoke();
        }
    }

    public static string DefaultDirectory =>
        Path.Combine(AppSupport.DataDirectory, "transcripts");

    public static string StorageDirectory
    {
        get
        {
            var raw = Load().StorageDirectory?.Trim() ?? "";
            return string.IsNullOrEmpty(raw) ? DefaultDirectory : raw;
        }
        set
        {
            Load().StorageDirectory = value.Trim();
            Persist();
            Changed?.Invoke();
        }
    }

    public static bool UsesDefaultDirectory =>
        string.IsNullOrWhiteSpace(Load().StorageDirectory);

    public static void ResetDirectoryToDefault()
    {
        Load().StorageDirectory = null;
        Persist();
        Changed?.Invoke();
    }

    public static string DirectoryDisplayPath =>
        UsesDefaultDirectory ? $"默认：{DefaultDirectory}" : StorageDirectory;

    public static string FilenameTemplate
    {
        get
        {
            var stored = Load().FilenameTemplate?.Trim() ?? "";
            return string.IsNullOrEmpty(stored) ? "{prefix}_{datetime}" : stored;
        }
        set
        {
            var trimmed = value.Trim();
            Load().FilenameTemplate = string.IsNullOrEmpty(trimmed) ? "{prefix}_{datetime}" : trimmed;
            Persist();
            Changed?.Invoke();
        }
    }

    public static string FilePrefix
    {
        get
        {
            var stored = Load().FilePrefix?.Trim() ?? "";
            return string.IsNullOrEmpty(stored) ? "字幕记录" : stored;
        }
        set
        {
            var trimmed = value.Trim();
            Load().FilePrefix = string.IsNullOrEmpty(trimmed) ? "字幕记录" : trimmed;
            Persist();
            Changed?.Invoke();
        }
    }

    public static FileFormat FileFormatValue
    {
        get
        {
            var raw = Load().FileExtension?.Trim();
            if (string.IsNullOrEmpty(raw))
            {
                return FileFormat.Markdown;
            }

            return raw.Equals("plainText", StringComparison.OrdinalIgnoreCase)
                ? FileFormat.PlainText
                : FileFormat.Markdown;
        }
        set
        {
            Load().FileExtension = value == FileFormat.PlainText ? "plainText" : "markdown";
            Persist();
            Changed?.Invoke();
        }
    }

    public static ContentLayout ContentLayoutValue
    {
        get
        {
            var raw = Load().ContentLayout?.Trim();
            if (string.IsNullOrEmpty(raw)
                || !Enum.TryParse<ContentLayout>(raw, ignoreCase: true, out var layout))
            {
                return ContentLayout.BilingualBlocks;
            }

            return layout;
        }
        set
        {
            Load().ContentLayout = value.ToString();
            Persist();
            Changed?.Invoke();
        }
    }

    public static string SessionFilename(DateTime started, string modeId)
    {
        var template = FilenameTemplate;
        var prefix = SanitizePathComponent(FilePrefix);
        var mode = SanitizePathComponent(modeId);
        var culture = CultureInfo.GetCultureInfo("zh-CN");

        var date = started.ToString("yyyy-MM-dd", culture);
        var time = started.ToString("HH-mm-ss", culture);
        var datetime = started.ToString("yyyy-MM-dd_HH-mm-ss", culture);

        var name = template
            .Replace("{prefix}", prefix, StringComparison.Ordinal)
            .Replace("{date}", date, StringComparison.Ordinal)
            .Replace("{time}", time, StringComparison.Ordinal)
            .Replace("{datetime}", datetime, StringComparison.Ordinal)
            .Replace("{mode}", mode, StringComparison.Ordinal);

        name = SanitizePathComponent(name);
        if (string.IsNullOrEmpty(name))
        {
            name = $"{prefix}_{datetime}";
        }

        var ext = FileExtensionFor(FileFormatValue);
        if (!name.EndsWith("." + ext, StringComparison.OrdinalIgnoreCase))
        {
            name += "." + ext;
        }

        return name;
    }

    public static string SanitizePathComponent(string value)
    {
        var trimmed = value.Trim();
        if (string.IsNullOrEmpty(trimmed))
        {
            return "";
        }

        var invalid = new HashSet<char>(Path.GetInvalidFileNameChars())
        {
            '/', '\\', '?', '%', '*', '|', '"', '<', '>', '\n', '\r', '\t',
        };

        var chars = trimmed.Select(ch => invalid.Contains(ch) ? '_' : ch).ToArray();
        return new string(chars).Trim();
    }

    public static string LabelFor(FileFormat format) => format switch
    {
        FileFormat.Markdown => "Markdown (.md)",
        FileFormat.PlainText => "纯文本 (.txt)",
        _ => format.ToString(),
    };

    public static string LabelFor(ContentLayout layout) => layout switch
    {
        ContentLayout.BilingualBlocks => "中英对照（分区）",
        ContentLayout.Combined => "中英结合（连续）",
        ContentLayout.EnglishOnly => "纯英文",
        ContentLayout.ChineseOnly => "纯中文",
        _ => layout.ToString(),
    };

    public static string ExportSuffixFor(ContentLayout layout) => layout switch
    {
        ContentLayout.BilingualBlocks => "_dual",
        ContentLayout.Combined => "_mix",
        ContentLayout.EnglishOnly => "_en",
        ContentLayout.ChineseOnly => "_zh",
        _ => "",
    };

    public static string FileExtensionFor(FileFormat format) => format switch
    {
        FileFormat.Markdown => "md",
        FileFormat.PlainText => "txt",
        _ => "md",
    };

    private static TranscriptPrefsData Load()
    {
        lock (Gate)
        {
            return _cache ??= ReadFromDisk();
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

    private static TranscriptPrefsData ReadFromDisk()
    {
        try
        {
            Directory.CreateDirectory(AppSupport.DataDirectory);
            var path = PrefsPath();
            if (!File.Exists(path))
            {
                return new TranscriptPrefsData();
            }

            var json = File.ReadAllText(path);
            return JsonSerializer.Deserialize<TranscriptPrefsData>(json) ?? new TranscriptPrefsData();
        }
        catch
        {
            return new TranscriptPrefsData();
        }
    }

    private static void WriteToDisk(TranscriptPrefsData data)
    {
        try
        {
            Directory.CreateDirectory(AppSupport.DataDirectory);
            File.WriteAllText(PrefsPath(), JsonSerializer.Serialize(data));
        }
        catch
        {
            // Preference persistence failure should not crash the app.
        }
    }

    private static string PrefsPath() => Path.Combine(AppSupport.DataDirectory, FileName);

    private sealed class TranscriptPrefsData
    {
        public string? StorageDirectory { get; set; }
        public string? FilenameTemplate { get; set; }
        public string? FilePrefix { get; set; }
        public string? FileExtension { get; set; }
        public string? ContentLayout { get; set; }
        public bool? RecordEnabled { get; set; }
    }
}
