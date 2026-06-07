using System.Globalization;
using System.Text;

namespace VoiceBridgeAI.Session;

public sealed class TranscriptEntry
{
    public int Index { get; init; }
    public string? Time { get; init; }
    public bool Revised { get; init; }
    public string English { get; init; } = "";
    public string Chinese { get; init; } = "";
}

public sealed class TranscriptDocument
{
    public string? Started { get; init; }
    public string? Scene { get; init; }
    public string? Ended { get; init; }
    public IReadOnlyList<TranscriptEntry> Entries { get; init; } = Array.Empty<TranscriptEntry>();

    public static TranscriptDocument Empty { get; } = new();
}

public static class TranscriptParser
{
    public static TranscriptDocument Parse(string text)
    {
        var lines = text.Replace("\r\n", "\n").Split('\n');
        string? started = null;
        string? scene = null;
        string? ended = null;
        var entries = new List<TranscriptEntry>();

        var i = 0;
        while (i < lines.Length)
        {
            var line = lines[i].Trim();
            if (line.StartsWith("- 开始：", StringComparison.Ordinal) || line.StartsWith("开始：", StringComparison.Ordinal))
            {
                started = line.Replace("- 开始：", "", StringComparison.Ordinal)
                    .Replace("开始：", "", StringComparison.Ordinal);
            }
            else if (line.StartsWith("- 观看场景：", StringComparison.Ordinal) || line.StartsWith("观看场景：", StringComparison.Ordinal))
            {
                scene = line.Replace("- 观看场景：", "", StringComparison.Ordinal)
                    .Replace("观看场景：", "", StringComparison.Ordinal);
            }
            else if (line.StartsWith("结束：", StringComparison.Ordinal))
            {
                ended = line["结束：".Length..];
            }
            else if (line.StartsWith("## ", StringComparison.Ordinal))
            {
                if (ParseMarkdownSection(lines, i) is { } md)
                {
                    entries.Add(md.Entry);
                    i = md.NextIndex;
                    continue;
                }
            }
            else if (line.StartsWith('[') && line.Contains(']'))
            {
                if (ParsePlainSection(lines, i) is { } plain)
                {
                    entries.Add(plain.Entry);
                    i = plain.NextIndex;
                    continue;
                }
            }

            i++;
        }

        return new TranscriptDocument
        {
            Started = started,
            Scene = scene,
            Ended = ended,
            Entries = entries,
        };
    }

    public static TranscriptDocument ParseFile(string path)
    {
        return Parse(File.ReadAllText(path, Encoding.UTF8));
    }

    private sealed record SectionParseResult(TranscriptEntry Entry, int NextIndex);

    private static SectionParseResult? ParseMarkdownSection(string[] lines, int start)
    {
        var header = lines[start].Trim();
        if (!header.StartsWith("## ", StringComparison.Ordinal))
        {
            return null;
        }

        var body = header["## ".Length..];
        var revised = body.Contains("修订", StringComparison.Ordinal);
        var index = EntriesIndex(body) ?? 0;
        var time = TimeFromHeader(body);

        var english = "";
        var chinese = "";
        string? mode = null;
        var i = start + 1;

        while (i < lines.Length)
        {
            var line = lines[i].Trim();
            if (line.StartsWith("## ", StringComparison.Ordinal))
            {
                break;
            }

            if (line == "---" && mode is not null)
            {
                break;
            }

            if (line is "**英文**" or "英文")
            {
                mode = "en";
                i++;
                continue;
            }

            if (line is "**中文**" or "中文")
            {
                mode = "zh";
                i++;
                continue;
            }

            if (string.IsNullOrEmpty(line) || line == "---")
            {
                i++;
                continue;
            }

            switch (mode)
            {
                case "en":
                    english = string.IsNullOrEmpty(english) ? line : english + "\n" + line;
                    break;
                case "zh":
                    chinese = string.IsNullOrEmpty(chinese) ? line : chinese + "\n" + line;
                    break;
            }

            i++;
        }

        if (string.IsNullOrEmpty(english) && string.IsNullOrEmpty(chinese))
        {
            return null;
        }

        return new SectionParseResult(
            new TranscriptEntry
            {
                Index = index,
                Time = time,
                Revised = revised,
                English = english.Trim(),
                Chinese = chinese.Trim(),
            },
            i);
    }

