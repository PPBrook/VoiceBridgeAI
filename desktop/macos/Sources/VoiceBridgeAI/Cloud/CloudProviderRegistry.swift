import Foundation

enum CloudProviderRegion {
    case domestic
    case overseas
}

struct CloudProviderTest {
    let label: String
    let layer: String
    let providerId: String

    var key: String { "\(layer):\(providerId)" }
}

/// 云端厂商卡片元数据（分区、测试项）— Swift 与 Python `cloud_ui_prefs.CARD_TEST_TARGETS` 对齐。
enum CloudProviderRegistry {
    static let domesticOrder = ["tencent", "qiniu", "aliyun", "baidu", "deepseek"]
    static let overseasOrder = ["openai", "deepl", "google"]
    static let allIds: [String] = domesticOrder + overseasOrder

    static let testsByProvider: [String: [CloudProviderTest]] = [
        "tencent": [
            .init(label: "识别", layer: "asr", providerId: "tencent"),
            .init(label: "句中 TMT", layer: "partial", providerId: "tmt"),
            .init(label: "句末 TMT", layer: "final", providerId: "tmt"),
        ],
        "qiniu": [
            .init(label: "句中", layer: "partial", providerId: "qiniu"),
            .init(label: "句末", layer: "final", providerId: "qiniu"),
        ],
        "aliyun": [
            .init(label: "句中", layer: "partial", providerId: "aliyun"),
            .init(label: "句末", layer: "final", providerId: "aliyun"),
        ],
        "baidu": [
            .init(label: "句中", layer: "partial", providerId: "baidu"),
            .init(label: "句末", layer: "final", providerId: "baidu"),
        ],
        "deepseek": [
            .init(label: "句中", layer: "partial", providerId: "deepseek"),
            .init(label: "句末", layer: "final", providerId: "deepseek"),
        ],
        "openai": [
            .init(label: "识别", layer: "asr", providerId: "openai"),
            .init(label: "句中", layer: "partial", providerId: "openai"),
            .init(label: "句末", layer: "final", providerId: "openai"),
        ],
        "deepl": [
            .init(label: "句中", layer: "partial", providerId: "deepl"),
            .init(label: "句末", layer: "final", providerId: "deepl"),
        ],
        "google": [
            .init(label: "句中", layer: "partial", providerId: "google"),
            .init(label: "句末", layer: "final", providerId: "google"),
        ],
    ]

    static func tests(for providerId: String) -> [CloudProviderTest] {
        testsByProvider[providerId] ?? []
    }

    static func cardId(forTestKey key: String) -> String? {
        for (id, tests) in testsByProvider where tests.contains(where: { $0.key == key }) {
            return id
        }
        return nil
    }

    static func activeTestKeys(hidden: Set<String>) -> [String] {
        allIds.flatMap { id -> [String] in
            guard !hidden.contains(id) else { return [] }
            return tests(for: id).map(\.key)
        }
    }
}
