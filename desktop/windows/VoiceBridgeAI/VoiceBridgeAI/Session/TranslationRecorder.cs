using System.Globalization;
using VoiceBridgeAI.Settings;

namespace VoiceBridgeAI.Session;

public sealed class TranslationRecorder
{
    public static TranslationRecorder Shared { get; } = new();

    private sealed class Entry
    {
        public required string SegmentId { get; init; }
        public string English { get; set; } = "";
        public string Chinese { get; set; } = "";
        public bool Revised { get; set; }
        public DateTime FirstSeen { get; init; }
        public DateTime LastUpdated { get; set; }
    }

    private readonly Dictionary<string, Entry> _entries = new();
    private string? _sessionPath;
    private DateTime? _sessionStarted;
    private string? _sessionEnded;
    private string _reviseModeId = "";
    private string _reviseModeLabel = "";

    private TranslationRecorder()
    {
    }

    public string TranscriptsDirectory => TranscriptPreferences.StorageDirectory;

    public string? CurrentSessionPath => _sessionPath;

    public void BeginSession(string reviseModeId, string reviseModeLabel)
    {
        if (!TranscriptPreferences.RecordEnabled)
        {
            return;
        }

        _entries.Clear();
        _sessionStarted = DateTime.Now;
        _sessionEnded = null;
        _reviseModeId = reviseModeId;
        _reviseModeLabel = reviseModeLabel;

        var name = TranscriptPreferences.SessionFilename(_sessionStarted.Value, reviseModeId);
        _sessionPath = Path.Combine(TranscriptsDirectory, name);
        FlushToDisk(ended: false);
    }

    public void BeginSessionIfNeeded(string reviseModeId, string reviseModeLabel)
    {
        if (_sessionPath is null)
        {
            BeginSession(reviseModeId, reviseModeLabel);
        }
    }

    public void Record(string segmentId, string english, string chinese, bool revised)
    {
        if (!TranscriptPreferences.RecordEnabled)
        {
            return;
        }

        var en = english.Trim();
        if (string.IsNullOrEmpty(en))
        {
            return;
        }

        if (_sessionPath is null)
        {
            try
            {
                var modeId = SettingsStore.Shared.Engine.ReviseMode;
                var label = ReviseModeLabel(modeId);
                BeginSession(modeId, label);
            }
            catch
            {
                BeginSession("speech", "speech");
            }
        }

        var now = DateTime.Now;
        if (_entries.TryGetValue(segmentId, out var existing))
        {
            existing.English = en;
            existing.Chinese = chinese.Trim();
            existing.Revised = existing.Revised || revised;
            existing.LastUpdated = now;
        }
        else
        {
            _entries[segmentId] = new Entry
            {
                SegmentId = segmentId,
                English = en,
                Chinese = chinese.Trim(),
                Revised = revised,
                FirstSeen = now,
                LastUpdated = now,
            };
        }

        FlushToDisk(ended: false);
    }

    public void EndSession()
    {
        if (_sessionPath is null)
        {
            return;
        }

        _sessionEnded = DisplayFormatter.Format(DateTime.Now);
        FlushToDisk(ended: true);
        _entries.Clear();
        _sessionPath = null;
        _sessionStarted = null;
        _sessionEnded = null;
    }

    public void OpenTranscriptsDirectory()
    {
        try
        {
            Directory.CreateDirectory(TranscriptsDirectory);
            System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo
            {
                FileName = TranscriptsDirectory,
                UseShellExecute = true,
            });
        }
        catch
        {
            // Opening Explorer failure should not crash the app.
        }
    }

    public static string ConvertFile(
        string sourcePath,
        TranscriptPreferences.ContentLayout layout,
        TranscriptPreferences.FileFormat format)
    {
        var document = TranscriptParser.ParseFile(sourcePath);
        if (document.Entries.Count == 0)
        {
            throw new TranscriptConvertException("未能从文件中解析出字幕条目");
        }

        var body = TranscriptRenderer.Render(
            document,
            layout,
            format,
            ended: !string.IsNullOrWhiteSpace(document.Ended));
        var dest = TranscriptRenderer.ExportPath(sourcePath, layout, format);
        Directory.CreateDirectory(Path.GetDirectoryName(dest)!);
        File.WriteAllText(dest, body, System.Text.Encoding.UTF8);
        return dest;
    }

    private void FlushToDisk(bool ended)
    {
        if (_sessionPath is null)
        {
            return;
        }

        try
        {
            Directory.CreateDirectory(TranscriptsDirectory);
            var body = TranscriptRenderer.Render(
                BuildDocument(ended),
                TranscriptPreferences.ContentLayoutValue,
                TranscriptPreferences.FileFormatValue,
                ended);
            File.WriteAllText(_sessionPath, body, System.Text.Encoding.UTF8);
        }
        catch
        {
            // Write failure should not crash the session.
        }
    }

    private TranscriptDocument BuildDocument(bool ended)
    {
        var started = _sessionStarted.HasValue
            ? DisplayFormatter.Format(_sessionStarted.Value)
            : null;
        var scene = string.IsNullOrEmpty(_reviseModeLabel)
            ? _reviseModeId
            : $"{_reviseModeLabel}（{_reviseModeId}）";

        var ordered = _entries.Values
            .OrderBy(e => int.TryParse(e.SegmentId, out var n) ? n : 0)
            .ToList();

        var transcriptEntries = ordered.Select((entry, offset) => new TranscriptEntry
        {
            Index = offset + 1,
            Time = DisplayFormatter.Format(entry.LastUpdated),
            Revised = entry.Revised,
            English = entry.English,
            Chinese = entry.Chinese,
        }).ToList();

        return new TranscriptDocument
        {
            Started = started,
            Scene = scene,
            Ended = ended ? (_sessionEnded ?? DisplayFormatter.Format(DateTime.Now)) : null,
            Entries = transcriptEntries,
        };
    }

    private static string ReviseModeLabel(string modeId)
    {
        try
        {
            var health = SettingsStore.Shared.Health;
            return ProviderOption.List(health, "reviseModes")
                .FirstOrDefault(p => p.Id == modeId).Label ?? modeId;
        }
        catch
        {
            return modeId;
        }
    }

    private static readonly CultureInfo DisplayCulture = CultureInfo.GetCultureInfo("zh-CN");

    private static class DisplayFormatter
    {
        public static string Format(DateTime value) =>
            value.ToString("yyyy-MM-dd HH:mm:ss", DisplayCulture);
    }
}