    private static SectionParseResult? ParsePlainSection(string[] lines, int start)
    {
        var header = lines[start].Trim();
        if (!header.StartsWith('[') || !header.EndsWith(']'))
        {
            return null;
        }

        var inner = header[1..^1];
        var revised = inner.Contains("修订", StringComparison.Ordinal);
        var index = EntriesIndex(inner) ?? 0;
        var time = TimeFromPlainHeader(inner);

        var english = "";
        var chinese = "";
        var i = start + 1;
        while (i < lines.Length)
        {
            var line = lines[i].Trim();
            if (line.StartsWith('[') && line.EndsWith(']'))
            {
                break;
            }

            if (line.StartsWith("英文：", StringComparison.Ordinal))
            {
                english = line["英文：".Length..];
            }
            else if (line.StartsWith("中文：", StringComparison.Ordinal))
            {
                chinese = line["中文：".Length..];
            }
            else if (string.IsNullOrEmpty(line))
            {
                if (!string.IsNullOrEmpty(english) || !string.IsNullOrEmpty(chinese))
                {
                    break;
                }
            }

            i++;
        }

        if (string.IsNullOrEmpty(english) && string.IsNullOrEmpty(chinese))
        {
            return null;
        }

        return new SectionParseResult(
            new TranscriptEntry
            {
                Index = index,
                Time = time,
                Revised = revised,
                English = english.Trim(),
                Chinese = chinese.Trim(),
            },
            i);
    }

    private static int? EntriesIndex(string header)
    {
        var digits = header.TakeWhile(char.IsDigit).ToArray();
        return digits.Length == 0 ? null : int.Parse(new string(digits));
    }

    private static string? TimeFromHeader(string header)
    {
        var idx = header.LastIndexOf(" · ", StringComparison.Ordinal);
        return idx < 0 ? null : header[(idx + 3)..].Trim();
    }

    private static string? TimeFromPlainHeader(string inner)
    {
        var idx = inner.LastIndexOf(" · ", StringComparison.Ordinal);
        return idx < 0 ? null : inner[(idx + 3)..].Trim();
    }
}

public static class TranscriptRenderer
{
    public static string Render(
        TranscriptDocument document,
        TranscriptPreferences.ContentLayout layout,
        TranscriptPreferences.FileFormat format,
        bool ended = false)
    {
        return format switch
        {
            TranscriptPreferences.FileFormat.Markdown => RenderMarkdown(document, layout, ended),
            TranscriptPreferences.FileFormat.PlainText => RenderPlainText(document, layout, ended),
            _ => RenderMarkdown(document, layout, ended),
        };
    }

    public static string ExportPath(string sourcePath, TranscriptPreferences.ContentLayout layout, TranscriptPreferences.FileFormat format)
    {
        var dir = Path.GetDirectoryName(sourcePath) ?? TranscriptPreferences.StorageDirectory;
        var baseName = Path.GetFileNameWithoutExtension(sourcePath);
        var ext = TranscriptPreferences.FileExtensionFor(format);
        var suffix = TranscriptPreferences.ExportSuffixFor(layout);
        return Path.Combine(dir, $"{baseName}{suffix}.{ext}");
    }

    private static string RenderMarkdown(TranscriptDocument document, TranscriptPreferences.ContentLayout layout, bool ended)
    {
        var lines = new List<string>
        {
            "# VoiceBridgeAI 字幕记录",
            "",
        };

        if (!string.IsNullOrWhiteSpace(document.Started))
        {
            lines.Add($"- 开始：{document.Started}");
        }

        if (!string.IsNullOrWhiteSpace(document.Scene))
        {
            lines.Add($"- 观看场景：{document.Scene}");
        }

        lines.Add($"- 内容形式：{TranscriptPreferences.LabelFor(layout)}");
        lines.Add("");
        lines.Add("---");
        lines.Add("");

        for (var offset = 0; offset < document.Entries.Count; offset++)
        {
            AppendEntry(document.Entries[offset], offset + 1, layout, markdown: true, lines);
        }

        if (ended)
        {
            lines.Add(string.IsNullOrWhiteSpace(document.Ended)
                ? $"结束：{DisplayNow()}"
                : $"结束：{document.Ended}");
        }

        lines.Add("");
        return string.Join('\n', lines);
    }

