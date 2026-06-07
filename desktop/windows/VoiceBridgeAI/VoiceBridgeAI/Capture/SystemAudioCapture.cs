using NAudio.Wave;
using NAudio.Wave.SampleProviders;

namespace VoiceBridgeAI.Capture;

/// <summary>WASAPI loopback — captures system playback audio as 48 kHz mono Int16 PCM.</summary>
public sealed class SystemAudioCapture : IDisposable
{
    public event Action<byte[]>? PcmAvailable;
    public event Action<string>? Failed;

    private WasapiLoopbackCapture? _capture;
    private readonly object _gate = new();

    public void Start()
    {
        lock (_gate)
        {
            StopInternal();

            _capture = new WasapiLoopbackCapture();
            _capture.DataAvailable += OnDataAvailable;
            _capture.RecordingStopped += (_, args) =>
            {
                if (args.Exception is not null)
                {
                    Failed?.Invoke(args.Exception.Message);
                }
            };
            _capture.StartRecording();
        }
    }

    public void Stop()
    {
        lock (_gate)
        {
            StopInternal();
        }
    }

    private void StopInternal()
    {
        if (_capture is null)
        {
            return;
        }

        _capture.DataAvailable -= OnDataAvailable;
        _capture.StopRecording();
        _capture.Dispose();
        _capture = null;
    }

    private void OnDataAvailable(object? sender, WaveInEventArgs e)
    {
        if (e.BytesRecorded <= 0 || _capture is null)
        {
            return;
        }

        try
        {
            using var input = new RawSourceWaveStream(e.Buffer, 0, e.BytesRecorded, _capture.WaveFormat);
            ISampleProvider samples = input.ToSampleProvider();
            if (samples.WaveFormat.Channels > 1)
            {
                samples = new StereoToMonoSampleProvider(samples);
            }

            if (samples.WaveFormat.SampleRate != 48000)
            {
                samples = new WdlResamplingSampleProvider(samples, 48000);
            }

            var frameCount = e.BytesRecorded / _capture.WaveFormat.BlockAlign;
            var floatBuffer = new float[Math.Max(frameCount, 4800)];
            var read = samples.Read(floatBuffer, 0, floatBuffer.Length);
            if (read <= 0)
            {
                return;
            }

            var pcm = new byte[read * 2];
            for (var i = 0; i < read; i++)
            {
                var clamped = Math.Clamp(floatBuffer[i], -1f, 1f);
                var sample = clamped < 0
                    ? (short)(clamped * 32768f)
                    : (short)(clamped * 32767f);
                BitConverter.TryWriteBytes(pcm.AsSpan(i * 2, 2), sample);
            }

            PcmAvailable?.Invoke(pcm);
        }
        catch (Exception ex)
        {
            Failed?.Invoke(ex.Message);
        }
    }

    public void Dispose()
    {
        Stop();
    }
}
