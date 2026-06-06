import AVFoundation
import CoreMedia
import Foundation
import ScreenCaptureKit

@available(macOS 13.0, *)
final class SystemAudioCapture: NSObject, SCStreamDelegate, SCStreamOutput {
    var onPCM: ((Data) -> Void)?
    var onFailure: ((String) -> Void)?

    private var stream: SCStream?
    private let queue = DispatchQueue(label: "ai.voicebridge.capture")

    func start() async throws {
        stop()

        let content = try await SCShareableContent.current
        guard let display = content.displays.first else {
            throw CaptureError.noDisplay
        }

        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = true
        config.sampleRate = 48000
        config.channelCount = 1

        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: queue)
        try await stream.startCapture()
        self.stream = stream
    }

    func stop() {
        if let stream {
            Task {
                try? await stream.stopCapture()
            }
        }
        stream = nil
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.onFailure?(error.localizedDescription)
        }
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio else { return }
        guard let block = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }

        var length = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        guard CMBlockBufferGetDataPointer(block, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &dataPointer) == kCMBlockBufferNoErr,
              let dataPointer else { return }

        guard let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer),
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc) else { return }

        let isFloat = (asbd.pointee.mFormatFlags & kAudioFormatFlagIsFloat) != 0
        let bytesPerSample = Int(asbd.pointee.mBitsPerChannel / 8)
        let channels = Int(asbd.pointee.mChannelsPerFrame)
        let frameCount = length / (bytesPerSample * max(channels, 1))

        var monoInt16 = [Int16](repeating: 0, count: frameCount)

        if isFloat && bytesPerSample == 4 {
            let floats = dataPointer.withMemoryRebound(to: Float.self, capacity: frameCount * channels) { $0 }
            for i in 0..<frameCount {
                var sum: Float = 0
                for c in 0..<channels {
                    sum += floats[i * channels + c]
                }
                let sample = sum / Float(channels)
                let clamped = max(-1, min(1, sample))
                monoInt16[i] = clamped < 0 ? Int16(clamped * 32768) : Int16(clamped * 32767)
            }
        } else if bytesPerSample == 2 {
            let samples = dataPointer.withMemoryRebound(to: Int16.self, capacity: frameCount * channels) { $0 }
            for i in 0..<frameCount {
                var sum: Int32 = 0
                for c in 0..<channels {
                    sum += Int32(samples[i * channels + c])
                }
                monoInt16[i] = Int16(max(-32768, min(32767, sum / Int32(channels))))
            }
        } else {
            return
        }

        let data = monoInt16.withUnsafeBufferPointer { Data(buffer: $0) }
        onPCM?(data)
    }

    enum CaptureError: LocalizedError {
        case noDisplay

        var errorDescription: String? {
            switch self {
            case .noDisplay: return "未找到可用显示器"
            }
        }
    }
}
