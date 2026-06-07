namespace VoiceBridgeAI.Session;

/// <summary>Detect sustained silence in PCM chunks (matches server RMS VAD threshold).</summary>
public struct PcmSilenceMonitor
{
    public float RmsThreshold { get; set; }
    public TimeSpan ClearAfter { get; set; }

    private DateTime? _silentSince;

    public PcmSilenceMonitor()
    {
        RmsThreshold = 0.012f;
        ClearAfter = TimeSpan.FromSeconds(2.5);
    }

    public void Reset()
    {
        _silentSince = null;
    }

    /// <returns>True once silence has exceeded ClearAfter.</returns>
    public bool Feed(ReadOnlySpan<byte> pcm)
    {
        var rms = ComputeRms(pcm);
        if (rms >= RmsThreshold)
        {
            _silentSince = null;
            return false;
        }

        var now = DateTime.UtcNow;
        _silentSince ??= now;
        return now - _silentSince.Value >= ClearAfter;
    }

    private static float ComputeRms(ReadOnlySpan<byte> pcm)
    {
        if (pcm.Length < 2)
        {
            return 0;
        }

        var count = pcm.Length / 2;
        var sum = 0f;
        for (var i = 0; i < count; i++)
        {
            var sample = BitConverter.ToInt16(pcm.Slice(i * 2, 2)) / 32768f;
            sum += sample * sample;
        }

        return MathF.Sqrt(sum / Math.Max(count, 1));
    }
}
