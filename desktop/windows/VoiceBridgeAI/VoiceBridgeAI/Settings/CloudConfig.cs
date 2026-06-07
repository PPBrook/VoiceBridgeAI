using System.Text.Json;

namespace VoiceBridgeAI.Settings;

public readonly record struct CloudProviderTest(string Label, string Layer, string ProviderId)
{
    public string Key => $"{Layer}:{ProviderId}";
}

public static class CloudProviderRegistry
{
    public static readonly string[] DomesticOrder = ["tencent", "qiniu", "aliyun", "baidu", "deepseek"];
    public static readonly string[] OverseasOrder = ["openai", "deepl", "google"];

    private static readonly Dictionary<string, CloudProviderTest[]> TestsByProvider = new()
    {
        ["tencent"] =
        [
            new("识别", "asr", "tencent"),
            new("句中 TMT", "partial", "tmt"),
            new("句末 TMT", "final", "tmt"),
        ],
        ["qiniu"] =
        [
            new("句中", "partial", "qiniu"),
            new("句末", "final", "qiniu"),
        ],
        ["aliyun"] =
        [
            new("句中", "partial", "aliyun"),
            new("句末", "final", "aliyun"),
        ],
        ["baidu"] =
        [
            new("句中", "partial", "baidu"),
            new("句末", "final", "baidu"),
        ],
        ["deepseek"] =
        [
            new("句中", "partial", "deepseek"),
            new("句末", "final", "deepseek"),
        ],
        ["openai"] =
        [
            new("识别", "asr", "openai"),
            new("句中", "partial", "openai"),
            new("句末", "final", "openai"),
        ],
        ["deepl"] =
        [
            new("句中", "partial", "deepl"),
            new("句末", "final", "deepl"),
        ],
        ["google"] =
        [
            new("句中", "partial", "google"),
            new("句末", "final", "google"),
        ],
    };

    private static readonly Dictionary<string, string> Titles = new()
    {
        ["tencent"] = "腾讯云",
        ["qiniu"] = "七牛 AI",
        ["aliyun"] = "阿里云",
        ["baidu"] = "百度翻译",
        ["deepseek"] = "DeepSeek",
        ["openai"] = "OpenAI",
        ["deepl"] = "DeepL",
        ["google"] = "Google 在线",
    };

    public static IReadOnlyList<CloudProviderTest> TestsFor(string providerId) =>
        TestsByProvider.TryGetValue(providerId, out var tests) ? tests : Array.Empty<CloudProviderTest>();

    public static string TitleFor(string providerId) =>
        Titles.TryGetValue(providerId, out var title) ? title : providerId;
}

public sealed class CloudCredentialsForm
{
    public string TencentAppId { get; set; } = "";
    public string TencentSecretId { get; set; } = "";
    public string TencentSecretKey { get; set; } = "";
    public string TencentEngine { get; set; } = "";
    public string TencentRegion { get; set; } = "";
    public string TencentProject { get; set; } = "";

    public string QiniuApiKey { get; set; } = "";
    public string QiniuBaseUrl { get; set; } = "";
    public string QiniuModel { get; set; } = "";

    public string AliyunApiKey { get; set; } = "";
    public string AliyunBaseUrl { get; set; } = "";
    public string AliyunModel { get; set; } = "";

    public string BaiduAppId { get; set; } = "";
    public string BaiduSecretKey { get; set; } = "";

    public string DeeplApiKey { get; set; } = "";

    public string DeepseekApiKey { get; set; } = "";
    public string DeepseekBaseUrl { get; set; } = "";
    public string DeepseekModel { get; set; } = "";

    public string OpenaiApiKey { get; set; } = "";
    public string OpenaiBaseUrl { get; set; } = "";
    public string OpenaiModel { get; set; } = "";
    public string OpenaiAsrModel { get; set; } = "";

