using System.Collections;

namespace VoiceBridgeAI;

public static class SidecarLaunch
{
    public sealed record Plan(
        string Executable,
        IReadOnlyList<string> Arguments,
        string WorkingDirectory,
        IReadOnlyDictionary<string, string> Environment,
        string ModeLabel);

    public static Plan? CreatePlan()
    {
        return CreateBundledPlan() ?? CreateDevPlan();
    }

    private static Plan? CreateBundledPlan()
    {
        var resources = AppContext.BaseDirectory.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        var script = Path.Combine(resources, "run-server.ps1");
        var venvPython = Path.Combine(resources, "python-venv", "Scripts", "python.exe");

        if (!File.Exists(script) || !File.Exists(venvPython))
        {
            return null;
        }

        try
        {
            AppSupport.EnsureLayout();
        }
        catch
        {
            return null;
        }

        var env = CopyEnvironment();
        env["VOICEBRIDGE_DATA_DIR"] = AppSupport.DataDirectory;
        env["VOICEBRIDGE_PORT"] = AppSettings.Port.ToString();
        ApplyBundleVariant(env);

        return new Plan(
            Executable: ResolvePowerShell(),
            Arguments: ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", script],
            WorkingDirectory: resources,
            Environment: env,
            ModeLabel: "bundled");
    }

    private static Plan? CreateDevPlan()
    {
        var root = RepoRoot.Find();
        if (root is null)
        {
            return null;
        }

        var runPs1 = Path.Combine(root, "run.ps1");
        if (!File.Exists(runPs1))
        {
            return null;
        }

        var env = CopyEnvironment();
        env["VOICEBRIDGE_PORT"] = AppSettings.Port.ToString();
        env["VOICEBRIDGE_DATA_DIR"] = root;
        ApplyBundleVariant(env);

        return new Plan(
            Executable: ResolvePowerShell(),
            Arguments: ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", runPs1],
            WorkingDirectory: root,
            Environment: env,
            ModeLabel: "dev");
    }

    private static Dictionary<string, string> CopyEnvironment()
    {
        var env = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        foreach (DictionaryEntry entry in System.Environment.GetEnvironmentVariables())
        {
            if (entry.Key is string key && entry.Value is string value)
            {
                env[key] = value;
            }
        }

        return env;
    }

    private static void ApplyBundleVariant(IDictionary<string, string> env)
    {
        switch (BundleVariant.Current)
        {
            case BundleVariant.Kind.Cloud:
                env["VOICEBRIDGE_BUNDLE_VARIANT"] = "cloud";
                env["VOICEBRIDGE_OPTIONAL_LOCAL_MODELS"] = "1";
                break;
            case BundleVariant.Kind.Local:
                env["VOICEBRIDGE_BUNDLE_VARIANT"] = "local";
                env["VOICEBRIDGE_OPTIONAL_LOCAL_MODELS"] = "0";
                break;
            default:
                env["VOICEBRIDGE_OPTIONAL_LOCAL_MODELS"] = "1";
                break;
        }
    }

    private static string ResolvePowerShell()
    {
        var systemRoot = Environment.GetFolderPath(Environment.SpecialFolder.System);
        var pwsh = Path.Combine(systemRoot, "..", "SysNative", "WindowsPowerShell", "v1.0", "powershell.exe");
        if (File.Exists(pwsh))
        {
            return Path.GetFullPath(pwsh);
        }

        pwsh = Path.Combine(systemRoot, "WindowsPowerShell", "v1.0", "powershell.exe");
        if (File.Exists(pwsh))
        {
            return pwsh;
        }

        return "powershell.exe";
    }
}
