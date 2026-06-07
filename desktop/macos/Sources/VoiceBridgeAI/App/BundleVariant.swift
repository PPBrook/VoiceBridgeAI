import Foundation

/// Build flavor written into Info.plist by `build-app.sh` (`cloud` | `local`).
enum BundleVariant {
    enum Kind: String {
        case cloud
        case local
        case standard
    }

    static var current: Kind {
        guard let raw = Bundle.main.infoDictionary?["VoiceBridgeBundleVariant"] as? String else {
            return .standard
        }
        return Kind(rawValue: raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()) ?? .standard
    }

    static var includesLocalModels: Bool {
        current != .cloud
    }

    static var appSupportFolderName: String {
        switch current {
        case .cloud: return "VoiceBridgeAI-Cloud"
        case .local: return "VoiceBridgeAI-Local"
        case .standard: return "VoiceBridgeAI"
        }
    }

    static var displaySuffix: String {
        switch current {
        case .cloud: return "（云端）"
        case .local: return "（本地）"
        case .standard: return ""
        }
    }
}