    public void BindFrom(JsonElement health)
    {
        BindProvider(health, "tencent", dict =>
        {
            TencentAppId = ReadString(dict, "appId");
            TencentEngine = ReadString(dict, "engine");
            TencentRegion = ReadString(dict, "tmtRegion");
            TencentProject = ReadString(dict, "tmtProjectId");
            TencentSecretId = "";
            TencentSecretKey = "";
        }, hasSecretId: "hasSecretId", hasSecretKey: "hasSecretKey");

        BindProvider(health, "qiniu", dict =>
        {
            QiniuBaseUrl = ReadString(dict, "baseUrl");
            QiniuModel = ReadString(dict, "model");
            QiniuApiKey = "";
        }, hasApiKey: "hasApiKey");

        BindProvider(health, "aliyun", dict =>
        {
            AliyunBaseUrl = ReadString(dict, "baseUrl");
            AliyunModel = ReadString(dict, "model");
            AliyunApiKey = "";
        }, hasApiKey: "hasApiKey");

        BindProvider(health, "baidu", dict =>
        {
            BaiduAppId = ReadString(dict, "appId");
            BaiduSecretKey = "";
        }, hasSecretKey: "hasSecretKey");

        BindProvider(health, "deepl", _ =>
        {
            DeeplApiKey = "";
        }, hasApiKey: "hasApiKey");

        BindProvider(health, "deepseek", dict =>
        {
            DeepseekBaseUrl = ReadString(dict, "baseUrl");
            DeepseekModel = ReadString(dict, "model");
            DeepseekApiKey = "";
        }, hasApiKey: "hasApiKey");

        BindProvider(health, "openai", dict =>
        {
            OpenaiBaseUrl = ReadString(dict, "baseUrl");
            OpenaiModel = ReadString(dict, "model");
            OpenaiAsrModel = ReadString(dict, "asrModel");
            OpenaiApiKey = "";
        }, hasApiKey: "hasApiKey");
    }

    public Dictionary<string, object> ToPayload()
    {
        var payload = new Dictionary<string, object>();
        PutProvider(payload, "tencent", new Dictionary<string, object>
        {
            ["appId"] = TencentAppId,
            ["secretId"] = TencentSecretId,
            ["secretKey"] = TencentSecretKey,
            ["engine"] = TencentEngine,
            ["tmtRegion"] = TencentRegion,
            ["tmtProjectId"] = TencentProject,
        });
        PutProvider(payload, "qiniu", new Dictionary<string, object>
        {
            ["apiKey"] = QiniuApiKey,
            ["baseUrl"] = QiniuBaseUrl,
            ["model"] = QiniuModel,
        });
        PutProvider(payload, "aliyun", new Dictionary<string, object>
        {
            ["apiKey"] = AliyunApiKey,
            ["baseUrl"] = AliyunBaseUrl,
            ["model"] = AliyunModel,
        });
        PutProvider(payload, "baidu", new Dictionary<string, object>
        {
            ["appId"] = BaiduAppId,
            ["secretKey"] = BaiduSecretKey,
        });
        PutProvider(payload, "deepl", new Dictionary<string, object>
        {
            ["apiKey"] = DeeplApiKey,
        });
        PutProvider(payload, "deepseek", new Dictionary<string, object>
        {
            ["apiKey"] = DeepseekApiKey,
            ["baseUrl"] = DeepseekBaseUrl,
            ["model"] = DeepseekModel,
        });
        PutProvider(payload, "openai", new Dictionary<string, object>
        {
            ["apiKey"] = OpenaiApiKey,
            ["baseUrl"] = OpenaiBaseUrl,
            ["model"] = OpenaiModel,
            ["asrModel"] = OpenaiAsrModel,
        });
        return payload;
    }

    public void ClearSecrets()
    {
        TencentSecretId = "";
        TencentSecretKey = "";
        QiniuApiKey = "";
        AliyunApiKey = "";
        BaiduSecretKey = "";
        DeeplApiKey = "";
        DeepseekApiKey = "";
        OpenaiApiKey = "";
    }

    public static bool IsVerified(JsonElement health, string layer, string providerId)
    {
        if (!health.TryGetProperty("verified", out var verified))
        {
            return false;
        }

        if (!verified.TryGetProperty(layer, out var array) || array.ValueKind != JsonValueKind.Array)
        {
            return false;
        }

        foreach (var item in array.EnumerateArray())
        {
            if (item.GetString() == providerId)
            {
                return true;
            }
        }

        return false;
    }

    private static void BindProvider(
        JsonElement health,
        string key,
        Action<JsonElement> apply,
        string? hasSecretId = null,
        string? hasSecretKey = null,
        string? hasApiKey = null)
    {
        if (!health.TryGetProperty(key, out var dict))
        {
            return;
        }

        apply(dict);
        _ = hasSecretId;
        _ = hasSecretKey;
        _ = hasApiKey;
    }

