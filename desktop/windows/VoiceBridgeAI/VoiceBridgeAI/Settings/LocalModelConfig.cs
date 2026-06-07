using System.Text.Json;

namespace VoiceBridgeAI.Settings;

public sealed class LocalModelDownloadJob
{
    public string Id { get; init; } = "";
    public string ModelId { get; init; } = "";
    public string? WhisperModel { get; init; }
    public string? Label { get; init; }
    public string Status { get; init; } = "";
    public double Progress { get; init; }
    public string Message { get; init; } = "";
    public string? Error { get; init; }

    public static LocalModelDownloadJob? From(JsonElement dict)
    {
        if (!dict.TryGetProperty("id", out var idEl) || idEl.ValueKind != JsonValueKind.String)
        {
            return null;
        }

        if (!dict.TryGetProperty("modelId", out var modelEl) || modelEl.ValueKind != JsonValueKind.String)
        {
            return null;
        }

        if (!dict.TryGetProperty("status", out var statusEl) || statusEl.ValueKind != JsonValueKind.String)
        {
            return null;
        }

        var progress = 0.0;
        if (dict.TryGetProperty("progress", out var progressEl))
        {
            progress = progressEl.ValueKind switch
            {
                JsonValueKind.Number => progressEl.GetDouble(),
                JsonValueKind.String when double.TryParse(progressEl.GetString(), out var parsed) => parsed,
                _ => 0.0,
            };
        }

        string? whisper = dict.TryGetProperty("whisperModel", out var whisperEl) && whisperEl.ValueKind == JsonValueKind.String
            ? whisperEl.GetString()
            : null;
        string? label = dict.TryGetProperty("label", out var labelEl) && labelEl.ValueKind == JsonValueKind.String
            ? labelEl.GetString()
            : null;
        var message = dict.TryGetProperty("message", out var msgEl) && msgEl.ValueKind == JsonValueKind.String
            ? msgEl.GetString() ?? ""
            : "";
        string? error = dict.TryGetProperty("error", out var errEl) && errEl.ValueKind == JsonValueKind.String
            ? errEl.GetString()
            : null;

        return new LocalModelDownloadJob
        {
            Id = idEl.GetString() ?? "",
            ModelId = modelEl.GetString() ?? "",
            WhisperModel = whisper,
            Label = label,
            Status = statusEl.GetString() ?? "",
            Progress = progress,
            Message = message,
            Error = error,
        };
    }

    public string DisplayMessage
    {
        get
        {
            if (!string.IsNullOrWhiteSpace(Message))
            {
                return Message;
            }

            if (!string.IsNullOrWhiteSpace(Label))
            {
                var pct = (int)(Progress * 100);
                if (Status == "running" && pct is > 0 and < 100)
                {
                    return $"{Label} · 正在下载 {pct}%";
                }

                return Label;
            }

            return Status == "done" ? "下载完成" : "正在下载…";
        }
    }

    public bool IsFinished => Status is "done" or "error";
}

public static class LocalModelJson
{
    public static bool? ReadBool(JsonElement el)
    {
        return el.ValueKind switch
        {
            JsonValueKind.True => true,
            JsonValueKind.False => false,
            JsonValueKind.Number => el.GetInt32() != 0,
            JsonValueKind.String when bool.TryParse(el.GetString(), out var b) => b,
            _ => null,
        };
    }

    public static bool? ReadBool(JsonElement obj, string property)
    {
        return obj.TryGetProperty(property, out var el) ? ReadBool(el) : null;
    }

    public static string ReadString(JsonElement obj, string property)
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

    public static JsonElement? FindLocalModel(JsonElement health, string id)
    {
        if (!health.TryGetProperty("localModels", out var array) || array.ValueKind != JsonValueKind.Array)
        {
            return null;
        }

        foreach (var item in array.EnumerateArray())
        {
            if (ReadString(item, "id") == id)
            {
                return item;
            }
        }

        return null;
    }
}

public sealed class LocalModelStore
{
    public async Task<string> UpdateSettingsAsync(Dictionary<string, object> body, CancellationToken ct = default)
    {
        using var doc = await ApiClient.PostJsonAsync("api/models/local/settings", body, ct);
        var root = doc.RootElement;
        if (root.TryGetProperty("ok", out var okEl) && okEl.ValueKind == JsonValueKind.False)
        {
            throw new InvalidOperationException(ReadMessage(root, "保存失败"));
        }

        SettingsStore.Shared.MergeHealth(root);
        return ReadMessage(root, "已保存");
    }

    public async Task<LocalModelDownloadJob> StartDownloadAsync(
        string id,
        string? whisperModel,
        CancellationToken ct = default)
    {
        var body = new Dictionary<string, object> { ["id"] = id };
        if (!string.IsNullOrWhiteSpace(whisperModel))
        {
            body["whisperModel"] = whisperModel;
        }

        using var doc = await ApiClient.PostJsonAsync("api/models/local/download", body, ct);
        var root = doc.RootElement;
        SettingsStore.Shared.MergeHealth(root);
        if (root.TryGetProperty("ok", out var okEl) && okEl.ValueKind == JsonValueKind.False)
        {
            throw new InvalidOperationException(ReadMessage(root, "下载失败"));
        }

        if (!root.TryGetProperty("job", out var jobEl)
            || LocalModelDownloadJob.From(jobEl) is not { } job)
        {
            throw new InvalidOperationException("无法创建下载任务");
        }

        return job;
    }

    public async Task<LocalModelDownloadJob> PollDownloadJobAsync(string jobId, CancellationToken ct = default)
    {
        using var doc = await ApiClient.GetJsonAsync($"api/models/local/download/{jobId}", ct)
            ?? throw new InvalidOperationException("无法读取下载状态");

        var root = doc.RootElement;
        SettingsStore.Shared.MergeHealth(root);
        if (!root.TryGetProperty("job", out var jobEl)
            || LocalModelDownloadJob.From(jobEl) is not { } job)
        {
            throw new InvalidOperationException(ReadMessage(root, "下载状态无效"));
        }

        if (job.Status == "error" || (root.TryGetProperty("ok", out var okEl) && okEl.ValueKind == JsonValueKind.False))
        {
            throw new InvalidOperationException(job.Error ?? job.Message);
        }

        return job;
    }

    public async Task<string> DeleteAsync(string id, string? whisperModel, CancellationToken ct = default)
    {
        var body = new Dictionary<string, object> { ["id"] = id };
        if (!string.IsNullOrWhiteSpace(whisperModel))
        {
            body["whisperModel"] = whisperModel;
        }

        using var doc = await ApiClient.PostJsonAsync("api/models/local/delete", body, ct);
        var root = doc.RootElement;
        if (root.TryGetProperty("ok", out var okEl) && okEl.ValueKind == JsonValueKind.False)
        {
            throw new InvalidOperationException(ReadMessage(root, "删除失败"));
        }

        SettingsStore.Shared.MergeHealth(root);
        return ReadMessage(root, "已删除");
    }

    private static string ReadMessage(JsonElement root, string fallback)
    {
        return root.TryGetProperty("message", out var msgEl) && msgEl.ValueKind == JsonValueKind.String
            ? msgEl.GetString() ?? fallback
            : fallback;
    }
}
