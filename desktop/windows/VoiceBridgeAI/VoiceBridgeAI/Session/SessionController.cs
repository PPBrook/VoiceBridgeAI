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
    private PcmSilenceMonitor _silenceMonitor;
    private readonly SynchronizationContext? _uiContext;

    private SessionController()
    {
        _uiContext = SynchronizationContext.Current;

        Store.Changed += () => PostToUi(() => StateChanged?.Invoke());

        _webSocket.AsrReceived += payload => PostToUi(() =>
        {
            _silenceMonitor.Reset();
            Store.ApplyAsr(payload);
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
}
