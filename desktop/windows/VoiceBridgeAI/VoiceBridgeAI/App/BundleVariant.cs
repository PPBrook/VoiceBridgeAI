namespace VoiceBridgeAI;

/// <summary>Build flavor: cloud | local | standard (mirrors macOS BundleVariant).</summary>
public static class BundleVariant
{
    public enum Kind
    {
        Cloud,
        Local,
        Standard,
    }

    public static Kind Current { get; } = Resolve();

    public static bool IncludesLocalModels => Current != Kind.Cloud;

    public static string AppSupportFolderName => Current switch
    {
        Kind.Cloud => "VoiceBridgeAI-Cloud",
        Kind.Local => "VoiceBridgeAI-Local",
        _ => "VoiceBridgeAI",
    };

    public static string DisplaySuffix => Current switch
    {
        Kind.Cloud => "（云端）",
        Kind.Local => "（本地）",
        _ => "",
    };

    private static Kind Resolve()
    {
        var fromEnv = Environment.GetEnvironmentVariable("VOICEBRIDGE_BUNDLE_VARIANT");
        if (TryParse(fromEnv, out var envKind))
        {
            return envKind;
        }

        var marker = Path.Combine(AppContext.BaseDirectory, "bundle-variant.txt");
        if (File.Exists(marker))
        {
            var text = File.ReadAllText(marker).Trim();
            if (TryParse(text, out var fileKind))
            {
                return fileKind;
            }
        }

        return Kind.Standard;
    }

    private static bool TryParse(string? raw, out Kind kind)
    {
        kind = Kind.Standard;
        if (string.IsNullOrWhiteSpace(raw))
        {
            return false;
        }

        return raw.Trim().ToLowerInvariant() switch
        {
            "cloud" => Assign(Kind.Cloud, out kind),
            "local" => Assign(Kind.Local, out kind),
            _ => false,
        };
    }

    private static bool Assign(Kind value, out Kind kind)
    {
        kind = value;
        return true;
    }
}
