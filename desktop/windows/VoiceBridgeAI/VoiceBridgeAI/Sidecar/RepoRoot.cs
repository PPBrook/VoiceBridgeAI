namespace VoiceBridgeAI;

public static class RepoRoot
{
    /// <summary>Engine repo root: contains run.ps1 (or run.sh) and server/main.py.</summary>
    public static string? Find()
    {
        var fromEnv = Environment.GetEnvironmentVariable("VOICEBRIDGE_ROOT");
        if (!string.IsNullOrWhiteSpace(fromEnv) && IsEngineRepoRoot(fromEnv))
        {
            return Path.GetFullPath(fromEnv);
        }

        var marker = Path.Combine(AppContext.BaseDirectory, "voicebridge-repo-path");
        if (File.Exists(marker))
        {
            var text = File.ReadAllText(marker).Trim();
            if (!string.IsNullOrWhiteSpace(text) && IsEngineRepoRoot(text))
            {
                return Path.GetFullPath(text);
            }
        }

        foreach (var start in SearchStartDirectories())
        {
            var found = WalkUpForEngineRoot(start);
            if (found is not null)
            {
                return found;
            }
        }

        return null;
    }

    private static bool IsEngineRepoRoot(string dir)
    {
        var runPs1 = Path.Combine(dir, "run.ps1");
        var runSh = Path.Combine(dir, "run.sh");
        var mainPy = Path.Combine(dir, "server", "main.py");
        return (File.Exists(runPs1) || File.Exists(runSh)) && File.Exists(mainPy);
    }

    private static IEnumerable<string> SearchStartDirectories()
    {
        var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        var candidates = new[]
        {
            AppContext.BaseDirectory,
            Environment.CurrentDirectory,
        };

        foreach (var path in candidates)
        {
            if (string.IsNullOrWhiteSpace(path))
            {
                continue;
            }

            var full = Path.GetFullPath(path);
            if (seen.Add(full))
            {
                yield return full;
            }
        }
    }

    private static string? WalkUpForEngineRoot(string start)
    {
        var dir = start;
        for (var i = 0; i < 10; i++)
        {
            if (IsEngineRepoRoot(dir))
            {
                return dir;
            }

            var parent = Directory.GetParent(dir)?.FullName;
            if (parent is null || parent == dir)
            {
                break;
            }

            dir = parent;
        }

        return null;
    }
}
