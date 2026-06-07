import Foundation

/// One finalized subtitle line in a transcript file.
struct TranscriptEntry: Equatable {
    let index: Int
    var time: String?
    var revised: Bool
    var english: String
    var chinese: String
}

/// Parsed transcript metadata + entries.
struct TranscriptDocument: Equatable {
    var started: String?
    var scene: String?
    var ended: String?
    var entries: [TranscriptEntry]

    static let empty = TranscriptDocument(started: nil, scene: nil, ended: nil, entries: [])
}

enum TranscriptContentLayout: String, CaseIterable {
    case bilingualBlocks
    case combined
    case englishOnly
    case chineseOnly

    var label: String {
        switch self {
        case .bilingualBlocks: return "中英对照（分区）"
        case .combined: return "中英结合（连续）"
        case .englishOnly: return "纯英文"
        case .chineseOnly: return "纯中文"
        }
    }

    var exportSuffix: String {
        switch self {
        case .bilingualBlocks: return "_dual"
        case .combined: return "_mix"
        case .englishOnly: return "_en"
        case .chineseOnly: return "_zh"
        }
    }
}

enum TranscriptParser {
    static func parse(text: String) -> TranscriptDocument {
        let lines = text.components(separatedBy: .newlines)
        var started: String?
        var scene: String?
        var ended: String?
        var entries: [TranscriptEntry] = []

        var i = 0
        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("- 开始：") || line.hasPrefix("开始：") {
                started = line.replacingOccurrences(of: "- 开始：", with: "")
                    .replacingOccurrences(of: "开始：", with: "")
            } else if line.hasPrefix("- 观看场景：") || line.hasPrefix("观看场景：") {
                scene = line.replacingOccurrences(of: "- 观看场景：", with: "")
                    .replacingOccurrences(of: "观看场景：", with: "")
            } else if line.hasPrefix("结束：") {
                ended = String(line.dropFirst("结束：".count))
            } else if line.hasPrefix("## ") {
                if let entry = parseMarkdownSection(lines: lines, start: i) {
                    entries.append(entry.entry)
                    i = entry.nextIndex
                    continue
                }
            } else if line.hasPrefix("[") && line.contains("]") {
                if let entry = parsePlainSection(lines: lines, start: i) {
                    entries.append(entry.entry)
                    i = entry.nextIndex
                    continue
                }
            }
            i += 1
        }

        return TranscriptDocument(started: started, scene: scene, ended: ended, entries: entries)
    }

    static func parse(file url: URL) throws -> TranscriptDocument {
        let text = try String(contentsOf: url, encoding: .utf8)
        return parse(text: text)
    }

    private static func parseMarkdownSection(lines: [String], start: Int) -> (entry: TranscriptEntry, nextIndex: Int)? {
        let header = lines[start].trimmingCharacters(in: .whitespaces)
        guard header.hasPrefix("## ") else { return nil }

        let body = String(header.dropFirst(3))
        let revised = body.contains("修订")
        let index = entriesIndex(fromHeader: body) ?? 0
        let time = timeFromHeader(body)

        var english = ""
        var chinese = ""
        var i = start + 1
        var mode: String?

        while i < lines.count {
            let raw = lines[i]
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("## ") {
                break
            }
            if line == "---", mode != nil {
                break
            }
            if line == "**英文**" || line == "英文" {
                mode = "en"
                i += 1
                continue
            }
            if line == "**中文**" || line == "中文" {
                mode = "zh"
                i += 1
                continue
            }
            if line.isEmpty || line == "---" {
                i += 1
                continue
            }
            switch mode {
            case "en":
                english = english.isEmpty ? line : english + "\n" + line
            case "zh":
                chinese = chinese.isEmpty ? line : chinese + "\n" + line
            default:
                break
            }
            i += 1
        }

        guard !english.isEmpty || !chinese.isEmpty else { return nil }
        let entry = TranscriptEntry(
            index: index,
            time: time,
            revised: revised,
            english: english.trimmingCharacters(in: .whitespacesAndNewlines),
            chinese: chinese.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        return (entry, i)
    }

    private static func entriesIndex(fromHeader header: String) -> Int? {
        let digits = header.prefix(while: { $0.isNumber })
        return Int(digits)
    }

    private static func parsePlainSection(lines: [String], start: Int) -> (entry: TranscriptEntry, nextIndex: Int)? {
        let header = lines[start].trimmingCharacters(in: .whitespaces)
        guard header.hasPrefix("["), header.hasSuffix("]") else { return nil }

        let inner = String(header.dropFirst().dropLast())
        let revised = inner.contains("修订")
        let index = entriesIndex(fromHeader: inner) ?? 0
        let time = timeFromPlainHeader(inner)

        var english = ""
        var chinese = ""
        var i = start + 1
        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("[") && line.hasSuffix("]") { break }
            if line.hasPrefix("英文：") {
                english = String(line.dropFirst("英文：".count))
            } else if line.hasPrefix("中文：") {
                chinese = String(line.dropFirst("中文：".count))
            } else if line.isEmpty {
                if !english.isEmpty || !chinese.isEmpty { break }
            }
            i += 1
        }

        guard !english.isEmpty || !chinese.isEmpty else { return nil }
        return (
            TranscriptEntry(
                index: index,
                time: time,
                revised: revised,
                english: english.trimmingCharacters(in: .whitespacesAndNewlines),
                chinese: chinese.trimmingCharacters(in: .whitespacesAndNewlines)
            ),
            i
        )
    }

    private static func timeFromHeader(_ header: String) -> String? {
        guard let dotRange = header.range(of: " · ", options: .backwards) else { return nil }
        return String(header[dotRange.upperBound...]).trimmingCharacters(in: .whitespaces)
    }

    private static func timeFromPlainHeader(_ inner: String) -> String? {
        guard let dotRange = inner.range(of: " · ", options: .backwards) else { return nil }
        return String(inner[dotRange.upperBound...]).trimmingCharacters(in: .whitespaces)
    }
}

