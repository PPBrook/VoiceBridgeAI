using System.Text;
using System.Text.Json;

namespace VoiceBridgeAI.Settings;

public static class ApiClient
{
    private static readonly HttpClient Http = new() { Timeout = TimeSpan.FromSeconds(30) };

    public static async Task<JsonDocument?> GetJsonAsync(string path, CancellationToken ct = default)
    {
        var response = await Http.GetAsync(new Uri(AppSettings.BaseUri, path), ct);
        if (!response.IsSuccessStatusCode)
        {
            return null;
        }

        await using var stream = await response.Content.ReadAsStreamAsync(ct);
        return await JsonDocument.ParseAsync(stream, cancellationToken: ct);
    }

    public static async Task<JsonDocument> PostJsonAsync(string path, object body, CancellationToken ct = default)
    {
        var json = JsonSerializer.Serialize(body);
        using var content = new StringContent(json, Encoding.UTF8, "application/json");
        var response = await Http.PostAsync(new Uri(AppSettings.BaseUri, path), content, ct);
        await using var stream = await response.Content.ReadAsStreamAsync(ct);
        return await JsonDocument.ParseAsync(stream, cancellationToken: ct);
    }
}

public readonly record struct ProviderOption(string Id, string Label)
{
    public static IReadOnlyList<ProviderOption> List(JsonElement health, string key)
    {
        if (!health.TryGetProperty(key, out var array) || array.ValueKind != JsonValueKind.Array)
        {
            return Array.Empty<ProviderOption>();
        }

        var list = new List<ProviderOption>();
        foreach (var item in array.EnumerateArray())
        {
            if (!item.TryGetProperty("id", out var idEl))
            {
                continue;
            }

            var id = idEl.GetString();
            if (string.IsNullOrEmpty(id))
            {
                continue;
            }

            var label = item.TryGetProperty("label", out var labelEl) ? labelEl.GetString() ?? id : id;
            list.Add(new ProviderOption(id, label));
        }

        return list;
    }
}

public sealed class EngineConfig
{
    public string InputMode { get; set; } = "audio";
    public string AsrProvider { get; set; } = "local";
    public string PartialProvider { get; set; } = "argos";
    public string FinalProvider { get; set; } = "argos";
    public string ReviseMode { get; set; } = "speech";
    public int SampleRate { get; set; } = 48000;

    public static EngineConfig FromHealth(JsonElement health)
    {
        var cfg = new EngineConfig();
        if (health.TryGetProperty("asrProvider", out var asrEl))
        {
            cfg.AsrProvider = asrEl.GetString() ?? cfg.AsrProvider;
        }
        else if (health.TryGetProperty("asrMode", out var modeEl))
        {
            cfg.AsrProvider = modeEl.GetString() ?? cfg.AsrProvider;
        }

        if (health.TryGetProperty("partialProvider", out var partialEl))
        {
            cfg.PartialProvider = partialEl.GetString() ?? cfg.PartialProvider;
        }

        if (health.TryGetProperty("finalProvider", out var finalEl))
        {
            cfg.FinalProvider = finalEl.GetString() ?? cfg.FinalProvider;
        }

        if (health.TryGetProperty("reviseMode", out var reviseEl))
        {
            cfg.ReviseMode = reviseEl.GetString() ?? cfg.ReviseMode;
        }

        return cfg;
    }

    public Dictionary<string, object> ToEnginePayload() => new()
    {
        ["asrMode"] = AsrProvider,
        ["asrProvider"] = AsrProvider,
        ["partialProvider"] = PartialProvider,
        ["finalProvider"] = FinalProvider,
        ["reviseMode"] = ReviseMode,
    };

    public Dictionary<string, object> ToWsPayload() => new()
    {
        ["type"] = "config",
        ["sampleRate"] = SampleRate,
        ["inputMode"] = InputMode,
        ["asrMode"] = AsrProvider,
        ["asrProvider"] = AsrProvider,
        ["partialProvider"] = PartialProvider,
        ["finalProvider"] = FinalProvider,
        ["reviseMode"] = ReviseMode,
    };

    public string Summary(JsonElement health)
    {
        string Label(string key, string id) =>
            ProviderOption.List(health, key).FirstOrDefault(p => p.Id == id).Label ?? id;

        var asr = Label("asrModes", AsrProvider);
        var partial = Label("partialProviders", PartialProvider);
        var final = Label("finalProviders", FinalProvider);
        var revise = Label("reviseModes", ReviseMode);
        return $"{ShortName(asr)} → {ShortName(partial)} → {ShortName(final)} · {ShortName(revise)}";
    }

    private static string ShortName(string label) =>
        label.Split('·', 2)[0].Trim();
}

public sealed class SettingsStore
{
    public static SettingsStore Shared { get; } = new();

    private JsonDocument? _healthDoc;
    public JsonElement Health => _healthDoc?.RootElement ?? throw new InvalidOperationException("Health not loaded");
    public EngineConfig Engine { get; private set; } = new();

    public async Task RefreshAsync(CancellationToken ct = default)
    {
        using var doc = await ApiClient.GetJsonAsync("api/health", ct)
            ?? throw new InvalidOperationException("无法读取引擎配置");

        _healthDoc?.Dispose();
        _healthDoc = JsonDocument.Parse(doc.RootElement.GetRawText());
        Engine = EngineConfig.FromHealth(_healthDoc.RootElement);
    }

    public async Task<string> SaveEngineAsync(EngineConfig engine, CancellationToken ct = default)
    {
        using var doc = await ApiClient.PostJsonAsync("api/engine/settings", engine.ToEnginePayload(), ct);
        _healthDoc?.Dispose();
        _healthDoc = JsonDocument.Parse(doc.RootElement.GetRawText());
        Engine = EngineConfig.FromHealth(_healthDoc.RootElement);
        return "引擎已保存";
    }
}
