import AppKit
import Foundation

/// Persists finalized bilingual subtitle lines to transcript files.
@MainActor
final class TranslationRecorder {
    static let shared = TranslationRecorder()

    private struct Entry {
        let segmentId: String
        var english: String
        var chinese: String
        var revised: Bool
        let firstSeen: Date
        var lastUpdated: Date
    }

    private var entries: [String: Entry] = [:]
    private var sessionURL: URL?
    private var sessionStarted: Date?
    private var sessionEnded: String?
    private var reviseModeId: String = ""
    private var reviseModeLabel: String = ""

    private init() {}

    var transcriptsDirectory: URL {
        TranscriptPreferences.storageDirectory
    }

    var currentSessionURL: URL? { sessionURL }

    func beginSession(reviseModeId: String, reviseModeLabel: String) {
        guard TranscriptPreferences.recordEnabled else { return }
        entries.removeAll()
        sessionStarted = Date()
        sessionEnded = nil
        self.reviseModeId = reviseModeId
        self.reviseModeLabel = reviseModeLabel

        let name = TranscriptPreferences.sessionFilename(started: sessionStarted!, modeId: reviseModeId)
        sessionURL = transcriptsDirectory.appendingPathComponent(name)
        flushToDisk(ended: false)
    }

    func beginSessionIfNeeded(reviseModeId: String, reviseModeLabel: String) {
        guard sessionURL == nil else { return }
        beginSession(reviseModeId: reviseModeId, reviseModeLabel: reviseModeLabel)
    }

    func record(segmentId: String, english: String, chinese: String, revised: Bool) {
        guard TranscriptPreferences.recordEnabled else { return }
        let en = english.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !en.isEmpty else { return }

        if sessionURL == nil {
            let health = SettingsStore.shared.health
            let modeId = SettingsStore.shared.engine.reviseMode
            let label = ReviseModeGuides.info(for: modeId, health: health)?.label ?? modeId
            beginSession(reviseModeId: modeId, reviseModeLabel: label)
        }

        let now = Date()
        if var existing = entries[segmentId] {
            existing.english = en
            existing.chinese = chinese.trimmingCharacters(in: .whitespacesAndNewlines)
            existing.revised = existing.revised || revised
            existing.lastUpdated = now
            entries[segmentId] = existing
        } else {
            entries[segmentId] = Entry(
                segmentId: segmentId,
                english: en,
                chinese: chinese.trimmingCharacters(in: .whitespacesAndNewlines),
                revised: revised,
                firstSeen: now,
                lastUpdated: now
            )
        }
        flushToDisk(ended: false)
    }

    func endSession() {
        guard sessionURL != nil else { return }
        sessionEnded = Self.displayFormatter.string(from: Date())
        flushToDisk(ended: true)
        entries.removeAll()
        sessionURL = nil
        sessionStarted = nil
        sessionEnded = nil
    }

    func openTranscriptsDirectory() {
        do {
            try FileManager.default.createDirectory(at: transcriptsDirectory, withIntermediateDirectories: true)
            NSWorkspace.shared.open(transcriptsDirectory)
        } catch {
            NSLog("TranslationRecorder: failed to open transcripts dir: \(error.localizedDescription)")
        }
    }

    static func convertFile(
        at source: URL,
        layout: TranscriptContentLayout,
        format: TranscriptPreferences.FileFormat
    ) throws -> URL {
        let document = try TranscriptParser.parse(file: source)
        if document.entries.isEmpty {
            throw TranscriptConvertError.noEntries
        }
        let body = TranscriptRenderer.render(
            document: document,
            layout: layout,
            format: format,
            ended: document.ended != nil
        )
        let dest = TranscriptRenderer.exportURL(for: source, layout: layout, format: format)
        try FileManager.default.createDirectory(
            at: dest.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try body.write(to: dest, atomically: true, encoding: .utf8)
        return dest
    }

    private func flushToDisk(ended: Bool) {
        guard let url = sessionURL else { return }
        do {
            try FileManager.default.createDirectory(at: transcriptsDirectory, withIntermediateDirectories: true)
            let body = TranscriptRenderer.render(
                document: buildDocument(ended: ended),
                layout: TranscriptPreferences.contentLayout,
                format: TranscriptPreferences.fileFormat,
                ended: ended
            )
            try body.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            NSLog("TranslationRecorder: write failed: \(error.localizedDescription)")
        }
    }

    private func buildDocument(ended: Bool) -> TranscriptDocument {
        let started = sessionStarted.map { Self.displayFormatter.string(from: $0) }
        let scene = reviseModeLabel.isEmpty
            ? reviseModeId
            : "\(reviseModeLabel)（\(reviseModeId)）"

        let ordered = entries.values.sorted {
            (Int($0.segmentId) ?? 0) < (Int($1.segmentId) ?? 0)
        }

        let transcriptEntries = ordered.enumerated().map { offset, entry in
            TranscriptEntry(
                index: offset + 1,
                time: Self.displayFormatter.string(from: entry.lastUpdated),
                revised: entry.revised,
                english: entry.english,
                chinese: entry.chinese
            )
        }

        return TranscriptDocument(
            started: started,
            scene: scene,
            ended: ended ? (sessionEnded ?? Self.displayFormatter.string(from: Date())) : nil,
            entries: transcriptEntries
        )
    }

    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()
}

enum TranscriptConvertError: LocalizedError {
    case noEntries

    var errorDescription: String? {
        switch self {
        case .noEntries: return "未能从文件中解析出字幕条目"
        }
    }
}
