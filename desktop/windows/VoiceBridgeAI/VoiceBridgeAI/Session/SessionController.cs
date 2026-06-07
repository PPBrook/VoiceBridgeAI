using VoiceBridgeAI.Capture;
using VoiceBridgeAI.Settings;

namespace VoiceBridgeAI.Session;

public sealed class SessionController
{
    public static SessionController Shared { get; } = new();

    public SubtitleStore Store { get; } = new();
    public bool IsRunning { get; private set; }
    public bool IsStarting { get; private set; }

    public event Action? StateChanged;

    private readonly WebSocketSession _webSocket = new();
    private SystemAudioCapture? _capture;
    private EngineConfig _engineConfig = new();
    private PcmSilenceMonitor _silenceMonitor = new();
    private readonly SynchronizationContext? _uiContext;

    private SessionController()
    {
        _uiContext = SynchronizationContext.Current;

        Store.Changed += () => PostToUi(() => StateChanged?.Invoke());

        _webSocket.AsrReceived += payload => PostToUi(() =>
        {
            _silenceMonitor.Reset();
            Store.ApplyAsr(payload);
            RecordTranslationIfNeeded(payload);
        });

        _webSocket.ErrorReceived += message => PostToUi(() =>
        {
            Store.ShowError(message);
            Stop();
        });
    }

    public async Task<string?> StartAsync()
    {
        if (IsRunning || IsStarting)
        {
            return null;
        }

        IsStarting = true;
        NotifyStateChanged();
        try
        {
            var serverErr = await ServerManager.Shared.EnsureRunningAsync();
            if (serverErr is not null)
            {
                return serverErr;
            }

            try
            {
                await SettingsStore.Shared.RefreshAsync();
                _engineConfig = SettingsStore.Shared.Engine;
            }
            catch
            {
                return "无法读取引擎配置";
            }

            try
            {
                await _webSocket.ConnectAsync(_engineConfig);
            }
            catch (Exception ex)
            {
                return ex.Message;
            }

            var capture = new SystemAudioCapture();
            capture.PcmAvailable += async pcm =>
            {
                if (!IsRunning)
                {
                    return;
                }

                if (_silenceMonitor.Feed(pcm) && Store.Segments.Count > 0)
                {
                    Store.ClearDisplay();
                    _silenceMonitor.Reset();
                }

                try
                {
                    await _webSocket.SendPcmAsync(pcm);
                }
                catch (Exception ex)
                {
                    PostToUi(() =>
                    {
                        Store.ShowError($"音频发送失败：{ex.Message}");
                        Stop();
                    });
                }
            };

            capture.Failed += message => PostToUi(() =>
            {
                Store.ShowError(message);
                Stop();
            });

            try
            {
                capture.Start();
            }
            catch (Exception ex)
            {
                await _webSocket.DisconnectAsync();
                return $"音频采集失败：{ex.Message}。请确认系统正在播放音频，且未被其他录音软件独占。";
            }

            _capture = capture;
            IsRunning = true;
            _silenceMonitor.Reset();
            Store.Reset();
            BeginTranslationRecordingIfNeeded();
            return null;
        }
        finally
        {
            IsStarting = false;
            NotifyStateChanged();
        }
    }

    public void Stop()
    {
        _capture?.Stop();
        _capture?.Dispose();
        _capture = null;
        _ = _webSocket.DisconnectAsync();
        IsRunning = false;
        IsStarting = false;
        TranslationRecorder.Shared.EndSession();
        Store.Hide();
        NotifyStateChanged();
    }

    private void NotifyStateChanged()
    {
        PostToUi(() => StateChanged?.Invoke());
    }

    private void PostToUi(Action action)
    {
        if (_uiContext is null)
        {
            action();
            return;
        }

        _uiContext.Post(_ => action(), null);
    }

    private void BeginTranslationRecordingIfNeeded()
    {
        if (!TranscriptPreferences.RecordEnabled)
        {
            return;
        }

        var modeId = _engineConfig.ReviseMode;
        var label = ReviseModeLabel(modeId);
        TranslationRecorder.Shared.BeginSession(modeId, label);
    }

    private static void RecordTranslationIfNeeded(IReadOnlyDictionary<string, object?> payload)
    {
        if (!TranscriptPreferences.RecordEnabled)
        {
            return;
        }

        if (payload.TryGetValue("final", out var finalVal) && finalVal is not true)
        {
            return;
        }

        var english = payload.TryGetValue("text", out var textVal)
            ? Convert.ToString(textVal)?.Trim() ?? ""
            : "";
        if (string.IsNullOrEmpty(english))
        {
            return;
        }

        var segmentId = payload.TryGetValue("segmentId", out var segVal)
            ? Convert.ToString(segVal) ?? ""
            : "";
        var chinese = payload.TryGetValue("translation", out var trVal)
            ? Convert.ToString(trVal) ?? ""
            : "";
        var revised = (payload.TryGetValue("revise", out var reviseVal) && reviseVal is true)
            || (payload.TryGetValue("lookback", out var lookbackVal) && lookbackVal is true);

        TranslationRecorder.Shared.Record(segmentId, english, chinese, revised);
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
}