enum TranscriptRenderer {
    static func render(
        document: TranscriptDocument,
        layout: TranscriptContentLayout,
        format: TranscriptPreferences.FileFormat,
        ended: Bool = false
    ) -> String {
        switch format {
        case .markdown:
            return renderMarkdown(document: document, layout: layout, ended: ended)
        case .plainText:
            return renderPlainText(document: document, layout: layout, ended: ended)
        }
    }

    static func exportURL(for source: URL, layout: TranscriptContentLayout, format: TranscriptPreferences.FileFormat) -> URL {
        let base = source.deletingPathExtension().lastPathComponent
        let dir = source.deletingLastPathComponent()
        let ext = format.fileExtension
        return dir.appendingPathComponent("\(base)\(layout.exportSuffix).\(ext)")
    }

    private static func renderMarkdown(document: TranscriptDocument, layout: TranscriptContentLayout, ended: Bool) -> String {
        var lines: [String] = [
            "# VoiceBridgeAI 字幕记录",
            "",
        ]
        if let started = document.started, !started.isEmpty {
            lines.append("- 开始：\(started)")
        }
        if let scene = document.scene, !scene.isEmpty {
            lines.append("- 观看场景：\(scene)")
        }
        lines.append("- 内容形式：\(layout.label)")
        lines.append("")
        lines.append("---")
        lines.append("")

        for (offset, entry) in document.entries.enumerated() {
            appendEntry(entry, displayIndex: offset + 1, layout: layout, markdown: true, to: &lines)
        }

        if ended, let endedAt = document.ended, !endedAt.isEmpty {
            lines.append("结束：\(endedAt)")
        } else if ended {
            lines.append("结束：\(displayNow())")
        }
        lines.append("")
        return lines.joined(separator: "\n")
    }

    private static func renderPlainText(document: TranscriptDocument, layout: TranscriptContentLayout, ended: Bool) -> String {
        var lines: [String] = ["VoiceBridgeAI 字幕记录"]
        if let started = document.started, !started.isEmpty {
            lines.append("开始：\(started)")
        }
        if let scene = document.scene, !scene.isEmpty {
            lines.append("观看场景：\(scene)")
        }
        lines.append("内容形式：\(layout.label)")
        lines.append("")

        for (offset, entry) in document.entries.enumerated() {
            appendEntry(entry, displayIndex: offset + 1, layout: layout, markdown: false, to: &lines)
        }

        if ended, let endedAt = document.ended, !endedAt.isEmpty {
            lines.append("结束：\(endedAt)")
        } else if ended {
            lines.append("结束：\(displayNow())")
        }
        lines.append("")
        return lines.joined(separator: "\n")
    }

    private static func appendEntry(
        _ entry: TranscriptEntry,
        displayIndex: Int,
        layout: TranscriptContentLayout,
        markdown: Bool,
        to lines: inout [String]
    ) {
        let tag = entry.revised ? " · 修订" : ""
        let time = entry.time ?? ""
        let headerSuffix = time.isEmpty ? "" : " · \(time)"

        switch layout {
        case .englishOnly:
            guard !entry.english.isEmpty else { return }
            if markdown {
                lines.append("## \(displayIndex)\(tag)\(headerSuffix)")
                lines.append("")
                lines.append(entry.english)
                lines.append("")
                lines.append("---")
                lines.append("")
            } else {
                lines.append("[\(displayIndex)\(tag)\(headerSuffix)]")
                lines.append(entry.english)
                lines.append("")
            }

        case .chineseOnly:
            let zh = entry.chinese.isEmpty ? entry.english : entry.chinese
            guard !zh.isEmpty else { return }
            if markdown {
                lines.append("## \(displayIndex)\(tag)\(headerSuffix)")
                lines.append("")
                lines.append(zh)
                lines.append("")
                lines.append("---")
                lines.append("")
            } else {
                lines.append("[\(displayIndex)\(tag)\(headerSuffix)]")
                lines.append(zh)
                lines.append("")
            }

        case .combined:
            if markdown {
                lines.append("## \(displayIndex)\(tag)\(headerSuffix)")
                lines.append("")
                if !entry.english.isEmpty { lines.append(entry.english) }
                if !entry.chinese.isEmpty { lines.append(entry.chinese) }
                lines.append("")
                lines.append("---")
                lines.append("")
            } else {
                lines.append("[\(displayIndex)\(tag)\(headerSuffix)]")
                if !entry.english.isEmpty { lines.append(entry.english) }
                if !entry.chinese.isEmpty { lines.append(entry.chinese) }
                lines.append("")
            }

        case .bilingualBlocks:
            if markdown {
                lines.append("## \(displayIndex)\(tag)\(headerSuffix)")
                lines.append("")
                if !entry.english.isEmpty {
                    lines.append("**英文**")
                    lines.append(entry.english)
                    lines.append("")
                }
                if !entry.chinese.isEmpty {
                    lines.append("**中文**")
                    lines.append(entry.chinese)
                    lines.append("")
                }
                lines.append("---")
                lines.append("")
            } else {
                lines.append("[\(displayIndex)\(tag)\(headerSuffix)]")
                if !entry.english.isEmpty { lines.append("英文：\(entry.english)") }
                if !entry.chinese.isEmpty { lines.append("中文：\(entry.chinese)") }
                lines.append("")
            }
        }
    }

    private static func displayNow() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f.string(from: Date())
    }
}
