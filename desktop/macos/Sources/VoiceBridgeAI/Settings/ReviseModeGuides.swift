import AppKit
import Foundation

struct ReviseModeInfo {
    let id: String
    let label: String
    let description: String
    let polishNote: String
    let examples: String
    let silenceMs: Int
    let minUtteranceMs: Int
    let maxUtteranceS: Double
    let refineIntervalS: Double
    let lookback: Int

    static let fallbackIntro =
        "按观看内容选择策略：影响断句、句中更新、回溯，以及句末 LLM 润色风格。"
            + "本地 Whisper / OpenAI 按静音切句；腾讯云由云端切句。修改后保存；运行中切换即时生效。"

    static let fallbackModes: [ReviseModeInfo] = [
        ReviseModeInfo(
            id: "speech",
            label: "演讲 · 跟节奏",
            description: "停顿约 1 秒再切句，单段不宜过长，跟演讲呼吸与排比节奏。",
            polishNote: "润色偏口语化、有节奏感，适合 keynote 听感。",
            examples: "TED、产品发布、毕业演讲",
            silenceMs: 1050,
            minUtteranceMs: 500,
            maxUtteranceS: 14,
            refineIntervalS: 0.9,
            lookback: 2
        ),
        ReviseModeInfo(
            id: "tech",
            label: "技术分享 · 术语稳定",
            description: "概念块尽量完整，术语与解释不拆开；句中更新较快，回溯更深。",
            polishNote: "润色保留 API/框架等术语，全文译名一致。",
            examples: "Meetup、架构讲解、DevRel、代码 walkthrough",
            silenceMs: 900,
            minUtteranceMs: 600,
            maxUtteranceS: 18,
            refineIntervalS: 0.7,
            lookback: 3
        ),
        ReviseModeInfo(
            id: "conference",
            label: "会议 · 低延迟",
            description: "短停顿即切句，句中更新快，少回溯；适合多人轮替与快问快答。",
            polishNote: "润色偏直译清晰，短句优先，减少赘述。",
            examples: "峰会 Q&A、圆桌、同传、多边讨论",
            silenceMs: 600,
            minUtteranceMs: 400,
            maxUtteranceS: 10,
            refineIntervalS: 0.5,
            lookback: 1
        ),
        ReviseModeInfo(
            id: "course",
            label: "网课 · 知识点整段",
            description: "长停顿才切句，过滤「嗯、好、下一页」；整段知识点一起显示。",
            polishNote: "润色成完整知识点表述，适合暂停记笔记。",
            examples: "MOOC、培训录播、在线课程",
            silenceMs: 1500,
            minUtteranceMs: 800,
            maxUtteranceS: 22,
            refineIntervalS: 1.1,
            lookback: 3
        ),
    ]

    static func list(from health: [String: Any]) -> [ReviseModeInfo] {
        guard let raw = health["reviseModes"] as? [[String: Any]], !raw.isEmpty else {
            return fallbackModes
        }
        return raw.compactMap { item in
            guard let id = item["id"] as? String else { return nil }
            return ReviseModeInfo(
                id: id,
                label: item["label"] as? String ?? id,
                description: item["description"] as? String ?? "",
                polishNote: item["polishNote"] as? String ?? "",
                examples: item["examples"] as? String ?? "",
                silenceMs: intValue(item["silenceMs"], default: 1000),
                minUtteranceMs: intValue(item["minUtteranceMs"], default: 500),
                maxUtteranceS: doubleValue(item["maxUtteranceS"], default: 14),
                refineIntervalS: doubleValue(item["refineIntervalS"], default: 0.8),
                lookback: intValue(item["lookback"], default: 2)
            )
        }
    }

    var detailText: String {
        let silence = String(format: "%.1f", Double(silenceMs) / 1000.0)
        let maxUtterance = String(format: "%.0f", maxUtteranceS)
        var lines: [String] = []
        if !description.isEmpty { lines.append(description) }
        if !polishNote.isEmpty { lines.append(polishNote) }
        if !examples.isEmpty { lines.append("示例：\(examples)") }
        lines.append(
            "断句：静音 ≥ \(silence)s 切句 · 单段最长 \(maxUtterance)s · "
                + "句中更新约 \(String(format: "%.1f", refineIntervalS))s · 回溯 \(lookback) 句"
        )
        return lines.joined(separator: "\n")
    }

    private static func intValue(_ value: Any?, default defaultValue: Int) -> Int {
        if let n = value as? Int { return n }
        if let n = value as? NSNumber { return n.intValue }
        return defaultValue
    }

    private static func doubleValue(_ value: Any?, default defaultValue: Double) -> Double {
        if let n = value as? Double { return n }
        if let n = value as? NSNumber { return n.doubleValue }
        return defaultValue
    }
}

@MainActor
enum ReviseModeGuides {
    static func intro(from health: [String: Any]) -> String {
        if let note = health["reviseSceneNote"] as? String, !note.isEmpty {
            return note
        }
        return ReviseModeInfo.fallbackIntro
    }

    static func info(for id: String, health: [String: Any]) -> ReviseModeInfo? {
        ReviseModeInfo.list(from: health).first { $0.id == id }
            ?? ReviseModeInfo.fallbackModes.first { $0.id == id }
    }

    static func detailText(for id: String, health: [String: Any]) -> String {
        info(for: id, health: health)?.detailText ?? "请选择观看场景。"
    }

    static func providerOptions(from health: [String: Any]) -> [ProviderOption] {
        ReviseModeInfo.list(from: health).map { ProviderOption(id: $0.id, label: $0.label) }
    }

    static func fillPopup(_ popup: NSPopUpButton, health: [String: Any], selected: String) {
        let modes = providerOptions(from: health)
        EngineSelectGroups.fillFlatPopup(
            popup,
            providers: modes.isEmpty
                ? ReviseModeInfo.fallbackModes.map { ProviderOption(id: $0.id, label: $0.label) }
                : modes,
            selected: selected
        )
    }
}
