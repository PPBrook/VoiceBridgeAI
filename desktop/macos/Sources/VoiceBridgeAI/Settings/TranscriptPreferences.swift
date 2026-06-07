import Foundation

/// Subtitle transcript storage path and filename preferences.
@MainActor
enum TranscriptPreferences {
    private static let directoryKey = "transcriptStorageDirectory"
    private static let filenameTemplateKey = "transcriptFilenameTemplate"
    private static let filePrefixKey = "transcriptFilePrefix"
    private static let fileExtensionKey = "transcriptFileExtension"
    private static let contentLayoutKey = "transcriptContentLayout"
    /// Kept from overlay toggle key for upgrade compatibility.
    private static let recordEnabledKey = "overlayRecordTranslations"

    static let filenameTokenHelp = "可用占位符：{prefix} {date} {time} {datetime} {mode}"

    /// Whether finalized subtitles are written to `storageDirectory` while a session runs.
    static var recordEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: recordEnabledKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: recordEnabledKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: recordEnabledKey)
        }
    }

    static var defaultDirectory: URL {
        CloudProviderPreferences.dataDirectory().appendingPathComponent("transcripts", isDirectory: true)
    }

    static var storageDirectory: URL {
        get {
            let raw = UserDefaults.standard.string(forKey: directoryKey)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if raw.isEmpty { return defaultDirectory }
            return URL(fileURLWithPath: raw, isDirectory: true)
        }
        set {
            UserDefaults.standard.set(newValue.path, forKey: directoryKey)
        }
    }

    static var usesDefaultDirectory: Bool {
        UserDefaults.standard.string(forKey: directoryKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
    }

    static func resetDirectoryToDefault() {
        UserDefaults.standard.removeObject(forKey: directoryKey)
    }

    static var directoryDisplayPath: String {
        if usesDefaultDirectory {
            return "默认：\(defaultDirectory.path)"
        }
        return storageDirectory.path
    }

    /// 文件名模板，默认 `{prefix}_{datetime}`。
    static var filenameTemplate: String {
        get {
            let stored = UserDefaults.standard.string(forKey: filenameTemplateKey)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return stored.isEmpty ? "{prefix}_{datetime}" : stored
        }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            UserDefaults.standard.set(trimmed.isEmpty ? "{prefix}_{datetime}" : trimmed, forKey: filenameTemplateKey)
        }
    }

    static var filePrefix: String {
        get {
            let stored = UserDefaults.standard.string(forKey: filePrefixKey)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return stored.isEmpty ? "字幕记录" : stored
        }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            UserDefaults.standard.set(trimmed.isEmpty ? "字幕记录" : trimmed, forKey: filePrefixKey)
        }
    }

    enum FileFormat: String, CaseIterable {
        case markdown
        case plainText

        var fileExtension: String {
            switch self {
            case .markdown: return "md"
            case .plainText: return "txt"
            }
        }

        var label: String {
            switch self {
            case .markdown: return "Markdown (.md)"
            case .plainText: return "纯文本 (.txt)"
            }
        }
    }

    static var fileFormat: FileFormat {
        get {
            guard let raw = UserDefaults.standard.string(forKey: fileExtensionKey) else { return .markdown }
            return FileFormat(rawValue: raw) ?? .markdown
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: fileExtensionKey)
        }
    }

    static var contentLayout: TranscriptContentLayout {
        get {
            guard let raw = UserDefaults.standard.string(forKey: contentLayoutKey),
                  let layout = TranscriptContentLayout(rawValue: raw) else {
                return .bilingualBlocks
            }
            return layout
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: contentLayoutKey)
        }
    }

    static func sessionFilename(started: Date, modeId: String) -> String {
        let template = filenameTemplate
        let prefix = sanitizePathComponent(filePrefix)
        let mode = sanitizePathComponent(modeId)

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "zh_CN")
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let date = dateFormatter.string(from: started)

        dateFormatter.dateFormat = "HH-mm-ss"
        let time = dateFormatter.string(from: started)

        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let datetime = dateFormatter.string(from: started)

        var name = template
            .replacingOccurrences(of: "{prefix}", with: prefix)
            .replacingOccurrences(of: "{date}", with: date)
            .replacingOccurrences(of: "{time}", with: time)
            .replacingOccurrences(of: "{datetime}", with: datetime)
            .replacingOccurrences(of: "{mode}", with: mode)

        name = sanitizePathComponent(name)
        if name.isEmpty { name = "\(prefix)_\(datetime)" }

        let ext = fileFormat.fileExtension
        if !name.lowercased().hasSuffix(".\(ext)") {
            name += ".\(ext)"
        }
        return name
    }

    static func sanitizePathComponent(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let invalid = CharacterSet(charactersIn: "/:\\?%*|\"<>\n\r\t")
        let scalars = trimmed.unicodeScalars.map { invalid.contains($0) ? "_" : Character($0) }
        return String(scalars).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