    private static string ReadString(JsonElement obj, string property)
    {
        if (!obj.TryGetProperty(property, out var el))
        {
            return "";
        }

        return el.ValueKind switch
        {
            JsonValueKind.String => el.GetString() ?? "",
            JsonValueKind.Number => el.ToString(),
            JsonValueKind.True => "true",
            JsonValueKind.False => "false",
            _ => "",
        };
    }

    private static void PutProvider(Dictionary<string, object> payload, string key, Dictionary<string, object> fields)
    {
        var trimmed = new Dictionary<string, object>();
        foreach (var (name, value) in fields)
        {
            if (value is string text && !string.IsNullOrWhiteSpace(text))
            {
                trimmed[name] = text.Trim();
            }
        }

        if (trimmed.Count > 0)
        {
            payload[key] = trimmed;
        }
    }
}

public sealed class CloudStore
{
    public async Task<string> SaveAsync(CloudCredentialsForm form, CancellationToken ct = default)
    {
        using var doc = await ApiClient.PostJsonAsync("api/cloud/settings", form.ToPayload(), ct);
        var root = doc.RootElement;
        if (root.TryGetProperty("ok", out var okEl) && okEl.ValueKind == JsonValueKind.False)
        {
            var message = ReadErrors(root) ?? "保存失败";
            throw new InvalidOperationException(message);
        }

        SettingsStore.Shared.MergeHealth(root);
        return "密钥已保存到 .env";
    }

    public async Task<(bool Ok, string Message)> TestAsync(
        string layer,
        string providerId,
        CloudCredentialsForm form,
        CancellationToken ct = default)
    {
        var body = form.ToPayload();
        body["layer"] = layer;
        body["providerId"] = providerId;
        try
        {
            using var doc = await ApiClient.PostJsonAsync("api/cloud/test", body, ct);
            var root = doc.RootElement;
            SettingsStore.Shared.MergeHealth(root);
            var ok = root.TryGetProperty("ok", out var okEl) && okEl.GetBoolean();
            var message = root.TryGetProperty("message", out var msgEl)
                ? msgEl.GetString() ?? (ok ? "已通过" : "失败")
                : ok ? "已通过" : "失败";
            return (ok, message);
        }
        catch (Exception ex)
        {
            return (false, ex.Message);
        }
    }

    public async Task<(string Summary, IReadOnlyList<(string Key, bool Ok, string Message)> Results)> TestAllAsync(
        CloudCredentialsForm form,
        CancellationToken ct = default)
    {
        try
        {
            using var doc = await ApiClient.PostJsonAsync("api/cloud/test-all", form.ToPayload(), ct);
            var root = doc.RootElement;
            SettingsStore.Shared.MergeHealth(root);
            var summary = root.TryGetProperty("message", out var msgEl)
                ? msgEl.GetString() ?? "测试完成"
                : "测试完成";

            var list = new List<(string, bool, string)>();
            if (root.TryGetProperty("results", out var results) && results.ValueKind == JsonValueKind.Array)
            {
                foreach (var item in results.EnumerateArray())
                {
                    var layer = item.TryGetProperty("layer", out var layerEl) ? layerEl.GetString() ?? "" : "";
                    var providerId = item.TryGetProperty("providerId", out var idEl) ? idEl.GetString() ?? "" : "";
                    var ok = item.TryGetProperty("ok", out var okEl) && okEl.GetBoolean();
                    var message = item.TryGetProperty("message", out var mEl)
                        ? mEl.GetString() ?? (ok ? "已通过" : "失败")
                        : ok ? "已通过" : "失败";
                    if (!string.IsNullOrEmpty(layer) && !string.IsNullOrEmpty(providerId))
                    {
                        list.Add(($"{layer}:{providerId}", ok, message));
                    }
                }
            }

            return (summary, list);
        }
        catch (Exception ex)
        {
            return (ex.Message, Array.Empty<(string, bool, string)>());
        }
    }

    private static string? ReadErrors(JsonElement root)
    {
        if (!root.TryGetProperty("errors", out var errors) || errors.ValueKind != JsonValueKind.Array)
        {
            return null;
        }

        var parts = errors.EnumerateArray()
            .Select(e => e.GetString())
            .Where(s => !string.IsNullOrWhiteSpace(s));
        return string.Join("\n", parts);
    }
}
