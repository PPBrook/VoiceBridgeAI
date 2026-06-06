import Foundation

struct SubtitleSegment: Identifiable, Equatable {
    let id: String
    var text: String
    var translation: String
    var partial: Bool
    var final: Bool
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

    private func notify() { onChange?() }

    func reset() {
        map.removeAll()
        segments = []
        errorMessage = nil
        statusMessage = "正在聆听…"
        isVisible = true
        notify()
    }

    func hide() {
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

        let seg = SubtitleSegment(
            id: id,
            text: text,
            translation: translation,
            partial: isPartial && !isFinal,
            final: isFinal
        )
        map[id] = seg

        let ordered = map.values.sorted { Int($0.id) ?? 0 < Int($1.id) ?? 0 }
        segments = Array(ordered.suffix(maxLines))
        statusMessage = ""
        notify()
    }
}
