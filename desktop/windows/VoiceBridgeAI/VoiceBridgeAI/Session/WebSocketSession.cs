using System.Net.WebSockets;
using System.Text;
using System.Text.Json;
using VoiceBridgeAI.Settings;

namespace VoiceBridgeAI.Session;

public sealed class WebSocketSession : IAsyncDisposable
{
    public event Action<Dictionary<string, object?>>? AsrReceived;
    public event Action<string>? ErrorReceived;

    private ClientWebSocket? _socket;
    private CancellationTokenSource? _receiveCts;
    private readonly TimeSpan _readyTimeout = TimeSpan.FromSeconds(120);

    public async Task ConnectAsync(EngineConfig config, CancellationToken ct = default)
    {
        await DisconnectAsync();

        _socket = new ClientWebSocket();
        await _socket.ConnectAsync(AppSettings.WebSocketUri, ct);

        var payload = JsonSerializer.Serialize(config.ToWsPayload());
        await SendTextAsync(payload, ct);
        await WaitForReadyAsync(ct);

        _receiveCts = CancellationTokenSource.CreateLinkedTokenSource(ct);
        _ = ReceiveLoopAsync(_receiveCts.Token);
    }

    private async Task WaitForReadyAsync(CancellationToken ct)
    {
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(ct);
        timeout.CancelAfter(_readyTimeout);

        while (!timeout.IsCancellationRequested)
        {
            var message = await ReceiveTextAsync(timeout.Token);
            if (message is null)
            {
                continue;
            }

            using var doc = JsonDocument.Parse(message);
            var type = doc.RootElement.TryGetProperty("type", out var typeEl) ? typeEl.GetString() : null;
            if (type == "asrReady")
            {
                return;
            }

            if (type == "error")
            {
                var msg = doc.RootElement.TryGetProperty("message", out var msgEl)
                    ? msgEl.GetString() ?? "服务端错误"
                    : "服务端错误";
                throw new InvalidOperationException(msg);
            }
        }

        throw new TimeoutException("等待服务端就绪超时（Whisper 首次加载可能较慢，请稍后重试）");
    }

    private async Task ReceiveLoopAsync(CancellationToken ct)
    {
        try
        {
            while (!ct.IsCancellationRequested && _socket?.State == WebSocketState.Open)
            {
                var message = await ReceiveTextAsync(ct);
                if (message is null)
                {
                    break;
                }

                HandleMessage(message);
            }
        }
        catch (OperationCanceledException)
        {
        }
        catch (Exception ex)
        {
            ErrorReceived?.Invoke(ex.Message);
        }
    }

    private void HandleMessage(string text)
    {
        using var doc = JsonDocument.Parse(text);
        var root = doc.RootElement;
        var type = root.TryGetProperty("type", out var typeEl) ? typeEl.GetString() : null;
        if (type == "error")
        {
            var msg = root.TryGetProperty("message", out var msgEl)
                ? msgEl.GetString() ?? "服务端错误"
                : "服务端错误";
            ErrorReceived?.Invoke(msg);
            return;
        }

        if (type != "asr")
        {
            return;
        }

        var dict = new Dictionary<string, object?>(StringComparer.Ordinal);
        foreach (var prop in root.EnumerateObject())
        {
            dict[prop.Name] = prop.Value.ValueKind switch
            {
                JsonValueKind.String => prop.Value.GetString(),
                JsonValueKind.Number => prop.Value.TryGetInt64(out var n) ? n : prop.Value.GetDouble(),
                JsonValueKind.True => true,
                JsonValueKind.False => false,
                _ => prop.Value.ToString(),
            };
        }

        AsrReceived?.Invoke(dict);
    }

    public async Task SendPcmAsync(ReadOnlyMemory<byte> pcm, CancellationToken ct = default)
    {
        if (_socket is null || _socket.State != WebSocketState.Open)
        {
            throw new InvalidOperationException("WebSocket 未连接");
        }

        await _socket.SendAsync(pcm, WebSocketMessageType.Binary, endOfMessage: true, ct);
    }

    public async Task ReconfigureAsync(EngineConfig config, CancellationToken ct = default)
    {
        var payload = JsonSerializer.Serialize(config.ToWsPayload());
        await SendTextAsync(payload, ct);
    }

    private async Task SendTextAsync(string text, CancellationToken ct)
    {
        if (_socket is null || _socket.State != WebSocketState.Open)
        {
            throw new InvalidOperationException("WebSocket 未连接");
        }

        var bytes = Encoding.UTF8.GetBytes(text);
        await _socket.SendAsync(bytes, WebSocketMessageType.Text, endOfMessage: true, ct);
    }

    private async Task<string?> ReceiveTextAsync(CancellationToken ct)
    {
        if (_socket is null)
        {
            return null;
        }

        var buffer = new byte[8192];
        using var ms = new MemoryStream();
        WebSocketReceiveResult result;
        do
        {
            result = await _socket.ReceiveAsync(buffer, ct);
            if (result.MessageType == WebSocketMessageType.Close)
            {
                return null;
            }

            ms.Write(buffer, 0, result.Count);
        } while (!result.EndOfMessage);

        return Encoding.UTF8.GetString(ms.ToArray());
    }

    public async Task DisconnectAsync()
    {
        _receiveCts?.Cancel();
        _receiveCts = null;

        if (_socket is null)
        {
            return;
        }

        if (_socket.State is WebSocketState.Open or WebSocketState.CloseReceived)
        {
            try
            {
                await _socket.CloseAsync(WebSocketCloseStatus.NormalClosure, "bye", CancellationToken.None);
            }
            catch
            {
            }
        }

        _socket.Dispose();
        _socket = null;
    }

    public async ValueTask DisposeAsync()
    {
        await DisconnectAsync();
    }
}
