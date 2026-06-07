import Foundation

struct SubtitleSegment: Identifiable, Equatable {
    let id: String
    var text: String
    var translation: String
    var partial: Bool
    var final: Bool
    var revised: Bool
    var lookback: Bool
}

@MainActor
final class SubtitleStore {
    private(set) var segments: [SubtitleSegment] = []
    var statusMessage: String = "等待字幕…"
    var errorMessage: String?
    var isVisible = false

    var onChange: (() -> Void)?

    private var map: [String: SubtitleSegment] = [:]
    private let maxLines = 2
    private var partialNotifyTask: Task<Void, Never>?
    private var idleClearTask: Task<Void, Never>?
    /// Clear stale subtitles if no ASR update (covers muted pause / tab switch).
    private let idleClearSeconds: TimeInterval = 8

    private func notify() { onChange?() }

    private func scheduleIdleClear() {
        idleClearTask?.cancel()
        idleClearTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(idleClearSeconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            clearDisplay()
        }
    }

    /// Remove on-screen subtitles after pause / video switch; keep session running.
    func clearDisplay() {
        partialNotifyTask?.cancel()
        partialNotifyTask = nil
        idleClearTask?.cancel()
        idleClearTask = nil
        map.removeAll()
        segments = []
        errorMessage = nil
        statusMessage = "正在聆听…"
        isVisible = true
        notify()
    }

    private func scheduleNotify(isFinal: Bool) {
        if isFinal {
            partialNotifyTask?.cancel()
            partialNotifyTask = nil
            notify()
            return
        }
        partialNotifyTask?.cancel()
        partialNotifyTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 180_000_000)
            guard !Task.isCancelled else { return }
            notify()
        }
    }

    func reset() {
        partialNotifyTask?.cancel()
        partialNotifyTask = nil
        idleClearTask?.cancel()
        idleClearTask = nil
        map.removeAll()
        segments = []
        errorMessage = nil
        statusMessage = "正在聆听…"
        isVisible = true
        notify()
    }

    func hide() {
        partialNotifyTask?.cancel()
        partialNotifyTask = nil
        idleClearTask?.cancel()
        idleClearTask = nil
        map.removeAll()
        segments = []
        errorMessage = nil
        isVisible = false
        notify()
    }

    func showError(_ message: String) {
        errorMessage = message
        isVisible = true
        notify()
    }

    func applyASR(_ payload: [String: Any]) {
        errorMessage = nil
        isVisible = true

        let id = String(describing: payload["segmentId"] ?? map.count)
        let prev = map[id]
        let text = (payload["text"] as? String) ?? prev?.text ?? ""
        var translation = (payload["translation"] as? String) ?? ""
        if translation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            translation = prev?.translation ?? ""
        }
        let isFinal = (payload["final"] as? Bool) ?? false
        let isPartial = (payload["partial"] as? Bool) ?? false
        let revised = (payload["revise"] as? Bool) ?? false
        let lookback = (payload["lookback"] as? Bool) ?? false

        let seg = SubtitleSegment(
            id: id,
            text: text,
            translation: translation,
            partial: isPartial && !isFinal,
            final: isFinal,
            revised: revised && prev != nil,
            lookback: lookback
        )
        map[id] = seg

        let ordered = map.values.sorted { Int($0.id) ?? 0 < Int($1.id) ?? 0 }
        segments = Array(ordered.suffix(maxLines))
        statusMessage = ""
        scheduleIdleClear()
        scheduleNotify(isFinal: isFinal || prev == nil)
    }
}
