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

    public static string BootstrapLogPath
    {
        get
        {
            var root = RepoRoot.Find();
            return root is not null
                ? Path.Combine(root, "sidecar-bootstrap.log")
                : Path.Combine(AppSupport.DataDirectory, "sidecar-bootstrap.log");
        }
    }

    public static Plan? CreatePlan()
    {
        return CreateBundledPlan() ?? CreateDevDirectPythonPlan() ?? CreateDevScriptPlan();
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
            Executable: venvPython,
            Arguments: ["main.py"],
            WorkingDirectory: Path.Combine(resources, "server"),
            Environment: env,
            ModeLabel: "bundled");
    }

    /// <summary>Prefer direct .venv python (no PowerShell pipe deadlock).</summary>
    private static Plan? CreateDevDirectPythonPlan()
    {
        var root = RepoRoot.Find();
        if (root is null)
        {
            return null;
        }

        var venvPython = Path.Combine(root, ".venv", "Scripts", "python.exe");
        var mainPy = Path.Combine(root, "server", "main.py");
        if (!File.Exists(venvPython) || !File.Exists(mainPy))
        {
            return null;
        }

        var env = BuildDevEnvironment(root);
        PrependPath(env, Path.GetDirectoryName(venvPython)!);

        return new Plan(
            Executable: venvPython,
            Arguments: ["main.py"],
            WorkingDirectory: Path.Combine(root, "server"),
            Environment: env,
            ModeLabel: "dev");
    }

    private static Plan? CreateDevScriptPlan()
    {
        var root = RepoRoot.Find();
        if (root is null)
        {
            return null;
        }

        var sidecarScript = Path.Combine(root, "desktop", "windows", "scripts", "start-engine-sidecar.ps1");
        if (!File.Exists(sidecarScript))
        {
            var runPs1 = Path.Combine(root, "run.ps1");
            if (!File.Exists(runPs1))
            {
                return null;
            }

            sidecarScript = runPs1;
        }

        var env = BuildDevEnvironment(root);
        InjectCommonPythonPaths(env);

        return new Plan(
            Executable: ResolvePowerShell(),
            Arguments: ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", sidecarScript],
            WorkingDirectory: root,
            Environment: env,
            ModeLabel: "dev-setup");
    }

    private static Dictionary<string, string> BuildDevEnvironment(string root)
    {
        var env = CopyEnvironment();
        env["VOICEBRIDGE_PORT"] = AppSettings.Port.ToString();
        env["VOICEBRIDGE_DATA_DIR"] = root;
        var repoRoot = RepoRoot.Find();
        if (repoRoot is not null)
        {
            env["VOICEBRIDGE_ROOT"] = repoRoot;
        }

        ApplyBundleVariant(env);
        return env;
    }

    private static void PrependPath(IDictionary<string, string> env, string directory)
    {
        env.TryGetValue("PATH", out var path);
        env["PATH"] = string.IsNullOrEmpty(path) ? directory : $"{directory};{path}";
    }

    private static void InjectCommonPythonPaths(IDictionary<string, string> env)
    {
        var candidates = new[]
        {
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Programs", "Python", "Python312"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Programs", "Python", "Python311"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Programs", "Python", "Python310"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "Python312"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "Python311"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "Python310"),
            Environment.GetFolderPath(Environment.SpecialFolder.Windows),
        };

        var prefix = string.Join(";", candidates.Where(Directory.Exists));
        if (string.IsNullOrEmpty(prefix))
        {
            return;
        }

        env.TryGetValue("PATH", out var path);
        env["PATH"] = string.IsNullOrEmpty(path) ? prefix : $"{prefix};{path}";
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

    public static string? ReadBootstrapLogTail(int maxLines = 12)
    {
        try
        {
            var path = BootstrapLogPath;
            if (!File.Exists(path))
            {
                return null;
            }

            var lines = File.ReadAllLines(path);
            if (lines.Length == 0)
            {
                return null;
            }

            return string.Join('\n', lines.TakeLast(maxLines));
        }
        catch
        {
            return null;
        }
    }
}