    private static string RenderPlainText(TranscriptDocument document, TranscriptPreferences.ContentLayout layout, bool ended)
    {
        var lines = new List<string> { "VoiceBridgeAI 字幕记录" };
        if (!string.IsNullOrWhiteSpace(document.Started))
        {
            lines.Add($"开始：{document.Started}");
        }

        if (!string.IsNullOrWhiteSpace(document.Scene))
        {
            lines.Add($"观看场景：{document.Scene}");
        }

        lines.Add($"内容形式：{TranscriptPreferences.LabelFor(layout)}");
        lines.Add("");

        for (var offset = 0; offset < document.Entries.Count; offset++)
        {
            AppendEntry(document.Entries[offset], offset + 1, layout, markdown: false, lines);
        }

        if (ended)
        {
            lines.Add(string.IsNullOrWhiteSpace(document.Ended)
                ? $"结束：{DisplayNow()}"
                : $"结束：{document.Ended}");
        }

        lines.Add("");
        return string.Join('\n', lines);
    }

    private static void AppendEntry(
        TranscriptEntry entry,
        int displayIndex,
        TranscriptPreferences.ContentLayout layout,
        bool markdown,
        List<string> lines)
    {
        var tag = entry.Revised ? " · 修订" : "";
        var headerSuffix = string.IsNullOrEmpty(entry.Time) ? "" : $" · {entry.Time}";

        switch (layout)
        {
            case TranscriptPreferences.ContentLayout.EnglishOnly:
                if (string.IsNullOrEmpty(entry.English))
                {
                    return;
                }

                if (markdown)
                {
                    lines.Add($"## {displayIndex}{tag}{headerSuffix}");
                    lines.Add("");
                    lines.Add(entry.English);
                    lines.Add("");
                    lines.Add("---");
                    lines.Add("");
                }
                else
                {
                    lines.Add($"[{displayIndex}{tag}{headerSuffix}]");
                    lines.Add(entry.English);
                    lines.Add("");
                }

                break;

            case TranscriptPreferences.ContentLayout.ChineseOnly:
                var zhOnly = string.IsNullOrEmpty(entry.Chinese) ? entry.English : entry.Chinese;
                if (string.IsNullOrEmpty(zhOnly))
                {
                    return;
                }

                if (markdown)
                {
                    lines.Add($"## {displayIndex}{tag}{headerSuffix}");
                    lines.Add("");
                    lines.Add(zhOnly);
                    lines.Add("");
                    lines.Add("---");
                    lines.Add("");
                }
                else
                {
                    lines.Add($"[{displayIndex}{tag}{headerSuffix}]");
                    lines.Add(zhOnly);
                    lines.Add("");
                }

                break;

            case TranscriptPreferences.ContentLayout.Combined:
                if (markdown)
                {
                    lines.Add($"## {displayIndex}{tag}{headerSuffix}");
                    lines.Add("");
                    if (!string.IsNullOrEmpty(entry.English))
                    {
                        lines.Add(entry.English);
                    }

                    if (!string.IsNullOrEmpty(entry.Chinese))
                    {
                        lines.Add(entry.Chinese);
                    }

                    lines.Add("");
                    lines.Add("---");
                    lines.Add("");
                }
                else
                {
                    lines.Add($"[{displayIndex}{tag}{headerSuffix}]");
                    if (!string.IsNullOrEmpty(entry.English))
                    {
                        lines.Add(entry.English);
                    }

                    if (!string.IsNullOrEmpty(entry.Chinese))
                    {
                        lines.Add(entry.Chinese);
                    }

                    lines.Add("");
                }

                break;

            case TranscriptPreferences.ContentLayout.BilingualBlocks:
            default:
                if (markdown)
                {
                    lines.Add($"## {displayIndex}{tag}{headerSuffix}");
                    lines.Add("");
                    if (!string.IsNullOrEmpty(entry.English))
                    {
                        lines.Add("**英文**");
                        lines.Add(entry.English);
                        lines.Add("");
                    }

                    if (!string.IsNullOrEmpty(entry.Chinese))
                    {
                        lines.Add("**中文**");
                        lines.Add(entry.Chinese);
                        lines.Add("");
                    }

                    lines.Add("---");
                    lines.Add("");
                }
                else
                {
                    lines.Add($"[{displayIndex}{tag}{headerSuffix}]");
                    if (!string.IsNullOrEmpty(entry.English))
                    {
                        lines.Add($"英文：{entry.English}");
                    }

                    if (!string.IsNullOrEmpty(entry.Chinese))
                    {
                        lines.Add($"中文：{entry.Chinese}");
                    }

                    lines.Add("");
                }

                break;
        }
    }

    private static string DisplayNow() =>
        DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss", CultureInfo.GetCultureInfo("zh-CN"));
}

public sealed class TranscriptConvertException : Exception
{
    public TranscriptConvertException(string message) : base(message)
    {
    }
}
