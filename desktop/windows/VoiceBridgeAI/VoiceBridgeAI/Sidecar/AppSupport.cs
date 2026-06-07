namespace VoiceBridgeAI;

public static class AppSupport
{
    public static string DataDirectory
    {
        get
        {
            var appData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
            return Path.Combine(appData, BundleVariant.AppSupportFolderName);
        }
    }

    public static string ServerLogPath => Path.Combine(DataDirectory, "server.log");

    public static void EnsureLayout()
    {
        Directory.CreateDirectory(DataDirectory);

        var envPath = Path.Combine(DataDirectory, ".env");
        if (File.Exists(envPath))
        {
            return;
        }

        var bundled = BundledSeedText();
        if (bundled is not null)
        {
            File.WriteAllText(envPath, bundled);
            return;
        }

        const string seed = """
            # VoiceBridgeAI — 由 App 自动创建
            AUTO_TEST_ON_START=0
            VOICEBRIDGE_OPTIONAL_LOCAL_MODELS=1
            """;

        File.WriteAllText(envPath, seed);
    }

    private static string? BundledSeedText()
    {
        var path = Path.Combine(AppContext.BaseDirectory, "bundle-seed.env");
        return File.Exists(path) ? File.ReadAllText(path) : null;
    }
}
