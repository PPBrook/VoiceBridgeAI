namespace VoiceBridgeAI.Session;

public sealed class SubtitleSegment
{
    public required string Id { get; init; }
    public string Text { get; init; } = "";
    public string Translation { get; init; } = "";
    public bool Partial { get; init; }
    public bool Final { get; init; }
}

public sealed class SubtitleStore
{
    private readonly Dictionary<string, SubtitleSegment> _map = new();
    private readonly int _maxLines = 2;
    private CancellationTokenSource? _partialNotifyCts;
    private CancellationTokenSource? _idleClearCts;
    private readonly TimeSpan _idleClearDelay = TimeSpan.FromSeconds(8);

    public IReadOnlyList<SubtitleSegment> Segments { get; private set; } = Array.Empty<SubtitleSegment>();
    public string StatusMessage { get; private set; } = "等待字幕…";
    public string? ErrorMessage { get; private set; }
    public bool IsVisible { get; private set; }

    public event Action? Changed;

    public void ClearDisplay()
    {
        CancelTimers();
        _map.Clear();
        Segments = Array.Empty<SubtitleSegment>();
        ErrorMessage = null;
        StatusMessage = "正在聆听…";
        IsVisible = true;
        Changed?.Invoke();
    }

    public void Reset()
    {
        CancelTimers();
        _map.Clear();
        Segments = Array.Empty<SubtitleSegment>();
        ErrorMessage = null;
        StatusMessage = "正在聆听…";
        IsVisible = true;
        Changed?.Invoke();
    }

    public void Hide()
    {
        CancelTimers();
        _map.Clear();
        Segments = Array.Empty<SubtitleSegment>();
        ErrorMessage = null;
        IsVisible = false;
        Changed?.Invoke();
    }

    public void ShowError(string message)
    {
        ErrorMessage = message;
        IsVisible = true;
        Changed?.Invoke();
    }

    public void ApplyAsr(IReadOnlyDictionary<string, object?> payload)
    {
        ErrorMessage = null;
        IsVisible = true;

        var id = payload.TryGetValue("segmentId", out var segId) ? Convert.ToString(segId) ?? _map.Count.ToString() : _map.Count.ToString();
        _map.TryGetValue(id, out var prev);

        var text = payload.TryGetValue("text", out var textVal) ? Convert.ToString(textVal) ?? "" : prev?.Text ?? "";
        var translation = payload.TryGetValue("translation", out var trVal) ? Convert.ToString(trVal) ?? "" : "";
        if (string.IsNullOrWhiteSpace(translation))
        {
            translation = prev?.Translation ?? "";
        }

        var isFinal = payload.TryGetValue("final", out var finalVal) && finalVal is true;
        var isPartial = payload.TryGetValue("partial", out var partialVal) && partialVal is true && !isFinal;

        var seg = new SubtitleSegment
        {
            Id = id,
            Text = text,
            Translation = translation,
            Partial = isPartial,
            Final = isFinal,
        };
        _map[id] = seg;

        Segments = _map.Values
            .OrderBy(s => int.TryParse(s.Id, out var n) ? n : 0)
            .TakeLast(_maxLines)
            .ToList();

        StatusMessage = "";
        ScheduleIdleClear();
        ScheduleNotify(isFinal || prev is null);
    }

    private void ScheduleIdleClear()
    {
        _idleClearCts?.Cancel();
        _idleClearCts = new CancellationTokenSource();
        var token = _idleClearCts.Token;
        _ = Task.Run(async () =>
        {
            try
            {
                await Task.Delay(_idleClearDelay, token);
                if (!token.IsCancellationRequested)
                {
                    ClearDisplay();
                }
            }
            catch (OperationCanceledException)
            {
            }
        }, token);
    }

    private void ScheduleNotify(bool immediate)
    {
        if (immediate)
        {
            _partialNotifyCts?.Cancel();
            Changed?.Invoke();
            return;
        }

        _partialNotifyCts?.Cancel();
        _partialNotifyCts = new CancellationTokenSource();
        var token = _partialNotifyCts.Token;
        _ = Task.Run(async () =>
        {
            try
            {
                await Task.Delay(180, token);
                if (!token.IsCancellationRequested)
                {
                    Changed?.Invoke();
                }
            }
            catch (OperationCanceledException)
            {
            }
        }, token);
    }

    private void CancelTimers()
    {
        _partialNotifyCts?.Cancel();
        _partialNotifyCts = null;
        _idleClearCts?.Cancel();
        _idleClearCts = null;
    }
}
