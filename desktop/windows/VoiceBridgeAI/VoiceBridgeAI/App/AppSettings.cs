namespace VoiceBridgeAI;

public static class AppSettings
{
    public static int Port { get; } = ParsePort(Environment.GetEnvironmentVariable("VOICEBRIDGE_PORT"));

    public static Uri BaseUri { get; } = new($"http://127.0.0.1:{Port}");

    public static Uri HealthUri { get; } = new(BaseUri, "api/health");

    public static Uri WebSocketUri { get; } = new($"ws://127.0.0.1:{Port}/ws");

    private static int ParsePort(string? raw)
    {
        if (int.TryParse(raw, out var port) && port is > 0 and < 65536)
        {
            return port;
        }

        return 8765;
    }
}
