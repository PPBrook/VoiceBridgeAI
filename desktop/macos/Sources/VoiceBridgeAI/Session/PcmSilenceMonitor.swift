import Foundation

/// Detects sustained silence in PCM chunks (matches server RMS VAD threshold).
struct PcmSilenceMonitor {
    var rmsThreshold: Float = 0.012
    var clearAfterSeconds: TimeInterval = 2.5

    private var silentSince: Date?

    mutating func reset() {
        silentSince = nil
    }

    /// Returns true once silence has exceeded `clearAfterSeconds`.
    mutating func feed(pcm: Data) -> Bool {
        let rms = Self.rms(pcm)
        if rms >= rmsThreshold {
            silentSince = nil
            return false
        }
        let now = Date()
        if silentSince == nil {
            silentSince = now
        }
        guard let since = silentSince else { return false }
        return now.timeIntervalSince(since) >= clearAfterSeconds
    }

    private static func rms(_ pcm: Data) -> Float {
        guard pcm.count >= 2 else { return 0 }
        let count = pcm.count / 2
        var sum: Float = 0
        pcm.withUnsafeBytes { raw in
            let samples = raw.bindMemory(to: Int16.self)
            for i in 0..<count {
                let s = Float(samples[i]) / 32768
                sum += s * s
            }
        }
        return sqrt(sum / Float(max(count, 1)))
    }
}
